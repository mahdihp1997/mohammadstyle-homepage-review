import { HttpException } from "@nestjs/common";
import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";
import sharp from "sharp";
import type { Evidence } from "../admin/security.js";
import { uuid } from "../admin/contracts.js";
import type { MediaStorage } from "../mvp/storage.js";
import { sha } from "../mvp/storage.js";
import { fields } from "./auth.js";
import { keyed, seal, unseal } from "./crypto.js";
import type { ProductRepository } from "./repository.js";

const fail = (code: string, status=422): never => { throw new HttpException({code},status); };
const text = (v:unknown,max:number):string => typeof v==="string"&&v.length<=max?v:fail("INVALID_FIELDS");
const digits = (v:string) => v.replace(/[۰-۹]/g,c=>String(c.charCodeAt(0)-1776)).replace(/[٠-٩]/g,c=>String(c.charCodeAt(0)-1632));
const version = (v:unknown) => { const s=text(v,19);if(!/^\d{1,19}$/.test(s)||BigInt(s)>9223372036854775806n)fail("INVALID_VERSION");return s; };
function canonical(v:unknown):unknown { return Array.isArray(v)?v.map(canonical):v&&typeof v==="object"?Object.fromEntries(Object.entries(v).sort(([a],[b])=>a.localeCompare(b)).map(([k,x])=>[k,canonical(x)])):v; }
export function normalizeCard(v:unknown) {
  const s=digits(text(v,40)).replace(/[\s-]/g,"");
  if(!/^\d{16}$/.test(s)||/^(\d)\1+$/.test(s))return fail("INVALID_CARD_NUMBER");
  const sum=[...s].reduce((n,c,i)=>{let d=Number(c)*(i%2===0?2:1);if(d>9)d-=9;return n+d;},0);
  if(sum%10!==0)return fail("INVALID_CARD_CHECKSUM");
  return s;
}
export function encryptReceipt(key:string,bytes:Buffer,aad:string) {
  const iv=randomBytes(12),c=createCipheriv("aes-256-gcm",Buffer.from(key,"base64url"),iv);c.setAAD(Buffer.from(aad));
  const body=Buffer.concat([c.update(bytes),c.final()]);return Buffer.concat([Buffer.from("MSR1"),iv,c.getAuthTag(),body]);
}
export function decryptReceipt(key:string,bytes:Buffer,aad:string) {
  if(bytes.length<33||bytes.subarray(0,4).toString()!=="MSR1")throw Error("INVALID_RECEIPT_ENVELOPE");
  const c=createDecipheriv("aes-256-gcm",Buffer.from(key,"base64url"),bytes.subarray(4,16));c.setAAD(Buffer.from(aad));c.setAuthTag(bytes.subarray(16,32));
  return Buffer.concat([c.update(bytes.subarray(32)),c.final()]);
}
export class ManualPaymentService {
  private processing=0;
  constructor(readonly repo:ProductRepository,readonly storage:MediaStorage) {}
  private signature(e:Evidence,op:string,data:unknown) { return keyed(this.repo.cfg.identityKey,"manual-request-v1",e.actor.businessId,e.actor.userId,op,JSON.stringify(canonical(data))); }
  private id(e:Evidence,op:string,k:string,intent="") { const b=Buffer.from(keyed(this.repo.cfg.identityKey,"manual-object-v1",e.actor.businessId,e.actor.userId,op,intent,k).subarray(0,16));b[6]=(b[6]!&15)|64;b[8]=(b[8]!&63)|128;const s=b.toString("hex");return `${s.slice(0,8)}-${s.slice(8,12)}-${s.slice(12,16)}-${s.slice(16,20)}-${s.slice(20)}`; }
  hydrate(value:unknown):unknown {
    if(Array.isArray(value))return value.map(v=>this.hydrate(v));
    if(!value||typeof value!=="object")return value;
    const doc=value as Record<string,unknown>,result:Record<string,unknown>={};
    for(const [k,v] of Object.entries(doc))if(!k.startsWith("_private"))result[k]=this.hydrate(v);
    const card=doc._privateCard as Record<string,unknown>|undefined;
    if(card){const c=unseal<{number:string;holder:string}>(this.repo.cfg.encryptionKey,String(card.ciphertext),`bank-card:${card.businessId}:${card.cardId}:${card.version}`);
      result.cardholder=c.holder;result.cardNumber=card.fullNumber===true?c.number:"•••• •••• •••• "+c.number.slice(-4);}
    const reference=doc._privateReference as Record<string,unknown>|undefined;
    if(reference)result.senderReference=unseal<{reference:string}>(this.repo.cfg.encryptionKey,String(reference.ciphertext),`receipt-reference:${reference.businessId}:${reference.receiptId}`).reference;
    const bank=doc._privateBankEvidence as Record<string,unknown>|undefined;
    if(bank)result.bankReference=unseal<{reference:string}>(this.repo.cfg.encryptionKey,String(bank.ciphertext),`bank-reconciliation:${bank.businessId}:${bank.intentId}`).reference;
    const shipping=doc._privateShipping as Record<string,unknown>|undefined;
    if(shipping){const details=unseal<Record<string,unknown>>(this.repo.cfg.encryptionKey,String(shipping.ciphertext),`shop-shipping:${shipping.businessId}:${shipping.orderId}`);if(shipping.includePhone!==true)delete details.mobile;result.shippingDetails=details;}
    return result;
  }
  async methods(e:Evidence,id:string) { return this.hydrate(await this.repo.rpc("manual_methods",[e.hash,uuid(id)])); }
  async settings(e:Evidence,branchId:unknown) { return this.hydrate(await this.repo.rpc("manual_settings_read",[e.hash,branchId===null?null:uuid(branchId)])); }
  async settingsSave(e:Evidence,k:string,input:unknown) {
    const d=fields(input,["branchId","version","onlineEnabled","manualEnabled","defaultCardId","retentionDays","maxSubmissions","inherit"]);
    d.version=version(d.version);if(d.branchId!==null)d.branchId=uuid(d.branchId);if(d.defaultCardId!==null)d.defaultCardId=uuid(d.defaultCardId);
    return this.repo.rpc("manual_settings_save",[e.hash,e.csrf,uuid(k),this.signature(e,"settings.save",d),d]);
  }
  async cardSave(e:Evidence,k:string,input:unknown) {
    const d=fields(input,["id","version","bankName","number","cardholder","scopeKind","branchIds","priority","active","archive"]);
    uuid(k);const v=version(d.version),id=d.id===null?this.id(e,"card.save",k):uuid(d.id);
    if((d.id===null)!==(v==="0"))fail("INVALID_VERSION");
    const holder=text(d.cardholder,120).trim(),bankName=text(d.bankName,100).trim();if(!holder||!bankName)fail("INVALID_FIELDS");
    let number:string;
    if(d.id!==null){const existing=await this.repo.rpc("manual_card_context",[e.hash,id]);const full=this.hydrate(existing) as {cardNumber:string};number=full.cardNumber;
      if(text(d.number,40)!==""&&normalizeCard(d.number)!==number)fail("CARD_NUMBER_IMMUTABLE",409);
    }else number=normalizeCard(d.number);
    if(!Array.isArray(d.branchIds)||d.branchIds.length>100)fail("INVALID_FIELDS");
    const branches=(d.branchIds as unknown[]).map(uuid).sort();
    const semantic={id,version:v,bankName,number,cardholder:holder,scopeKind:d.scopeKind,branchIds:branches,priority:d.priority,active:d.active,archive:d.archive};
    const payload={id,version:v,bankName,ciphertext:seal(this.repo.cfg.encryptionKey,{number,holder},`bank-card:${e.actor.businessId}:${id}:${BigInt(v)+1n}`),fingerprint:keyed(this.repo.cfg.identityKey,"bank-card",number).toString("hex"),lastFour:number.slice(-4),scopeKind:d.scopeKind,branchIds:branches,priority:d.priority,active:d.active,archive:d.archive};
    return this.repo.rpc("manual_card_save",[e.hash,e.csrf,k,this.signature(e,"card.save",semantic),payload]);
  }
  async start(e:Evidence,k:string,input:unknown) {
    const d=fields(input,["bookingId","version","cardId"]);d.bookingId=uuid(d.bookingId);d.cardId=uuid(d.cardId);d.version=version(d.version);
    await this.repo.sweep(e.hash,e.csrf);
    return this.repo.rpc("manual_start",[e.hash,e.csrf,uuid(k),this.signature(e,"manual.start",d),d]);
  }
  async uploadContext(e:Evidence,intent:string,k:string) { return this.repo.rpc("manual_submission_context",[e.hash,e.csrf,uuid(intent),uuid(k)]); }
  private aad(bid:string,id:string,kind:string) { return `receipt-image:${bid}:${id}:${kind}`; }
  private async bytes(key:string) {
    const stream=await this.storage.read(key),parts:Buffer[]=[];let n=0;
    for await(const part of stream){const b=Buffer.from(part);n+=b.length;if(n>6*1024*1024){stream.destroy();throw Error("RECEIPT_OBJECT_SIZE");}parts.push(b);}return Buffer.concat(parts);
  }
  private async existing(key:string) {
    try{return await this.bytes(key);}catch(e){const x=e as {code?:string;name?:string};if(x.code==="ENOENT"||["NoSuchKey","NotFound"].includes(x.name??""))return null;throw e;}
  }
  private async putOnce(key:string,plain:Buffer,aad:string) {
    let stored=await this.existing(key);
    if(!stored){const cipher=encryptReceipt(this.repo.cfg.encryptionKey,plain,aad);try{await this.storage.put(key,cipher,"application/octet-stream");stored=cipher;}catch(e){stored=await this.existing(key);if(!stored)throw e;}}
    if(sha(decryptReceipt(this.repo.cfg.encryptionKey,stored,aad))!==sha(plain))fail("IDEMPOTENCY_BODY_MISMATCH",409);
    return {hash:sha(stored),size:String(stored.length)};
  }
  async submit(e:Evidence,k:string,input:unknown) {
    if(this.processing>=2)fail("RECEIPT_PROCESSING_BUSY",429);
    this.processing++;
    try{return await this.submitImage(e,k,input);}finally{this.processing--;}
  }
  private async submitImage(e:Evidence,k:string,input:unknown) {
    const d=fields(input,["intentId","version","content","reference"]),intent=uuid(d.intentId),v=version(d.version);uuid(k);
    const ctx=await this.uploadContext(e,intent,k),id=this.id(e,"receipt.submit",k,intent),bid=e.actor.businessId;
    const encoded=text(d.content,6990510),reference=text(d.reference,160).trim();
    if(!encoded||encoded.length%4!==0||!/^[A-Za-z0-9+/]*={0,2}$/.test(encoded))fail("INVALID_RECEIPT");
    const original=Buffer.from(encoded,"base64");if(!original.length||original.length>5242880)fail("RECEIPT_SIZE",413);
    if(original.toString("base64")!==encoded)fail("INVALID_RECEIPT");
    let mime:string;
    if(original.subarray(0,3).equals(Buffer.from([255,216,255])))mime="image/jpeg";
    else if(original.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))mime="image/png";
    else if(original.subarray(0,4).toString()==="RIFF"&&original.subarray(8,12).toString()==="WEBP")mime="image/webp";
    else return fail("RECEIPT_TYPE");
    let display:Buffer,width:number,height:number;
    try{const image=sharp(original,{limitInputPixels:25000000,failOn:"warning"});const meta=await image.metadata();width=meta.width!;height=meta.height!;
      if(!width||!height||width>12000||height>12000||width*height>25000000||(meta.pages??1)>1||!["jpeg","png","webp"].includes(meta.format??""))fail("RECEIPT_DIMENSIONS");
      display=await image.rotate().resize({width:1800,height:1800,fit:"inside",withoutEnlargement:true}).webp({quality:88}).toBuffer();
    }catch(e){if(e instanceof HttpException)throw e;return fail("INVALID_RECEIPT_IMAGE");}
    const originalKey=`receipts/${bid}/${id}/original.aes`,displayKey=`receipts/${bid}/${id}/display.aes`;
    const semantic={intentId:intent,version:v,hash:sha(original),reference};
    // Storage is immutable and private. SQL authorizes again before committing
    // any object reference; a lost commit response retries the same opaque keys.
    const o=await this.putOnce(originalKey,original,this.aad(bid,id,"original"));
    const p=await this.putOnce(displayKey,display,this.aad(bid,id,"display"));
    const payload={id,intentId:intent,version:v,referenceCiphertext:reference?seal(this.repo.cfg.encryptionKey,{reference},`receipt-reference:${bid}:${id}`):null,originalKey,originalHash:sha(original),originalObjectHash:o.hash,originalObjectBytes:o.size,displayKey,displayHash:sha(display),displayObjectHash:p.hash,displayObjectBytes:p.size,mime,sourceBytes:String(original.length),width:String(width),height:String(height)};
    void ctx;
    return this.repo.rpc("manual_receipt_submit",[e.hash,e.csrf,k,this.signature(e,"receipt.submit",semantic),payload]);
  }
  async review(e:Evidence,k:string,input:unknown) {
    const d=fields(input,["intentId","receiptId","version","decision","reason","amountRial","receivedAt","bankReference","attested"]);
    const intent=uuid(d.intentId),receipt=uuid(d.receiptId),v=version(d.version),reason=text(d.reason,300).trim();uuid(k);
    const ctx=await this.repo.rpc("manual_review_context",[e.hash,e.csrf,intent,receipt]);
    let reference:string|null=null,amount:string|null=null,at:string|null=null;
    if(d.decision==="APPROVE"){
      reference=digits(text(d.bankReference,160)).normalize("NFKC").replace(/[\s-]/g,"").toUpperCase();
      if(!/^[A-Z0-9]{4,160}$/.test(reference)||d.attested!==true)fail("BANK_RECONCILIATION_REQUIRED");
      amount=digits(text(d.amountRial,19));if(!/^[1-9]\d{0,18}$/.test(amount)||BigInt(amount)>9223372036854775807n)fail("INVALID_RIAL_AMOUNT");
      at=text(d.receivedAt,40);if(!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,3})?Z$/.test(at)||!Number.isFinite(Date.parse(at)))fail("INVALID_BANK_TIME");at=new Date(at).toISOString();
    }else if(d.decision!=="REJECT"||d.amountRial!==null||d.receivedAt!==null||d.bankReference!==null||d.attested!==false)fail("INVALID_REVIEW");
    const payload={intentId:intent,receiptId:receipt,version:v,decision:d.decision,reason,amountRial:amount,receivedAt:at,bankReferenceHash:reference?keyed(this.repo.cfg.identityKey,"bank-transaction",String(ctx.cardFingerprint),reference).toString("hex"):null,evidenceCiphertext:reference?seal(this.repo.cfg.encryptionKey,{reference},`bank-reconciliation:${e.actor.businessId}:${intent}`):null,attested:d.attested};
    return this.repo.rpc("manual_review_decide",[e.hash,e.csrf,k,this.signature(e,"receipt.review",{...d,version:v,reason,amountRial:amount,receivedAt:at,bankReference:reference}),payload]);
  }
  async list(e:Evidence,input:unknown) { const d=fields(input,["branchId","from","to","state","query","offset"]);return this.hydrate(await this.repo.rpc("manual_payments_read",[e.hash,d])); }
  async image(e:Evidence,id:string) {
    const r=await this.repo.rpc("manual_receipt_access",[e.hash,uuid(id)]),bytes=await this.bytes(String(r.display_key));
    if(sha(bytes)!==r.display_object_sha256||String(bytes.length)!==String(r.display_object_bytes))throw Error("RECEIPT_INTEGRITY");
    const plain=decryptReceipt(this.repo.cfg.encryptionKey,bytes,this.aad(String(r.business_id),id,"display"));
    if(sha(plain)!==String(r.display_sha256).replace(/^\\x/,""))throw Error("RECEIPT_INTEGRITY");
    return plain;
  }
}
