SET search_path=pg_catalog;
-- Explicit response field allowlists: never expose tokens, identity evidence, actor IDs or SQL rows wholesale.
CREATE FUNCTION ms_b1_design.b2b_view(kind text,v jsonb) RETURNS jsonb
 LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE keys text[]; result jsonb;k text;
BEGIN
 keys:=CASE kind
 WHEN 'staff' THEN ARRAY['display_name','active']
 WHEN 'assignments' THEN ARRAY['staff_id','branch_id','valid_from','valid_to','active','voided_at']
 WHEN 'qualifications' THEN ARRAY['staff_id','service_id','active','verified_at']
 WHEN 'eligibilities' THEN ARRAY['staff_id','branch_id','offering_id','assignment_id','qualification_id','active']
 WHEN 'resources' THEN ARRAY['branch_id','kind','label','active']
 WHEN 'hours' THEN ARRAY['branch_id','iso_weekday','start_minute','end_minute','valid_from','valid_to']
 WHEN 'rules' THEN ARRAY['staff_id','branch_id','assignment_id','iso_weekday','start_minute','end_minute','valid_from','valid_to','service_id','qualification_id','offering_id']
 WHEN 'configuration' THEN ARRAY['branch_id','enabled','slot_stride_minutes','lead_minutes','horizon_days','hold_ttl_seconds','quote_ttl_seconds']
 WHEN 'timeoff' THEN ARRAY['staff_id','starts_at','ends_at','review_status','supersedes_id']
 WHEN 'closures' THEN ARRAY['branch_id','starts_at','ends_at','review_status','supersedes_id']
 ELSE ARRAY['staff_id','branch_id','assignment_id','schedule_rule_id','starts_at','ends_at','published','plan_id','local_date','time_zone','start_minute','end_minute','start_resolution','end_resolution'] END;
 result:=jsonb_build_object('id',v->'id','recordVersion',v->>'row_version','kind',kind,'archived',v->>'archived_at' IS NOT NULL);
 FOREACH k IN ARRAY keys LOOP result:=result||jsonb_build_object(k,v->k);END LOOP;
 IF kind IN ('rules','configuration') THEN result:=result||jsonb_build_object('configurationVersion',v->>'configuration_version');END IF;
 IF kind='shifts' THEN result:=result||jsonb_build_object('scheduleVersion',v->>'schedule_version');END IF;
 RETURN result;
END $$;

