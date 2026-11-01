import { randomBytes, timingSafeEqual } from "node:crypto";
import { NextRequest, NextResponse } from "next/server";
import { localLoginBridge } from "@/lib/mvp/local-login";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
const headers = { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff", "Cross-Origin-Resource-Policy": "same-origin" };
const error = (code: string, status: number) => NextResponse.json({ code }, { status, headers });
const format = /^[A-Za-z0-9_-]{43}$/;
function allowed(req: NextRequest) {
  return req.headers.get("host") === "127.0.0.1:3000" &&
    !["cross-site", "same-site"].includes(req.headers.get("sec-fetch-site") ?? "") &&
    (!req.headers.get("origin") || req.headers.get("origin") === "http://127.0.0.1:3000");
}
export async function GET(req: NextRequest) {
  if (!localLoginBridge() || req.headers.get("host") !== "127.0.0.1:3000") return error("LOCAL_LOGIN_DISABLED", 404);
  if (!allowed(req)) return error("FORBIDDEN", 403);
  const nonce = randomBytes(32).toString("base64url");
  const response = NextResponse.json({ csrfToken: nonce }, { headers });
  response.cookies.set("ms_login_nonce", nonce, { httpOnly: true, sameSite: "strict", path: "/api/local-review/login", maxAge: 600 });
  return response;
}
export async function POST(req: NextRequest) {
  const bridge = localLoginBridge();
  if (!bridge || req.headers.get("host") !== "127.0.0.1:3000") return error("LOCAL_LOGIN_DISABLED", 404);
  if (!allowed(req) || req.headers.get("origin") !== "http://127.0.0.1:3000") return error("FORBIDDEN", 403);
  const cookies = req.cookies.getAll("ms_login_nonce"), csrf = req.headers.get("x-login-csrf") ?? "";
  if (cookies.length !== 1 || !format.test(cookies[0].value) || !format.test(csrf) ||
      !timingSafeEqual(Buffer.from(cookies[0].value), Buffer.from(csrf))) return error("FORBIDDEN", 403);
  if (!/^application\/json(?:;\s*charset=utf-8)?$/i.test(req.headers.get("content-type") ?? "")) return error("INVALID_REQUEST", 415);
  const reader = req.body?.getReader();
  if (!reader) return error("INVALID_REQUEST", 422);
  const chunks: Uint8Array[] = []; let size = 0;
  for (;;) {
    const chunk = await reader.read(); if (chunk.done) break;
    size += chunk.value.byteLength;
    if (size > 2048) { await reader.cancel(); return error("INVALID_REQUEST", 413); }
    chunks.push(chunk.value);
  }
  try {
    const upstream = await fetch("http://127.0.0.1:3112/api/v1/local-review/login", {
      method: "POST", headers: { origin: "http://127.0.0.1:3112", "sec-fetch-site": "same-origin",
        "content-type": "application/json", "x-local-login-bridge": bridge },
      body: Buffer.concat(chunks).toString("utf8"), cache: "no-store", redirect: "error", signal: AbortSignal.timeout(12000),
    });
    if (!upstream.ok) {
      const status = [401, 403, 413, 415, 422, 429].includes(upstream.status) ? upstream.status : 503;
      const response = error(status === 401 ? "INVALID_CREDENTIALS" : status === 429 ? "RATE_LIMITED" : "LOGIN_UNAVAILABLE", status);
      if (status === 429) response.headers.set("Retry-After", "60");
      return response;
    }
    const value = await upstream.json();
    if (!format.test(value.token) || !format.test(value.csrf) || value.maxAge !== 3600) return error("LOGIN_UNAVAILABLE", 503);
    // Never serialize upstream session tokens into the client response body or URL.
    const response = NextResponse.json({ authenticated: true }, { headers });
    response.cookies.set("ms_session", value.token, { httpOnly: true, sameSite: "strict", path: "/", maxAge: 3600 });
    response.cookies.set("ms_csrf", value.csrf, { sameSite: "strict", path: "/", maxAge: 3600 });
    response.cookies.set("ms_login_nonce", "", { httpOnly: true, sameSite: "strict", path: "/api/local-review/login", maxAge: 0 });
    return response;
  } catch { return error("LOGIN_UNAVAILABLE", 503); }
}
