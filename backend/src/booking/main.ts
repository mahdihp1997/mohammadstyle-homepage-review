import fs from 'node:fs';
import { createBookingApp } from './app.js';
if (process.env.APP_ENV !== 'b4-local' || process.env.NODE_ENV === 'production')
    throw Error('Explicit isolated B4 environment required');
const values = Object.fromEntries(fs.readFileSync(new URL('../../.env.b4.local', import.meta.url), 'utf8').split(/\r?\n/).filter(Boolean).map(l => l.split('=')));
const app = await createBookingApp({ host: '127.0.0.1', port: 55446, database: 'ms_b4_dev', user: 'ms_b1b_api', password: values.B4_API_PASSWORD!, origin: 'http://127.0.0.1:3110' });
await app.listen(3110, '127.0.0.1');
