import fs from 'node:fs';
import path from 'node:path';
import {catalog as foundationCatalog,fingerprint} from '../b1a/catalog.mjs';
import {root} from './local.mjs';
export {fingerprint};
export async function catalog(db) {
 const value=await foundationCatalog(db);
 value.apiRoles=(await db.query("SELECT rolname,rolsuper,rolcreaterole,rolcreatedb,rolreplication,rolbypassrls,rolcanlogin FROM pg_roles WHERE rolname='ms_b1b_api'")).rows;
 value.apiMemberships=(await db.query("SELECT pg_get_userbyid(roleid) AS role,admin_option FROM pg_auth_members WHERE member=(SELECT oid FROM pg_roles WHERE rolname='ms_b1b_api') ORDER BY role")).rows;
 value.apiDatabasePrivileges=(await db.query("SELECT has_database_privilege('ms_b1b_api',current_database(),'CREATE') AS create,has_database_privilege('ms_b1b_api',current_database(),'TEMP') AS temp,has_database_privilege('ms_b1b_api',current_database(),'CONNECT') AS connect")).rows;
 value.functionSecurity=(await db.query(`SELECT p.proname,pg_get_function_identity_arguments(p.oid) AS args,pg_get_userbyid(p.proowner) AS owner,p.prosecdef,p.proconfig,
 CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END AS grantee,a.privilege_type,a.is_grantable
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace CROSS JOIN LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
 WHERE n.nspname='ms_b1_design' ORDER BY p.proname,args,grantee,a.privilege_type`)).rows;
 return value;
}
export async function assertCatalog(db) {
 const actual=await catalog(db),expected=JSON.parse(fs.readFileSync(path.join(root,'migrations/catalog.b1b.expected.json'),'utf8'));
 if(fingerprint(actual)!==expected.sha256)throw Object.assign(Error('B1B catalog drift; refuse automatic repair'),{code:'B1B_DRIFT'});
 return {sha256:expected.sha256,tables:actual.tables.length,indexes:actual.indexes.length,functions:actual.routines.length,foreignKeys:actual.constraints.filter(c=>c.type==='f').length,checks:actual.constraints.filter(c=>c.type==='c').length};
}
