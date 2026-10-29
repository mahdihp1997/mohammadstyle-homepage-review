import type { Transaction } from './transaction.js';

export interface BusinessRecord { id: string; brand_name: string; slug: string; currency_code: string; row_version: string }
export interface BranchRecord { id: string; business_id: string; display_name: string; time_zone: string; active: boolean; bookable: boolean; row_version: string }
export interface ServiceRecord { id: string; business_id: string; display_name: string; active: boolean; row_version: string }
export interface OfferingRecord { id: string; business_id: string; branch_id: string; service_id: string; active: boolean; price_rial: string | null; duration_minutes: number | null; row_version: string }
export interface BusinessRepository { business(id: string): Promise<BusinessRecord | null> }
export interface BranchRepository { branch(id: string): Promise<BranchRecord | null> }
export interface ServiceRepository { service(id: string): Promise<ServiceRecord | null> }
export interface OfferingRepository { offering(id: string): Promise<OfferingRecord | null> }

/** Minimal read boundary for future modules; no configuration command, auth or booking API. */
export class ConfigurationReader implements BusinessRepository, BranchRepository, ServiceRepository, OfferingRepository {
  constructor(private readonly transaction: Transaction) {}
  async business(id: string): Promise<BusinessRecord | null> {
    return (await this.transaction.query<BusinessRecord>('SELECT id,brand_name,slug,currency_code,row_version FROM ms_b1_design.business WHERE id=$1 AND id=$2', [id,this.transaction.businessId]))[0] ?? null;
  }
  async branch(id: string): Promise<BranchRecord | null> {
    return (await this.transaction.query<BranchRecord>('SELECT id,business_id,display_name,time_zone,active,bookable,row_version FROM ms_b1_design.branch WHERE id=$1 AND business_id=$2', [id,this.transaction.businessId]))[0] ?? null;
  }
  async service(id: string): Promise<ServiceRecord | null> {
    return (await this.transaction.query<ServiceRecord>('SELECT id,business_id,display_name,active,row_version FROM ms_b1_design.service WHERE id=$1 AND business_id=$2', [id,this.transaction.businessId]))[0] ?? null;
  }
  async offering(id: string): Promise<OfferingRecord | null> {
    return (await this.transaction.query<OfferingRecord>('SELECT id,business_id,branch_id,service_id,active,price_rial,duration_minutes,row_version FROM ms_b1_design.branch_service_offering WHERE id=$1 AND business_id=$2', [id,this.transaction.businessId]))[0] ?? null;
  }
}
const tables = { business: 'business', branch: 'branch', service: 'service', offering: 'branch_service_offering' } as const;
/** Technical CAS proof only: advances concurrency metadata, changes no business configuration. */
export class VersionedWriter {
  constructor(private readonly transaction: Transaction) {}
  async advance(kind: keyof typeof tables, id: string, expectedVersion: string): Promise<string | null> {
    if (!Object.hasOwn(tables,kind) || !/^[1-9][0-9]*$/.test(expectedVersion) || BigInt(expectedVersion) > 9223372036854775807n) throw new Error('Invalid versioned write');
    const tenantColumn = kind === 'business' ? 'id' : 'business_id';
    const rows = await this.transaction.query<{ row_version: string }>(`UPDATE ms_b1_design.${tables[kind]} SET row_version=row_version+1,updated_at=clock_timestamp() WHERE id=$1 AND ${tenantColumn}=$2 AND row_version=$3 RETURNING row_version`, [id,this.transaction.businessId,expectedVersion]);
    return rows[0]?.row_version ?? null;
  }
}
