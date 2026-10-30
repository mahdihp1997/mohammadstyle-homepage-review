import fs from 'node:fs';
import path from 'node:path';
import pg from 'pg';
import { root } from '../local.mjs';
export { root };
export const resultDir = path.join(root,'.local/b4/results');
export const databases = ['ms_b4_dev','ms_b4_restore','ms_b4_failure'];
export const marker = 'mohammadstyle-b4-disposable-v1';
export const docker = process.env.DOCKER_BIN || (process.platform==='win32' ? 'C:\\Program Files\\Docker\\Docker\\resources\\bin\\docker.exe' : 'docker');
export function env() {
  const values=Object.fromEntries(fs.readFileSync(path.join(root,'.env.b4.local'),'utf8').split(/\r?\n/).filter(Boolean).map(l=>{const i=l.indexOf('=');return[l.slice(0,i),l.slice(i+1)];}));
  for(const key of ['B4_ADMIN_PASSWORD','B4_MIGRATOR_PASSWORD','B4_RUNTIME_PASSWORD','B4_API_PASSWORD']) if(!/^[0-9a-f]{64}$/.test(values[key]??''))throw Error('Missing/invalid B4 secret configuration');
  return values;
}
export function connection(database, role='migrator') {
  if(!databases.includes(database)&&!(database==='ms_b4_control'&&role==='admin'))throw Error('Database outside B4 allowlist');
  if(!['admin','migrator','runtime','api'].includes(role))throw Error('Role outside B4 allowlist');
  return {host:'127.0.0.1',port:55446,database,user:role==='api'?'ms_b1b_api':'ms_b1a_'+role,password:env()['B4_'+role.toUpperCase()+'_PASSWORD'],application_name:'mohammadstyle-b4-validation',connectionTimeoutMillis:3000,statement_timeout:15000};
}
export function client(database,role='migrator') {return new pg.Client(connection(database,role));}
export async function identify(db, database, role='migrator') {
  const row=(await db.query("SELECT current_database() AS database,current_user AS role,current_setting('server_version_num')::int AS version,shobj_description((SELECT oid FROM pg_database WHERE datname=current_database()),'pg_database') AS marker")).rows[0];
  const expectedRole=role==='api'?'ms_b1b_api':'ms_b1a_'+role;
  if(row.database!==database||row.role!==expectedRole||row.version<180000||row.version>=190000||row.marker!==marker)throw Error('B4 database identity mismatch');
  return row;
}
export function save(name,data){fs.mkdirSync(resultDir,{recursive:true});fs.writeFileSync(path.join(resultDir,name),JSON.stringify(data,null,2)+'\n');}
