import assert from "node:assert/strict";
import { randomUUID, randomInt } from "node:crypto";
import fs from "node:fs";
import { applyEnvironment, client, identify, save } from "./local.mjs";
import { bootstrap } from "./bootstrap.mjs";
import { loadProductConfig } from "../../dist/product/config.js";
import { ProductAuthService } from "../../dist/product/auth.js";
import { base32, digest, keyed, token, totp, normalizeMobile, seal, unseal } from "../../dist/product/crypto.js";
applyEnvironment();const cfg=loadProductConfig(),db=client(),api=client('ms_product_test','api'),service=new ProductAuthService(cfg);
const tests=[],sessions=[];let phoneSerial=randomInt(10000000,80000000);
const phone=()=> '090'+String(++phoneSerial).padStart(8,'0');
const context=()=>({binding:digest(token()),peer:keyed(cfg.identityKey,'peer',token()),device:'SYNTHETIC native auth test'});
const denied=async(fn,status)=>assert.rejects(fn,e=>e?.getStatus?.()===status);
async function test(name,fn){try{await fn();tests.push({name,passed:true});console.log('PASS '+name);}catch(e){tests.push({name,passed:false});console.error('FAIL '+name+' '+(e.code??'')+' '+String(e.message).slice(0,500));throw e;}}
async function request(mobile,ctx,kind='MOBILE_LOGIN',extra={}){
 const result=await service.request(kind,{mobile,...extra},ctx);
 const row=(await db.query('SELECT secret_ciphertext,otp_hash FROM ms_b1_design.product_auth_challenge WHERE id=$1',[result.challengeId])).rows[0];
 const payload=unseal(cfg.encryptionKey,row.secret_ciphertext,'otp:'+result.challengeId);
 assert.equal(row.otp_hash.length,32);return{...result,code:payload.code};
}
async function customer(){const mobile=phone(),ctx=context(),r=await request(mobile,ctx),v=await service.verify({challengeId:r.challengeId,code:r.code},ctx);assert.equal(v.authenticated,true);sessions.push(v.session);return{ctx,mobile,result:v};}
async function administrator(){
 const mobile=phone(),ctx=context(),invite=(await bootstrap(db,cfg,{inviteMobile:mobile})).invitation;
 const r=await request(mobile,ctx,'ADMIN_ACTIVATION',{invitation:invite.token});
 assert.equal((await service.verify({challengeId:r.challengeId,code:r.code},ctx)).state,'ACTIVATION_READY');
 const username='qa_'+randomUUID().slice(0,8),password=token();
 const ready=await service.activate({challengeId:r.challengeId,username,password},ctx);
 const counter=BigInt(Math.floor(Date.now()/30000)),result=await service.mfa({challengeId:ready.challengeId,code:totp(ready.secret,counter)},ctx);
 assert.equal(result.authenticated,true);assert.equal(result.recoveryCodes.length,10);sessions.push(result.session);
 return{mobile,ctx,username,password,secret:ready.secret,counter,result};
}
try{
 await db.connect();await identify(db,'ms_product_test');await api.connect();await service.onModuleInit();
 await test('Iranian mobile normalization accepts Persian/Arabic/E164 and rejects foreign/invalid numbers',async()=>{
  for(const value of ['۰۹۱۲۱۲۳۴۵۶۷','٠٩١٢١٢٣٤٥٦٧','09121234567','+989121234567','00989121234567'])assert.equal(normalizeMobile(value),'+989121234567');
  for(const value of ['+12025550123','0912123','+9891212345670',{},'9'.repeat(100)])assert.throws(()=>normalizeMobile(value));
 });
 await test('authenticated encryption binds purposes and RFC6238 SHA1 vector matches six digits',async()=>{
  const ciphertext=seal(cfg.encryptionKey,{value:'ephemeral'},'bound-purpose');assert.equal(unseal(cfg.encryptionKey,ciphertext,'bound-purpose').value,'ephemeral');
  assert.throws(()=>unseal(cfg.encryptionKey,ciphertext,'other-purpose'));
  assert.equal(totp(base32(Buffer.from('12345678901234567890')),1n),'287082');
 });
 await test('OTP denial commits attempt limits and one challenge cannot be brute-forced',async()=>{
  const ctx=context(),r=await request(phone(),ctx);for(let i=0;i<5;i++)await denied(()=>service.verify({challengeId:r.challengeId,code:r.code==='000000'?'111111':'000000'},ctx),401);
  const row=(await db.query('SELECT attempts,state FROM ms_b1_design.product_auth_challenge WHERE id=$1',[r.challengeId])).rows[0];assert.equal(row.attempts,5);assert.equal(row.state,'LOCKED');
  await denied(()=>service.verify({challengeId:r.challengeId,code:r.code},ctx),401);
 });
 await test('stolen challenge/code without the browser binding and injected authority cannot authenticate',async()=>{
  const ctx=context(),r=await request(phone(),ctx);await denied(()=>service.verify({challengeId:r.challengeId,code:r.code},context()),401);
  await denied(()=>service.verify({challengeId:r.challengeId,code:r.code,userId:randomUUID()},ctx),422);
  const v=await service.verify({challengeId:r.challengeId,code:r.code},ctx);assert.equal(v.authenticated,true);sessions.push(v.session);
 });
 await test('verified OTP creates a single canonical customer and existing core session authorization accepts it',async()=>{
  const f=await customer(),a=(await api.query('SELECT ms_b1_design.b1b_session($1) r',[digest(f.result.session.token)])).rows[0].r;
  assert.equal(a.userId,f.result.userId);assert.equal(a.businessId,cfg.businessId);assert.ok(a.assignments.every(x=>x.permission==='booking.customer'));
  const count=(await db.query("SELECT count(*)::int n FROM ms_b1_design.auth_identity WHERE provider='IRAN_MOBILE' AND subject_hash=$1",[keyed(cfg.identityKey,'mobile',normalizeMobile(f.mobile))])).rows[0].n;assert.equal(count,1);
 });
 await test('expired and consumed OTPs fail and consumed encrypted code material is erased',async()=>{
  const ctx=context(),r=await request(phone(),ctx);await db.query("UPDATE ms_b1_design.product_auth_challenge SET created_at=clock_timestamp()-interval '10 minutes',expires_at=clock_timestamp()-interval '1 second' WHERE id=$1",[r.challengeId]);
  await denied(()=>service.verify({challengeId:r.challengeId,code:r.code},ctx),401);
  const ctx2=context(),q=await request(phone(),ctx2),v=await service.verify({challengeId:q.challengeId,code:q.code},ctx2);sessions.push(v.session);
  await denied(()=>service.verify({challengeId:q.challengeId,code:q.code},ctx2),401);
  const row=(await db.query('SELECT otp_hash,secret_ciphertext FROM ms_b1_design.product_auth_challenge WHERE id=$1',[q.challengeId])).rows[0];assert.equal(row.otp_hash,null);assert.equal(row.secret_ciphertext,null);
 });
 await test('session list and revocation are identity-bound and current revocation is authoritative',async()=>{
  const a=await customer(),b=await customer(),list=await service.sessions(digest(a.result.session.token),Buffer.alloc(32),'list');assert.equal(list.items.length,1);
  const other=(await service.sessions(digest(b.result.session.token),Buffer.alloc(32),'list')).items[0].id;
  await assert.rejects(()=>service.sessions(digest(a.result.session.token),digest(a.result.session.csrf),'revoke',other),e=>e.code==='MS404');
  await service.sessions(digest(a.result.session.token),digest(a.result.session.csrf),'revoke_all');
  await assert.rejects(()=>api.query('SELECT ms_b1_design.b1b_session($1)',[digest(a.result.session.token)]),e=>e.code==='MS401');
  assert.equal((await api.query('SELECT ms_b1_design.b1b_session($1) r',[digest(b.result.session.token)])).rows[0].r.authenticated,true);
 });
 await test('admin invitation needs verified OTP, password setup and MFA before existing admin permissions activate',async()=>{
  const a=await administrator(),actor=(await api.query('SELECT ms_b1_design.b1b_session($1) r',[digest(a.result.session.token)])).rows[0].r;
  assert.ok(actor.assignments.some(x=>x.permission==='security.manage'));
  const grant=await service.adminLogin({username:a.username,password:a.password},a.ctx);assert.equal(grant.state,'MFA_REQUIRED');assert.equal(grant.session,undefined);
  await denied(()=>service.mfa({challengeId:grant.challengeId,code:totp(a.secret,a.counter)},a.ctx),401);
  await denied(()=>service.adminLogin({username:a.username,password:'wrong-password'},a.ctx),401);
 });
 await test('MFA replay and simultaneous grants admit the same TOTP counter only once',async()=>{
  const a=await administrator(),grants=await Promise.all([service.adminLogin({username:a.username,password:a.password},a.ctx),service.adminLogin({username:a.username,password:a.password},a.ctx)]);
  const code=totp(a.secret,BigInt(Math.floor(Date.now()/30000))+1n);
  const outcomes=await Promise.allSettled(grants.map(g=>service.mfa({challengeId:g.challengeId,code},a.ctx)));
  assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);for(const x of outcomes)if(x.status==='fulfilled')sessions.push(x.value.session);
 });
 await test('recovery needs verified mobile plus unused recovery code, rotates credentials/MFA and revokes old sessions',async()=>{
  const a=await administrator();await db.query("UPDATE ms_b1_design.product_auth_challenge SET created_at=created_at-interval '61 seconds' WHERE mobile_lookup=$1",[keyed(cfg.identityKey,'mobile',normalizeMobile(a.mobile))]);
  const r=await request(a.mobile,a.ctx,'ADMIN_RECOVERY');assert.equal((await service.verify({challengeId:r.challengeId,code:r.code},a.ctx)).state,'RECOVERY_READY');
  await denied(()=>service.recover({challengeId:r.challengeId,recoveryCode:'invalid',password:token()},a.ctx),401);
  const newPassword=token(),result=await service.recover({challengeId:r.challengeId,recoveryCode:a.result.recoveryCodes[0],password:newPassword},a.ctx);
  assert.equal(result.state,'MFA_ENROLLMENT_REQUIRED');
  await assert.rejects(()=>api.query('SELECT ms_b1_design.b1b_session($1)',[digest(a.result.session.token)]),e=>e.code==='MS401');
  await denied(()=>service.adminLogin({username:a.username,password:a.password},a.ctx),401);
  const finished=await service.mfa({challengeId:result.challengeId,code:totp(result.secret,BigInt(Math.floor(Date.now()/30000)))},a.ctx);sessions.push(finished.session);
  assert.equal(finished.authenticated,true);assert.equal(finished.recoveryCodes.length,10);
 });
 await test('ordinary API cannot access credential tables, issue sessions or disable owner MFA',async()=>{
  await assert.rejects(()=>api.query('SELECT * FROM ms_b1_design.product_admin_credential'),e=>e.code==='42501');
  await assert.rejects(()=>api.query('SELECT ms_b1_design.product_issue_session($1,$2,$3,$4,$5)',[randomUUID(),'MFA',digest(token()),digest(token()),'forged']),e=>e.code==='42501');
  await assert.rejects(()=>db.query("UPDATE ms_b1_design.role SET product_mfa_required=false WHERE business_id=$1 AND role_key='OWNER'",[cfg.businessId]),e=>e.code==='MS403');
 });
}finally{
 for(const s of sessions)if(s?.token)await db.query("UPDATE ms_b1_design.auth_session SET revoked_at=clock_timestamp(),revocation_reason='TEST_CLEANUP' WHERE token_hash=$1 AND product_environment='test'",[digest(s.token)]).catch(()=>{});
 await service.onModuleDestroy();await Promise.allSettled([db.end(),api.end()]);
 save('auth.json',{kind:'ACTUAL_PRODUCT_AUTH_POSTGRES_SERVICE',passed:tests.filter(t=>t.passed).length,failed:tests.filter(t=>!t.passed).length,tests});
}
