import { NextRequest, NextResponse } from "next/server";
const id = "[a-f0-9-]{36}",
  patterns = [
    /^session(?:\/revoke)?$/,
    /^admin\/(?:business|branches|services|staff|staff\/qualifications|workforce\/context)$/,
    new RegExp(`^admin/(?:branches|services|staff)/${id}$`),
    new RegExp(`^admin/staff/${id}/verified-identity$`),
    new RegExp(
      `^admin/branches/${id}/(?:offerings(?:/${id})?|branch-assignments(?:/${id}/end)?|offering-staff-eligibility|resources(?:/${id})?|working-hours|schedule-rules|schedule/(?:publications|withdrawals)|time-off(?:/${id}/review)?|closures(?:/${id}/review)?|availability-configuration|calendar|exceptions|staff/${id}/schedule)$`,
    ),
    /^admin\/pricing\/(?:context|policies|assignments|commands\/(?:policy.create|version.create|version.replace|version.publish|version.retire|assignment.create|assignment.revoke|configuration.set))$/,
    /^admin\/portal\/workspace$/,
    /^admin\/portal\/read\/(?:media|categories|reservations|reservation|identities|instant|policy-headers)$/,
    /^admin\/portal\/commands\/(?:branch.save|service.save|offering.create|offering.configure|offering.requirements|booking.cancel|category.save|media.edit|media.rights|media.publish|media.unpublish|media.archive)$/,
    /^admin\/media\/upload$/,
    new RegExp(`^admin/media/view/${id}/(?:THUMB|DISPLAY|VIDEO)$`),
    /^booking\/commands\/configuration.enable$/,
  ];
export function mvpEnabled() {
  return (
    process.env.MS_MVP_ENABLED === "1" && process.env.NODE_ENV !== "production"
  );
}
export async function mvpProxy(
  req: NextRequest,
  route: string,
  publicRoute = false,
) {
  const headers = {
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
    error = (code: string, status: number) =>
      NextResponse.json({ code }, { status, headers });
  if (!mvpEnabled() || req.headers.get("host") !== "127.0.0.1:3000")
    return error("MVP_DISABLED", 404);
  if (
    publicRoute
      ? !/^portfolio(?:\/[a-f0-9-]{36}\/(?:THUMB|DISPLAY|VIDEO))?$/.test(route)
      : !patterns.some((p) => p.test(route))
  )
    return error("NOT_FOUND", 404);
  const writing = !["GET", "HEAD"].includes(req.method);
  if (
    (publicRoute && writing) ||
    !["GET", "HEAD", "POST", "PUT"].includes(req.method)
  )
    return error("METHOD_NOT_ALLOWED", 405);
  if (
    (req.headers.get("origin") &&
      req.headers.get("origin") !== "http://127.0.0.1:3000") ||
    (writing && req.headers.get("origin") !== "http://127.0.0.1:3000")
  )
    return error("FORBIDDEN", 403);
  const cookies = req.cookies.getAll("ms_session");
  if (
    !publicRoute &&
    (cookies.length !== 1 || !/^[A-Za-z0-9_-]{43}$/.test(cookies[0].value))
  )
    return error("UNAUTHENTICATED", 401);
  let body: string | undefined;
  if (writing) {
    if (
      !/^application\/json(?:;\s*charset=utf-8)?$/i.test(
        req.headers.get("content-type") ?? "",
      )
    )
      return error("INVALID_REQUEST", 415);
    const limit = route === "admin/media/upload" ? 44 * 1024 * 1024 : 32768,
      reader = req.body?.getReader();
    if (!reader) return error("INVALID_REQUEST", 422);
    const chunks: Uint8Array[] = [];
    let size = 0;
    for (;;) {
      const chunk = await reader.read();
      if (chunk.done) break;
      size += chunk.value.byteLength;
      if (size > limit) {
        await reader.cancel();
        return error("UPLOAD_SIZE", 413);
      }
      chunks.push(chunk.value);
    }
    body = Buffer.concat(chunks).toString("utf8");
  }
  const upstreamHeaders: Record<string, string> = {
    origin: "http://127.0.0.1:3112",
    "sec-fetch-site": "same-origin",
  };
  if (!publicRoute) upstreamHeaders.cookie = "ms_session=" + cookies[0].value;
  if (writing) {
    upstreamHeaders["content-type"] = "application/json";
    for (const name of ["x-csrf-token", "idempotency-key", "if-match"]) {
      const v = req.headers.get(name);
      if (v) upstreamHeaders[name] = v;
    }
  }
  if (req.headers.get("range"))
    upstreamHeaders.range = req.headers.get("range")!;
  try {
    const r = await fetch(
      "http://127.0.0.1:3112/api/v1/" + route + req.nextUrl.search,
      {
        method: req.method,
        headers: upstreamHeaders,
        body,
        redirect: "error",
        cache: "no-store",
        signal: AbortSignal.timeout(
          route === "admin/media/upload" ? 180000 : 35000,
        ),
      },
    );
    const responseHeaders = new Headers(headers);
    for (const name of [
      "content-type",
      "content-length",
      "content-range",
      "accept-ranges",
      "etag",
      "retry-after",
      "cross-origin-resource-policy",
    ]) {
      const v = r.headers.get(name);
      if (v) responseHeaders.set(name, v);
    }
    const response = new NextResponse(req.method === "HEAD" ? null : r.body, {
      status: r.status,
      headers: responseHeaders,
    });
    if (route === "session/revoke" && r.ok) {
      response.cookies.set("ms_session", "", {
        path: "/",
        httpOnly: true,
        sameSite: "strict",
        maxAge: 0,
      });
      response.cookies.set("ms_csrf", "", {
        path: "/",
        sameSite: "strict",
        maxAge: 0,
      });
    }
    return response;
  } catch {
    return error("UNAVAILABLE", 503);
  }
}
