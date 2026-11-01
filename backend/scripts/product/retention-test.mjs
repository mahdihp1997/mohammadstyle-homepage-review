// Expired retention dates are a trusted historical fixture in a NEW scratch
// database. No runtime clock override, production receipt or live DB is used.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {randomBytes,randomInt,randomUUID,createHash} from 'node:crypto';
import {spawn} from 'node:child_process';
import sharp from 'sharp';
import {applyEnvironment,client,folder,docker,readEnvironment,testProject,save} from './local.mjs';
import {freshScratch} from './scratch.mjs';
import {migrate} from './migrate.mjs';
import {bootstrap} from './bootstrap.mjs';
import {identities,commercialFixture} from './fixtures.mjs';
import {loadProductConfig} from '../../dist/product/config.js';
import {ProductRepository} from '../../dist/product/repository.js';
import {ProductAuthService} from '../../dist/product/auth.js';
import {ManualPaymentService,normalizeCard,encryptReceipt} from '../../dist/product/manual.js';
import {LocalMediaStorage} from '../../dist/mvp/storage.js';
import {digest} from '../../dist/product/crypto.js';
import {backupOperation} from './backup.mjs';
import {receiptRetention} from './receipt-retention.mjs';
applyEnvironment();
await freshScratch('ms_product_failure');
const cfg=loadProductConfig({...process.env,PGDATABASE:'ms_product_failure',PAYMENT_PROVIDER:'none',PRODUCT_MEDIA_ROOT:path.join(folder,'retention-media-'+randomUUID())});
const db=client('ms_product_failure'),repo=new ProductRepository(cfg),auth=new ProductAuthService(cfg),storage=new LocalMediaStorage(cfg.mediaRoot),manual=new ManualPaymentService(repo,storage),tests=[];
const directory=path.join(folder,'retention-backup-'+randomUUID()),key=randomBytes(32),password=readEnvironment().PRODUCT_MIGRATOR_PASSWORD;
const sha=b=>createHash('sha256').update(b).digest('hex');
let closed=false,receiptId,originalKey,displayKey,eCustomer;
async function test(name,fn){await fn();tests.push({name,passed:true});console.log('PASS '+name);}
function tools(database){return(name,args)=>{const options=[...args],file=name==='pg_restore'?options.pop():null,child=spawn(docker,['exec','-i',testProject()+'-postgres-1','sh','-c','IFS= read -r PGPASSWORD; export PGPASSWORD; exec "$@"','backup-tool',name,'--host=127.0.0.1','--port=5432','--username=ms_b1a_migrator',...(name==='pg_dump'?['--dbname='+database]:[]),...options],{stdio:['pipe','pipe','pipe'],windowsHide:true});child.stdin.write(password+'\n');if(file)fs.createReadStream(file).pipe(child.stdin);else child.stdin.end();return child;};}
async function waitOffline(){const control=client('ms_product_control','admin');await control.connect();try{for(let i=0;i<40;i++){const n=Number((await control.query("SELECT count(*) n FROM pg_stat_activity WHERE datname='ms_product_failure' AND backend_type='client backend'")).rows[0].n);if(!n)return;await new Promise(r=>setTimeout(r,50));}throw Error('SCRATCH_CLIENTS_STILL_OPEN');}finally{await control.end();}}
const retain=(extra={})=>receiptRetention({cfg,password,key,directory,receiptId,expectedBusinessId:cfg.businessId,storage,...extra});
try{
 await db.connect();await migrate(db,cfg.database.marker);await bootstrap(db,cfg);await auth.onModuleInit();await repo.onModuleInit();
 const ids=await identities(db,cfg,auth),owner=await ids.administrator(),customer=await ids.customer();
 const evidence=async a=>({hash:digest(a.result.session.token),csrf:digest(a.result.session.csrf),actor:await repo.session(digest(a.result.session.token)),requestId:randomUUID()});
 const eo=await evidence(owner);eCustomer=await evidence(customer);const f=await commercialFixture(db,cfg,repo,owner);
 let number;const prefix='999996'+String(randomInt(100000000,999999999));for(let i=0;i<10;i++){try{number=normalizeCard(prefix+i);break;}catch{}}
 const card=await manual.cardSave(eo,randomUUID(),{id:null,version:'0',bankName:'SYNTHETIC RETENTION BANK',number,cardholder:'SYNTHETIC ONLY',scopeKind:'BRANCHES',branchIds:[f.branch.id],priority:'1',active:true,archive:false});
 await manual.settingsSave(eo,randomUUID(),{branchId:f.branch.id,version:'0',onlineEnabled:false,manualEnabled:true,defaultCardId:card.id,retentionDays:'1',maxSubmissions:'3',inherit:false});
 const command=(op,d)=>repo.command(eCustomer.hash,eCustomer.csrf,op,randomUUID(),randomUUID(),d);
 const a=await command('availability',{branchId:f.branch.id,offeringIds:f.offerings.map(x=>x.id),staffId:null,date:f.day,optionalDepositChosen:false,rescheduleBookingId:null,cursor:'600'}),q=await command('quote',{planId:a.slots[0].id});let booking=await command('draft',{branchId:f.branch.id});booking=await command('hold',{bookingId:booking.id,version:booking.version,quoteId:q.id,contentHash:q.contentHash,snapshotHash:q.content.policy.snapshotHash,accepted:true});booking=await command('confirm',{bookingId:booking.id,version:booking.version});
 const p=await manual.start(eCustomer,randomUUID(),{bookingId:booking.id,version:booking.version,cardId:card.id});
 receiptId=randomUUID();originalKey=`receipts/${cfg.businessId}/${receiptId}/original.aes`;displayKey=`receipts/${cfg.businessId}/${receiptId}/display.aes`;
 const bytes=await sharp({create:{width:400,height:240,channels:3,background:'#375d71'}}).png().toBuffer(),display=await sharp(bytes).webp().toBuffer();
 const originalObject=encryptReceipt(cfg.encryptionKey,bytes,`receipt-image:${cfg.businessId}:${receiptId}:original`),displayObject=encryptReceipt(cfg.encryptionKey,display,`receipt-image:${cfg.businessId}:${receiptId}:display`);
 await storage.put(originalKey,originalObject,'application/octet-stream');await storage.put(displayKey,displayObject,'application/octet-stream');
 await db.query("INSERT INTO ms_b1_design.product_manual_receipt(id,business_id,intent_id,submission,submitted_by,original_key,original_sha256,original_object_sha256,original_object_bytes,display_key,display_sha256,display_object_sha256,display_object_bytes,mime,source_bytes,width,height,retention_eligible_at,created_at) VALUES($1,$2,$3,1,$4,$5,$6,$7,$8,$9,$10,$11,$12,'image/png',$13,400,240,clock_timestamp()-interval '1 day',clock_timestamp()-interval '2 days')",[receiptId,cfg.businessId,p.id,customer.result.userId,originalKey,Buffer.from(sha(bytes),'hex'),sha(originalObject),String(originalObject.length),displayKey,Buffer.from(sha(display),'hex'),sha(displayObject),String(displayObject.length),String(bytes.length)]);
 await test('A configured deadline alone never permits deleting an unreviewed/live receipt',async()=>{assert.equal((await db.query('SELECT ms_b1_design.manual_retention_eligible($1) ok',[receiptId])).rows[0].ok,false);await assert.rejects(()=>db.query('SELECT ms_b1_design.manual_retention_request($1,$2)',[receiptId,'0'.repeat(64)]),e=>e.message==='RETENTION_NOT_ELIGIBLE');assert.ok((await manual.image(eCustomer,receiptId)).length);});
 await manual.review(eo,randomUUID(),{intentId:p.id,receiptId,version:'1',decision:'REJECT',reason:'SYNTHETIC historical evidence test',amountRial:null,receivedAt:null,bankReference:null,attested:false});await command('cancel',{bookingId:booking.id,version:booking.version});
 await test('Offline retention functions are unavailable to API/auth/worker and deletion cannot target gallery media',async()=>{for(const role of ['ms_b1b_api','ms_product_auth','ms_product_worker'])assert.equal((await db.query("SELECT has_function_privilege($1,'ms_b1_design.manual_retention_request(uuid,text)','EXECUTE') ok",[role])).rows[0].ok,false);await assert.rejects(()=>storage.deleteReceipt(`${cfg.businessId}/${randomUUID()}/${'0'.repeat(64)}/display.webp`),/boundary/);});
 await test('An actual authenticated encrypted backup contains both immutable receipt objects and the database',async()=>{const result=await backupOperation({operation:'backup',cfg,password,key,directory,storage,tool:tools('ms_product_failure')});assert.equal(result.media,2);assert.equal(result.encrypted,true);});
 await test('Wrong key/business and a live application connection cannot authorize deletion',async()=>{await assert.rejects(()=>retain({key:randomBytes(32),execute:true}));await assert.rejects(()=>retain({expectedBusinessId:randomUUID(),execute:true}),/CONFIGURATION/);await assert.rejects(()=>retain({execute:true}),/OFFLINE_DATABASE/);assert.equal((await db.query('SELECT count(*)::int n FROM ms_b1_design.product_receipt_retention')).rows[0].n,0);});
 await test('Dry-run authenticates the exact backup without deleting any live evidence',async()=>{const result=await retain();assert.equal(result.dryRun,true);assert.equal(result.eligible,true);assert.equal((await manual.image(eCustomer,receiptId)).length,display.length);});
 await repo.onApplicationShutdown();await auth.onModuleDestroy();await db.end();closed=true;
 await test('Explicit offline purge and retry delete only the two receipt objects, retaining immutable history',async()=>{await waitOffline();assert.equal((await retain({execute:true})).purged,true);await waitOffline();assert.equal((await retain({execute:true})).purged,true);await assert.rejects(()=>storage.read(originalKey));await assert.rejects(()=>storage.read(displayKey));const check=client('ms_product_failure');await check.connect();try{assert.equal((await check.query('SELECT state FROM ms_b1_design.product_receipt_retention WHERE receipt_id=$1',[receiptId])).rows[0].state,'PURGED');assert.equal((await check.query('SELECT count(*)::int n FROM ms_b1_design.product_manual_receipt WHERE id=$1',[receiptId])).rows[0].n,1);assert.equal((await check.query('SELECT count(*)::int n FROM ms_b1_design.product_manual_review WHERE receipt_id=$1',[receiptId])).rows[0].n,1);assert.equal((await check.query("SELECT count(*)::int n FROM ms_b1_design.audit_log WHERE target_id=$1 AND action='manual.receipt.retention.purged'",[receiptId])).rows[0].n,1);}finally{await check.end();}});
 await freshScratch('ms_product_restore');const restored={...cfg,database:{...cfg.database,database:'ms_product_restore'},mediaRoot:path.join(folder,'retention-restored-'+randomUUID())};
 await test('Independent PostgreSQL restore recovers the pre-purge database and both exact receipt object hashes',async()=>{const restoredStorage=new LocalMediaStorage(restored.mediaRoot),result=await backupOperation({operation:'restore',cfg:restored,password,key,directory,storage:restoredStorage,restoreTarget:'ms_product_restore',tool:tools('ms_product_restore')});assert.equal(result.media,2);assert.equal(result.rowCountsMatch,true);let data=[];for await(const b of await restoredStorage.read(originalKey))data.push(b);assert.equal(sha(Buffer.concat(data)),sha(originalObject));data=[];for await(const b of await restoredStorage.read(displayKey))data.push(b);assert.equal(sha(Buffer.concat(data)),sha(displayObject));});
}finally{save('receipt-retention.json',{kind:'ACTUAL_POSTGRES_OFFLINE_RETENTION_AND_RESTORE',historicalFixture:true,passed:tests.length,tests});if(!closed){await repo.onApplicationShutdown();await auth.onModuleDestroy();await db.end();}}
