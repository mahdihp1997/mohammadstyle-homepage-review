// Offline, explicit receipt-only retention. No HTTP route or worker permission.
// A valid, authenticated backup containing this exact immutable evidence is
// mandatory before a single live object can be deleted. Defaults to dry-run.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import pg from 'pg';
import {loadProductConfig,secret} from '../../dist/product/config.js';
import {LocalMediaStorage,S3MediaStorage,validKey} from '../../dist/mvp/storage.js';
import {decryptTo} from './backup-crypto.mjs';

export async function receiptRetention({cfg,password,key,directory,receiptId,expectedBusinessId,storage,execute=false}){
 if(!Buffer.isBuffer(key)||key.length!==32||expectedBusinessId!==cfg.businessId||!/^[a-f0-9-]{36}$/.test(receiptId)||typeof execute!=='boolean')throw Error('EXPLICIT_RETENTION_CONFIGURATION_REQUIRED');
 const folder=path.resolve(directory);
 if(folder===path.parse(folder).root||folder.split(path.sep).includes('public'))throw Error('PRIVATE_BACKUP_DIRECTORY_REQUIRED');
 const db=new pg.Client({host:cfg.database.host,port:cfg.database.port,database:cfg.database.database,user:'ms_b1a_migrator',password,ssl:cfg.database.ssl});
 let scratch;
 try{
  await db.connect();const identity=(await db.query("SELECT current_database() db,current_user role,shobj_description((SELECT oid FROM pg_database WHERE datname=current_database()),'pg_database') marker")).rows[0];
  if(identity.db!==cfg.database.database||identity.role!=='ms_b1a_migrator'||identity.marker!==cfg.database.marker)throw Error('RETENTION_DATABASE_IDENTITY');
  const r=(await db.query('SELECT r.*,t.state retention_state,t.backup_manifest_sha256 FROM ms_b1_design.product_manual_receipt r LEFT JOIN ms_b1_design.product_receipt_retention t ON t.receipt_id=r.id WHERE r.id=$1 AND r.business_id=$2',[receiptId,cfg.businessId])).rows[0];
  if(!r)throw Error('RETENTION_RECEIPT_NOT_FOUND');
  scratch=await fs.promises.mkdtemp(path.join(folder,'.verified-retention-'));await fs.promises.chmod(scratch,0o700);
  const manifestFile=path.join(scratch,'manifest.json');await decryptTo(path.join(folder,'manifest.aes'),manifestFile,key,'manifest');
  const bytes=await fs.promises.readFile(manifestFile),manifest=JSON.parse(bytes),hash=createHash('sha256').update(bytes).digest('hex');
  if(manifest.format!=='mohammadstyle-encrypted-backup-v1'||manifest.environment!==cfg.environment||manifest.businessId!==cfg.businessId||!Array.isArray(manifest.media)||!Number.isFinite(Date.parse(manifest.at))||Date.parse(manifest.at)<new Date(r.created_at).getTime())throw Error('RETENTION_BACKUP_REALM_OR_DATE');
  if(r.backup_manifest_sha256&&r.backup_manifest_sha256!==hash)throw Error('RETENTION_BACKUP_MISMATCH');
  // Authenticate the dump as well as both original/display objects. An empty or
  // damaged archive must not be used to authorize removal of the live evidence.
  await decryptTo(path.join(folder,'database.aes'),path.join(scratch,'database.dump'),key,'database',manifest.database);
  for(const [kind,objectKey,sha,objectBytes] of [['original',r.original_key,r.original_object_sha256,r.original_object_bytes],['display',r.display_key,r.display_object_sha256,r.display_object_bytes]]){
   validKey(objectKey);const index=manifest.media.findIndex(m=>m.key===objectKey),item=manifest.media[index];
   if(!item||item.file!=='object-'+String(index).padStart(8,'0')+'.aes'||item.sha256!==sha||item.bytes!==String(objectBytes))throw Error('RETENTION_BACKUP_OBJECT_MISMATCH');
   await decryptTo(path.join(folder,item.file),path.join(scratch,kind+'.bin'),key,objectKey,item);
  }
  const eligible=(await db.query('SELECT ms_b1_design.manual_retention_eligible($1) eligible',[receiptId])).rows[0].eligible;
  if(!eligible&&!r.retention_state)throw Error('RETENTION_NOT_ELIGIBLE');
  if(!execute)return{dryRun:true,eligible,authenticatedBackup:true,alreadyRequested:!!r.retention_state,objects:2};
  if(!storage.deleteReceipt)throw Error('RETENTION_STORAGE_UNSUPPORTED');
  // Stop API/worker first. Retention is deliberately an offline operator task;
  // it is never run by the app scheduler or a configurable web command.
  if(Number((await db.query("SELECT count(*) n FROM pg_stat_activity WHERE datname=current_database() AND backend_type='client backend'")).rows[0].n)!==1)throw Error('RETENTION_REQUIRES_OFFLINE_DATABASE');
  await db.query('BEGIN');try{await db.query('SELECT ms_b1_design.manual_retention_request($1,$2)',[receiptId,hash]);await db.query('COMMIT');}catch(e){await db.query('ROLLBACK');throw e;}
  // REQUESTED hides live image access before deletion. A crash after either
  // object deletion is safe to retry using the same authenticated manifest.
  await storage.deleteReceipt(r.original_key);await storage.deleteReceipt(r.display_key);
  await db.query('SELECT ms_b1_design.manual_retention_finish($1,$2)',[receiptId,hash]);
  return{dryRun:false,purged:true,authenticatedBackup:true,metadataAndHistoryRetained:true,objects:2};
 }finally{
  await db.end();storage.close?.();
  if(scratch){const resolved=path.resolve(scratch);if(!resolved.startsWith(folder+path.sep)||!path.basename(resolved).startsWith('.verified-retention-'))throw Error('UNSAFE_RETENTION_TEMP');await fs.promises.rm(resolved,{recursive:true,force:true});}
 }
}
if(process.argv[1]?.replaceAll('\\','/').endsWith('/scripts/product/receipt-retention.mjs')){
 const cfg=loadProductConfig(process.env,'migrate'),password=secret(process.env,'PRODUCT_MIGRATOR_PASSWORD'),encoded=secret(process.env,'BACKUP_ENCRYPTION_KEY');
 if(!/^[a-f0-9]{64}$/.test(password??'')||!/^[A-Za-z0-9_-]{43}$/.test(encoded??''))throw Error('RETENTION_SECRETS_REQUIRED');
 const storage=process.env.PRODUCT_STORAGE==='s3'?new S3MediaStorage({endpoint:process.env.S3_ENDPOINT??'',bucket:process.env.S3_BUCKET??'',region:process.env.S3_REGION??'',accessKey:secret(process.env,'S3_ACCESS_KEY'),secretKey:secret(process.env,'S3_SECRET_KEY')}):new LocalMediaStorage(cfg.mediaRoot);
 try{console.log(JSON.stringify(await receiptRetention({cfg,password,key:Buffer.from(encoded,'base64url'),directory:process.env.BACKUP_DIRECTORY??'',receiptId:process.env.RETENTION_RECEIPT_ID??'',expectedBusinessId:process.env.RETENTION_BUSINESS_ID,storage,execute:process.argv[2]==='--execute'})));}catch{console.error('Receipt retention failed; no secrets or receipt content are logged. Check eligibility, offline state and authenticated backup.');process.exitCode=1;}
}
