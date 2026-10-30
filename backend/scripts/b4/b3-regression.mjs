import fs from 'node:fs';import path from 'node:path';import {spawnSync} from 'node:child_process';import {createHash} from 'node:crypto';import {root,docker,save} from './local.mjs';
const flat=path.join(root,'.local/b4/flat'),dest=path.join(flat,'b3'),project='mohammadstyle-b4-b3-baseline';
if(!path.resolve(dest).startsWith(path.resolve(root,'.local/b4')+path.sep))throw Error('Unexpected B4 scratch');fs.mkdirSync(dest,{recursive:true});
for(const name of ['scripts','migrations','dist','test','prisma'])fs.cpSync(path.join(root,name),path.join(dest,name),{recursive:true});
for(const name of fs.readdirSync(root).filter(n=>/^compose\..*\.yaml$/.test(n)||['package.json','prisma.config.ts','.env.example'].includes(n)))fs.copyFileSync(path.join(root,name),path.join(dest,name));
const schema=path.join(dest,'../docs/architecture/schema');fs.mkdirSync(schema,{recursive:true});
for(const name of ['draft-postgresql.sql','b1-draft-postgresql.sql','quote-content.schema.json','quote-hash-vectors.json'])fs.copyFileSync(path.join(root,'../docs/architecture/schema',name),path.join(schema,name));
if(!fs.existsSync(path.join(dest,'node_modules')))fs.symlinkSync(path.join(root,'node_modules'),path.join(dest,'node_modules'),process.platform==='win32'?'junction':'dir');
if(fs.realpathSync(path.join(dest,'node_modules'))!==fs.realpathSync(path.join(root,'node_modules')))throw Error('Unexpected modules target');
const hash=b=>createHash('sha256').update(b).digest('hex'),original=hash(fs.readFileSync(path.join(root,'scripts/b3/test.mjs')));
for(const name of ['local','infra','backup']){const f=path.join(dest,'scripts/b3',name+'.mjs');fs.writeFileSync(f,fs.readFileSync(f,'utf8').replaceAll('55444','55448').replaceAll('mohammadstyle-b3',project));}
for(const name of ['local','infra','backup']){const s=fs.readFileSync(path.join(dest,'scripts/b3',name+'.mjs'),'utf8');if(s.includes('55444')||!s.includes(project))throw Error('B3 clone route guard failed');}
const compiled=path.join(dest,'dist/pricing/repository.js');fs.writeFileSync(compiled,fs.readFileSync(compiled,'utf8').replaceAll('55444','55448'));
const helper=path.join(dest,'scripts/b3/b2h-regression.mjs'),selector="path.join(root,'.local/b3/flat')";let s=fs.readFileSync(helper,'utf8');if(!s.includes(selector))throw Error('Unknown B3 baseline harness');s=s.replace(selector,"path.resolve(process.env.MS_B4_REGRESSION_SCRATCH)").replace("path.resolve(root,'.local/b3')+path.sep","path.resolve(process.env.MS_B4_REGRESSION_SCRATCH)+path.sep");fs.writeFileSync(helper,s);
let yaml=fs.readFileSync(path.join(root,'compose.b3.yaml'),'utf8').replaceAll('55444','55448').replaceAll('mohammadstyle-b3',project).replace('    volumes: ["b3_pgdata:/var/lib/postgresql"]','    tmpfs: ["/var/lib/postgresql"]');yaml=yaml.slice(0,yaml.indexOf('\nvolumes:'))+'\n';if(!yaml.includes('tmpfs:')||yaml.includes('55444'))throw Error('Unsafe baseline Compose');fs.writeFileSync(path.join(dest,'compose.b3.yaml'),yaml);
try{
 const commands=[['scripts/b3/infra.mjs','env'],['scripts/b3/infra.mjs','up'],...(process.argv.includes('--descendants-only')?[]:[['scripts/b3/test.mjs']]),['scripts/b3/b2h-regression.mjs']];
 if(process.argv.includes('--descendants-only')){const prior=JSON.parse(fs.readFileSync(path.join(dest,'.local/b3/results/integration.json')));if(prior.summary.passed!==78||prior.summary.failed!==0)throw Error('No successful B3 result to resume');}
 for(const args of commands){
 const r=spawnSync(process.execPath,args,{cwd:dest,env:{...process.env,MS_B4_REGRESSION_SCRATCH:flat},encoding:'utf8',timeout:1200000,maxBuffer:20*1024*1024});process.stdout.write((r.stdout??'')+(r.stderr??''));if(r.status!==0)throw Error('Original regression failed: '+args[0]);}
 const r=JSON.parse(fs.readFileSync(path.join(dest,'.local/b3/results/integration.json')));if(r.summary.passed!==78||r.summary.failed!==0||hash(fs.readFileSync(path.join(dest,'scripts/b3/test.mjs')))!==original)throw Error('Original B3 body/result mismatch');save('b3-regression.json',{...r,originalTestBodySha256:original});
 for(const name of ['b2h','b2b','b2a','b1b','b1a','b0'])save(name+'-regression.json',JSON.parse(fs.readFileSync(path.join(dest,'.local/b3/results',name+'-regression.json'))));
}finally{const r=spawnSync(docker,['compose','--project-name',project,'--file',path.join(dest,'compose.b3.yaml'),'--env-file',path.join(dest,'.env.b3.local'),'down','--volumes'],{stdio:'inherit'});if(r.status!==0)throw Error('Disposable B3 cleanup failed');}
