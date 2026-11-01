// Explicit privileged operator command; never loaded by an HTTP application.
import pg from 'pg';
import {loadProductConfig,secret} from '../../dist/product/config.js';
if(!['staging','production'].includes(process.env.APP_ENV??''))throw Error('DEPLOYMENT_REALM_REQUIRED');
const cfg=loadProductConfig(process.env,'migrate'),adminPassword=secret(process.env,'PRODUCT_ADMIN_PASSWORD');
if(!/^[a-f0-9]{64}$/.test(adminPassword??''))throw Error('ADMIN_SECRET_REQUIRED');
const db=new pg.Client({host:cfg.database.host,port:cfg.database.port,database:'postgres',user:'ms_b1a_admin',password:adminPassword,ssl:cfg.database.ssl});
const roles={ms_b1a_migrator:'MIGRATOR',ms_b1a_runtime:'RUNTIME',ms_b1b_api:'API',ms_product_auth:'AUTH',ms_product_worker:'WORKER'};
try{await db.connect();await db.query('SELECT pg_advisory_lock(603031,0)');
 for(const[role,name]of Object.entries(roles)){const password=secret(process.env,'PRODUCT_'+name+'_PASSWORD');if(!/^[a-f0-9]{64}$/.test(password??''))throw Error('STRONG_ROLE_SECRET_REQUIRED');
  if(!(await db.query('SELECT 1 FROM pg_roles WHERE rolname=$1',[role])).rowCount)await db.query(`CREATE ROLE ${role} NOLOGIN`);
  // Identifiers are a fixed allowlist; password is restricted to 64 hexadecimal digits.
  await db.query(`ALTER ROLE ${role} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD '${password}'`);
 }
 const name=cfg.database.database,marker=cfg.database.marker,prior=(await db.query("SELECT shobj_description(oid,'pg_database') marker,pg_get_userbyid(datdba) owner FROM pg_database WHERE datname=$1",[name])).rows[0];
 if(prior&&(prior.marker!==marker||prior.owner!=='ms_b1a_migrator'))throw Error('REFUSING_UNOWNED_DATABASE');
 if(!prior){await db.query(`CREATE DATABASE "${name}" OWNER ms_b1a_migrator`);await db.query(`COMMENT ON DATABASE "${name}" IS '${marker}'`);}
 await db.query(`REVOKE ALL ON DATABASE "${name}" FROM PUBLIC`);
 await db.query(`GRANT CONNECT ON DATABASE "${name}" TO ms_b1a_migrator,ms_b1b_api,ms_product_auth,ms_product_worker`);
 console.log('Deployment roles/database prepared; existing data preserved; credentials withheld.');
}finally{await db.end();}
