import {HttpException} from '@nestjs/common';import {uuid} from '../admin/contracts.js';
export const commandFields:Record<string,string[]>={
 availability:['branchId','offeringIds','staffId','date','optionalDepositChosen','rescheduleBookingId','cursor'],
 quote:['planId'],draft:['branchId'],
 hold:['bookingId','version','quoteId','contentHash','snapshotHash','accepted'],
 reschedule:['bookingId','version','quoteId','contentHash','snapshotHash','accepted'],
 confirm:['bookingId','version'],cancel:['bookingId','version'],
 'configuration.enable':['branchId','offeringIds'],
};
export function validateCommand(op:string,raw:unknown):Record<string,unknown>{
 const invalid=():never=>{throw new HttpException('Invalid booking contract',422);};
 const fields=commandFields[op];if(!fields||!raw||typeof raw!=='object'||Array.isArray(raw))return invalid();
 const d=raw as Record<string,unknown>;
 if(Object.keys(d).length!==fields.length||fields.some(k=>!Object.hasOwn(d,k)))return invalid();
 for(const k of fields){const v=d[k];
  if(['branchId','planId','bookingId','quoteId'].includes(k))uuid(v);
  else if(['staffId','rescheduleBookingId'].includes(k)){if(v!==null)uuid(v);}
  else if(k==='offeringIds'){if(!Array.isArray(v)||v.length<1||v.length>12)return invalid();for(const id of v)uuid(id);if(new Set(v).size!==v.length)return invalid();}
  else if(k==='date'){if(typeof v!=='string'||!/^20\d{2}-\d{2}-\d{2}$/.test(v))return invalid();}
  else if(k==='cursor'){if(typeof v!=='string'||!/^(0|[1-9]\d{0,3})$/.test(v)||Number(v)>1439)return invalid();}
  else if(k==='version'){if(typeof v!=='string'||!/^[1-9]\d{0,18}$/.test(v)||BigInt(v)>9223372036854775807n)return invalid();}
  else if(['contentHash','snapshotHash'].includes(k)){if(typeof v!=='string'||!/^[0-9a-f]{64}$/.test(v))return invalid();}
  else if(typeof v!=='boolean')return invalid();
 }return d;
}
