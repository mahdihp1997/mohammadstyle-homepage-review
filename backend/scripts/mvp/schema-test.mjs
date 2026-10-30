import assert from "node:assert/strict";
import { client, save, identify } from "./local.mjs";
import { provision } from "./infra.mjs";
import { migrate, loadMigrations } from "./migrate.mjs";
import { catalog, assertCatalog, fingerprint } from "./catalog.mjs";
import { fixtures } from "../b4/fixtures.mjs";
if (
  process.env.APP_ENV !== "mvp-local" ||
  process.env.NODE_ENV === "production"
)
  throw Error("Isolated schema test required");
const tests = [];
let db;
async function test(name, fn) {
  try {
    await fn();
    tests.push({ name, status: "PASS" });
  } catch (e) {
    tests.push({
      name,
      status: "FAIL",
      code: e.code ?? null,
      error: e.message,
    });
  }
}
try {
  await provision("ms_mvp_failure", true);
  db = client("ms_mvp_failure");
  await db.connect();
  await identify(db, "ms_mvp_failure");
  const definitions = loadMigrations();
  await migrate(db, "ms_mvp_failure", {
    definitions: definitions.slice(0, 14),
    verifyCatalog: false,
  });
  await fixtures(db);
  const before = new Map();
  for (const t of (await catalog(db)).tables) {
    const rows = (
      await db.query(
        `SELECT to_jsonb(t)::text v FROM ms_b1_design."${t.name}" t ORDER BY v`,
      )
    ).rows;
    before.set(t.name, fingerprint(rows));
  }
  await test("actual fourteen-to-fifteen upgrade preserves all existing synthetic B4 table rows", async () => {
    const r = await migrate(db, "ms_mvp_failure");
    assert.deepEqual(r.applied, ["0015_mvp_admin_media"]);
    for (const [t, digest] of before) {
      const rows = (
        await db.query(
          `SELECT (to_jsonb(t)${t === "booking_status_history" ? "-'operator_reason'" : ""})::text v FROM ms_b1_design."${t}" t ORDER BY v`,
        )
      ).rows;
      assert.equal(fingerprint(rows), digest, t);
    }
    assert.equal((await assertCatalog(db)).tables, 55);
  });
  await test("second migration run is a no-op with a verified native catalog", async () =>
    assert.deepEqual((await migrate(db, "ms_mvp_failure")).applied, []));
  await test("runtime and public roles receive neither table access nor helper execution", async () => {
    const c = await catalog(db);
    assert.equal(c.apiMemberships.length, 0);
    assert.ok(c.functionSecurity.every((x) => x.grantee !== "PUBLIC"));
    const api = client("ms_mvp_failure", "api");
    await api.connect();
    try {
      await assert.rejects(
        api.query("SELECT * FROM ms_b1_design.media_asset"),
        (e) => e.code === "42501",
      );
      await assert.rejects(
        api.query(
          "SELECT ms_b1_design.mvp_rights_current(gen_random_uuid(),gen_random_uuid())",
        ),
        (e) => e.code === "42501",
      );
    } finally {
      await api.end();
    }
  });
  await test("failed forward DDL and migration metadata roll back together", async () => {
    await assert.rejects(
      migrate(db, "ms_mvp_failure", {
        definitions: [
          ...definitions,
          {
            id: "0016_synthetic_failure",
            sha256: "a".repeat(64),
            sql: "CREATE TABLE ms_b1_design.synthetic_mvp_rollback(id int);SELECT 1/0;",
          },
        ],
        verifyCatalog: false,
      }),
      (e) => e.code === "22012",
    );
    assert.equal(
      (
        await db.query(
          "SELECT to_regclass('ms_b1_design.synthetic_mvp_rollback') t",
        )
      ).rows[0].t,
      null,
    );
    assert.equal(
      (
        await db.query(
          "SELECT count(*)::int n FROM ms_b1_meta.schema_migration",
        )
      ).rows[0].n,
      15,
    );
  });
  await test("catalog drift is detected and rolled back without automatic repair", async () => {
    await db.query("BEGIN");
    try {
      await db.query(
        "CREATE INDEX synthetic_mvp_drift ON ms_b1_design.media_asset(title)",
      );
      await assert.rejects(assertCatalog(db), (e) => e.code === "MVP_DRIFT");
    } finally {
      await db.query("ROLLBACK");
    }
    await assertCatalog(db);
  });
} catch (e) {
  tests.push({
    name: "schema test setup",
    status: "FAIL",
    code: e.code ?? null,
    error: e.message,
  });
} finally {
  if (db) await db.end();
}
const result = {
  kind: "ACTUAL_POSTGRES18_MVP_UPGRADE_AND_BOUNDARY",
  tests,
  summary: {
    passed: tests.filter((x) => x.status === "PASS").length,
    failed: tests.filter((x) => x.status === "FAIL").length,
  },
};
save("schema.json", result);
console.log(JSON.stringify(result));
if (result.summary.failed) process.exitCode = 1;
