SET search_path=pg_catalog;
-- Explicit safety replacement only: no UPDATE/activation/data seeds in this migration.
ALTER TABLE ms_b1_design.branch DROP CONSTRAINT b1_branch_inactive;
ALTER TABLE ms_b1_design.branch_service_offering DROP CONSTRAINT b1_branch_service_offering_inactive;
CREATE FUNCTION ms_b1_design.b4_gate_guard() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF TG_TABLE_NAME='branch' THEN
 IF NEW.bookable AND current_setting('ms.b4_activation',true) IS DISTINCT FROM NEW.business_id::text THEN PERFORM ms_b1_design.b3_fail('EXPLICIT_ACTIVATION_REQUIRED');END IF;
 ELSE
 IF NEW.active AND current_setting('ms.b4_activation',true) IS DISTINCT FROM NEW.business_id::text THEN PERFORM ms_b1_design.b3_fail('EXPLICIT_ACTIVATION_REQUIRED');END IF;END IF;RETURN NEW;
END $$;
CREATE TRIGGER b4_branch_gate BEFORE INSERT OR UPDATE OF bookable ON ms_b1_design.branch FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_gate_guard();
CREATE TRIGGER b4_offering_gate BEFORE INSERT OR UPDATE OF active ON ms_b1_design.branch_service_offering FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_gate_guard();
CREATE FUNCTION ms_b1_design.b4_lifecycle_guard() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF TG_OP='DELETE' THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_BOOKING_EVIDENCE');END IF;
 IF TG_TABLE_NAME='booking' THEN
 IF (to_jsonb(NEW)-ARRAY['status','active_revision_id','draft_expires_at','row_version','plan_committed']) IS DISTINCT FROM(to_jsonb(OLD)-ARRAY['status','active_revision_id','draft_expires_at','row_version','plan_committed']) OR NEW.row_version<>OLD.row_version+1 OR(OLD.plan_committed AND NOT NEW.plan_committed)
 OR NOT((OLD.status='DRAFT' AND NEW.status IN('HELD','CANCELLED','EXPIRED')) OR(OLD.status='HELD' AND NEW.status IN('HELD','CONFIRMED','PENDING_PAYMENT','CANCELLED','EXPIRED')) OR(OLD.status='PENDING_PAYMENT' AND NEW.status IN('PENDING_PAYMENT','CANCELLED','EXPIRED')) OR(OLD.status='CONFIRMED' AND NEW.status IN('CONFIRMED','CANCELLED'))) THEN PERFORM ms_b1_design.b3_fail('INVALID_BOOKING_STATE','MS409');END IF;
 ELSE
 IF (to_jsonb(NEW)-ARRAY['released_at','busy_period']) IS DISTINCT FROM(to_jsonb(OLD)-ARRAY['released_at','busy_period']) OR OLD.released_at IS NOT NULL OR NEW.released_at IS NULL THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_BOOKING_EVIDENCE');END IF;
 END IF;RETURN NEW;
