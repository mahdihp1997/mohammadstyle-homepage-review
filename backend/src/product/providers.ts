import { createHash } from 'node:crypto';
import type { ProductConfig } from './config.js';
import { normalizeMobile } from './crypto.js';

export interface PaymentRequest { id: string; amountRial: string; currency: 'IRR'; callbackUrl: string; expiresAt: string }
export type PaymentCreation = { status: 'created'; authority: string; hostedUrl: string } | { status: 'declined' | 'unknown'; retrySafe?: boolean };
export type PaymentVerification = { status: 'paid'; authority: string; amountRial: string; currency: 'IRR'; reference: string; evidenceHash: string } | { status: 'pending' | 'declined' | 'unknown' };
export interface PaymentProvider {
  readonly name: string;
  readonly idempotentRequests: boolean;
  request(data: PaymentRequest): Promise<PaymentCreation>;
  verify(authority: string, expectedRial: string): Promise<PaymentVerification>;
  refund(id: string, authority: string, rial: string): Promise<{ status: 'verified' | 'declined' | 'unknown' | 'unsupported'; reference?: string }>;
}
export class UnconfiguredPayment implements PaymentProvider {
  readonly name = 'none'; readonly idempotentRequests = false;
  async request(): Promise<PaymentCreation> { return {status:'declined'}; }
  async verify(): Promise<PaymentVerification> { return {status:'unknown'}; }
  async refund(): Promise<{status:'unsupported'}> { return {status:'unsupported'}; }
}
const amount = (v: string) => { if (!/^[1-9]\d{0,18}$/.test(v) || BigInt(v)>9223372036854775807n) throw Error('INVALID_EXACT_RIAL'); return v; };
export class MockPayment implements PaymentProvider {
  readonly name = 'mock'; readonly idempotentRequests = true;
  constructor(private readonly cfg: ProductConfig) { assertMock(cfg); }
  private async call(route: string, data: unknown): Promise<Record<string,unknown>> {
    const response=await fetch(this.cfg.mockGatewayOrigin+route,{method:'POST',headers:{'content-type':'application/json','x-mock-key':this.cfg.bridgeKey},body:JSON.stringify(data),signal:AbortSignal.timeout(8000),redirect:'error'});
    if (!response.ok || Number(response.headers.get('content-length')??0)>16384) throw Error('MOCK_PROVIDER_RESPONSE');
    const body=await response.text();if(body.length>16384)throw Error('MOCK_PROVIDER_RESPONSE');return JSON.parse(body) as Record<string,unknown>;
  }
  async request(data: PaymentRequest): Promise<PaymentCreation> {
    amount(data.amountRial);if(data.currency!=='IRR')throw Error('CURRENCY_REQUIRED');
    try { const r=await this.call('/request',data);
      if(r.status==='declined')return {status:'declined'};
      if(r.status!=='created'||typeof r.authority!=='string'||!/^[A-Za-z0-9_-]{8,160}$/.test(r.authority)||r.hostedUrl!==this.cfg.mockGatewayOrigin+'/pay/'+r.authority)throw Error('MOCK_PROVIDER_RESPONSE');
      return {status:'created',authority:r.authority,hostedUrl:r.hostedUrl};
    }catch{return {status:'unknown',retrySafe:true};}
  }
  async verify(authority: string, expectedRial: string): Promise<PaymentVerification> {
    amount(expectedRial);
    try { const r=await this.call('/verify',{authority,amountRial:expectedRial,currency:'IRR'});
      if(['pending','declined','unknown'].includes(String(r.status)))return {status:r.status as 'pending'|'declined'|'unknown'};
      if(r.status!=='paid'||r.authority!==authority||r.amountRial!==expectedRial||r.currency!=='IRR'||typeof r.reference!=='string'||!/^[A-Za-z0-9_-]{8,160}$/.test(r.reference))return {status:'unknown'};
      return {status:'paid',authority,amountRial:expectedRial,currency:'IRR',reference:r.reference,evidenceHash:createHash('sha256').update(JSON.stringify(r)).digest('hex')};
    }catch{return {status:'unknown'};}
  }
  async refund(id: string, authority: string, rial: string) {
    amount(rial);try { const r=await this.call('/refund',{id,authority,amountRial:rial,currency:'IRR'});
      if(r.status==='verified'&&typeof r.reference==='string'&&/^mock_refund_[a-f0-9]{32}$/.test(r.reference))return {status:'verified' as const,reference:r.reference};
      return {status:'declined' as const};
    }catch{return {status:'unknown' as const};}
  }
}
export function assertMock(c: ProductConfig) { if(c.environment!=='test'||process.env.APP_ENV!=='product-test'||process.env.NODE_ENV==='production'||c.database.host!=='127.0.0.1'||![55460,55461].includes(c.database.port)||!c.database.marker.includes('-test-'))throw Error('ISOLATED_MOCK_ONLY'); }
export interface SmsMessage { dedupeKey: string; mobile: string; kind: string; code?: string; text?: string }
export interface SmsProvider { readonly replaySafe: boolean; send(message: SmsMessage): Promise<{state:'accepted'|'retry'|'unknown'|'blocked';receipt?:string;code:string}> }
export class UnconfiguredSms implements SmsProvider { readonly replaySafe=false;async send(){return {state:'blocked' as const,code:'SMS_UNCONFIGURED'};} }
export class MockSms implements SmsProvider {
  readonly replaySafe=true;constructor(private readonly cfg: ProductConfig){assertMock(cfg);}
  async send(message: SmsMessage){try{const r=await fetch((this.cfg.mockGatewayOrigin??'http://127.0.0.1:3117')+'/sms',{method:'POST',headers:{'content-type':'application/json','x-mock-key':this.cfg.bridgeKey},body:JSON.stringify(message),signal:AbortSignal.timeout(8000),redirect:'error'});const body=await r.json() as {receipt?:string};
    if(!r.ok||typeof body.receipt!=='string'||!/^mock_sms_[a-f0-9]{32}$/.test(body.receipt))throw Error();return {state:'accepted' as const,code:'PROVIDER_ACCEPTED',receipt:body.receipt};}catch{return {state:'retry' as const,code:'MOCK_RETRY_SAFE'};}}
}
/** Official contract: https://kavenegar.com/rest.html . No documented deduplication
 * guarantee for verify/lookup; ambiguous outcomes are never automatically resent. */
