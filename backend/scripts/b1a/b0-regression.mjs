import fs from'node:fs';import path from'node:path';import{randomBytes}from'node:crypto';import{spawnSync}from'node:child_process';import pg from'pg';import{root,docker,save}from'./local.mjs';
const dir=path.join(root,'.local/b1a'),file=path.join(dir,'b0-regression.env');fs.mkdirSync(dir,{recursive:true});
const admin=randomBytes(32).toString('hex'),probe=randomBytes(32).toString('hex');
fs.writeFileSync(file,`B0_ADMIN_PASSWORD=${admin}\nB0_PROBE_PASSWORD=${probe}\nPGHOST=127.0.0.1\nPGPORT=55435\nPGDATABASE=ms_b0_control\nPGUSER=ms_b0_probe\nPGPASSWORD=${probe}\nAPI_HOST=127.0.0.1\nAPI_PORT=3100\nAPP_ENV=b0-local\n`,{mode:0o600});
const args=['compose','--project-name','mohammadstyle-b1a-regression','--file',path.join(root,'compose.b0-regression.yaml'),'--env-file',file];
function compose(extra){const r=spawnSync(docker,[...args,...extra],{stdio:'inherit'});if(r.status!==0)throw Error('B0 clone Compose failed');}
const results=[];
try{
 compose(['up','-d','--wait']);const db=new pg.Client({host:'127.0.0.1',port:55435,database:'ms_b0_control',user:'ms_b0_admin',password:admin});await db.connect();
 try{const identity=(await db.query('SELECT current_database() AS database,current_user AS role')).rows[0];if(identity.database!=='ms_b0_control'||identity.role!=='ms_b0_admin')throw Error('Regression cluster mismatch');await db.query("COMMENT ON DATABASE ms_b0_control IS 'mohammadstyle-b0-disposable-control'");await db.query('REVOKE CREATE ON SCHEMA public FROM PUBLIC');await db.query(`CREATE ROLE ms_b0_probe LOGIN PASSWORD '${probe}' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION`);await db.query('REVOKE ALL ON DATABASE ms_b0_control FROM PUBLIC');await db.query('GRANT CONNECT ON DATABASE ms_b0_control TO ms_b0_probe');}finally{await db.end();}
 for(const[command,nodeArgs]of[['existing backend tests',['--test','--test-concurrency=1','test/config.test.mjs','test/http.test.mjs']],['existing B0 SQL35',['scripts/validate-db.mjs']],['existing Prisma compatibility',['scripts/prisma-probe.mjs']]]){
  const run=spawnSync(process.execPath,nodeArgs,{cwd:root,env:{...process.env,MS_B0_REGRESSION:'b1a'},encoding:'utf8',maxBuffer:5*1024*1024,timeout:180000});const log=(run.stdout??'')+(run.stderr??'');if(log.includes(admin)||log.includes(probe))throw Error('Secret in regression log');fs.writeFileSync(path.join(dir,'b0-clone-'+results.length+'.log'),log);process.stdout.write(log);results.push({command,status:run.status});if(run.status!==0)throw Error('Existing B0 regression failed');
 }
 save('b0-regression.json',{status:'PASS',project:'mohammadstyle-b1a-regression',storage:'tmpfs; removed after checks',originalB0DatabasesTouched:false,results});
}finally{compose(['down','--volumes']);}
