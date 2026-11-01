import{applyEnvironment,client,save}from'./local.mjs';import{loadProductConfig}from'../../dist/product/config.js';import{ProductAuthService}from'../../dist/product/auth.js';import{identities}from'./fixtures.mjs';import{digest}from'../../dist/product/crypto.js';import{randomUUID}from'node:crypto';applyEnvironment();const cfg=loadProductConfig(),auth=new ProductAuthService(cfg),db=client('ms_product_test','admin');await db.connect();await auth.onModuleInit();try{
 await db.query("SET track_functions='all'");await db.query('SET jit=off');
 const before=(await db.query('SELECT funcid,calls,total_time,self_time FROM pg_stat_user_functions')).rows;
 const p=(await db.query('SELECT business_id,branch_id,selectors FROM ms_b1_design.booking_plan ORDER BY created_at DESC LIMIT 1')).rows[0];
 const actor=await(await identities(db,cfg,auth)).customer();await db.query('BEGIN ISOLATION LEVEL SERIALIZABLE');await db.query('SET ROLE ms_b1b_api');
 const start=performance.now();await db.query('SELECT ms_b1_design.b4_command($1,$2,$3,$4,$5,$6)',[digest(actor.result.session.token),digest(actor.result.session.csrf),'availability',randomUUID(),randomUUID(),{branchId:p.branch_id,offeringIds:p.selectors.selection.offerings.map(x=>x.id),staffId:null,date:p.selectors.selection.startsAt.slice(0,10),optionalDepositChosen:false,rescheduleBookingId:null,cursor:'600'}]);const elapsed=performance.now()-start;await db.query('COMMIT');await db.query('RESET ROLE');
 await db.query('SELECT pg_stat_force_next_flush()');await db.query('SELECT pg_stat_clear_snapshot()');
 const after=(await db.query("SELECT funcid,funcname,calls,total_time,self_time FROM pg_stat_user_functions WHERE schemaname='ms_b1_design'")).rows;
 const changes=after.map(a=>{const b=before.find(b=>b.funcid===a.funcid);return{name:a.funcname,calls:Number(a.calls)-Number(b?.calls??0),totalMs:a.total_time-(b?.total_time??0),selfMs:a.self_time-(b?.self_time??0)};}).filter(a=>a.calls>0).sort((a,b)=>b.selfMs-a.selfMs);
 const result={elapsedMs:Math.round(elapsed),changes};save('planner-profile.json',result);console.log(JSON.stringify(result,null,2));
}finally{await auth.onModuleDestroy();await db.end();}
