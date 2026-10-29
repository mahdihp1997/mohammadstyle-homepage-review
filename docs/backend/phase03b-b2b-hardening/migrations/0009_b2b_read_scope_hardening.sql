-- Read-only boundary hardening.0001..0008 and all application rows are preserved.
SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.b2h_membership_window(m ms_b1_design.staff_branch_assignment,fromdate date,todate date,zone text,history boolean,asof timestamptz)
 RETURNS tstzrange LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE lo date;hi date;st timestamptz;en timestamptz;
BEGIN
 IF m.voided_at IS NOT NULL OR NOT(m.membership_period && daterange(fromdate,todate,'[)')) THEN RETURN NULL;END IF;
 IF NOT m.active OR m.archived_at IS NOT NULL THEN
  -- Deactivation/archive alone supplies no reviewed temporal end. Do not guess one.
  IF NOT history OR m.valid_to IS NULL THEN RETURN NULL;END IF;
  IF ms_b1_design.b2b_local_instant(m.valid_to::timestamp,zone,'reject')>asof THEN RETURN NULL;END IF;
 END IF;
 lo:=greatest(m.valid_from,fromdate);hi:=least(coalesce(m.valid_to,todate),todate);
 IF hi<=lo THEN RETURN NULL;END IF;
 st:=ms_b1_design.b2b_local_instant(lo::timestamp,zone,'reject');
 en:=ms_b1_design.b2b_local_instant(hi::timestamp,zone,'reject');
 IF en<=st THEN RETURN NULL;END IF;
 RETURN tstzrange(st,en,'[)');
 -- Ambiguous/nonexistent midnight cannot silently confer access.
 EXCEPTION WHEN SQLSTATE 'MS422' THEN RETURN NULL;
END $$;

CREATE FUNCTION ms_b1_design.b2h_read(h bytea,query_kind text,branchid uuid,sid uuid,fromdate date,todate date,page_offset int,history boolean)
 RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE a jsonb;bid uuid;ownonly boolean:=false;items jsonb;permission text;zone text:='UTC';query_window tstzrange;asof timestamptz:=statement_timestamp();global_staff boolean;
