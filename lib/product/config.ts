import 'server-only';
import fs from 'node:fs';
export function productEnabled(){return process.env.MS_PRODUCT_ENABLED==='1';}
export function productBridge(){
 if(!productEnabled())return null;
 const environment=process.env.PRODUCT_ENV,origin=process.env.PUBLIC_ORIGIN??'',api=process.env.PRODUCT_API_ORIGIN??'';
 const site=new URL(origin),upstream=new URL(api);
 if(!['test','staging','production'].includes(environment??'')||site.origin!==origin||site.username||site.password||upstream.origin!==api||upstream.username||upstream.password)throw Error('Invalid product bridge origin');
 if(environment==='test'){
  if(process.env.NODE_ENV==='production'||!((origin==='http://127.0.0.1:3006'&&api==='http://127.0.0.1:3116')||(origin==='http://127.0.0.1:3007'&&api==='http://127.0.0.1:3119')))throw Error('Isolated product frontend required');
 }else if(site.protocol!=='https:'||api!=='http://api:3116')throw Error('HTTPS public origin and private API service required');
 if(process.env.PRODUCT_BRIDGE_KEY&&process.env.PRODUCT_BRIDGE_KEY_FILE)throw Error('Duplicate bridge secret source');
 const key=process.env.PRODUCT_BRIDGE_KEY_FILE?fs.readFileSync(process.env.PRODUCT_BRIDGE_KEY_FILE,'utf8').trim():process.env.PRODUCT_BRIDGE_KEY;
 if(!/^[A-Za-z0-9_-]{43}$/.test(key??''))throw Error('Private bridge secret required');
 return{environment,origin,host:site.host,api,key:key!,secure:site.protocol==='https:'};
}
