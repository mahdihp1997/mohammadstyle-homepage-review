import { Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { AdminCoreModule, IamModule, BusinessModule, BranchModule, CatalogModule, OfferingModule } from './modules.js';
import { AdminExceptionFilter } from './security.js';
import type { AdminOptions } from './repository.js';
import { requestDiagnostics } from '../observability.js';

export async function createAdminApp(options: AdminOptions) {
  @Module({imports:[AdminCoreModule.forLocal(options),IamModule,BusinessModule,BranchModule,CatalogModule,OfferingModule]})
  class LocalAdminModule {}
  const app=await NestFactory.create<NestExpressApplication>(LocalAdminModule,{logger:false,abortOnError:false,bodyParser:false});
  app.use(requestDiagnostics);
  // The platform's built-in parser is bounded; no cookie parser or auth bypass middleware.
  app.useBodyParser('json',{limit:'16kb',strict:true});
  app.useGlobalFilters(new AdminExceptionFilter());
  app.enableShutdownHooks();
  return app;
}
