import {client,identify} from './local.mjs';import {migrate} from './migrate.mjs';
const db=client('ms_b3_dev');try{await db.connect();await identify(db,'ms_b3_dev');console.log(JSON.stringify(await migrate(db,'ms_b3_dev')));}finally{await db.end();}
