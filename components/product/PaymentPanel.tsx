'use client';
import {useCallback,useEffect,useRef,useState} from 'react';import {productApi} from '@/lib/product/client';import {rialLabel} from '@/lib/booking/server-adapter';import type{ServerBooking}from '@/types/booking-server';
export interface Payment{ id:string;state:string;amountRial:string;currency:string;hostedUrl:string|null;expiresAt:string;reference?:string;refunds:{id:string;state:string;reason:string;maximumRial:string;requestedRial:string|null}[] }
const states:Record<string,string>={REQUESTED:'در حال ساخت درخواست پرداخت',REDIRECT_READY:'آمادهٔ انتقال به درگاه',VERIFYING:'در انتظار تأیید مستقل درگاه',VERIFIED:'پرداخت تأیید شده توسط درگاه',DECLINED:'پرداخت ناموفق یا لغوشده',UNKNOWN:'نتیجهٔ نامشخص؛ در حال بررسی',CLOSED:'مهلت پرداخت پایان یافته',REVIEW:'در انتظار بررسی بازپرداخت'};
export default function PaymentPanel({booking,onChange}:{booking:ServerBooking;onChange?:()=>void}){
 const [items,setItems]=useState<Payment[]>([]),[busy,setBusy]=useState(false),[error,setError]=useState(''),[loading,setLoading]=useState(true);const lock=useRef(false),changed=useRef(onChange);changed.current=onChange;const status=useRef('');
 const refresh=useCallback(async()=>{try{const r=await productApi<{items:Payment[];bookingStatus:string}>('payments/read',{bookingId:booking.id});setError('');setItems(r.items);if(status.current&&status.current!==r.bookingStatus)changed.current?.();status.current=r.bookingStatus;}catch(e){setError((e as Error).message);}finally{setLoading(false);}},[booking.id]);
 useEffect(()=>{void refresh();},[refresh,booking.status]);
 const pending=items.some(p=>['REQUESTED','VERIFYING','REDIRECT_READY'].includes(p.state));
 useEffect(()=>{if(!pending)return;const timer=setInterval(()=>{if(!lock.current)void refresh();},5000);return()=>clearInterval(timer);},[pending,refresh]);
 async function start(){if(lock.current)return;lock.current=true;setBusy(true);setError('');try{await productApi('payments/start',{bookingId:booking.id,version:booking.version});await refresh();}catch(e){setError((e as Error).message);}finally{lock.current=false;setBusy(false);}}
 if(!items.length&&booking.status!=='PENDING_PAYMENT'&&!error)return null;
 return <section className="product-payment" aria-label="وضعیت پرداخت"><h3>پرداخت و پیگیری</h3>{error&&<p className="product-error" role="alert">{error}</p>}{loading&&<p role="status">در حال دریافت وضعیت پرداخت…</p>}
 {!items.length&&booking.status==='PENDING_PAYMENT'&&<><p>رزرو تا پایان مهلت نگهداری ظرفیت، در انتظار پرداخت است. پیش از تأیید مستقل درگاه، نوبت نهایی نمی‌شود.</p><button type="button" className="btn btn-gold" disabled={busy||loading} onClick={()=>void start()}>{busy?'در حال درخواست…':'دریافت لینک پرداخت'}</button></>}
 {items.map(p=><div key={p.id}><p role="status"><strong>{states[p.state]??p.state}</strong></p><dl><dt>مبلغ</dt><dd>{rialLabel(p.amountRial)}</dd><dt>شناسهٔ پرداخت</dt><dd className="product-hash">{p.id}</dd>{p.reference&&<><dt>مرجع تأییدشده</dt><dd className="product-hash">{p.reference}</dd></>}</dl>
 {p.state==='REDIRECT_READY'&&p.hostedUrl&&Date.parse(p.expiresAt)>Date.now()&&booking.status==='PENDING_PAYMENT'&&<a className="btn btn-gold" href={p.hostedUrl} referrerPolicy="no-referrer">ادامه در صفحهٔ امن درگاه</a>}
 {['UNKNOWN','VERIFYING'].includes(p.state)&&<p className="product-note">پرداخت دیگری آغاز نکنید. نتیجهٔ نهایی پس از بررسی درگاه در همین حساب نمایش داده می‌شود.</p>}
 {p.refunds.map(r=><p key={r.id}>بازپرداخت: {states[r.state]??({REQUESTED:'درخواست‌شده',VERIFIED:'تأییدشده توسط ارائه‌دهنده',UNKNOWN:'نیازمند بررسی',DECLINED:'ناموفق'}[r.state]??r.state)}{r.requestedRial?' · '+rialLabel(r.requestedRial):''}</p>)}</div>)}
 <div className="product-actions"><button className="booking-text-button" type="button" disabled={busy} onClick={()=>void refresh()}>بررسی دوبارهٔ وضعیت پرداخت</button></div></section>;
}
