import {MvpRepository} from '../mvp/repository.js';
import type {ProductConfig} from './config.js';
import {digest,seal,token} from './crypto.js';
import {verifyRuntime}from'./readiness.js';
const allowed=new Set(['product_public_catalog','product_account','product_account_update','product_payment_start','product_payment_read','product_payment_callback','product_payment_callback_route','product_admin_read','product_admin_command','product_worker_runtime','product_customer_contact']);
for(const name of ['shop_public','shop_admin_read','shop_config_save','shop_product_command','shop_quote_context','shop_quote_create','shop_checkout','shop_checkout_status','shop_orders_read','shop_order_command','shop_payment_methods','shop_payment_start','product_content_public','product_content_read','product_content_command','manual_methods','manual_settings_read','manual_settings_save','manual_card_context','manual_card_save','manual_start','manual_submission_context','manual_receipt_submit','manual_review_context','manual_review_decide','manual_receipt_access','manual_payments_read'])allowed.add(name);
export class ProductRepository extends MvpRepository {
 constructor(readonly cfg:ProductConfig){super(cfg.database);}
 override async onModuleInit(){await super.onModuleInit();const r=await this.rpc('product_worker_runtime',[]);
  verifyRuntime(r,this.cfg);}
 async ready(){const r=await this.rpc('product_worker_runtime',[]);verifyRuntime(r,this.cfg);if(!r.workerLastSuccess||Date.parse(String(r.workerLastSuccess))<Date.now()-120000)throw Error('WORKER_NOT_READY');return{status:'ready'};}
 async rpc(name:string,args:unknown[]):Promise<Record<string,unknown>>{if(!allowed.has(name))throw Error('PRODUCT_RPC_ALLOWLIST');return this.transaction(async c=>(await c.query(`SELECT ms_b1_design.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) r`,args)).rows[0].r as Record<string,unknown>);}
 async paymentStart(h:Buffer,c:Buffer,id:string,version:string){await this.sweep(h,c);const state=token();return this.rpc('product_payment_start',[h,c,id,version,digest(state),seal(this.cfg.encryptionKey,state,'payment-callback:'+id)]);}
}
