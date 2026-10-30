import 'reflect-metadata';
import { Body, Controller, Post, Param, Req, UseGuards, Global, Module, Catch, HttpCode, HttpException, type ArgumentsHost } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { ADMIN_OPTIONS, AdminExceptionFilter, SessionGuard, evidence, type Request, type Response } from '../admin/security.js';
import { AdminRepository } from '../admin/repository.js';
import { uuid } from '../admin/contracts.js';
import { requestDiagnostics } from '../observability.js';
import { uniqueJson } from '../pricing/canonical.js';
import { BookingRepository, type BookingOptions } from './repository.js';
import {validateCommand} from './contracts.js';
const operations = new Set(['availability', 'quote', 'draft', 'hold', 'confirm', 'cancel', 'reschedule', 'configuration.enable']);
@Catch()
export class BookingFilter extends AdminExceptionFilter {
    override catch(error: unknown, host: ArgumentsHost) {
        const e = error as {
            code?: string;
            message?: string;
        };
        if (e.code === '23P01' || /^MS(409|412|422|403|404)$/.test(e.code ?? '') && /^[A-Z][A-Z0-9_]{2,63}$/.test(e.message ?? '')) {
            const status = e.code === '23P01' ? 409 : Number(e.code!.slice(2)), res = host.switchToHttp().getResponse<Response>();
            res.setHeader('Cache-Control', 'no-store');
            res.status(status).json({ code: e.code === '23P01' ? 'RESOURCE_CONFLICT' : e.message, requestId: host.switchToHttp().getRequest<Request>().requestId, retryable: false });
            return;
        }
        super.catch(error, host);
    }
}
@Controller('api/v1/booking')
@UseGuards(SessionGuard)
export class BookingController {
    constructor(private readonly repository: BookingRepository) { }
    @Post('read/:kind')
    @HttpCode(200)
    async read(
    @Req()
    req: Request,
    @Param('kind')
    kind: string,
    @Body()
    raw: unknown) {
        if (!['catalog', 'history', 'booking', 'events', 'cancellation-preview'].includes(kind))
            throw new HttpException('Not found', 404);
        if (!raw || typeof raw !== 'object' || Array.isArray(raw) || Object.keys(raw).sort().join(',') !== 'entityId,pageOffset')
            throw new HttpException('Invalid read', 422);
        const d = raw as {
            entityId: unknown;
            pageOffset: unknown;
        };
        if (typeof d.pageOffset !== 'number' || !Number.isInteger(d.pageOffset) || d.pageOffset < 0 || d.pageOffset > 10000)
            throw new HttpException('Invalid pagination', 422);
        const id = d.entityId === null ? null : uuid(d.entityId);
        if (['booking', 'events', 'cancellation-preview'].includes(kind) && id === null || ['catalog', 'history'].includes(kind) && id !== null)
            throw new HttpException('Invalid target', 422);
        const e = evidence(req);
        return this.repository.read(e.hash, e.csrf, kind, id, d.pageOffset);
    }
    @Post('commands/:operation')
    @HttpCode(200)
    async command(
    @Req()
    req: Request,
    @Param('operation')
    op: string,
    @Body()
    data: unknown) {
        const key = req.headers['idempotency-key'];
        if (!operations.has(op) || typeof key !== 'string' || !/^[A-Za-z0-9_-]{16,128}$/.test(key))
            throw new HttpException('Invalid command', 422);
        const e = evidence(req);
        return this.repository.command(e.hash, e.csrf, op, key, e.requestId, validateCommand(op,data));
    }
}
export async function createBookingApp(options: BookingOptions) {
    @Global()
    @Module({ controllers: [BookingController], providers: [{ provide: ADMIN_OPTIONS, useValue: options }, { provide: BookingRepository, useFactory: () => new BookingRepository(options) },
            { provide: AdminRepository, useFactory: (r: BookingRepository) => ({ session: r.session.bind(r) }), inject: [BookingRepository] }, SessionGuard] })
    class LocalBookingModule {
    }
    const app = await NestFactory.create<NestExpressApplication>(LocalBookingModule, { logger: false, abortOnError: false, bodyParser: false });
    app.use(requestDiagnostics);
    app.useBodyParser('json', { limit: '32kb', strict: true, verify: (_req: unknown, _res: unknown, b: Buffer) => { try {
            uniqueJson(b.toString('utf8'));
        }
        catch {
            throw new HttpException('Invalid JSON', 422);
        } } });
    app.useGlobalFilters(new BookingFilter());
    app.enableShutdownHooks();
    return app;
}
