import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { root, localEnv, save } from './local.mjs';
const repository = path.dirname(root), env = localEnv();
const args = ['-C',repository];
const files = execFileSync('git',[...args,'ls-files','-z','--cached','--others','--exclude-standard','--','backend','docs/backend','docs/PROJECT_CONTEXT.md','tsconfig.json'],{encoding:'utf8'}).split('\0').filter(Boolean);
const forbidden = [env.B0_ADMIN_PASSWORD, env.B0_PROBE_PASSWORD];
for(const file of files) {
  assert.ok(!/\.(env|pem|key)$|\.env\.local|node_modules\/|\.local\//.test(file),`Forbidden export path ${file}`);
  const data = fs.readFileSync(path.join(repository,file),'utf8');
  for(const secret of forbidden) assert.ok(!data.includes(secret),`Local credential found in ${file}`);
  assert.ok(!/-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----|(?:ghp_|github_pat_)[A-Za-z0-9_]{20,}/.test(data),`Credential signature in ${file}`);
}
execFileSync('git',[...args,'check-ignore','--quiet','backend/.env.local']);
const result = { status:'PASS', checkedFiles:files.length, localCredentialsAbsent:true, localEnvironmentIgnored:true, note:'Value/signature/path checks; not a proof of absence of every possible secret' };
save('secrets-results.json',result); console.log(JSON.stringify(result));
