import fs from'node:fs';import type{ProductConfig}from'./config.js';
export function verifyRuntime(r:Record<string,unknown>,cfg:ProductConfig){
 const registry=JSON.parse(fs.readFileSync(new URL('../../migrations/registry.product.json',import.meta.url),'utf8')) as{migrations:{id:string;sha256:string}[]};const head=registry.migrations.at(-1);
 if(r.marker!==cfg.database.marker||r.environment!==cfg.environment||r.businessId!==cfg.businessId||r.origin!==cfg.origin||r.payment!==cfg.payment||r.sms!==cfg.sms||Number(r.postgres)<180000||Number(r.postgres)>=190000||r.schemaHead!==head?.id||r.schemaChecksum!==head?.sha256||(cfg.environment!=='test'&&Number(r.testData)!==0))throw Error('PRODUCT_SCHEMA_OR_REALM_MISMATCH');
}
