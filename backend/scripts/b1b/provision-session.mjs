import {randomBytes,createHash} from 'node:crypto';
import {client,identify} from './local.mjs';
const hash=v=>createHash('sha256').update(v,'ascii').digest();
/** Test harness/CLI only; never imported by API source. Requires a marked disposable DB,
 * migration credentials and an existing SYNTHETIC active user/role assignment.
 * Locks user, revokes old sessions and mints entirely new entropy (no supplied token).
 */
export async function provisionSession(userId,businessId) {
 if(process.env.APP_ENV!=='b1b-local'||process.env.NODE_ENV==='production')throw Error('Synthetic provisioning is local-only');
 if(![userId,businessId].every(v=>/^[0-9a-f-]{36}$/.test(v)))throw Error('Invalid synthetic identity');
 const db=client('ms_b1b_dev');await db.connect();
 try {
  await identify(db,'ms_b1b_dev');await db.query('BEGIN');
  const found=(await db.query("SELECT id FROM ms_b1_design.app_user WHERE id=$1 AND status='ACTIVE' AND archived_at IS NULL AND display_name LIKE 'B1B SYNTHETIC %' FOR UPDATE",[userId])).rowCount;
  if(!found||!(await db.query('SELECT 1 FROM ms_b1_design.user_role_assignment WHERE user_id=$1 AND business_id=$2 AND revoked_at IS NULL AND archived_at IS NULL',[userId,businessId])).rowCount)throw Error('Synthetic membership required');
  const token=randomBytes(32).toString('base64url'),csrf=randomBytes(32).toString('base64url');
  await db.query('UPDATE ms_b1_design.auth_session SET revoked_at=clock_timestamp(),row_version=row_version+1 WHERE user_id=$1 AND business_id=$2 AND revoked_at IS NULL',[userId,businessId]);
  const session=(await db.query("INSERT INTO ms_b1_design.auth_session(user_id,business_id,token_hash,csrf_hash,expires_at,idle_expires_at) VALUES($1,$2,$3,$4,clock_timestamp()+interval '1 hour',clock_timestamp()+interval '15 minutes') RETURNING id",[userId,businessId,hash(token),hash(csrf)])).rows[0];
  await db.query('COMMIT');return {token,csrf,id:session.id};
 } catch(e){await db.query('ROLLBACK');throw e;}finally{await db.end();}
}
