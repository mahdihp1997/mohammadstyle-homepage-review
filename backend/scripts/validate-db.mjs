import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { randomUUID, createHash } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import { root, client, save } from './local.mjs';

const report = { executedAt: new Date().toISOString(), kind: 'ACTUAL_POSTGRESQL_EXECUTION', schemas: [], tests: [], sqlErrors: [] };
const quote = value => `"${value.replaceAll('"','""')}"`;
// These drafts contain no stored procedure bodies. Respect SQL strings/comments when splitting.
function statements(sql) {
  const result = []; let start = 0, single = false, line = false, block = false;
  for (let i = 0; i < sql.length; i++) {
    const c = sql[i], n = sql[i+1];
    if (line) { if (c === '\n') line = false; continue; }
    if (block) { if (c === '*' && n === '/') { block = false; i++; } continue; }
    if (!single && c === '-' && n === '-') { line = true; i++; continue; }
    if (!single && c === '/' && n === '*') { block = true; i++; continue; }
    if (c === "'") { if (single && n === "'") { i++; continue; } single = !single; }
    if (c === ';' && !single) { result.push(sql.slice(start, i+1).trim()); start = i+1; }
  }
  if (sql.slice(start).replace(/--[^\n]*/g, '').trim()) throw new Error('Unterminated SQL statement');
  return result;
}
async function check(name, fn) {
  const started = Date.now();
  try { const observed = await fn(); report.tests.push({ name, status: 'PASS', milliseconds: Date.now()-started, observed: observed ?? 'assertions passed' }); console.log(`PASS ${name}`); }
  catch (error) {
    report.tests.push({ name, status: 'FAIL', sqlstate: error.code ?? null, error: error.message });
    console.log(`FAIL ${name}: ${error.code ?? error.name}`);
  }
}
async function reject(db, sql, values, expected, constraint) {
  try { await db.query(sql, values); throw new Error(`Expected SQLSTATE ${expected}, statement succeeded`); }
  catch (error) {
    const record = { expected: true, sqlstate: error.code ?? null, statement: sql, constraint: error.constraint ?? null,
      rootCause: error.message, proposedCorrection: 'No DDL correction: deliberately invalid synthetic input; supply valid tenant/configuration/state/range instead' };
    report.sqlErrors.push(record);
    assert.equal(error.code, expected); if (constraint) assert.equal(error.constraint, constraint);
    return { sqlstate: error.code, constraint: error.constraint ?? null };
  }
}
async function insert(db, table, values) {
  const keys = Object.keys(values), params = Object.values(values);
  const sql = `INSERT INTO ${quote(table)} (${keys.map(quote).join(',')}) VALUES (${keys.map((_,i)=>`$${i+1}`).join(',')}) RETURNING *`;
  try { return (await db.query(sql, params)).rows[0]; }
  catch(error) { error.statement=sql; throw error; }
}
async function resetDatabase(admin, name) {
  const existing = (await admin.query('SELECT shobj_description(oid,\'pg_database\') AS marker FROM pg_database WHERE datname=$1', [name])).rows[0];
  if (existing && existing.marker !== 'mohammadstyle-b0-disposable-validation') throw new Error('Refusing to drop unmarked database');
  if (existing) await admin.query(`DROP DATABASE ${quote(name)}`);
  await admin.query(`CREATE DATABASE ${quote(name)} OWNER ms_b0_admin`);
  await admin.query(`COMMENT ON DATABASE ${quote(name)} IS 'mohammadstyle-b0-disposable-validation'`);
}
async function schema(admin, dbName, schemaName, file, expectedTables, expectedStatements) {
  await resetDatabase(admin, dbName);
  const db = client(dbName); await db.connect();
  const sql = fs.readFileSync(path.join(root, '..', 'docs/architecture/schema', file), 'utf8');
  const list = statements(sql); assert.equal(list.length, expectedStatements);
  const result = { database: dbName, schema: schemaName, source: file, sha256: createHash('sha256').update(sql).digest('hex'), statements: list.length, errors: [] };
  await db.query('BEGIN');
  for (let i = 0; i < list.length; i++) {
    await db.query('SAVEPOINT ddl_statement');
    try { await db.query(list[i]); }
    catch (error) {
      const failure = { expected: false, sqlstate: error.code, statementNumber: i+1, statement: list[i],
        rootCause: error.message, proposedCorrection: 'Requires an explicit B0 correction patch and review; baseline remains unchanged' };
      result.errors.push(failure); report.sqlErrors.push(failure);
      await db.query('ROLLBACK TO SAVEPOINT ddl_statement');
    }
    await db.query('RELEASE SAVEPOINT ddl_statement');
  }
  await db.query('COMMIT');
  const counts = (await db.query(`SELECT
    (SELECT count(*)::int FROM pg_tables WHERE schemaname=$1) AS tables,
    (SELECT count(*)::int FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname=$1 AND contype='f') AS foreign_keys,
    (SELECT count(*)::int FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname=$1 AND contype='c') AS checks,
    (SELECT count(*)::int FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname=$1 AND contype='x') AS exclusions,
    (SELECT count(*)::int FROM pg_indexes WHERE schemaname=$1) AS indexes,
    (SELECT count(*)::int FROM information_schema.columns WHERE table_schema=$1 AND is_generated='ALWAYS') AS generated`, [schemaName])).rows[0];
  result.catalog = counts; result.extensions = (await db.query('SELECT extname, extversion FROM pg_extension ORDER BY extname')).rows;
  result.status = !result.errors.length && counts.tables === expectedTables ? 'PASS' : 'FAIL';
  report.schemas.push(result);
  assert.equal(result.errors.length, 0, `DDL errors in ${file}; inspect database-results.json`);
  assert.equal(counts.tables, expectedTables);
  await db.query(`SET search_path = ${quote(schemaName)}, public`);
  return db;
}
async function fixture(db) {
  const actor = await insert(db, 'app_user', { display_name: 'B0 SYNTHETIC ACTOR' });
  const business = await insert(db, 'business', { brand_name: 'B0 SYNTHETIC TENANT A', slug: randomUUID(), created_by: actor.id });
  const other = await insert(db, 'business', { brand_name: 'B0 SYNTHETIC TENANT B', slug: randomUUID() });
  const branch = await insert(db, 'branch', { business_id: business.id, code: 'B0_ONLY', display_name: 'B0 SYNTHETIC BRANCH', time_zone: 'Asia/Tehran' });
  const service = await insert(db, 'service', { business_id: business.id, code: 'B0_ONLY', display_name: 'B0 SYNTHETIC SERVICE' });
  const offering = await insert(db, 'branch_service_offering', { business_id: business.id, branch_id: branch.id, service_id: service.id });
  return { actor, business, other, branch, service, offering };
}
async function common(db, f, prefix) {
  const { business, other, branch, service, offering } = f;
  await check(`${prefix}: cross-tenant composite FK rejects foreign branch`, () => reject(db,
    'INSERT INTO branch_service_offering(business_id,branch_id,service_id) VALUES($1,$2,$3)', [other.id, branch.id, service.id], '23503'));
  await check(`${prefix}: per-tenant branch code uniqueness`, () => reject(db,
    'INSERT INTO branch(business_id,code,display_name,time_zone) VALUES($1,$2,$3,$4)', [business.id, branch.code, 'B0 DUPLICATE', 'Asia/Tehran'], '23505', 'uq_branch_1'));
  await check(`${prefix}: absent mandatory timezone rejected`, () => reject(db,
    'INSERT INTO branch(business_id,code,display_name) VALUES($1,$2,$3)', [business.id, randomUUID(), 'B0 MISSING CONFIG'], '23502'));
  await check(`${prefix}: negative price rejected`, () => reject(db,
    'UPDATE branch_service_offering SET price_rial=-10 WHERE id=$1', [offering.id], '23514', 'ck_branch_service_offering_1'));
  await check(`${prefix}: zero duration rejected`, () => reject(db,
    'UPDATE branch_service_offering SET duration_minutes=0 WHERE id=$1', [offering.id], '23514', 'ck_branch_service_offering_2'));
  await check(`${prefix}: transaction rollback removes synthetic write`, async () => {
    const id = randomUUID(); await db.query('BEGIN'); await insert(db, 'service', { id, business_id: business.id, code: randomUUID(), display_name: 'B0 ROLLBACK' });
    await db.query('ROLLBACK'); assert.equal((await db.query('SELECT id FROM service WHERE id=$1', [id])).rowCount, 0);
  });
  await check(`${prefix}: FK deferral supports child-before-parent commit`, async () => {
    const user = randomUUID(), id = randomUUID(); await db.query('BEGIN'); await db.query('SET CONSTRAINTS ALL DEFERRED');
    try { await insert(db, 'auth_identity', { id, user_id: user, provider: 'B0_SYNTHETIC', subject_hash: Buffer.alloc(32, 1) });
      await insert(db, 'app_user', { id: user }); await db.query('COMMIT');
      assert.equal((await db.query('SELECT id FROM auth_identity WHERE id=$1', [id])).rowCount, 1);
    } catch (e) { await db.query('ROLLBACK'); throw e; }
  });
  await check(`${prefix}: unresolved deferred FK fails COMMIT and rolls back`, async () => {
    const id = randomUUID(); await db.query('BEGIN'); await db.query('SET CONSTRAINTS ALL DEFERRED');
    await insert(db, 'auth_identity', { id, user_id: randomUUID(), provider: 'B0_MISSING', subject_hash: Buffer.alloc(32, 2) });
    const observed = await reject(db, 'COMMIT', [], '23503'); await db.query('ROLLBACK');
    assert.equal((await db.query('SELECT id FROM auth_identity WHERE id=$1', [id])).rowCount, 0); return observed;
  });
}
const admin = client(); let b1, full;
try {
  await admin.connect();
  const identity = (await admin.query("SELECT version(), current_user, current_database(), current_setting('server_version_num')::int AS version_num, shobj_description((SELECT oid FROM pg_database WHERE datname=current_database()),'pg_database') AS marker")).rows[0];
  assert.equal(identity.marker, 'mohammadstyle-b0-disposable-control'); assert.equal(identity.current_user, 'ms_b0_admin');
  assert.ok(identity.version_num >= 180000 && identity.version_num < 190000);
  report.server = identity;
  b1 = await schema(admin, 'ms_b0_b1_test', 'ms_b1_design', 'b1-draft-postgresql.sql', 16, 70);
  const b = await fixture(b1); await common(b1, b, 'B1');
  await check('B1: bookable branch gate even with active branch', () => reject(b1,
    'UPDATE branch SET active=true,bookable=true WHERE id=$1', [b.branch.id], '23514', 'b1_branch_inactive'));
  await check('B1: active offering gate even with all scalar configuration', () => reject(b1,
    'UPDATE branch_service_offering SET active=true,price_rial=100,duration_minutes=30,buffer_before_minutes=0,buffer_after_minutes=0,resources_confirmed=true WHERE id=$1', [b.offering.id], '23514', 'b1_branch_service_offering_inactive'));
  full = await schema(admin, 'ms_b0_full_test', 'ms_design', 'draft-postgresql.sql', 72, 423);
  const f = await fixture(full); await common(full, f, 'FULL');
  await check('FULL: activating missing offering configuration fails closed', () => reject(full,
    'UPDATE branch_service_offering SET active=true WHERE id=$1', [f.offering.id], '23514', 'ck_branch_service_offering_6'));
  const quoteValues = { business_id: f.business.id, branch_id: f.branch.id, total_rial: '100', deposit_rial: '20', remaining_rial: '80',
    expires_at: '2040-01-01T00:00:00Z', configuration_fingerprint: Buffer.alloc(32, 3), quote_hash: Buffer.alloc(32, 4), source: 'SERVER',
    created_by: f.actor.id, content_document: { schema: 'MS_QUOTE_CONTENT_V2', note: 'B0 synthetic DB row-shape only; not a validated domain quote' } };
  await check('FULL: independent customers may retain identical content hashes', async () => {
    const customerA = await insert(full, 'customer', { business_id: f.business.id });
    const customerB = await insert(full, 'customer', { business_id: f.business.id });
    const a = await insert(full, 'pricing_quote', { ...quoteValues, customer_id: customerA.id });
    const b = await insert(full, 'pricing_quote', { ...quoteValues, customer_id: customerB.id });
    assert.notEqual(a.id, b.id); assert.notEqual(a.customer_id, b.customer_id); assert.deepEqual(a.quote_hash, b.quote_hash);
    return 'Two distinct customer/quote UUIDs, identical 32-byte content hashes; no UNIQUE conflict. Ownership/hash recomputation not tested.';
  });
  const resource = await insert(full, 'resource', { business_id: f.business.id, kind: 'STAFF', label: 'B0 SYNTHETIC RESOURCE' });
  const staff = await insert(full, 'staff', { business_id: f.business.id, resource_id: resource.id, display_name: 'B0 SYNTHETIC STAFF' });
  const membership = { business_id: f.business.id, staff_id: staff.id, branch_id: f.branch.id };
  await insert(full, 'staff_branch_assignment', { ...membership, valid_from: '2030-01-01', valid_to: '2030-02-01', active: false, archived_at: '2030-02-01Z' });
  await check('FULL: inactive archived membership overlap still rejected', () => reject(full,
    'INSERT INTO staff_branch_assignment(business_id,staff_id,branch_id,valid_from,valid_to) VALUES($1,$2,$3,$4,$5)',
    [f.business.id, staff.id, f.branch.id, '2030-01-15', '2030-03-01'], '23P01', 'no_overlapping_membership_period'));
  await check('FULL: adjacent rejoin creates new historical stint and generated range', async () => {
    const row = await insert(full, 'staff_branch_assignment', { ...membership, valid_from: '2030-02-01', valid_to: '2030-03-01' });
    assert.equal(row.membership_period, '[2030-02-01,2030-03-01)');
  });
  await check('FULL: unreasoned void rejected', () => reject(full,
    'INSERT INTO staff_branch_assignment(business_id,staff_id,branch_id,valid_from,voided_at) VALUES($1,$2,$3,$4,now())',
    [f.business.id, staff.id, f.branch.id, '2031-01-01'], '23514', 'ck_staff_branch_assignment_4'));
  await check('FULL: global staff shift exclusion across different branches', async () => {
    const branchB = await insert(full,'branch',{business_id:f.business.id,code:'B0_SECOND_SYNTHETIC',display_name:'B0 SYNTHETIC',time_zone:'Asia/Tehran'});
    const a = await insert(full,'staff_branch_assignment',{...membership,valid_from:'2032-01-01',valid_to:'2033-01-01'});
    const b = await insert(full,'staff_branch_assignment',{...membership,branch_id:branchB.id,valid_from:'2032-01-01',valid_to:'2033-01-01'});
    const shift={business_id:f.business.id,staff_id:staff.id,branch_id:f.branch.id,assignment_id:a.id,starts_at:'2032-01-02T10:00Z',ends_at:'2032-01-02T11:00Z',published:true,schedule_version:1};
    const row=await insert(full,'staff_shift',shift); assert.match(row.working_period,/\)$/);
    return reject(full,'INSERT INTO staff_shift(business_id,staff_id,branch_id,assignment_id,starts_at,ends_at,published,schedule_version) VALUES($1,$2,$3,$4,$5,$6,true,1)',
      [f.business.id,staff.id,branchB.id,b.id,shift.starts_at,shift.ends_at],'23P01','no_cross_branch_staff_shift');
  });
  await check('FULL: policy scope/range generation and equal-rank exclusion', async () => {
    const policy=await insert(full,'booking_policy',{business_id:f.business.id,code:'B0_SYNTHETIC',name:'B0 synthetic constraint fixture'});
    const version=await insert(full,'booking_policy_version',{business_id:f.business.id,policy_id:policy.id,version_number:1,effective_from:'2030-01-01Z',deposit_requirement:'NONE',refundability:'NONE',refund_base:'DEPOSIT_PAID',outside_refund_bps:0,terms_text:'B0 SYNTHETIC; NOT BUSINESS TERMS',terms_locale:'en',content_hash:Buffer.alloc(32,7)});
    const assignment={business_id:f.business.id,policy_version_id:version.id,scope_kind:'BUSINESS',effective_from:'2030-01-01Z',effective_to:'2030-02-01Z'};
    const row=await insert(full,'booking_policy_assignment',assignment);
    assert.equal(row.scope_key,'BUSINESS:*:*:*:*'); assert.match(row.effective_period,/\)$/);
    return reject(full,'INSERT INTO booking_policy_assignment(business_id,policy_version_id,scope_kind,effective_from,effective_to) VALUES($1,$2,\'BUSINESS\',$3,$4)',
      [f.business.id,version.id,'2030-01-15Z','2030-03-01Z'],'23P01','no_equal_rank_policy_assignment');
  });
  for (const state of ['DRAFT', 'CANCELLED', 'EXPIRED']) await check(`FULL: revisionless ${state} row representable`, async () => {
    const row = await insert(full, 'booking', { business_id: f.business.id, branch_id: f.branch.id, origin: 'STAFF', status: state, draft_expires_at: '2040-01-01Z' });
    assert.equal(row.active_revision_id, null); assert.equal(row.plan_committed, false);
  });
  await check('FULL: revisionless confirmed state rejected', () => reject(full,
    "INSERT INTO booking(business_id,branch_id,origin,status,draft_expires_at) VALUES($1,$2,'STAFF','CONFIRMED','2040-01-01Z')", [f.business.id, f.branch.id], '23514', 'ck_booking_4'));
  await check('FULL: draft without finite expiry rejected', () => reject(full,
    "INSERT INTO booking(business_id,branch_id,origin,draft_expires_at) VALUES($1,$2,'STAFF','infinity')", [f.business.id, f.branch.id], '23514', 'ck_booking_5'));
  const allocation = { business_id: f.business.id, resource_id: resource.id, resource_kind: 'STAFF', allocation_kind: 'MAINTENANCE' };
  await insert(full, 'resource_allocation', { ...allocation, busy_starts_at: '2030-01-01T10:00Z', busy_ends_at: '2030-01-01T11:00Z' });
  await check('FULL: live resource overlap rejected', () => reject(full,
    "INSERT INTO resource_allocation(business_id,resource_id,resource_kind,allocation_kind,busy_starts_at,busy_ends_at) VALUES($1,$2,'STAFF','MAINTENANCE',$3,$4)",
    [f.business.id, resource.id, '2030-01-01T10:30Z', '2030-01-01T11:30Z'], '23P01', 'no_live_resource_overlap'));
  await check('FULL: adjacent half-open occupancy accepted', async () => {
    const row = await insert(full, 'resource_allocation', { ...allocation, busy_starts_at: '2030-01-01T11:00Z', busy_ends_at: '2030-01-01T12:00Z' });
    assert.match(row.busy_period, /^\[/); assert.match(row.busy_period, /\)$/);
  });
  await check('FULL: released ledger history does not block new live interval', async () => {
    await insert(full, 'resource_allocation', { ...allocation, busy_starts_at: '2030-01-01T10:00Z', busy_ends_at: '2030-01-01T11:00Z', released_at: '2030-01-02Z' });
  });
  await check('FULL: separate sessions block then reject overlapping uncommitted interval', async () => {
    const a = client('ms_b0_full_test'), b = client('ms_b0_full_test'); await a.connect(); await b.connect();
    try {
      await a.query('SET search_path=ms_design,public'); await b.query('SET search_path=ms_design,public');
      const ids = [(await a.query('SELECT pg_backend_pid() AS pid')).rows[0].pid, (await b.query('SELECT pg_backend_pid() AS pid')).rows[0].pid]; assert.notEqual(...ids);
      await a.query('BEGIN'); await b.query('BEGIN');
      await insert(a, 'resource_allocation', { ...allocation, busy_starts_at: '2030-02-01T10:00Z', busy_ends_at: '2030-02-01T11:00Z' });
      const pending = insert(b, 'resource_allocation', { ...allocation, busy_starts_at: '2030-02-01T10:30Z', busy_ends_at: '2030-02-01T11:30Z' }).then(()=>({success:true}),error=>({error}));
      let waiting = false;
      for (let i=0;i<40;i++) { const state = (await admin.query('SELECT wait_event_type FROM pg_stat_activity WHERE pid=$1',[ids[1]])).rows[0]; if(state?.wait_event_type==='Lock') {waiting=true;break;} await delay(25); }
      assert.equal(waiting,true, 'second backend must actually wait for a PostgreSQL lock');
      await a.query('COMMIT'); const outcome = await pending;
      assert.equal(outcome.error?.code,'23P01'); assert.equal(outcome.error?.constraint,'no_live_resource_overlap');
      report.sqlErrors.push({ expected:true, sqlstate:'23P01', statement:outcome.error.statement, constraint:'no_live_resource_overlap', rootCause:'Session A committed overlapping live interval', proposedCorrection:'No DDL correction; future engine must handle/retry conflicts' });
      await b.query('ROLLBACK'); return { backendPids: ids, observedWait: 'Lock', winner: 'session A committed', loser: 'session B SQLSTATE 23P01' };
    } finally { await a.query('ROLLBACK'); await b.query('ROLLBACK'); await a.end(); await b.end(); }
  });
  await check('FULL: real catalog has all generated and exclusion definitions; indexes valid', async () => {
    const result = report.schemas.find(s=>s.schema==='ms_design').catalog;
    assert.equal(result.generated,5); assert.equal(result.exclusions,4); assert.equal(result.foreign_keys,254);
    const invalid = await full.query("SELECT count(*)::int AS n FROM pg_index i JOIN pg_class t ON t.oid=i.indrelid JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname='ms_design' AND (NOT indisvalid OR NOT indisready)");
    assert.equal(invalid.rows[0].n,0); return result;
  });
} catch (error) {
  report.fatal = { sqlstate: error.code ?? null, error: error.message }; console.log(`VALIDATION STOPPED: ${error.code ?? error.name}: ${error.message}`);
} finally {
  if(b1) await b1.end(); if(full) await full.end(); await admin.end();
  report.summary = { passed: report.tests.filter(t=>t.status==='PASS').length, failed: report.tests.filter(t=>t.status==='FAIL').length,
    unexpectedSqlErrors: report.sqlErrors.filter(e=>!e.expected).length, expectedSqlRejections: report.sqlErrors.filter(e=>e.expected).length };
  save('database-results.json', report);
  console.log(JSON.stringify(report.summary));
  if(report.fatal || report.summary.failed || report.summary.unexpectedSqlErrors) process.exitCode=1;
}
