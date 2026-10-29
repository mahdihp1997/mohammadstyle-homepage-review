import { Inject, Injectable, Module, OnApplicationShutdown } from '@nestjs/common';
import { Pool } from 'pg';
import { CONFIG, type B0Config } from './config.js';

@Injectable()
export class DatabaseProbe implements OnApplicationShutdown {
  private readonly pool: Pool;
  constructor(@Inject(CONFIG) config: B0Config) {
    this.pool = new Pool({ ...config.database, max: 2, connectionTimeoutMillis: 1000,
      idleTimeoutMillis: 5000, statement_timeout: 1000, query_timeout: 1500,
      application_name: 'mohammadstyle-b0-health' });
    this.pool.on('error', () => { /* Failed readiness reports outage without exposing connection details. */ });
  }
  async ready(): Promise<boolean> {
    try { const result = await this.pool.query('SELECT 1 AS ok'); return result.rows[0]?.ok === 1; }
    catch { return false; }
  }
  async onApplicationShutdown(): Promise<void> { await this.pool.end(); }
}
@Module({ providers: [DatabaseProbe], exports: [DatabaseProbe] })
export class DatabaseModule {}
