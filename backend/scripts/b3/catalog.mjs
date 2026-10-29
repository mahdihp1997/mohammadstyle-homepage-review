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
 value.triggers=(await db.query("SELECT c.relname AS table_name,t.tgname,pg_get_triggerdef(t.oid) AS definition FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='ms_b1_design' AND NOT t.tgisinternal ORDER BY c.relname,t.tgname")).rows;
 value.generatedExpressions=(await db.query("SELECT c.relname AS table_name,a.attname,a.attgenerated,pg_get_expr(d.adbin,d.adrelid) AS expression FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum WHERE n.nspname='ms_b1_design' AND a.attgenerated<>'' ORDER BY c.relname,a.attname")).rows;
 value.extensions=(await db.query("SELECT e.extname,e.extversion,pg_get_userbyid(e.extowner) AS owner,n.nspname AS schema FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace WHERE e.extname<>'plpgsql' ORDER BY e.extname")).rows;
 return value;
}
export async function assertCatalog(db) {
 const actual=await catalog(db),expected=JSON.parse(fs.readFileSync(path.join(root,'migrations/catalog.b3.expected.json'),'utf8'));
 if(fingerprint(actual)!==expected.sha256)throw Object.assign(Error('B3 catalog drift; refuse automatic repair'),{code:'B3_DRIFT'});
 return {sha256:expected.sha256,tables:actual.tables.length,indexes:actual.indexes.length,functions:actual.routines.length,foreignKeys:actual.constraints.filter(c=>c.type==='f').length,checks:actual.constraints.filter(c=>c.type==='c').length};
}
