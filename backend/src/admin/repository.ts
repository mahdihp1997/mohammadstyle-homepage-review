import { Pool } from 'pg';
import type { CommandResult, PageQuery, ResourceKind, SessionView, WriteDto } from './contracts.js';

export interface AdminOptions { host: '127.0.0.1'; port: 55436; database: 'ms_b1b_dev' | 'ms_b1b_restore'; user: 'ms_b1b_api'; password: string; origin: 'http://127.0.0.1:3102' }
export function assertOptions(o: AdminOptions): void {
  if (process.env.NODE_ENV === 'production' || process.env.APP_ENV === 'production' || o.host !== '127.0.0.1' || o.port !== 55436 || !['ms_b1b_dev','ms_b1b_restore'].includes(o.database) || o.user !== 'ms_b1b_api' || !/^[a-f0-9]{64}$/.test(o.password) || o.origin !== 'http://127.0.0.1:3102') throw new Error('B1B is isolated development only');
}
/** No public query(sql) method. Values reach only three fixed, reviewed SQL functions.
 * Each function owns its atomic transaction and re-verifies session and authorization.
 * The API role cannot SELECT/write tables, invoke private helpers or assume owner roles.
 */
export class AdminRepository {
  private readonly pool: Pool;
  constructor(options: AdminOptions) {
    assertOptions(options);
    const {origin: _origin,...connection} = options;
    this.pool = new Pool({...connection,max:4,connectionTimeoutMillis:2000,statement_timeout:5000,idle_in_transaction_session_timeout:5000,application_name:'mohammadstyle-b1b-api'});
    this.pool.on('error',()=>{});
  }
  async session(hash: Buffer): Promise<SessionView> { return (await this.pool.query('SELECT ms_b1_design.b1b_session($1) AS result',[hash])).rows[0].result; }
  async read(hash: Buffer, kind: ResourceKind | 'business', branchId: string | null, page: PageQuery): Promise<unknown> {
    return (await this.pool.query('SELECT ms_b1_design.b1b_read($1,$2,$3,$4,$5,$6) AS result',[hash,kind,branchId,page.limit,page.offset,page.sort])).rows[0].result;
  }
  async command(hash: Buffer, csrf: Buffer, kind: ResourceKind | 'session', id: string | null, branchId: string | null, version: string | null, key: string, requestId: string, data: WriteDto | Record<string,never>): Promise<CommandResult> {
    return (await this.pool.query('SELECT ms_b1_design.b1b_command($1,$2,$3,$4,$5,$6,$7,$8,$9) AS result',[hash,csrf,kind,id,branchId,version,key,requestId,data])).rows[0].result;
  }
  async onApplicationShutdown(): Promise<void> { await this.pool.end(); }
}
