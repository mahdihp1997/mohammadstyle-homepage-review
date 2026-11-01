import fs from "node:fs";
import path from "node:path";
import { randomBytes, randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { root, folder, environmentFile, docker, readEnvironment, client, databases, marker } from "./local.mjs";
if (process.env.NODE_ENV === "production" || ![undefined, "product-test"].includes(process.env.APP_ENV)) throw Error("Isolated product infrastructure only");
const op = process.argv[2];
if (op === "env") {
  fs.mkdirSync(folder, { recursive: true });
  if (fs.existsSync(environmentFile)) { readEnvironment(); console.log("Existing isolated product secrets preserved"); }
  else {
    const values = { APP_ENV: "product-test", PGHOST: "127.0.0.1", PGPORT: "55460", PGDATABASE: "ms_product_test", PUBLIC_ORIGIN: "http://127.0.0.1:3006", PRODUCT_API_PORT: "3116",
      PRODUCT_BUSINESS_ID: randomUUID(), PRODUCT_MEDIA_ROOT: path.join(folder, "media"), SMS_PROVIDER: "mock", PAYMENT_PROVIDER: "mock", MOCK_GATEWAY_ORIGIN: "http://127.0.0.1:3117" };
    for (const role of ["ADMIN", "MIGRATOR", "RUNTIME", "API", "AUTH", "WORKER"]) values["PRODUCT_" + role + "_PASSWORD"] = randomBytes(32).toString("hex");
    for (const key of ["BRIDGE", "ENCRYPTION", "IDENTITY", "OTP"]) values["PRODUCT_" + key + "_KEY"] = randomBytes(32).toString("base64url");
    fs.writeFileSync(environmentFile, Object.entries(values).map(([k, v]) => k + "=" + v).join("\n") + "\n", { mode: 0o600 });
    console.log("Created ignored isolated product secrets; values withheld");
  }
} else if (op === "up" || op === "stop") {
  readEnvironment();
  const result = spawnSync(docker, ["compose", "--env-file", environmentFile, "-f", path.join(root, "compose.product-test.yml"), "-p", "mohammadstyle-product-test", ...(op === "up" ? ["up", "-d", "--wait"] : ["stop"])], { cwd: root, stdio: "inherit", windowsHide: true });
  if (result.status !== 0) throw Error("Product test container operation failed");
} else if (op === "db") {
  const values = readEnvironment(), admin = client("ms_product_control", "admin");
  try {
    await admin.connect();
    const roles = { ms_b1a_migrator: "MIGRATOR", ms_b1a_runtime: "RUNTIME", ms_b1b_api: "API", ms_product_auth: "AUTH", ms_product_worker: "WORKER" };
    for (const [role, key] of Object.entries(roles)) {
      if (!(await admin.query("SELECT 1 FROM pg_roles WHERE rolname=$1", [role])).rowCount) await admin.query(`CREATE ROLE ${role} NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS`);
      await admin.query(`ALTER ROLE ${role} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD '${values["PRODUCT_" + key + "_PASSWORD"]}'`);
    }
    for (const database of databases) {
      const prior = (await admin.query("SELECT shobj_description(oid,'pg_database') marker FROM pg_database WHERE datname=$1", [database])).rows[0];
      if (prior && prior.marker !== marker) throw Error("Refusing to adopt unmarked database");
      if (!prior) { await admin.query(`CREATE DATABASE "${database}" OWNER ms_b1a_migrator`); await admin.query(`COMMENT ON DATABASE "${database}" IS '${marker}'`); }
      console.log("Preserved/created owned product test DB: " + database);
    }
  } finally { await admin.end(); }
} else throw Error("Use env, up, db or stop; no implicit reset/delete");