BEGIN
 a:=ms_b1_design.b1b_actor(h);bid:=(a->>'businessId')::uuid;
 IF query_kind IS NULL OR query_kind NOT IN ('context','staff','assignments','qualifications','eligibilities','rules','schedule','calendar','hours','resources','configuration','exceptions')
 OR history IS NULL OR page_offset IS NULL OR page_offset NOT BETWEEN 0 AND 10000 OR fromdate IS NULL OR todate IS NULL OR NOT isfinite(fromdate) OR NOT isfinite(todate)
 OR fromdate<'2020-01-01' OR todate>='2101-01-01' OR todate<=fromdate OR todate-fromdate>31 THEN PERFORM ms_b1_design.b2b_fail('INVALID_QUERY','MS422');END IF;
 IF history AND query_kind NOT IN ('assignments','eligibilities','rules','schedule','calendar','hours','exceptions') THEN PERFORM ms_b1_design.b2b_fail('INVALID_QUERY','MS422');END IF;
 permission:=CASE WHEN history THEN CASE WHEN query_kind IN ('assignments','eligibilities') THEN 'staff.history.read' ELSE 'schedule.history.read' END
 WHEN query_kind IN ('context','schedule','calendar','rules','hours','exceptions','configuration') THEN 'schedule.read'
 WHEN query_kind='resources' THEN 'resource.manage' ELSE 'staff.read' END;
 IF NOT ms_b1_design.b1b_can(a,permission,branchid) THEN
  IF NOT history AND query_kind='schedule' AND branchid IS NOT NULL AND sid IS NOT NULL AND ms_b1_design.b1b_can(a,'schedule.read.own',branchid)
  AND EXISTS(SELECT 1 FROM ms_b1_design.staff s JOIN ms_b1_design.staff_branch_assignment m ON m.business_id=s.business_id AND m.staff_id=s.id
  JOIN ms_b1_design.branch b ON b.business_id=m.business_id AND b.id=m.branch_id
  WHERE s.business_id=bid AND s.id=sid AND s.user_id=(a->>'userId')::uuid AND s.archived_at IS NULL AND m.branch_id=branchid
  AND ms_b1_design.b2h_membership_window(m,fromdate,todate,b.time_zone,false,asof) IS NOT NULL) THEN ownonly:=true;
  ELSE PERFORM ms_b1_design.b2b_fail('FORBIDDEN','MS403');END IF;
 END IF;
 IF branchid IS NOT NULL THEN
  -- Authorized writes already lock branches before changing membership/timezone.
  -- Hold this scope stable through clipping/projection; no new mutation lock order.
  SELECT b.time_zone INTO zone FROM ms_b1_design.branch b WHERE b.business_id=bid AND b.id=branchid AND b.archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN PERFORM ms_b1_design.b2b_fail('NOT_FOUND','MS404');END IF;
 END IF;
 IF (query_kind NOT IN ('context','staff','qualifications') OR history) AND branchid IS NULL THEN PERFORM ms_b1_design.b2b_fail('BRANCH_REQUIRED','MS422');END IF;
 query_window:=tstzrange(ms_b1_design.b2b_local_instant(fromdate::timestamp,zone,'reject'),ms_b1_design.b2b_local_instant(todate::timestamp,zone,'reject'),'[)');
 global_staff:=ms_b1_design.b1b_can(a,'staff.read',NULL);
 IF query_kind='context' THEN items:='[]';ELSE
 WITH memberships AS MATERIALIZED (
  SELECT m.id,m.staff_id,ms_b1_design.b2h_membership_window(m,fromdate,todate,zone,history,asof) applicable,
   (m.active AND m.archived_at IS NULL AND m.voided_at IS NULL AND m.membership_period @> ((asof AT TIME ZONE zone)::date)) live_now
  FROM ms_b1_design.staff_branch_assignment m WHERE m.business_id=bid AND m.branch_id=branchid
 ), all_rows AS (
  SELECT 'staff' k,to_jsonb(s) v,NULL::uuid assignment_id FROM ms_b1_design.staff s
  WHERE query_kind='staff' AND s.business_id=bid AND s.archived_at IS NULL AND (sid IS NULL OR s.id=sid)
  AND (branchid IS NULL OR EXISTS(SELECT 1 FROM memberships m WHERE m.staff_id=s.id AND m.applicable IS NOT NULL AND (global_staff OR m.live_now)))
  UNION ALL SELECT 'assignments',to_jsonb(m),NULL::uuid FROM ms_b1_design.staff_branch_assignment m
  WHERE query_kind='assignments' AND m.business_id=bid AND m.branch_id=branchid AND (sid IS NULL OR m.staff_id=sid)
  AND ms_b1_design.b2h_membership_window(m,fromdate,todate,zone,history,asof) IS NOT NULL
  UNION ALL SELECT 'qualifications',to_jsonb(q),NULL::uuid FROM ms_b1_design.staff_service_eligibility q
  WHERE query_kind='qualifications' AND q.business_id=bid AND (sid IS NULL OR q.staff_id=sid) AND q.archived_at IS NULL
  AND (branchid IS NULL OR EXISTS(SELECT 1 FROM memberships m WHERE m.staff_id=q.staff_id AND m.applicable IS NOT NULL AND (global_staff OR m.live_now)))
  UNION ALL SELECT 'eligibilities',to_jsonb(e),NULL::uuid FROM ms_b1_design.offering_staff_eligibility e
  WHERE query_kind='eligibilities' AND e.business_id=bid AND e.branch_id=branchid AND (sid IS NULL OR e.staff_id=sid)
  AND (history OR e.archived_at IS NULL) AND EXISTS(SELECT 1 FROM memberships m WHERE m.id=e.assignment_id AND m.applicable IS NOT NULL)
  UNION ALL SELECT 'resources',to_jsonb(x),NULL::uuid FROM ms_b1_design.resource x WHERE query_kind='resources' AND x.business_id=bid AND x.branch_id=branchid AND x.archived_at IS NULL
  UNION ALL SELECT 'hours',to_jsonb(x),NULL::uuid FROM ms_b1_design.branch_working_hours x WHERE query_kind='hours' AND x.business_id=bid AND x.branch_id=branchid
  AND (history OR x.archived_at IS NULL) AND daterange(x.valid_from,x.valid_to,'[)') && daterange(fromdate,todate,'[)')
  UNION ALL SELECT 'rules',to_jsonb(x),NULL::uuid FROM ms_b1_design.staff_schedule_rule x WHERE query_kind='rules' AND x.business_id=bid AND x.branch_id=branchid AND (sid IS NULL OR x.staff_id=sid)
  AND (history OR x.archived_at IS NULL) AND daterange(x.valid_from,x.valid_to,'[)') && daterange(fromdate,todate,'[)')
  AND EXISTS(SELECT 1 FROM memberships m WHERE m.id=x.assignment_id AND m.applicable IS NOT NULL)
  UNION ALL SELECT 'configuration',to_jsonb(x),NULL::uuid FROM ms_b1_design.availability_configuration x WHERE query_kind='configuration' AND x.business_id=bid AND x.branch_id=branchid AND x.archived_at IS NULL
  UNION ALL SELECT 'shifts',to_jsonb(x),NULL::uuid FROM ms_b1_design.staff_shift x WHERE query_kind IN ('schedule','calendar') AND x.business_id=bid AND x.branch_id=branchid AND (sid IS NULL OR x.staff_id=sid)
  AND (history OR (x.published AND x.archived_at IS NULL)) AND x.working_period && query_window
  AND (NOT ownonly OR EXISTS(SELECT 1 FROM memberships m WHERE m.id=x.assignment_id AND m.applicable @> x.working_period))
  UNION ALL SELECT 'timeoff',to_jsonb(x)||jsonb_build_object('starts_at',lower(clip.period),'ends_at',upper(clip.period)),m.id
  FROM ms_b1_design.staff_time_off x JOIN memberships m ON m.staff_id=x.staff_id AND m.applicable IS NOT NULL
  CROSS JOIN LATERAL (SELECT tstzrange(x.starts_at,x.ends_at,'[)') * m.applicable period) clip
  WHERE query_kind='exceptions' AND x.business_id=bid AND (sid IS NULL OR x.staff_id=sid) AND (history OR x.archived_at IS NULL) AND NOT isempty(clip.period)
  UNION ALL SELECT 'closures',to_jsonb(x),NULL::uuid FROM ms_b1_design.branch_closure x WHERE query_kind='exceptions' AND x.business_id=bid AND x.branch_id=branchid
  AND (history OR x.archived_at IS NULL) AND tstzrange(x.starts_at,x.ends_at,'[)') && query_window
 ), projected AS (
  SELECT k,v,assignment_id,ms_b1_design.b2b_view(k,v)||CASE
   WHEN k='shifts' THEN jsonb_build_object('evidenceState',CASE WHEN v->>'archived_at' IS NOT NULL THEN CASE WHEN(v->>'published')::boolean THEN 'WITHDRAWN' ELSE 'ARCHIVED_DRAFT' END WHEN(v->>'published')::boolean THEN 'PUBLISHED' ELSE 'DRAFT' END)
   WHEN k='timeoff' THEN jsonb_build_object('scopeAssignmentId',assignment_id,'intervalScope','BRANCH_MEMBERSHIP_AND_QUERY') ELSE '{}'::jsonb END view
  FROM all_rows ORDER BY k,v->>'id',assignment_id,v->>'starts_at' LIMIT 100 OFFSET page_offset
 ) SELECT coalesce(jsonb_agg(view ORDER BY k,v->>'id',assignment_id,v->>'starts_at'),'[]') INTO items FROM projected;
 END IF;
 RETURN jsonb_build_object('version',coalesce((SELECT w.version::text FROM ms_b1_design.workforce_calendar_revision w WHERE w.business_id=bid),'1'),
 'items',items,'limit',100,'offset',page_offset,'ownScheduleOnly',ownonly,'capacityReserved',false,'projection',CASE WHEN history THEN 'history' ELSE 'current' END);
