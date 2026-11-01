// Explicit offline opt-in. Never imported by an HTTP runtime.
import fs from "node:fs";
import path from "node:path";
import { randomBytes } from "node:crypto";
import { client, identify, root } from "./local.mjs";
import { passwordKey, validateLocalLoginOptions } from "../../dist/mvp/local-login.js";

if (process.env.APP_ENV !== "mvp-local" || process.env.NODE_ENV === "production") throw Error("Explicit local review environment required");
const dir = path.join(root, ".local/mvp"), file = path.join(dir, "manual-login.json");
const fixture = JSON.parse(fs.readFileSync(path.join(dir, "review-session.json"), "utf8"));
const existing = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : null;
const password = existing ? null : randomBytes(18).toString("base64url");
const salt = existing?.salt ?? randomBytes(32).toString("hex");
const config = existing ?? { version: 1, username: "owner", salt,
  passwordHash: (await passwordKey(password, salt)).toString("hex"), bridgeSecret: randomBytes(32).toString("base64url"),
  databasePassword: randomBytes(32).toString("hex"), userId: fixture.accounts.owner.userId, businessId: fixture.businessId };
validateLocalLoginOptions(config);
if (config.userId !== fixture.accounts.owner.userId || config.businessId !== fixture.businessId)
  throw Error("Existing local login belongs to a different synthetic fixture; refusing to replace it");
const db = client("ms_mvp_dev"), admin = client("ms_mvp_dev", "admin");
try {
  await db.connect(); await identify(db, "ms_mvp_dev");
  const proof = await db.query(`SELECT 1 FROM ms_b1_design.app_user u JOIN ms_b1_design.auth_identity i ON i.user_id=u.id
    JOIN ms_b1_design.business b ON b.id=$2 WHERE u.id=$1 AND u.status='ACTIVE' AND u.archived_at IS NULL
    AND u.display_name LIKE 'B4 SYNTHETIC %' AND i.provider='B4_ISOLATED_TEST' AND i.verified_at IS NOT NULL
    AND b.slug LIKE 'b4-synthetic-%' AND b.archived_at IS NULL
    AND ms_b1_design.b1b_can(jsonb_build_object('userId',u.id,'businessId',b.id),'branch.manage',NULL)`,
    [config.userId, config.businessId]);
  if (!proof.rowCount) throw Error("Existing verified synthetic administrator required");
  await admin.connect(); await identify(admin, "ms_mvp_dev", "admin");
  if (!(await admin.query("SELECT 1 FROM pg_roles WHERE rolname='ms_mvp_local_login'")).rowCount)
    await admin.query("CREATE ROLE ms_mvp_local_login NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS");
  // Password is generated/validated lowercase hex, never browser input or shell interpolation.
  await admin.query(`ALTER ROLE ms_mvp_local_login LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 4 PASSWORD '${config.databasePassword}'`);
  await admin.query("GRANT CONNECT ON DATABASE ms_mvp_dev TO ms_mvp_local_login");
  await db.query("BEGIN");
  await db.query(fs.readFileSync(path.join(root, "local/mvp/manual-login.sql"), "utf8"));
  await db.query("COMMIT");
  fs.writeFileSync(file, JSON.stringify(config, null, 2), { mode: 0o600 });
  fs.writeFileSync(path.join(dir, "login-bridge.json"), JSON.stringify({ version: 1, secret: config.bridgeSecret }), { mode: 0o600 });
  if (password) fs.writeFileSync(path.join(dir, "owner-login.txt"), `Local development only\nURL: http://127.0.0.1:3000/admin/login\nUsername: ${config.username}\nPassword: ${password}\n`, { mode: 0o600 });
  console.log("Configured manual local review login for the EXISTING verified synthetic administrator. Credentials preserved in ignored backend/.local/mvp/owner-login.txt; values withheld. Restart the local API.");
} finally { await db.end(); await admin.end(); }
