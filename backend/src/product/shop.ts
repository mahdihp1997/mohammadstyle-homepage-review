import {HttpException} from '@nestjs/common';import type{Evidence} from '../admin/security.js';import{uuid}from'../admin/contracts.js';
import{fields}from'./auth.js';import{digest,keyed,seal,token,unseal}from'./crypto.js';import type{ProductRepository}from'./repository.js';import type{ManualPaymentService}from'./manual.js';
const fail=(code:string):never=>{throw new HttpException({code},422);};
const text=(v:unknown,n:number)=>typeof v==='string'&&v.length<=n?v:fail('INVALID_FIELDS');
const canonical=(v:unknown):unknown=>Array.isArray(v)?v.map(canonical):v&&typeof v==='object'?Object.fromEntries(Object.entries(v).sort(([a],[b])=>a.localeCompare(b)).map(([k,x])=>[k,canonical(x)])):v;
const digits=(v:string)=>v.replace(/[۰-۹]/g,c=>String(c.charCodeAt(0)-1776)).replace(/[٠-٩]/g,c=>String(c.charCodeAt(0)-1632));
export class ShopService{
 constructor(readonly repo:ProductRepository,readonly manual:ManualPaymentService){}
 private signature(e:Evidence,op:string,d:unknown){return keyed(this.repo.cfg.identityKey,'shop-request-v1',e.actor.businessId,e.actor.userId,op,JSON.stringify(canonical(d)));}
 private orderId(e:Evidence,k:string){const b=keyed(this.repo.cfg.identityKey,'shop-order-v1',e.actor.businessId,e.actor.userId,k).subarray(0,16);b[6]=(b[6]!&15)|64;b[8]=(b[8]!&63)|128;const s=b.toString('hex');return `${s.slice(0,8)}-${s.slice(8,12)}-${s.slice(12,16)}-${s.slice(16,20)}-${s.slice(20)}`;}
 async adminRead(e:Evidence,kind:string,input:unknown){const d=fields(input,['offset']);return this.repo.rpc('shop_admin_read',[e.hash,kind,d]);}
 async configuration(e:Evidence,k:string,input:unknown){const d=fields(input,['version','enabled','branchId','paymentMode','holdSeconds','pickupEnabled','deliveryEnabled','deliveryFeeRial','termsText','returnsText','shippingText','finalPricesConfirmed','deliveryProvinces']);if(d.branchId!==null)d.branchId=uuid(d.branchId);if(!Array.isArray(d.deliveryProvinces)||d.deliveryProvinces.length>100)fail('INVALID_DELIVERY_AREAS');d.deliveryProvinces=(d.deliveryProvinces as unknown[]).map((v:unknown)=>text(v,80).trim().normalize('NFKC').replace(/ك/g,'ک').replace(/[يى]/g,'ی'));return this.repo.rpc('shop_config_save',[e.hash,e.csrf,uuid(k),this.signature(e,'configuration',d),d]);}
 async product(e:Evidence,k:string,op:string,input:unknown){const names=op==='stock'?['id','version','delta','reason']:op==='archive'?['id','version']:['id','version','sku','slug','name','description','category','priceRial','active','published','coverId'];const d=fields(input,names);if(d.id!==null)d.id=uuid(d.id);return this.repo.rpc('shop_product_command',[e.hash,e.csrf,uuid(k),this.signature(e,'product.'+op,d),op,d]);}
 async quote(e:Evidence,input:unknown){const d=fields(input,['items','shippingMethod']);if(!Array.isArray(d.items)||d.items.length<1||d.items.length>20)fail('INVALID_CART');d.items=(d.items as unknown[]).map(x=>{const item=fields(x,['productId','quantity']);return{productId:uuid(item.productId),quantity:text(item.quantity,2)};}).sort((a,b)=>a.productId.localeCompare(b.productId));return this.repo.rpc('shop_quote_create',[e.hash,e.csrf,d]);}
 async checkout(e:Evidence,k:string,input:unknown){const d=fields(input,['quoteId','contentHash','accepted','shippingDetails']),id=this.orderId(e,uuid(k)),quoteId=uuid(d.quoteId),hash=text(d.contentHash,64);
  if(!/^[a-f0-9]{64}$/.test(hash)||d.accepted!==true)fail('ORDER_TERMS_REQUIRED');
  const ctx=await this.repo.rpc('shop_quote_context',[e.hash,e.csrf,quoteId]),s=fields(d.shippingDetails,['recipientName','province','city','address','postalCode']);
  const shipping={recipientName:text(s.recipientName,100).trim(),province:text(s.province,80).trim(),city:text(s.city,80).trim(),address:text(s.address,500).trim(),postalCode:digits(text(s.postalCode,20)).replace(/\s/g,'')};
  if(shipping.recipientName.length<2||!['PICKUP','DELIVERY'].includes(String(ctx.shippingMethod)))fail('INVALID_SHIPPING_DETAILS');
  if(ctx.shippingMethod==='DELIVERY'){shipping.province=shipping.province.normalize('NFKC').replace(/ك/g,'ک').replace(/[يى]/g,'ی');if(!Array.isArray(ctx.deliveryProvinces)||!ctx.deliveryProvinces.includes(shipping.province))fail('DELIVERY_AREA_UNAVAILABLE');if(!shipping.province||!shipping.city||shipping.address.length<8||!/^\d{10}$/.test(shipping.postalCode)||/^(\d)\1{9}$/.test(shipping.postalCode))fail('INVALID_SHIPPING_DETAILS');}
  else if(Object.entries(shipping).some(([key,value])=>key!=='recipientName'&&value!==''))fail('INVALID_SHIPPING_DETAILS');
  const mobile=unseal<{mobile:string}>(this.repo.cfg.encryptionKey,String(ctx.mobileCiphertext),'mobile:'+String(ctx.mobileLookup)).mobile;
  const payload={id,quoteId,contentHash:hash,accepted:true,shippingCiphertext:seal(this.repo.cfg.encryptionKey,{...shipping,mobile},`shop-shipping:${e.actor.businessId}:${id}`)};
  return this.repo.rpc('shop_checkout',[e.hash,e.csrf,k,this.signature(e,'checkout',{quoteId,contentHash:hash,accepted:true,shipping}),payload]);
 }
 async checkoutStatus(e:Evidence,input:unknown){const d=fields(input,['key','cancelAttempt']);if(typeof d.cancelAttempt!=='boolean')fail('INVALID_FIELDS');return this.repo.rpc('shop_checkout_status',[e.hash,e.csrf,uuid(d.key),d.cancelAttempt]);}
 async orders(e:Evidence,mode:string,input:unknown){const d=fields(input,['id','branchId','state','offset']);if(d.id!==null)d.id=uuid(d.id);if(d.branchId!==null)d.branchId=uuid(d.branchId);return this.manual.hydrate(await this.repo.rpc('shop_orders_read',[e.hash,e.csrf,mode,d]));}
 async command(e:Evidence,k:string,op:string,input:unknown){const names=op==='fulfill'?['id','version','state','trackingReference']:op==='accept-cancellation'?['id','version','reason','goodsReconciled','restock']:op==='cancel'?['id','version']:['id','version','reason'];const d=fields(input,names);d.id=uuid(d.id);return this.repo.rpc('shop_order_command',[e.hash,e.csrf,uuid(k),this.signature(e,'order.'+op,d),op,d]);}
 async methods(e:Evidence,input:unknown){const d=fields(input,['orderId']);return this.manual.hydrate(await this.repo.rpc('shop_payment_methods',[e.hash,e.csrf,uuid(d.orderId)]));}
 async payment(e:Evidence,k:string,input:unknown){const d=fields(input,['orderId','version','method','cardId']);d.orderId=uuid(d.orderId);if(d.cardId!==null)d.cardId=uuid(d.cardId);const state=token(),online=d.method==='ONLINE_GATEWAY';
  const payload={...d,callbackHash:online?digest(state).toString('hex'):null,callbackCiphertext:online?seal(this.repo.cfg.encryptionKey,state,'payment-callback:'+d.orderId):null};
  return this.repo.rpc('shop_payment_start',[e.hash,e.csrf,uuid(k),this.signature(e,'payment.start',d),payload]);
 }
}
