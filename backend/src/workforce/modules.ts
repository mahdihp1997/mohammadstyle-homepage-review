import 'reflect-metadata';
import {Body,Controller,Get,Post,Put,Param,Query,Req,Res,UseGuards,Module,Global,type DynamicModule} from '@nestjs/common';
import {AdminRepository} from '../admin/repository.js';
import {AdminCommands} from '../admin/modules.js';
import {ADMIN_OPTIONS,SessionGuard,evidence,type Request,type Response} from '../admin/security.js';
import {commandHeaders,uuid,invalid} from '../admin/contracts.js';
import {WorkforceRepository,type WorkforceOptions} from './repository.js';
import {validate,query,type Operation,type WorkforcePage} from './contracts.js';
export class WorkforceCommands {
 constructor(private readonly repository:WorkforceRepository){}
 async write(req:Request,res:Response,op:Operation,branch:string|null,id:string|null,d:unknown){const e=evidence(req),{key,version}=commandHeaders(req.headers,true);const result=await this.repository.command(e.hash,e.csrf,op,branch,id,version!,key,e.requestId,validate(op,d));res.status(result.status);res.setHeader('ETag','"'+result.body.version+'"');return result.body;}
 async read(req:Request,res:Response,kind:string,p:Record<string,string>,q:Record<string,unknown>):Promise<WorkforcePage>{const x=query(q);if(p.branchId&&x.branch&&p.branchId!==x.branch||p.id&&x.staff&&p.id!==x.staff)invalid();const branch=p.branchId?uuid(p.branchId):x.branch,staff=p.id?uuid(p.id):x.staff;const result=await this.repository.read(evidence(req).hash,kind,branch,staff,x.from,x.to,x.offset,x.view);res.setHeader('ETag','"'+result.version+'"');return result;}
}
@Controller('api/v1/admin') @UseGuards(SessionGuard)
export class WorkforceController {
 constructor(private readonly commands:WorkforceCommands){}
 @Post('staff') write0(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'staff.create',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Put('staff/:id') write1(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'staff.update',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Post('staff/:id/verified-identity') write2(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'staff.link',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Post('branches/:branchId/branch-assignments') write3(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'assignment.create',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Post('branches/:branchId/branch-assignments/:id/end') write4(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'assignment.close',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Post('staff/qualifications') write5(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'qualification.set',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Put('branches/:branchId/offering-staff-eligibility') write6(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'eligibility.set',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Post('branches/:branchId/resources') write7(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'resource.create',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Put('branches/:branchId/resources/:id') write8(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'resource.update',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Put('branches/:branchId/working-hours') write9(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'hours.replace',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Put('branches/:branchId/schedule-rules') write10(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'rule.create',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Post('branches/:branchId/schedule/publications') write11(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'schedule.publish',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Post('branches/:branchId/schedule/withdrawals') write12(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'schedule.withdraw',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Post('branches/:branchId/time-off') write13(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'timeoff.create',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Post('branches/:branchId/closures') write14(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'closure.create',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Post('branches/:branchId/time-off/:id/review') write15(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'timeoff.review',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Post('branches/:branchId/closures/:id/review') write16(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'closure.review',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Put('branches/:branchId/availability-configuration') write17(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Body() d:unknown){return this.commands.write(req,res,'configuration.set',p.branchId?uuid(p.branchId):null,p.id?uuid(p.id):null,d);}
 @Get('workforce/context') read0(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Query() q:Record<string,unknown>){return this.commands.read(req,res,'context',p,q);}
 @Get('staff') read1(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Query() q:Record<string,unknown>){return this.commands.read(req,res,'staff',p,q);}
 @Get('branches/:branchId/branch-assignments') read2(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Query() q:Record<string,unknown>){return this.commands.read(req,res,'assignments',p,q);}
 @Get('staff/qualifications') read3(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Query() q:Record<string,unknown>){return this.commands.read(req,res,'qualifications',p,q);}
 @Get('branches/:branchId/offering-staff-eligibility') read4(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Query() q:Record<string,unknown>){return this.commands.read(req,res,'eligibilities',p,q);}
 @Get('branches/:branchId/schedule-rules') read5(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Query() q:Record<string,unknown>){return this.commands.read(req,res,'rules',p,q);}
 @Get('branches/:branchId/staff/:id/schedule') read6(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Query() q:Record<string,unknown>){return this.commands.read(req,res,'schedule',p,q);}
 @Get('branches/:branchId/calendar') read7(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Query() q:Record<string,unknown>){return this.commands.read(req,res,'calendar',p,q);}
 @Get('branches/:branchId/working-hours') read8(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Query() q:Record<string,unknown>){return this.commands.read(req,res,'hours',p,q);}
 @Get('branches/:branchId/resources') read9(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Query() q:Record<string,unknown>){return this.commands.read(req,res,'resources',p,q);}
 @Get('branches/:branchId/availability-configuration') read10(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Query() q:Record<string,unknown>){return this.commands.read(req,res,'configuration',p,q);}
 @Get('branches/:branchId/exceptions') read11(@Req() req:Request,@Res({passthrough:true}) res:Response,@Param() p:Record<string,string>,@Query() q:Record<string,unknown>){return this.commands.read(req,res,'exceptions',p,q);}
}
@Global() @Module({}) export class WorkforceModule {
 static forLocal(options:WorkforceOptions):DynamicModule{return{module:WorkforceModule,controllers:[WorkforceController],providers:[{provide:ADMIN_OPTIONS,useValue:options},{provide:WorkforceRepository,useFactory:()=>new WorkforceRepository(options)},
 // Adapt the unchanged B1B controllers to this isolated cluster through fixed entry points.
 {provide:AdminRepository,useFactory:(r:WorkforceRepository)=>({session:r.session.bind(r),read:r.legacyRead.bind(r),command:r.legacyCommand.bind(r)}),inject:[WorkforceRepository]},
 {provide:AdminCommands,useFactory:(r:AdminRepository)=>new AdminCommands(r),inject:[AdminRepository]},SessionGuard,{provide:WorkforceCommands,useFactory:(r:WorkforceRepository)=>new WorkforceCommands(r),inject:[WorkforceRepository]}],exports:[ADMIN_OPTIONS,AdminRepository,AdminCommands,SessionGuard]};}
}
