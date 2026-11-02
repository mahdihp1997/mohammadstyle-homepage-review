import {services,type ServiceId} from '@/data/site';
import type {ServerOffering} from '@/types/booking-server';

/** URL selections are hints. Keep only known brochure IDs, once, in menu order. */
export function bookingEntryServices(value:unknown):ServiceId[]{
 const values=Array.isArray(value)?value.slice(0,24):[value];
 const requested=new Set(values.flatMap(v=>typeof v==='string'&&v.length<=128?v.split(','):[]));
 return services.filter(s=>requested.has(s.id)).map(s=>s.id);
}
export function bookingEntryHref(ids:readonly ServiceId[]):string{
 const query=new URLSearchParams();for(const id of bookingEntryServices(ids))query.append('service',id);
 return '/booking'+(query.size?'?'+query.toString():'');
}
/** The current catalog has names/UUIDs, not brochure codes. Ambiguous names never preselect. */
export function bookingEntryOfferings(offerings:readonly ServerOffering[],branchId:string,ids:readonly ServiceId[]):string[]{
 return bookingEntryServices(ids).flatMap(id=>{
  const name=services.find(s=>s.id===id)!.name;
  const matches=offerings.filter(o=>o.branchId===branchId&&o.name===name);
  return matches.length===1?[matches[0].id]:[];
 });
}
