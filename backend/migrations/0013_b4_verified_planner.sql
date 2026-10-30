SET search_path=pg_catalog;
-- Coarse aggregate mutex deliberately reuses B2B's sorted ALL-selected_branch/ALL-resource lock.
-- Serializes one business, not the whole cluster. Optimize only after measured contention.
CREATE FUNCTION ms_b1_design.b4_lock(bid uuid) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 PERFORM 1 FROM ms_b1_design.pricing_configuration_revision WHERE business_id=bid FOR UPDATE;
 PERFORM ms_b1_design.b2b_lock(bid);
END $$;
CREATE FUNCTION ms_b1_design.b4_actor(h bytea,csrf bytea) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE a jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);
 PERFORM 1 FROM ms_b1_design.auth_identity WHERE user_id=(a->>'userId')::uuid AND verified_at IS NOT NULL FOR SHARE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('VERIFIED_IDENTITY_REQUIRED','MS403');END IF;
 IF NOT ms_b1_design.b1b_can(a,'booking.customer',NULL) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;RETURN a;
END $$;
CREATE FUNCTION ms_b1_design.b4_signature(bid uuid) RETURNS text LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT encode(sha256(convert_to(coalesce(string_agg(row_value,'|' ORDER BY table_name,row_value),''),'UTF8')),'hex') FROM (
 SELECT 'branch' table_name,to_jsonb(t)::text row_value FROM ms_b1_design.branch t WHERE business_id=bid UNION ALL
 SELECT 'offer',to_jsonb(t)::text FROM ms_b1_design.branch_service_offering t WHERE business_id=bid UNION ALL
 SELECT 'service',to_jsonb(t)::text FROM ms_b1_design.service t WHERE business_id=bid UNION ALL
 SELECT 'requirement',to_jsonb(t)::text FROM ms_b1_design.offering_resource_requirement t WHERE business_id=bid UNION ALL
 SELECT 'config',to_jsonb(t)::text FROM ms_b1_design.availability_configuration t WHERE business_id=bid UNION ALL
 SELECT 'hours',to_jsonb(t)::text FROM ms_b1_design.branch_working_hours t WHERE business_id=bid UNION ALL
 SELECT 'closure',to_jsonb(t)::text FROM ms_b1_design.branch_closure t WHERE business_id=bid UNION ALL
 SELECT 'resource',to_jsonb(t)::text FROM ms_b1_design.resource t WHERE business_id=bid UNION ALL
 SELECT 'staff',to_jsonb(t)::text FROM ms_b1_design.staff t WHERE business_id=bid UNION ALL
 SELECT 'member',to_jsonb(t)::text FROM ms_b1_design.staff_branch_assignment t WHERE business_id=bid UNION ALL
 SELECT 'qualification',to_jsonb(t)::text FROM ms_b1_design.staff_service_eligibility t WHERE business_id=bid UNION ALL
 SELECT 'eligibility',to_jsonb(t)::text FROM ms_b1_design.offering_staff_eligibility t WHERE business_id=bid UNION ALL
 SELECT 'shift',to_jsonb(t)::text FROM ms_b1_design.staff_shift t WHERE business_id=bid UNION ALL
 SELECT 'timeoff',to_jsonb(t)::text FROM ms_b1_design.staff_time_off t WHERE business_id=bid UNION ALL
 SELECT 'pricing',to_jsonb(t)::text FROM ms_b1_design.pricing_configuration_revision t WHERE business_id=bid
 ) evidence
