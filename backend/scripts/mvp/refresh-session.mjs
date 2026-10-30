import fs from "node:fs";
import path from "node:path";
import { randomBytes, createHash } from "node:crypto";
import { client, identify, root } from "./local.mjs";
// Same offline rotation pattern as B1B. Existing verified SYNTHETIC identities only, no HTTP entry point.
if (
  process.env.APP_ENV !== "mvp-local" ||
  process.env.NODE_ENV === "production"
)
  throw Error("Explicit isolated rotation required");
const file = path.join(root, ".local/mvp/review-session.json"),
  fixture = JSON.parse(fs.readFileSync(file)),
  db = client("ms_mvp_dev"),
  hash = (x) => createHash("sha256").update(x, "ascii").digest();
try {
  await db.connect();
  await identify(db, "ms_mvp_dev");
  await db.query("BEGIN");
  for (const account of Object.values(fixture.accounts)) {
    const r = await db.query(
      "SELECT u.id FROM ms_b1_design.app_user u JOIN ms_b1_design.auth_identity i ON i.user_id=u.id JOIN ms_b1_design.business b ON b.id=$2 WHERE u.id=$1 AND u.status='ACTIVE' AND u.archived_at IS NULL AND u.display_name LIKE 'B4 SYNTHETIC %' AND i.provider='B4_ISOLATED_TEST' AND i.verified_at IS NOT NULL AND b.slug LIKE 'b4-synthetic-%' FOR UPDATE OF u",
      [account.userId, fixture.businessId],
    );
    if (
      !r.rowCount ||
      !(
        await db.query(
          "SELECT 1 FROM ms_b1_design.user_role_assignment WHERE user_id=$1 AND business_id=$2 AND revoked_at IS NULL AND archived_at IS NULL",
          [account.userId, fixture.businessId],
        )
      ).rowCount
    )
      throw Error("Existing verified synthetic membership required");
    await db.query(
      "UPDATE ms_b1_design.auth_session SET revoked_at=clock_timestamp(),row_version=row_version+1 WHERE user_id=$1 AND business_id=$2 AND revoked_at IS NULL",
      [account.userId, fixture.businessId],
    );
    const token = randomBytes(32).toString("base64url"),
      csrf = randomBytes(32).toString("base64url");
    await db.query(
      "INSERT INTO ms_b1_design.auth_session(user_id,business_id,token_hash,csrf_hash,expires_at,idle_expires_at) VALUES($1,$2,$3,$4,clock_timestamp()+interval '1 hour',clock_timestamp()+interval '15 minutes')",
      [account.userId, fixture.businessId, hash(token), hash(csrf)],
    );
    account.token = token;
    account.csrf = csrf;
  }
  await db.query("COMMIT");
  fs.writeFileSync(file, JSON.stringify(fixture, null, 2), { mode: 0o600 });
  console.log(
    "Rotated only verified synthetic local sessions; old sessions revoked, secrets withheld.",
  );
} catch (e) {
  await db.query("ROLLBACK");
  throw e;
} finally {
  await db.end();
}
