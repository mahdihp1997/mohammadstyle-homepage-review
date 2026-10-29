import fs from 'node:fs';
import path from 'node:path';
import { randomBytes } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { root, localEnv, client } from './local.mjs';
const command = process.argv[2];
const docker = process.env.DOCKER_BIN || (process.platform === 'win32' ? 'C:\\Program Files\\Docker\\Docker\\resources\\bin\\docker.exe' : 'docker');
const args = ['compose', '--project-name', 'mohammadstyle-b0', '--file', path.join(root, 'compose.yaml'), '--env-file', path.join(root, '.env.local')];
function run(extra, capture = false) {
  const result = spawnSync(docker, [...args, ...extra], { cwd: root, encoding: 'utf8', stdio: capture ? 'pipe' : 'inherit' });
  if (result.status !== 0) throw new Error('B0 compose command failed');
  return result.stdout;
}
if (command === 'env') {
  const target = path.join(root, '.env.local');
  if (fs.existsSync(target)) { localEnv(); console.log('Existing isolated B0 environment preserved'); }
  else {
    const admin = randomBytes(32).toString('hex'), probe = randomBytes(32).toString('hex');
    fs.writeFileSync(target, `B0_ADMIN_PASSWORD=${admin}\nB0_PROBE_PASSWORD=${probe}\nPGHOST=127.0.0.1\nPGPORT=55432\nPGDATABASE=ms_b0_control\nPGUSER=ms_b0_probe\nPGPASSWORD=${probe}\nAPI_HOST=127.0.0.1\nAPI_PORT=3100\nAPP_ENV=b0-local\n`, { mode: 0o600, flag: 'wx' });
    console.log('Created ignored local random credentials; values withheld');
  }
} else if (command === 'up' || command === 'db') {
  const env = localEnv();
  run(['up', '-d', '--wait', 'postgres']);
  const db = client(); await db.connect();
  try {
    await db.query('REVOKE CREATE ON SCHEMA public FROM PUBLIC');
    const role = await db.query("SELECT 1 FROM pg_roles WHERE rolname='ms_b0_probe'");
    if (!role.rowCount) await db.query(`CREATE ROLE ms_b0_probe LOGIN PASSWORD '${env.B0_PROBE_PASSWORD}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION`);
    await db.query('REVOKE ALL ON DATABASE ms_b0_control FROM PUBLIC');
    await db.query('GRANT CONNECT ON DATABASE ms_b0_control TO ms_b0_probe');
    await db.query("COMMENT ON DATABASE ms_b0_control IS 'mohammadstyle-b0-disposable-control'");
  } finally { await db.end(); }
  if (command === 'up') run(['up', '-d', '--build', '--wait', 'api']);
} else if (command === 'stop') {
  localEnv(); run(['down']); // preserves only this project's named volume
} else if (command === 'reset') {
  localEnv();
  // Never run a global prune or infer a volume name from user input.
  const name = 'mohammadstyle-b0_b0_pgdata';
  const inspected = spawnSync(docker, ['volume', 'inspect', name], { encoding: 'utf8' });
  if (inspected.status !== 0) throw new Error('Expected B0 volume missing; refusing reset');
  const volume = JSON.parse(inspected.stdout)[0];
  if (volume.Name !== name || volume.Labels?.['com.docker.compose.project'] !== 'mohammadstyle-b0'
    || volume.Labels?.['com.mohammadstyle.purpose'] !== 'phase03b-b0-disposable') throw new Error('B0 volume identity/labels do not match');
  run(['down', '--volumes']);
  console.log('Reset only verified mohammadstyle-b0 project volume; environment credentials preserved');
} else throw new Error('Use env, db, up, stop or reset');
