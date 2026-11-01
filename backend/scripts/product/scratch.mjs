import{client,identify,marker}from'./local.mjs';
/** Only owned scratch databases; never the running product-test DB, never FORCE. */
export async function freshScratch(name){if(!['ms_product_failure','ms_product_restore'].includes(name)||process.env.APP_ENV!=='product-test'||process.env.NODE_ENV==='production')throw Error('ISOLATED_SCRATCH_ONLY');
 const check=client(name,'admin');await check.connect();try{await identify(check,name,'admin');
  if((await check.query('SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid()')).rowCount)throw Error('SCRATCH_DATABASE_IN_USE');
  if((await check.query("SELECT to_regclass('ms_b1_design.product_runtime') present")).rows[0].present){const r=(await check.query('SELECT environment FROM ms_b1_design.product_runtime WHERE singleton')).rows[0];if(r&&r.environment!=='test')throw Error('NONTEST_REALM_REFUSED');}
 }finally{await check.end();}
 const control=client('ms_product_control','admin');await control.connect();try{
  const literal=name==='ms_product_failure'?'ms_product_failure':'ms_product_restore';
  await control.query('DROP DATABASE '+literal);await control.query('CREATE DATABASE '+literal+' OWNER ms_b1a_migrator');await control.query("COMMENT ON DATABASE "+literal+" IS '"+marker+"'");
 }finally{await control.end();}
}
