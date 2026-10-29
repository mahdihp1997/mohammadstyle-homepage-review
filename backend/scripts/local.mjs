import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const evidence = path.join(root, '.local', 'results');
export function localEnv() {
  const env = Object.fromEntries(fs.readFileSync(path.join(root, '.env.local'), 'utf8').split(/\r?\n/)
    .filter(line => line && !line.startsWith('#')).map(line => { const i = line.indexOf('='); return [line.slice(0, i), line.slice(i + 1)]; }));
  if (env.PGHOST !== '127.0.0.1' || env.PGPORT !== '55432' || env.PGDATABASE !== 'ms_b0_control'
      || !/^[a-f0-9]{64}$/.test(env.B0_ADMIN_PASSWORD ?? '') || !/^[a-f0-9]{64}$/.test(env.B0_PROBE_PASSWORD ?? ''))
    throw new Error('Refusing non-isolated B0 environment');
  return env;
}
export function client(database = 'ms_b0_control', probe = false) {
  if (!['ms_b0_control', 'ms_b0_b1_test', 'ms_b0_full_test'].includes(database)) throw new Error('Database outside B0 allowlist');
  const env = localEnv();
  const pg = require('pg');
  return new pg.Client({ host: env.PGHOST, port: +env.PGPORT, database,
    user: probe ? 'ms_b0_probe' : 'ms_b0_admin', password: probe ? env.B0_PROBE_PASSWORD : env.B0_ADMIN_PASSWORD,
    application_name: 'mohammadstyle-b0-validation', connectionTimeoutMillis: 3000, statement_timeout: 15000 });
}
export function save(name, value) {
  fs.mkdirSync(evidence, { recursive: true });
  fs.writeFileSync(path.join(evidence, name), JSON.stringify(value, null, 2) + '\n');
}
