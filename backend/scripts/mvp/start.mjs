import fs from "node:fs";
import path from "node:path";
import { spawn } from "node:child_process";
import { root } from "./local.mjs";
if (
  process.env.APP_ENV !== "mvp-local" ||
  process.env.NODE_ENV === "production"
)
  throw Error("Explicit isolated startup required");
const p = path.join(root, ".local/mvp/public-tenant.json"),
  business =
    process.env.MVP_PUBLIC_BUSINESS_ID ??
    (fs.existsSync(p) ? JSON.parse(fs.readFileSync(p)).businessId : "");
if (business && !/^[a-f0-9-]{36}$/.test(business))
  throw Error("Invalid public tenant configuration");
const child = spawn(process.execPath, [path.join(root, "dist/mvp/main.js")], {
  stdio: "inherit",
  windowsHide: true,
  env: {
    ...process.env,
    ...(business ? { MVP_PUBLIC_BUSINESS_ID: business } : {}),
  },
});
child.on("exit", (n) => (process.exitCode = n ?? 1));
process.on("SIGINT", () => child.kill("SIGINT"));
process.on("SIGTERM", () => child.kill("SIGTERM"));
