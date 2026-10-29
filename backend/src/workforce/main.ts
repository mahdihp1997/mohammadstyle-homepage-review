import fs from 'node:fs';import {createWorkforceApp} from './app.js';
if(process.env.APP_ENV!=='b2h-local'||process.env.NODE_ENV==='production')throw Error('Explicit local read-scope hardening environment required');
const raw=fs.readFileSync(new URL('../../.env.b2h.local',import.meta.url),'utf8');const values=Object.fromEntries(raw.split(/\r?\n/).filter(Boolean).map(l=>l.split('=')));
const app=await createWorkforceApp({host:'127.0.0.1',port:55442,database:'ms_b2h_dev',user:'ms_b1b_api',password:values.B2H_API_PASSWORD!,origin:'http://127.0.0.1:3106'});await app.listen(3106,'127.0.0.1');