export function kavenegarRequest(cfg: Pick<ProductConfig,'smsKey'|'smsOtpTemplate'|'smsSender'>,message: SmsMessage) {
  if(!cfg.smsKey||!/^[A-Za-z0-9_-]+$/.test(cfg.smsKey))throw Error('SMS_UNCONFIGURED');
  const receptor='0'+normalizeMobile(message.mobile).slice(3);
  const otp=message.kind==='OTP';
  if(otp&&(!/^\d{6}$/.test(message.code??'')||!cfg.smsOtpTemplate))throw Error('OTP_TEMPLATE_UNCONFIGURED');
  if(!otp&&(!cfg.smsSender||!message.text||message.text.length>600))throw Error('SMS_SENDER_UNCONFIGURED');
  return {url:'https://api.kavenegar.com/v1/'+cfg.smsKey+(otp?'/verify/lookup.json':'/sms/send.json'),
    body:new URLSearchParams(otp?{receptor,token:message.code!,template:cfg.smsOtpTemplate!,type:'sms'}:{receptor,sender:cfg.smsSender!,message:message.text!})};
}
export class KavenegarSms implements SmsProvider {
  readonly replaySafe=false;constructor(private readonly cfg: ProductConfig){if(cfg.environment==='test'||cfg.sms!=='kavenegar')throw Error('LIVE_SMS_FORBIDDEN');}
  async send(message: SmsMessage){let request:ReturnType<typeof kavenegarRequest>;try{request=kavenegarRequest(this.cfg,message);}catch{return {state:'blocked' as const,code:'SMS_UNCONFIGURED'};}
    try {const r=await fetch(request.url,{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded'},body:request.body,signal:AbortSignal.timeout(10000),redirect:'error'});
      const raw=await r.text();if(raw.length>16384)return {state:'unknown' as const,code:'AMBIGUOUS_RESPONSE'};
      const value=JSON.parse(raw) as {return?:{status?:number};entries?:{messageid?:number}[]};
      const code=value.return?.status,receipt=value.entries?.[0]?.messageid;
      if(code===200&&Number.isSafeInteger(receipt)&&receipt!>0)return {state:'accepted' as const,code:'PROVIDER_ACCEPTED',receipt:String(receipt)};
      if([400,401,403,404,405,414,417,418,422,424,426,428,431,432,607].includes(code??0))return {state:'blocked' as const,code:'PROVIDER_REJECTED'};
      return {state:'unknown' as const,code:'AMBIGUOUS_RESPONSE'};
    }catch{return {state:'unknown' as const,code:'TRANSPORT_AMBIGUOUS'};}
  }
}
export const paymentProvider=(c:ProductConfig):PaymentProvider=>c.payment==='mock'?new MockPayment(c):new UnconfiguredPayment();
export const smsProvider=(c:ProductConfig):SmsProvider=>c.sms==='mock'?new MockSms(c):c.sms==='kavenegar'?new KavenegarSms(c):new UnconfiguredSms();
