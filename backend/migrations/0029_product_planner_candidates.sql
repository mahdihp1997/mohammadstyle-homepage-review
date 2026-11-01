-- Measured product availability timeout with accumulated unrelated branch staff.
-- Candidate prefilter is necessary-only. b4_plan still revalidates temporal membership,
-- qualifications, prices, policy, schedules and every capacity allocation under b4_lock.
SET search_path=ms_b1_design,public;
CREATE TABLE product_time_zone(name text PRIMARY KEY);
INSERT INTO product_time_zone SELECT name FROM pg_catalog.pg_timezone_names WHERE name !~ '^(posix|right)/' AND(name='UTC' OR position('/' IN name)>0);
REVOKE ALL ON product_time_zone FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker;
-- This is a pinned PG image's accepted-name catalog, not a cache of offsets.
-- Offset/DST resolution still round-trips every minute exactly as in approved B2B.
CREATE OR REPLACE FUNCTION ms_b1_design.b2b_local_instant(local_value timestamp,zone text,resolution text)
 RETURNS timestamptz LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE candidates timestamptz[];
BEGIN
 IF local_value IS NULL OR local_value<'2020-01-01' OR local_value>='2101-01-01'
 OR resolution IS NULL OR resolution NOT IN ('reject','earlier','later') OR NOT EXISTS
 (SELECT 1 FROM ms_b1_design.product_time_zone WHERE name=zone) THEN
 PERFORM ms_b1_design.b2b_fail('INVALID_LOCAL_TIME','MS422'); END IF;
 SELECT array_agg(t ORDER BY t) INTO candidates FROM generate_series(
 local_value AT TIME ZONE 'UTC'-interval '16 hours',local_value AT TIME ZONE 'UTC'+interval '16 hours',interval '1 minute') t
 WHERE t AT TIME ZONE zone=local_value;
 IF cardinality(candidates) IS NULL THEN PERFORM ms_b1_design.b2b_fail('DST_GAP','MS422'); END IF;
 IF cardinality(candidates)>1 AND resolution='reject' THEN PERFORM ms_b1_design.b2b_fail('DST_FOLD_REVIEW_REQUIRED','MS422'); END IF;
 RETURN CASE WHEN resolution='later' THEN candidates[cardinality(candidates)] ELSE candidates[1] END;
END $$;

