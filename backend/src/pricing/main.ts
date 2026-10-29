import fs from'node:fs';import{createPricingApp}from'./app.js';
if(process.env.APP_ENV!=='b3-local'||process.env.NODE_ENV==='production')throw Error('Explicit isolated B3 environment required');
const values=Object.fromEntries(fs.readFileSync(new URL('../../.env.b3.local',import.meta.url),'utf8').split(/\r?\n/).filter(Boolean).map(l=>l.split('=')));
const app=await createPricingApp({host:'127.0.0.1',port:55444,database:'ms_b3_dev',user:'ms_b1b_api',password:values.B3_API_PASSWORD!,origin:'http://127.0.0.1:3108'});await app.listen(3108,'127.0.0.1');
