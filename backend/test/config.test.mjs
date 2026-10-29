import test from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../dist/config.js';
const valid = { APP_ENV: 'b0-local', API_HOST: '127.0.0.1', API_PORT: '3100', PGHOST: '127.0.0.1', PGPORT: '55432', PGDATABASE: 'ms_b0_control', PGUSER: 'ms_b0_probe', PGPASSWORD: 'a'.repeat(64) };
test('isolated local configuration accepted', () => assert.equal(loadConfig(valid).port, 3100));
for (const [key, value] of Object.entries({ APP_ENV: 'production', API_HOST: 'public.example', API_PORT: '3100oops', PGHOST: 'production.example', PGDATABASE: 'real_customers', PGUSER: 'postgres', PGPASSWORD: 'REPLACE_ME', PGPORT: '-1' })) {
  test(`invalid ${key} fails without leaking value`, () => {
    assert.throws(() => loadConfig({ ...valid, [key]: value }), error => error.message.includes(key) && !error.message.includes(value));
  });
}
test('missing configuration lists keys without values', () => assert.throws(() => loadConfig({}), /Invalid B0 configuration keys/));
