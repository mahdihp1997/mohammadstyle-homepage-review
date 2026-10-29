import { Pool } from 'pg';
import type { SessionView } from '../admin/contracts.js';
import type { ResourceKind,PageQuery,WriteDto,CommandResult } from '../admin/contracts.js';
import type { CommandData,Operation,WorkforcePage,WorkforceReceipt } from './contracts.js';
export type WorkforceOptions = {host:'127.0.0.1';user:'ms_b1b_api';password:string} & (
 {port:55440;database:'ms_b2b_dev'|'ms_b2b_restore';origin:'http://127.0.0.1:3104'} |
 {port:55442;database:'ms_b2h_dev'|'ms_b2h_restore';origin:'http://127.0.0.1:3106'});
export class WorkforceRepository {
 private readonly pool:Pool;
 private readonly requiresHardenedReads:boolean;
 constructor(o:WorkforceOptions){
 this.requiresHardenedReads=o.port===55442;
 const profile=(o.port===55440&&['ms_b2b_dev','ms_b2b_restore'].includes(o.database)&&o.origin==='http://127.0.0.1:3104') || (o.port===55442&&['ms_b2h_dev','ms_b2h_restore'].includes(o.database)&&o.origin==='http://127.0.0.1:3106');
 if(process.env.NODE_ENV==='production'||process.env.APP_ENV==='production'||o.host!=='127.0.0.1'||!profile||o.user!=='ms_b1b_api'||!/^[a-f0-9]{64}$/.test(o.password))throw Error('B2B isolated local options required');
 const {origin:_origin,...connection}=o;this.pool=new Pool({...connection,max:4,connectionTimeoutMillis:2000,statement_timeout:15000,idle_in_transaction_session_timeout:15000,application_name:'mohammadstyle-b2b-api'});this.pool.on('error',()=>{});
 }
 async onModuleInit():Promise<void>{
 if(!this.requiresHardenedReads)return; // Legacy factory profile exists only for unchanged baseline regression.
 const row=(await this.pool.query("SELECT has_function_privilege(current_user,to_regprocedure('ms_b1_design.b2b_read_history(bytea,text,uuid,uuid,date,date,integer)'),'EXECUTE') ready")).rows[0];
 if(row?.ready!==true)throw Error('Reviewed read-scope migration required before API startup');
 }
 async session(hash:Buffer):Promise<SessionView>{return (await this.pool.query('SELECT ms_b1_design.b1b_session($1) AS result',[hash])).rows[0].result;}
 async legacyRead(hash:Buffer,kind:ResourceKind|'business',branch:string|null,page:PageQuery):Promise<unknown>{return(await this.pool.query('SELECT ms_b1_design.b1b_read($1,$2,$3,$4,$5,$6) AS result',[hash,kind,branch,page.limit,page.offset,page.sort])).rows[0].result;}
 async legacyCommand(hash:Buffer,csrf:Buffer,kind:ResourceKind|'session',id:string|null,branch:string|null,version:string|null,key:string,requestId:string,data:WriteDto|Record<string,never>):Promise<CommandResult>{return(await this.pool.query('SELECT ms_b1_design.b1b_command($1,$2,$3,$4,$5,$6,$7,$8,$9) AS result',[hash,csrf,kind,id,branch,version,key,requestId,data])).rows[0].result;}
 async read(hash:Buffer,kind:string,branch:string|null,staff:string|null,from:string,to:string,offset:number,view:'current'|'history'='current'):Promise<WorkforcePage>{
 const sql=view==='history'?'SELECT ms_b1_design.b2b_read_history($1,$2,$3,$4,$5,$6,$7) AS result':'SELECT ms_b1_design.b2b_read($1,$2,$3,$4,$5,$6,$7) AS result';
 return (await this.pool.query(sql,[hash,kind,branch,staff,from,to,offset])).rows[0].result;
 }
 async command(hash:Buffer,csrf:Buffer,op:Operation,branch:string|null,id:string|null,version:string,key:string,requestId:string,data:CommandData):Promise<WorkforceReceipt>{
 // Entire statement is one transaction. Only abort-proven40001/40P01 retries;
 // uncertain transport outcomes return503 and caller reuses the same durable key.
 for(let attempt=0;;attempt++){try{return(await this.pool.query('SELECT ms_b1_design.b2b_command($1,$2,$3,$4,$5,$6,$7,$8,$9) AS result',[hash,csrf,op,branch,id,version,key,requestId,data])).rows[0].result;}catch(e){if(attempt>=2||!['40001','40P01'].includes((e as {code?:string}).code??''))throw e;await new Promise(r=>setTimeout(r,20*(attempt+1)));}}
 }
 async onApplicationShutdown():Promise<void>{await this.pool.end();}
}
