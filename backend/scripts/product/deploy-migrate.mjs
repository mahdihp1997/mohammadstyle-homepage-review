import pg from 'pg';import {loadProductConfig,secret}from'../../dist/product/config.js';import{migrate}from'./migrate.mjs';import{bootstrap}from'./bootstrap.mjs';
const cfg=loadProductConfig(process.env,'bootstrap');if(!['staging','production'].includes(cfg.environment))throw Error('DEPLOYMENT_REALM_REQUIRED');
const password=secret(process.env,'PRODUCT_MIGRATOR_PASSWORD');if(!/^[a-f0-9]{64}$/.test(password??''))throw Error('MIGRATION_SECRET_REQUIRED');
const db=new pg.Client({host:cfg.database.host,port:cfg.database.port,database:cfg.database.database,user:'ms_b1a_migrator',password,ssl:cfg.database.ssl});
try{await db.connect();const result=await migrate(db,cfg.database.marker);await bootstrap(db,cfg);console.log(JSON.stringify({migrations:result.length,applied:result.filter(x=>x.state==='applied').length,businessFactsOnly:true}));}finally{await db.end();}
