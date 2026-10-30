import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { client, identify, root } from "./local.mjs";
import { assertCatalog } from "./catalog.mjs";
import { fixtures, hash, terms } from "../b4/fixtures.mjs";
if (
  process.env.APP_ENV !== "mvp-local" ||
  process.env.NODE_ENV === "production"
)
  throw Error("Explicit isolated synthetic UI fixture environment required");
const db = client("ms_mvp_dev"),
  api = client("ms_mvp_dev", "api");
await db.connect();
await api.connect();
try {
  await identify(db, "ms_mvp_dev");
  await assertCatalog(db);
  const f = await fixtures(db);
  await db.query(
    "UPDATE ms_b1_design.availability_configuration SET hold_ttl_seconds=300,quote_ttl_seconds=300,row_version=row_version+1,configuration_version=configuration_version+1 WHERE business_id=$1",
    [f.business.id],
  );
  async function pricing(op, data, id = null) {
    const revision = (
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
          revision,
          randomUUID(),
          randomUUID(),
          data,
        ],
      )
    ).rows[0].r.body;
  }
  const p = await pricing("policy.create", {
      code: "B4_SYNTHETIC_UI",
      name: "B4 SYNTHETIC UI policy",
    }),
    v = await pricing("version.create", { terms: terms() }, p.id);
  await pricing("version.publish", {}, v.id);
  await pricing("assignment.create", {
    versionId: v.id,
    scopeKind: "BUSINESS",
    serviceId: null,
    staffId: null,
    priority: "0",
    effectiveFrom: "2026-01-01T00:00:00.000Z",
    effectiveTo: null,
    reason: null,
    serviceIds: [],
    compatibleVersionIds: [],
  });
  const optionalPolicy = await pricing("policy.create", {
      code: "B4_SYNTHETIC_UI_OPTIONAL",
      name: "B4 SYNTHETIC optional staff policy",
    }),
    optionalVersion = await pricing(
      "version.create",
      {
        terms: terms({
          depositRequirement: "OPTIONAL",
          amountKind: "FIXED",
          fixedRial: "20000",
        }),
      },
      optionalPolicy.id,
    );
  await pricing("version.publish", {}, optionalVersion.id);
  const revision = (
    await db.query(
      "SELECT revision::text v FROM ms_b1_design.pricing_configuration_revision WHERE business_id=$1",
      [f.business.id],
    )
  ).rows[0].v;
  await api.query(
    "SELECT ms_b1_design.b3_command($1,$2,$3,$4,$5,$6,$7,$8,$9)",
    [
      hash(f.owner.token),
      hash(f.owner.csrf),
      "assignment.create",
      f.branch.id,
      null,
      revision,
      randomUUID(),
      randomUUID(),
      {
        versionId: optionalVersion.id,
        scopeKind: "STAFF",
        serviceId: null,
        staffId: f.staff[1].id,
        priority: "0",
        effectiveFrom: f.day + "T00:00:00.000Z",
        effectiveTo: null,
        reason: null,
        serviceIds: [],
        compatibleVersionIds: [],
      },
    ],
  );
  await api.query("SELECT ms_b1_design.b4_command($1,$2,$3,$4,$5,$6)", [
    hash(f.owner.token),
    hash(f.owner.csrf),
    "configuration.enable",
    randomUUID(),
    randomUUID(),
    { branchId: f.branch.id, offeringIds: f.offerings.map((x) => x.id) },
  ]);
  const accounts = {
    desktop: f.customer,
    tablet: f.other,
    mobile: await f.actor("mobile-ui"),
    "mobile-small": await f.actor("small-ui"),
  };
  const file = path.join(root, ".local/mvp/booking-session.json");
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(
    file,
    JSON.stringify({
      businessId: f.business.id,
      branchId: f.branch.id,
      day: f.day,
      accounts,
      optionalStaffName: f.staff[1].display_name,
      nonPaymentStaffName: f.staff[0].display_name,
    }),
    { mode: 0o600 },
  );
  console.log(
    "Prepared isolated verified synthetic browser identities. Credentials stored only in ignored local fixture; values withheld.",
  );
} finally {
  await api.end();
  await db.end();
}
