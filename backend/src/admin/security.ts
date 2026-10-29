import { createHash, randomUUID } from 'node:crypto';
import { Catch, HttpException, Inject, Injectable, type ArgumentsHost, type CanActivate, type ExceptionFilter, type ExecutionContext } from '@nestjs/common';
import { AdminRepository, type AdminOptions } from './repository.js';
import type { SessionView } from './contracts.js';
import { event } from '../observability.js';
export const ADMIN_OPTIONS = Symbol('B1B options');
export interface Request { requestId?: string; headers: Record<string,string | string[] | undefined>; method: string; ip: string; socket: {remoteAddress?:string} }
export interface Response { status(n:number): Response; json(value:unknown): void; setHeader(k:string,v:string):void }
export interface Evidence { hash: Buffer; csrf: Buffer; actor: SessionView; requestId: string }
const verified = new WeakMap<Request,Evidence>();
export function evidence(request: Request): Evidence { const found = verified.get(request); if (!found) throw new HttpException('Unauthenticated',401); return found; }
export const hashToken = (value: string): Buffer => createHash('sha256').update(value,'ascii').digest();
export const sessionCookie = (token: string, maxAge: number): string => `ms_session=${token}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${maxAge}`;

/** One bounded process/loopback API only. No trust-proxy or client X-Forwarded-For.
 * Distributed limits and trusted proxy configuration remain production gates.
 */
class Limiter {
  private readonly entries = new Map<string,{start:number;count:number}>();
  take(key: string, limit: number): void {
    const now = Date.now();
    for (const [k,v] of this.entries) if (v.start+60000<=now) this.entries.delete(k);
    let entry = this.entries.get(key);
    if (!entry) { if (this.entries.size>=10000) throw new HttpException('Unavailable',503); entry={start:now,count:0};this.entries.set(key,entry); }
    if (++entry.count>limit) throw new HttpException('Rate limited',429);
  }
}
@Injectable()
export class SessionGuard implements CanActivate {
  private readonly limiter = new Limiter();
  constructor(private readonly repository: AdminRepository,@Inject(ADMIN_OPTIONS) private readonly options: AdminOptions) {}
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request>(); const res = context.switchToHttp().getResponse<Response>();
    const requestId=req.requestId ?? randomUUID();
    res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('X-Request-Id',requestId);
    this.limiter.take('ip:'+req.socket.remoteAddress,240);
    const cookie = req.headers.cookie;
    const matches = typeof cookie === 'string' ? cookie.split(';').map(s=>s.trim()).filter(s=>s.startsWith('ms_session=')) : [];
    if (matches.length!==1 || !/^ms_session=[A-Za-z0-9_-]{43}$/.test(matches[0] ?? '')) throw new HttpException('Unauthenticated',401);
    const hash = hashToken(matches[0]!.slice('ms_session='.length));
    this.limiter.take('session:'+hash.toString('hex'),120);
    const actor = await this.repository.session(hash);
    const mutation = !['GET','HEAD'].includes(req.method);
    let csrf: Buffer = Buffer.alloc(32);
    if (mutation) {
      this.limiter.take('write:'+hash.toString('hex'),60);
      if (req.headers.origin !== this.options.origin || (req.headers['sec-fetch-site'] && req.headers['sec-fetch-site'] !== 'same-origin') || typeof req.headers['content-type']!=='string' || !/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(req.headers['content-type'])) throw new HttpException('Forbidden',403);
      const token = req.headers['x-csrf-token'];
      if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token)) throw new HttpException('Forbidden',403);
      csrf = hashToken(token);
    }
    verified.set(req,{hash,csrf,actor,requestId});return true;
  }
}
@Catch()
export class AdminExceptionFilter implements ExceptionFilter {
  catch(error: unknown, host: ArgumentsHost): void {
    const e = error as {code?:string;status?:number};
    let status = error instanceof HttpException ? error.getStatus() : [400,413,415].includes(e?.status ?? 0) ? e.status! : /^MS(401|403|404|409|412|422)$/.test(e?.code ?? '') ? Number(e.code!.slice(2)) : e?.code === '23505' ? 409 : /^(22|23)/.test(e?.code ?? '') ? 422 : 503;
    if (status<400 || status>599) status=503;
    const response = host.switchToHttp().getResponse<Response>();
    const requestId=host.switchToHttp().getRequest<Request>().requestId ?? randomUUID();
    event('b1b.http.denied_or_failed',{requestId,status});
    response.setHeader('Cache-Control','no-store');
    if (status===429) response.setHeader('Retry-After','60');
    response.status(status).json({code:({401:'UNAUTHENTICATED',403:'FORBIDDEN',404:'NOT_FOUND',409:'CONFLICT',412:'STALE_VERSION',422:'INVALID_CONFIGURATION',429:'RATE_LIMITED'} as Record<number,string>)[status] ?? (status===503?'UNAVAILABLE':'INVALID_REQUEST'),message:'Request could not be completed',requestId,retryable:status===503 || status===429});
  }
}
