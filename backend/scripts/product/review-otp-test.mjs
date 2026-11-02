// This convenience is confined to browser-bound customer OTPs in the isolated
// development profile. It never grants an administrator session or skips SQL.
import assert from 'node:assert/strict';
import {applyEnvironment,client,identify,save} from './local.mjs';
import {bootstrap} from './bootstrap.mjs';
import {identities} from './fixtures.mjs';
import {loadProductConfig} from '../../dist/product/config.js';
import {ProductAuthService} from '../../dist/product/auth.js';
import {keyed,normalizeMobile} from '../../dist/product/crypto.js';
applyEnvironment();
const base=loadProductConfig(),cfg=loadProductConfig({...process.env,NODE_ENV:'development',PRODUCT_REVIEW_OTP_AUTOFILL:'1'}),db=client(),ordinary=new ProductAuthService(base),review=new ProductAuthService(cfg),tests=[];
async function test(name,fn){await fn();tests.push({name,passed:true});console.log('PASS '+name);}
try{
 await db.connect();await identify(db,'ms_product_test');await bootstrap(db,base);await ordinary.onModuleInit();await review.onModuleInit();const ids=await identities(db,base,ordinary);
 await test('Autofill is OFF by default; all other runtime profiles reject its flag',async()=>{
  assert.equal(base.reviewOtpAutofill,false);
  for(const overrides of [{NODE_ENV:undefined},{NODE_ENV:'production'},{SMS_PROVIDER:'none'},{PUBLIC_ORIGIN:'http://127.0.0.1:3999'},{MOCK_GATEWAY_ORIGIN:'http://127.0.0.1:3998'},{PRODUCT_REVIEW_OTP_AUTOFILL:'yes'}])assert.throws(()=>loadProductConfig({...process.env,NODE_ENV:'development',PRODUCT_REVIEW_OTP_AUTOFILL:'1',...overrides}));
  const r=await ordinary.request('MOBILE_LOGIN',{mobile:ids.phone()},ids.context());assert.equal(r.testOtp,undefined);
 });
 await test('A returned development code still requires the same browser context and one-use verification',async()=>{
  const ctx=ids.context(),r=await review.request('MOBILE_LOGIN',{mobile:ids.phone()},ctx);assert.match(r.testOtp,/^\d{6}$/);
  await assert.rejects(()=>review.verify({challengeId:r.challengeId,code:r.testOtp},ids.context()),e=>e.getStatus?.()===401);
  const done=await review.verify({challengeId:r.challengeId,code:r.testOtp},ctx);assert.equal(done.authenticated,true);
  await assert.rejects(()=>review.verify({challengeId:r.challengeId,code:r.testOtp},ctx),e=>e.getStatus?.()===401);
 });
 await test('Activation and recovery never reveal their codes; owner SMS cannot replace password and TOTP',async()=>{
  const mobile=ids.phone(),ctx=ids.context(),inv=(await bootstrap(db,base,{inviteMobile:mobile})).invitation;
  const activation=await review.request('ADMIN_ACTIVATION',{mobile,invitation:inv.token},ctx);assert.equal(activation.testOtp,undefined);
  const owner=await ids.administrator();await db.query("UPDATE ms_b1_design.product_auth_challenge SET created_at=created_at-interval '61 seconds' WHERE mobile_lookup=$1",[keyed(base.identityKey,'mobile',normalizeMobile(owner.mobile))]);
  const recovery=await review.request('ADMIN_RECOVERY',{mobile:owner.mobile},owner.ctx);assert.equal(recovery.testOtp,undefined);
  await db.query("UPDATE ms_b1_design.product_auth_challenge SET created_at=created_at-interval '61 seconds' WHERE mobile_lookup=$1",[keyed(base.identityKey,'mobile',normalizeMobile(owner.mobile))]);
  const customer=await review.request('MOBILE_LOGIN',{mobile:owner.mobile},owner.ctx);assert.match(customer.testOtp,/^\d{6}$/);
  await assert.rejects(()=>review.verify({challengeId:customer.challengeId,code:customer.testOtp},owner.ctx),e=>e.getStatus?.()===409);
  const login=await review.adminLogin({username:owner.username,password:owner.password},owner.ctx);assert.equal(login.state,'MFA_REQUIRED');assert.equal(login.authenticated,undefined);assert.equal(login.testOtp,undefined);
 });
}finally{save('review-otp.json',{kind:'ACTUAL_POSTGRES_ISOLATED_REVIEW_OTP',passed:tests.length,tests});await ordinary.onModuleDestroy();await review.onModuleDestroy();await db.end();}
