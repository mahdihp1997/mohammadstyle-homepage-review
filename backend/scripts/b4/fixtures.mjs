// Trusted disposable-test provisioning only. Never imported by API code.
import {randomUUID,randomBytes,createHash} from 'node:crypto';
export const hash=x=>createHash('sha256').update(x).digest();
export const terms=(extra={})=>({depositRequirement:'NONE',amountKind:null,fixedRial:null,basisPoints:null,minimumRial:null,maximumRial:null,refundability:'FULL',refundBase:'DEPOSIT_PAID',outsideRefundBps:'10000',cancellationDeadlineMinutes:'0',termsText:'B4 SYNTHETIC — شرایط صرفاً آزمایشی؛ تعرفه و سیاست واقعی سالن نیست.',termsLocale:'fa',effectiveFrom:'2026-01-01T00:00:00.000Z',effectiveTo:null,refundWindows:[],...extra});
export async function fixtures(db){
 async function insert(table,d){const keys=Object.keys(d);return(await db.query(`INSERT INTO ms_b1_design.${table}(${keys.join(',')}) VALUES(${keys.map((_,i)=>'$'+(i+1)).join(',')}) RETURNING *`,Object.values(d))).rows[0];}
 const business=await insert('business',{brand_name:'B4 SYNTHETIC — not salon configuration',slug:'b4-synthetic-'+randomUUID()});
 await insert('pricing_configuration_revision',{business_id:business.id});
 const branch=await insert('branch',{business_id:business.id,code:'B4_SYNTHETIC',display_name:'شعبه آزمایشی B4',time_zone:'Asia/Tehran',active:true});
 const secondBranch=await insert('branch',{business_id:business.id,code:'B4_UNCONFIGURED',display_name:'پیکربندی ناقص آزمایشی',time_zone:'Asia/Tehran',active:true});
 async function actor(label,{verified=true,configure=false,businessId=business.id}={}){
  const user=await insert('app_user',{display_name:'B4 SYNTHETIC '+label,status:'ACTIVE'}),role=await insert('role',{business_id:businessId,role_key:'B4_'+randomUUID(),display_name:'B4 SYNTHETIC isolated customer'});
  await insert('user_role_assignment',{business_id:businessId,user_id:user.id,role_id:role.id});
  for(const key of ['booking.customer',...(configure?['booking.configure','policy.read','policy.manage','policy.override','pricing.quote']:[])]){let p=(await db.query('SELECT * FROM ms_b1_design.permission WHERE permission_key=$1',[key])).rows[0];p??=await insert('permission',{permission_key:key,description:'B4 SYNTHETIC permission'});await insert('role_permission',{business_id:businessId,role_id:role.id,permission_id:p.id});}
  if(verified)await insert('auth_identity',{user_id:user.id,provider:'B4_ISOLATED_TEST',subject_hash:hash(randomUUID()),verified_at:new Date()});
  const token=randomBytes(32).toString('base64url'),csrf=randomBytes(32).toString('base64url');
  await insert('auth_session',{user_id:user.id,business_id:businessId,token_hash:hash(token),csrf_hash:hash(csrf),expires_at:new Date(Date.now()+3600000),idle_expires_at:new Date(Date.now()+900000)});return {userId:user.id,token,csrf,businessId};
 }
 const owner=await actor('owner',{configure:true}),customer=await actor('customer'),other=await actor('other'),unverified=await actor('unverified',{verified:false});
 const day=new Date(Date.now()+86400000).toISOString().slice(0,10),start=new Date(day+'T06:30:00.000Z'),end=new Date(day+'T15:30:00.000Z');
 await insert('availability_configuration',{business_id:business.id,branch_id:branch.id,slot_stride_minutes:30,lead_minutes:0,horizon_days:60,hold_ttl_seconds:30,quote_ttl_seconds:60});
 await insert('branch_working_hours',{business_id:business.id,branch_id:branch.id,iso_weekday:new Date(day+'T12:00Z').getUTCDay()||7,start_minute:600,end_minute:1140,valid_from:day});
 const services=[],offerings=[],staff=[];
 for(const [code,name,price,duration]of [['hair','هیرکات مو','100000','30'],['facial','فیشیال صورت','200000','30']]){
  const service=await insert('service',{business_id:business.id,code:'B4_SYNTHETIC_'+code,display_name:name+' · آزمایشی',active:true});services.push(service);
  const o=await insert('branch_service_offering',{business_id:business.id,branch_id:branch.id,service_id:service.id,price_rial:price,duration_minutes:Number(duration),buffer_before_minutes:5,buffer_after_minutes:5,resources_confirmed:true});offerings.push(o);
  await insert('offering_resource_requirement',{business_id:business.id,branch_id:branch.id,offering_id:o.id,service_id:service.id,resource_kind:'CHAIR',quantity:1});
  if(code==='facial')for(const kind of ['ROOM','DEVICE'])await insert('offering_resource_requirement',{business_id:business.id,branch_id:branch.id,offering_id:o.id,service_id:service.id,resource_kind:kind,quantity:1});
 }
 for(const kind of ['CHAIR','ROOM','DEVICE'])await insert('resource',{business_id:business.id,branch_id:branch.id,kind,label:'B4 SYNTHETIC '+kind,active:true});
 for(let i=0;i<2;i++){
  const resource=await insert('resource',{business_id:business.id,kind:'STAFF',label:'B4 SYNTHETIC staff '+i,active:true}),s=await insert('staff',{business_id:business.id,resource_id:resource.id,display_name:'ارائه‌دهنده آزمایشی '+(i+1),active:true});staff.push(s);
  const member=await insert('staff_branch_assignment',{business_id:business.id,staff_id:s.id,branch_id:branch.id,valid_from:day,active:true});
  for(const o of offerings){const q=await insert('staff_service_eligibility',{business_id:business.id,staff_id:s.id,service_id:o.service_id,active:true,verified_at:new Date(),verified_by:owner.userId,verification_evidence_hash:hash('B4 SYNTHETIC qualification')});
   await insert('offering_staff_eligibility',{business_id:business.id,branch_id:branch.id,offering_id:o.id,service_id:o.service_id,staff_id:s.id,assignment_id:member.id,qualification_id:q.id,active:true});}
  await insert('staff_shift',{business_id:business.id,branch_id:branch.id,staff_id:s.id,assignment_id:member.id,starts_at:start,ends_at:end,published:true,schedule_version:1,local_date:day,time_zone:'Asia/Tehran',start_minute:600,end_minute:1140,start_resolution:'reject',end_resolution:'reject'});
 }
 return {business,branch,secondBranch,owner,customer,other,unverified,day,start,end,services,offerings,staff,insert,actor};
}
