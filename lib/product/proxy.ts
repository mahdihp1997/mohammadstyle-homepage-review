import {NextRequest,NextResponse} from 'next/server';import {randomBytes,timingSafeEqual} from 'node:crypto';import {productBridge} from './config';import {allowedMvpRoute} from '../mvp/proxy';
const tokenPattern=/^[A-Za-z0-9_-]{43}$/;
const headers={'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','X-Frame-Options':'DENY'};
const error=(code:string,status:number)=>NextResponse.json({code},{status,headers});
const readCookie=(r:NextRequest,name:string)=>{const a=r.cookies.getAll(name);return a.length===1&&tokenPattern.test(a[0].value)?a[0].value:null;};
const equal=(a:string|null,b:string|null)=>!!a&&!!b&&a.length===b.length&&timingSafeEqual(Buffer.from(a),Buffer.from(b));
const booking=/^booking\/(?:read\/(?:catalog|history|booking|events|cancellation-preview)|commands\/(?:availability|quote|draft|hold|confirm|cancel|reschedule))$/;
const own=/^product\/(?:account|sessions(?:\/(?:revoke|revoke_all|revoke_others))?|payments\/(?:start|read)|admin\/(?:contact|read\/(?:bookings|customers|notifications|settings)|commands\/(?:operation|refund.request|settings|template|delivery.retry)))$/;
const login=/^product\/auth\/(?:request|activation-request|recovery-request|verify|admin-login|mfa-enroll|mfa|activate|recover)$/;
const shop=/^product\/shop\/(?:admin\/(?:read\/(?:settings|products)|configuration|products\/(?:save|stock|archive))|quote|checkout(?:\/status)?|orders\/(?:customer|admin|commands\/(?:cancel|request-cancellation|fulfill|decline-cancellation|accept-cancellation))|payment\/(?:methods|start))$/;
const content=/^product\/content\/(?:read|save|publish|unpublish|archive)$/;
const manual=/^product\/manual\/(?:methods|settings\/(?:read|save)|cards\/save|start|upload-context\/[a-f0-9-]{36}|receipts\/(?:upload\/[a-f0-9-]{36}|[a-f0-9-]{36}\/image)|payments\/read|review)$/;
export async function productProxy(req:NextRequest,route:string,publicMedia=false){
 let cfg;try{cfg=productBridge();}catch{return error('PRODUCT_CONFIGURATION_REQUIRED',503);}if(!cfg)return error('PRODUCT_DISABLED',404);
 if(req.headers.get('host')!==cfg.host||req.nextUrl.search.length>1024)return error('FORBIDDEN',403);
 const writing=!['GET','HEAD'].includes(req.method);
 if(!['GET','HEAD','POST','PUT'].includes(req.method))return error('METHOD_NOT_ALLOWED',405);
 if(req.headers.get('origin')&&req.headers.get('origin')!==cfg.origin)return error('FORBIDDEN',403);
 if(writing&&(req.headers.get('origin')!==cfg.origin||(['same-site','cross-site'].includes(req.headers.get('sec-fetch-site')??''))))return error('FORBIDDEN',403);
 const auth=login.test(route),catalog=['product/public/catalog','product/public/articles','product/public/shop'].includes(route),callback=/^product\/public\/payment-callback\/[a-f0-9-]{36}$/.test(route);
 if(publicMedia?!/^portfolio(?:\/[a-f0-9-]{36}\/(?:THUMB|DISPLAY|VIDEO))?$/.test(route):!auth&&!catalog&&!callback&&!own.test(route)&&!manual.test(route)&&!content.test(route)&&!shop.test(route)&&!booking.test(route)&&!allowedMvpRoute(route))return error('NOT_FOUND',404);
 const receiptUpload=/^product\/manual\/receipts\/upload\/([a-f0-9-]{36})$/.exec(route);
 if(manual.test(route)&&(route.endsWith('/image')?req.method!=='GET':req.method!=='POST'))return error('METHOD_NOT_ALLOWED',405);
 if((catalog||publicMedia)&&writing)return error('METHOD_NOT_ALLOWED',405);
 const cookie=readCookie(req,'ms_product_session'),csrf=readCookie(req,'ms_product_csrf');
 if(!auth&&!catalog&&!callback&&!publicMedia&&!cookie)return error('UNAUTHENTICATED',401);
 if(auth&&(!writing||!equal(readCookie(req,'ms_product_login_nonce'),req.headers.get('x-login-nonce'))))return error('LOGIN_CONTEXT_REQUIRED',403);
 if(writing&&!auth&&!callback&&!equal(csrf,req.headers.get('x-csrf-token')))return error('FORBIDDEN',403);
 if(receiptUpload){
  const key=req.headers.get('idempotency-key');if(!/^[a-f0-9-]{36}$/.test(key??''))return error('INVALID_FIELDS',422);
  try{const preflight=await fetch(cfg.api+'/api/v1/product/manual/upload-context/'+receiptUpload[1],{method:'POST',headers:{'x-product-bridge':cfg.key,'x-product-peer':cfg.environment==='test'?'127.0.0.1':(req.headers.get('x-real-ip')??'unknown'),origin:cfg.origin,'sec-fetch-site':'same-origin',cookie:'ms_session='+cookie,'x-csrf-token':csrf!,'idempotency-key':key!,'content-type':'application/json'},body:'{}',cache:'no-store',redirect:'error',signal:AbortSignal.timeout(10000)});
   if(!preflight.ok){const d=await preflight.json() as {code?:string};return error(typeof d.code==='string'?d.code:'RECEIPT_UPLOAD_NOT_ALLOWED',[401,403,404,409,412,422,429].includes(preflight.status)?preflight.status:503);}
  }catch{return error('UNAVAILABLE',503);}
 }
 // A forged cookie must not buy a 44MB allocation. Verify the real session and
 // an upload permission before reading any bytes; SQL later checks exact scope.
 if(route==='admin/media/upload'){
  try{const proof=await fetch(cfg.api+'/api/v1/session',{headers:{'x-product-bridge':cfg.key,'x-product-peer':cfg.environment==='test'?'127.0.0.1':(req.headers.get('x-real-ip')??'unknown'),origin:cfg.origin,cookie:'ms_session='+cookie},cache:'no-store',redirect:'error',signal:AbortSignal.timeout(5000)});
   if(!proof.ok){const status=[401,403,429].includes(proof.status)?proof.status:503;const denied=error(status===401?'UNAUTHENTICATED':status===403?'FORBIDDEN':status===429?'RATE_LIMITED':'UNAVAILABLE',status);if(status===429)denied.headers.set('Retry-After',proof.headers.get('retry-after')??'60');return denied;}
   const actor=await proof.json() as {assignments?:{permission:string}[]};if(!Array.isArray(actor.assignments))return error('UNAVAILABLE',503);if(!actor.assignments.some(a=>a.permission==='media.manage'))return error('FORBIDDEN',403);
  }catch{return error('UNAVAILABLE',503);}
 }
 let body:string|undefined;
 if(writing){if(!/^application\/json(?:;\s*charset=utf-8)?$/i.test(req.headers.get('content-type')??''))return error('INVALID_REQUEST',415);
  const limit=route==='product/shop/admin/configuration'?65536:receiptUpload?8*1024*1024:route==='admin/media/upload'?44*1024*1024:32768;const reader=req.body?.getReader();if(!reader)return error('INVALID_FIELDS',422);const chunks:Uint8Array[]=[];let size=0;
  for(;;){const part=await reader.read();if(part.done)break;size+=part.value.byteLength;if(size>limit){await reader.cancel();return error('UPLOAD_SIZE',413);}chunks.push(part.value);}body=Buffer.concat(chunks).toString('utf8');}
 const upstreamHeaders:Record<string,string>={'x-product-bridge':cfg.key,origin:cfg.origin,'sec-fetch-site':'same-origin',
  // Only the private HTTPS proxy may reach production Next; it overwrites X-Real-IP.
  'x-product-peer':cfg.environment==='test'?'127.0.0.1':(req.headers.get('x-real-ip')??'unknown')};
 if(cookie)upstreamHeaders.cookie='ms_session='+cookie;
 if(writing){upstreamHeaders['content-type']='application/json';for(const key of ['x-csrf-token','idempotency-key','if-match']){const v=req.headers.get(key);if(v)upstreamHeaders[key]=v;}}
 if(auth){upstreamHeaders['x-product-binding']=readCookie(req,'ms_product_login_nonce')!;
  // Production Next is reachable only through the HTTPS proxy which overwrites this header.
  upstreamHeaders['user-agent']=(req.headers.get('user-agent')??'browser').slice(0,120);}
 if(req.headers.get('range'))upstreamHeaders.range=req.headers.get('range')!;
 try{const r=await fetch(cfg.api+'/api/v1/'+route+req.nextUrl.search,{method:req.method,headers:upstreamHeaders,body,redirect:'error',cache:'no-store',signal:AbortSignal.timeout(route==='admin/media/upload'?180000:receiptUpload?120000:35000)});
  if(auth){const value=await r.json() as Record<string,unknown>&{session?:{token:string;csrf:string;maxAge:number}};const session=value.session;delete value.session;
   const res=NextResponse.json(value,{status:r.status,headers});if(r.ok&&session){if(!tokenPattern.test(session.token)||!tokenPattern.test(session.csrf)||!Number.isInteger(session.maxAge)||session.maxAge<1||session.maxAge>86400)return error('UNAVAILABLE',503);
    res.cookies.set('ms_product_session',session.token,{path:'/',httpOnly:true,secure:cfg.secure,sameSite:'strict',maxAge:session.maxAge});res.cookies.set('ms_product_csrf',session.csrf,{path:'/',httpOnly:false,secure:cfg.secure,sameSite:'strict',maxAge:session.maxAge});}
   return res;}
  if(r.ok&&/^product\/sessions\/(?:revoke|revoke_all|revoke_others)$/.test(route)){const value=await r.json() as{currentRevoked?:boolean};const res=NextResponse.json(value,{status:r.status,headers});if(value.currentRevoked)for(const name of ['ms_product_session','ms_product_csrf'])res.cookies.set(name,'',{path:'/',httpOnly:name.endsWith('session'),secure:cfg.secure,sameSite:'strict',maxAge:0});return res;}
  const responseHeaders=new Headers(headers);for(const key of ['content-type','content-length','content-range','accept-ranges','etag','retry-after','cross-origin-resource-policy']){const value=r.headers.get(key);if(value)responseHeaders.set(key,value);}
  if(/^product\/manual\/receipts\/[a-f0-9-]{36}\/image$/.test(route)){responseHeaders.set('Content-Security-Policy',"default-src 'none'; frame-ancestors 'none'; sandbox");responseHeaders.set('Content-Disposition','inline; filename="receipt.webp"');responseHeaders.set('Cache-Control','private, no-store');responseHeaders.set('Vary','Cookie');}
  const res=new NextResponse(req.method==='HEAD'?null:r.body,{status:r.status,headers:responseHeaders});
  if(r.ok&&(route==='session/revoke'||route==='product/sessions/revoke_all'))for(const name of ['ms_product_session','ms_product_csrf'])res.cookies.set(name,'',{path:'/',httpOnly:name.endsWith('session'),secure:cfg.secure,sameSite:'strict',maxAge:0});return res;
 }catch{return error('UNAVAILABLE',503);}
}
export function loginContext(req:NextRequest){let cfg;try{cfg=productBridge();}catch{return error('PRODUCT_CONFIGURATION_REQUIRED',503);}if(!cfg)return error('PRODUCT_DISABLED',404);
 if(req.headers.get('host')!==cfg.host||(req.headers.get('sec-fetch-site')&&req.headers.get('sec-fetch-site')!=='same-origin'))return error('FORBIDDEN',403);
 const nonce=readCookie(req,'ms_product_login_nonce')??randomBytes(32).toString('base64url');const res=NextResponse.json({nonce},{headers});res.cookies.set('ms_product_login_nonce',nonce,{path:'/',httpOnly:true,secure:cfg.secure,sameSite:'strict',maxAge:900});return res;
}
export async function paymentCallback(req:NextRequest,id:string){let cfg;try{cfg=productBridge();}catch{return error('PRODUCT_CONFIGURATION_REQUIRED',503);}if(!cfg||req.headers.get('host')!==cfg.host)return error('FORBIDDEN',403);
 const state=req.nextUrl.searchParams.get('state'),authority=req.nextUrl.searchParams.get('authority');if(!tokenPattern.test(state??'')||!authority||!/^[A-Za-z0-9_-]{8,160}$/.test(authority)||!/^([a-f0-9-]{36})$/.test(id))return error('INVALID_CALLBACK',422);
 try{const r=await fetch(cfg.api+'/api/v1/product/public/payment-callback/'+id,{method:'POST',headers:{'content-type':'application/json','x-product-bridge':cfg.key,origin:cfg.origin},body:JSON.stringify({state,authority}),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(10000)});if(!r.ok)return error('CALLBACK_NOT_ACCEPTED',422);const result=await r.json();if(result.accepted!==true||!['/account?payment=checking','/account/orders?payment=checking'].includes(result.returnPath))return error('CALLBACK_NOT_ACCEPTED',422);
  return NextResponse.redirect(new URL(result.returnPath,cfg.origin),{status:303,headers});}catch{return error('UNAVAILABLE',503);}
}
