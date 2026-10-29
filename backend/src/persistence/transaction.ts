import { Pool, type PoolClient, type QueryResultRow } from 'pg';

/** Supplied only after future application authorization. A UUID is not proof of access. */
export interface TenantContext { readonly businessId: string }
export interface PersistenceOptions { host: '127.0.0.1'; port: 55434; database: 'ms_b1a_dev' | 'ms_b1a_restore'; user: 'ms_b1a_runtime'; password: string }
export interface Transaction {
  readonly businessId: string;
  query<T extends QueryResultRow = QueryResultRow>(sql: string, values?: unknown[]): Promise<T[]>;
}
class ScopedTransaction implements Transaction {
  private active = true;
  constructor(private readonly client: PoolClient, readonly businessId: string) {}
  async query<T extends QueryResultRow = QueryResultRow>(sql: string, values: unknown[] = []): Promise<T[]> {
    if (!this.active) throw new Error('Transaction scope has ended');
    return (await this.client.query<T>(sql, values)).rows;
  }
  finish(): void { this.active = false; }
}

/** Shared explicit transaction scope; no ambient tenant or automatic retry of callbacks. */
export class TransactionManager {
  private readonly pool: Pool;
  constructor(options: PersistenceOptions) {
    if (options.host !== '127.0.0.1' || options.port !== 55434 || !['ms_b1a_dev','ms_b1a_restore'].includes(options.database)
      || options.user !== 'ms_b1a_runtime' || !/^[a-f0-9]{64}$/.test(options.password)) throw new Error('Invalid isolated B1A persistence options');
    this.pool = new Pool({ ...options, max: 2, connectionTimeoutMillis: 2000, statement_timeout: 3000,
      idle_in_transaction_session_timeout: 5000, application_name: 'mohammadstyle-b1a-repository' });
    this.pool.on('error', () => { /* Query errors propagate without credential-bearing logs. */ });
  }
  async run<T>(context: TenantContext, work: (transaction: Transaction) => Promise<T>, isolation: 'READ COMMITTED' | 'SERIALIZABLE' = 'READ COMMITTED'): Promise<T> {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(context.businessId)) throw new Error('Invalid tenant context');
    if (!['READ COMMITTED','SERIALIZABLE'].includes(isolation)) throw new Error('Invalid transaction isolation');
    const client = await this.pool.connect(); const transaction = new ScopedTransaction(client, context.businessId); let discard = false;
    try {
      await client.query(`BEGIN ISOLATION LEVEL ${isolation}`);
      await client.query("SELECT set_config('ms.business_id',$1,true)", [context.businessId]);
      const value = await work(transaction);
      await client.query('COMMIT'); return value;
    } catch (error) {
      try { await client.query('ROLLBACK'); } catch { discard = true; }
      throw error;
    } finally { transaction.finish(); client.release(discard); }
  }
  async close(): Promise<void> { await this.pool.end(); }
  async onApplicationShutdown(): Promise<void> { await this.close(); }
}
