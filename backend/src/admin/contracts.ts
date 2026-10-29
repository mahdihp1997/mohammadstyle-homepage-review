import { BadRequestException, HttpException, type PipeTransform } from '@nestjs/common';

export type ResourceKind = 'branch' | 'service' | 'offering';
export interface BranchWrite { code: string; displayName: string; address: string | null; timeZone: string; active: boolean; bookable: false }
export interface ServiceWrite { code: string; displayName: string; description: string | null; active: boolean }
export interface Money { amountRial: string; currency: 'IRR'; unitVersion: 'IRR_RIAL_V1' }
export interface OfferingWrite { serviceId: string; active: false; price: Money | null; durationMinutes: number | null; bufferBeforeMinutes: number | null; bufferAfterMinutes: number | null; eligibleStaffIds: never[]; resourcesConfirmed: false; resourceRequirements: never[] }
export type WriteDto = BranchWrite | ServiceWrite | OfferingWrite;
export interface SessionView { authenticated: true; userId: string; businessId: string; assignments: {role: string; branchId: string | null; permission: string}[] }
export interface RecordView { id: string; version: string; [key: string]: unknown }
export interface CommandResult { status: number; body: RecordView | { revoked: true } }
export interface PageQuery { limit: number; offset: number; sort: 'asc' | 'desc' }
export const invalid = (): never => { throw new HttpException('Invalid request', 422); };
export function uuid(value: unknown): string {
  if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(value)) return invalid();
  return value;
}
function object(value: unknown, keys: string[]): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return invalid();
  const o = value as Record<string, unknown>;
  if (Object.keys(o).length !== keys.length || !keys.every(k => Object.hasOwn(o, k))) return invalid();
  return o;
}
function text(value: unknown, max: number, nullable = false): void {
  if (nullable && value === null) return;
  if (typeof value !== 'string' || value.length > max || (!nullable && !value.trim())) invalid();
}
export function validateWrite(kind: ResourceKind, value: unknown): WriteDto {
  const keys = kind === 'branch' ? ['code','displayName','address','timeZone','active','bookable'] : kind === 'service'
    ? ['code','displayName','description','active'] : ['serviceId','active','price','durationMinutes','bufferBeforeMinutes','bufferAfterMinutes','eligibleStaffIds','resourcesConfirmed','resourceRequirements'];
  const d = object(value, keys);
  if (typeof d.active !== 'boolean') invalid();
  if (kind === 'branch' || kind === 'service') {
    if (typeof d.code !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/.test(d.code)) invalid();
    text(d.displayName,200); text(d[kind === 'branch' ? 'address' : 'description'],kind === 'branch' ? 1000 : 2000,true);
  }
  if (kind === 'branch') {
    if (d.bookable !== false || typeof d.timeZone !== 'string' || d.timeZone.length > 100 || !(d.timeZone === 'UTC' || d.timeZone.includes('/'))) invalid();
    try { new Intl.DateTimeFormat('en',{timeZone:d.timeZone as string}).format(); } catch { invalid(); }
  }
  if (kind === 'offering') {
    uuid(d.serviceId);
    if (d.active !== false || d.resourcesConfirmed !== false || !Array.isArray(d.eligibleStaffIds) || d.eligibleStaffIds.length || !Array.isArray(d.resourceRequirements) || d.resourceRequirements.length) invalid();
    for (const k of ['durationMinutes','bufferBeforeMinutes','bufferAfterMinutes']) {
      const v = d[k]; if (v !== null && (typeof v !== 'number' || !Number.isInteger(v) || v < (k === 'durationMinutes' ? 1 : 0) || v > 2147483647)) invalid();
    }
    if (d.price !== null) {
      const m = object(d.price,['amountRial','currency','unitVersion']);
      if (m.currency !== 'IRR' || m.unitVersion !== 'IRR_RIAL_V1' || typeof m.amountRial !== 'string' || !/^(0|[1-9][0-9]*0)$/.test(m.amountRial) || m.amountRial.length > 19 || BigInt(m.amountRial) > 9223372036854775807n) invalid();
    }
  }
  return d as unknown as WriteDto;
}
export class WritePipe implements PipeTransform { constructor(private readonly kind: ResourceKind) {} transform(v: unknown): WriteDto { return validateWrite(this.kind,v); } }
export function pagination(value: Record<string, unknown>): PageQuery {
  if (Object.keys(value).some(k => !['limit','offset','sort'].includes(k))) invalid();
  const number = (v: unknown, fallback: number, max: number, min: number): number => {
    if (v === undefined) return fallback;
    if (typeof v !== 'string' || !/^(0|[1-9][0-9]{0,4})$/.test(v) || Number(v) > max || Number(v) < min) return invalid();
    return Number(v);
  };
  if (value.sort !== undefined && value.sort !== 'asc' && value.sort !== 'desc') invalid();
  return {limit:number(value.limit,25,100,1),offset:number(value.offset,0,10000,0),sort:(value.sort ?? 'asc') as 'asc' | 'desc'};
}
export function commandHeaders(headers: Record<string,string | string[] | undefined>, update: boolean): {key: string; version: string | null} {
  const key = headers['idempotency-key']; const match = headers['if-match'];
  if (typeof key !== 'string' || !/^[A-Za-z0-9_-]{16,128}$/.test(key)) invalid();
  if (update && (typeof match !== 'string' || !/^"[1-9][0-9]{0,18}"$/.test(match) || BigInt(match.slice(1,-1)) > 9223372036854775806n)) throw new HttpException('Version required',412);
  if (!update && match !== undefined) throw new BadRequestException('Unexpected If-Match');
  return {key:key as string,version:update ? (match as string).slice(1,-1) : null};
}
