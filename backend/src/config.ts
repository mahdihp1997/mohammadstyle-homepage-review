import { Global, Module } from '@nestjs/common';

export interface B0Config {
  host: '127.0.0.1' | '0.0.0.0'; port: number;
  database: { host: string; port: number; database: 'ms_b0_control'; user: 'ms_b0_probe'; password: string };
}
export const CONFIG = Symbol('B0_CONFIG');

/** Deliberately rejects production targets; B0 is not a production bootstrap. */
export function loadConfig(env: NodeJS.ProcessEnv): B0Config {
  const errors: string[] = [];
  const required = (key: string): string => {
    const value = env[key] ?? '';
    if (!value || /REPLACE|example|changeme/i.test(value)) errors.push(key);
    return value;
  };
  const port = (key: string): number => {
    const value = required(key);
    if (!/^\d+$/.test(value) || +value < 1024 || +value > 65535) errors.push(key);
    return +value;
  };
  if (required('APP_ENV') !== 'b0-local') errors.push('APP_ENV');
  const host = required('API_HOST');
  if (!['127.0.0.1', '0.0.0.0'].includes(host)) errors.push('API_HOST');
  const dbHost = required('PGHOST');
  if (!['127.0.0.1', 'postgres'].includes(dbHost)) errors.push('PGHOST');
  if (required('PGDATABASE') !== 'ms_b0_control') errors.push('PGDATABASE');
  if (required('PGUSER') !== 'ms_b0_probe') errors.push('PGUSER');
  const password = required('PGPASSWORD');
  if (password.length < 32) errors.push('PGPASSWORD');
  const apiPort = port('API_PORT'); const dbPort = port('PGPORT');
  if (errors.length) throw new Error(`Invalid B0 configuration keys: ${[...new Set(errors)].sort().join(', ')}`);
  return { host: host as B0Config['host'], port: apiPort,
    database: { host: dbHost, port: dbPort, database: 'ms_b0_control', user: 'ms_b0_probe', password } };
}

@Global()
@Module({ providers: [{ provide: CONFIG, useFactory: () => loadConfig(process.env) }], exports: [CONFIG] })
export class ConfigModule {}
