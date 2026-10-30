import "reflect-metadata";
import {
  Body,
  Controller,
  Get,
  Post,
  Param,
  Query,
  Req,
  Res,
  UseGuards,
  Global,
  Module,
  Catch,
  HttpException,
  StreamableFile,
  Inject,
  type ArgumentsHost,
} from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import type { NestExpressApplication } from "@nestjs/platform-express";
import {
  ADMIN_OPTIONS,
  SessionGuard,
  evidence,
  type Request,
  type Response,
} from "../admin/security.js";
import { AdminRepository } from "../admin/repository.js";
import {
  AdminCommands,
  IamModule,
  BusinessModule,
  BranchModule,
  CatalogModule,
  OfferingModule,
} from "../admin/modules.js";
import { uuid, invalid } from "../admin/contracts.js";
import {
  WorkforceCommands,
  WorkforceController,
} from "../workforce/modules.js";
import { WorkforceRepository } from "../workforce/repository.js";
import { PricingController } from "../pricing/app.js";
import { PricingRepository } from "../pricing/repository.js";
import { BookingController, BookingFilter } from "../booking/app.js";
import {
  BookingRepository,
  type BookingOptions,
} from "../booking/repository.js";
import { uniqueJson } from "../pricing/canonical.js";
import { requestDiagnostics } from "../observability.js";
import { MvpRepository } from "./repository.js";
import { MediaService } from "./media.js";
import { byteRange, type MediaStorage } from "./storage.js";
const publicBusiness = Symbol("public business");
function object(v: unknown, keys: string[]): Record<string, unknown> {
  if (
    !v ||
    typeof v !== "object" ||
    Array.isArray(v) ||
    Object.keys(v).sort().join(",") !== keys.sort().join(",")
  )
    return invalid();
  return v as Record<string, unknown>;
}
const nullableId = (v: unknown) => (v === null ? null : uuid(v));
function idem(req: Request) {
  const key = req.headers["idempotency-key"];
  if (typeof key !== "string" || !/^[A-Za-z0-9_-]{16,128}$/.test(key))
    return invalid();
  return key;
}
@Catch()
class MvpFilter extends BookingFilter {
  override catch(error: unknown, host: ArgumentsHost) {
    if (error instanceof HttpException) {
      const body = error.getResponse();
      if (
        body &&
        typeof body === "object" &&
        "code" in body &&
        typeof body.code === "string" &&
        /^[A-Z][A-Z0-9_]{2,63}$/.test(body.code)
      ) {
        const res = host.switchToHttp().getResponse<Response>();
        res.setHeader("Cache-Control", "no-store");
        res.status(error.getStatus()).json({
          code: body.code,
          requestId: host.switchToHttp().getRequest<Request>().requestId,
          retryable: [429, 503].includes(error.getStatus()),
        });
        return;
      }
    }
    super.catch(error, host);
  }
}
async function deliver(
  repo: MvpRepository,
  storage: MediaStorage,
  req: Request,
  res: Response,
  id: string,
  variant: string,
  pub: boolean,
  business: string | null,
) {
  const descriptor = await repo.delivery(
      pub ? null : evidence(req).hash,
      business,
      uuid(id),
      variant,
      pub,
    ),
    size = Number(descriptor.bytes);
  let range;
  try {
    const header = req.headers.range;
    if (Array.isArray(header)) throw Error("RANGE");
    range = byteRange(header, size);
  } catch {
    res.setHeader("Content-Range", "bytes */" + size);
    throw new HttpException({ code: "RANGE_NOT_SATISFIABLE" }, 416);
  }
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Cross-Origin-Resource-Policy", "same-origin");
  res.setHeader("Accept-Ranges", "bytes");
  res.setHeader("Content-Type", descriptor.mime);
  res.setHeader(
    "Content-Length",
    String(range ? range.end - range.start + 1 : size),
  );
  if (range) {
    res.status(206);
    res.setHeader("Content-Range", `bytes ${range.start}-${range.end}/${size}`);
  }
  if (req.method === "HEAD") return;
  return new StreamableFile(await storage.read(descriptor.key, range));
}
class StorageProvider {
  constructor(readonly value: MediaStorage) {}
  onModuleDestroy() {
    this.value.close?.();
  }
}
@Controller("api/v1/admin")
@UseGuards(SessionGuard)
class PortalController {
  constructor(
    private readonly repo: MvpRepository,
    private readonly media: MediaService,
    private readonly storage: StorageProvider,
  ) {}
  @Get("portal/workspace") workspace(
    @Req() req: Request,
    @Query() q: Record<string, unknown>,
  ) {
    if (
      Object.keys(q).some(
        (k) =>
          !["view", "branchId", "from", "to", "history", "offset"].includes(k),
      ) ||
      ![
        "overview",
        "branches",
        "services",
        "prices",
        "policies",
        "staff",
        "schedule",
        "reservations",
        "media",
      ].includes(String(q.view)) ||
      typeof q.from !== "string" ||
      typeof q.to !== "string" ||
      !/^20\d\d-\d\d-\d\d$/.test(q.from) ||
      !/^20\d\d-\d\d-\d\d$/.test(q.to) ||
      (q.history !== undefined &&
        !["true", "false"].includes(String(q.history)))
    )
      invalid();
    const offset = Number(q.offset ?? 0);
    if (!Number.isInteger(offset) || offset < 0 || offset > 10000) invalid();
    return this.repo.workspace(
      evidence(req).hash,
      String(q.view),
      q.branchId === undefined ? null : uuid(q.branchId),
      q.from as string,
      q.to as string,
      q.history === "true",
      offset,
    );
  }
  @Get("portal/read/:kind") read(
    @Req() req: Request,
    @Param("kind") kind: string,
    @Query() q: Record<string, unknown>,
  ) {
    if (
      Object.keys(q).some(
        (k) => !["branchId", "entityId", "offset", "local"].includes(k),
      )
    )
      invalid();
    const offset = q.offset === undefined ? 0 : Number(q.offset);
    if (!Number.isInteger(offset) || offset < 0 || offset > 10000) invalid();
    return this.repo.portalRead(
      evidence(req).hash,
      kind,
      q.branchId === undefined ? null : uuid(q.branchId),
      q.entityId === undefined ? null : uuid(q.entityId),
      offset,
      q.local === undefined ? {} : { local: q.local },
    );
  }
  @Post("portal/commands/:op") write(
    @Req() req: Request,
    @Param("op") op: string,
    @Body() raw: unknown,
  ) {
    const d = object(raw, ["branchId", "entityId", "version", "data"]);
    if (
      typeof d.version !== "string" ||
      !/^(0|[1-9][0-9]{0,18})$/.test(d.version) ||
      BigInt(d.version) > 9223372036854775806n ||
      !d.data ||
      typeof d.data !== "object" ||
      Array.isArray(d.data)
    )
      invalid();
    const e = evidence(req);
    return this.repo.portalCommand(
      e.hash,
      e.csrf,
      op,
      nullableId(d.branchId),
      nullableId(d.entityId),
      d.version as string,
      idem(req),
      e.requestId,
      d.data,
    );
  }
  @Post("media/upload") upload(@Req() req: Request, @Body() raw: unknown) {
    return this.media.upload(evidence(req), idem(req), raw);
  }
  @Get("media/view/:id/:variant") view(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
    @Param("id") id: string,
    @Param("variant") variant: string,
  ) {
    return deliver(
      this.repo,
      this.storage.value,
      req,
      res,
      id,
      variant,
      false,
      null,
    );
  }
}
@Controller("api/v1/portfolio")
class PublicGalleryController {
  constructor(
    private readonly repo: MvpRepository,
    private readonly storage: StorageProvider,
    @Inject(publicBusiness) private readonly business: string | null,
  ) {}
  @Get() gallery(@Query() q: Record<string, unknown>) {
    if (
      Object.keys(q).some((k) => !["category", "offset"].includes(k)) ||
      (q.category !== undefined && typeof q.category !== "string")
    )
      invalid();
    const offset = q.offset === undefined ? 0 : Number(q.offset);
    if (!Number.isInteger(offset) || offset < 0 || offset > 10000) invalid();
    return this.repo.gallery(
      this.business,
      (q.category as string | undefined) ?? null,
      offset,
    );
  }
  @Get(":id/:variant") view(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
    @Param("id") id: string,
    @Param("variant") variant: string,
  ) {
    return deliver(
      this.repo,
      this.storage.value,
      req,
      res,
      id,
      variant,
      true,
      this.business,
    );
  }
}
export async function createMvpApp(
  options: BookingOptions,
  storage: MediaStorage,
  businessId: string | null = null,
) {
  if (
    process.env.APP_ENV !== "mvp-local" ||
    process.env.NODE_ENV === "production"
  )
    throw Error("MVP isolated startup only");
  if (businessId !== null) uuid(businessId);
  await storage.prepare?.();
  @Global()
  @Module({
    controllers: [
      BookingController,
      WorkforceController,
      PricingController,
      PortalController,
      PublicGalleryController,
    ],
    providers: [
      { provide: ADMIN_OPTIONS, useValue: options },
      { provide: MvpRepository, useFactory: () => new MvpRepository(options) },
      { provide: BookingRepository, useExisting: MvpRepository },
      {
        provide: AdminRepository,
        useFactory: (r: MvpRepository) => ({
          session: r.session.bind(r),
          read: r.legacyRead.bind(r),
          command: r.legacyCommand.bind(r),
        }),
        inject: [MvpRepository],
      },
      {
        provide: WorkforceRepository,
        useFactory: (r: MvpRepository) => ({
          read: r.workforceRead.bind(r),
          command: r.workforceCommand.bind(r),
        }),
        inject: [MvpRepository],
      },
      {
        provide: PricingRepository,
        useFactory: (r: MvpRepository) => ({
          read: r.pricingRead.bind(r),
          command: r.pricingCommand.bind(r),
        }),
        inject: [MvpRepository],
      },
      {
        provide: AdminCommands,
        useFactory: (r: AdminRepository) => new AdminCommands(r),
        inject: [AdminRepository],
      },
      {
        provide: WorkforceCommands,
        useFactory: (r: WorkforceRepository) => new WorkforceCommands(r),
        inject: [WorkforceRepository],
      },
      SessionGuard,
      { provide: StorageProvider, useValue: new StorageProvider(storage) },
      {
        provide: MediaService,
        useFactory: (r: MvpRepository) => new MediaService(r, storage),
        inject: [MvpRepository],
      },
      { provide: publicBusiness, useValue: businessId },
    ],
    exports: [ADMIN_OPTIONS, AdminRepository, AdminCommands, SessionGuard],
  })
  class IntegrationModule {}
  @Module({
    imports: [
      IntegrationModule,
      IamModule,
      BusinessModule,
      BranchModule,
      CatalogModule,
      OfferingModule,
    ],
  })
  class App {}
  const app = await NestFactory.create<NestExpressApplication>(App, {
    logger: false,
    abortOnError: false,
    bodyParser: false,
  });
  app.use(requestDiagnostics);
  const verify = (_req: unknown, _res: unknown, b: Buffer) => {
    try {
      uniqueJson(b.toString("utf8"));
    } catch {
      throw new HttpException({ code: "INVALID_JSON" }, 422);
    }
  };
  app.useBodyParser("json", {
    type: (req: { url?: string }) => req.url === "/api/v1/admin/media/upload",
    limit: "44mb",
    strict: true,
    verify,
  });
  app.useBodyParser("json", {
    type: (req: { url?: string }) => req.url !== "/api/v1/admin/media/upload",
    limit: "32kb",
    strict: true,
    verify,
  });
  app.useGlobalFilters(new MvpFilter());
  app.enableShutdownHooks();
  return app;
}
