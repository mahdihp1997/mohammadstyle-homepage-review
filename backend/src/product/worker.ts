import {Pool} from 'pg';
import {productPoolOptions,type ProductConfig} from './config.js';
import {paymentProvider,smsProvider,type PaymentProvider,type SmsProvider} from './providers.js';
import {unseal} from './crypto.js';
import {verifyRuntime}from'./readiness.js';
type Row=Record<string,unknown>;
interface Job {id:string;token:string;kind:string;payload:Row;attempt:number;businessId:string}
const allowed=new Set(['product_collect','product_claim','product_tick','product_delivery_state','product_sms_context','product_payment_context','product_payment_result','product_refund_context','product_refund_result','product_worker_runtime','product_worker_heartbeat']);
export class ProductWorker {
  private readonly pool:Pool;
  private readonly payment:PaymentProvider;
  private readonly sms:SmsProvider;
  constructor(readonly cfg:ProductConfig,providers?:{payment?:PaymentProvider;sms?:SmsProvider}) {
    this.pool=new Pool(productPoolOptions(cfg.database,'ms_product_worker',cfg.workerDatabasePassword));this.pool.on('error',()=>{});
    this.payment=providers?.payment??paymentProvider(cfg);this.sms=providers?.sms??smsProvider(cfg);
    if(providers&&cfg.environment!=='test')throw Error('TEST_INJECTION_FORBIDDEN');
  }
  async call(name:string,args:unknown[]=[]):Promise<unknown>{if(!allowed.has(name))throw Error('WORKER_RPC_ALLOWLIST');return(await this.pool.query(`SELECT ms_b1_design.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) r`,args)).rows[0].r;}
  async init(){const r=await this.call('product_worker_runtime') as Row;
    verifyRuntime(r,this.cfg);}
  async close(){await this.pool.end();}
  private state(j:Job,state:string,code:string,receipt:string|null=null){return this.call('product_delivery_state',[j.id,j.token,state,code,receipt]);}
  async tick(maximum=10){if(!Number.isInteger(maximum)||maximum<1||maximum>100)throw Error('BOUNDED_WORKER_BATCH');
    await this.call('product_tick');await this.call('product_collect');let n=0;
    for(;n<maximum;n++){const j=await this.call('product_claim',[this.sms.replaySafe]) as Job|null;if(!j)break;
      try{await this.handle(j);}catch{await this.state(j,'UNKNOWN','HANDLER_REVIEW_REQUIRED').catch(()=>{});/* Never log payloads, OTPs, URLs, mobile numbers or provider errors. */}}
    await this.call('product_worker_heartbeat',[n]);return n;
  }
  private async handle(j:Job){
    if(j.kind==='SMS'){
      const c=await this.call('product_sms_context',[j.id,j.token]) as Row;
      if(c.code){await this.state(j,['STALE','OPTED_OUT','LEASE_LOST'].includes(String(c.code))?'CANCELLED':'BLOCKED',String(c.code));return;}
      let mobile:string,code:string|undefined,text:string|undefined;
      if(c.kind==='OTP'){const p=unseal<{mobile:string;code:string}>(this.cfg.encryptionKey,String(c.ciphertext),'otp:'+String(c.challengeId));mobile=p.mobile;code=p.code;}
      else{mobile=unseal<{mobile:string}>(this.cfg.encryptionKey,String(c.mobileCiphertext),'mobile:'+String(c.mobileLookup)).mobile;
        const variables=c.variables as Record<string,string>;text=String(c.body).replace(/\{(booking|order|status|date|reason)\}/g,(_,key:string)=>variables[key]??'');}
      if(!await this.state(j,'DISPATCHED','DISPATCH_START'))return;
      const r=await this.sms.send({dedupeKey:j.id,mobile,kind:String(c.kind),...(code?{code}:{}),...(text?{text}:{})});
      await this.state(j,r.state==='accepted'?'DELIVERED':r.state==='retry'?'READY':r.state==='blocked'?'BLOCKED':'UNKNOWN',r.code,r.receipt??null);return;
    }
    if(j.kind==='REFUND'){
      const c=await this.call('product_refund_context',[j.id,j.token]) as Row|null;if(!c){await this.state(j,'CANCELLED','REFUND_NOT_PENDING');return;}
      if(!await this.state(j,'DISPATCHED','DISPATCH_START'))return;
      const r=await this.payment.refund(String(c.id),String(c.authority),String(c.amountRial));
      await this.call('product_refund_result',[j.id,j.token,r.status,r.reference??null]);return;
    }
    const c=await this.call('product_payment_context',[j.id,j.token]) as Row|null;if(!c){await this.state(j,'CANCELLED','LEASE_LOST');return;}
    if(c.state==='VERIFIED'){await this.state(j,'DELIVERED','ALREADY_VERIFIED');return;}
    if(!await this.state(j,'DISPATCHED','DISPATCH_START'))return;
    if(j.kind==='PAYMENT_REQUEST'){
      if(Date.parse(String(c.expiresAt))<=Date.now()){await this.call('product_payment_result',[j.id,j.token,{status:'closed'}]);return;}
      const state=unseal<string>(this.cfg.encryptionKey,String(c.callbackCiphertext),'payment-callback:'+String(c.paymentTargetId??c.bookingId));
      const callbackUrl=String(c.origin)+'/api/product/payment/callback/'+String(c.id)+'?state='+encodeURIComponent(state);
      const r=await this.payment.request({id:String(c.id),amountRial:String(c.amountRial),currency:'IRR',callbackUrl,expiresAt:String(c.expiresAt)});
      await this.call('product_payment_result',[j.id,j.token,r]);
    }else if(j.kind==='PAYMENT_VERIFY'){
      const r=c.authority?await this.payment.verify(String(c.authority),String(c.amountRial)):{status:'unknown'};
      await this.call('product_payment_result',[j.id,j.token,r]);
    }else await this.state(j,'DEAD','UNKNOWN_JOB_KIND');
  }
}
