import { Module, type DynamicModule } from '@nestjs/common';
import { TransactionManager, type PersistenceOptions } from './transaction.js';

/** Explicit opt-in. Deliberately not imported by the B0 AppModule. */
@Module({})
export class PersistenceModule {
  static forLocal(options: PersistenceOptions): DynamicModule {
    return { module: PersistenceModule, providers: [{ provide: TransactionManager, useFactory: () => new TransactionManager(options) }], exports: [TransactionManager] };
  }
}
