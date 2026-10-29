import fs from'node:fs';import{canonical,contentHash,rial}from'./canonical.js';
type Schema={type?:string;const?:unknown;enum?:unknown[];anyOf?:Schema[];properties?:Record<string,Schema>;required?:string[];additionalProperties?:boolean;items?:Schema;minItems?:number;pattern?:string;minLength?:number;maxLength?:number;format?:string};
const schema=JSON.parse(fs.readFileSync(new URL('../../../docs/architecture/schema/quote-content.schema.json',import.meta.url),'utf8')) as Schema;
function check(s:Schema,v:unknown,key=''):void{
 if(s.anyOf){if(!s.anyOf.some(x=>{try{check(x,v,key);return true;}catch{return false;}}))throw Error('Invalid nullable field');return;}
 if(Object.hasOwn(s,'const')&&v!==s.const||s.enum&&!s.enum.includes(v))throw Error('Invalid domain');
 if(s.type==='object'){if(!v||typeof v!=='object'||Array.isArray(v))throw Error('Object required');const o=v as Record<string,unknown>;if(s.required?.some(k=>!Object.hasOwn(o,k))||Object.keys(o).some(k=>!Object.hasOwn(s.properties??{},k)))throw Error('Exact fields required');for(const[k,x]of Object.entries(o))check(s.properties![k]!,x,k);}
 else if(s.type==='array'){if(!Array.isArray(v)||v.length<(s.minItems??0)||v.length>64)throw Error('Invalid array');for(const x of v)check(s.items!,x,key);}
 else if(s.type==='null'){if(v!==null)throw Error('Null required');}
 else if(s.type==='boolean'){if(typeof v!=='boolean')throw Error('Boolean required');}
 else if(s.type==='string'){if(typeof v!=='string'||v.length<(s.minLength??0)||v.length>(s.maxLength??20000))throw Error('String required');
 // The proposal schema over-escaped timestamp dots; its written UTC semantic contract is authoritative.
 if(['startsAt','endsAt'].includes(key)){if(!/^20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(v)||new Date(v).toISOString()!==v)throw Error('UTC milliseconds required');}
 else if(s.pattern&&!new RegExp(s.pattern).test(v))throw Error('Invalid string');
 if(s.format==='uuid'&&!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(v))throw Error('UUID required');
 if(/Rial$/.test(key))rial(v);else if(/^(position|sequence|quoteItemPosition|quantity|offeringVersion|versionNumber|durationMinutes|bufferBeforeMinutes|bufferAfterMinutes)$/.test(key)&&BigInt(v)>9223372036854775807n)throw Error('Integer overflow');}
}
/** Integrity serialization for a future trusted B4 caller, not a plan validator or issuance endpoint. */
export function finalQuoteContentHash(document:unknown):string{
 check(schema,document);canonical(document);
 const d=structuredClone(document) as Record<string,unknown>;
 type Row=Record<string,unknown>;
 const ordered=(rows:Row[],field:string):Row[]=>rows.sort((a,b)=>BigInt(a[field] as string)<BigInt(b[field] as string)?-1:BigInt(a[field] as string)>BigInt(b[field] as string)?1:0);
 const items=ordered(d.items as Row[],'position'),segments=ordered(d.segments as Row[],'sequence'),policy=d.policy as Row;
 for(const [i,item]of items.entries())if(item.position!==String(i+1))throw Error('Contiguous item positions required');
 for(const [i,segment]of segments.entries()){
  if(segment.sequence!==String(i+1))throw Error('Contiguous segment sequences required');
  const resources=segment.resources as Row[];resources.sort((a,b)=>String(a.resourceId).localeCompare(String(b.resourceId),'en')||String(a.kind).localeCompare(String(b.kind),'en'));
  if(new Set(resources.map(r=>r.resourceId+':'+r.kind)).size!==resources.length)throw Error('Duplicate resource');
  const dependencies=(segment.dependsOnSequences as string[]).sort((a,b)=>BigInt(a)<BigInt(b)?-1:BigInt(a)>BigInt(b)?1:0);
  if(new Set(dependencies).size!==dependencies.length||dependencies.some(x=>BigInt(x)<1n||BigInt(x)>=BigInt(segment.sequence as string)))throw Error('Invalid dependency');
 }
 const sources=ordered(policy.sourceAssignments as Row[],'quoteItemPosition');sources.sort((a,b)=>BigInt(a.quoteItemPosition as string)<BigInt(b.quoteItemPosition as string)?-1:BigInt(a.quoteItemPosition as string)>BigInt(b.quoteItemPosition as string)?1:String(a.assignmentId).localeCompare(String(b.assignmentId),'en'));
 if(new Set(sources.map(s=>s.quoteItemPosition+':'+s.assignmentId)).size!==sources.length)throw Error('Duplicate assignment source');
 return contentHash(d);
}
