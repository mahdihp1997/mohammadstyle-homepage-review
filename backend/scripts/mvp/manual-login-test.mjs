// Real PostgreSQL + Nest HTTP. Uses only the marked local review DB and existing synthetic identities.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { createHash, randomBytes, randomUUID } from "node:crypto";
import pg from "pg";
import http from "node:http";
import { client, identify, connection, root } from "./local.mjs";
import { createMvpApp } from "../../dist/mvp/app.js";
import { LocalMediaStorage } from "../../dist/mvp/storage.js";
import { LocalLoginService, validateLocalLoginOptions } from "../../dist/mvp/local-login.js";
if (process.env.APP_ENV !== "mvp-local" || process.env.NODE_ENV === "production") throw Error("Local test environment required");
const dir=path.join(root,".local/mvp"), config=JSON.parse(fs.readFileSync(path.join(dir,"manual-login.json"))),
  fixture=JSON.parse(fs.readFileSync(path.join(dir,"review-session.json"))),
  password=fs.readFileSync(path.join(dir,"owner-login.txt"),"utf8").match(/^Password: (.+)$/m)[1],
  hash=s=>createHash("sha256").update(s).digest(), results=[], issued=[];
const db=client("ms_mvp_dev"), api=client("ms_mvp_dev","api");
const issuer=new pg.Client({...connection("ms_mvp_dev"),user:"ms_mvp_local_login",password:config.databasePassword});
let app;
const service=new LocalLoginService(config);
const req=(body={username:config.username,password},overrides={})=>({method:"POST",body,requestId:randomUUID(),socket:{remoteAddress:"127.0.0.1"},headers:{host:"127.0.0.1:3112",origin:"http://127.0.0.1:3112","sec-fetch-site":"same-origin","content-type":"application/json","x-local-login-bridge":config.bridgeSecret,...overrides}});
const denied=async(fn,status)=>{await assert.rejects(fn,e=>e?.getStatus?.()===status);};
async function test(name,fn){try{await fn();results.push({name,passed:true});console.log("PASS "+name);}catch(e){results.push({name,passed:false});throw Error("Failed: "+name,{cause:e});}}
try{
 await db.connect();await identify(db,"ms_mvp_dev");await api.connect();await issuer.connect();await service.onModuleInit();
 await test("isolated issuer has EXECUTE only; existing API cannot issue sessions",async()=>{
  await assert.rejects(()=>issuer.query("SELECT * FROM ms_b1_design.app_user"),e=>e.code==='42501');
  await assert.rejects(()=>issuer.query("SET ROLE ms_b1a_migrator"),e=>e.code==='42501');
  await assert.rejects(()=>api.query("SELECT ms_b1_design.mvp_local_issue_session($1,$2,$3,$4,$5)",[config.userId,config.businessId,randomBytes(32),randomBytes(32),randomUUID()]),e=>e.code==='42501');
 });
 await test("production and absent configuration fail closed",async()=>{
  const prior=process.env.NODE_ENV;try{process.env.NODE_ENV='production';assert.throws(()=>validateLocalLoginOptions(config));await denied(()=>service.login(req()),404);}finally{if(prior===undefined)delete process.env.NODE_ENV;else process.env.NODE_ENV=prior;}
  await denied(()=>new LocalLoginService(null).login(req()),404);
 });
 await test("forged bridge, Host, Origin and cross-site requests cannot log in",async()=>{
  for(const headers of [{host:'evil.test:3112'},{origin:'http://evil.test'},{'sec-fetch-site':'cross-site'},{'x-local-login-bridge':'wrong'}])await denied(()=>service.login(req(undefined,headers)),403);
 });
 await test("caller-supplied user, tenant, role and malformed credentials are rejected",async()=>{
  for(const extra of [{userId:fixture.accounts.desktop.userId},{businessId:randomUUID()},{role:'owner'}])await denied(()=>service.login(req({username:config.username,password,...extra})),422);
  await denied(()=>service.login(req({username:[],password})),422);
  await denied(()=>service.login(req(undefined,{'content-type':'text/plain'})),415);
 });
 await test("unknown username and incorrect password give identical denial",async()=>{
  await denied(()=>service.login(req({username:'unknown-user',password})),401);
  await denied(()=>service.login(req({username:config.username,password:'wrong-password'})),401);
 });
 await test("separate logins mint fresh DB-backed tokens; no fixture token reuse",async()=>{
  for(let i=0;i<2;i++){const value=await service.login(req());assert.match(value.token,/^[A-Za-z0-9_-]{43}$/);assert.match(value.csrf,/^[A-Za-z0-9_-]{43}$/);assert.equal(value.maxAge,3600);issued.push(value);}
  assert.ok(issued[0].token!==issued[1].token&&issued[0].csrf!==issued[1].csrf&&issued[0].token!==fixture.accounts.owner.token);
  for(const value of issued){const r=await api.query("SELECT ms_b1_design.b1b_session($1) r",[hash(value.token)]);assert.equal(r.rows[0].r.userId,config.userId);assert.equal(r.rows[0].r.businessId,config.businessId);}
  const row=(await db.query("SELECT extract(epoch from expires_at-created_at) absolute,extract(epoch from idle_expires_at-created_at) idle FROM ms_b1_design.auth_session WHERE token_hash=$1",[hash(issued[1].token)])).rows[0];assert.ok(Number(row.idle)>890&&Number(row.idle)<910);assert.ok(Number(row.absolute)>3590&&Number(row.absolute)<3610);
 });
 await test("revoking one login leaves the other session valid",async()=>{
  const a=issued[0];await api.query("SELECT ms_b1_design.b1b_command($1,$2,'session',NULL,NULL,NULL,$3,$4,'{}'::jsonb)",[hash(a.token),hash(a.csrf),randomUUID(),randomUUID()]);
  await assert.rejects(()=>api.query("SELECT ms_b1_design.b1b_session($1)",[hash(a.token)]),e=>e.code==='MS401');
  assert.equal((await api.query("SELECT ms_b1_design.b1b_session($1) r",[hash(issued[1].token)])).rows[0].r.authenticated,true);
 });
 await test("idle expiry is authoritative in PostgreSQL",async()=>{
  const value=await service.login(req());issued.push(value);
  await db.query("UPDATE ms_b1_design.auth_session SET idle_expires_at=clock_timestamp()+interval '1 second' WHERE token_hash=$1",[hash(value.token)]);
  await new Promise(r=>setTimeout(r,1200));
  await assert.rejects(()=>api.query("SELECT ms_b1_design.b1b_session($1)",[hash(value.token)]),e=>e.code==='MS401');
 });
 await test("customer-only identity cannot acquire admin login even through issuer",async()=>{
  await assert.rejects(()=>issuer.query("SELECT ms_b1_design.mvp_local_issue_session($1,$2,$3,$4,$5)",[fixture.accounts.desktop.userId,config.businessId,randomBytes(32),randomBytes(32),randomUUID()]),e=>e.code==='MS403');
 });
 await test("DB session admission cap is atomic and rolls back without rotating other sessions",async()=>{
  await issuer.query('BEGIN');let capped=false;try{for(let i=0;i<21;i++){await issuer.query('SAVEPOINT admission');try{await issuer.query("SELECT ms_b1_design.mvp_local_issue_session($1,$2,$3,$4,$5)",[config.userId,config.businessId,randomBytes(32),randomBytes(32),randomUUID()]);}catch(e){await issuer.query('ROLLBACK TO SAVEPOINT admission');if(e.code==='MS429'){capped=true;break;}throw e;}}assert.ok(capped);}finally{await issuer.query('ROLLBACK');}
 });
 await test("real Nest transport rejects duplicate JSON and issues a valid session",async()=>{
  app=await createMvpApp({...connection('ms_mvp_dev','api'),origin:'http://127.0.0.1:3112'},new LocalMediaStorage(path.join(dir,'media')),fixture.businessId,config);
  await app.listen(0,'127.0.0.1');const port=app.getHttpServer().address().port;
  const headers={...req().headers};
  const post=body=>new Promise((resolve,reject)=>{const q=http.request({hostname:'127.0.0.1',port,path:'/api/v1/local-review/login',method:'POST',headers},r=>{const chunks=[];r.on('data',c=>chunks.push(c));r.on('end',()=>resolve({status:r.statusCode,body:JSON.parse(Buffer.concat(chunks).toString())}));});q.on('error',reject);q.end(body);});
  let r=await post('{"username":"owner","username":"other","password":"x"}');assert.equal(r.status,422);
  r=await post(JSON.stringify({username:config.username,password}));assert.equal(r.status,201);const value=r.body;issued.push(value);assert.equal((await api.query("SELECT ms_b1_design.b1b_session($1) r",[hash(value.token)])).rows[0].r.authenticated,true);
 });
 await test("failed credentials are throttled before unlimited password hashing",async()=>{
  for(let i=0;i<6;i++)await denied(()=>service.login(req({username:config.username,password:'wrong-password'})),401);
  await denied(()=>service.login(req()),429);
 });
}finally{
 for(const value of issued)await db.query("UPDATE ms_b1_design.auth_session SET revoked_at=clock_timestamp() WHERE token_hash=$1",[hash(value.token)]).catch(()=>{});
 await app?.close();await service.onModuleDestroy();await Promise.allSettled([db.end(),api.end(),issuer.end()]);
 fs.writeFileSync(path.join(dir,'results/manual-login.json'),JSON.stringify({passed:results.filter(r=>r.passed).length,failed:results.filter(r=>!r.passed).length,tests:results},null,2));
}
