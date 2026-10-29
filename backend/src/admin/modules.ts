import 'reflect-metadata';
import { Body, Controller, Get, Global, Module, Param, Post, Put, Query, Req, Res, UseGuards, type DynamicModule } from '@nestjs/common';
import { AdminRepository, assertOptions, type AdminOptions } from './repository.js';
import { ADMIN_OPTIONS, SessionGuard, evidence, sessionCookie, type Request, type Response } from './security.js';
import { WritePipe, commandHeaders, pagination, uuid, type ResourceKind, type WriteDto } from './contracts.js';

/** Command service delegates data+audit+outbox+idempotency to one atomic DB entry point.
 * No external effects, generic SQL executor or client-provided actor/tenant context.
 */
export class AdminCommands {
  constructor(private readonly repository: AdminRepository) {}
  read(request: Request, kind: ResourceKind | 'business', branch: string | null, query: Record<string,unknown>): Promise<unknown> {
    return this.repository.read(evidence(request).hash,kind,branch,pagination(query));
  }
  async write(request: Request, response: Response, kind: ResourceKind | 'session', id: string | null, branch: string | null, data: WriteDto | Record<string,never>): Promise<unknown> {
    const e=evidence(request); const {key,version}=commandHeaders(request.headers,id!==null);
    const result=await this.repository.command(e.hash,e.csrf,kind,id,branch,version,key,e.requestId,data);
    response.status(result.status);
    if ('version' in result.body) response.setHeader('ETag',`"${result.body.version}"`);
    return result.body;
  }
}
@Global()
@Module({})
export class AdminCoreModule {
  static forLocal(options: AdminOptions): DynamicModule {
    assertOptions(options);
    return {module:AdminCoreModule,providers:[{provide:ADMIN_OPTIONS,useValue:options},{provide:AdminRepository,useFactory:()=>new AdminRepository(options)},SessionGuard,
      {provide:AdminCommands,useFactory:(r:AdminRepository)=>new AdminCommands(r),inject:[AdminRepository]}],exports:[ADMIN_OPTIONS,AdminRepository,SessionGuard,AdminCommands]};
  }
}
@Controller('api/v1/session')
@UseGuards(SessionGuard)
class SessionController {
  constructor(private readonly commands: AdminCommands) {}
  @Get() get(@Req() req: Request): unknown { return evidence(req).actor; }
  @Post('revoke') async revoke(@Req() req: Request,@Res({passthrough:true}) res: Response,@Body() data: unknown): Promise<unknown> {
    if (!data || typeof data!=='object' || Array.isArray(data) || Object.keys(data).length) { const {invalid}=await import('./contracts.js');invalid(); }
    const result=await this.commands.write(req,res,'session',null,null,{});
    res.setHeader('Set-Cookie',sessionCookie('',0));return result;
  }
}
@Module({controllers:[SessionController]})
export class IamModule {}
@Controller('api/v1/admin/business')
@UseGuards(SessionGuard)
class BusinessController {
  constructor(private readonly commands: AdminCommands) {}
  @Get() get(@Req() req: Request,@Query() q: Record<string,unknown>): Promise<unknown> { return this.commands.read(req,'business',null,q); }
}
@Module({controllers:[BusinessController]})
export class BusinessModule {}
@Controller('api/v1/admin/branches')
@UseGuards(SessionGuard)
class BranchController {
  constructor(private readonly commands: AdminCommands) {}
  @Get() list(@Req() req: Request,@Query() q: Record<string,unknown>): Promise<unknown> { return this.commands.read(req,'branch',null,q); }
  @Post() create(@Req() req: Request,@Res({passthrough:true}) res: Response,@Body(new WritePipe('branch')) d: WriteDto): Promise<unknown> { return this.commands.write(req,res,'branch',null,null,d); }
  @Put(':branchId') update(@Req() req: Request,@Res({passthrough:true}) res: Response,@Param('branchId') id: string,@Body(new WritePipe('branch')) d: WriteDto): Promise<unknown> { return this.commands.write(req,res,'branch',uuid(id),uuid(id),d); }
}
@Module({controllers:[BranchController]})
export class BranchModule {}
@Controller('api/v1/admin/services')
@UseGuards(SessionGuard)
class CatalogController {
  constructor(private readonly commands: AdminCommands) {}
  @Get() list(@Req() req: Request,@Query() q: Record<string,unknown>): Promise<unknown> { return this.commands.read(req,'service',null,q); }
  @Post() create(@Req() req: Request,@Res({passthrough:true}) res: Response,@Body(new WritePipe('service')) d: WriteDto): Promise<unknown> { return this.commands.write(req,res,'service',null,null,d); }
  @Put(':serviceId') update(@Req() req: Request,@Res({passthrough:true}) res: Response,@Param('serviceId') id: string,@Body(new WritePipe('service')) d: WriteDto): Promise<unknown> { return this.commands.write(req,res,'service',uuid(id),null,d); }
}
@Module({controllers:[CatalogController]})
export class CatalogModule {}
@Controller('api/v1/admin/branches/:branchId/offerings')
@UseGuards(SessionGuard)
class OfferingController {
  constructor(private readonly commands: AdminCommands) {}
  @Get() list(@Req() req: Request,@Param('branchId') bid: string,@Query() q: Record<string,unknown>): Promise<unknown> { return this.commands.read(req,'offering',uuid(bid),q); }
  @Post() create(@Req() req: Request,@Res({passthrough:true}) res: Response,@Param('branchId') bid: string,@Body(new WritePipe('offering')) d: WriteDto): Promise<unknown> { return this.commands.write(req,res,'offering',null,uuid(bid),d); }
  @Put(':offeringId') update(@Req() req: Request,@Res({passthrough:true}) res: Response,@Param('branchId') bid: string,@Param('offeringId') id: string,@Body(new WritePipe('offering')) d: WriteDto): Promise<unknown> { return this.commands.write(req,res,'offering',uuid(id),uuid(bid),d); }
}
@Module({controllers:[OfferingController]})
export class OfferingModule {}
