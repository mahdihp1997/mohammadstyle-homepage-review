// Explicit trusted local test provisioning, never imported by the runtime or exposed over HTTP.
import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { client, root } from "./local.mjs";
import { fixtures, hash, terms } from "../b4/fixtures.mjs";
if (
  process.env.APP_ENV !== "mvp-local" ||
  process.env.NODE_ENV === "production"
)
  throw Error("Explicit isolated fixture required");
export const permissions = [
  "business.read",
  "branch.read",
  "branch.manage",
  "catalog.read",
  "catalog.manage",
  "offering.read",
  "offering.manage",
  "staff.read",
  "staff.manage",
  "staff.link",
  "staff.qualify",
  "staff.history.read",
  "schedule.read",
  "schedule.history.read",
  "schedule.manage",
  "schedule.publish",
  "resource.manage",
  "branchhours.manage",
  "timeoff.approve",
  "policy.read",
  "policy.manage",
  "policy.override",
  "policy.history.read",
  "pricing.quote",
  "booking.read",
  "booking.manage",
  "media.manage",
  "media.rights.manage",
  "media.publish",
];
export async function createFixture(db) {
  const f = await fixtures(db);
  await db.query("UPDATE ms_b1_design.business SET brand_name=$1 WHERE id=$2", [
    "MVP SYNTHETIC — اطلاعات واقعی سالن نیست",
    f.business.id,
  ]);
  await db.query("UPDATE ms_b1_design.branch SET display_name=$1 WHERE id=$2", [
    "شعبه آزمایشی یکپارچه",
    f.branch.id,
  ]);
  async function grant(actor, keys, branch = null) {
    const role = (
      await db.query(
        "SELECT role_id FROM ms_b1_design.user_role_assignment WHERE business_id=$1 AND user_id=$2",
        [f.business.id, actor.userId],
      )
    ).rows[0].role_id;
    if (branch)
      await db.query(
        "UPDATE ms_b1_design.user_role_assignment SET branch_id=$1 WHERE role_id=$2",
        [branch, role],
      );
    for (const key of keys) {
      let p = (
        await db.query(
          "SELECT id FROM ms_b1_design.permission WHERE permission_key=$1",
          [key],
        )
      ).rows[0];
      p ??= await f.insert("permission", {
        permission_key: key,
        description: "MVP SYNTHETIC test permission",
      });
      await db.query(
        "INSERT INTO ms_b1_design.role_permission(business_id,role_id,permission_id) VALUES($1,$2,$3) ON CONFLICT DO NOTHING",
        [f.business.id, role, p.id],
      );
    }
  }
  await grant(f.owner, permissions);
  const mediaEditor = await f.actor("media editor");
  await grant(mediaEditor, ["media.manage"]);
  const scoped = await f.actor("branch scoped");
  await grant(scoped, ["media.manage", "booking.read"], f.branch.id);
  const accounts = { owner: f.owner, editor: mediaEditor, scoped };
  for (const viewport of ["desktop", "tablet", "mobile", "mobile-small"]) {
    accounts[viewport] = await f.actor("MVP " + viewport);
    // Independent verified browser administrators keep viewport runs isolated
    // without raising or disabling the approved per-session request limits.
    const admin = await f.actor("MVP administrator " + viewport);
    await grant(admin, [...permissions, "booking.configure"]);
    accounts["owner-" + viewport] = admin;
  }
  const api = client("ms_mvp_dev", "api");
  await api.connect();
  try {
    const command = async (op, d, id = null) => {
      const rev = (
        await db.query(
          "SELECT revision::text v FROM ms_b1_design.pricing_configuration_revision WHERE business_id=$1",
          [f.business.id],
        )
      ).rows[0].v;
      return (
        await api.query(
          "SELECT ms_b1_design.b3_command($1,$2,$3,$4,$5,$6,$7,$8,$9) r",
          [
            hash(f.owner.token),
            hash(f.owner.csrf),
            op,
            null,
            id,
            rev,
            randomUUID(),
            randomUUID(),
            d,
          ],
        )
      ).rows[0].r.body;
    };
    const p = await command("policy.create", {
        code: "MVP_SYNTHETIC",
        name: "سیاست آزمایشی یکپارچه؛ واقعی نیست",
      }),
      v = await command(
        "version.create",
        {
          terms: terms({
            termsText:
              "MVP SYNTHETIC — شرایط آزمایشی؛ تعرفه و سیاست تجاری سالن نیست.",
          }),
        },
        p.id,
      );
    await command("version.publish", {}, v.id);
    await command("assignment.create", {
      versionId: v.id,
      scopeKind: "BUSINESS",
      serviceId: null,
      staffId: null,
      priority: "0",
      effectiveFrom: f.day + "T00:00:00.000Z",
      effectiveTo: null,
      reason: null,
      serviceIds: [],
      compatibleVersionIds: [],
    });
    await db.query(
      "UPDATE ms_b1_design.availability_configuration SET quote_ttl_seconds=180,hold_ttl_seconds=180,row_version=row_version+1,configuration_version=configuration_version+1 WHERE business_id=$1",
      [f.business.id],
    );
    await api.query("SELECT ms_b1_design.b4_command($1,$2,$3,$4,$5,$6)", [
      hash(f.owner.token),
      hash(f.owner.csrf),
      "configuration.enable",
      randomUUID(),
      randomUUID(),
      { branchId: f.branch.id, offeringIds: f.offerings.map((o) => o.id) },
    ]);
  } finally {
    await api.end();
  }
  return { ...f, accounts, grant };
}
if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.join(root, "scripts/mvp/fixture.mjs")
) {
  const db = client("ms_mvp_dev");
  try {
    await db.connect();
    const f = await createFixture(db);
    fs.mkdirSync(path.join(root, ".local/mvp"), { recursive: true });
    fs.writeFileSync(
      path.join(root, ".local/mvp/review-session.json"),
      JSON.stringify(
        {
          businessId: f.business.id,
          branchId: f.branch.id,
          secondBranchId: f.secondBranch.id,
          day: f.day,
          staff: f.staff.map((s) => ({ id: s.id, name: s.display_name })),
          offeringIds: f.offerings.map((o) => o.id),
          accounts: f.accounts,
        },
        null,
        2,
      ),
      { mode: 0o600 },
    );
    fs.writeFileSync(
      path.join(root, ".local/mvp/public-tenant.json"),
      JSON.stringify({ businessId: f.business.id }),
    );
    console.log(
      "Created isolated synthetic review tenant and verified sessions; credentials withheld. No salon configuration or media imported.",
    );
  } finally {
    await db.end();
  }
}
