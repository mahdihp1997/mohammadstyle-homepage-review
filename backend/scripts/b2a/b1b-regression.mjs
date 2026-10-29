import fs from 'node:fs';import path from 'node:path';import {spawnSync} from 'node:child_process';import {createHash} from 'node:crypto';
import {root,docker,save} from './local.mjs';
const dest=path.join(root,'.local/b2a/b1b-regression-source');
if(!dest.startsWith(path.join(root,'.local/b2a')+path.sep))throw Error('Unexpected regression workspace');
fs.mkdirSync(dest,{recursive:true});for(const name of ['scripts','migrations','dist','test'])fs.cpSync(path.join(root,name),path.join(dest,name),{recursive:true});
fs.copyFileSync(path.join(root,'package.json'),path.join(dest,'package.json'));
for(const name of ['compose.b1a.yaml','compose.b0-regression.yaml','prisma.config.ts','.env.example'])fs.copyFileSync(path.join(root,name),path.join(dest,name));
fs.mkdirSync(path.join(dest,'prisma'),{recursive:true});fs.copyFileSync(path.join(root,'prisma/schema.prisma'),path.join(dest,'prisma/schema.prisma'));
const schemaDir=path.join(dest,'../docs/architecture/schema');fs.mkdirSync(schemaDir,{recursive:true});
for(const name of ['draft-postgresql.sql','b1-draft-postgresql.sql'])fs.copyFileSync(path.join(root,'../docs/architecture/schema',name),path.join(schemaDir,name));
const modules=path.join(dest,'node_modules');if(!fs.existsSync(modules))fs.symlinkSync(path.join(root,'node_modules'),modules,process.platform==='win32'?'junction':'dir');
if(fs.realpathSync(modules)!==fs.realpathSync(path.join(root,'node_modules')))throw Error('Unexpected ignored harness module path');
const body=fs.readFileSync(path.join(root,'scripts/b1b/test.mjs'));const sha=createHash('sha256').update(body).digest('hex');
for(const name of ['scripts/b1b/local.mjs','scripts/b1b/infra.mjs','scripts/b1b/backup.mjs','dist/admin/repository.js']){
 const f=path.join(dest,name);fs.writeFileSync(f,fs.readFileSync(f,'utf8').replaceAll('55436','55439').replaceAll('mohammadstyle-b1b','mohammadstyle-b2a-b1b-baseline'));
}
let yaml=fs.readFileSync(path.join(root,'compose.b1b.yaml'),'utf8').replaceAll('mohammadstyle-b1b','mohammadstyle-b2a-b1b-baseline').replaceAll('55436','55439');
yaml=yaml.replace('    volumes: ["b1b_pgdata:/var/lib/postgresql"]','    tmpfs: ["/var/lib/postgresql"]');yaml=yaml.slice(0,yaml.indexOf('\nvolumes:'))+'\n';fs.writeFileSync(path.join(dest,'compose.b1b.yaml'),yaml);
try {
 for(const args of [['scripts/b1b/infra.mjs','env'],['scripts/b1b/infra.mjs','up'],['scripts/b1b/test.mjs']]){
  const run=spawnSync(process.execPath,args,{cwd:dest,encoding:'utf8',timeout:240000,maxBuffer:8*1024*1024});process.stdout.write((run.stdout??'')+(run.stderr??''));if(run.status!==0)throw Error('Original B1B regression failed');
 }
 const result=JSON.parse(fs.readFileSync(path.join(dest,'.local/b1b/results/integration.json'),'utf8'));
 if(result.summary.passed!==83||result.summary.failed!==0)throw Error('Original83 B1B assertions not preserved');
 if(createHash('sha256').update(fs.readFileSync(path.join(dest,'scripts/b1b/test.mjs'))).digest('hex')!==sha)throw Error('Regression test body changed');
 save('b1b-regression.json',{...result,originalB1BDatabasesTouched:false,originalTestBodySha256:sha,harness:'Unchanged83 tests; only routing in ignored copied helpers/compiled options; tmpfs55439'});
 for(const [name,script]of [['b1a','scripts/b1b/b1a-regression.mjs'],['b0','scripts/b1a/b0-regression.mjs']]){
  const run=spawnSync(process.execPath,[script],{cwd:dest,encoding:'utf8',timeout:300000,maxBuffer:8*1024*1024});process.stdout.write((run.stdout??'')+(run.stderr??''));
  fs.writeFileSync(path.join(root,'.local/b2a',name+'-regression.log'),(run.stdout??'')+(run.stderr??''));if(run.status!==0)throw Error('Original '+name+' regression failed');
  const from=path.join(dest,name==='b1a'?'.local/b1b/results/b1a-regression.json':'.local/b1a/results/b0-regression.json');save(name+'-regression.json',JSON.parse(fs.readFileSync(from,'utf8')));
 }
}finally{
 const r=spawnSync(docker,['compose','--project-name','mohammadstyle-b2a-b1b-baseline','--file',path.join(dest,'compose.b1b.yaml'),'--env-file',path.join(dest,'.env.b1b.local'),'down','--volumes'],{stdio:'inherit'});if(r.status!==0)throw Error('B1B clone cleanup failed');
}
