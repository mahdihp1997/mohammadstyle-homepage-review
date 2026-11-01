import {loadProductConfig} from './config.js';
import {ProductWorker} from './worker.js';
const cfg=loadProductConfig(process.env,'worker'),worker=new ProductWorker(cfg);let stopping=false;
process.on('SIGTERM',()=>{stopping=true;});process.on('SIGINT',()=>{stopping=true;});
await worker.init();
while(!stopping){try{await worker.tick();}catch{process.stderr.write(JSON.stringify({event:'worker.tick.failed',at:new Date().toISOString()})+'\n');}
  if(!stopping)await new Promise(resolve=>setTimeout(resolve,2000));}
await worker.close();
