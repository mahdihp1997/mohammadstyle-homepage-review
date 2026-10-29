import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
import {root,save} from './local.mjs';
const spec=JSON.parse(fs.readFileSync(path.join(root,'openapi.b1b.json'),'utf8'));
assert.equal(Object.values(spec.paths).flatMap(Object.values).length,12);
function walk(value){if(!value||typeof value!=='object')return;for(const [k,v]of Object.entries(value)){if(k==='$ref'){assert.ok(v.startsWith('#/'));assert.ok(v.slice(2).split('/').reduce((o,key)=>o?.[key],spec),'Unresolved local contract reference');}else walk(v);}}
walk(spec);assert.equal(spec.components.schemas.BranchWrite.properties.bookable.enum[0],false);assert.equal(spec.components.schemas.OfferingWrite.properties.active.enum[0],false);
for(const [url,pathItem]of Object.entries(spec.paths))for(const [method,operation]of Object.entries(pathItem)){
 assert.ok(url.startsWith('/api/v1/'));assert.ok(operation.security.length);assert.ok(operation.responses['401']);assert.ok(operation.responses['503']);
 if(method!=='get'){assert.ok(operation.security[0].CsrfHeader);assert.ok(operation.parameters.some(p=>p.$ref?.endsWith('/IdempotencyKey')));}
 if(method==='put')assert.ok(operation.parameters.some(p=>p.$ref?.endsWith('/IfMatch')));
}
const result={status:'PASS',operations:12,allReferencesResolved:true,csrfIdempotencyAndVersionContracts:true,note:'Static structural/reference checks, not database execution or independent security certification'};
save('contract.json',result);console.log(JSON.stringify(result));
