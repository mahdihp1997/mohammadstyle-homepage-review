// Local review recovery drill; S3 bucket lifecycle/backup is a separate deployment decision.
import fs from "node:fs/promises";
import path from "node:path";
import assert from "node:assert/strict";
import { client, root, identify, save } from "./local.mjs";
import { LocalMediaStorage, sha } from "../../dist/mvp/storage.js";
if (
  process.env.APP_ENV !== "mvp-local" ||
  process.env.NODE_ENV === "production" ||
  (process.env.MVP_STORAGE && process.env.MVP_STORAGE !== "local")
)
  throw Error("Explicit local storage recovery drill required");
const source = path.resolve(root, ".local/mvp/media"),
  copy = path.resolve(root, ".local/mvp/backup/media"),
  restored = path.resolve(root, ".local/mvp/media-restore");
for (const p of [source, copy, restored])
  assert.ok(p.startsWith(path.resolve(root, ".local/mvp") + path.sep));
const db = client("ms_mvp_dev");
await db.connect();
try {
  await identify(db, "ms_mvp_dev");
  const keys = (
    await db.query(
      "SELECT original_key key,source_hash digest FROM ms_b1_design.media_asset UNION ALL SELECT storage_key key,sha256 digest FROM ms_b1_design.media_variant ORDER BY key",
    )
  ).rows;
  const collect = async (stream) => {
      const a = [];
      for await (const c of stream) a.push(c);
      return Buffer.concat(a);
    },
    input = new LocalMediaStorage(source),
    backup = new LocalMediaStorage(copy),
    output = new LocalMediaStorage(restored);
  for (const { key, digest } of keys) {
    const bytes = await collect(await input.read(key));
    assert.equal(sha(bytes), digest);
    await backup.put(key, bytes, "application/octet-stream");
    await output.put(
      key,
      await collect(await backup.read(key)),
      "application/octet-stream",
    );
    assert.equal(sha(await collect(await output.read(key))), digest);
  }
  const result = {
    status: "PASS",
    kind: "ACTUAL_LOCAL_OBJECT_BACKUP_AND_SEPARATE_COPY_RESTORE",
    objects: keys.length,
    manifestSha256: sha(JSON.stringify(keys)),
    sourceUntouched: true,
    liveS3BackupTested: false,
  };
  save("media-restore.json", result);
  console.log(JSON.stringify(result));
} finally {
  await db.end();
}
