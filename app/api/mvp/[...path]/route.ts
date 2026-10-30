import { NextRequest } from "next/server";
import { mvpProxy } from "@/lib/mvp/proxy";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
async function handler(
  req: NextRequest,
  { params }: { params: Promise<{ path: string[] }> },
) {
  return mvpProxy(req, (await params).path.join("/"));
}
export { handler as GET, handler as POST, handler as PUT, handler as HEAD };
