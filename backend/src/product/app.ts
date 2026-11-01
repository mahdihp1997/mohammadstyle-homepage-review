import 'reflect-metadata';
import {timingSafeEqual} from 'node:crypto';
import {Body,Controller,Get,Post,Param,Req,UseGuards,Global,Module,HttpException,HttpCode} from '@nestjs/common';
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
 @Post('payment-callback/:id') @HttpCode(200)
 callback(@Param('id')id:string,@Body()body:unknown){const d=fields(body,['state','authority']),state=boundedString(d.state,43),authority=boundedString(d.authority,160);if(!/^[A-Za-z0-9_-]{43}$/.test(state))throw new HttpException('Invalid callback',422);return this.repo.rpc('product_payment_callback',[uuid(id),digest(state),authority]);}
 @Get('health')health(){return this.repo.ready();}
}
@Controller('api/v1/product') @UseGuards(SessionGuard)
class ProductController {
 constructor(private readonly repo:ProductRepository,private readonly auth:ProductAuthService){}
 @Get('account')account(@Req()req:Request){return this.repo.rpc('product_account',[evidence(req).hash]);}
 @Post('account') @HttpCode(200)
 update(@Req()req:Request,@Body()body:unknown){const d=fields(body,['displayName','notificationsOptIn']);if(typeof d.notificationsOptIn!=='boolean')throw new HttpException('Invalid preference',422);const e=evidence(req);return this.repo.rpc('product_account_update',[e.hash,e.csrf,boundedString(d.displayName,100),d.notificationsOptIn]);}
 @Get('sessions')sessions(@Req()req:Request){const e=evidence(req);return this.auth.sessions(e.hash,e.csrf,'list');}
 @Post('sessions/:action') @HttpCode(200)
 revoke(@Req()req:Request,@Param('action')action:string,@Body()body:unknown){const d=fields(body,['id']);if(!['revoke','revoke_all','revoke_others'].includes(action))throw new HttpException('Not found',404);const e=evidence(req);return this.auth.sessions(e.hash,e.csrf,action as 'revoke'|'revoke_all'|'revoke_others',d.id===null?null:uuid(d.id));}
 @Post('payments/start') @HttpCode(200)
 start(@Req()req:Request,@Body()body:unknown){const d=fields(body,['bookingId','version']),e=evidence(req);return this.repo.paymentStart(e.hash,e.csrf,uuid(d.bookingId),boundedString(d.version,20));}
 @Post('payments/read') @HttpCode(200)
 payments(@Req()req:Request,@Body()body:unknown){const d=fields(body,['bookingId']);return this.repo.rpc('product_payment_read',[evidence(req).hash,uuid(d.bookingId)]);}
 @Post('admin/read/:kind') @HttpCode(200)
 adminRead(@Req()req:Request,@Param('kind')kind:string,@Body()body:unknown){const d=fields(body,['branchId','customerId','query','offset']);if(d.branchId!==null)uuid(d.branchId);if(d.customerId!==null)uuid(d.customerId);boundedString(d.query);if(typeof d.offset!=='string'||!/^\d{1,5}$/.test(d.offset))throw new HttpException('Invalid offset',422);return this.repo.rpc('product_admin_read',[evidence(req).hash,kind,d]);}
 @Post('admin/commands/:op') @HttpCode(200)
 command(@Req()req:Request,@Param('op')op:string,@Body()body:unknown){if(!body||typeof body!=='object'||Array.isArray(body))throw new HttpException('Invalid command',422);const e=evidence(req);return this.repo.rpc('product_admin_command',[e.hash,e.csrf,op,body]);}
 @Post('admin/contact') @HttpCode(200)
 async contact(@Req()req:Request,@Body()body:unknown){const d=fields(body,['userId','branchId']),e=evidence(req),r=await this.repo.rpc('product_customer_contact',[e.hash,e.csrf,uuid(d.userId),uuid(d.branchId)]);if(!r)throw new HttpException('Not found',404);return{mobile:unseal<{mobile:string}>(this.repo.cfg.encryptionKey,String(r.ciphertext),'mobile:'+String(r.lookup)).mobile};}
}
export async function createProductApp(cfg:ProductConfig,storage:MediaStorage){
 @Global() @Module({controllers:[AuthController,PublicController,ProductController,BookingController,WorkforceController,PricingController,PortalController,PublicGalleryController],providers:[
  {provide:PRODUCT_CONFIG,useValue:cfg},{provide:ADMIN_OPTIONS,useValue:{origin:cfg.origin,trustedProductPeer:true}},ProductAuthService,
  {provide:ProductRepository,useFactory:()=>new ProductRepository(cfg)}, {provide:MvpRepository,useExisting:ProductRepository},{provide:BookingRepository,useExisting:ProductRepository},
  {provide:AdminRepository,useFactory:(r:ProductRepository)=>({session:r.session.bind(r),read:r.legacyRead.bind(r),command:r.legacyCommand.bind(r)}),inject:[ProductRepository]},
  {provide:WorkforceRepository,useFactory:(r:ProductRepository)=>({read:r.workforceRead.bind(r),command:r.workforceCommand.bind(r)}),inject:[ProductRepository]},
  {provide:PricingRepository,useFactory:(r:ProductRepository)=>({read:r.pricingRead.bind(r),command:r.pricingCommand.bind(r)}),inject:[ProductRepository]},
  {provide:AdminCommands,useFactory:(r:AdminRepository)=>new AdminCommands(r),inject:[AdminRepository]},
  {provide:WorkforceCommands,useFactory:(r:WorkforceRepository)=>new WorkforceCommands(r),inject:[WorkforceRepository]},SessionGuard,
  {provide:StorageProvider,useValue:new StorageProvider(storage)},{provide:MediaService,useFactory:(r:ProductRepository)=>new MediaService(r,storage),inject:[ProductRepository]},
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
 app.useBodyParser('json',{type:(r:{url?:string})=>r.url==='/api/v1/admin/media/upload',limit:'44mb',strict:true,verify});
 app.useBodyParser('json',{type:(r:{url?:string})=>r.url!=='/api/v1/admin/media/upload',limit:'32kb',strict:true,verify});
 app.useGlobalFilters(new MvpFilter());app.enableShutdownHooks();return app;
}
