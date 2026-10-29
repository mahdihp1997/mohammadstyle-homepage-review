import fs from 'node:fs';import path from 'node:path';import{spawnSync}from'node:child_process';import{createHash}from'node:crypto';import{root,docker,save}from'./local.mjs';
const dest=path.join(root,'.local/b2h/b2b-regression-source');fs.mkdirSync(dest,{recursive:true});
for(const name of ['scripts','migrations','dist','test','prisma'])fs.cpSync(path.join(root,name),path.join(dest,name),{recursive:true});
for(const name of ['package.json','compose.b1a.yaml','compose.b1b.yaml','compose.b2a.yaml','compose.b0-regression.yaml','prisma.config.ts','.env.example'])fs.copyFileSync(path.join(root,name),path.join(dest,name));
const schema=path.join(dest,'../docs/architecture/schema');fs.mkdirSync(schema,{recursive:true});for(const n of ['draft-postgresql.sql','b1-draft-postgresql.sql'])fs.copyFileSync(path.join(root,'../docs/architecture/schema',n),path.join(schema,n));
if(!fs.existsSync(path.join(dest,'node_modules')))fs.symlinkSync(path.join(root,'node_modules'),path.join(dest,'node_modules'),process.platform==='win32'?'junction':'dir');
if(fs.realpathSync(path.join(dest,'node_modules'))!==fs.realpathSync(path.join(root,'node_modules')))throw Error('Unexpected ignored modules target');
const hash=b=>createHash('sha256').update(b).digest('hex'),original=hash(fs.readFileSync(path.join(root,'scripts/b2b/test.mjs')));
for(const n of ['local','infra','backup']){const f=path.join(dest,'scripts/b2b',n+'.mjs');fs.writeFileSync(f,fs.readFileSync(f,'utf8').replaceAll('55440','55445').replaceAll('mohammadstyle-b2b','mohammadstyle-b2h-b2b-baseline'));}
for(const n of ['local','infra','backup']){const body=fs.readFileSync(path.join(dest,'scripts/b2b',n+'.mjs'),'utf8');if(body.includes('55440')||!body.includes('mohammadstyle-b2h-b2b-baseline'))throw Error('Clone routing not verified');}
const compiled=path.join(dest,'dist/workforce/repository.js');fs.writeFileSync(compiled,fs.readFileSync(compiled,'utf8').replaceAll('55440','55445'));
let yaml=fs.readFileSync(path.join(root,'compose.b2b.yaml'),'utf8').replaceAll('55440','55445').replaceAll('mohammadstyle-b2b','mohammadstyle-b2h-b2b-baseline').replace('    volumes: ["b2b_pgdata:/var/lib/postgresql"]','    tmpfs: ["/var/lib/postgresql"]');yaml=yaml.slice(0,yaml.indexOf('\nvolumes:'))+'\n';fs.writeFileSync(path.join(dest,'compose.b2b.yaml'),yaml);
try{
 for(const args of [['scripts/b2b/infra.mjs','env'],['scripts/b2b/infra.mjs','up'],['scripts/b2b/test.mjs'],['scripts/b2b/b2a-regression.mjs']]){
 const r=spawnSync(process.execPath,args,{cwd:dest,encoding:'utf8',timeout:600000,maxBuffer:10*1024*1024});process.stdout.write((r.stdout??'')+(r.stderr??''));if(r.status!==0)throw Error('Baseline regression command failed: '+args[0]);}
 const value=JSON.parse(fs.readFileSync(path.join(dest,'.local/b2b/results/integration.json')));if(value.summary.passed!==71||value.summary.failed!==0||hash(fs.readFileSync(path.join(dest,'scripts/b2b/test.mjs')))!==original)throw Error('Original71 test body/result mismatch');
 save('b2b-regression.json',{...value,originalTestBodySha256:original,harness:'Unchanged B2B71 in isolated tmpfs55445; original databases/evidence untouched'});
 for(const n of ['b2a','b1b','b1a','b0'])save(n+'-regression.json',JSON.parse(fs.readFileSync(path.join(dest,'.local/b2b/results',n+'-regression.json'))));
}finally{const r=spawnSync(docker,['compose','--project-name','mohammadstyle-b2h-b2b-baseline','--file',path.join(dest,'compose.b2b.yaml'),'--env-file',path.join(dest,'.env.b2b.local'),'down','--volumes'],{stdio:'inherit'});if(r.status!==0)throw Error('B2A clone cleanup failed');}
