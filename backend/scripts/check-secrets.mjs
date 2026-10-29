import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { root, localEnv, save } from './local.mjs';
const repository = path.dirname(root), env = localEnv();
const args = ['-C',repository];
const files = execFileSync('git',[...args,'ls-files','-z','--cached','--others','--exclude-standard','--','backend','docs/backend','docs/PROJECT_CONTEXT.md','tsconfig.json','.github'],{encoding:'utf8'}).split('\0').filter(Boolean);
const forbidden = [env.B0_ADMIN_PASSWORD, env.B0_PROBE_PASSWORD];
const b2aEnv=path.join(root,'.env.b2a.local');
if(fs.existsSync(b2aEnv)) {
  for(const line of fs.readFileSync(b2aEnv,'utf8').split(/\r?\n/).filter(line=>/^B2A_.*_PASSWORD=/.test(line))) forbidden.push(line.slice(line.indexOf('=')+1));
  execFileSync('git',[...args,'check-ignore','--quiet','backend/.env.b2a.local']);
}
const b1bEnv=path.join(root,'.env.b1b.local');
if(fs.existsSync(b1bEnv)) {
  for(const line of fs.readFileSync(b1bEnv,'utf8').split(/\r?\n/).filter(line=>/^B1B_.*_PASSWORD=/.test(line))) forbidden.push(line.slice(line.indexOf('=')+1));
  execFileSync('git',[...args,'check-ignore','--quiet','backend/.env.b1b.local']);
}
const b1aEnv=path.join(root,'.env.b1a.local');
if(fs.existsSync(b1aEnv)) {
  for(const line of fs.readFileSync(b1aEnv,'utf8').split(/\r?\n/).filter(line=>/^B1A_.*_PASSWORD=/.test(line))) forbidden.push(line.slice(line.indexOf('=')+1));
  execFileSync('git',[...args,'check-ignore','--quiet','backend/.env.b1a.local']);
}
const regressionEnv=path.join(root,'.local/b1a/b0-regression.env');
if(fs.existsSync(regressionEnv))for(const line of fs.readFileSync(regressionEnv,'utf8').split(/\r?\n/).filter(line=>/^B0_.*_PASSWORD=/.test(line)))forbidden.push(line.slice(line.indexOf('=')+1));
for(const file of files) {
  assert.ok(!/\.(env|pem|key)$|\.env\.local|node_modules\/|\.local\//.test(file),`Forbidden export path ${file}`);
  const data = fs.readFileSync(path.join(repository,file),'utf8');
  for(const secret of forbidden) assert.ok(!data.includes(secret),`Local credential found in ${file}`);
  assert.ok(!/-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----|(?:ghp_|github_pat_)[A-Za-z0-9_]{20,}/.test(data),`Credential signature in ${file}`);
}
execFileSync('git',[...args,'check-ignore','--quiet','backend/.env.local']);
const result = { status:'PASS', checkedFiles:files.length, localCredentialsAbsent:true, localEnvironmentIgnored:true, note:'Value/signature/path checks; not a proof of absence of every possible secret' };
if(process.env.MS_SECURITY_RESULTS==='b2a') {
  const directory=path.join(root,'.local/b2a/results');fs.mkdirSync(directory,{recursive:true});fs.writeFileSync(path.join(directory,'secrets.json'),JSON.stringify(result,null,2)+'\n');
} else {
  if(process.env.MS_SECURITY_RESULTS)throw Error('Unknown security evidence profile');
  save('secrets-results.json',result);
}
console.log(JSON.stringify(result));