CREATE FUNCTION ms_b1_design.b2b_read(h bytea,query_kind text,branchid uuid,sid uuid,fromdate date,todate date,page_offset int)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;bid uuid;ownonly boolean:=false;items jsonb;permission text;
BEGIN
 a:=ms_b1_design.b1b_actor(h);bid:=(a->>'businessId')::uuid;
 IF query_kind IS NULL OR query_kind NOT IN ('context','staff','assignments','qualifications','eligibilities','rules','schedule','calendar','hours','resources','configuration','exceptions')
 OR page_offset IS NULL OR page_offset NOT BETWEEN 0 AND 10000 OR fromdate IS NULL OR todate IS NULL OR NOT isfinite(fromdate) OR NOT isfinite(todate)
 OR fromdate<'2020-01-01' OR todate>='2101-01-01' OR todate<=fromdate OR todate-fromdate>31 THEN PERFORM ms_b1_design.b2b_fail('INVALID_QUERY','MS422');END IF;
 permission:=CASE WHEN query_kind IN ('context','schedule','calendar','rules','hours','exceptions','configuration') THEN 'schedule.read'
 WHEN query_kind='resources' THEN 'resource.manage' ELSE 'staff.read' END;
 IF NOT ms_b1_design.b1b_can(a,permission,branchid) THEN
 IF query_kind='schedule' AND branchid IS NOT NULL AND sid IS NOT NULL AND ms_b1_design.b1b_can(a,'schedule.read.own',branchid)
 AND EXISTS(SELECT 1 FROM ms_b1_design.staff s JOIN ms_b1_design.staff_branch_assignment m ON m.business_id=s.business_id AND m.staff_id=s.id
 WHERE s.business_id=bid AND s.id=sid AND s.user_id=(a->>'userId')::uuid AND s.archived_at IS NULL AND m.branch_id=branchid AND m.voided_at IS NULL
 AND m.membership_period && daterange(fromdate,todate,'[)')) THEN ownonly:=true;
 ELSE PERFORM ms_b1_design.b2b_fail('FORBIDDEN','MS403');END IF;END IF;
 IF branchid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch WHERE business_id=bid AND id=branchid AND archived_at IS NULL) THEN PERFORM ms_b1_design.b2b_fail('NOT_FOUND','MS404');END IF;
 IF query_kind NOT IN ('context','staff','qualifications') AND branchid IS NULL THEN PERFORM ms_b1_design.b2b_fail('BRANCH_REQUIRED','MS422');END IF;
 IF query_kind='context' THEN items:='[]';ELSE
 SELECT coalesce(jsonb_agg(ms_b1_design.b2b_view(k,v) ORDER BY v->>'id'),'[]') INTO items FROM (SELECT k,v FROM (
 SELECT 'staff' k,to_jsonb(s) v FROM ms_b1_design.staff s WHERE query_kind='staff' AND s.business_id=bid AND s.archived_at IS NULL AND (sid IS NULL OR s.id=sid)
 AND (branchid IS NULL OR EXISTS(SELECT 1 FROM ms_b1_design.staff_branch_assignment m WHERE m.business_id=bid AND m.staff_id=s.id AND m.branch_id=branchid AND m.voided_at IS NULL))
 UNION ALL SELECT 'assignments',to_jsonb(m) FROM ms_b1_design.staff_branch_assignment m WHERE query_kind='assignments' AND m.business_id=bid AND m.branch_id=branchid AND (sid IS NULL OR m.staff_id=sid)
 UNION ALL SELECT 'qualifications',to_jsonb(q) FROM ms_b1_design.staff_service_eligibility q WHERE query_kind='qualifications' AND q.business_id=bid AND (sid IS NULL OR q.staff_id=sid)
 AND (branchid IS NULL OR EXISTS(SELECT 1 FROM ms_b1_design.staff_branch_assignment m WHERE m.business_id=bid AND m.staff_id=q.staff_id AND m.branch_id=branchid AND m.voided_at IS NULL))
 UNION ALL SELECT 'eligibilities',to_jsonb(e) FROM ms_b1_design.offering_staff_eligibility e WHERE query_kind='eligibilities' AND e.business_id=bid AND e.branch_id=branchid AND (sid IS NULL OR e.staff_id=sid)
 UNION ALL SELECT 'resources',to_jsonb(r) FROM ms_b1_design.resource r WHERE query_kind='resources' AND r.business_id=bid AND r.branch_id=branchid
 UNION ALL SELECT 'hours',to_jsonb(x) FROM ms_b1_design.branch_working_hours x WHERE query_kind='hours' AND x.business_id=bid AND x.branch_id=branchid
 UNION ALL SELECT 'rules',to_jsonb(x) FROM ms_b1_design.staff_schedule_rule x WHERE query_kind='rules' AND x.business_id=bid AND x.branch_id=branchid AND (sid IS NULL OR x.staff_id=sid)
 UNION ALL SELECT 'configuration',to_jsonb(x) FROM ms_b1_design.availability_configuration x WHERE query_kind='configuration' AND x.business_id=bid AND x.branch_id=branchid
 UNION ALL SELECT 'shifts',to_jsonb(x) FROM ms_b1_design.staff_shift x WHERE query_kind IN ('schedule','calendar') AND x.business_id=bid AND x.branch_id=branchid AND (sid IS NULL OR x.staff_id=sid)
 AND x.starts_at<(todate::timestamp AT TIME ZONE 'UTC')+interval '16 hours' AND x.ends_at>(fromdate::timestamp AT TIME ZONE 'UTC')-interval '16 hours'
 UNION ALL SELECT 'timeoff',to_jsonb(x) FROM ms_b1_design.staff_time_off x WHERE query_kind='exceptions' AND x.business_id=bid AND (sid IS NULL OR x.staff_id=sid)
 AND x.starts_at<(todate::timestamp AT TIME ZONE 'UTC')+interval '16 hours' AND x.ends_at>(fromdate::timestamp AT TIME ZONE 'UTC')-interval '16 hours'
 AND EXISTS(SELECT 1 FROM ms_b1_design.staff_branch_assignment m WHERE m.business_id=bid AND m.staff_id=x.staff_id AND m.branch_id=branchid AND m.voided_at IS NULL)
 UNION ALL SELECT 'closures',to_jsonb(x) FROM ms_b1_design.branch_closure x WHERE query_kind='exceptions' AND x.business_id=bid AND x.branch_id=branchid
 AND x.starts_at<(todate::timestamp AT TIME ZONE 'UTC')+interval '16 hours' AND x.ends_at>(fromdate::timestamp AT TIME ZONE 'UTC')-interval '16 hours'
 ) all_rows ORDER BY v->>'id' LIMIT 100 OFFSET page_offset) selected;
 END IF;
 RETURN jsonb_build_object('version',coalesce((SELECT w.version::text FROM ms_b1_design.workforce_calendar_revision w WHERE w.business_id=bid),'1'),
 'items',items,'limit',100,'offset',page_offset,'ownScheduleOnly',ownonly,'capacityReserved',false);
