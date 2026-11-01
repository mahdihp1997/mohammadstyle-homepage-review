import 'server-only';
import {productBridge} from './config';
/** Fixed read-only endpoints; no visitor-provided URL or private session forwarding. */
export async function publicProductRead<T>(kind:'articles'|'catalog'|'shop',query:Record<string,string>={}):Promise<T|null>{
 const cfg=productBridge();if(!cfg)return null;
 const qs=new URLSearchParams(query);if(qs.toString().length>1024)throw Error('PUBLIC_QUERY_LIMIT');
 const response=await fetch(cfg.api+'/api/v1/product/public/'+kind+(qs.size?'?'+qs.toString():''),{headers:{'x-product-bridge':cfg.key},cache:'no-store',redirect:'error',signal:AbortSignal.timeout(10000)});
 if(!response.ok)throw Error('PUBLIC_CONTENT_UNAVAILABLE');return response.json() as Promise<T>;
}
