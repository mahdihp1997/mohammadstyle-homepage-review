import "server-only";
import fs from "node:fs";
import path from "node:path";
import { mvpEnabled } from "./proxy";
import {productEnabled} from '@/lib/product/config';

/** Only this bridge key reaches Next. The password verifier/DB secret stay in Nest. */
export function localLoginBridge(): string | null {
  if (productEnabled() || process.env.NODE_ENV === 'production' || !mvpEnabled()) return null;
  try {
    const value = JSON.parse(fs.readFileSync(path.join(process.cwd(), "backend/.local/mvp/login-bridge.json"), "utf8"));
    return value.version === 1 && typeof value.secret === "string" && /^[A-Za-z0-9_-]{43}$/.test(value.secret)
      ? value.secret : null;
  } catch { return null; }
}
