import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createMvpApp } from "./app.js";
import { LocalMediaStorage, S3MediaStorage } from "./storage.js";
if (
  process.env.APP_ENV !== "mvp-local" ||
  process.env.NODE_ENV === "production"
)
  throw Error("Explicit isolated MVP environment required");
if (
  process.env.MVP_STORAGE &&
  !["local", "s3"].includes(process.env.MVP_STORAGE)
)
  throw Error("Unknown storage provider");
const root = fileURLToPath(new URL("../../", import.meta.url)),
  env = Object.fromEntries(
    fs
      .readFileSync(path.join(root, ".env.mvp.local"), "utf8")
      .split(/\r?\n/)
      .filter(Boolean)
      .map((l) => {
        const i = l.indexOf("=");
        return [l.slice(0, i), l.slice(i + 1)];
      }),
  );
const storage =
  process.env.MVP_STORAGE === "s3"
    ? new S3MediaStorage({
        endpoint: process.env.MVP_S3_ENDPOINT ?? "",
        bucket: process.env.MVP_S3_BUCKET ?? "",
        region: process.env.MVP_S3_REGION ?? "",
        accessKey: process.env.MVP_S3_ACCESS_KEY ?? "",
        secretKey: process.env.MVP_S3_SECRET_KEY ?? "",
      })
    : new LocalMediaStorage(path.join(root, ".local/mvp/media"));
const app = await createMvpApp(
  {
    host: "127.0.0.1",
    port: 55450,
    database: "ms_mvp_dev",
    user: "ms_b1b_api",
    password: env.MVP_API_PASSWORD!,
    origin: "http://127.0.0.1:3112",
  },
  storage,
  process.env.MVP_PUBLIC_BUSINESS_ID ?? null,
);
await app.listen(3112, "127.0.0.1");