CREATE OR REPLACE FUNCTION ms_b1_design.b4_command(h bytea,csrf bytea,op text,idem text,requestid uuid,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;bid uuid;uid uuid;prior ms_b1_design.idempotency_record;rh bytea;route text;result jsonb;selected_branch uuid;br ms_b1_design.branch;cfg ms_b1_design.availability_configuration;
 p ms_b1_design.booking_plan;q ms_b1_design.pricing_quote;b ms_b1_design.booking;old_status text;plan jsonb;sel jsonb;offerings jsonb;entry jsonb;provider record;slot_time timestamptz;day date;minute integer;slots jsonb:='[]';ignore_booking uuid;fingerprint text;expires timestamptz;target uuid;previous_q ms_b1_design.pricing_quote;previous_hold ms_b1_design.booking_hold;number_slots integer:=0;without_payment boolean;
BEGIN
 a:=ms_b1_design.b4_actor(h,csrf);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;
 IF op NOT IN('availability','quote','draft','hold','confirm','cancel','reschedule','configuration.enable') OR op IS NULL OR idem IS NULL OR idem !~ '^[A-Za-z0-9_-]{16,128}$' OR requestid IS NULL THEN PERFORM ms_b1_design.b3_fail('INVALID_HEADERS');END IF;
 route:='b4:'||op;rh:=sha256(convert_to(d::text,'UTF8'));
 PERFORM ms_b1_design.b4_lock(bid);
 SELECT * INTO prior FROM ms_b1_design.idempotency_record WHERE business_id=bid AND actor_key=uid::text AND route_key=route AND idempotency_key=idem FOR UPDATE;
 IF FOUND THEN IF prior.request_hash<>rh OR prior.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('IDEMPOTENCY_CONFLICT','MS409');END IF;RETURN prior.response_snapshot;END IF;
 IF op IN('availability','configuration.enable') THEN
 IF op='availability' THEN PERFORM ms_b1_design.b3_keys(d,ARRAY['branchId','offeringIds','staffId','date','optionalDepositChosen','rescheduleBookingId','cursor']);ELSE PERFORM ms_b1_design.b3_keys(d,ARRAY['branchId','offeringIds']);END IF;
 selected_branch:=(d->>'branchId')::uuid;SELECT * INTO br FROM ms_b1_design.branch WHERE business_id=bid AND id=selected_branch AND active AND archived_at IS NULL;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF jsonb_typeof(d->'offeringIds')<>'array' OR jsonb_array_length(d->'offeringIds') NOT BETWEEN 1 AND 12 OR EXISTS(SELECT 1 FROM jsonb_array_elements(d->'offeringIds') x WHERE jsonb_typeof(x)<>'string') THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 IF (SELECT count(DISTINCT x) FROM jsonb_array_elements_text(d->'offeringIds') x)<>jsonb_array_length(d->'offeringIds') THEN PERFORM ms_b1_design.b3_fail('DUPLICATE_SERVICE');END IF;
 SELECT jsonb_agg(jsonb_build_object('id',o.id,'version',o.row_version::text) ORDER BY x.n) INTO offerings FROM jsonb_array_elements_text(d->'offeringIds') WITH ORDINALITY x(id,n) JOIN ms_b1_design.branch_service_offering o ON o.id=x.id::uuid AND o.business_id=bid AND o.branch_id=selected_branch AND o.archived_at IS NULL;
 IF coalesce(jsonb_array_length(offerings),0)<>jsonb_array_length(d->'offeringIds') THEN PERFORM ms_b1_design.b3_fail('OFFERING_NOT_FOUND','MS404');END IF;
 SELECT * INTO cfg FROM ms_b1_design.availability_configuration WHERE business_id=bid AND branch_id=selected_branch AND archived_at IS NULL;
 IF op='configuration.enable' THEN
 IF NOT ms_b1_design.b1b_can(a,'booking.configure',selected_branch) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF cfg.id IS NULL THEN PERFORM ms_b1_design.b3_fail('BOOKING_UNCONFIGURED');END IF;
 PERFORM set_config('ms.b4_activation',bid::text,true);
 UPDATE ms_b1_design.branch_service_offering SET active=true,row_version=row_version+1 WHERE business_id=bid AND branch_id=selected_branch AND id IN(SELECT value::uuid FROM jsonb_array_elements_text(d->'offeringIds'));
 UPDATE ms_b1_design.availability_configuration SET enabled=true,row_version=row_version+1,configuration_version=configuration_version+1 WHERE id=cfg.id;
 UPDATE ms_b1_design.branch SET bookable=true,row_version=row_version+1 WHERE id=selected_branch RETURNING * INTO br;
 SELECT jsonb_agg(jsonb_build_object('id',o.id,'version',o.row_version::text) ORDER BY x.n) INTO offerings FROM jsonb_array_elements_text(d->'offeringIds') WITH ORDINALITY x(id,n) JOIN ms_b1_design.branch_service_offering o ON o.id=x.id::uuid;
 -- Explicit enable must prove a real future feasible plan; the transaction rolls back ALL gates if absent.
 FOR provider IN SELECT s.staff_id,s.starts_at FROM ms_b1_design.staff_shift s WHERE s.business_id=bid AND s.branch_id=selected_branch AND s.published AND s.archived_at IS NULL AND s.starts_at>clock_timestamp()+make_interval(mins=>coalesce(cfg.lead_minutes,0)) ORDER BY s.starts_at,s.staff_id LIMIT 32 LOOP
 sel:=jsonb_build_object('branchVersion',br.row_version::text,'offerings',offerings,'staffId',provider.staff_id,'startsAt',ms_b1_design.b3_iso(provider.starts_at),'optionalDepositChosen',false);
 plan:=ms_b1_design.b4_plan(bid,selected_branch,sel);IF plan IS NOT NULL THEN EXIT;END IF;END LOOP;
 IF plan IS NULL THEN PERFORM ms_b1_design.b3_fail('NO_VERIFIED_PLAN_FOR_ACTIVATION');END IF;
 PERFORM set_config('ms.b4_activation','',true);target:=selected_branch;result:=jsonb_build_object('branchId',selected_branch,'enabled',true,'version',br.row_version::text);
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,branch_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES(bid,uid,selected_branch,'b4.configuration.enabled','branch',selected_branch,requestid,jsonb_build_object('enabled',true),uid);
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at,created_by) VALUES(bid,'booking.configuration',requestid,1,'b4.configuration.enabled',1,jsonb_build_object('id',selected_branch),clock_timestamp(),uid);
 ELSE
 IF jsonb_typeof(d->'optionalDepositChosen')<>'boolean' OR jsonb_typeof(d->'staffId') NOT IN('string','null') OR jsonb_typeof(d->'rescheduleBookingId') NOT IN('string','null') OR d->>'date' !~ '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 day:=(d->>'date')::date;IF day::text<>d->>'date' OR day<(clock_timestamp() AT TIME ZONE br.time_zone)::date OR day>(clock_timestamp() AT TIME ZONE br.time_zone)::date+coalesce(cfg.horizon_days,0) THEN PERFORM ms_b1_design.b3_fail('OUTSIDE_BOOKING_WINDOW');END IF;
 IF NOT br.bookable OR cfg.id IS NULL OR NOT cfg.enabled OR cfg.slot_stride_minutes NOT BETWEEN 5 AND 120 THEN PERFORM ms_b1_design.b3_fail('BOOKING_UNCONFIGURED');END IF;
 ignore_booking:=(d->>'rescheduleBookingId')::uuid;
 IF ignore_booking IS NOT NULL THEN SELECT * INTO b FROM ms_b1_design.booking WHERE business_id=bid AND id=ignore_booking AND created_by=uid AND branch_id=selected_branch AND status IN('HELD','CONFIRMED') FOR UPDATE;IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;END IF;
 PERFORM ms_b1_design.b3_nat(d->>'cursor',1439);
 IF jsonb_typeof(d->'cursor')<>'string' OR mod((d->>'cursor')::integer,cfg.slot_stride_minutes)<>0 THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 FOR minute IN SELECT m FROM generate_series((d->>'cursor')::integer,1439,cfg.slot_stride_minutes) m
 WHERE EXISTS(SELECT 1 FROM ms_b1_design.staff_shift x WHERE x.business_id=bid AND x.branch_id=selected_branch AND x.published AND x.archived_at IS NULL
 AND x.starts_at<=((day::timestamp+make_interval(mins=>m)) AT TIME ZONE br.time_zone) AND x.ends_at>((day::timestamp+make_interval(mins=>m)) AT TIME ZONE br.time_zone)) LOOP
 BEGIN slot_time:=ms_b1_design.b2b_local_instant(day::timestamp+make_interval(mins=>minute),br.time_zone,'reject');EXCEPTION WHEN SQLSTATE 'MS422' THEN CONTINUE;END;
 IF slot_time<clock_timestamp()+make_interval(mins=>cfg.lead_minutes) THEN CONTINUE;END IF;
 FOR provider IN SELECT s.id FROM ms_b1_design.staff s WHERE s.business_id=bid AND s.active AND s.archived_at IS NULL AND((d->>'staffId') IS NULL OR s.id=(d->>'staffId')::uuid)
 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements_text(d->'offeringIds') selected(id) WHERE NOT EXISTS(SELECT 1 FROM ms_b1_design.offering_staff_eligibility eligible WHERE eligible.business_id=bid AND eligible.branch_id=selected_branch AND eligible.staff_id=s.id AND eligible.offering_id=selected.id::uuid AND eligible.active AND eligible.archived_at IS NULL)) ORDER BY s.id LIMIT 32 LOOP
 sel:=jsonb_build_object('branchVersion',br.row_version::text,'offerings',offerings,'staffId',provider.id,'startsAt',ms_b1_design.b3_iso(slot_time),'optionalDepositChosen',d->'optionalDepositChosen');
 BEGIN plan:=ms_b1_design.b4_plan(bid,selected_branch,sel,ignore_booking);EXCEPTION WHEN SQLSTATE 'MS422' THEN IF SQLERRM IN('STAFF_NOT_ELIGIBLE','STAFF_NOT_APPLICABLE','OVERNIGHT_REQUIRES_REVIEW') THEN CONTINUE;ELSE RAISE;END IF;END;
 IF plan IS NOT NULL THEN
 expires:=clock_timestamp()+make_interval(secs=>cfg.quote_ttl_seconds);
 INSERT INTO ms_b1_design.booking_plan(business_id,branch_id,created_by,selectors,content_document,terms_document,content_hash,expires_at) VALUES(bid,selected_branch,uid,jsonb_build_object('selection',sel,'rescheduleBookingId',ignore_booking),plan->'content',plan->'terms',ms_b1_design.b3_digest(plan->'content'),expires) RETURNING id INTO target;
 slots:=slots||jsonb_build_array(jsonb_build_object('id',target,'startsAt',plan->'content'->>'startsAt','endsAt',plan->'content'->>'endsAt','staffId',provider.id,'timeZone',br.time_zone,'expiresAt',ms_b1_design.b3_iso(expires)));number_slots:=number_slots+1;EXIT;
 END IF;END LOOP;EXIT WHEN number_slots>=6;END LOOP;
 result:=jsonb_build_object('source','SERVER','slots',slots,'maximumSlots',6,'nextCursor',CASE WHEN number_slots>=6 AND minute+cfg.slot_stride_minutes<1440 THEN(minute+cfg.slot_stride_minutes)::text ELSE NULL END,'requestKey',encode(rh,'hex'),'date',day::text,'timeZone',br.time_zone);
 END IF;
 ELSIF op='quote' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['planId']);SELECT * INTO p FROM ms_b1_design.booking_plan WHERE business_id=bid AND id=(d->>'planId')::uuid AND created_by=uid;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF p.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('PLAN_EXPIRED','MS409');END IF;
 ignore_booking:=(p.selectors->>'rescheduleBookingId')::uuid;
 IF ignore_booking IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.booking WHERE business_id=bid AND id=ignore_booking AND created_by=uid AND status IN('HELD','CONFIRMED')) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 plan:=ms_b1_design.b4_plan(bid,p.branch_id,p.selectors->'selection',ignore_booking);
 IF plan IS NULL OR plan->'content'<>p.content_document OR plan->'terms'<>p.terms_document OR p.content_hash<>ms_b1_design.b3_digest(p.content_document) THEN PERFORM ms_b1_design.b3_fail('PLAN_STALE','MS409');END IF;
 IF p.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('PLAN_EXPIRED','MS409');END IF;
 INSERT INTO ms_b1_design.pricing_quote(business_id,branch_id,created_by,plan_id,content_document,terms_document,content_hash,policy_version_id,expires_at) VALUES(bid,p.branch_id,uid,p.id,p.content_document,p.terms_document,p.content_hash,(p.content_document->'policy'->>'versionId')::uuid,p.expires_at) RETURNING * INTO q;target:=q.id;
 FOR entry IN SELECT value FROM jsonb_array_elements(q.content_document->'items') LOOP
 INSERT INTO ms_b1_design.pricing_quote_item(business_id,quote_id,position,offering_id,branch_id,service_id,item_document) VALUES(bid,q.id,(entry->>'position')::integer,(entry->>'offeringId')::uuid,q.branch_id,(entry->>'serviceId')::uuid,entry);END LOOP;
 FOR entry IN SELECT value FROM jsonb_array_elements(q.content_document->'policy'->'sourceAssignments') LOOP INSERT INTO ms_b1_design.quote_policy_source(business_id,quote_id,position,assignment_id) VALUES(bid,q.id,(entry->>'quoteItemPosition')::integer,(entry->>'assignmentId')::uuid);END LOOP;
 result:=jsonb_build_object('id',q.id,'content',q.content_document,'terms',q.terms_document,'contentHash',encode(q.content_hash,'hex'),'expiresAt',ms_b1_design.b3_iso(q.expires_at),'capacityReserved',false);
 ELSIF op='draft' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['branchId']);selected_branch:=(d->>'branchId')::uuid;
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.branch WHERE business_id=bid AND id=selected_branch AND bookable AND archived_at IS NULL) THEN PERFORM ms_b1_design.b3_fail('BOOKING_UNCONFIGURED');END IF;
 INSERT INTO ms_b1_design.booking(business_id,branch_id,created_by) VALUES(bid,selected_branch,uid) RETURNING * INTO b;PERFORM ms_b1_design.b4_event(b,uid,NULL,'b4.booking.drafted');result:=ms_b1_design.b4_view(b);target:=b.id;
 ELSE
 IF op IN('hold','reschedule') THEN PERFORM ms_b1_design.b3_keys(d,ARRAY['bookingId','version','quoteId','contentHash','snapshotHash','accepted']);ELSE PERFORM ms_b1_design.b3_keys(d,ARRAY['bookingId','version']);END IF;
 SELECT * INTO b FROM ms_b1_design.booking WHERE business_id=bid AND id=(d->>'bookingId')::uuid AND created_by=uid FOR UPDATE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF jsonb_typeof(d->'version')<>'string' OR b.row_version::text<>d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_BOOKING','MS412');END IF;
 old_status:=b.status;target:=b.id;
 IF op IN('hold','reschedule') THEN
 IF d->'accepted' IS DISTINCT FROM 'true'::jsonb OR jsonb_typeof(d->'contentHash')<>'string' OR jsonb_typeof(d->'snapshotHash')<>'string' THEN PERFORM ms_b1_design.b3_fail('EXPLICIT_CONSENT_REQUIRED');END IF;
 IF(op='hold' AND b.status<>'DRAFT') OR(op='reschedule' AND b.status NOT IN('HELD','CONFIRMED')) THEN PERFORM ms_b1_design.b3_fail('INVALID_BOOKING_STATE','MS409');END IF;
 IF b.status='DRAFT' AND b.draft_expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('DRAFT_EXPIRED','MS409');END IF;
 q:=ms_b1_design.b4_quote_check(bid,uid,(d->>'quoteId')::uuid,CASE WHEN op='reschedule' THEN b.id ELSE NULL END);
 IF q.branch_id<>b.branch_id OR d->>'contentHash'<>encode(q.content_hash,'hex') OR d->>'snapshotHash'<>q.content_document->'policy'->>'snapshotHash' THEN PERFORM ms_b1_design.b3_fail('QUOTE_TAMPERED','MS409');END IF;
 IF op='reschedule' THEN
 SELECT x.* INTO previous_q FROM ms_b1_design.pricing_quote x JOIN ms_b1_design.booking_revision r ON r.business_id=x.business_id AND r.quote_id=x.id WHERE r.business_id=bid AND r.id=b.active_revision_id;
 SELECT * INTO previous_hold FROM ms_b1_design.booking_hold WHERE business_id=bid AND revision_id=b.active_revision_id;
 IF b.status='HELD' AND previous_hold.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('HOLD_EXPIRED','MS409');END IF;
 IF NOT(ms_b1_design.b4_cancellation(b,clock_timestamp())->>'cancellationAllowed')::boolean OR previous_q.content_document->'items'<>q.content_document->'items' OR previous_q.terms_document<>q.terms_document OR previous_q.content_document->>'depositRial'<>'0' OR q.content_document->>'depositRial'<>'0'
 OR NOT(previous_q.terms_document->'terms'->>'depositRequirement'='NONE' OR(previous_q.terms_document->'terms'->>'depositRequirement'='OPTIONAL' AND previous_q.content_document->'optionalDepositChosen'='false'::jsonb)) THEN PERFORM ms_b1_design.b3_fail('RESCHEDULE_REQUIRES_REVIEW');END IF;
 UPDATE ms_b1_design.resource_allocation SET released_at=clock_timestamp() WHERE business_id=bid AND revision_id=b.active_revision_id AND released_at IS NULL;
 UPDATE ms_b1_design.booking_hold SET released_at=clock_timestamp() WHERE business_id=bid AND revision_id=b.active_revision_id AND released_at IS NULL;
 END IF;
 b:=ms_b1_design.b4_admit(b,q,uid);
 ELSIF op='confirm' THEN
 IF b.status NOT IN('HELD','PENDING_PAYMENT') THEN PERFORM ms_b1_design.b3_fail('INVALID_BOOKING_STATE','MS409');END IF;
 SELECT * INTO previous_hold FROM ms_b1_design.booking_hold WHERE business_id=bid AND revision_id=b.active_revision_id;
 IF previous_hold.expires_at<=clock_timestamp() OR previous_hold.released_at IS NOT NULL THEN PERFORM ms_b1_design.b3_fail('HOLD_EXPIRED','MS409');END IF;
 SELECT x.* INTO q FROM ms_b1_design.pricing_quote x JOIN ms_b1_design.booking_revision r ON r.business_id=x.business_id AND r.quote_id=x.id WHERE r.business_id=bid AND r.id=b.active_revision_id;
 -- Accepted snapshots, allocations and consent stay authoritative after quote TTL; no new quote.
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.booking_policy_acceptance WHERE business_id=bid AND revision_id=b.active_revision_id AND quote_hash=q.content_hash) THEN PERFORM ms_b1_design.b3_fail('EXPLICIT_CONSENT_REQUIRED');END IF;
 -- A REQUIRED/chosen deposit rounded to zero is NOT an approved non-payment path.
 without_payment:=q.content_document->>'depositRial'='0' AND(q.terms_document->'terms'->>'depositRequirement'='NONE' OR(q.terms_document->'terms'->>'depositRequirement'='OPTIONAL' AND q.content_document->'optionalDepositChosen'='false'::jsonb));
 IF without_payment THEN UPDATE ms_b1_design.booking_hold SET released_at=clock_timestamp() WHERE id=previous_hold.id;END IF;
 UPDATE ms_b1_design.booking SET status=CASE WHEN without_payment THEN 'CONFIRMED' ELSE 'PENDING_PAYMENT' END,row_version=row_version+1 WHERE id=b.id RETURNING * INTO b;
 ELSIF op='cancel' THEN
 IF NOT(ms_b1_design.b4_cancellation(b,clock_timestamp())->>'cancellationAllowed')::boolean THEN PERFORM ms_b1_design.b3_fail('CANCELLATION_REQUIRES_REVIEW');END IF;
 UPDATE ms_b1_design.resource_allocation SET released_at=clock_timestamp() WHERE business_id=bid AND revision_id=b.active_revision_id AND released_at IS NULL;
 UPDATE ms_b1_design.booking_hold SET released_at=clock_timestamp() WHERE business_id=bid AND revision_id=b.active_revision_id AND released_at IS NULL;
 UPDATE ms_b1_design.booking SET status='CANCELLED',row_version=row_version+1 WHERE id=b.id RETURNING * INTO b;
 END IF;
 PERFORM ms_b1_design.b4_event(b,uid,old_status,'b4.booking.'||op);result:=ms_b1_design.b4_view(b);
 END IF;
 INSERT INTO ms_b1_design.idempotency_record(business_id,actor_key,route_key,idempotency_key,request_hash,state,response_code,response_snapshot,expires_at,created_by) VALUES(bid,uid::text,route,idem,rh,'COMPLETE',200,result,clock_timestamp()+interval '24 hours',uid);
 RETURN result;
END $$;

