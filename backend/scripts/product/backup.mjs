// Offline operator only. AEAD-authenticate every restored byte BEFORE pg_restore.
import fs from'node:fs';import path from'node:path';import{spawn}from'node:child_process';import{Readable}from'node:stream';import pg from'pg';
import{loadProductConfig,secret}from'../../dist/product/config.js';import{LocalMediaStorage,S3MediaStorage,validKey}from'../../dist/mvp/storage.js';import{encryptTo,decryptTo}from'./backup-crypto.mjs';
export async function backupOperation({operation,directory,cfg,password,key,storage,tool,restoreTarget=null}){
 if(!['backup','restore'].includes(operation)||!Buffer.isBuffer(key)||key.length!==32)throw Error('BACKUP_CONFIGURATION_REQUIRED');
 const folder=path.resolve(directory);if(folder===path.parse(folder).root||folder.split(path.sep).includes('public'))throw Error('PRIVATE_BACKUP_DIRECTORY_REQUIRED');
 const db=new pg.Client({host:cfg.database.host,port:cfg.database.port,database:cfg.database.database,user:'ms_b1a_migrator',password,ssl:cfg.database.ssl});
 let scratch;try{await db.connect();const identity=(await db.query("SELECT current_database() name,current_user owner,shobj_description((SELECT oid FROM pg_database WHERE datname=current_database()),'pg_database') marker,current_setting('server_version_num')::int version")).rows[0];
  if(identity.owner!=='ms_b1a_migrator'||identity.name!==cfg.database.database||identity.marker!==cfg.database.marker||identity.version<180000||identity.version>=190000)throw Error('BACKUP_DATABASE_IDENTITY');
  await fs.promises.mkdir(folder,{recursive:true,mode:0o700});scratch=await fs.promises.mkdtemp(path.join(folder,'.verified-'));await fs.promises.chmod(scratch,0o700);
  if(operation==='backup'){
   if(fs.existsSync(path.join(folder,'manifest.aes')))throw Error('BACKUP_ALREADY_EXISTS');
   await db.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');const snapshot=(await db.query('SELECT pg_export_snapshot() id')).rows[0].id;
   const hasReceipts=(await db.query("SELECT to_regclass('ms_b1_design.product_manual_receipt') IS NOT NULL yes")).rows[0].yes;
   const receiptObjects=hasReceipts?" UNION ALL SELECT original_key,original_object_sha256,original_object_bytes::text FROM ms_b1_design.product_manual_receipt r WHERE NOT EXISTS(SELECT 1 FROM ms_b1_design.product_receipt_retention t WHERE t.receipt_id=r.id) UNION ALL SELECT display_key,display_object_sha256,display_object_bytes::text FROM ms_b1_design.product_manual_receipt r WHERE NOT EXISTS(SELECT 1 FROM ms_b1_design.product_receipt_retention t WHERE t.receipt_id=r.id)":"";
   const objects=(await db.query("SELECT original_key key,source_hash sha256,source_bytes::text bytes FROM ms_b1_design.media_asset UNION ALL SELECT storage_key,sha256,bytes::text FROM ms_b1_design.media_variant"+receiptObjects+" ORDER BY key")).rows;
   const count=await counts(db),schema=(await db.query('SELECT id,checksum FROM ms_b1_meta.schema_migration ORDER BY id')).rows;
   const child=tool('pg_dump',['--format=custom','--no-owner','--snapshot='+snapshot]),done=completion(child);const database=await encryptTo(child.stdout,path.join(folder,'database.aes'),key,'database');await done;
   const media=[];for(const item of objects){validKey(item.key);const name='object-'+String(media.length).padStart(8,'0')+'.aes',actual=await encryptTo(await storage.read(item.key),path.join(folder,name),key,item.key);if(actual.sha256!==item.sha256||actual.bytes!==item.bytes)throw Error('SOURCE_MEDIA_HASH_MISMATCH');media.push({...item,file:name});}
   await db.query('COMMIT');const manifest={format:'mohammadstyle-encrypted-backup-v1',at:new Date().toISOString(),environment:cfg.environment,businessId:cfg.businessId,database,counts:count,schema,media};
   await encryptTo(Readable.from([Buffer.from(JSON.stringify(manifest))]),path.join(folder,'manifest.aes'),key,'manifest');return{database:true,media:media.length,tables:count.length,encrypted:true};
  }
  if(restoreTarget!==identity.name)throw Error('EXPLICIT_RESTORE_TARGET_REQUIRED');
  if((await db.query("SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname NOT LIKE 'pg_%' AND n.nspname<>'information_schema' AND c.relkind IN('r','p','v','m','S') LIMIT 1")).rowCount)throw Error('RESTORE_REQUIRES_EMPTY_DATABASE');
  if(Number((await db.query('SELECT count(*) n FROM pg_stat_activity WHERE datname=current_database()')).rows[0].n)!==1)throw Error('RESTORE_REQUIRES_OFFLINE_DATABASE');
  const manifestFile=path.join(scratch,'manifest.json');await decryptTo(path.join(folder,'manifest.aes'),manifestFile,key,'manifest');const manifest=JSON.parse(await fs.promises.readFile(manifestFile,'utf8'));
  if(manifest.format!=='mohammadstyle-encrypted-backup-v1'||manifest.environment!==cfg.environment||manifest.businessId!==cfg.businessId||!Array.isArray(manifest.media))throw Error('RESTORE_REALM_MISMATCH');
  const dump=path.join(scratch,'database.dump');await decryptTo(path.join(folder,'database.aes'),dump,key,'database',manifest.database);
  // Immutable objects can be restored first. DB stays empty if any object fails authentication.
  for(const [i,item]of manifest.media.entries()){validKey(item.key);if(item.file!=='object-'+String(i).padStart(8,'0')+'.aes')throw Error('INVALID_BACKUP_OBJECT');const plain=path.join(scratch,'object.bin');await decryptTo(path.join(folder,item.file),plain,key,item.key,item);await storage.put(item.key,await fs.promises.readFile(plain),'application/octet-stream');await fs.promises.unlink(plain);}
  const child=tool('pg_restore',['--dbname='+cfg.database.database,'--no-owner','--exit-on-error','--single-transaction',dump]);await completion(child);
  const actual=await counts(db);if(JSON.stringify(actual)!==JSON.stringify(manifest.counts))throw Error('RESTORE_ROW_COUNT_MISMATCH');
  const schema=(await db.query('SELECT id,checksum FROM ms_b1_meta.schema_migration ORDER BY id')).rows;if(JSON.stringify(schema)!==JSON.stringify(manifest.schema))throw Error('RESTORE_SCHEMA_MISMATCH');
  for(const item of manifest.media){const{createHash}=await import('node:crypto');const hash=createHash('sha256');let size=0;for await(const bytes of await storage.read(item.key)){hash.update(bytes);size+=bytes.length;}if(hash.digest('hex')!==item.sha256||String(size)!==item.bytes)throw Error('RESTORE_OBJECT_MISMATCH');}
  return{database:true,media:manifest.media.length,tables:actual.length,authenticatedBeforeRestore:true,rowCountsMatch:true,schemaChecksumsMatch:true};
 }finally{await db.end();storage.close?.();if(scratch){const resolved=path.resolve(scratch);if(!resolved.startsWith(folder+path.sep)||!path.basename(resolved).startsWith('.verified-'))throw Error('UNSAFE_BACKUP_TEMP');await fs.promises.rm(resolved,{recursive:true,force:true});}}
}
async function counts(db){const tables=(await db.query("SELECT schemaname,tablename FROM pg_tables WHERE schemaname IN('ms_b1_design','ms_b1_meta') ORDER BY schemaname,tablename")).rows,values=[];for(const t of tables){if(!/^[a-z0-9_]+$/.test(t.tablename))throw Error('UNEXPECTED_TABLE');values.push({table:t.schemaname+'.'+t.tablename,count:(await db.query(`SELECT count(*)::text n FROM "${t.schemaname}"."${t.tablename}"`)).rows[0].n});}return values;}
function completion(child){return new Promise((resolve,reject)=>{child.once('error',reject);child.stderr?.resume();child.once('exit',code=>code===0?resolve():reject(Error('POSTGRES_BACKUP_TOOL_FAILED')));});}
if(process.argv[1]?.replaceAll('\\','/').endsWith('/scripts/product/backup.mjs')){
 const cfg=loadProductConfig(process.env,'migrate'),password=secret(process.env,'PRODUCT_MIGRATOR_PASSWORD'),encoded=secret(process.env,'BACKUP_ENCRYPTION_KEY');if(!/^[a-f0-9]{64}$/.test(password??'')||!/^[A-Za-z0-9_-]{43}$/.test(encoded??''))throw Error('BACKUP_SECRETS_REQUIRED');
 const env={...process.env,PGHOST:cfg.database.host,PGPORT:String(cfg.database.port),PGDATABASE:cfg.database.database,PGUSER:'ms_b1a_migrator',PGPASSWORD:password,PGSSLMODE:'verify-full',PGSSLROOTCERT:process.env.PGSSL_CA_FILE};
 const storage=process.env.PRODUCT_STORAGE==='s3'?new S3MediaStorage({endpoint:process.env.S3_ENDPOINT??'',bucket:process.env.S3_BUCKET??'',region:process.env.S3_REGION??'',accessKey:secret(process.env,'S3_ACCESS_KEY'),secretKey:secret(process.env,'S3_SECRET_KEY')}):new LocalMediaStorage(cfg.mediaRoot);await storage.prepare?.();
 try{const result=await backupOperation({operation:process.argv[2],directory:process.env.BACKUP_DIRECTORY??'',cfg,password,key:Buffer.from(encoded,'base64url'),storage,restoreTarget:process.env.RESTORE_TARGET_DATABASE,tool:(name,args)=>spawn(name,args,{env,stdio:['ignore','pipe','pipe'],windowsHide:true})});console.log(JSON.stringify(result));}catch{console.error('Backup/restore failed; preserve encrypted files and inspect operator diagnostics without logging secrets.');process.exitCode=1;}
}
