import fs from 'node:fs';
import { createAdminApp } from './app.js';
try {
  if (process.env.APP_ENV !== 'b1b-local' || process.env.NODE_ENV === 'production') throw new Error('Local B1B only');
  const values=Object.fromEntries(fs.readFileSync('.env.b1b.local','utf8').split(/\r?\n/).filter(Boolean).map(line=>{const i=line.indexOf('=');return [line.slice(0,i),line.slice(i+1)];}));
  const app=await createAdminApp({host:'127.0.0.1',port:55436,database:'ms_b1b_dev',user:'ms_b1b_api',password:values.B1B_API_PASSWORD ?? '',origin:'http://127.0.0.1:3102'});
  await app.listen(3102,'127.0.0.1');console.log('B1B isolated admin API listening on127.0.0.1:3102; no login/provisioning route');
} catch {console.error('B1B local startup refused');process.exitCode=1;}
