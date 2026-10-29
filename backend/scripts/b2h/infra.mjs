import fs from 'node:fs';import path from 'node:path';import {randomBytes}from'node:crypto';import{spawnSync}from'node:child_process';
import{root,env,client,identify,databases,marker,docker}from'./local.mjs';
const args=['compose','--project-name','mohammadstyle-b2h','--file',path.join(root,'compose.b2h.yaml'),'--env-file',path.join(root,'.env.b2h.local')];
function compose(extra){const r=spawnSync(docker,[...args,...extra],{cwd:root,stdio:'inherit'});if(r.status!==0)throw Error('B2H Compose command failed');}
export async function provision(database, reset=false){
  if(!databases.includes(database))throw Error('B2H database outside disposable allowlist');
  const admin=client('ms_b2h_control','admin');await admin.connect();
  try{
    await identify(admin,'ms_b2h_control','admin');
    const prior=(await admin.query("SELECT pg_get_userbyid(datdba) AS owner,shobj_description(oid,'pg_database') AS marker FROM pg_database WHERE datname=$1",[database])).rows[0];
    if(prior&&(prior.marker!==marker||prior.owner!=='ms_b1a_migrator'))throw Error('Refusing existing database with unexpected owner/marker');
    if(prior&&reset)await admin.query(`DROP DATABASE "${database}"`); // no FORCE, no killing sessions
    if(!prior||reset){await admin.query(`CREATE DATABASE "${database}" OWNER ms_b1a_migrator`);await admin.query(`COMMENT ON DATABASE "${database}" IS '${marker}'`);}
    await admin.query(`REVOKE ALL ON DATABASE "${database}" FROM PUBLIC`);
    await admin.query(`GRANT CONNECT ON DATABASE "${database}" TO ms_b1a_runtime, ms_b1b_api`);
    const db=client(database);await db.connect();try{await identify(db,database);await db.query('REVOKE ALL ON SCHEMA public FROM PUBLIC');}finally{await db.end();}
  }finally{await admin.end();}
}
if(process.argv[1]&&path.resolve(process.argv[1])===path.join(root,'scripts/b2h/infra.mjs')){
 const command=process.argv[2];
 if(command==='env'){
  const target=path.join(root,'.env.b2h.local');if(fs.existsSync(target)){env();console.log('Existing B2H local credentials preserved');}
  else{fs.writeFileSync(target,['ADMIN','MIGRATOR','RUNTIME','API'].map(role=>`B2H_${role}_PASSWORD=${randomBytes(32).toString('hex')}`).join('\n')+'\n',{mode:0o600,flag:'wx'});console.log('Created ignored random B2H credentials; values withheld');}
 }else if(command==='up'){
  const values=env();compose(['up','-d','--wait']);const admin=client('ms_b2h_control','admin');await admin.connect();
  try{
   await admin.query(`COMMENT ON DATABASE ms_b2h_control IS '${marker}'`);await identify(admin,'ms_b2h_control','admin');
   await admin.query('REVOKE ALL ON SCHEMA public FROM PUBLIC');await admin.query('REVOKE ALL ON DATABASE ms_b2h_control FROM PUBLIC');
   for(const role of['migrator','runtime','api']){
    const name=role==='api'?'ms_b1b_api':'ms_b1a_'+role,exists=(await admin.query('SELECT 1 FROM pg_roles WHERE rolname=$1',[name])).rowCount;
    if(!exists)await admin.query(`CREATE ROLE ${name} LOGIN PASSWORD '${values['B2H_'+role.toUpperCase()+'_PASSWORD']}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS`);
   }
  }finally{await admin.end();}
  await provision('ms_b2h_dev');console.log('B2H isolated cluster/roles/database prepared; no application migration applied');
 }else if(command==='stop'){env();compose(['down']);}
 else throw Error('Use env, up or stop. Test-only database resets verify exact allowlist/owner/marker; no volume reset is provided.');
}
