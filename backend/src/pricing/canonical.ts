import {createHash} from 'node:crypto';
/** RFC8785 on the approved decimal-string/boolean/null domain. No money Number. */
export function canonical(value:unknown):string {
 if(value===null||typeof value==='boolean')return JSON.stringify(value);
 if(typeof value==='string'){if(/[\uD800-\uDFFF]/u.test(value))throw Error('Invalid Unicode');return JSON.stringify(value);}
 if(Array.isArray(value))return '['+value.map(canonical).join(',')+']';
 if(value&&typeof value==='object'){const o=value as Record<string,unknown>;return '{'+Object.keys(o).sort().map(k=>canonical(k)+':'+canonical(o[k])).join(',')+'}';}
 throw Error('Integer values must be canonical decimal strings');
}
export const contentHash=(value:unknown):string=>createHash('sha256').update(canonical(value),'utf8').digest('hex');
export const MAX_RIAL=9223372036854775807n;
export function rial(s:string):bigint {if(!/^(0|[1-9][0-9]*0)$/.test(s)||s.length>19||BigInt(s)>MAX_RIAL)throw Error('Invalid Rial');return BigInt(s);}
export function percentage(amount:bigint,bps:bigint):bigint {if(amount<0n||amount>MAX_RIAL||amount%10n!==0n||bps<0n||bps>10000n)throw Error('Invalid amount');return((amount*bps+50000n)/100000n)*10n;}
/** Called on raw JSON before the platform constructs the DTO. */
export function uniqueJson(raw:string):void {
 JSON.parse(raw);let i=0;const ws=()=>{while(/\s/.test(raw[i]??'')&&i<raw.length)i++;};
 const str=():string=>{const start=i++;while(i<raw.length){if(raw[i]==='\\'){i+=2;continue;}if(raw[i++]==='"')break;}const s=JSON.parse(raw.slice(start,i)) as string;if(/[\uD800-\uDFFF]/u.test(s))throw Error('Invalid Unicode');return s;};
 const value=():void=>{ws();if(raw[i]==='"'){str();return;}if(raw[i]==='{'){i++;ws();const keys=new Set<string>();if(raw[i]==='}'){i++;return;}for(;;){ws();const k=str();if(keys.has(k))throw Error('Duplicate JSON key');keys.add(k);ws();i++;value();ws();if(raw[i++]==='}')break;}return;}
 if(raw[i]==='['){i++;ws();if(raw[i]===']'){i++;return;}for(;;){value();ws();if(raw[i++]===']')break;}return;}while(i<raw.length&&!/[\s,\]}]/.test(raw[i]!))i++;};value();
}
