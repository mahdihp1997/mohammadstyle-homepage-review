import {MvpRepository} from '../mvp/repository.js';
import type {ProductConfig} from './config.js';
import {digest,seal,token} from './crypto.js';
import {verifyRuntime}from'./readiness.js';
const allowed=new Set(['product_public_catalog','product_account','product_account_update','product_payment_start','product_payment_read','product_payment_callback','product_admin_read','product_admin_command','product_worker_runtime','product_customer_contact']);
export class ProductRepository extends MvpRepository {
 constructor(readonly cfg:ProductConfig){super(cfg.database);}
 override async onModuleInit(){await super.onModuleInit();const r=await this.rpc('product_worker_runtime',[]);
  verifyRuntime(r,this.cfg);}
 async ready(){const r=await this.rpc('product_worker_runtime',[]);verifyRuntime(r,this.cfg);if(!r.workerLastSuccess||Date.parse(String(r.workerLastSuccess))<Date.now()-120000)throw Error('WORKER_NOT_READY');return{status:'ready'};}
 async rpc(name:string,args:unknown[]):Promise<Record<string,unknown>>{if(!allowed.has(name))throw Error('PRODUCT_RPC_ALLOWLIST');return this.transaction(async c=>(await c.query(`SELECT ms_b1_design.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) r`,args)).rows[0].r as Record<string,unknown>);}
 async paymentStart(h:Buffer,c:Buffer,id:string,version:string){await this.sweep(h,c);const state=token();return this.rpc('product_payment_start',[h,c,id,version,digest(state),seal(this.cfg.encryptionKey,state,'payment-callback:'+id)]);}
}
