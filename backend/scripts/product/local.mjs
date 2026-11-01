import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";
export const root = fileURLToPath(new URL("../../", import.meta.url));
export const folder = path.join(root, ".local/product");
export const environmentFile = process.env.PRODUCT_TEST_ENV_FILE ? path.resolve(process.env.PRODUCT_TEST_ENV_FILE) : path.join(root, ".env.product-test.local");
export const databases = ["ms_product_test", "ms_product_restore", "ms_product_failure"];
export const marker = "mohammadstyle-product-test-v1";
export const docker = process.env.DOCKER_BIN || (process.platform === "win32" ? "C:/Program Files/Docker/Docker/resources/bin/docker.exe" : "docker");
export function readEnvironment() {
  const values = Object.fromEntries(fs.readFileSync(environmentFile, "utf8").split(/\r?\n/).filter(Boolean).map(line => {
    const i = line.indexOf("="); if (i < 1) throw Error("Invalid isolated environment file"); return [line.slice(0, i), line.slice(i + 1)];
  }));
  for (const key of ["PRODUCT_ADMIN_PASSWORD", "PRODUCT_MIGRATOR_PASSWORD", "PRODUCT_RUNTIME_PASSWORD", "PRODUCT_API_PASSWORD", "PRODUCT_AUTH_PASSWORD", "PRODUCT_WORKER_PASSWORD"])
    if (!/^[a-f0-9]{64}$/.test(values[key] ?? "")) throw Error("Missing isolated product secret: " + key);
  if (values.APP_ENV !== "product-test" || values.PGHOST !== "127.0.0.1" || values.PGPORT !== (values.PRODUCT_TEST_PROFILE === "manual" ? "55461" : "55460")) throw Error("Isolated product profile mismatch");
  return values;
}
export function applyEnvironment() { Object.assign(process.env, readEnvironment()); if (process.env.NODE_ENV === "production") throw Error("Test tools cannot run in production"); }
export function connection(database, role = "migrator") {
  if (!databases.includes(database) && !(database === "ms_product_control" && role === "admin")) throw Error("Product test DB allowlist");
  const names = { admin: "ms_b1a_admin", migrator: "ms_b1a_migrator", runtime: "ms_b1a_runtime", api: "ms_b1b_api", auth: "ms_product_auth", worker: "ms_product_worker" };
  if (!names[role]) throw Error("Product test role allowlist");
  return { host: "127.0.0.1", port: Number(readEnvironment().PGPORT), database, user: names[role], password: readEnvironment()["PRODUCT_" + role.toUpperCase() + "_PASSWORD"],
    connectionTimeoutMillis: 5000, statement_timeout: 60000, application_name: "mohammadstyle-product-validation" };
}
export const client = (database = "ms_product_test", role = "migrator") => new pg.Client(connection(database, role));
export async function identify(db, database, role = "migrator") {
  const r = (await db.query("SELECT current_database() db,current_user role,current_setting('server_version_num')::int version,shobj_description((SELECT oid FROM pg_database WHERE datname=current_database()),'pg_database') marker")).rows[0];
  if (r.db !== database || r.role !== connection(database, role).user || r.version < 180000 || r.version >= 190000 || r.marker !== marker)
    throw Error("Product test database identity mismatch");
  return r;
}
export function save(name, value) { fs.mkdirSync(path.join(folder, "results"), { recursive: true }); fs.writeFileSync(path.join(folder, "results", name), JSON.stringify(value, null, 2) + "\n"); }

export function testProject(){return readEnvironment().PRODUCT_TEST_PROFILE==='manual'?'mohammadstyle-manual-test':'mohammadstyle-product-test';}
