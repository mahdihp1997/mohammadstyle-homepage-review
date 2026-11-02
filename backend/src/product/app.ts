import 'reflect-metadata';
import {timingSafeEqual} from 'node:crypto';
import {Body,Controller,Get,Post,Param,Query,Req,Res,UseGuards,Global,Module,HttpException,HttpCode} from '@nestjs/common';
import {ManualPaymentService} from './manual.js';
import {ShopService} from './shop.js';
import {NestFactory} from '@nestjs/core';import type {NestExpressApplication} from '@nestjs/platform-express';
import {ADMIN_OPTIONS,SessionGuard,evidence,type Request,type Response} from '../admin/security.js';
import {AdminRepository} from '../admin/repository.js';import {AdminCommands,IamModule,BusinessModule,BranchModule,CatalogModule,OfferingModule} from '../admin/modules.js';
import {WorkforceCommands,WorkforceController} from '../workforce/modules.js';import {WorkforceRepository} from '../workforce/repository.js';
import {PricingController} from '../pricing/app.js';import {PricingRepository} from '../pricing/repository.js';import {BookingController} from '../booking/app.js';import {BookingRepository} from '../booking/repository.js';
import {uniqueJson} from '../pricing/canonical.js';import {requestDiagnostics} from '../observability.js';import {uuid} from '../admin/contracts.js';
import {MvpRepository} from '../mvp/repository.js';import {MvpFilter,PortalController,PublicGalleryController,StorageProvider,publicBusiness} from '../mvp/app.js';import {MediaService} from '../mvp/media.js';import type {MediaStorage} from '../mvp/storage.js';
import {ProductRepository} from './repository.js';import {PRODUCT_CONFIG,ProductAuthService,fields,type AuthContext} from './auth.js';import type {ProductConfig} from './config.js';import {digest,keyed,unseal} from './crypto.js';
import {Inject} from '@nestjs/common';

