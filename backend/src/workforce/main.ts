import fs from 'node:fs';import {createWorkforceApp} from './app.js';
if(process.env.APP_ENV!=='b2b-local'||process.env.NODE_ENV==='production')throw Error('Explicit local B2B environment required');
const raw=fs.readFileSync(new URL('../../.env.b2b.local',import.meta.url),'utf8');const values=Object.fromEntries(raw.split(/\r?\n/).filter(Boolean).map(l=>l.split('=')));
const app=await createWorkforceApp({host:'127.0.0.1',port:55440,database:'ms_b2b_dev',user:'ms_b1b_api',password:values.B2B_API_PASSWORD!,origin:'http://127.0.0.1:3104'});await app.listen(3104,'127.0.0.1');
