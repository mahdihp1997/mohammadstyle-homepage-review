import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { client, save } from './local.mjs';
const docker = process.env.DOCKER_BIN || (process.platform === 'win32' ? 'C:\\Program Files\\Docker\\Docker\\resources\\bin\\docker.exe' : 'docker');
const run = args => execFileSync(docker,args,{encoding:'utf8'}).trim();
const report = { executedAt:new Date().toISOString(), hostNode:process.version,
  docker:JSON.parse(run(['version','--format','{{json .Server.Version}}'])), compose:run(['compose','version','--short']), containers:[] };
for(const name of ['mohammadstyle-b0-postgres-1','mohammadstyle-b0-api-1']) {
  const data = JSON.parse(run(['inspect',name,'--format','{"name":{{json .Name}},"health":{{json .State.Health.Status}},"ports":{{json .NetworkSettings.Ports}},"image":{{json .Config.Image}},"project":{{json (index .Config.Labels "com.docker.compose.project")}}}']));
  assert.equal(data.project,'mohammadstyle-b0'); assert.equal(data.health,'healthy');
  const bindings=Object.values(data.ports).flat(); assert.ok(bindings.length>0);
  for(const binding of bindings) assert.equal(binding.HostIp,'127.0.0.1');
  report.containers.push(data);
}
report.containerNode = run(['exec','mohammadstyle-b0-api-1','node','--version']);
report.containerNpm = run(['exec','mohammadstyle-b0-api-1','npm','--version']);
report.runtimeUser = run(['exec','mohammadstyle-b0-api-1','id','-u']); assert.notEqual(report.runtimeUser,'0');
report.health = [];
for(const endpoint of ['live','ready']) {
  const response=await fetch(`http://127.0.0.1:3100/health/${endpoint}`,{signal:AbortSignal.timeout(5000)});
  assert.equal(response.status,200); report.health.push({endpoint,status:response.status,body:await response.json()});
}
const db=client('ms_b0_control',true); await db.connect();
try { report.database=(await db.query("SELECT version(),current_user,current_database(),inet_server_port(),(SELECT count(*)::int FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema')) AS application_tables")).rows[0];
  assert.equal(report.database.application_tables,0);
} finally { await db.end(); }
report.status='PASS'; save('environment-results.json',report); console.log(JSON.stringify(report,null,2));