END $$;
CREATE TRIGGER b4_booking_lifecycle BEFORE UPDATE OR DELETE ON ms_b1_design.booking FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_lifecycle_guard();
CREATE TRIGGER b4_hold_lifecycle BEFORE UPDATE OR DELETE ON ms_b1_design.booking_hold FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_lifecycle_guard();
CREATE TRIGGER b4_allocation_lifecycle BEFORE UPDATE OR DELETE ON ms_b1_design.resource_allocation FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_lifecycle_guard();
CREATE FUNCTION ms_b1_design.b4_event(b ms_b1_design.booking,actor uuid,previous text,event_name text) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 INSERT INTO ms_b1_design.booking_status_history(business_id,booking_id,revision_id,actor_user_id,from_status,to_status,event_type) VALUES(b.business_id,b.id,b.active_revision_id,actor,previous,b.status,event_name);
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,branch_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES(b.business_id,actor,b.branch_id,event_name,'booking',b.id,gen_random_uuid(),jsonb_build_object('version',b.row_version::text,'status',b.status),actor);
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at,created_by) VALUES(b.business_id,'booking',b.id,b.row_version,event_name,1,jsonb_build_object('id',b.id,'version',b.row_version::text,'status',b.status),clock_timestamp(),actor);
END $$;
CREATE FUNCTION ms_b1_design.b4_expire_business(bid uuid) RETURNS integer LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE b ms_b1_design.booking;old_status text;n integer:=0;now_at timestamptz;BEGIN
 PERFORM ms_b1_design.b4_lock(bid);now_at:=clock_timestamp();
 FOR b IN SELECT x.* FROM ms_b1_design.booking x WHERE x.business_id=bid AND((x.status='DRAFT' AND x.draft_expires_at<=now_at) OR(x.status IN('HELD','PENDING_PAYMENT') AND EXISTS(SELECT 1 FROM ms_b1_design.booking_hold h WHERE h.business_id=bid AND h.revision_id=x.active_revision_id AND h.released_at IS NULL AND h.expires_at<=now_at))) ORDER BY x.id LIMIT 100 FOR UPDATE LOOP
 old_status:=b.status;UPDATE ms_b1_design.resource_allocation SET released_at=now_at WHERE business_id=bid AND revision_id=b.active_revision_id AND released_at IS NULL;
 UPDATE ms_b1_design.booking_hold SET released_at=now_at WHERE business_id=bid AND revision_id=b.active_revision_id AND released_at IS NULL;
 UPDATE ms_b1_design.booking SET status='EXPIRED',row_version=row_version+1 WHERE id=b.id RETURNING * INTO b;PERFORM ms_b1_design.b4_event(b,NULL,old_status,'b4.booking.expired');n:=n+1;END LOOP;RETURN n;
END $$;
-- Independent transaction before planning/admission; never release other bookings while
-- holding an incomplete subset of resources. All lock acquisition is canonical and complete.
CREATE FUNCTION ms_b1_design.b4_sweep(h bytea,csrf bytea) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;BEGIN a:=ms_b1_design.b4_actor(h,csrf);RETURN ms_b1_design.b4_expire_business((a->>'businessId')::uuid);END $$;
CREATE FUNCTION ms_b1_design.b4_view(b ms_b1_design.booking) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('id',b.id,'branchId',b.branch_id,'status',b.status,'version',b.row_version::text,'revisionId',b.active_revision_id,'createdAt',ms_b1_design.b3_iso(b.created_at),'draftExpiresAt',ms_b1_design.b3_iso(b.draft_expires_at),
 'quote',(SELECT jsonb_build_object('id',q.id,'content',q.content_document,'terms',q.terms_document,'contentHash',encode(q.content_hash,'hex'),'expiresAt',ms_b1_design.b3_iso(q.expires_at)) FROM ms_b1_design.booking_revision r JOIN ms_b1_design.pricing_quote q ON q.business_id=r.business_id AND q.id=r.quote_id WHERE r.business_id=b.business_id AND r.id=b.active_revision_id),
 'holdExpiresAt',(SELECT ms_b1_design.b3_iso(expires_at) FROM ms_b1_design.booking_hold WHERE business_id=b.business_id AND revision_id=b.active_revision_id),'moneyExecuted',false)
$$;
CREATE FUNCTION ms_b1_design.b4_quote_check(bid uuid,uid uuid,qid uuid,ignore_booking uuid) RETURNS ms_b1_design.pricing_quote LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE q ms_b1_design.pricing_quote;p ms_b1_design.booking_plan;current_plan jsonb;BEGIN
 SELECT * INTO q FROM ms_b1_design.pricing_quote WHERE business_id=bid AND id=qid AND created_by=uid;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 SELECT * INTO p FROM ms_b1_design.booking_plan WHERE business_id=bid AND id=q.plan_id;
 IF q.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('QUOTE_EXPIRED','MS409');END IF;
 IF q.content_hash<>ms_b1_design.b3_digest(q.content_document) OR encode(ms_b1_design.b3_digest(q.terms_document),'hex')<>q.content_document->'policy'->>'snapshotHash' THEN PERFORM ms_b1_design.b3_fail('QUOTE_INTEGRITY');END IF;
 IF (p.selectors->>'rescheduleBookingId')::uuid IS DISTINCT FROM ignore_booking THEN PERFORM ms_b1_design.b3_fail('PLAN_CONTEXT_MISMATCH','MS409');END IF;
 current_plan:=ms_b1_design.b4_plan(bid,q.branch_id,p.selectors->'selection',ignore_booking);
 IF current_plan IS NULL OR current_plan->'content'<>q.content_document OR current_plan->'terms'<>q.terms_document THEN PERFORM ms_b1_design.b3_fail('QUOTE_STALE','MS409');END IF;
 IF q.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('QUOTE_EXPIRED','MS409');END IF;RETURN q;
