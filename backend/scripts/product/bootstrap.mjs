import fs from "node:fs";
import path from "node:path";
import { randomBytes, randomUUID } from "node:crypto";
import pg from "pg";
import { root, folder, applyEnvironment, client, identify } from "./local.mjs";
import { loadProductConfig, secret } from "../../dist/product/config.js";
import { normalizeMobile, keyed, digest } from "../../dist/product/crypto.js";

export async function bootstrap(db,cfg,{inviteMobile=null,branchId=null,roleKey="OWNER"}={}) {
  const facts=JSON.parse(fs.readFileSync(path.join(root,"../data/business-facts.json"),"utf8")).verified_or_user_provided;
  await db.query("BEGIN");
  try {
    await db.query("SELECT pg_advisory_xact_lock(603031,2)");
    const existing=(await db.query("SELECT * FROM ms_b1_design.product_runtime WHERE singleton")).rows[0];
    if(existing&&(existing.environment!==cfg.environment||existing.business_id!==cfg.businessId||existing.public_origin!==cfg.origin))throw Error("Refusing to adopt a different product realm");
    await db.query("INSERT INTO ms_b1_design.business(id,brand_name,slug) VALUES($1,$2,$3) ON CONFLICT(id) DO NOTHING",[cfg.businessId,facts.brand_name,cfg.environment==='test'?'product-synthetic-'+cfg.businessId:'mohammadstyle']);
    await db.query("INSERT INTO ms_b1_design.pricing_configuration_revision(business_id) VALUES($1) ON CONFLICT DO NOTHING",[cfg.businessId]);
    if(!(await db.query("SELECT 1 FROM ms_b1_design.branch WHERE business_id=$1",[cfg.businessId])).rowCount)
      await db.query("INSERT INTO ms_b1_design.branch(business_id,code,display_name,address,time_zone,active,bookable) VALUES($1,'POONAK',$2,$3,'Asia/Tehran',true,false)",[cfg.businessId,facts.brochure_title,facts.branch_1_location]);
    for(const [i,label]of facts.services.entries())await db.query("INSERT INTO ms_b1_design.service(business_id,code,display_name,active) VALUES($1,$2,$3,true) ON CONFLICT(business_id,code) DO NOTHING",[cfg.businessId,'BROCHURE_'+(i+1),label]);
    const permissions=['booking.customer','business.read','branch.read','branch.manage','catalog.read','catalog.manage','offering.read','offering.manage','staff.read','staff.manage','staff.link','staff.qualify','staff.history.read','schedule.read','schedule.history.read','schedule.manage','schedule.publish','resource.manage','branchhours.manage','timeoff.approve','policy.read','policy.manage','policy.override','policy.history.read','pricing.quote','booking.read','booking.manage','booking.configure','media.manage','media.rights.manage','media.publish','customer.read','customer.contact.read','payment.read','refund.review','notification.read','notification.manage','security.manage','operations.manage'];
    for(const key of permissions)await db.query("INSERT INTO ms_b1_design.permission(permission_key,description) VALUES($1,$2) ON CONFLICT(permission_key) DO NOTHING",[key,'Product permission: '+key]);
    const roles={CUSTOMER:['booking.customer'],OWNER:permissions,BRANCH_MANAGER:permissions.filter(p=>!['business.read','security.manage','policy.override','media.rights.manage','refund.review','notification.manage'].includes(p)),OPERATOR:['branch.read','staff.read','schedule.read','booking.read','customer.read','operations.manage']};
    for(const [key,allowed]of Object.entries(roles)){
      const role=(await db.query("INSERT INTO ms_b1_design.role(business_id,role_key,display_name,system_role,product_mfa_required) VALUES($1,$2,$3,true,$4) ON CONFLICT(business_id,role_key) DO UPDATE SET role_key=excluded.role_key RETURNING id",[cfg.businessId,key,{CUSTOMER:'مشتری',OWNER:'مالک مجموعه',BRANCH_MANAGER:'مدیر شعبه',OPERATOR:'پذیرش'}[key],key!=='CUSTOMER'])).rows[0].id;
      for(const permission of allowed)await db.query("INSERT INTO ms_b1_design.role_permission(business_id,role_id,permission_id) SELECT $1,$2,id FROM ms_b1_design.permission WHERE permission_key=$3 ON CONFLICT DO NOTHING",[cfg.businessId,role,permission]);
    }
    await db.query("INSERT INTO ms_b1_design.product_runtime(singleton,business_id,environment,public_origin,session_seconds,idle_seconds) VALUES(true,$1,$2,$3,$4,$5) ON CONFLICT(singleton) DO NOTHING",[cfg.businessId,cfg.environment,cfg.origin,cfg.sessionSeconds,cfg.idleSeconds]);
    await db.query("UPDATE ms_b1_design.product_runtime SET payment_provider=$1,sms_provider=$2 WHERE singleton",[cfg.payment,cfg.sms]);
    let invitation=null;
    if(inviteMobile){
      const mobile=normalizeMobile(inviteMobile),raw=randomBytes(32).toString('base64url');
      if(!['OWNER','BRANCH_MANAGER','OPERATOR'].includes(roleKey)||(roleKey!=='OWNER'&&!branchId)||(roleKey==='OWNER'&&branchId))throw Error('Explicit valid invitation role/scope required');
      const role=(await db.query("SELECT id FROM ms_b1_design.role WHERE business_id=$1 AND role_key=$2",[cfg.businessId,roleKey])).rows[0].id;
      if(branchId&&!(await db.query("SELECT 1 FROM ms_b1_design.branch WHERE business_id=$1 AND id=$2 AND archived_at IS NULL",[cfg.businessId,branchId])).rowCount)throw Error('Invitation scope mismatch');
      const id=randomUUID();await db.query("INSERT INTO ms_b1_design.product_admin_invitation(id,business_id,mobile_lookup,invitation_hash,role_id,branch_id,expires_at) VALUES($1,$2,$3,$4,$5,$6,clock_timestamp()+interval '24 hours')",[id,cfg.businessId,keyed(cfg.identityKey,'mobile',mobile),digest(raw),role,branchId]);
      await db.query("INSERT INTO ms_b1_design.audit_log(business_id,action,target_type,target_id,request_id,redacted_change) VALUES($1,'admin.invitation.created','admin_invitation',$2,$3,$4)",[cfg.businessId,id,randomUUID(),JSON.stringify({role:roleKey,branchId,method:'operator-cli'})]);
      invitation={token:raw,mobile,activationUrl:cfg.origin+'/admin/activate'};
    }
    await db.query('COMMIT');return {businessId:cfg.businessId,invitation};
  }catch(e){await db.query('ROLLBACK');throw e;}
}
if(process.argv[1]?.replaceAll('\\','/').endsWith('/scripts/product/bootstrap.mjs')){
 const test=process.argv.includes('--test');if(test)applyEnvironment();const cfg=loadProductConfig(process.env,'bootstrap');
 const db=test?client():new pg.Client({host:cfg.database.host,port:cfg.database.port,database:cfg.database.database,user:'ms_b1a_migrator',password:secret(process.env,'PRODUCT_MIGRATOR_PASSWORD'),ssl:cfg.database.ssl});
 await db.connect();if(test)await identify(db,'ms_product_test');
 try{const mobile=process.argv.find(x=>x.startsWith('--invite-mobile='))?.slice(16)??null;
 const roleKey=process.argv.find(x=>x.startsWith('--role='))?.slice(7)??'OWNER',branchId=process.argv.find(x=>x.startsWith('--branch='))?.slice(9)??null;
 if(mobile&&!test&&!process.env.ADMIN_INVITATION_OUTPUT)throw Error('Private ADMIN_INVITATION_OUTPUT path required before creating an invitation');
 const result=await bootstrap(db,cfg,{inviteMobile:mobile,roleKey,branchId});
 if(result.invitation){const destination=test?path.join(folder,'owner-invitation.json'):process.env.ADMIN_INVITATION_OUTPUT;
 if(!destination)throw Error('Private ADMIN_INVITATION_OUTPUT path required before creating an invitation');fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,JSON.stringify(result.invitation,null,2),{mode:0o600});}
 console.log('Product site configured from verified business facts; no prices, staff, policy or identity verification invented. Invitation, if requested, requires real OTP and MFA activation. Secrets withheld.');
 }finally{await db.end();}
}
