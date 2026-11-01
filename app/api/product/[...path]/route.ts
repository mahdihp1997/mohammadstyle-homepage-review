import {NextRequest} from 'next/server';import {productProxy,loginContext,paymentCallback} from '@/lib/product/proxy';
export const runtime='nodejs';export const dynamic='force-dynamic';
async function handler(req:NextRequest,{params}:{params:Promise<{path:string[]}>}){const path=(await params).path;
 if(path.join('/')==='auth/context'&&req.method==='GET')return loginContext(req);
 if(path.length===3&&path[0]==='payment'&&path[1]==='callback'&&req.method==='GET')return paymentCallback(req,path[2]);
 return productProxy(req,'product/'+path.join('/'));}
export{handler as GET,handler as POST,handler as HEAD};
