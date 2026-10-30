// Offline local review tool, never imported by Nest or exposed as a login endpoint.
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { root } from "./local.mjs";
if (
  process.env.APP_ENV !== "mvp-local" ||
  process.env.NODE_ENV === "production"
)
  throw Error("Explicit synthetic local review required");
const f = JSON.parse(
    fs.readFileSync(path.join(root, ".local/mvp/review-session.json")),
  ),
  a = f.accounts.owner;
const response = await fetch("http://127.0.0.1:3112/api/v1/session", {
  headers: {
    cookie: "ms_session=" + a.token,
    origin: "http://127.0.0.1:3112",
    "sec-fetch-site": "same-origin",
  },
  signal: AbortSignal.timeout(10000),
});
if (!response.ok || (await response.json()).businessId !== f.businessId)
  throw Error(
    "Existing verified local session required; rotate it with refresh-session.mjs",
  );
const { chromium } = createRequire(path.join(root, "../package.json"))(
    "@playwright/test",
  ),
  context = await chromium.launchPersistentContext(
    path.join(root, ".local/mvp/review-browser"),
    {
      headless: false,
      channel: process.env.PLAYWRIGHT_CHANNEL ?? "chrome",
      locale: "fa-IR",
      viewport: { width: 1440, height: 900 },
    },
  );
await context.addCookies([
  {
    name: "ms_session",
    value: a.token,
    domain: "127.0.0.1",
    path: "/",
    httpOnly: true,
    sameSite: "Strict",
  },
  {
    name: "ms_csrf",
    value: a.csrf,
    domain: "127.0.0.1",
    path: "/",
    sameSite: "Strict",
  },
]);
await context.newPage().then((p) => p.goto("http://127.0.0.1:3000/admin"));
console.log(
  "Opened authenticated synthetic local review. No production login or client media. Close Chrome to end this tool.",
);
await new Promise((resolve) => context.on("close", resolve));
