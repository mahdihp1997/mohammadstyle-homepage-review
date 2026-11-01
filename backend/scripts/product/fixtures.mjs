// Trusted, explicitly isolated fixtures. No synthetic identity or commercial seed in runtime.
import {randomUUID,randomInt} from 'node:crypto';import {bootstrap} from './bootstrap.mjs';
import {token,digest,keyed,normalizeMobile,unseal,totp} from '../../dist/product/crypto.js';import {terms} from '../b4/fixtures.mjs';
export async function identities(db,cfg,auth){
 if(cfg.environment!=='test'||process.env.APP_ENV!=='product-test'||process.env.NODE_ENV==='production')throw Error('SYNTHETIC_FIXTURE_FORBIDDEN');
 let serial=randomInt(10000000,80000000);const phone=()=> '090'+String(++serial).padStart(8,'0');
 const context=()=>({binding:digest(token()),peer:keyed(cfg.identityKey,'peer',token()),device:'SYNTHETIC product fixture'});
 async function request(mobile,ctx,kind='MOBILE_LOGIN',extra={}){const r=await auth.request(kind,{mobile,...extra},ctx);const row=(await db.query('SELECT secret_ciphertext FROM ms_b1_design.product_auth_challenge WHERE id=$1',[r.challengeId])).rows[0];return {...r,...unseal(cfg.encryptionKey,row.secret_ciphertext,'otp:'+r.challengeId)};}
 async function customer(){const mobile=phone(),ctx=context(),r=await request(mobile,ctx),result=await auth.verify({challengeId:r.challengeId,code:r.code},ctx);return{mobile,ctx,result};}
 async function administrator({branchId=null,roleKey='OWNER'}={}){const mobile=phone(),ctx=context(),invitation=(await bootstrap(db,cfg,{inviteMobile:mobile,branchId,roleKey})).invitation;
  const r=await request(mobile,ctx,'ADMIN_ACTIVATION',{invitation:invitation.token});await auth.verify({challengeId:r.challengeId,code:r.code},ctx);
  const username='qa_'+randomUUID().slice(0,8),password=token(),ready=await auth.activate({challengeId:r.challengeId,username,password},ctx),result=await auth.mfa({challengeId:ready.challengeId,code:totp(ready.secret,BigInt(Math.floor(Date.now()/30000)))},ctx);
  return{mobile,username,password,secret:ready.secret,ctx,result};}
 return{phone,context,request,customer,administrator};
}
export async function commercialFixture(db,cfg,repo,owner,{deposit='20000'}={}){
 if(cfg.environment!=='test'||process.env.APP_ENV!=='product-test'||process.env.NODE_ENV==='production')throw Error('SYNTHETIC_FIXTURE_FORBIDDEN');
 const bid=cfg.businessId;const h=digest(owner.result.session.token),csrf=digest(owner.result.session.csrf);
 async function insert(table,d){const keys=Object.keys(d);return(await db.query(`INSERT INTO ms_b1_design.${table}(${keys.join(',')}) VALUES(${keys.map((_,i)=>'$'+(i+1)).join(',')}) RETURNING *`,Object.values(d))).rows[0];}
 const branch=await insert('branch',{business_id:bid,code:'SYNTHETIC_'+randomUUID().slice(0,8),display_name:'شعبهٔ صرفاً آزمایشی — اطلاعات واقعی سالن نیست',time_zone:'Asia/Tehran',active:true});
 // Explicit synthetic mock gateway configuration; runtime defaults remain NONE.
 if(cfg.payment==='mock')await insert('product_payment_configuration',{business_id:bid,branch_id:branch.id,online_enabled:true,manual_enabled:false,updated_by:owner.result.userId});
 const day=new Date(Date.now()+86400000).toISOString().slice(0,10),start=new Date(day+'T06:30:00Z'),end=new Date(day+'T15:30:00Z');
 await insert('availability_configuration',{business_id:bid,branch_id:branch.id,slot_stride_minutes:30,lead_minutes:0,horizon_days:60,hold_ttl_seconds:300,quote_ttl_seconds:300});
 await insert('branch_working_hours',{business_id:bid,branch_id:branch.id,iso_weekday:new Date(day+'T12:00Z').getUTCDay()||7,start_minute:600,end_minute:1140,valid_from:day});
 const services=(await db.query("SELECT * FROM ms_b1_design.service WHERE business_id=$1 AND code IN('BROCHURE_2','BROCHURE_3') ORDER BY code",[bid])).rows,offerings=[],staff=[];
 for(const s of services){const o=await insert('branch_service_offering',{business_id:bid,branch_id:branch.id,service_id:s.id,price_rial:'100000',duration_minutes:30,buffer_before_minutes:5,buffer_after_minutes:5,resources_confirmed:true});offerings.push(o);
  await insert('offering_resource_requirement',{business_id:bid,branch_id:branch.id,offering_id:o.id,service_id:s.id,resource_kind:'CHAIR',quantity:1});}
 await insert('resource',{business_id:bid,branch_id:branch.id,kind:'CHAIR',label:'SYNTHETIC chair',active:true});
 for(let i=0;i<2;i++){const resource=await insert('resource',{business_id:bid,kind:'STAFF',label:'SYNTHETIC staff',active:true});const s=await insert('staff',{business_id:bid,resource_id:resource.id,display_name:'ارائه‌دهندهٔ آزمایشی '+(i+1),active:true});staff.push(s);
  const member=await insert('staff_branch_assignment',{business_id:bid,staff_id:s.id,branch_id:branch.id,valid_from:day,active:true});
  for(const o of offerings){const q=await insert('staff_service_eligibility',{business_id:bid,staff_id:s.id,service_id:o.service_id,active:true,verified_at:new Date(),verified_by:owner.result.userId,verification_evidence_hash:digest('SYNTHETIC product qualification')});
   await insert('offering_staff_eligibility',{business_id:bid,branch_id:branch.id,offering_id:o.id,service_id:o.service_id,staff_id:s.id,assignment_id:member.id,qualification_id:q.id,active:true});}
  await insert('staff_shift',{business_id:bid,branch_id:branch.id,staff_id:s.id,assignment_id:member.id,starts_at:start,ends_at:end,published:true,schedule_version:1,local_date:day,time_zone:'Asia/Tehran',start_minute:600,end_minute:1140,start_resolution:'reject',end_resolution:'reject'});}
 async function pricing(op,data,id=null,branchId=null){const v=(await db.query('SELECT revision::text v FROM ms_b1_design.pricing_configuration_revision WHERE business_id=$1',[bid])).rows[0].v;return(await repo.pricingCommand(h,csrf,op,branchId,id,v,randomUUID(),randomUUID(),data)).body;}
 const policy=await pricing('policy.create',{code:'SYNTHETIC_'+randomUUID().slice(0,8),name:'شرایط صرفاً آزمایشی محصول'}),version=await pricing('version.create',{terms:terms(deposit==='0'?{}:{depositRequirement:'REQUIRED',amountKind:'FIXED',fixedRial:deposit})},policy.id);
 await pricing('version.publish',{},version.id);await pricing('assignment.create',{versionId:version.id,scopeKind:'BRANCH',serviceId:null,staffId:null,priority:'0',effectiveFrom:'2026-01-01T00:00:00.000Z',effectiveTo:null,reason:null,serviceIds:[],compatibleVersionIds:[]},null,branch.id);
 await repo.command(h,csrf,'configuration.enable',randomUUID(),randomUUID(),{branchId:branch.id,offeringIds:offerings.map(x=>x.id)});
 return{branch,offerings,staff,day,pricing,policy,version};
}
