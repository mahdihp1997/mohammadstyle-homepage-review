import { ArgumentsHost, Catch, ExceptionFilter, HttpException, LoggerService } from '@nestjs/common';
import { randomUUID } from 'node:crypto';

export function event(name: string, fields: Record<string, string | number | boolean> = {}): void {
  process.stdout.write(`${JSON.stringify({ time: new Date().toISOString(), event: name, ...fields })}\n`);
}

/** Framework messages are not serialized: arbitrary exception strings can contain secrets. */
export class StructuredLogger implements LoggerService {
  log(): void { event('framework.info'); }
  error(): void { event('framework.error'); }
  warn(): void { event('framework.warn'); }
  debug(): void { /* disabled for this foundation */ }
  verbose(): void { /* disabled */ }
  fatal(): void { event('framework.fatal'); }
}
interface HttpRequest { requestId?: string; method: string }
interface HttpResponse { statusCode: number; setHeader(name: string, value: string): void;
  once(name: string, fn: () => void): void; status(code: number): HttpResponse; json(body: unknown): void }

export function requestDiagnostics(req: HttpRequest, res: HttpResponse, next: () => void): void {
  req.requestId = randomUUID();
  res.setHeader('X-Request-Id', req.requestId);
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.once('finish', () => event('http.completed', { requestId: req.requestId!, method: req.method, status: res.statusCode }));
  next();
}

@Catch()
export class SafeExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const request = http.getRequest<HttpRequest>();
    const status = exception instanceof HttpException ? exception.getStatus() : 500;
    event('http.failed', { requestId: request.requestId ?? 'unassigned', status });
    http.getResponse<HttpResponse>().status(status).json({ statusCode: status,
      code: status === 503 ? 'DATABASE_NOT_READY' : status === 404 ? 'NOT_FOUND' : 'REQUEST_FAILED',
      requestId: request.requestId });
  }
}
