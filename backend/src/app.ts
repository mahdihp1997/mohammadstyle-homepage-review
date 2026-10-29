import 'reflect-metadata';
import { Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { CONFIG, ConfigModule, type B0Config } from './config.js';
import { HealthModule } from './health.js';
import { requestDiagnostics, SafeExceptionFilter, StructuredLogger } from './observability.js';

@Module({ imports: [ConfigModule, HealthModule] })
export class AppModule {}
export async function createApp() {
  const app = await NestFactory.create(AppModule, { logger: new StructuredLogger(), abortOnError: false });
  app.use(requestDiagnostics);
  app.useGlobalFilters(new SafeExceptionFilter());
  app.enableShutdownHooks();
  const config = app.get<B0Config>(CONFIG);
  return { app, config };
}