$$;
CREATE FUNCTION ms_b1_design.b4_plan(bid uuid,selected_branch uuid,d jsonb,ignore_booking uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE br ms_b1_design.branch;cfg ms_b1_design.availability_configuration;s ms_b1_design.staff;o ms_b1_design.branch_service_offering;
 commercial jsonb;items jsonb:='[]';segments jsonb:='[]';res jsonb;entry jsonb;req record;r record;resources uuid[];sid uuid;st timestamptz;en timestamptz;cur timestamptz;
 service_start timestamptz;service_end timestamptz;busy_end timestamptz;instant timestamptz;local_value timestamp;pos integer:=0;terms jsonb;policy jsonb;sources jsonb;fingerprint text;rr uuid[];
BEGIN
 SELECT * INTO br FROM ms_b1_design.branch WHERE business_id=bid AND id=selected_branch AND active AND bookable AND archived_at IS NULL;
 SELECT * INTO cfg FROM ms_b1_design.availability_configuration WHERE business_id=bid AND branch_id=selected_branch AND enabled AND archived_at IS NULL;
 IF br.id IS NULL OR cfg.id IS NULL OR cfg.slot_stride_minutes NOT BETWEEN 5 AND 120 OR cfg.lead_minutes NOT BETWEEN 0 AND 10080 OR cfg.horizon_days NOT BETWEEN 1 AND 366 OR cfg.hold_ttl_seconds NOT BETWEEN 30 AND 1800 OR cfg.quote_ttl_seconds NOT BETWEEN 60 AND 3600 THEN PERFORM ms_b1_design.b3_fail('BOOKING_UNCONFIGURED');END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=br.time_zone AND (name='UTC' OR position('/' IN name)>0) AND name !~ '^(posix|right)/') THEN PERFORM ms_b1_design.b3_fail('INVALID_TIME_ZONE');END IF;
 st:=ms_b1_design.b3_instant(d->>'startsAt');sid:=(d->>'staffId')::uuid;
 IF st<clock_timestamp()+make_interval(mins=>cfg.lead_minutes) OR (st AT TIME ZONE br.time_zone)::date>(clock_timestamp() AT TIME ZONE br.time_zone)::date+cfg.horizon_days OR extract(second FROM st)<>0
 OR mod(extract(hour FROM st AT TIME ZONE br.time_zone)::integer*60+extract(minute FROM st AT TIME ZONE br.time_zone)::integer,cfg.slot_stride_minutes)<>0 THEN PERFORM ms_b1_design.b3_fail('OUTSIDE_BOOKING_WINDOW');END IF;
 -- Even UTC selectors must represent an unambiguous reviewed local wall time.
 IF ms_b1_design.b2b_local_instant(st AT TIME ZONE br.time_zone,br.time_zone,'reject')<>st THEN PERFORM ms_b1_design.b3_fail('INVALID_LOCAL_TIME');END IF;
 SELECT * INTO s FROM ms_b1_design.staff WHERE business_id=bid AND id=sid AND active AND archived_at IS NULL;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('STAFF_NOT_ELIGIBLE');END IF;
 -- Cheap server-owned shift/envelope pruning BEFORE the commercial resolver. This does
 -- not replace B3 validation: only feasible candidates reach the complete resolver below.
 SELECT st+make_interval(mins=>sum(x.duration_minutes+x.buffer_before_minutes+x.buffer_after_minutes)::integer) INTO en
 FROM ms_b1_design.branch_service_offering x WHERE x.business_id=bid AND x.branch_id=selected_branch AND x.id IN(SELECT (v->>'id')::uuid FROM jsonb_array_elements(d->'offerings') v);
 IF en IS NULL OR en<=st OR en>st+interval '1 day' THEN PERFORM ms_b1_design.b3_fail('OFFERING_UNCONFIGURED');END IF;
 IF (en AT TIME ZONE br.time_zone)::date<>(st AT TIME ZONE br.time_zone)::date THEN PERFORM ms_b1_design.b3_fail('OVERNIGHT_REQUIRES_REVIEW');END IF;
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.resource WHERE business_id=bid AND id=s.resource_id AND kind='STAFF' AND active AND archived_at IS NULL) THEN RETURN NULL;END IF;
 IF NOT coalesce((SELECT range_agg(tstzrange(x.starts_at,x.ends_at,'[)')) @> tstzrange(st,en,'[)') FROM ms_b1_design.staff_shift x
 WHERE x.business_id=bid AND x.staff_id=sid AND x.branch_id=selected_branch AND x.published AND x.archived_at IS NULL AND x.time_zone=br.time_zone AND x.local_date IS NOT NULL),false) THEN RETURN NULL;END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.staff_shift WHERE business_id=bid AND staff_id=sid AND branch_id<>selected_branch AND published AND archived_at IS NULL) THEN RETURN NULL;END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.staff_time_off x WHERE x.business_id=bid AND x.staff_id=sid AND x.archived_at IS NULL AND x.review_status<>'REJECTED'
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.staff_time_off y WHERE y.business_id=bid AND y.supersedes_id=x.id AND y.archived_at IS NULL) AND tstzrange(x.starts_at,x.ends_at,'[)')&&tstzrange(st,en,'[)')) THEN RETURN NULL;END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.branch_closure x WHERE x.business_id=bid AND x.branch_id=selected_branch AND x.archived_at IS NULL AND x.review_status<>'REJECTED'
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch_closure y WHERE y.business_id=bid AND y.supersedes_id=x.id AND y.archived_at IS NULL) AND tstzrange(x.starts_at,x.ends_at,'[)')&&tstzrange(st,en,'[)')) THEN RETURN NULL;END IF;
 FOR instant IN SELECT t FROM generate_series(st,en-interval '1 minute',interval '1 minute') t LOOP
 local_value:=instant AT TIME ZONE br.time_zone;
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.branch_working_hours x WHERE x.business_id=bid AND x.branch_id=selected_branch AND x.archived_at IS NULL AND x.valid_from<=local_value::date AND(x.valid_to IS NULL OR x.valid_to>local_value::date)
 AND x.iso_weekday=extract(isodow FROM local_value) AND x.start_minute<=extract(hour FROM local_value)*60+extract(minute FROM local_value) AND x.end_minute>=extract(hour FROM local_value)*60+extract(minute FROM local_value)+1) THEN RETURN NULL;END IF;
 END LOOP;
 cur:=st;
 FOR entry IN SELECT value FROM jsonb_array_elements(d->'offerings') LOOP
 pos:=pos+1;SELECT * INTO o FROM ms_b1_design.branch_service_offering WHERE business_id=bid AND id=(entry->>'id')::uuid AND branch_id=selected_branch AND active AND resources_confirmed AND archived_at IS NULL;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM ms_b1_design.offering_resource_requirement WHERE business_id=bid AND offering_id=o.id AND archived_at IS NULL) THEN PERFORM ms_b1_design.b3_fail('RESOURCES_UNCONFIGURED');END IF;
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.offering_staff_eligibility e JOIN ms_b1_design.staff_service_eligibility q ON q.business_id=e.business_id AND q.id=e.qualification_id
 WHERE e.business_id=bid AND e.offering_id=o.id AND e.staff_id=sid AND e.active AND e.archived_at IS NULL AND q.active AND q.archived_at IS NULL AND q.verified_at IS NOT NULL AND q.verified_by IS NOT NULL AND q.verification_evidence_hash IS NOT NULL) THEN RETURN NULL;END IF;
 service_start:=cur+make_interval(mins=>o.buffer_before_minutes);service_end:=service_start+make_interval(mins=>o.duration_minutes);busy_end:=service_end+make_interval(mins=>o.buffer_after_minutes);
 resources:=ARRAY[s.resource_id];
 FOR req IN SELECT * FROM ms_b1_design.offering_resource_requirement WHERE business_id=bid AND offering_id=o.id AND archived_at IS NULL ORDER BY resource_kind LOOP
 IF req.quantity>16 THEN PERFORM ms_b1_design.b3_fail('RESOURCE_LIMIT');END IF;
 SELECT array_agg(x.id ORDER BY x.id) INTO rr FROM (SELECT z.id FROM ms_b1_design.resource z WHERE z.business_id=bid AND z.branch_id=selected_branch AND z.kind=req.resource_kind AND z.active AND z.archived_at IS NULL
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.resource_allocation a JOIN ms_b1_design.booking_revision v ON v.business_id=a.business_id AND v.id=a.revision_id
 WHERE a.resource_id=z.id AND a.released_at IS NULL AND a.busy_period&&tstzrange(cur,busy_end,'[)') AND(ignore_booking IS NULL OR v.booking_id<>ignore_booking)) ORDER BY z.id LIMIT req.quantity) x;
 IF coalesce(cardinality(rr),0)<>req.quantity THEN RETURN NULL;END IF;resources:=resources||rr;END LOOP;
 IF EXISTS(SELECT 1 FROM ms_b1_design.resource_allocation a JOIN ms_b1_design.booking_revision v ON v.business_id=a.business_id AND v.id=a.revision_id WHERE a.resource_id=ANY(resources) AND a.released_at IS NULL AND a.busy_period&&tstzrange(cur,busy_end,'[)') AND(ignore_booking IS NULL OR v.booking_id<>ignore_booking)) THEN RETURN NULL;END IF;
 SELECT jsonb_agg(jsonb_build_object('resourceId',x.id,'kind',x.kind) ORDER BY x.id) INTO res FROM ms_b1_design.resource x WHERE x.id=ANY(resources) AND x.business_id=bid;
 segments:=segments||jsonb_build_array(jsonb_build_object('sequence',pos::text,'quoteItemPosition',pos::text,'offeringId',o.id,'staffId',sid,'startsAt',ms_b1_design.b3_iso(service_start),'endsAt',ms_b1_design.b3_iso(service_end),
 'durationMinutes',o.duration_minutes::text,'bufferBeforeMinutes',o.buffer_before_minutes::text,'bufferAfterMinutes',o.buffer_after_minutes::text,'resources',res,'dependsOnSequences',CASE WHEN pos=1 THEN '[]'::jsonb ELSE jsonb_build_array((pos-1)::text) END));cur:=busy_end;
 END LOOP;
 -- Every offered candidate still receives the complete B3 calculation, including all
 -- effective policy windows and provider membership. Infeasible candidates need no price.
 commercial:=ms_b1_design.b3_calculate(bid,selected_branch,d)->'content';
 SELECT jsonb_agg((x-'serviceVersion')||jsonb_build_object('packageId',NULL) ORDER BY (x->>'position')::integer) INTO items FROM jsonb_array_elements(commercial->'items') x;
 -- Frozen resolution preserves underlying service winners and explicit whole-booking compatibility evidence.
 terms:=jsonb_build_object('terms',commercial->'policy'->'terms','resolution',commercial->'policy'->'sourceAssignments');
 SELECT jsonb_agg(jsonb_build_object('quoteItemPosition',x->>'position','assignmentId',coalesce(
 (SELECT y->>'assignmentId' FROM jsonb_array_elements(commercial->'policy'->'sourceAssignments') y WHERE y->>'quoteItemPosition'='0'),
 (SELECT y->>'assignmentId' FROM jsonb_array_elements(commercial->'policy'->'sourceAssignments') y WHERE y->>'quoteItemPosition'=x->>'position'))) ORDER BY (x->>'position')::integer) INTO sources FROM jsonb_array_elements(items) x;
 policy:=((commercial->'policy')-ARRAY['terms','sourceAssignments'])||jsonb_build_object('snapshotHash',encode(ms_b1_design.b3_digest(terms),'hex'),'resolverVersion','B4_VERIFIED_B3_V1','sourceAssignments',sources);
 fingerprint:=encode(ms_b1_design.b3_digest(jsonb_build_object('commercial',commercial->>'configurationFingerprint','workforce',ms_b1_design.b4_signature(bid))),'hex');
 RETURN jsonb_build_object('content',(commercial-ARRAY['staffId','items','policy'])||jsonb_build_object('schema','MS_QUOTE_CONTENT_V2','configurationFingerprint',fingerprint,'items',items,'segments',segments,'policy',policy),'terms',terms);