END $$;

CREATE OR REPLACE FUNCTION ms_b1_design.b2b_read(h bytea,query_kind text,branchid uuid,sid uuid,fromdate date,todate date,page_offset int)
 RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ms_b1_design.b2h_read(h,query_kind,branchid,sid,fromdate,todate,page_offset,false)
$$;
CREATE FUNCTION ms_b1_design.b2b_read_history(h bytea,query_kind text,branchid uuid,sid uuid,fromdate date,todate date,page_offset int)
 RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT ms_b1_design.b2h_read(h,query_kind,branchid,sid,fromdate,todate,page_offset,true)
$$;
REVOKE ALL ON FUNCTION ms_b1_design.b2h_membership_window(ms_b1_design.staff_branch_assignment,date,date,text,boolean,timestamptz),
 ms_b1_design.b2h_read(bytea,text,uuid,uuid,date,date,integer,boolean),ms_b1_design.b2b_read_history(bytea,text,uuid,uuid,date,date,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ms_b1_design.b2b_read_history(bytea,text,uuid,uuid,date,date,integer) TO ms_b1b_api;

-- Legacy configured staff IDs must not retain former-branch disclosure.
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
  'configurationVersion',value->>'configuration_version','resourcesConfirmed',value->'resources_confirmed','eligibleStaffIds',coalesce((SELECT jsonb_agg(DISTINCT e.staff_id ORDER BY e.staff_id) FROM ms_b1_design.offering_staff_eligibility e JOIN ms_b1_design.staff s ON s.business_id=e.business_id AND s.id=e.staff_id JOIN ms_b1_design.staff_service_eligibility q ON q.business_id=e.business_id AND q.id=e.qualification_id JOIN ms_b1_design.staff_branch_assignment m ON m.business_id=e.business_id AND m.id=e.assignment_id WHERE e.business_id=(value->>'business_id')::uuid AND e.offering_id=(value->>'id')::uuid AND e.active AND e.archived_at IS NULL AND s.active AND s.archived_at IS NULL AND q.active AND q.verified_at IS NOT NULL AND q.archived_at IS NULL AND m.active AND m.voided_at IS NULL AND m.archived_at IS NULL AND m.membership_period @> ((statement_timestamp() AT TIME ZONE (SELECT b.time_zone FROM ms_b1_design.branch b WHERE b.business_id=e.business_id AND b.id=e.branch_id))::date)),'[]'::jsonb),
  'resourceRequirements',coalesce((SELECT jsonb_agg(jsonb_build_object('kind',r.resource_kind,'quantity',r.quantity) ORDER BY r.resource_kind)
   FROM ms_b1_design.offering_resource_requirement r WHERE r.business_id=(value->>'business_id')::uuid
   AND r.offering_id=(value->>'id')::uuid AND r.archived_at IS NULL),'[]'::jsonb));
END $$;



