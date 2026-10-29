import fs from 'node:fs';import path from 'node:path';import{spawnSync}from'node:child_process';import{createHash}from'node:crypto';import{root,docker,save}from'./local.mjs';
const dest=path.join(root,'.local/b2b/b2a-regression-source');fs.mkdirSync(dest,{recursive:true});
for(const name of ['scripts','migrations','dist','test','prisma'])fs.cpSync(path.join(root,name),path.join(dest,name),{recursive:true});
for(const name of ['package.json','compose.b1a.yaml','compose.b1b.yaml','compose.b0-regression.yaml','prisma.config.ts','.env.example'])fs.copyFileSync(path.join(root,name),path.join(dest,name));
const schema=path.join(dest,'../docs/architecture/schema');fs.mkdirSync(schema,{recursive:true});for(const n of ['draft-postgresql.sql','b1-draft-postgresql.sql'])fs.copyFileSync(path.join(root,'../docs/architecture/schema',n),path.join(schema,n));
if(!fs.existsSync(path.join(dest,'node_modules')))fs.symlinkSync(path.join(root,'node_modules'),path.join(dest,'node_modules'),process.platform==='win32'?'junction':'dir');
if(fs.realpathSync(path.join(dest,'node_modules'))!==fs.realpathSync(path.join(root,'node_modules')))throw Error('Unexpected ignored modules target');
const hash=b=>createHash('sha256').update(b).digest('hex'),original=hash(fs.readFileSync(path.join(root,'scripts/b2a/test.mjs')));
for(const n of ['local','infra','backup']){const f=path.join(dest,'scripts/b2a',n+'.mjs');fs.writeFileSync(f,fs.readFileSync(f,'utf8').replaceAll('55438','55441').replaceAll('mohammadstyle-b2a','mohammadstyle-b2b-b2a-baseline'));}
let yaml=fs.readFileSync(path.join(root,'compose.b2a.yaml'),'utf8').replaceAll('55438','55441').replaceAll('mohammadstyle-b2a','mohammadstyle-b2b-b2a-baseline').replace('    volumes: ["b2a_pgdata:/var/lib/postgresql"]','    tmpfs: ["/var/lib/postgresql"]');yaml=yaml.slice(0,yaml.indexOf('\nvolumes:'))+'\n';fs.writeFileSync(path.join(dest,'compose.b2a.yaml'),yaml);
try{
 for(const args of [['scripts/b2a/infra.mjs','env'],['scripts/b2a/infra.mjs','up'],['scripts/b2a/test.mjs'],['scripts/b2a/b1b-regression.mjs']]){
 const r=spawnSync(process.execPath,args,{cwd:dest,encoding:'utf8',timeout:600000,maxBuffer:10*1024*1024});process.stdout.write((r.stdout??'')+(r.stderr??''));if(r.status!==0)throw Error('Baseline regression command failed: '+args[0]);}
 const value=JSON.parse(fs.readFileSync(path.join(dest,'.local/b2a/results/integration.json')));if(value.summary.passed!==69||value.summary.failed!==0||hash(fs.readFileSync(path.join(dest,'scripts/b2a/test.mjs')))!==original)throw Error('Original69 test body/result mismatch');
 save('b2a-regression.json',{...value,originalTestBodySha256:original,harness:'Unchanged B2A69 in isolated tmpfs55441; original databases/evidence untouched'});
 for(const n of ['b1b','b1a','b0'])save(n+'-regression.json',JSON.parse(fs.readFileSync(path.join(dest,'.local/b2a/results',n+'-regression.json'))));
}finally{const r=spawnSync(docker,['compose','--project-name','mohammadstyle-b2b-b2a-baseline','--file',path.join(dest,'compose.b2a.yaml'),'--env-file',path.join(dest,'.env.b2a.local'),'down','--volumes'],{stdio:'inherit'});if(r.status!==0)throw Error('B2A clone cleanup failed');}
