import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { PrismaPg } from '@prisma/adapter-pg';
import { root, localEnv, client, save } from './local.mjs';
const require = createRequire(import.meta.url), local = localEnv();
const connectionString = `postgresql://ms_b0_admin:${local.B0_ADMIN_PASSWORD}@${local.PGHOST}:${local.PGPORT}/ms_b0_full_test`;
const env = { ...process.env, DATABASE_URL: connectionString, CHECKPOINT_DISABLE: '1', PRISMA_HIDE_UPDATE_MESSAGE: '1' };
const result = { executedAt: new Date().toISOString(), version: require('prisma/package.json').version, database: 'ms_b0_full_test', commands: [], assertions: [] };
function cli(args) {
  const run = spawnSync(process.execPath, [path.join(root, 'node_modules/prisma/build/index.js'), ...args], { cwd: root, env, encoding: 'utf8', timeout: 90000 });
  const stdout = (run.stdout ?? '').replaceAll(local.B0_ADMIN_PASSWORD, '[REDACTED]');
  const stderr = (run.stderr ?? '').replaceAll(local.B0_ADMIN_PASSWORD, '[REDACTED]');
  result.commands.push({ command: `prisma ${args.join(' ')}`, status: run.status, stdout: args.includes('--print') ? '[full introspection saved locally, warnings below]' : stdout, stderr });
  assert.equal(run.status, 0, `Prisma command failed: ${stderr.slice(-1500)}`); return stdout;
}
const db = client('ms_b0_full_test'); let prisma;
try {
  await db.connect();
  const catalog = async () => ({
    constraints: (await db.query("SELECT pg_get_constraintdef(c.oid) AS definition, conname FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname='ms_design' ORDER BY conname")).rows,
    indexes: (await db.query("SELECT indexname,indexdef FROM pg_indexes WHERE schemaname='ms_design' ORDER BY indexname")).rows,
    generated: (await db.query("SELECT table_name,column_name,generation_expression FROM information_schema.columns WHERE table_schema='ms_design' AND is_generated='ALWAYS' ORDER BY table_name,column_name")).rows
  });
  const before = await catalog();
  cli(['validate']); cli(['generate']);
  const introspected = cli(['db','pull','--print']);
  fs.writeFileSync(path.join(root,'prisma/introspected.prisma'), introspected);
  assert.match(introspected,/Unsupported\("daterange"\)/); assert.match(introspected,/Unsupported\("tstzrange"\)/);
  result.assertions.push('Real 72-table introspection returns Unsupported daterange/tstzrange fields');
  assert.equal((introspected.match(/^model /gm) ?? []).length,72);
  assert.match(introspected,/@@unique\([^\n]+where: raw\(/); assert.match(introspected,/@@index\([^\n]+where: raw\(/);
  result.assertions.push('Selected Prisma release actually introspects partial unique and non-unique indexes with where: raw');
  assert.match(introspected,/scope_key\s+String\?\s+@default\(dbgenerated/);
  result.assertions.push('Generated scope_key appears as optional dbgenerated default; PSL alone does not preserve GENERATED ALWAYS STORED semantics');
  const { PrismaClient } = require('../prisma/generated');
  prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString }) });
  const count = await prisma.businessProbe.count(); assert.ok(count >= 2);
  result.assertions.push(`Generated Prisma client ordinary model read: ${count} synthetic businesses`);
  const isolation = await prisma.$transaction(async tx => (await tx.$queryRawUnsafe('SHOW transaction_isolation'))[0].transaction_isolation, { isolationLevel: 'Serializable' });
  assert.equal(isolation,'serializable'); result.assertions.push('Interactive transaction actually reports serializable');
  const range = await prisma.$queryRaw`SELECT daterange('2030-01-01','2030-02-01','[)')::text AS value`;
  assert.equal(range[0].value,'[2030-01-01,2030-02-01)'); result.assertions.push('Parameterized native range SQL with text projection works');
  await assert.rejects(prisma.$transaction(async tx => { await tx.$queryRaw`SELECT 1`; throw new Error('B0 deliberate rollback'); }), /B0 deliberate rollback/);
  assert.deepEqual(await catalog(), before); result.assertions.push('Validate/generate/introspect/read/transaction leave constraints, indexes and generated expressions unchanged');
  result.status='PASS';
} catch(error) { result.status='FAIL'; result.error=error.message.replaceAll(local.B0_ADMIN_PASSWORD,'[REDACTED]'); process.exitCode=1; }
finally { if(prisma) await prisma.$disconnect(); await db.end(); save('prisma-results.json',result); console.log(JSON.stringify({status:result.status,version:result.version,commands:result.commands.map(c=>({command:c.command,status:c.status})),assertions:result.assertions,error:result.error})); }
