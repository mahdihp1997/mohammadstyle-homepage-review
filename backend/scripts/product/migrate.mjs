import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import pg from "pg";
import { fileURLToPath } from "node:url";
import { root, applyEnvironment, client, identify, save } from "./local.mjs";
export function definitions() {
  const registry = JSON.parse(fs.readFileSync(path.join(root, "migrations/registry.product.json"), "utf8"));
  if (!Array.isArray(registry.migrations) || !registry.migrations.length) throw Error("Empty product registry");
  return registry.migrations.map((m,i) => {
    if (!/^\d{4}_[a-z0-9_]+$/.test(m.id) || Number(m.id.slice(0,4)) !== i+1 || m.file !== m.id + ".sql" || !/^[a-f0-9]{64}$/.test(m.sha256)) throw Error("Invalid/noncontiguous product registry");
    const sql = fs.readFileSync(path.join(root, "migrations", m.file), "utf8").replaceAll("\r\n", "\n");
    if (createHash("sha256").update(sql).digest("hex") !== m.sha256) throw Error("Product migration checksum mismatch: " + m.id);
    return { ...m, sql };
  });
}
export async function migrate(db, expectedMarker, { throughCore = false } = {}) {
  const actual = (await db.query("SELECT current_user role,current_setting('server_version_num')::int version,shobj_description((SELECT oid FROM pg_database WHERE datname=current_database()),'pg_database') marker")).rows[0];
  if (actual.role !== "ms_b1a_migrator" || actual.marker !== expectedMarker || actual.version < 180000 || actual.version >= 190000)
    throw Error("Explicit PostgreSQL18 product migration owner/marker required");
  const wanted = definitions().filter(m => !throughCore || m.id.slice(0,4) <= "0015");
  const result = [];
  await db.query("BEGIN");
  try {
    await db.query("SET LOCAL lock_timeout='10s'");
    await db.query("SELECT pg_advisory_xact_lock(603031,1)");
    await db.query("CREATE SCHEMA IF NOT EXISTS ms_b1_meta");
    await db.query("CREATE TABLE IF NOT EXISTS ms_b1_meta.schema_migration(id text PRIMARY KEY,checksum text NOT NULL CHECK(checksum ~ '^[a-f0-9]{64}$'),applied_at timestamptz NOT NULL DEFAULT clock_timestamp(),execution_ms integer NOT NULL CHECK(execution_ms>=0))");
    await db.query("REVOKE ALL ON SCHEMA ms_b1_meta FROM PUBLIC");
    const prior = (await db.query("SELECT id,checksum FROM ms_b1_meta.schema_migration ORDER BY id")).rows;
    const all = definitions();
    if (prior.some((p,i) => !all[i] || p.id !== all[i].id || p.checksum !== all[i].sha256)) throw Error("Unknown/out-of-order/changed product migration history");
    for (const m of wanted) {
      if (prior.some(p => p.id === m.id)) { result.push({ id: m.id, state: "already-applied" }); continue; }
      const start = Date.now(); await db.query(m.sql);
      await db.query("INSERT INTO ms_b1_meta.schema_migration(id,checksum,execution_ms) VALUES($1,$2,$3)",[m.id,m.sha256,Date.now()-start]);
      result.push({ id:m.id,state:"applied" });
    }
    await db.query("COMMIT"); return result;
  } catch (e) { await db.query("ROLLBACK"); throw e; }
}
if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  const test = process.argv.includes("--test"); let db, marker;
  if (test) { applyEnvironment(); db = client(); await db.connect(); await identify(db,"ms_product_test"); marker="mohammadstyle-product-test-v1"; }
  else {
    if (!["staging","production"].includes(process.env.APP_ENV ?? "")) throw Error("Explicit product migration environment required");
    const { loadProductConfig, secret } = await import("../../dist/product/config.js");
    const cfg=loadProductConfig(process.env,'migrate'),password=secret(process.env,"PRODUCT_MIGRATOR_PASSWORD");
    if (!/^[a-f0-9]{64}$/.test(password??""))throw Error("Migration secret required");
    db=new pg.Client({host:cfg.database.host,port:cfg.database.port,database:cfg.database.database,user:"ms_b1a_migrator",password,ssl:cfg.database.ssl});
    await db.connect();marker=cfg.database.marker;
  }
  try { const r=await migrate(db,marker,{throughCore:process.argv.includes("--through-core")});if(test)save("migration.json",r);console.log(JSON.stringify({migrations:r.length,applied:r.filter(x=>x.state==='applied').length})); } finally { await db.end(); }
}
