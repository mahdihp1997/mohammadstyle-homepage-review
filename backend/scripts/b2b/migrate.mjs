import fs from 'node:fs';import path from 'node:path';import {createHash} from 'node:crypto';
import {root,client,identify} from './local.mjs';import {assertCatalog} from './catalog.mjs';
export function loadMigrations() {
 const registry=JSON.parse(fs.readFileSync(path.join(root,'migrations/registry.b2b.json'),'utf8'));
 return registry.migrations.map(m=>{
  if(!/^\d{4}_[a-z0-9_]+$/.test(m.id)||m.file!==m.id+'.sql')throw Error('Invalid B2B registry');
  const sql=fs.readFileSync(path.join(root,'migrations',m.file),'utf8').replaceAll('\r\n','\n');
  if(createHash('sha256').update(sql).digest('hex')!==m.sha256)throw Object.assign(Error('Migration source checksum mismatch'),{code:'B2B_SOURCE_CHECKSUM'});
  return {...m,sql};
 });
}
export async function migrate(db,database,{definitions=loadMigrations(),verifyCatalog=true}={}) {
 await identify(db,database);await db.query('BEGIN');let migrationId=null;
 try {
  await db.query("SET LOCAL lock_timeout='5s'");await db.query('SELECT pg_advisory_xact_lock(603031,1)');
  await db.query('CREATE SCHEMA IF NOT EXISTS ms_b1_meta');
  await db.query("CREATE TABLE IF NOT EXISTS ms_b1_meta.schema_migration(id text PRIMARY KEY,checksum text NOT NULL CHECK(checksum ~ '^[0-9a-f]{64}$'),applied_at timestamptz NOT NULL DEFAULT clock_timestamp(),execution_ms integer NOT NULL CHECK(execution_ms>=0))");
  await db.query('REVOKE ALL ON SCHEMA ms_b1_meta FROM PUBLIC');
  const rows=(await db.query('SELECT id,checksum FROM ms_b1_meta.schema_migration ORDER BY id')).rows;
  if(rows.length>definitions.length||rows.some((r,i)=>r.id!==definitions[i]?.id))throw Object.assign(Error('Unknown/missing/out-of-order history'),{code:'B2B_HISTORY'});
  if(rows.some((r,i)=>r.checksum!==definitions[i].sha256))throw Object.assign(Error('Applied checksum mismatch'),{code:'B2B_CHECKSUM'});
  if(!rows.length&&(await db.query("SELECT 1 FROM pg_namespace WHERE nspname='ms_b1_design'")).rowCount)throw Object.assign(Error('Untracked schema refused'),{code:'B2B_UNTRACKED_SCHEMA'});
  const applied=[];
  for(const m of definitions.slice(rows.length)) {
   migrationId=m.id;const started=Date.now();
   // PostgreSQL parses the complete native migration, including dollar-quoted function bodies.
   await db.query(m.sql);
   await db.query('INSERT INTO ms_b1_meta.schema_migration(id,checksum,execution_ms) VALUES($1,$2,$3)',[m.id,m.sha256,Date.now()-started]);applied.push(m.id);
  }
  const result={applied,currentVersion:definitions.at(-1)?.id,catalog:verifyCatalog?await assertCatalog(db):null};
  await db.query('COMMIT');return result;
 } catch(e) {await db.query('ROLLBACK');e.migrationId=migrationId;throw e;}
}
if(process.argv[1]&&path.resolve(process.argv[1])===path.join(root,'scripts/b2b/migrate.mjs')) {
 const database=process.argv[2]??'ms_b2b_dev',db=client(database);
 try{await db.connect();console.log(JSON.stringify(await migrate(db,database)));}catch(e){console.error(JSON.stringify({status:'FAIL',code:e.code??null,migration:e.migrationId??null,message:e.message}));process.exitCode=1;}finally{await db.end();}
}
