import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { setTimeout as delay } from 'node:timers/promises';
import { root, localEnv, client } from '../scripts/local.mjs';

test('real least-privilege database connection and denied DDL', async () => {
  const db = client('ms_b0_control', true); await db.connect();
  try {
    assert.equal((await db.query('SELECT current_user AS name')).rows[0].name, 'ms_b0_probe');
    await assert.rejects(db.query('CREATE TABLE public.must_not_exist(id int)'), { code: '42501' });
  } finally { await db.end(); }
});

async function server(env, run) {
  const child = spawn(process.execPath, ['dist/main.js'], { cwd: root, env: { ...process.env, ...env, API_PORT: '3101' }, stdio: ['ignore', 'pipe', 'pipe'] });
  let logs = ''; child.stdout.on('data', b => { logs += b; }); child.stderr.on('data', b => { logs += b; });
  try {
    let live;
    for (let i = 0; i < 80; i++) {
      if (child.exitCode !== null) throw new Error('Backend exited before liveness');
      try { live = await fetch('http://127.0.0.1:3101/health/live'); if (live.ok) break; } catch {}
      await delay(100);
    }
    assert.equal(live?.status, 200);
    await run(logs);
  } finally {
    child.kill('SIGTERM'); await once(child, 'exit');
    assert.ok(!logs.includes(env.PGPASSWORD), 'logs must omit database secret');
    assert.ok(!logs.includes('must-not-log'), 'query strings must not appear in logs');
    for (const line of logs.trim().split('\n').filter(Boolean)) assert.doesNotThrow(() => JSON.parse(line));
  }
}
test('backend startup, readiness, request identity, safe centralized 404', async () => {
  await server(localEnv(), async () => {
    const response = await fetch('http://127.0.0.1:3101/health/ready');
    assert.equal(response.status, 200); assert.deepEqual(await response.json(), { status: 'ready' });
    assert.match(response.headers.get('x-request-id'), /^[a-f0-9-]{36}$/);
    const missing = await fetch('http://127.0.0.1:3101/no-controller?secret=must-not-log');
    assert.equal(missing.status, 404); assert.equal((await missing.json()).code, 'NOT_FOUND');
  });
});
test('database outage leaves liveness up and readiness fails closed', async () => {
  await server({ ...localEnv(), PGPORT: '55433' }, async () => {
    const response = await fetch('http://127.0.0.1:3101/health/ready');
    assert.equal(response.status, 503); const body = await response.json();
    assert.equal(body.code, 'DATABASE_NOT_READY'); assert.deepEqual(Object.keys(body).sort(), ['code', 'requestId', 'statusCode']);
  });
});
test('invalid startup configuration exits nonzero without logging secrets', async () => {
  const env = { ...localEnv(), APP_ENV: 'production' };
  const child = spawn(process.execPath, ['dist/main.js'], { cwd: root, env: { ...process.env, ...env }, stdio: ['ignore','pipe','pipe'] });
  let logs=''; child.stdout.on('data', b=>{logs+=b;}); child.stderr.on('data', b=>{logs+=b;});
  const [code] = await once(child,'exit'); assert.equal(code,1); assert.ok(logs.includes('b0.start_failed'));
  assert.ok(!logs.includes(env.PGPASSWORD));
});
