import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {root,applyEnvironment,client,identify} from './local.mjs';
// Build-time utility: append new product migrations, never rewrite an applied checksum.
const folder=path.join(root,'migrations'),file=path.join(folder,'registry.product.json');
const registry=JSON.parse(fs.readFileSync(file,'utf8'));
let applied=null;
if(process.argv.includes('--refresh-unapplied-test')){applyEnvironment();const db=client();await db.connect();try{await identify(db,'ms_product_test');applied=new Set((await db.query('SELECT id FROM ms_b1_meta.schema_migration')).rows.map(r=>r.id));}finally{await db.end();}}
for(const name of fs.readdirSync(folder).filter(n=>/^00\d\d_product_.*\.sql$/.test(n)).sort()){
 const sql=fs.readFileSync(path.join(folder,name),'utf8').replaceAll('\r\n','\n');
 const sha256=createHash('sha256').update(sql).digest('hex'),id=name.slice(0,-4),prior=registry.migrations.find(m=>m.id===id);
 if(prior&&prior.sha256!==sha256){if(!applied||applied.has(id))throw Error('Immutable migration checksum changed: '+id);prior.sha256=sha256;}
 if(!prior)registry.migrations.push({id,file:name,sha256});
}
fs.writeFileSync(file,JSON.stringify(registry,null,2)+'\n');
console.log('Product migration registry checked: '+registry.migrations.length);
