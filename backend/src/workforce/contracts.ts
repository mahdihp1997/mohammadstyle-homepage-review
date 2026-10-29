import { invalid, uuid } from '../admin/contracts.js';
export const commandFields = {
  "staff.create": [
    "displayName"
  ],
  "staff.update": [
    "displayName",
    "active"
  ],
  "staff.link": [
    "userId",
    "evidenceReference"
  ],
  "assignment.create": [
    "staffId",
    "validFrom",
    "validTo"
  ],
  "assignment.close": [
    "validTo",
    "reason"
  ],
  "qualification.set": [
    "staffId",
    "serviceId",
    "active",
    "evidenceReference"
  ],
  "eligibility.set": [
    "offeringId",
    "assignmentId",
    "qualificationId",
    "active"
  ],
  "resource.create": [
    "kind",
    "label",
    "active"
  ],
  "resource.update": [
    "label",
    "active"
  ],
  "hours.replace": [
    "segments",
    "reason"
  ],
  "rule.create": [
    "staffId",
    "assignmentId",
    "qualificationId",
    "offeringId",
    "isoWeekday",
    "startMinute",
    "endMinute",
    "validFrom",
    "validTo"
  ],
  "schedule.publish": [
    "staffId",
    "segments",
    "replaces",
    "reason",
    "overnight"
  ],
  "schedule.withdraw": [
    "staffId",
    "shiftIds",
    "reason"
  ],
  "timeoff.create": [
    "staffId",
    "startsAt",
    "endsAt",
    "reason"
  ],
  "closure.create": [
    "startsAt",
    "endsAt",
    "reason"
  ],
  "timeoff.review": [
    "approve",
    "reason"
  ],
  "closure.review": [
    "approve",
    "reason"
  ],
  "configuration.set": [
    "slotStrideMinutes",
    "leadMinutes",
    "horizonDays",
    "holdTtlSeconds",
    "quoteTtlSeconds"
  ]
} as const;
export type Operation = keyof typeof commandFields;
export interface Segment { ruleId: string; ruleVersion: string; date: string; startResolution: 'reject'|'earlier'|'later'; endResolution: 'reject'|'earlier'|'later' }
export interface HoursSegment { isoWeekday:number;startMinute:number;endMinute:number;validFrom:string;validTo:string|null }
export interface CommandDataMap {
 'staff.create':{displayName:string};
 'staff.update':{displayName:string;active:boolean};
 'staff.link':{userId:string;evidenceReference:string};
 'assignment.create':{staffId:string;validFrom:string;validTo:string|null};
 'assignment.close':{validTo:string;reason:string};
 'qualification.set':{staffId:string;serviceId:string;active:boolean;evidenceReference:string};
 'eligibility.set':{offeringId:string;assignmentId:string;qualificationId:string;active:boolean};
 'resource.create':{kind:'CHAIR'|'ROOM'|'DEVICE';label:string;active:boolean};
 'resource.update':{label:string;active:boolean};
 'hours.replace':{segments:HoursSegment[];reason:string};
 'rule.create':HoursSegment&{staffId:string;assignmentId:string;qualificationId:string;offeringId:string|null};
 'schedule.publish':{staffId:string;segments:Segment[];replaces:string[];reason:string;overnight:boolean};
 'schedule.withdraw':{staffId:string;shiftIds:string[];reason:string};
 'timeoff.create':{staffId:string;startsAt:string;endsAt:string;reason:string};
 'closure.create':{startsAt:string;endsAt:string;reason:string};
 'timeoff.review':{approve:boolean;reason:string};
 'closure.review':{approve:boolean;reason:string};
 'configuration.set':{slotStrideMinutes:number|null;leadMinutes:number|null;horizonDays:number|null;holdTtlSeconds:number|null;quoteTtlSeconds:number|null};
}
export type CommandData = CommandDataMap[Operation];
export interface WorkforceRecord {id:string;recordVersion:string;kind:string;archived:boolean;evidenceState?:'PUBLISHED'|'DRAFT'|'WITHDRAWN'|'ARCHIVED_DRAFT';scopeAssignmentId?:string;intervalScope?:'BRANCH_MEMBERSHIP_AND_QUERY';[key:string]:unknown}
export interface WorkforcePage {version:string;items:WorkforceRecord[];limit:100;offset:number;ownScheduleOnly:boolean;capacityReserved:false;projection?:'current'|'history'}
export interface WorkforceReceipt {status:200;body:{id:string;version:string;operation:Operation;items:{id:string;startsAt:string;endsAt:string;date:string;timeZone:string;ruleId:string;ruleVersion:string}[]}}
export function validate(op:Operation,value:unknown):CommandData {
 if(!value||typeof value!=='object'||Array.isArray(value))return invalid();
 const d=value as Record<string,unknown>,keys:readonly string[]=commandFields[op];
 if(Object.keys(d).length!==keys.length||!keys.every(k=>Object.hasOwn(d,k)))return invalid();
 for(const [k,v]of Object.entries(d)){
 if(['active','approve','overnight'].includes(k)&&typeof v!=='boolean')invalid();
 if(['displayName','label','reason','evidenceReference','kind'].includes(k)&&(typeof v!=='string'||!v.trim()||v.length>200))invalid();
 if(k.endsWith('Id')&&!(k==='offeringId'&&v===null))uuid(v);
 if(['segments','replaces','shiftIds'].includes(k)&&(!Array.isArray(v)||v.length>62))invalid();
 if(['validFrom','validTo'].includes(k)&&!(k==='validTo'&&v===null)&&(typeof v!=='string'||!/^20[0-9]{2}-[0-9]{2}-[0-9]{2}$/.test(v)))invalid();
 }
 return d as unknown as CommandData;
}
export function query(q:Record<string,unknown>):{from:string;to:string;offset:number;branch:string|null;staff:string|null;view:'current'|'history'} {
 if(Object.keys(q).some(k=>!['from','to','offset','branchId','staffId','view'].includes(k)))invalid();
 if(q.view!==undefined&&q.view!=='current'&&q.view!=='history')invalid();
 const {from,to}=q;
 if(typeof from!=='string'||typeof to!=='string'||!/^20[0-9]{2}-[0-9]{2}-[0-9]{2}$/.test(from)||!/^20[0-9]{2}-[0-9]{2}-[0-9]{2}$/.test(to))return invalid();
 if(q.offset!==undefined&&(typeof q.offset!=='string'||!/^(0|[1-9][0-9]{0,4})$/.test(q.offset)||Number(q.offset)>10000))invalid();
 return {from,to,offset:Number(q.offset??0),branch:q.branchId===undefined?null:uuid(q.branchId),staff:q.staffId===undefined?null:uuid(q.staffId),view:q.view==='history'?'history':'current'};
}