END $$;
-- Writer guard: conservative business freeze while ANY current/future reservation exists. Changes require
-- cancellation/expiry first; emergency compensation and non-displacing fine-grained edits are deferred.
CREATE FUNCTION ms_b1_design.b4_schedule_guard() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE bid uuid;BEGIN
 bid:=CASE WHEN TG_OP='DELETE' THEN OLD.business_id ELSE NEW.business_id END;
 PERFORM ms_b1_design.b2b_lock(bid);
 IF EXISTS(SELECT 1 FROM ms_b1_design.resource_allocation WHERE business_id=bid AND released_at IS NULL AND busy_ends_at>clock_timestamp()) THEN PERFORM ms_b1_design.b3_fail('LIVE_RESERVATIONS_REQUIRE_REVIEW','MS409');END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;ELSE RETURN NEW;END IF;
END $$;
CREATE TRIGGER b4_shift_guard BEFORE INSERT OR UPDATE OR DELETE ON ms_b1_design.staff_shift FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_schedule_guard();
CREATE TRIGGER b4_hours_guard BEFORE INSERT OR UPDATE OR DELETE ON ms_b1_design.branch_working_hours FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_schedule_guard();
CREATE TRIGGER b4_timeoff_guard BEFORE INSERT OR UPDATE OR DELETE ON ms_b1_design.staff_time_off FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_schedule_guard();
CREATE TRIGGER b4_closure_guard BEFORE INSERT OR UPDATE OR DELETE ON ms_b1_design.branch_closure FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_schedule_guard();
CREATE TRIGGER b4_resource_guard BEFORE UPDATE OR DELETE ON ms_b1_design.resource FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_schedule_guard();
CREATE TRIGGER b4_staff_guard BEFORE UPDATE OR DELETE ON ms_b1_design.staff FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_schedule_guard();
CREATE TRIGGER b4_membership_guard BEFORE UPDATE OR DELETE ON ms_b1_design.staff_branch_assignment FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_schedule_guard();
CREATE TRIGGER b4_qualification_guard BEFORE UPDATE OR DELETE ON ms_b1_design.staff_service_eligibility FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_schedule_guard();
CREATE TRIGGER b4_eligibility_guard BEFORE INSERT OR UPDATE OR DELETE ON ms_b1_design.offering_staff_eligibility FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_schedule_guard();
CREATE TRIGGER b4_requirement_guard BEFORE INSERT OR UPDATE OR DELETE ON ms_b1_design.offering_resource_requirement FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_schedule_guard();
CREATE TRIGGER b4_configuration_guard BEFORE UPDATE OR DELETE ON ms_b1_design.availability_configuration FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_schedule_guard();
CREATE TRIGGER b4_branch_guard BEFORE UPDATE OR DELETE ON ms_b1_design.branch FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b4_schedule_guard();
REVOKE ALL ON FUNCTION ms_b1_design.b4_lock(uuid),ms_b1_design.b4_actor(bytea,bytea),ms_b1_design.b4_signature(uuid),ms_b1_design.b4_plan(uuid,uuid,jsonb,uuid),ms_b1_design.b4_schedule_guard() FROM PUBLIC,ms_b1a_runtime,ms_b1b_api;
