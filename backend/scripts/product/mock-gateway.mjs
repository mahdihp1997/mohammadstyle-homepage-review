// A real HTTP test double with a durable isolated ledger. Never a live gateway.
import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {randomBytes,timingSafeEqual} from 'node:crypto';
import {applyEnvironment,folder} from './local.mjs';import {loadProductConfig} from '../../dist/product/config.js';import {assertMock} from '../../dist/product/providers.js';import {seal,digest} from '../../dist/product/crypto.js';
applyEnvironment();const cfg=loadProductConfig();assertMock(cfg);const origin=cfg.mockGatewayOrigin??'http://127.0.0.1:3117';
const file=path.join(folder,'mock-provider-ledger.json');
let ledger=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,'utf8')):{payments:{},sms:{},refunds:{},controls:{}};
const save=()=>{fs.mkdirSync(folder,{recursive:true});fs.writeFileSync(file+'.tmp',JSON.stringify(ledger),{mode:0o600});fs.renameSync(file+'.tmp',file);};
const amount=v=>typeof v==='string'&&/^[1-9]\d{0,18}$/.test(v)&&BigInt(v)<=9223372036854775807n;
const keyOk=req=>typeof req.headers['x-mock-key']==='string'&&req.headers['x-mock-key'].length===cfg.bridgeKey.length&&timingSafeEqual(Buffer.from(req.headers['x-mock-key']),Buffer.from(cfg.bridgeKey));
const json=(res,status,body)=>{res.writeHead(status,{'content-type':'application/json','cache-control':'no-store','x-content-type-options':'nosniff'});res.end(JSON.stringify(body));};
const server=http.createServer(async(req,res)=>{try{
 const url=new URL(req.url,origin),authority=url.pathname.split('/')[2];
 if(url.pathname.startsWith('/pay/')){
  const p=Object.values(ledger.payments).find(x=>x.authority===authority);if(!p)return json(res,404,{code:'NOT_FOUND'});
  if(req.method==='POST'){
   if(req.headers.origin!==origin||req.headers['content-type']!=='application/x-www-form-urlencoded')return json(res,403,{code:'ORIGIN'});
   let raw='';for await(const c of req){raw+=c;if(raw.length>200)return json(res,413,{});}const d=new URLSearchParams(raw),action=d.get('action');
   if(p.state==='pending'&&['paid','declined'].includes(action)){p.state=action;if(action==='paid')p.reference='mock_tx_'+randomBytes(16).toString('hex');save();}
   const callback=new URL(p.callbackUrl);callback.searchParams.set('authority',p.authority);callback.searchParams.set('status',p.state);
   res.writeHead(303,{location:callback.href,'cache-control':'no-store','referrer-policy':'no-referrer'});return res.end();
  }
  res.writeHead(200,{'content-type':'text/html; charset=utf-8','cache-control':'no-store','content-security-policy':`default-src 'none'; style-src 'unsafe-inline'; form-action 'self' ${cfg.origin}; frame-ancestors 'none'`,'referrer-policy':'same-origin'});
  return res.end(`<!doctype html><html lang="fa" dir="rtl"><meta name="viewport" content="width=device-width"><title>درگاه آزمایش ایزوله</title><style>body{background:#101112;color:#ead6b3;font:18px Tahoma;margin:10vh auto;max-width:550px;padding:24px}button{font:inherit;padding:16px;margin:12px;background:#dbc092;border:0;border-radius:12px}strong{display:block;margin:30px 0}</style><h1>پرداخت آزمایشی</h1><p>این درگاه فقط برای آزمون نرم‌افزار است؛ هیچ پول واقعی جابه‌جا نمی‌شود.</p><strong>${p.amountRial} ریال</strong><p>${p.state}</p><form method="post"><button name="action" value="paid">تأیید آزمایشی</button><button name="action" value="declined">انصراف</button></form></html>`);
 }
 if(req.method!=='POST'||!keyOk(req))return json(res,403,{code:'FORBIDDEN'});
 let raw='';for await(const c of req){raw+=c;if(raw.length>16384)return json(res,413,{});}const d=JSON.parse(raw);
 const control=ledger.controls[url.pathname];if(control?.remaining>0){control.remaining--;save();if(control.mode==='reject')return json(res,503,{});if(control.mode==='malformed'){res.writeHead(200);return res.end('{');}}
 if(url.pathname==='/request'){
  if(!/^[a-f0-9-]{36}$/.test(d.id)||!amount(d.amountRial)||d.currency!=='IRR'||!d.callbackUrl.startsWith(cfg.origin+'/api/product/payment/callback/'))return json(res,422,{});
  let p=ledger.payments[d.id];if(p&&(p.amountRial!==d.amountRial||p.callbackUrl!==d.callbackUrl))return json(res,409,{});
  if(!p){p={...d,authority:'mock_auth_'+randomBytes(16).toString('hex'),state:'pending'};ledger.payments[d.id]=p;save();}
  if(control?.mode==='lost-after-commit'&&control.remaining>=0&&control.remaining<1){delete ledger.controls[url.pathname];save();return req.socket.destroy();}
  return json(res,200,{status:'created',authority:p.authority,hostedUrl:origin+'/pay/'+p.authority});
 }
 if(url.pathname==='/verify'){const p=Object.values(ledger.payments).find(x=>x.authority===d.authority);if(!p||p.amountRial!==d.amountRial||d.currency!=='IRR')return json(res,200,{status:'unknown'});
  return json(res,200,p.state==='paid'?{status:'paid',authority:p.authority,amountRial:p.amountRial,currency:'IRR',reference:p.reference}:{status:p.state});}
 if(url.pathname==='/refund'){const p=Object.values(ledger.payments).find(x=>x.authority===d.authority);if(!p||p.state!=='paid'||!amount(d.amountRial)||BigInt(d.amountRial)>BigInt(p.amountRial))return json(res,200,{status:'declined'});
  const prior=ledger.refunds[d.id];if(prior&&(prior.authority!==d.authority||prior.amountRial!==d.amountRial))return json(res,409,{});
  const total=Object.values(ledger.refunds).filter(x=>x.authority===d.authority&&x.id!==d.id).reduce((n,x)=>n+BigInt(x.amountRial),0n);if(total+BigInt(d.amountRial)>BigInt(p.amountRial))return json(res,200,{status:'declined'});
  const r=prior??{...d,reference:'mock_refund_'+randomBytes(16).toString('hex')};ledger.refunds[d.id]=r;save();return json(res,200,{status:'verified',reference:r.reference});}
 if(url.pathname==='/sms'){
  if(!/^[a-f0-9-]{36}$/.test(d.dedupeKey)||!/^\+989\d{9}$/.test(d.mobile))return json(res,422,{});
  const hash=digest(JSON.stringify(d)).toString('hex');let p=ledger.sms[d.dedupeKey];if(p&&p.hash!==hash)return json(res,409,{});
  if(!p){p={hash,ciphertext:seal(cfg.encryptionKey,d,'mock-sms:'+d.dedupeKey),receipt:'mock_sms_'+randomBytes(16).toString('hex')};ledger.sms[d.dedupeKey]=p;save();}
  if(control?.mode==='lost-after-commit'&&control.remaining===0){delete ledger.controls[url.pathname];save();return req.socket.destroy();}return json(res,200,{receipt:p.receipt});
 }
 if(url.pathname==='/control'){if(!['/request','/verify','/sms','/refund'].includes(d.route)||!['reject','malformed','lost-after-commit'].includes(d.mode)||!Number.isInteger(d.count)||d.count<1||d.count>5)return json(res,422,{});ledger.controls[d.route]={mode:d.mode,remaining:d.count};save();return json(res,200,{configured:true});}
 return json(res,404,{code:'NOT_FOUND'});
 }catch{return json(res,422,{code:'INVALID_REQUEST'});}});
server.listen(Number(new URL(origin).port),'127.0.0.1',()=>console.log('Isolated synthetic HTTP payment/SMS provider ready; payloads and secrets withheld.'));
process.on('SIGTERM',()=>server.close());
