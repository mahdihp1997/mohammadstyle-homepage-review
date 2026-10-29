import fs from 'node:fs';import path from 'node:path';import {spawnSync} from 'node:child_process';
import {root,docker,save} from './local.mjs';
// Exact existing47-test body, immutable0001/0002/catalog/registry and compiled B1A
// repositories run in a copied harness. Only ignored harness routing is rewritten.
// This avoids any change to approved B1A scripts or access to its55434 cluster.
const dest=path.join(root,'.local/b1b/b1a-regression-source');
if(!dest.startsWith(path.join(root,'.local/b1b')+path.sep))throw Error('Unexpected regression workspace');
fs.mkdirSync(dest,{recursive:true});
for(const name of ['scripts','migrations','dist','test'])fs.cpSync(path.join(root,name),path.join(dest,name),{recursive:true});
fs.copyFileSync(path.join(root,'package.json'),path.join(dest,'package.json'));
for(const name of ['scripts/b1a/local.mjs','scripts/b1a/infra.mjs','scripts/b1a/backup.mjs','dist/persistence/transaction.js']) {
 const file=path.join(dest,name);fs.writeFileSync(file,fs.readFileSync(file,'utf8').replaceAll('55434','55437').replaceAll('mohammadstyle-b1a','mohammadstyle-b1b-baseline'));
}
let yaml=fs.readFileSync(path.join(root,'compose.b1a.yaml'),'utf8').replaceAll('mohammadstyle-b1a','mohammadstyle-b1b-baseline').replaceAll('55434','55437');
yaml=yaml.replace('    volumes: ["b1a_pgdata:/var/lib/postgresql"]','    tmpfs: ["/var/lib/postgresql"]');
yaml=yaml.slice(0,yaml.indexOf('\nvolumes:'))+'\n';fs.writeFileSync(path.join(dest,'compose.b1a.yaml'),yaml);
const commands=[['scripts/b1a/infra.mjs','env'],['scripts/b1a/infra.mjs','up'],['scripts/b1a/test.mjs']];
try {
 for(const args of commands) {
  const run=spawnSync(process.execPath,args,{cwd:dest,encoding:'utf8',timeout:180000,maxBuffer:5*1024*1024});
  process.stdout.write((run.stdout??'')+(run.stderr??''));if(run.status!==0)throw Error('Isolated B1A regression failed');
 }
 const result=JSON.parse(fs.readFileSync(path.join(dest,'.local/b1a/results/integration.json'),'utf8'));
 if(result.summary.passed!==47||result.summary.failed!==0)throw Error('Original47 B1A tests not preserved');
 save('b1a-regression.json',{...result,originalB1ADatabasesTouched:false,harness:'Exact test body; routing only in ignored copy; tmpfs55437'});
} finally {
 const run=spawnSync(docker,['compose','--project-name','mohammadstyle-b1b-baseline','--file',path.join(dest,'compose.b1a.yaml'),'--env-file',path.join(dest,'.env.b1a.local'),'down','--volumes'],{stdio:'inherit'});
 if(run.status!==0)throw Error('Isolated B1A cleanup failed');
}
