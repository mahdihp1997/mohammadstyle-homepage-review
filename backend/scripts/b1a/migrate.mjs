import fs from'node:fs';import path from'node:path';import{createHash}from'node:crypto';import{root,client,identify}from'./local.mjs';import{assertCatalog}from'./catalog.mjs';
export function loadMigrations(){const dir=path.join(root,'migrations'),registry=JSON.parse(fs.readFileSync(path.join(dir,'registry.json'),'utf8'));return registry.migrations.map(m=>{if(!/^\d{4}_[a-z0-9_]+$/.test(m.id)||m.file!==m.id+'.sql')throw Error('Invalid migration registry');const sql=fs.readFileSync(path.join(dir,m.file),'utf8').replaceAll('\r\n','\n'),hash=createHash('sha256').update(sql).digest('hex');if(hash!==m.sha256)throw Object.assign(Error('Migration source checksum mismatch'),{code:'B1A_SOURCE_CHECKSUM'});return{...m,sql};});}
export function splitSql(sql){const list=[];let start=0,single=false,line=false;for(let i=0;i<sql.length;i++){const c=sql[i],n=sql[i+1];if(line){if(c==='\n')line=false;continue;}if(!single&&c==='-'&&n==='-'){line=true;i++;continue;}if(c==="'"){if(single&&n==="'"){i++;continue;}single=!single;}if(c===';'&&!single){list.push(sql.slice(start,i+1).trim());start=i+1;}}if(sql.slice(start).replace(/--[^\n]*/g,'').trim())throw Error('Unterminated native SQL');return list;}
export async function migrate(db,database,{definitions=loadMigrations(),verifyCatalog=true}={}){
 await identify(db,database);await db.query('BEGIN');let statement='BEGIN',migrationId=null;
 try{
  await db.query('SET LOCAL lock_timeout=\'5s\'');await db.query('SELECT pg_advisory_xact_lock(603031,1)');
  await db.query('CREATE SCHEMA IF NOT EXISTS ms_b1_meta');
  await db.query(`CREATE TABLE IF NOT EXISTS ms_b1_meta.schema_migration(id text PRIMARY KEY,checksum text NOT NULL CHECK(checksum ~ '^[0-9a-f]{64}$'),applied_at timestamptz NOT NULL DEFAULT clock_timestamp(),execution_ms integer NOT NULL CHECK(execution_ms>=0))`);
  await db.query('REVOKE ALL ON SCHEMA ms_b1_meta FROM PUBLIC');
  const rows=(await db.query('SELECT id,checksum FROM ms_b1_meta.schema_migration ORDER BY id')).rows;
  if(rows.length>definitions.length||rows.some((r,i)=>r.id!==definitions[i]?.id))throw Object.assign(Error('Unknown, missing or out-of-order migration history'),{code:'B1A_HISTORY'});
  if(rows.some((r,i)=>r.checksum!==definitions[i].sha256))throw Object.assign(Error('Applied migration checksum differs from reviewed source'),{code:'B1A_CHECKSUM'});
  if(!rows.length&&(await db.query("SELECT 1 FROM pg_namespace WHERE nspname='ms_b1_design'")).rowCount)throw Object.assign(Error('Untracked application schema; refuse implicit adoption'),{code:'B1A_UNTRACKED_SCHEMA'});
  const applied=[];
  for(const migration of definitions.slice(rows.length)){
   migrationId=migration.id;const started=Date.now();for(const sql of splitSql(migration.sql)){statement=sql;await db.query(sql);}
   await db.query('INSERT INTO ms_b1_meta.schema_migration(id,checksum,execution_ms) VALUES($1,$2,$3)',[migration.id,migration.sha256,Date.now()-started]);applied.push(migration.id);
  }
  const summary=verifyCatalog?await assertCatalog(db):null;await db.query('COMMIT');return{applied,currentVersion:definitions.at(-1)?.id,catalog:summary};
 }catch(error){await db.query('ROLLBACK');error.migrationId=migrationId;error.statement=statement;throw error;}
}
if(process.argv[1]&&path.resolve(process.argv[1])===path.join(root,'scripts/b1a/migrate.mjs')){const database=process.argv[2]??'ms_b1a_dev',db=client(database);try{await db.connect();console.log(JSON.stringify(await migrate(db,database)));}catch(e){console.error(JSON.stringify({status:'FAIL',code:e.code??null,sqlstate:/^[0-9A-Z]{5}$/.test(e.code??'')?e.code:null,migration:e.migrationId??null,statement:e.statement??null,rootCause:e.message}));process.exitCode=1;}finally{await db.end();}}
