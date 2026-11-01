// The persistent owner clone is deliberately outside every disposable test tool.
import assert from 'node:assert/strict';import {applyEnvironment,databases,connection,save} from './local.mjs';import {freshScratch} from './scratch.mjs';import {loadProductConfig} from '../../dist/product/config.js';
applyEnvironment();const env={...process.env,NODE_ENV:'development',PGPORT:'55461',PGDATABASE:'ms_product_owner_review',PUBLIC_ORIGIN:'http://127.0.0.1:3006',MOCK_GATEWAY_ORIGIN:'http://127.0.0.1:3117',PRODUCT_REVIEW_OTP_AUTOFILL:'1'};
assert.equal(loadProductConfig(env).database.database,'ms_product_owner_review');
for(const extra of [{PGPORT:'55460'},{PUBLIC_ORIGIN:'http://127.0.0.1:3007'},{MOCK_GATEWAY_ORIGIN:'http://127.0.0.1:3120'},{NODE_ENV:'production'}])assert.throws(()=>loadProductConfig({...env,...extra}));
assert.ok(!databases.includes('ms_product_owner_review'));assert.throws(()=>connection('ms_product_owner_review'));await assert.rejects(()=>freshScratch('ms_product_owner_review'),/ISOLATED_SCRATCH_ONLY/);
save('owner-clone-guard.json',{passed:7,kind:'CONFIGURATION_AND_NO_DATABASE_DELETION_BOUNDARY'});console.log('PASS Exact persistent owner clone profile; wrong origins/ports/production and all disposable database tools reject it (7 checks)');