END $$;
CREATE FUNCTION ms_b1_design.b4_admit(b ms_b1_design.booking,q ms_b1_design.pricing_quote,uid uuid) RETURNS ms_b1_design.booking LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE rev uuid:=gen_random_uuid();hid uuid:=gen_random_uuid();n integer;entry jsonb;assigned_resource jsonb;segment_id uuid;aid uuid;span record;now_at timestamptz:=clock_timestamp();ttl integer;next_status text;
BEGIN
 SELECT coalesce(max(revision_number),0)+1 INTO n FROM ms_b1_design.booking_revision WHERE business_id=b.business_id AND booking_id=b.id;
 SELECT hold_ttl_seconds INTO ttl FROM ms_b1_design.availability_configuration WHERE business_id=b.business_id AND branch_id=b.branch_id AND enabled AND archived_at IS NULL;
 INSERT INTO ms_b1_design.booking_revision(id,business_id,booking_id,branch_id,quote_id,revision_number,supersedes_revision_id) VALUES(rev,b.business_id,b.id,b.branch_id,q.id,n,b.active_revision_id);
 -- Rescheduling a confirmed zero-deposit reservation remains confirmed; unpaid holds retain
 -- their ORIGINAL deadline. Moving a booking must never extend its capacity lease silently.
 INSERT INTO ms_b1_design.booking_hold(id,business_id,booking_id,revision_id,expires_at,released_at) VALUES(hid,b.business_id,b.id,rev,
 CASE WHEN b.plan_committed AND b.status<>'CONFIRMED' THEN(SELECT expires_at FROM ms_b1_design.booking_hold WHERE business_id=b.business_id AND revision_id=b.active_revision_id) ELSE now_at+make_interval(secs=>ttl) END,
 CASE WHEN b.status='CONFIRMED' THEN now_at ELSE NULL END);
 -- Normalize/union touching intervals BEFORE GiST insertion; no self-revision exception.
 FOR span IN WITH raw AS(SELECT (r->>'resourceId')::uuid rid,tstzrange(ms_b1_design.b3_instant(s->>'startsAt')-make_interval(mins=>(s->>'bufferBeforeMinutes')::integer),ms_b1_design.b3_instant(s->>'endsAt')+make_interval(mins=>(s->>'bufferAfterMinutes')::integer),'[)') busy
 FROM jsonb_array_elements(q.content_document->'segments') s CROSS JOIN LATERAL jsonb_array_elements(s->'resources') r),unions AS(SELECT rid,range_agg(busy) busy FROM raw GROUP BY rid)
 SELECT rid,unnest(busy) busy FROM unions ORDER BY rid LOOP
 INSERT INTO ms_b1_design.resource_allocation(business_id,branch_id,revision_id,hold_id,resource_id,resource_kind,resource_branch_id,busy_starts_at,busy_ends_at)
 SELECT b.business_id,b.branch_id,rev,hid,x.id,x.kind,x.branch_id,lower(span.busy),upper(span.busy) FROM ms_b1_design.resource x WHERE x.business_id=b.business_id AND x.id=span.rid AND x.active AND x.archived_at IS NULL;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('RESOURCE_UNAVAILABLE','MS409');END IF;END LOOP;
 FOR entry IN SELECT value FROM jsonb_array_elements(q.content_document->'segments') LOOP
 INSERT INTO ms_b1_design.booking_service_segment(business_id,revision_id,quote_id,position,staff_id,starts_at,ends_at,segment_document) VALUES(b.business_id,rev,q.id,(entry->>'sequence')::integer,(entry->>'staffId')::uuid,ms_b1_design.b3_instant(entry->>'startsAt'),ms_b1_design.b3_instant(entry->>'endsAt'),entry) RETURNING id INTO segment_id;
 FOR assigned_resource IN SELECT value FROM jsonb_array_elements(entry->'resources') LOOP
 SELECT id INTO aid FROM ms_b1_design.resource_allocation WHERE business_id=b.business_id AND revision_id=rev AND resource_id=(assigned_resource->>'resourceId')::uuid AND busy_period @> tstzrange(ms_b1_design.b3_instant(entry->>'startsAt')-make_interval(mins=>(entry->>'bufferBeforeMinutes')::integer),ms_b1_design.b3_instant(entry->>'endsAt')+make_interval(mins=>(entry->>'bufferAfterMinutes')::integer),'[)');
 INSERT INTO ms_b1_design.segment_resource_assignment(business_id,segment_id,revision_id,resource_id,allocation_id) VALUES(b.business_id,segment_id,rev,(assigned_resource->>'resourceId')::uuid,aid);END LOOP;END LOOP;
 INSERT INTO ms_b1_design.booking_policy_acceptance(business_id,booking_id,revision_id,quote_id,accepted_by,quote_hash,snapshot_hash) VALUES(b.business_id,b.id,rev,q.id,uid,q.content_hash,decode(q.content_document->'policy'->>'snapshotHash','hex'));
 next_status:=CASE WHEN b.status='DRAFT' THEN 'HELD' ELSE b.status END;
 UPDATE ms_b1_design.booking SET status=next_status,plan_committed=true,active_revision_id=rev,draft_expires_at=NULL,row_version=row_version+1 WHERE id=b.id RETURNING * INTO b;RETURN b;