END $$;

-- Coordinate old configuration commands with B2B. Once calendar configuration exists,
-- timezone/activation/catalog edits require a separately reviewed reconciliation workflow.
ALTER FUNCTION ms_b1_design.b1b_command(bytea,bytea,text,uuid,uuid,bigint,text,uuid,jsonb) RENAME TO b2b_legacy_command;
CREATE FUNCTION ms_b1_design.b1b_command(h bytea,csrf bytea,kind text,entity uuid,branchid uuid,expected bigint,idem text,requestid uuid,d jsonb)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;bid uuid;
BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;
 PERFORM ms_b1_design.b2b_lock(bid);
 IF kind<>'session' AND (EXISTS(SELECT 1 FROM ms_b1_design.staff_schedule_rule WHERE business_id=bid)
 OR EXISTS(SELECT 1 FROM ms_b1_design.branch_working_hours WHERE business_id=bid)
 OR EXISTS(SELECT 1 FROM ms_b1_design.staff_shift WHERE business_id=bid)) THEN PERFORM ms_b1_design.b2b_fail('CALENDAR_RECONCILIATION_REQUIRED');END IF;
 RETURN ms_b1_design.b2b_legacy_command(h,csrf,kind,entity,branchid,expected,idem,requestid,d);
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA ms_b1_design FROM PUBLIC;
REVOKE ALL ON FUNCTION ms_b1_design.b2b_legacy_command(bytea,bytea,text,uuid,uuid,bigint,text,uuid,jsonb) FROM ms_b1b_api;
GRANT EXECUTE ON FUNCTION ms_b1_design.b1b_command(bytea,bytea,text,uuid,uuid,bigint,text,uuid,jsonb),
 ms_b1_design.b2b_command(bytea,bytea,text,uuid,uuid,bigint,text,uuid,jsonb),
 ms_b1_design.b2b_read(bytea,text,uuid,uuid,date,date,integer) TO ms_b1b_api;

-- Replace the formerly deferred empty configuration projection honestly. This is not availability.
CREATE OR REPLACE FUNCTION ms_b1_design.b1b_view(kind text, value jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 result:=jsonb_build_object('id',value->'id','version',value->>'row_version');
 IF kind='business' THEN RETURN result||jsonb_build_object('brandName',value->'brand_name','legalName',value->'legal_name','currency',value->'currency_code'); END IF;
 IF kind IN ('branch','service') THEN
  result:=result||jsonb_build_object('code',value->'code','displayName',value->'display_name','active',value->'active');
  IF kind='service' THEN RETURN result||jsonb_build_object('description',value->'description'); END IF;
  RETURN result||jsonb_build_object('address',value->'address','timeZone',value->'time_zone','bookable',value->'bookable','configurationVersion',value->>'configuration_version');
 END IF;
 RETURN result||jsonb_build_object('branchId',value->'branch_id','serviceId',value->'service_id','active',value->'active',
  'price',CASE WHEN value->>'price_rial' IS NULL THEN NULL ELSE jsonb_build_object('amountRial',value->>'price_rial','currency','IRR','unitVersion','IRR_RIAL_V1') END,
  'durationMinutes',value->'duration_minutes','bufferBeforeMinutes',value->'buffer_before_minutes','bufferAfterMinutes',value->'buffer_after_minutes',
  'configurationVersion',value->>'configuration_version','resourcesConfirmed',value->'resources_confirmed','eligibleStaffIds',coalesce((SELECT jsonb_agg(DISTINCT e.staff_id ORDER BY e.staff_id) FROM ms_b1_design.offering_staff_eligibility e JOIN ms_b1_design.staff s ON s.business_id=e.business_id AND s.id=e.staff_id JOIN ms_b1_design.staff_service_eligibility q ON q.business_id=e.business_id AND q.id=e.qualification_id JOIN ms_b1_design.staff_branch_assignment m ON m.business_id=e.business_id AND m.id=e.assignment_id WHERE e.business_id=(value->>'business_id')::uuid AND e.offering_id=(value->>'id')::uuid AND e.active AND e.archived_at IS NULL AND s.active AND s.archived_at IS NULL AND q.active AND q.verified_at IS NOT NULL AND q.archived_at IS NULL AND m.active AND m.voided_at IS NULL AND m.archived_at IS NULL),'[]'::jsonb),
  'resourceRequirements',coalesce((SELECT jsonb_agg(jsonb_build_object('kind',r.resource_kind,'quantity',r.quantity) ORDER BY r.resource_kind)
   FROM ms_b1_design.offering_resource_requirement r WHERE r.business_id=(value->>'business_id')::uuid
   AND r.offering_id=(value->>'id')::uuid AND r.archived_at IS NULL),'[]'::jsonb));
END $$;


