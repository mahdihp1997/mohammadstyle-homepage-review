import { NextRequest } from "next/server";
import { mvpProxy } from "@/lib/mvp/proxy";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
async function handler(
  req: NextRequest,
  { params }: { params: Promise<{ path?: string[] }> },
) {
  const p = (await params).path;
  return mvpProxy(
    req,
    "portfolio" + (p?.length ? "/" + p.join("/") : ""),
    true,
  );
}
export { handler as GET, handler as HEAD };