END $$;
CREATE FUNCTION ms_b1_design.b4_read(h bytea,csrf bytea,kind text,entity uuid,page_offset integer DEFAULT 0) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;bid uuid;uid uuid;b ms_b1_design.booking;result jsonb;BEGIN
 a:=ms_b1_design.b4_actor(h,csrf);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;
 IF page_offset NOT BETWEEN 0 AND 10000 THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 IF kind='catalog' THEN
 RETURN jsonb_build_object('source','SERVER','isolated',true,'branches',coalesce((SELECT jsonb_agg(jsonb_build_object('id',x.id,'name',x.display_name,'timeZone',x.time_zone,'configured',x.bookable,'version',x.row_version::text,'today',(clock_timestamp() AT TIME ZONE x.time_zone)::date::text,'horizonDays',coalesce((SELECT c.horizon_days FROM ms_b1_design.availability_configuration c WHERE c.business_id=bid AND c.branch_id=x.id AND c.enabled AND c.archived_at IS NULL),0)) ORDER BY x.code) FROM ms_b1_design.branch x WHERE x.business_id=bid AND x.active AND x.archived_at IS NULL),'[]'::jsonb),
 'offerings',coalesce((SELECT jsonb_agg(jsonb_build_object('id',o.id,'branchId',o.branch_id,'serviceId',o.service_id,'name',s.display_name,'priceRial',o.price_rial::text,'durationMinutes',o.duration_minutes::text,'version',o.row_version::text) ORDER BY s.code) FROM ms_b1_design.branch_service_offering o JOIN ms_b1_design.service s ON s.business_id=o.business_id AND s.id=o.service_id WHERE o.business_id=bid AND o.active AND o.archived_at IS NULL AND s.active AND s.archived_at IS NULL),'[]'::jsonb),
 'staff',coalesce((SELECT jsonb_agg(jsonb_build_object('id',s.id,'name',s.display_name,'offeringIds',coalesce((SELECT jsonb_agg(DISTINCT e.offering_id ORDER BY e.offering_id) FROM ms_b1_design.offering_staff_eligibility e WHERE e.business_id=bid AND e.staff_id=s.id AND e.active AND e.archived_at IS NULL),'[]'::jsonb)) ORDER BY s.id) FROM ms_b1_design.staff s WHERE s.business_id=bid AND s.active AND s.archived_at IS NULL),'[]'::jsonb));
 ELSIF kind='history' THEN RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(ms_b1_design.b4_view(x) ORDER BY x.created_at DESC,x.id) FROM(SELECT * FROM ms_b1_design.booking WHERE business_id=bid AND created_by=uid ORDER BY created_at DESC,id LIMIT 25 OFFSET page_offset) x),'[]'::jsonb));
 ELSIF kind IN('booking','events','cancellation-preview') THEN
 SELECT * INTO b FROM ms_b1_design.booking WHERE business_id=bid AND id=entity AND created_by=uid;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF kind='events' THEN RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(jsonb_build_object('from',x.from_status,'to',x.to_status,'event',x.event_type,'at',ms_b1_design.b3_iso(x.created_at)) ORDER BY x.created_at,x.id) FROM ms_b1_design.booking_status_history x WHERE x.business_id=bid AND x.booking_id=b.id),'[]'::jsonb));
 ELSIF kind='cancellation-preview' THEN RETURN ms_b1_design.b4_cancellation(b,clock_timestamp());ELSE RETURN ms_b1_design.b4_view(b);END IF;
 ELSE PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;RETURN NULL;
