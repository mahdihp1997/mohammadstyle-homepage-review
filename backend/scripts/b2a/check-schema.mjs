import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
import {root,client,identify,save} from './local.mjs';import {catalog,assertCatalog} from './catalog.mjs';import {loadMigrations} from './migrate.mjs';
const db=client('ms_b2a_dev');await db.connect();try{
 await identify(db,'ms_b2a_dev');const summary=await assertCatalog(db),c=await catalog(db),inventory=JSON.parse(fs.readFileSync(path.join(root,'migrations/b2a-inventory.json'),'utf8'));
 assert.equal(c.tables.length,27);assert.equal(inventory.tables.length,11);assert.ok(inventory.tables.every(t=>c.tables.some(x=>x.name===t)));
 assert.equal(c.generatedExpressions.length,2);assert.equal(c.constraints.filter(x=>x.type==='x').length,2);assert.equal(c.triggers.length,12);
 assert.ok(c.indexes.every(x=>x.indisvalid&&x.indisready));assert.equal(c.functionSecurity.filter(g=>g.grantee==='ms_b1b_api').length,3);
 assert.equal(c.functionSecurity.filter(g=>g.grantee==='PUBLIC').length,0);assert.equal(c.tableGrants.filter(g=>g.grantee==='ms_b1b_api').length,0);
 assert.ok(!c.tables.some(t=>['booking_revision','booking_hold','resource_allocation'].includes(t.name)));
 const result={status:'PASS',kind:'ACTUAL_POSTGRESQL_CATALOG_VERIFICATION',summary,newTables:inventory.tables,migrations:loadMigrations().map(m=>({id:m.id,sha256:m.sha256})),generated:c.generatedExpressions,exclusions:c.constraints.filter(x=>x.type==='x'),extensions:c.extensions,apiGrantsUnchanged:true};
 save('schema.json',result);console.log(JSON.stringify(result));
}finally{await db.end();}
