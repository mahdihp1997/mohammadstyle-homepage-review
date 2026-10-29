import {invalid,uuid} from '../admin/contracts.js';
export const operations=['policy.create','version.create','version.replace','version.publish','version.retire','assignment.create','assignment.revoke','configuration.set','quote.create','quote.validate','quote.cancellation-preview'] as const;
export type Operation=typeof operations[number];
export interface PolicyTerms {
 depositRequirement:'NONE'|'OPTIONAL'|'REQUIRED';amountKind:'FIXED'|'PERCENTAGE'|null;fixedRial:string|null;basisPoints:string|null;
 minimumRial:string|null;maximumRial:string|null;refundability:'FULL'|'NONE'|'PARTIAL'|'CONDITIONAL';refundBase:'DEPOSIT_PAID'|'ALL_PAID';
 outsideRefundBps:string;cancellationDeadlineMinutes:string;termsText:string;termsLocale:string;effectiveFrom:string;effectiveTo:string|null;
 refundWindows:{thresholdMinutes:string;refundBps:string}[];
}
export interface CommercialItem {position:string;offeringId:string;serviceId:string;offeringVersion:string;serviceVersion:string;displayName:string;quantity:'1';unitPriceRial:string;durationMinutes:string;bufferBeforeMinutes:string;bufferAfterMinutes:string}
export interface CommercialProposalContent {
 schema:'MS_COMMERCIAL_PROPOSAL_V1';businessId:string;branchId:string;source:'SERVER';currency:'IRR';unitVersion:'IRR_RIAL_V1';configurationFingerprint:string;
 timeZone:string;startsAt:string;endsAt:string;staffId:string|null;optionalDepositChosen:boolean;totalRial:string;depositRial:string;remainingRial:string;items:CommercialItem[];
 policy:{versionId:string;versionNumber:string;contentHash:string;resolverVersion:'B3_RESOLVER_V1';sourceAssignments:{quoteItemPosition:string;assignmentId:string;versionId:string}[];terms:PolicyTerms};
}
export interface CommercialProposal {id:string;content:CommercialProposalContent;contentHash:string;hashVersion:'MS_COMMERCIAL_PROPOSAL_V1';issuedAt:string;expiresAt:string;bookable:false;capacityReserved:false;finalQuoteAvailable:false}
export interface PricingReceipt {status:200;body:{id:string;version:string;operation:Operation;[key:string]:unknown}}
export interface CommandEnvelope {branchId:string|null;entityId:string|null;data:Record<string,unknown>}
export function command(op:string,raw:unknown):{op:Operation;value:CommandEnvelope}{
 if(!operations.includes(op as Operation)||!raw||typeof raw!=='object'||Array.isArray(raw))return invalid();const d=raw as Record<string,unknown>;
 if(Object.keys(d).length!==3||!['branchId','entityId','data'].every(k=>Object.hasOwn(d,k))||!d.data||typeof d.data!=='object'||Array.isArray(d.data))return invalid();
 return{op:op as Operation,value:{branchId:d.branchId===null?null:uuid(d.branchId),entityId:d.entityId===null?null:uuid(d.entityId),data:d.data as Record<string,unknown>}};
}
export function readQuery(q:Record<string,unknown>):{branch:string|null;history:boolean;offset:number}{if(Object.keys(q).some(k=>!['branchId','view','offset'].includes(k))||q.view!==undefined&&!['current','history'].includes(q.view as string)||q.offset!==undefined&&(typeof q.offset!=='string'||!/^(0|[1-9][0-9]{0,4})$/.test(q.offset)||Number(q.offset)>10000))return invalid();return{branch:q.branchId===undefined?null:uuid(q.branchId),history:q.view==='history',offset:Number(q.offset??0)};}