function boundedString(v:unknown,max=100){if(typeof v!=='string'||v.length>max)throw new HttpException({code:'INVALID_FIELDS'},422);return v;}
@Controller('api/v1/product/auth')
class AuthController {
 constructor(private readonly auth:ProductAuthService,@Inject(PRODUCT_CONFIG)private readonly cfg:ProductConfig){}
 private context(req:Request):AuthContext{const b=req.headers['x-product-binding'],peer=req.headers['x-product-peer'];if(typeof b!=='string'||!/^[A-Za-z0-9_-]{43}$/.test(b)||typeof peer!=='string'||peer.length>80)throw new HttpException({code:'INVALID_LOGIN_CONTEXT'},403);
  return {binding:digest(b),peer:keyed(this.cfg.identityKey,'peer',peer),device:typeof req.headers['user-agent']==='string'?req.headers['user-agent'].slice(0,120):'browser'};}
 @Post(':action') @HttpCode(200)
 async action(@Req()req:Request,@Param('action')action:string,@Body()body:unknown){const ctx=this.context(req);
  switch(action){case 'request':return this.auth.request('MOBILE_LOGIN',body,ctx);case 'activation-request':return this.auth.request('ADMIN_ACTIVATION',body,ctx);case 'recovery-request':return this.auth.request('ADMIN_RECOVERY',body,ctx);case 'verify':return this.auth.verify(body,ctx);case 'admin-login':return this.auth.adminLogin(body,ctx);case 'mfa-enroll':return this.auth.adminLogin(body,ctx,true);case 'mfa':return this.auth.mfa(body,ctx);case 'activate':return this.auth.activate(body,ctx);case 'recover':return this.auth.recover(body,ctx);default:throw new HttpException('Not found',404);}
 }
}
@Controller('api/v1/product/public')
class PublicController {
 constructor(private readonly repo:ProductRepository){}
 @Get('catalog')catalog(){return this.repo.rpc('product_public_catalog',[]);}
 @Get('shop')shop(@Query()q:Record<string,unknown>){if(Object.keys(q).some(k=>!['view','slug','offset'].includes(k)))throw new HttpException({code:'INVALID_QUERY'},422);const view=q.view===undefined?'catalog':boundedString(q.view,10),slug=q.slug===undefined?null:boundedString(q.slug,100),offset=q.offset===undefined?'0':boundedString(q.offset,5);if(!/^\d{1,5}$/.test(offset))throw new HttpException({code:'INVALID_QUERY'},422);return this.repo.rpc('shop_public',[this.repo.cfg.businessId,view,slug,Number(offset)]);}
 @Get('articles')articles(@Query()q:Record<string,unknown>){if(Object.keys(q).some(k=>!['slug','offset'].includes(k)))throw new HttpException({code:'INVALID_QUERY'},422);const slug=q.slug===undefined?null:boundedString(q.slug,100),offset=q.offset===undefined?'0':boundedString(q.offset,5);if(!/^\d{1,5}$/.test(offset))throw new HttpException({code:'INVALID_QUERY'},422);return this.repo.rpc('product_content_public',[this.repo.cfg.businessId,slug,Number(offset)]);}
 @Post('payment-callback/:id') @HttpCode(200)
 callback(@Param('id')id:string,@Body()body:unknown){const d=fields(body,['state','authority']),state=boundedString(d.state,43),authority=boundedString(d.authority,160);if(!/^[A-Za-z0-9_-]{43}$/.test(state))throw new HttpException('Invalid callback',422);return this.repo.rpc('product_payment_callback_route',[uuid(id),digest(state),authority]);}
 @Get('health')health(){return this.repo.ready();}
}
@Controller('api/v1/product') @UseGuards(SessionGuard)
class ProductController {
 constructor(private readonly repo:ProductRepository,private readonly auth:ProductAuthService,private readonly manual:ManualPaymentService){}
 @Get('account')account(@Req()req:Request){return this.repo.rpc('product_account',[evidence(req).hash]);}
 @Post('content/read') @HttpCode(200)
 contentRead(@Req()req:Request,@Body()body:unknown){const d=fields(body,['id']);return this.repo.rpc('product_content_read',[evidence(req).hash,d.id===null?null:uuid(d.id)]);}
 @Post('content/:op') @HttpCode(200)
 contentWrite(@Req()req:Request,@Param('op')op:string,@Body()body:unknown){if(!['save','publish','unpublish','archive'].includes(op))throw new HttpException('Not found',404);fields(body,['id','version','slug','document']);const e=evidence(req);return this.repo.rpc('product_content_command',[e.hash,e.csrf,uuid(req.headers['idempotency-key']),op,body]);}
 @Post('account') @HttpCode(200)
 update(@Req()req:Request,@Body()body:unknown){const d=fields(body,['displayName','notificationsOptIn']);if(typeof d.notificationsOptIn!=='boolean')throw new HttpException('Invalid preference',422);const e=evidence(req);return this.repo.rpc('product_account_update',[e.hash,e.csrf,boundedString(d.displayName,100),d.notificationsOptIn]);}
 @Get('sessions')sessions(@Req()req:Request){const e=evidence(req);return this.auth.sessions(e.hash,e.csrf,'list');}
 @Post('sessions/:action') @HttpCode(200)
 revoke(@Req()req:Request,@Param('action')action:string,@Body()body:unknown){const d=fields(body,['id']);if(!['revoke','revoke_all','revoke_others'].includes(action))throw new HttpException('Not found',404);const e=evidence(req);return this.auth.sessions(e.hash,e.csrf,action as 'revoke'|'revoke_all'|'revoke_others',d.id===null?null:uuid(d.id));}
 @Post('payments/start') @HttpCode(200)
 async start(@Req()req:Request,@Body()body:unknown){const d=fields(body,['bookingId','version']),e=evidence(req);return this.manual.hydrate(await this.repo.paymentStart(e.hash,e.csrf,uuid(d.bookingId),boundedString(d.version,20)));}
 @Post('payments/read') @HttpCode(200)
 async payments(@Req()req:Request,@Body()body:unknown){const d=fields(body,['bookingId']);return this.manual.hydrate(await this.repo.rpc('product_payment_read',[evidence(req).hash,uuid(d.bookingId)]));}
 @Post('admin/read/:kind') @HttpCode(200)
 async adminRead(@Req()req:Request,@Param('kind')kind:string,@Body()body:unknown){const d=fields(body,['branchId','customerId','query','offset']);if(d.branchId!==null)uuid(d.branchId);if(d.customerId!==null)uuid(d.customerId);boundedString(d.query);if(typeof d.offset!=='string'||!/^\d{1,5}$/.test(d.offset))throw new HttpException('Invalid offset',422);return this.manual.hydrate(await this.repo.rpc('product_admin_read',[evidence(req).hash,kind,d]));}
 @Post('admin/commands/:op') @HttpCode(200)
 command(@Req()req:Request,@Param('op')op:string,@Body()body:unknown){if(!body||typeof body!=='object'||Array.isArray(body))throw new HttpException('Invalid command',422);const e=evidence(req);return this.repo.rpc('product_admin_command',[e.hash,e.csrf,op,body]);}
 @Post('admin/contact') @HttpCode(200)
 async contact(@Req()req:Request,@Body()body:unknown){const d=fields(body,['userId','branchId']),e=evidence(req),r=await this.repo.rpc('product_customer_contact',[e.hash,e.csrf,uuid(d.userId),uuid(d.branchId)]);if(!r)throw new HttpException('Not found',404);return{mobile:unseal<{mobile:string}>(this.repo.cfg.encryptionKey,String(r.ciphertext),'mobile:'+String(r.lookup)).mobile};}
}
@Controller('api/v1/product/manual') @UseGuards(SessionGuard)
class ManualController {
 constructor(private readonly manual:ManualPaymentService){}
 private key(req:Request){return uuid(req.headers['idempotency-key']);}
 @Post('methods') @HttpCode(200)
 methods(@Req()req:Request,@Body()body:unknown){const d=fields(body,['bookingId']);return this.manual.methods(evidence(req),uuid(d.bookingId));}
 @Post('settings/read') @HttpCode(200)
 settings(@Req()req:Request,@Body()body:unknown){const d=fields(body,['branchId']);return this.manual.settings(evidence(req),d.branchId);}
 @Post('settings/save') @HttpCode(200)
 save(@Req()req:Request,@Body()body:unknown){return this.manual.settingsSave(evidence(req),this.key(req),body);}
 @Post('cards/save') @HttpCode(200)
 card(@Req()req:Request,@Body()body:unknown){return this.manual.cardSave(evidence(req),this.key(req),body);}
 @Post('start') @HttpCode(200)
 start(@Req()req:Request,@Body()body:unknown){return this.manual.start(evidence(req),this.key(req),body);}
 @Post('upload-context/:intent') @HttpCode(200)
 context(@Req()req:Request,@Param('intent')intent:string,@Body()body:unknown){fields(body,[]);return this.manual.uploadContext(evidence(req),uuid(intent),this.key(req));}
 @Post('receipts/upload/:intent') @HttpCode(200)
 submit(@Req()req:Request,@Param('intent')intent:string,@Body()body:unknown){const d=body as Record<string,unknown>;if(!d||d.intentId!==uuid(intent))throw new HttpException({code:'INVALID_FIELDS'},422);return this.manual.submit(evidence(req),this.key(req),body);}
 @Post('payments/read') @HttpCode(200)
 list(@Req()req:Request,@Body()body:unknown){return this.manual.list(evidence(req),body);}
 @Post('review') @HttpCode(200)
 review(@Req()req:Request,@Body()body:unknown){return this.manual.review(evidence(req),this.key(req),body);}
 @Get('receipts/:id/image')
 async image(@Req()req:Request,@Param('id')id:string,@Res()res:Response&{send(b:Buffer):void}){
  const bytes=await this.manual.image(evidence(req),uuid(id));res.setHeader('Cache-Control','private, no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Vary','Cookie');res.setHeader('Content-Type','image/webp');res.setHeader('Content-Length',String(bytes.length));res.setHeader('Content-Disposition','inline; filename="receipt.webp"');res.setHeader('Cross-Origin-Resource-Policy','same-origin');res.setHeader('Content-Security-Policy',"default-src 'none'; frame-ancestors 'none'; sandbox");res.send(bytes);
 }
}
@Controller('api/v1/product/shop') @UseGuards(SessionGuard)
class ShopController {
 constructor(private readonly shop:ShopService){}
 private key(req:Request){return uuid(req.headers['idempotency-key']);}
 @Post('admin/read/:kind') @HttpCode(200)
 read(@Req()req:Request,@Param('kind')kind:string,@Body()body:unknown){return this.shop.adminRead(evidence(req),kind,body);}
 @Post('admin/configuration') @HttpCode(200)
 configuration(@Req()req:Request,@Body()body:unknown){return this.shop.configuration(evidence(req),this.key(req),body);}
 @Post('admin/products/:op') @HttpCode(200)
 product(@Req()req:Request,@Param('op')op:string,@Body()body:unknown){if(!['save','stock','archive'].includes(op))throw new HttpException('Not found',404);return this.shop.product(evidence(req),this.key(req),op,body);}
 @Post('quote') @HttpCode(200)
 quote(@Req()req:Request,@Body()body:unknown){return this.shop.quote(evidence(req),body);}
 @Post('checkout') @HttpCode(200)
 checkout(@Req()req:Request,@Body()body:unknown){return this.shop.checkout(evidence(req),this.key(req),body);}
 @Post('checkout/status') @HttpCode(200)
 checkoutStatus(@Req()req:Request,@Body()body:unknown){return this.shop.checkoutStatus(evidence(req),body);}
 @Post('orders/:mode') @HttpCode(200)
 orders(@Req()req:Request,@Param('mode')mode:string,@Body()body:unknown){return this.shop.orders(evidence(req),mode,body);}
 @Post('orders/commands/:op') @HttpCode(200)
 command(@Req()req:Request,@Param('op')op:string,@Body()body:unknown){return this.shop.command(evidence(req),this.key(req),op,body);}
 @Post('payment/methods') @HttpCode(200)
 methods(@Req()req:Request,@Body()body:unknown){return this.shop.methods(evidence(req),body);}
 @Post('payment/start') @HttpCode(200)
 payment(@Req()req:Request,@Body()body:unknown){return this.shop.payment(evidence(req),this.key(req),body);}
}
export async function createProductApp(cfg:ProductConfig,storage:MediaStorage){
 @Global() @Module({controllers:[AuthController,PublicController,ProductController,ManualController,ShopController,BookingController,WorkforceController,PricingController,PortalController,PublicGalleryController],providers:[
  {provide:PRODUCT_CONFIG,useValue:cfg},{provide:ADMIN_OPTIONS,useValue:{origin:cfg.origin,trustedProductPeer:true}},ProductAuthService,
  {provide:ProductRepository,useFactory:()=>new ProductRepository(cfg)}, {provide:MvpRepository,useExisting:ProductRepository},{provide:BookingRepository,useExisting:ProductRepository},
  {provide:AdminRepository,useFactory:(r:ProductRepository)=>({session:r.session.bind(r),read:r.legacyRead.bind(r),command:r.legacyCommand.bind(r)}),inject:[ProductRepository]},
  {provide:WorkforceRepository,useFactory:(r:ProductRepository)=>({read:r.workforceRead.bind(r),command:r.workforceCommand.bind(r)}),inject:[ProductRepository]},
  {provide:PricingRepository,useFactory:(r:ProductRepository)=>({read:r.pricingRead.bind(r),command:r.pricingCommand.bind(r)}),inject:[ProductRepository]},
  {provide:AdminCommands,useFactory:(r:AdminRepository)=>new AdminCommands(r),inject:[AdminRepository]},
  {provide:WorkforceCommands,useFactory:(r:WorkforceRepository)=>new WorkforceCommands(r),inject:[WorkforceRepository]},SessionGuard,
  {provide:StorageProvider,useValue:new StorageProvider(storage)},{provide:MediaService,useFactory:(r:ProductRepository)=>new MediaService(r,storage),inject:[ProductRepository]},
  {provide:ManualPaymentService,useFactory:(r:ProductRepository)=>new ManualPaymentService(r,storage),inject:[ProductRepository]},
  {provide:ShopService,useFactory:(r:ProductRepository,m:ManualPaymentService)=>new ShopService(r,m),inject:[ProductRepository,ManualPaymentService]},
  {provide:publicBusiness,useValue:cfg.businessId}
 ],exports:[ADMIN_OPTIONS,AdminRepository,AdminCommands,SessionGuard]})class Integration{}
 @Module({imports:[Integration,IamModule,BusinessModule,BranchModule,CatalogModule,OfferingModule]})class App{}
 const app=await NestFactory.create<NestExpressApplication>(App,{logger:false,abortOnError:false,bodyParser:false});
 app.use((req:Request&{url:string},res:Response,next:()=>void)=>{
  if(req.url==='/health/live'&&req.method==='GET'){res.status(200).json({status:'live'});return;}
  const key=req.headers['x-product-bridge'];if(typeof key!=='string'||key.length!==cfg.bridgeKey.length||!timingSafeEqual(Buffer.from(key),Buffer.from(cfg.bridgeKey))){res.status(403).json({code:'PRIVATE_API'});return;}
  if(!['GET','HEAD'].includes(req.method)&&req.headers.origin!==cfg.origin){res.status(403).json({code:'ORIGIN_REQUIRED'});return;}
  next();});
 app.use(requestDiagnostics);
 const verify=(_req:unknown,_res:unknown,b:Buffer)=>{try{uniqueJson(b.toString('utf8'));}catch{throw new HttpException({code:'INVALID_JSON'},422);}};
 const receiptUpload=/^\/api\/v1\/product\/manual\/receipts\/upload\/([a-f0-9-]{36})$/;
 // Repeat the real SQL ownership/CSRF/state preflight before the large JSON
 // parser, even when the private bridge is called without the Next proxy.
 app.use(async(req:Request&{url:string},res:Response,next:()=>void)=>{
  const match=receiptUpload.exec(req.url);if(!match){next();return;}
  try{const cookies=typeof req.headers.cookie==='string'?req.headers.cookie.split(';').map(x=>x.trim()).filter(x=>x.startsWith('ms_session=')):[];
   const csrf=req.headers['x-csrf-token'];if(cookies.length!==1||!/^ms_session=[A-Za-z0-9_-]{43}$/.test(cookies[0]!)||typeof csrf!=='string'||!/^[A-Za-z0-9_-]{43}$/.test(csrf))throw new HttpException('Unauthenticated',401);
   if(req.headers.origin!==cfg.origin||(req.headers['sec-fetch-site']&&req.headers['sec-fetch-site']!=='same-origin'))throw new HttpException('Forbidden',403);
   const repo=app.get(ProductRepository),hash=digest(cookies[0]!.slice(11)),actor=await repo.session(hash);
   await app.get(ManualPaymentService).uploadContext({hash,csrf:digest(csrf),actor,requestId:req.requestId??'upload-preflight'},uuid(match[1]),uuid(req.headers['idempotency-key']));next();
  }catch(err){const e=err as {getStatus?:()=>number;code?:string};res.status(e.getStatus?.()??({MS401:401,MS403:403,MS404:404,MS409:409,MS412:412}[e.code??'']??503)).json({code:'RECEIPT_UPLOAD_NOT_ALLOWED'});}
 });
 app.useBodyParser('json',{type:(r:{url?:string})=>r.url==='/api/v1/admin/media/upload',limit:'44mb',strict:true,verify});
 app.useBodyParser('json',{type:(r:{url?:string})=>receiptUpload.test(r.url??''),limit:'8mb',strict:true,verify});
 app.useBodyParser('json',{type:(r:{url?:string})=>r.url==='/api/v1/product/shop/admin/configuration',limit:'64kb',strict:true,verify});
 app.useBodyParser('json',{type:(r:{url?:string})=>r.url!=='/api/v1/admin/media/upload'&&r.url!=='/api/v1/product/shop/admin/configuration'&&!receiptUpload.test(r.url??''),limit:'32kb',strict:true,verify});
 app.useGlobalFilters(new MvpFilter());app.enableShutdownHooks();return app;
}
