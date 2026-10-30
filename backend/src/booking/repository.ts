import { Pool, type PoolClient } from 'pg';
import type { SessionView } from '../admin/contracts.js';
import { finalQuoteContentHash } from '../pricing/final-quote-contract.js';
export interface BookingOptions {
    host: '127.0.0.1';
    port: 55446 | 55450;
    database: 'ms_b4_dev' | 'ms_b4_restore' | 'ms_mvp_dev' | 'ms_mvp_restore';
    user: 'ms_b1b_api';
    password: string;
    origin: 'http://127.0.0.1:3110' | 'http://127.0.0.1:3112';
}
export class BookingRepository {
    protected readonly pool: Pool;
    private readonly marker: string;
    constructor(o: BookingOptions) {
        const original = o.port === 55446 && ['ms_b4_dev','ms_b4_restore'].includes(o.database) && o.origin === 'http://127.0.0.1:3110';
        const integration = process.env.APP_ENV === 'mvp-local' && o.port === 55450 && ['ms_mvp_dev','ms_mvp_restore'].includes(o.database) && o.origin === 'http://127.0.0.1:3112';
        this.marker = integration ? 'mohammadstyle-mvp-disposable-v1' : 'mohammadstyle-b4-disposable-v1';
        if (process.env.NODE_ENV === 'production' || process.env.APP_ENV === 'production' || o.host !== '127.0.0.1' || !(original || integration) || o.user !== 'ms_b1b_api' || !/^[a-f0-9]{64}$/.test(o.password))
            throw Error('B4 isolated local profile required');
        const { origin: _origin, ...connection } = o;
        this.pool = new Pool({ ...connection, max: 4, connectionTimeoutMillis: 2000, statement_timeout: 30000, idle_in_transaction_session_timeout: 15000 });
        this.pool.on('error', () => { });
    }
    async onModuleInit() { const r = (await this.pool.query("SELECT current_database() db,current_setting('server_version_num')::int version,shobj_description((SELECT oid FROM pg_database WHERE datname=current_database()),'pg_database') marker,has_function_privilege(current_user,to_regprocedure('ms_b1_design.b4_command(bytea,bytea,text,text,uuid,jsonb)'),'EXECUTE') ready")).rows[0]; if (!r.ready || r.marker !== this.marker || r.version < 180000 || r.version >= 190000)
        throw Error('Reviewed B4 PostgreSQL18 migrations required'); }
    async session(h: Buffer): Promise<SessionView> { return (await this.pool.query('SELECT ms_b1_design.b1b_session($1) result', [h])).rows[0].result; }
    protected async transaction<T>(fn: (c: PoolClient) => Promise<T>): Promise<T> {
        for (let attempt = 0;; attempt++) {
            const c = await this.pool.connect();
            try {
                await c.query('BEGIN ISOLATION LEVEL SERIALIZABLE');
                await c.query("SET LOCAL lock_timeout='5s'");
                await c.query('SET LOCAL jit=off');
                const result = await fn(c);
                await c.query('COMMIT');
                return result;
            }
            catch (e) {
                await c.query('ROLLBACK').catch(() => { });
                if (attempt >= 2 || !['40001', '40P01'].includes((e as {
                    code?: string;
                }).code ?? ''))
                    throw e;
            }
            finally {
                c.release();
            }
            await new Promise(resolve => setTimeout(resolve, 20 * (attempt + 1)));
        }
    }
    async sweep(h: Buffer, csrf: Buffer) { return this.transaction(async (c) => (await c.query('SELECT ms_b1_design.b4_sweep($1,$2) result', [h, csrf])).rows[0].result as number); }
    async read(h: Buffer, csrf: Buffer, kind: string, id: string | null, offset: number): Promise<Record<string, unknown>> {
        await this.sweep(h, csrf);
        return this.transaction(async (c) => (await c.query('SELECT ms_b1_design.b4_read($1,$2,$3,$4,$5) result', [h, csrf, kind, id, offset])).rows[0].result as Record<string, unknown>);
    }
    async command(h: Buffer, csrf: Buffer, op: string, key: string, requestId: string, data: unknown): Promise<Record<string, unknown>> {
        await this.sweep(h, csrf);
        return this.transaction(async (c) => {
            const result = (await c.query('SELECT ms_b1_design.b4_command($1,$2,$3,$4,$5,$6) result', [h, csrf, op, key, requestId, data])).rows[0].result as Record<string, unknown>;
            // Integrity validation is inside the transaction, before COMMIT. SQL planner owns semantics.
            const q = (op === 'quote' ? result : result.quote) as {
                content?: unknown;
                contentHash?: string;
            } | undefined;
            if (q?.content && finalQuoteContentHash(q.content) !== q.contentHash)
                throw Error('B4 quote serialization mismatch');
            return result;
        });
    }
    async onApplicationShutdown() { await this.pool.end(); }
}