END $$;
CREATE FUNCTION ms_b1_design.b4_cancellation(b ms_b1_design.booking,at_time timestamptz) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE q ms_b1_design.pricing_quote;deadline timestamptz;allowed boolean;BEGIN
 IF b.plan_committed THEN SELECT x.* INTO q FROM ms_b1_design.pricing_quote x JOIN ms_b1_design.booking_revision v ON v.business_id=x.business_id AND v.quote_id=x.id WHERE v.business_id=b.business_id AND v.id=b.active_revision_id;
 deadline:=ms_b1_design.b3_instant(q.content_document->>'startsAt')-make_interval(mins=>(q.terms_document->'terms'->>'cancellationDeadlineMinutes')::integer);END IF;
 allowed:=b.status IN('DRAFT','HELD','PENDING_PAYMENT','CONFIRMED') AND(deadline IS NULL OR at_time<=deadline);
 RETURN jsonb_build_object('bookingId',b.id,'version',b.row_version::text,'evaluatedAt',ms_b1_design.b3_iso(at_time),'cancellationAllowed',allowed,'deadline',ms_b1_design.b3_iso(deadline),'paidRial','0','refundPreviewRial','0','moneyExecuted',false,'terms',q.terms_document);
END $$;
CREATE FUNCTION ms_b1_design.b4_command(h bytea,csrf bytea,op text,idem text,requestid uuid,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
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
 FOR provider IN SELECT s.id FROM ms_b1_design.staff s WHERE s.business_id=bid AND s.active AND s.archived_at IS NULL AND((d->>'staffId') IS NULL OR s.id=(d->>'staffId')::uuid) ORDER BY s.id LIMIT 32 LOOP
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
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA ms_b1_design FROM PUBLIC;
REVOKE ALL ON FUNCTION ms_b1_design.b4_gate_guard(),ms_b1_design.b4_lifecycle_guard(),ms_b1_design.b4_event(ms_b1_design.booking,uuid,text,text),ms_b1_design.b4_expire_business(uuid),ms_b1_design.b4_view(ms_b1_design.booking),ms_b1_design.b4_quote_check(uuid,uuid,uuid,uuid),ms_b1_design.b4_admit(ms_b1_design.booking,ms_b1_design.pricing_quote,uuid),ms_b1_design.b4_cancellation(ms_b1_design.booking,timestamptz) FROM ms_b1a_runtime,ms_b1b_api;
GRANT EXECUTE ON FUNCTION ms_b1_design.b4_read(bytea,bytea,text,uuid,integer),ms_b1_design.b4_command(bytea,bytea,text,text,uuid,jsonb),ms_b1_design.b4_sweep(bytea,bytea) TO ms_b1b_api;
