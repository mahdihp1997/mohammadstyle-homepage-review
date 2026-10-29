SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.b2b_command(h bytea,csrf bytea,op text,branchid uuid,entity uuid,expected bigint,idem text,requestid uuid,d jsonb)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;bid uuid;uid uuid;permission text;global_command boolean;route text;digest bytea;prior ms_b1_design.idempotency_record;
 version bigint; target uuid; sid uuid;rid uuid;serviceid uuid;assignmentid uuid;qualificationid uuid;offeringid uuid;
 saved jsonb;result jsonb;items jsonb:='[]';part jsonb;day date;sm int;em int;zone text;st timestamptz;en timestamptz;
 r ms_b1_design.staff_schedule_rule;m ms_b1_design.staff_branch_assignment;ruleversion bigint;plan uuid;ids uuid[];n int;
BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;
 PERFORM ms_b1_design.b2b_validate(op,d);
 global_command:=op IN ('staff.create','staff.update','staff.link','qualification.set');
 IF global_command AND branchid IS NOT NULL OR NOT global_command AND branchid IS NULL THEN PERFORM ms_b1_design.b2b_fail('INVALID_SCOPE','MS422'); END IF;
 permission:=CASE WHEN op LIKE 'staff.%' THEN CASE WHEN op='staff.link' THEN 'staff.link' ELSE 'staff.manage' END
 WHEN op='qualification.set' THEN 'staff.qualify' WHEN op LIKE 'assignment.%' THEN 'staff.manage'
 WHEN op LIKE 'resource.%' THEN 'resource.manage' WHEN op='hours.replace' THEN 'branchhours.manage'
 WHEN op IN ('schedule.publish','schedule.withdraw') THEN 'schedule.publish'
 WHEN op IN ('timeoff.review','closure.review') THEN 'timeoff.approve' ELSE 'schedule.manage' END;
 IF NOT ms_b1_design.b1b_can(a,permission,branchid) THEN PERFORM ms_b1_design.b2b_fail('FORBIDDEN','MS403'); END IF;
 IF expected IS NULL OR expected<1 THEN PERFORM ms_b1_design.b2b_fail('VERSION_REQUIRED','MS412'); END IF;
 IF idem IS NULL OR idem !~ '^[A-Za-z0-9_-]{16,128}$' OR requestid IS NULL THEN PERFORM ms_b1_design.b2b_fail('INVALID_HEADERS','MS422'); END IF;
 PERFORM ms_b1_design.b2b_lock(bid);
 IF branchid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch WHERE business_id=bid AND id=branchid AND archived_at IS NULL) THEN PERFORM ms_b1_design.b2b_fail('NOT_FOUND','MS404'); END IF;
 route:='b2b:'||op||':'||coalesce(branchid::text,'global')||':'||coalesce(entity::text,'new');
 digest:=sha256(convert_to(jsonb_build_object('data',d,'version',expected)::text,'UTF8'));
 SELECT * INTO prior FROM ms_b1_design.idempotency_record WHERE business_id=bid AND actor_key=uid::text AND route_key=route AND idempotency_key=idem;
 IF FOUND THEN
 IF prior.request_hash<>digest OR prior.state<>'COMPLETE' OR prior.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b2b_fail('IDEMPOTENCY_CONFLICT'); END IF;
 RETURN prior.response_snapshot;END IF;
 INSERT INTO ms_b1_design.workforce_calendar_revision(business_id) VALUES(bid) ON CONFLICT DO NOTHING;
 SELECT w.version INTO version FROM ms_b1_design.workforce_calendar_revision w WHERE business_id=bid FOR UPDATE;
 IF version<>expected THEN PERFORM ms_b1_design.b2b_fail('STALE_CALENDAR_VERSION','MS412'); END IF;
 IF (op IN ('staff.update','staff.link','assignment.close','resource.update','timeoff.review','closure.review')) IS DISTINCT FROM (entity IS NOT NULL) THEN PERFORM ms_b1_design.b2b_fail('INVALID_TARGET','MS422'); END IF;
 target:=coalesce(entity,gen_random_uuid());sid:=(d->>'staffId')::uuid;
 IF sid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.staff WHERE business_id=bid AND id=sid AND archived_at IS NULL) THEN PERFORM ms_b1_design.b2b_fail('NOT_FOUND','MS404'); END IF;
 IF op='staff.create' THEN
 rid:=gen_random_uuid();INSERT INTO ms_b1_design.resource(id,business_id,kind,label,created_by) VALUES(rid,bid,'STAFF',d->>'displayName',uid);
 INSERT INTO ms_b1_design.staff(id,business_id,resource_id,display_name,created_by) VALUES(target,bid,rid,d->>'displayName',uid);
 ELSIF op IN ('staff.update','staff.link') THEN
 SELECT to_jsonb(s) INTO saved FROM ms_b1_design.staff s WHERE business_id=bid AND id=entity AND archived_at IS NULL FOR UPDATE;
 IF saved IS NULL THEN PERFORM ms_b1_design.b2b_fail('NOT_FOUND','MS404'); END IF;
 IF op='staff.link' THEN
 IF saved->>'user_id' IS NOT NULL THEN PERFORM ms_b1_design.b2b_fail('VERIFIED_IDENTITY_REQUIRED');END IF;
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.app_user u JOIN ms_b1_design.auth_identity i ON i.user_id=u.id
 WHERE u.id=(d->>'userId')::uuid AND u.status='ACTIVE' AND u.archived_at IS NULL AND i.verified_at IS NOT NULL
 AND EXISTS(SELECT 1 FROM ms_b1_design.user_role_assignment x WHERE x.user_id=u.id AND x.business_id=bid AND x.revoked_at IS NULL AND x.archived_at IS NULL)) THEN
 PERFORM ms_b1_design.b2b_fail('VERIFIED_IDENTITY_REQUIRED');END IF;
 UPDATE ms_b1_design.staff SET user_id=(d->>'userId')::uuid,identity_link_evidence_hash=sha256(convert_to(d->>'evidenceReference','UTF8')),row_version=row_version+1 WHERE id=entity;
 ELSE
 IF NOT(d->>'active')::boolean AND EXISTS(SELECT 1 FROM ms_b1_design.staff_shift WHERE business_id=bid AND staff_id=entity AND published AND archived_at IS NULL AND ends_at>clock_timestamp()) THEN PERFORM ms_b1_design.b2b_fail('PUBLISHED_SHIFT_REVIEW_REQUIRED');END IF;
 UPDATE ms_b1_design.staff SET display_name=d->>'displayName',active=(d->>'active')::boolean,row_version=row_version+1 WHERE id=entity;
 UPDATE ms_b1_design.resource SET label=d->>'displayName',active=(d->>'active')::boolean,row_version=row_version+1 WHERE id=(saved->>'resource_id')::uuid;
 END IF;
 ELSIF op='assignment.create' THEN
 INSERT INTO ms_b1_design.staff_branch_assignment(id,business_id,staff_id,branch_id,valid_from,valid_to,active,created_by)
 VALUES(target,bid,sid,branchid,(d->>'validFrom')::date,(d->>'validTo')::date,true,uid);
 ELSIF op='assignment.close' THEN
 SELECT * INTO m FROM ms_b1_design.staff_branch_assignment WHERE business_id=bid AND id=entity AND branch_id=branchid FOR UPDATE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b2b_fail('NOT_FOUND','MS404'); END IF;
 IF d->>'validTo' IS NULL OR m.valid_to IS NOT NULL OR m.voided_at IS NOT NULL OR (d->>'validTo')::date<=m.valid_from THEN PERFORM ms_b1_design.b2b_fail('INVALID_MEMBERSHIP_END');END IF;
 SELECT time_zone INTO zone FROM ms_b1_design.branch WHERE id=branchid AND business_id=bid;
 IF EXISTS(SELECT 1 FROM ms_b1_design.staff_shift x WHERE x.business_id=bid AND x.assignment_id=entity AND x.published AND x.archived_at IS NULL
 AND x.ends_at>ms_b1_design.b2b_local_instant((d->>'validTo')::date::timestamp,zone,'reject')) THEN PERFORM ms_b1_design.b2b_fail('MEMBERSHIP_SHIFT_CONFLICT');END IF;
 -- Keep active=true until exclusive end; active is administrative eligibility, not employment-now inference.
 UPDATE ms_b1_design.staff_branch_assignment SET valid_to=(d->>'validTo')::date,row_version=row_version+1 WHERE id=entity;
 ELSIF op='qualification.set' THEN
 serviceid:=(d->>'serviceId')::uuid;
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.service WHERE business_id=bid AND id=serviceid AND archived_at IS NULL) THEN PERFORM ms_b1_design.b2b_fail('NOT_FOUND','MS404');END IF;
 IF NOT(d->>'active')::boolean AND EXISTS(SELECT 1 FROM ms_b1_design.staff_shift WHERE business_id=bid AND staff_id=sid AND published AND archived_at IS NULL AND ends_at>clock_timestamp()) THEN PERFORM ms_b1_design.b2b_fail('PUBLISHED_SHIFT_REVIEW_REQUIRED');END IF;
 INSERT INTO ms_b1_design.staff_service_eligibility(id,business_id,staff_id,service_id,verified_at,active,created_by,verification_evidence_hash,verified_by)
 VALUES(target,bid,sid,serviceid,clock_timestamp(),(d->>'active')::boolean,uid,sha256(convert_to(d->>'evidenceReference','UTF8')),uid)
 ON CONFLICT(business_id,staff_id,service_id) DO UPDATE SET verified_at=clock_timestamp(),active=(d->>'active')::boolean,verification_evidence_hash=excluded.verification_evidence_hash,verified_by=uid,row_version=staff_service_eligibility.row_version+1 RETURNING id INTO target;
 ELSIF op='eligibility.set' THEN
 SELECT * INTO m FROM ms_b1_design.staff_branch_assignment WHERE business_id=bid AND id=(d->>'assignmentId')::uuid AND branch_id=branchid AND voided_at IS NULL AND archived_at IS NULL;
 IF NOT FOUND THEN PERFORM ms_b1_design.b2b_fail('NOT_FOUND','MS404');END IF;sid:=m.staff_id;offeringid:=(d->>'offeringId')::uuid;qualificationid:=(d->>'qualificationId')::uuid;
 SELECT service_id INTO serviceid FROM ms_b1_design.staff_service_eligibility WHERE business_id=bid AND id=qualificationid AND staff_id=sid AND active AND archived_at IS NULL;
 IF NOT FOUND THEN PERFORM ms_b1_design.b2b_fail('QUALIFICATION_REQUIRED');END IF;
 IF NOT(d->>'active')::boolean AND EXISTS(SELECT 1 FROM ms_b1_design.staff_shift WHERE business_id=bid AND staff_id=sid AND branch_id=branchid AND published AND archived_at IS NULL AND ends_at>clock_timestamp()) THEN PERFORM ms_b1_design.b2b_fail('PUBLISHED_SHIFT_REVIEW_REQUIRED');END IF;
 INSERT INTO ms_b1_design.offering_staff_eligibility(id,business_id,offering_id,branch_id,service_id,staff_id,assignment_id,qualification_id,active,created_by)
 VALUES(target,bid,offeringid,branchid,serviceid,sid,m.id,qualificationid,(d->>'active')::boolean,uid)
 ON CONFLICT(business_id,offering_id,staff_id,assignment_id) DO UPDATE SET active=(d->>'active')::boolean,row_version=offering_staff_eligibility.row_version+1 RETURNING id INTO target;
 ELSIF op='resource.create' THEN
 IF d->>'kind' NOT IN ('CHAIR','ROOM','DEVICE') THEN PERFORM ms_b1_design.b2b_fail('PHYSICAL_KIND_REQUIRED','MS422');END IF;
 INSERT INTO ms_b1_design.resource(id,business_id,branch_id,kind,label,active,created_by) VALUES(target,bid,branchid,d->>'kind',d->>'label',(d->>'active')::boolean,uid);
 ELSIF op='resource.update' THEN
 UPDATE ms_b1_design.resource SET label=d->>'label',active=(d->>'active')::boolean,row_version=row_version+1 WHERE business_id=bid AND id=entity AND branch_id=branchid AND kind<>'STAFF' AND archived_at IS NULL;
 IF NOT FOUND THEN PERFORM ms_b1_design.b2b_fail('NOT_FOUND','MS404');END IF;
 ELSIF op='hours.replace' THEN
 IF EXISTS(SELECT 1 FROM ms_b1_design.staff_shift WHERE business_id=bid AND branch_id=branchid AND published AND archived_at IS NULL AND ends_at>clock_timestamp()) THEN PERFORM ms_b1_design.b2b_fail('PUBLISHED_SHIFT_REVIEW_REQUIRED');END IF;
 IF jsonb_array_length(d->'segments')<1 THEN PERFORM ms_b1_design.b2b_fail('EMPTY_HOURS','MS422');END IF;
 UPDATE ms_b1_design.branch_working_hours SET archived_at=clock_timestamp(),row_version=row_version+1 WHERE business_id=bid AND branch_id=branchid AND archived_at IS NULL;
 FOR part IN SELECT value FROM jsonb_array_elements(d->'segments') LOOP
 PERFORM ms_b1_design.b2b_validate('rule.create',part||jsonb_build_object('staffId',gen_random_uuid(),'assignmentId',gen_random_uuid(),'qualificationId',gen_random_uuid(),'offeringId',NULL));
 INSERT INTO ms_b1_design.branch_working_hours(business_id,branch_id,iso_weekday,start_minute,end_minute,valid_from,valid_to,created_by)
 VALUES(bid,branchid,(part->>'isoWeekday')::int,(part->>'startMinute')::int,(part->>'endMinute')::int,(part->>'validFrom')::date,(part->>'validTo')::date,uid);
 END LOOP;
 ELSIF op='rule.create' THEN
 SELECT * INTO m FROM ms_b1_design.staff_branch_assignment WHERE business_id=bid AND id=(d->>'assignmentId')::uuid AND staff_id=sid AND branch_id=branchid AND active AND voided_at IS NULL AND archived_at IS NULL;
 IF NOT FOUND THEN PERFORM ms_b1_design.b2b_fail('MEMBERSHIP_REQUIRED');END IF;
 SELECT service_id INTO serviceid FROM ms_b1_design.staff_service_eligibility WHERE business_id=bid AND id=(d->>'qualificationId')::uuid AND staff_id=sid AND active AND archived_at IS NULL;
 IF NOT FOUND THEN PERFORM ms_b1_design.b2b_fail('QUALIFICATION_REQUIRED');END IF;
 INSERT INTO ms_b1_design.staff_schedule_rule(id,business_id,staff_id,branch_id,assignment_id,iso_weekday,start_minute,end_minute,valid_from,valid_to,configuration_version,service_id,qualification_id,offering_id,created_by)
 VALUES(target,bid,sid,branchid,m.id,(d->>'isoWeekday')::int,(d->>'startMinute')::int,(d->>'endMinute')::int,(d->>'validFrom')::date,(d->>'validTo')::date,version+1,serviceid,(d->>'qualificationId')::uuid,(d->>'offeringId')::uuid,uid);
 ELSIF op IN ('schedule.publish','schedule.withdraw') THEN
 ids:=ARRAY(SELECT value::uuid FROM jsonb_array_elements_text(CASE WHEN op='schedule.publish' THEN d->'replaces' ELSE d->'shiftIds' END));
 IF cardinality(ids)<>(SELECT count(DISTINCT x) FROM unnest(ids) x) THEN PERFORM ms_b1_design.b2b_fail('DUPLICATE_SHIFT','MS422');END IF;
 SELECT count(*) INTO n FROM ms_b1_design.staff_shift WHERE business_id=bid AND id=ANY(ids) AND staff_id=sid AND branch_id=branchid AND published AND archived_at IS NULL AND starts_at>clock_timestamp();
 IF n<>cardinality(ids) OR (op='schedule.withdraw' AND n=0) THEN PERFORM ms_b1_design.b2b_fail('REVIEW_SET_MISMATCH');END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.staff_shift x WHERE x.business_id=bid AND x.plan_id IS NOT NULL AND x.published AND x.archived_at IS NULL
 AND x.plan_id IN(SELECT y.plan_id FROM ms_b1_design.staff_shift y WHERE y.business_id=bid AND y.id=ANY(ids)) AND NOT(x.id=ANY(ids))) THEN
 PERFORM ms_b1_design.b2b_fail('REVIEW_SET_MISMATCH');END IF;
 UPDATE ms_b1_design.staff_shift SET archived_at=clock_timestamp(),row_version=row_version+1 WHERE id=ANY(ids) AND business_id=bid;
 IF op='schedule.publish' THEN
 IF jsonb_array_length(d->'segments') NOT BETWEEN 1 AND 62 THEN PERFORM ms_b1_design.b2b_fail('EMPTY_PLAN','MS422');END IF;
 SELECT time_zone INTO zone FROM ms_b1_design.branch WHERE id=branchid AND business_id=bid;plan:=target;
 FOR part IN SELECT value FROM jsonb_array_elements(d->'segments') LOOP
 IF jsonb_typeof(part)<>'object' OR (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(part) k) IS DISTINCT FROM ARRAY['date','endResolution','ruleId','ruleVersion','startResolution'] THEN PERFORM ms_b1_design.b2b_fail('INVALID_SEGMENT','MS422');END IF;
 IF part->>'date' !~ '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' OR part->>'ruleVersion' !~ '^[1-9][0-9]{0,18}$' THEN PERFORM ms_b1_design.b2b_fail('INVALID_SEGMENT','MS422');END IF;
 SELECT * INTO r FROM ms_b1_design.staff_schedule_rule WHERE business_id=bid AND id=(part->>'ruleId')::uuid AND staff_id=sid AND branch_id=branchid;
 IF NOT FOUND OR r.configuration_version<>(part->>'ruleVersion')::bigint THEN PERFORM ms_b1_design.b2b_fail('STALE_RULE','MS412');END IF;
 day:=(part->>'date')::date;sm:=r.start_minute;em:=r.end_minute;
 st:=ms_b1_design.b2b_local_instant(day::timestamp+make_interval(mins=>sm),zone,part->>'startResolution');
 en:=ms_b1_design.b2b_local_instant(day::timestamp+make_interval(mins=>em),zone,part->>'endResolution');
 IF st<=clock_timestamp() OR en<=st OR en-st>interval '26 hours' THEN PERFORM ms_b1_design.b2b_fail('INVALID_SHIFT_WINDOW','MS422');END IF;
 PERFORM ms_b1_design.b2b_check_shift(bid,sid,branchid,r.assignment_id,r.id,day,sm,em,zone,st,en);
 rid:=gen_random_uuid();INSERT INTO ms_b1_design.staff_shift(id,business_id,staff_id,branch_id,assignment_id,schedule_rule_id,starts_at,ends_at,published,schedule_version,plan_id,local_date,time_zone,start_minute,end_minute,start_resolution,end_resolution,created_by)
 VALUES(rid,bid,sid,branchid,r.assignment_id,r.id,st,en,true,version+1,plan,day,zone,sm,em,part->>'startResolution',part->>'endResolution',uid);
 items:=items||jsonb_build_array(jsonb_build_object('id',rid,'startsAt',st,'endsAt',en,'date',day,'timeZone',zone,'ruleId',r.id,'ruleVersion',r.configuration_version::text));
 END LOOP;
 -- Explicit overnight edge segments must be paired in this same atomic plan.
 IF (d->>'overnight')::boolean AND EXISTS(SELECT 1 FROM ms_b1_design.staff_shift x WHERE x.plan_id=plan AND x.business_id=bid AND
 ((x.end_minute=1440 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.staff_shift y WHERE y.plan_id=plan AND y.assignment_id=x.assignment_id AND y.local_date=x.local_date+1 AND y.start_minute=0 AND y.starts_at=x.ends_at))
 OR (x.start_minute=0 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.staff_shift y WHERE y.plan_id=plan AND y.assignment_id=x.assignment_id AND y.local_date=x.local_date-1 AND y.end_minute=1440 AND y.ends_at=x.starts_at)))) THEN PERFORM ms_b1_design.b2b_fail('OVERNIGHT_PLAN_INCOMPLETE');END IF;
 IF (SELECT max(local_date)-min(local_date) FROM ms_b1_design.staff_shift WHERE business_id=bid AND plan_id=plan)>30 THEN PERFORM ms_b1_design.b2b_fail('PLAN_HORIZON_EXCEEDED','MS422');END IF;
 END IF;
 ELSIF op IN ('timeoff.create','closure.create') THEN
 IF (d->>'endsAt')::timestamptz<=(d->>'startsAt')::timestamptz OR (d->>'endsAt')::timestamptz-(d->>'startsAt')::timestamptz>interval '366 days' THEN PERFORM ms_b1_design.b2b_fail('INVALID_EXCEPTION_WINDOW','MS422');END IF;
 IF op='timeoff.create' THEN
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.staff_branch_assignment WHERE business_id=bid AND staff_id=sid AND branch_id=branchid AND voided_at IS NULL AND archived_at IS NULL) THEN PERFORM ms_b1_design.b2b_fail('MEMBERSHIP_REQUIRED');END IF;
 SELECT resource_id INTO rid FROM ms_b1_design.staff WHERE business_id=bid AND id=sid;
 INSERT INTO ms_b1_design.staff_time_off(id,business_id,staff_id,resource_id,starts_at,ends_at,reason_code,review_status,created_by)
 VALUES(target,bid,sid,rid,(d->>'startsAt')::timestamptz,(d->>'endsAt')::timestamptz,d->>'reason','REQUESTED',uid);
 ELSE INSERT INTO ms_b1_design.branch_closure(id,business_id,branch_id,starts_at,ends_at,reason_code,review_status,created_by)
 VALUES(target,bid,branchid,(d->>'startsAt')::timestamptz,(d->>'endsAt')::timestamptz,d->>'reason','REQUESTED',uid);END IF;
 ELSIF op IN ('timeoff.review','closure.review') THEN
 IF op='timeoff.review' THEN SELECT to_jsonb(x) INTO saved FROM ms_b1_design.staff_time_off x WHERE business_id=bid AND id=entity FOR UPDATE;
 ELSE SELECT to_jsonb(x) INTO saved FROM ms_b1_design.branch_closure x WHERE business_id=bid AND id=entity AND branch_id=branchid FOR UPDATE;END IF;
 IF saved IS NULL OR saved->>'review_status' NOT IN ('REQUESTED','LEGACY_UNREVIEWED') OR saved->>'archived_at' IS NOT NULL THEN PERFORM ms_b1_design.b2b_fail('NOT_REVIEWABLE');END IF;
 -- Staff time off is global: branch managers may request it, approval needs business-wide authority.
 IF op='timeoff.review' AND NOT ms_b1_design.b1b_can(a,'timeoff.approve',NULL) THEN PERFORM ms_b1_design.b2b_fail('GLOBAL_APPROVAL_REQUIRED','MS403');END IF;
 sid:=(saved->>'staff_id')::uuid;st:=(saved->>'starts_at')::timestamptz;en:=(saved->>'ends_at')::timestamptz;
 IF (d->>'approve')::boolean AND EXISTS(SELECT 1 FROM ms_b1_design.staff_shift x WHERE x.business_id=bid AND x.published AND x.archived_at IS NULL AND x.starts_at<en AND x.ends_at>st AND
 (op='timeoff.review' AND x.staff_id=sid OR op='closure.review' AND x.branch_id=branchid)) THEN PERFORM ms_b1_design.b2b_fail('EXCEPTION_SHIFT_CONFLICT');END IF;
 target:=gen_random_uuid();
 IF op='timeoff.review' THEN INSERT INTO ms_b1_design.staff_time_off(id,business_id,staff_id,resource_id,starts_at,ends_at,reason_code,approved_by,review_status,supersedes_id,created_by)
 VALUES(target,bid,sid,(saved->>'resource_id')::uuid,st,en,d->>'reason',uid,CASE WHEN(d->>'approve')::boolean THEN 'APPROVED' ELSE 'REJECTED' END,entity,uid);
 ELSE INSERT INTO ms_b1_design.branch_closure(id,business_id,branch_id,starts_at,ends_at,reason_code,approved_by,review_status,supersedes_id,created_by)
 VALUES(target,bid,branchid,st,en,d->>'reason',uid,CASE WHEN(d->>'approve')::boolean THEN 'APPROVED' ELSE 'REJECTED' END,entity,uid);END IF;
 ELSIF op='configuration.set' THEN
 INSERT INTO ms_b1_design.availability_configuration(id,business_id,branch_id,slot_stride_minutes,lead_minutes,horizon_days,hold_ttl_seconds,quote_ttl_seconds,created_by)
 VALUES(target,bid,branchid,(d->>'slotStrideMinutes')::int,(d->>'leadMinutes')::int,(d->>'horizonDays')::int,(d->>'holdTtlSeconds')::int,(d->>'quoteTtlSeconds')::int,uid)
 ON CONFLICT(business_id,branch_id) DO UPDATE SET slot_stride_minutes=excluded.slot_stride_minutes,lead_minutes=excluded.lead_minutes,horizon_days=excluded.horizon_days,hold_ttl_seconds=excluded.hold_ttl_seconds,quote_ttl_seconds=excluded.quote_ttl_seconds,row_version=availability_configuration.row_version+1,configuration_version=availability_configuration.configuration_version+1 RETURNING id INTO target;
 END IF;
 UPDATE ms_b1_design.workforce_calendar_revision w SET version=w.version+1 WHERE w.business_id=bid RETURNING w.version INTO version;
 IF branchid IS NOT NULL THEN UPDATE ms_b1_design.branch SET schedule_version=schedule_version+1 WHERE business_id=bid AND id=branchid;END IF;
 result:=jsonb_build_object('status',200,'body',jsonb_build_object('id',target,'version',version::text,'operation',op,'items',items));
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,branch_id,action,target_type,target_id,request_id,redacted_change,created_by)
 VALUES(bid,uid,branchid,op,'workforce',target,requestid,jsonb_build_object('calendarVersion',version::text,'fields',(SELECT jsonb_agg(k ORDER BY k) FROM jsonb_object_keys(d) k),
 'active',d->'active','approve',d->'approve','reasonHash',encode(sha256(convert_to(d->>'reason','UTF8')),'hex'),
 'evidenceHash',encode(sha256(convert_to(d->>'evidenceReference','UTF8')),'hex'),'reviewedShiftIds',coalesce(d->'replaces',d->'shiftIds'),
 'membershipEnd',d->'validTo','staffId',sid,'createdShiftIds',items),uid);
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at,created_by)
 VALUES(bid,'workforce',target,version,'admin.'||op,1,jsonb_build_object('id',target,'calendarVersion',version::text),clock_timestamp(),uid);
 INSERT INTO ms_b1_design.idempotency_record(business_id,actor_key,route_key,idempotency_key,request_hash,state,response_code,response_snapshot,expires_at,created_by)
 VALUES(bid,uid::text,route,idem,digest,'COMPLETE',200,result,clock_timestamp()+interval '24 hours',uid);
 RETURN result;
END $$;
