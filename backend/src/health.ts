import { Controller, Get, Inject, Module, ServiceUnavailableException } from '@nestjs/common';
import { DatabaseModule, DatabaseProbe } from './database.js';

@Controller('health')
export class HealthController {
  constructor(@Inject(DatabaseProbe) private readonly database: DatabaseProbe) {}
  @Get('live') live(): { status: string } { return { status: 'alive' }; }
  @Get('ready') async ready(): Promise<{ status: string }> {
    if (!await this.database.ready()) throw new ServiceUnavailableException();
    return { status: 'ready' };
  }
}
@Module({ imports: [DatabaseModule], controllers: [HealthController] })
export class HealthModule {}
