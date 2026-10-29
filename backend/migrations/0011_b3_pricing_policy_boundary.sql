SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.b3_fail(reason text,code text DEFAULT 'MS422') RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN RAISE EXCEPTION USING ERRCODE=code,MESSAGE=reason;END $$;
CREATE FUNCTION ms_b1_design.b3_keys(d jsonb,allowed text[]) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF jsonb_typeof(d) IS DISTINCT FROM 'object' OR NOT(d ?& allowed) OR EXISTS(SELECT 1 FROM jsonb_object_keys(d) k WHERE NOT(k=ANY(allowed))) THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;END $$;
CREATE FUNCTION ms_b1_design.b3_nat(t text,hi numeric DEFAULT 9223372036854775807) RETURNS numeric LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF t IS NULL OR t !~ '^(0|[1-9][0-9]{0,18})$' OR t::numeric>hi THEN PERFORM ms_b1_design.b3_fail('INVALID_INTEGER');END IF;RETURN t::numeric;END $$;
CREATE FUNCTION ms_b1_design.b3_instant(t text) RETURNS timestamptz LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE v timestamptz;BEGIN
 IF t IS NULL OR t !~ '^20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z$' THEN PERFORM ms_b1_design.b3_fail('INVALID_INSTANT');END IF;
 v:=t::timestamptz;IF to_char(v AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')<>t THEN PERFORM ms_b1_design.b3_fail('INVALID_INSTANT');END IF;RETURN v;END $$;
CREATE FUNCTION ms_b1_design.b3_iso(t timestamptz) RETURNS text LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$SELECT to_char(t AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')$$;
-- RFC8785 restricted string/boolean/null domain, ASCII schema keys only; no JSON numbers.
CREATE FUNCTION ms_b1_design.b3_jcs(d jsonb) RETURNS text LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE s text;BEGIN
 CASE jsonb_typeof(d) WHEN 'object' THEN
 IF EXISTS(SELECT 1 FROM jsonb_object_keys(d) k WHERE k !~ '^[A-Za-z][A-Za-z0-9]*$') THEN PERFORM ms_b1_design.b3_fail('INVALID_HASH_DOMAIN');END IF;
 SELECT '{'||coalesce(string_agg(to_jsonb(k)::text||':'||ms_b1_design.b3_jcs(v),',' ORDER BY k COLLATE "C"),'')||'}' INTO s FROM jsonb_each(d) e(k,v);
 WHEN 'array' THEN SELECT '['||coalesce(string_agg(ms_b1_design.b3_jcs(v),',' ORDER BY n),'')||']' INTO s FROM jsonb_array_elements(d) WITH ORDINALITY e(v,n);
 WHEN 'string','boolean','null' THEN s:=d::text; ELSE PERFORM ms_b1_design.b3_fail('INVALID_HASH_DOMAIN');END CASE;RETURN s;END $$;
CREATE FUNCTION ms_b1_design.b3_digest(d jsonb) RETURNS bytea LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path=pg_catalog AS $$SELECT sha256(convert_to(ms_b1_design.b3_jcs(d),'UTF8'))$$;
CREATE FUNCTION ms_b1_design.b3_terms(v ms_b1_design.booking_policy_version) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('depositRequirement',v.deposit_requirement,'amountKind',v.amount_kind,'fixedRial',v.fixed_rial::text,'basisPoints',v.basis_points::text,
 'minimumRial',v.minimum_rial::text,'maximumRial',v.maximum_rial::text,'refundability',v.refundability,'refundBase',v.refund_base,'outsideRefundBps',v.outside_refund_bps::text,
 'cancellationDeadlineMinutes',v.cancellation_deadline_minutes::text,'termsText',v.terms_text,'termsLocale',v.terms_locale,'effectiveFrom',ms_b1_design.b3_iso(v.effective_from),
 'effectiveTo',ms_b1_design.b3_iso(v.effective_to),'refundWindows',coalesce((SELECT jsonb_agg(jsonb_build_object('thresholdMinutes',w.threshold_minutes::text,'refundBps',w.refund_bps::text) ORDER BY w.threshold_minutes)
 FROM ms_b1_design.policy_refund_window w WHERE w.business_id=v.business_id AND w.policy_version_id=v.id),'[]'::jsonb))$$;
CREATE FUNCTION ms_b1_design.b3_validate_terms(d jsonb) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE k text;w jsonb;n integer;BEGIN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['depositRequirement','amountKind','fixedRial','basisPoints','minimumRial','maximumRial','refundability','refundBase','outsideRefundBps','cancellationDeadlineMinutes','termsText','termsLocale','effectiveFrom','effectiveTo','refundWindows']);
 FOR k IN SELECT jsonb_object_keys(d) LOOP
 IF k<>'refundWindows' AND jsonb_typeof(d->k) NOT IN('string','null') THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;END LOOP;
 IF jsonb_typeof(d->'termsText')<>'string' OR length(btrim(d->>'termsText')) NOT BETWEEN 1 AND 8000 OR d->>'termsLocale' !~ '^[a-z]{2}(-[A-Z]{2})?$' THEN PERFORM ms_b1_design.b3_fail('INVALID_TERMS');END IF;
 PERFORM ms_b1_design.b3_instant(d->>'effectiveFrom');IF d->>'effectiveTo' IS NOT NULL THEN PERFORM ms_b1_design.b3_instant(d->>'effectiveTo');END IF;
 FOR k IN SELECT unnest(ARRAY['fixedRial','minimumRial','maximumRial']) LOOP IF d->>k IS NOT NULL AND mod(ms_b1_design.b3_nat(d->>k),10)<>0 THEN PERFORM ms_b1_design.b3_fail('INVALID_MONEY');END IF;END LOOP;
 IF d->>'basisPoints' IS NOT NULL THEN PERFORM ms_b1_design.b3_nat(d->>'basisPoints',10000);END IF;
 PERFORM ms_b1_design.b3_nat(d->>'outsideRefundBps',10000);PERFORM ms_b1_design.b3_nat(d->>'cancellationDeadlineMinutes',525600);
 IF jsonb_typeof(d->'refundWindows')<>'array' OR jsonb_array_length(d->'refundWindows')>32 THEN PERFORM ms_b1_design.b3_fail('INVALID_REFUND_WINDOWS');END IF;
 FOR w IN SELECT value FROM jsonb_array_elements(d->'refundWindows') LOOP PERFORM ms_b1_design.b3_keys(w,ARRAY['thresholdMinutes','refundBps']);
 IF jsonb_typeof(w->'thresholdMinutes')<>'string' OR jsonb_typeof(w->'refundBps')<>'string' THEN PERFORM ms_b1_design.b3_fail('INVALID_REFUND_WINDOWS');END IF;
 PERFORM ms_b1_design.b3_nat(w->>'thresholdMinutes',525600);PERFORM ms_b1_design.b3_nat(w->>'refundBps',10000);END LOOP;
 SELECT count(DISTINCT value->>'thresholdMinutes') INTO n FROM jsonb_array_elements(d->'refundWindows');IF n<>jsonb_array_length(d->'refundWindows') THEN PERFORM ms_b1_design.b3_fail('INVALID_REFUND_WINDOWS');END IF;
 IF (d->>'refundability'='FULL' AND (d->>'outsideRefundBps'<>'10000' OR n<>0)) OR (d->>'refundability'='NONE' AND (d->>'outsideRefundBps'<>'0' OR n<>0)) OR
 (d->>'refundability'='PARTIAL' AND (NOT((d->>'outsideRefundBps')::integer BETWEEN 1 AND 9999) OR n<>0)) OR (d->>'refundability'='CONDITIONAL' AND n=0)
 THEN PERFORM ms_b1_design.b3_fail('INVALID_REFUND_WINDOWS');END IF;END $$;
CREATE FUNCTION ms_b1_design.b3_freeze() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$DECLARE v uuid;b uuid;BEGIN
 IF TG_TABLE_NAME='booking_policy_version' THEN
 IF OLD.published_at IS NOT NULL AND (TG_OP='DELETE' OR (to_jsonb(NEW)-ARRAY['lifecycle','row_version']) IS DISTINCT FROM(to_jsonb(OLD)-ARRAY['lifecycle','row_version']) OR NEW.lifecycle NOT IN('ACTIVE','RETIRED') OR (OLD.lifecycle='RETIRED' AND NEW.lifecycle<>'RETIRED')) THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_POLICY');END IF;
 ELSIF TG_TABLE_NAME='policy_refund_window' THEN
 IF TG_OP<>'INSERT' THEN v:=OLD.policy_version_id;b:=OLD.business_id;IF EXISTS(SELECT 1 FROM ms_b1_design.booking_policy_version p WHERE p.id=v AND p.business_id=b AND p.published_at IS NOT NULL) THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_POLICY');END IF;END IF;
 IF TG_OP<>'DELETE' AND EXISTS(SELECT 1 FROM ms_b1_design.booking_policy_version p WHERE p.id=NEW.policy_version_id AND p.business_id=NEW.business_id AND p.published_at IS NOT NULL) THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_POLICY');END IF;
 ELSIF TG_TABLE_NAME='booking_policy_assignment' THEN
 IF TG_OP='DELETE' OR(to_jsonb(NEW)-ARRAY['revoked_at','applicable_period']) IS DISTINCT FROM(to_jsonb(OLD)-ARRAY['revoked_at','applicable_period']) OR OLD.revoked_at IS NOT NULL OR NEW.revoked_at IS NULL THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_ASSIGNMENT');END IF;
 ELSE PERFORM ms_b1_design.b3_fail('IMMUTABLE_SNAPSHOT');END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;ELSE RETURN NEW;END IF;END $$;
CREATE TRIGGER freeze_policy BEFORE UPDATE OR DELETE ON ms_b1_design.booking_policy_version FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_windows BEFORE INSERT OR UPDATE OR DELETE ON ms_b1_design.policy_refund_window FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_assignment BEFORE UPDATE OR DELETE ON ms_b1_design.booking_policy_assignment FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_proposal BEFORE UPDATE OR DELETE ON ms_b1_design.pricing_proposal FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_proposal_item BEFORE UPDATE OR DELETE ON ms_b1_design.pricing_proposal_item FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_proposal_source BEFORE UPDATE OR DELETE ON ms_b1_design.pricing_proposal_source FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_assignment_service BEFORE UPDATE OR DELETE ON ms_b1_design.policy_assignment_service FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_assignment_compat BEFORE UPDATE OR DELETE ON ms_b1_design.policy_assignment_compatibility FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();

CREATE FUNCTION ms_b1_design.b3_calculate(bid uuid,branch uuid,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE br ms_b1_design.branch;o ms_b1_design.branch_service_offering;s ms_b1_design.service;v ms_b1_design.booking_policy_version;
 entry jsonb;items jsonb:='[]';sources jsonb:='[]';winners uuid[]:=ARRAY[]::uuid[];services uuid[]:=ARRAY[]::uuid[];off_ids uuid[]:=ARRAY[]::uuid[];
 candidates record;winner record;win uuid;assignment uuid;whole ms_b1_design.booking_policy_assignment;sid uuid;st timestamptz;en timestamptz;mins bigint:=0;total numeric:=0;dep numeric:=0;pos integer:=0;
 rev bigint;ttl integer;fingerprint jsonb;terms jsonb;artifact jsonb;chosen boolean;staff_version text;membership_evidence jsonb;eligibility_evidence jsonb;
BEGIN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['branchVersion','offerings','staffId','startsAt','optionalDepositChosen']);
 IF jsonb_typeof(d->'branchVersion')<>'string' OR jsonb_typeof(d->'offerings')<>'array' OR jsonb_array_length(d->'offerings') NOT BETWEEN 1 AND 12 OR jsonb_typeof(d->'optionalDepositChosen')<>'boolean'
 OR jsonb_typeof(d->'staffId') NOT IN('string','null') THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 SELECT * INTO br FROM ms_b1_design.branch b WHERE b.business_id=bid AND b.id=branch AND b.archived_at IS NULL FOR SHARE;
 IF NOT FOUND OR NOT br.active THEN PERFORM ms_b1_design.b3_fail('INACTIVE_CONTEXT');END IF;
 IF br.row_version::text<>d->>'branchVersion' THEN PERFORM ms_b1_design.b3_fail('QUOTE_STALE','MS409');END IF;
 st:=ms_b1_design.b3_instant(d->>'startsAt');IF st<=clock_timestamp() OR st>clock_timestamp()+interval '10 years' THEN PERFORM ms_b1_design.b3_fail('INVALID_INSTANT');END IF;
 sid:=(d->>'staffId')::uuid;chosen:=(d->>'optionalDepositChosen')::boolean;
 FOR entry IN SELECT value FROM jsonb_array_elements(d->'offerings') LOOP
 PERFORM ms_b1_design.b3_keys(entry,ARRAY['id','version']);IF jsonb_typeof(entry->'id')<>'string' OR jsonb_typeof(entry->'version')<>'string' THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 SELECT * INTO o FROM ms_b1_design.branch_service_offering x WHERE x.business_id=bid AND x.branch_id=branch AND x.id=(entry->>'id')::uuid AND x.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('OFFERING_NOT_FOUND','MS404');END IF;
 IF o.row_version::text<>entry->>'version' THEN PERFORM ms_b1_design.b3_fail('QUOTE_STALE','MS409');END IF;
 IF o.id=ANY(off_ids) THEN PERFORM ms_b1_design.b3_fail('DUPLICATE_SERVICE');END IF;off_ids:=array_append(off_ids,o.id);
 SELECT * INTO s FROM ms_b1_design.service x WHERE x.business_id=bid AND x.id=o.service_id AND x.archived_at IS NULL FOR SHARE;
 IF NOT FOUND OR NOT s.active OR o.price_rial IS NULL OR o.duration_minutes IS NULL OR o.buffer_before_minutes IS NULL OR o.buffer_after_minutes IS NULL OR o.duration_minutes>1440 OR o.buffer_before_minutes>1440 OR o.buffer_after_minutes>1440 THEN PERFORM ms_b1_design.b3_fail('OFFERING_UNCONFIGURED');END IF;
 total:=total+o.price_rial;IF total>9223372036854775807 THEN PERFORM ms_b1_design.b3_fail('MONEY_OVERFLOW');END IF;
 mins:=mins+o.duration_minutes+o.buffer_before_minutes+o.buffer_after_minutes;IF mins>1440 THEN PERFORM ms_b1_design.b3_fail('DURATION_LIMIT');END IF;pos:=pos+1;
 services:=array_append(services,s.id);
 items:=items||jsonb_build_array(jsonb_build_object('position',pos::text,'offeringId',o.id,'serviceId',s.id,'offeringVersion',o.row_version::text,'serviceVersion',s.row_version::text,'displayName',s.display_name,
 'quantity','1','unitPriceRial',o.price_rial::text,'durationMinutes',o.duration_minutes::text,'bufferBeforeMinutes',o.buffer_before_minutes::text,'bufferAfterMinutes',o.buffer_after_minutes::text));
 END LOOP;
 en:=st+make_interval(mins=>mins::integer);
 IF sid IS NOT NULL THEN
 SELECT x.row_version::text INTO staff_version FROM ms_b1_design.staff x WHERE x.business_id=bid AND x.id=sid AND x.active AND x.archived_at IS NULL FOR SHARE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('STAFF_NOT_APPLICABLE');END IF;
 SELECT jsonb_agg(jsonb_build_object('id',m.id,'version',m.row_version::text) ORDER BY m.id) INTO membership_evidence
 FROM ms_b1_design.staff_branch_assignment m WHERE m.business_id=bid AND m.staff_id=sid AND m.branch_id=branch AND m.active AND m.voided_at IS NULL AND m.archived_at IS NULL
 AND ms_b1_design.b2h_membership_window(m,(st AT TIME ZONE br.time_zone)::date,(en AT TIME ZONE br.time_zone)::date+1,br.time_zone,false,clock_timestamp()) @> tstzrange(st,en,'[)');
 IF membership_evidence IS NULL THEN PERFORM ms_b1_design.b3_fail('STAFF_NOT_APPLICABLE');END IF;
 END IF;
 FOR entry IN SELECT value FROM jsonb_array_elements(items) LOOP
 IF sid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.offering_staff_eligibility e JOIN ms_b1_design.staff_service_eligibility q ON q.id=e.qualification_id AND q.business_id=e.business_id
 JOIN ms_b1_design.staff_branch_assignment m ON m.id=e.assignment_id AND m.business_id=e.business_id
 WHERE e.business_id=bid AND e.branch_id=branch AND e.staff_id=sid AND e.offering_id=(entry->>'offeringId')::uuid AND e.active AND e.archived_at IS NULL AND q.active AND q.archived_at IS NULL AND q.verified_at IS NOT NULL
 AND m.active AND m.archived_at IS NULL AND m.voided_at IS NULL AND ms_b1_design.b2h_membership_window(m,(st AT TIME ZONE br.time_zone)::date,(en AT TIME ZONE br.time_zone)::date+1,br.time_zone,false,clock_timestamp()) @> tstzrange(st,en,'[)')) THEN PERFORM ms_b1_design.b3_fail('STAFF_NOT_ELIGIBLE');END IF;
 win:=NULL;assignment:=NULL;winner:=NULL;
 FOR candidates IN SELECT a.*,CASE a.scope_kind WHEN 'STAFF_SERVICE' THEN 5 WHEN 'STAFF' THEN 4 WHEN 'SERVICE' THEN 3 WHEN 'BRANCH' THEN 2 ELSE 1 END rank,
 (a.branch_id IS NOT NULL)::integer specificity FROM ms_b1_design.booking_policy_assignment a JOIN ms_b1_design.booking_policy_version p ON p.business_id=a.business_id AND p.id=a.policy_version_id
 WHERE a.business_id=bid AND a.revoked_at IS NULL AND a.scope_kind<>'WHOLE_BOOKING' AND (a.branch_id IS NULL OR a.branch_id=branch)
 AND (a.service_id IS NULL OR a.service_id=(entry->>'serviceId')::uuid) AND (a.staff_id IS NULL OR a.staff_id=sid)
 AND a.effective_from<=st AND(a.effective_to IS NULL OR a.effective_to>=en) AND p.lifecycle='ACTIVE' AND p.effective_from<=st AND(p.effective_to IS NULL OR p.effective_to>=en)
 ORDER BY rank DESC,specificity DESC,a.priority DESC,a.id LOOP
 IF win IS NULL THEN win:=candidates.policy_version_id;assignment:=candidates.id;winner:=candidates;
 ELSIF (winner.rank,winner.specificity,winner.priority)=(candidates.rank,candidates.specificity,candidates.priority) AND win<>candidates.policy_version_id THEN PERFORM ms_b1_design.b3_fail('POLICY_CONFLICT','MS409');ELSE EXIT;END IF;END LOOP;
 IF win IS NULL THEN PERFORM ms_b1_design.b3_fail('POLICY_REQUIRED');END IF;
 winners:=array_append(winners,win);sources:=sources||jsonb_build_array(jsonb_build_object('quoteItemPosition',entry->>'position','assignmentId',assignment,'versionId',win));
 END LOOP;
 IF sid IS NOT NULL THEN
 SELECT jsonb_agg(jsonb_build_object('id',e.id,'version',e.row_version::text,'qualificationId',q.id,'qualificationVersion',q.row_version::text) ORDER BY e.offering_id,e.id)
 INTO eligibility_evidence FROM ms_b1_design.offering_staff_eligibility e JOIN ms_b1_design.staff_service_eligibility q ON q.business_id=e.business_id AND q.id=e.qualification_id
 WHERE e.business_id=bid AND e.branch_id=branch AND e.staff_id=sid AND e.offering_id=ANY(off_ids) AND e.active AND e.archived_at IS NULL AND q.active AND q.archived_at IS NULL;
 END IF;
 winner:=NULL;whole:=NULL;
 FOR candidates IN SELECT a.* FROM ms_b1_design.booking_policy_assignment a JOIN ms_b1_design.booking_policy_version p ON p.business_id=a.business_id AND p.id=a.policy_version_id
 WHERE a.business_id=bid AND a.branch_id=branch AND a.scope_kind='WHOLE_BOOKING' AND a.revoked_at IS NULL AND a.effective_from<=st AND(a.effective_to IS NULL OR a.effective_to>=en)
 AND p.lifecycle='ACTIVE' AND p.effective_from<=st AND(p.effective_to IS NULL OR p.effective_to>=en)
 AND ARRAY(SELECT x.service_id FROM ms_b1_design.policy_assignment_service x WHERE x.business_id=bid AND x.assignment_id=a.id ORDER BY x.service_id)=ARRAY(SELECT DISTINCT x FROM unnest(services) x ORDER BY x)
 AND ARRAY(SELECT x.policy_version_id FROM ms_b1_design.policy_assignment_compatibility x WHERE x.business_id=bid AND x.assignment_id=a.id ORDER BY x.policy_version_id)=ARRAY(SELECT DISTINCT x FROM unnest(winners) x ORDER BY x)
 ORDER BY a.priority DESC,a.id LOOP
 IF whole.id IS NULL THEN whole:=candidates;ELSIF whole.priority=candidates.priority AND whole.policy_version_id<>candidates.policy_version_id THEN PERFORM ms_b1_design.b3_fail('POLICY_CONFLICT','MS409');ELSE EXIT;END IF;END LOOP;
 IF whole.id IS NOT NULL THEN win:=whole.policy_version_id;sources:=sources||jsonb_build_array(jsonb_build_object('quoteItemPosition','0','assignmentId',whole.id,'versionId',win));
 ELSIF (SELECT count(DISTINCT x) FROM unnest(winners) x)<>1 THEN PERFORM ms_b1_design.b3_fail('POLICY_CONFLICT','MS409');ELSE win:=winners[1];END IF;
 SELECT * INTO v FROM ms_b1_design.booking_policy_version p WHERE p.business_id=bid AND p.id=win;terms:=ms_b1_design.b3_terms(v);
 IF v.content_hash IS DISTINCT FROM ms_b1_design.b3_digest(terms) THEN PERFORM ms_b1_design.b3_fail('POLICY_INTEGRITY');END IF;
 IF v.deposit_requirement<>'OPTIONAL' AND chosen THEN PERFORM ms_b1_design.b3_fail('OPTIONAL_CHOICE_NOT_APPLICABLE');END IF;
 IF v.deposit_requirement<>'NONE' THEN
 dep:=CASE WHEN v.amount_kind='FIXED' THEN v.fixed_rial::numeric ELSE floor((total*v.basis_points+50000)/100000)*10 END;
 IF v.minimum_rial IS NOT NULL THEN dep:=greatest(dep,v.minimum_rial);END IF;IF v.maximum_rial IS NOT NULL THEN dep:=least(dep,v.maximum_rial);END IF;
 IF dep>total THEN PERFORM ms_b1_design.b3_fail('POLICY_UNCALCULABLE');END IF;
 IF v.deposit_requirement='OPTIONAL' AND NOT chosen THEN dep:=0;END IF;END IF;
 SELECT c.quote_ttl_seconds INTO ttl FROM ms_b1_design.availability_configuration c WHERE c.business_id=bid AND c.branch_id=branch AND c.archived_at IS NULL;
 IF ttl IS NULL OR ttl NOT BETWEEN 60 AND 3600 THEN PERFORM ms_b1_design.b3_fail('QUOTE_TTL_REQUIRED');END IF;
 SELECT coalesce((SELECT c.revision FROM ms_b1_design.pricing_configuration_revision c WHERE c.business_id=bid),1) INTO rev;
 fingerprint:=jsonb_build_object('revision',rev::text,'branchVersion',br.row_version::text,'branchConfiguration',br.configuration_version::text,'staffVersion',staff_version,'membership',membership_evidence,'eligibility',eligibility_evidence,'items',items,'sources',sources,'ttlSeconds',ttl::text);
 artifact:=jsonb_build_object('schema','MS_COMMERCIAL_PROPOSAL_V1','businessId',bid,'branchId',branch,'source','SERVER','currency','IRR','unitVersion','IRR_RIAL_V1',
 'configurationFingerprint',encode(ms_b1_design.b3_digest(fingerprint),'hex'),'timeZone',br.time_zone,'startsAt',ms_b1_design.b3_iso(st),'endsAt',ms_b1_design.b3_iso(en),'staffId',sid,
 'optionalDepositChosen',chosen,'totalRial',total::text,'depositRial',dep::text,'remainingRial',(total-dep)::text,'items',items,
 'policy',jsonb_build_object('versionId',v.id,'versionNumber',v.version_number::text,'contentHash',encode(v.content_hash,'hex'),'resolverVersion','B3_RESOLVER_V1','sourceAssignments',sources,'terms',terms));
 RETURN jsonb_build_object('content',artifact,'ttlSeconds',ttl::text);END $$;

CREATE FUNCTION ms_b1_design.b3_read(h bytea,kind text,branch uuid,entity uuid,history boolean DEFAULT false,page_offset integer DEFAULT 0) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;bid uuid;result jsonb;rev bigint;proposal_row ms_b1_design.pricing_proposal;BEGIN
 a:=ms_b1_design.b1b_actor(h);bid:=(a->>'businessId')::uuid;
 IF kind IS NULL OR kind NOT IN('context','policies','assignments','quote') OR history IS NULL OR(history AND kind NOT IN('policies','assignments')) OR page_offset IS NULL OR page_offset NOT BETWEEN 0 AND 10000 OR(kind IN('context','quote') AND page_offset<>0) THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 IF NOT ms_b1_design.b1b_can(a,CASE WHEN kind='quote' THEN 'pricing.quote' WHEN history THEN 'policy.history.read' ELSE 'policy.read' END,branch) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF branch IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND b.id=branch AND b.archived_at IS NULL) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 PERFORM 1 FROM ms_b1_design.pricing_configuration_revision c WHERE c.business_id=bid FOR SHARE;
 SELECT coalesce((SELECT c.revision FROM ms_b1_design.pricing_configuration_revision c WHERE c.business_id=bid),1) INTO rev;
 IF kind='context' THEN
 result:=jsonb_build_object('branchVersion',(SELECT b.row_version::text FROM ms_b1_design.branch b WHERE b.business_id=bid AND b.id=branch),
 'quoteTtlSeconds',(SELECT c.quote_ttl_seconds::text FROM ms_b1_design.availability_configuration c WHERE c.business_id=bid AND c.branch_id=branch AND c.archived_at IS NULL),
 'bookable',false,'capacityReserved',false,'finalQuoteAvailable',false);
 ELSIF kind='policies' THEN
 SELECT jsonb_build_object('items',coalesce(jsonb_agg(value ORDER BY value->>'policyId',value->>'versionNumber'),'[]'::jsonb)) INTO result FROM(
 SELECT jsonb_build_object('id',v.id,'policyId',p.id,'name',p.name,'branchId',p.branch_id,'versionNumber',v.version_number::text,'recordVersion',v.row_version::text,'lifecycle',v.lifecycle,
 'terms',ms_b1_design.b3_terms(v),'contentHash',encode(v.content_hash,'hex')) value
 FROM ms_b1_design.booking_policy p JOIN ms_b1_design.booking_policy_version v ON v.business_id=p.business_id AND v.policy_id=p.id
 WHERE p.business_id=bid AND(p.branch_id=branch OR p.branch_id IS NULL) AND(history OR v.lifecycle='ACTIVE')
 AND(p.branch_id IS NOT NULL OR ms_b1_design.b1b_can(a,CASE WHEN history THEN 'policy.history.read' ELSE 'policy.read' END,NULL) OR EXISTS(
 SELECT 1 FROM ms_b1_design.booking_policy_assignment routing WHERE routing.business_id=bid AND routing.policy_version_id=v.id AND(routing.branch_id=branch OR routing.branch_id IS NULL) AND(history OR(routing.revoked_at IS NULL AND v.lifecycle='ACTIVE'))))
 ORDER BY p.id,v.version_number LIMIT 100 OFFSET page_offset) x;
 ELSIF kind='assignments' THEN
 SELECT jsonb_build_object('items',coalesce(jsonb_agg(value ORDER BY value->>'id'),'[]'::jsonb)) INTO result FROM(
 SELECT (to_jsonb(x)-ARRAY['business_id','created_by','context_key'])||jsonb_build_object('serviceIds',coalesce((SELECT jsonb_agg(s.service_id ORDER BY s.service_id) FROM ms_b1_design.policy_assignment_service s WHERE s.business_id=bid AND s.assignment_id=x.id),'[]'),
 'compatibleVersionIds',coalesce((SELECT jsonb_agg(s.policy_version_id ORDER BY s.policy_version_id) FROM ms_b1_design.policy_assignment_compatibility s WHERE s.business_id=bid AND s.assignment_id=x.id),'[]')) value
 FROM ms_b1_design.booking_policy_assignment x WHERE x.business_id=bid AND(x.branch_id=branch OR x.branch_id IS NULL) AND(history OR x.revoked_at IS NULL) ORDER BY x.id LIMIT 100 OFFSET page_offset) y;
 ELSE
 SELECT * INTO proposal_row FROM ms_b1_design.pricing_proposal x WHERE x.business_id=bid AND x.id=entity AND x.branch_id=branch AND x.created_by=(a->>'userId')::uuid;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 result:=jsonb_build_object('id',proposal_row.id,'hashVersion','MS_COMMERCIAL_PROPOSAL_V1','content',proposal_row.content_document,'contentHash',encode(proposal_row.content_hash,'hex'),
 'issuedAt',ms_b1_design.b3_iso(proposal_row.created_at),'expiresAt',ms_b1_design.b3_iso(proposal_row.expires_at),'expired',proposal_row.expires_at<=clock_timestamp(),'bookable',false,'capacityReserved',false,'finalQuoteAvailable',false);
 END IF;RETURN result||jsonb_build_object('version',rev::text,'projection',CASE WHEN history THEN 'history' ELSE 'current' END,'limit',100,'offset',page_offset);END $$;

CREATE FUNCTION ms_b1_design.b3_command(h bytea,csrf bytea,op text,branch uuid,entity uuid,expected bigint,idem text,requestid uuid,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;bid uuid;uid uuid;permission_key text;scope_branch uuid;revision bigint;prior ms_b1_design.idempotency_record;route text;request_hash bytea;
 result jsonb;body jsonb;target uuid;policy ms_b1_design.booking_policy;v ms_b1_design.booking_policy_version;assignment ms_b1_design.booking_policy_assignment;
 proposal ms_b1_design.pricing_proposal;t jsonb;w jsonb;x jsonb;content jsonb;hash bytea;calc jsonb;starts timestamptz;ends timestamptz;
 version_no integer;service_ids uuid[];compatible_ids uuid[];key text;now_at timestamptz;minutes_before numeric;rate integer;base numeric;refund numeric;
BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;
 IF op IS NULL OR op NOT IN('policy.create','version.create','version.replace','version.publish','version.retire','assignment.create','assignment.revoke','configuration.set','quote.create','quote.validate','quote.cancellation-preview')
 OR expected IS NULL OR expected<1 OR idem IS NULL OR idem !~ '^[A-Za-z0-9_-]{16,128}$' OR requestid IS NULL THEN PERFORM ms_b1_design.b3_fail('INVALID_HEADERS');END IF;
 scope_branch:=branch;
 IF op='version.create' THEN SELECT * INTO policy FROM ms_b1_design.booking_policy p WHERE p.business_id=bid AND p.id=entity;
 ELSIF op LIKE 'version.%' THEN SELECT * INTO v FROM ms_b1_design.booking_policy_version p WHERE p.business_id=bid AND p.id=entity;SELECT * INTO policy FROM ms_b1_design.booking_policy p WHERE p.business_id=bid AND p.id=v.policy_id;
 ELSIF op='assignment.revoke' THEN SELECT * INTO assignment FROM ms_b1_design.booking_policy_assignment x WHERE x.business_id=bid AND x.id=entity;scope_branch:=assignment.branch_id;END IF;
 IF op LIKE 'version.%' THEN scope_branch:=policy.branch_id;END IF;
 permission_key:=CASE WHEN op LIKE 'quote.%' THEN 'pricing.quote' ELSE 'policy.manage' END;
 IF NOT ms_b1_design.b1b_can(a,permission_key,scope_branch) OR scope_branch IS DISTINCT FROM branch THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF branch IS NOT NULL THEN PERFORM 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND b.id=branch AND b.archived_at IS NULL FOR SHARE;IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;END IF;
 IF (op IN('policy.create','assignment.create','configuration.set','quote.create') AND entity IS NOT NULL) OR(op NOT IN('policy.create','assignment.create','configuration.set','quote.create') AND entity IS NULL) THEN PERFORM ms_b1_design.b3_fail('INVALID_TARGET');END IF;
 IF(op LIKE 'version.%' AND policy.id IS NULL) OR(op='assignment.revoke' AND assignment.id IS NULL) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF op='assignment.create' AND d->>'scopeKind'='WHOLE_BOOKING' AND NOT ms_b1_design.b1b_can(a,'policy.override',branch) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 route:='b3:'||op||':'||coalesce(branch::text,'business')||':'||coalesce(entity::text,'create');
 request_hash:=sha256(convert_to(jsonb_build_object('data',d,'ifMatch',expected::text)::text,'UTF8'));
 PERFORM pg_advisory_xact_lock(hashtextextended(bid::text||uid::text||route||idem,0));
 SELECT * INTO prior FROM ms_b1_design.idempotency_record r WHERE r.business_id=bid AND r.actor_key=uid::text AND r.route_key=route AND r.idempotency_key=idem FOR UPDATE;
 IF FOUND THEN IF prior.request_hash<>request_hash OR prior.state<>'COMPLETE' OR prior.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('IDEMPOTENCY_CONFLICT','MS409');END IF;RETURN prior.response_snapshot;END IF;
 INSERT INTO ms_b1_design.pricing_configuration_revision(business_id) VALUES(bid) ON CONFLICT DO NOTHING;
 SELECT c.revision INTO revision FROM ms_b1_design.pricing_configuration_revision c WHERE c.business_id=bid FOR UPDATE;
 IF revision<>expected THEN PERFORM ms_b1_design.b3_fail('STALE_CONFIGURATION','MS412');END IF;
 -- Re-read entity after the aggregate lock; no pre-lock stale draft/lifecycle decisions.
 IF op LIKE 'version.%' AND op<>'version.create' THEN SELECT * INTO v FROM ms_b1_design.booking_policy_version p WHERE p.business_id=bid AND p.id=entity FOR UPDATE;END IF;
 target:=coalesce(entity,gen_random_uuid());
 IF op='policy.create' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['code','name']);IF jsonb_typeof(d->'code')<>'string' OR jsonb_typeof(d->'name')<>'string' THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 INSERT INTO ms_b1_design.booking_policy(id,business_id,branch_id,code,name,created_by) VALUES(target,bid,branch,d->>'code',d->>'name',uid);
 ELSIF op IN('version.create','version.replace') THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['terms']);t:=d->'terms';PERFORM ms_b1_design.b3_validate_terms(t);
 IF op='version.create' THEN
 SELECT coalesce(max(p.version_number),0)+1 INTO version_no FROM ms_b1_design.booking_policy_version p WHERE p.business_id=bid AND p.policy_id=entity;target:=gen_random_uuid();
 INSERT INTO ms_b1_design.booking_policy_version(id,business_id,policy_id,version_number,effective_from,effective_to,deposit_requirement,amount_kind,fixed_rial,basis_points,minimum_rial,maximum_rial,refundability,refund_base,outside_refund_bps,cancellation_deadline_minutes,terms_text,terms_locale,created_by)
 VALUES(target,bid,entity,version_no,ms_b1_design.b3_instant(t->>'effectiveFrom'),CASE WHEN t->>'effectiveTo' IS NOT NULL THEN ms_b1_design.b3_instant(t->>'effectiveTo') END,t->>'depositRequirement',t->>'amountKind',(t->>'fixedRial')::bigint,(t->>'basisPoints')::int,(t->>'minimumRial')::bigint,(t->>'maximumRial')::bigint,t->>'refundability',t->>'refundBase',(t->>'outsideRefundBps')::int,(t->>'cancellationDeadlineMinutes')::int,t->>'termsText',t->>'termsLocale',uid);
 ELSE
 IF v.lifecycle<>'DRAFT' THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_POLICY');END IF;
 UPDATE ms_b1_design.booking_policy_version SET effective_from=ms_b1_design.b3_instant(t->>'effectiveFrom'),effective_to=CASE WHEN t->>'effectiveTo' IS NOT NULL THEN ms_b1_design.b3_instant(t->>'effectiveTo') END,
 deposit_requirement=t->>'depositRequirement',amount_kind=t->>'amountKind',fixed_rial=(t->>'fixedRial')::bigint,basis_points=(t->>'basisPoints')::int,minimum_rial=(t->>'minimumRial')::bigint,maximum_rial=(t->>'maximumRial')::bigint,
 refundability=t->>'refundability',refund_base=t->>'refundBase',outside_refund_bps=(t->>'outsideRefundBps')::int,cancellation_deadline_minutes=(t->>'cancellationDeadlineMinutes')::int,terms_text=t->>'termsText',terms_locale=t->>'termsLocale',row_version=row_version+1 WHERE business_id=bid AND id=target;
 DELETE FROM ms_b1_design.policy_refund_window q WHERE q.business_id=bid AND q.policy_version_id=target;END IF;
 FOR w IN SELECT value FROM jsonb_array_elements(t->'refundWindows') LOOP INSERT INTO ms_b1_design.policy_refund_window(business_id,policy_version_id,threshold_minutes,refund_bps) VALUES(bid,target,(w->>'thresholdMinutes')::int,(w->>'refundBps')::int);END LOOP;
 ELSIF op IN('version.publish','version.retire') THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY[]::text[]);
 IF op='version.publish' THEN
 IF v.lifecycle<>'DRAFT' THEN PERFORM ms_b1_design.b3_fail('INVALID_LIFECYCLE');END IF;t:=ms_b1_design.b3_terms(v);PERFORM ms_b1_design.b3_validate_terms(t);
 UPDATE ms_b1_design.booking_policy_version SET lifecycle='ACTIVE',published_at=clock_timestamp(),content_hash=ms_b1_design.b3_digest(t),row_version=row_version+1 WHERE business_id=bid AND id=entity;
 ELSE IF v.lifecycle<>'ACTIVE' THEN PERFORM ms_b1_design.b3_fail('INVALID_LIFECYCLE');END IF;
 UPDATE ms_b1_design.booking_policy_version SET lifecycle='RETIRED',row_version=row_version+1 WHERE business_id=bid AND id=entity;END IF;
 ELSIF op='assignment.create' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['versionId','scopeKind','serviceId','staffId','priority','effectiveFrom','effectiveTo','reason','serviceIds','compatibleVersionIds']);
 FOR key IN SELECT unnest(ARRAY['versionId','scopeKind','serviceId','staffId','priority','effectiveFrom','effectiveTo','reason']) LOOP IF jsonb_typeof(d->key) NOT IN('string','null') THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;END LOOP;
 IF jsonb_typeof(d->'serviceIds')<>'array' OR jsonb_typeof(d->'compatibleVersionIds')<>'array' OR jsonb_array_length(d->'serviceIds')>12 OR jsonb_array_length(d->'compatibleVersionIds')>12 THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 SELECT * INTO v FROM ms_b1_design.booking_policy_version p WHERE p.business_id=bid AND p.id=(d->>'versionId')::uuid;
 SELECT * INTO policy FROM ms_b1_design.booking_policy p WHERE p.business_id=bid AND p.id=v.policy_id;
 IF v.id IS NULL OR v.lifecycle<>'ACTIVE' OR (policy.branch_id IS NOT NULL AND policy.branch_id IS DISTINCT FROM branch) THEN PERFORM ms_b1_design.b3_fail('POLICY_SCOPE');END IF;
 starts:=ms_b1_design.b3_instant(d->>'effectiveFrom');ends:=CASE WHEN d->>'effectiveTo' IS NOT NULL THEN ms_b1_design.b3_instant(d->>'effectiveTo') END;
 IF starts<v.effective_from OR(v.effective_to IS NOT NULL AND(ends IS NULL OR ends>v.effective_to)) THEN PERFORM ms_b1_design.b3_fail('POLICY_WINDOW');END IF;
 service_ids:=ARRAY(SELECT value::uuid FROM jsonb_array_elements_text(d->'serviceIds') ORDER BY value);compatible_ids:=ARRAY(SELECT value::uuid FROM jsonb_array_elements_text(d->'compatibleVersionIds') ORDER BY value);
 IF cardinality(service_ids)<>(SELECT count(DISTINCT u.val) FROM unnest(service_ids) u(val)) OR cardinality(compatible_ids)<>(SELECT count(DISTINCT u.val) FROM unnest(compatible_ids) u(val)) THEN PERFORM ms_b1_design.b3_fail('DUPLICATE_SCOPE');END IF;
 IF d->>'scopeKind'='WHOLE_BOOKING' THEN
 IF cardinality(service_ids)=0 OR cardinality(compatible_ids)=0 OR jsonb_typeof(d->'reason')<>'string' OR d->>'reason' IS NULL OR length(btrim(d->>'reason')) NOT BETWEEN 1 AND 200 THEN PERFORM ms_b1_design.b3_fail('POLICY_SCOPE');END IF;
 IF EXISTS(SELECT 1 FROM unnest(compatible_ids) u(val) LEFT JOIN ms_b1_design.booking_policy_version p ON p.id=u.val AND p.business_id=bid LEFT JOIN ms_b1_design.booking_policy q ON q.id=p.policy_id AND q.business_id=p.business_id WHERE p.id IS NULL OR p.lifecycle<>'ACTIVE' OR(q.branch_id IS NOT NULL AND q.branch_id IS DISTINCT FROM branch)) THEN PERFORM ms_b1_design.b3_fail('POLICY_SCOPE');END IF;
 ELSIF cardinality(service_ids)<>0 OR cardinality(compatible_ids)<>0 OR d->>'reason' IS NOT NULL THEN PERFORM ms_b1_design.b3_fail('POLICY_SCOPE');END IF;
 IF d->>'staffId' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.staff s JOIN ms_b1_design.staff_branch_assignment m ON m.staff_id=s.id AND m.business_id=s.business_id JOIN ms_b1_design.branch b ON b.id=m.branch_id AND b.business_id=m.business_id
 WHERE s.business_id=bid AND s.id=(d->>'staffId')::uuid AND s.active AND s.archived_at IS NULL AND m.branch_id=branch AND m.active AND m.archived_at IS NULL AND m.voided_at IS NULL
 AND ms_b1_design.b2h_membership_window(m,(starts AT TIME ZONE b.time_zone)::date,((coalesce(ends,starts+interval '1 day')) AT TIME ZONE b.time_zone)::date+1,b.time_zone,false,clock_timestamp()) @> tstzrange(starts,coalesce(ends,starts+interval '1 day'),'[)') AND(ends IS NOT NULL OR m.valid_to IS NULL)) THEN PERFORM ms_b1_design.b3_fail('STAFF_NOT_APPLICABLE');END IF;
 key:=(d->>'scopeKind')||':'||coalesce(branch::text,'')||':'||coalesce(d->>'serviceId','')||':'||coalesce(d->>'staffId','')||':'||array_to_string(service_ids,',')||':'||array_to_string(compatible_ids,',');
 INSERT INTO ms_b1_design.booking_policy_assignment(id,business_id,policy_version_id,scope_kind,branch_id,service_id,staff_id,priority,effective_from,effective_to,override_reason,context_key,created_by)
 VALUES(target,bid,v.id,d->>'scopeKind',branch,(d->>'serviceId')::uuid,(d->>'staffId')::uuid,ms_b1_design.b3_nat(d->>'priority',1000)::integer,starts,ends,d->>'reason',key,uid);
 FOR x IN SELECT to_jsonb(s) FROM unnest(service_ids) s LOOP INSERT INTO ms_b1_design.policy_assignment_service(business_id,assignment_id,service_id) VALUES(bid,target,(x#>>'{}')::uuid);END LOOP;
 FOR x IN SELECT to_jsonb(s) FROM unnest(compatible_ids) s LOOP INSERT INTO ms_b1_design.policy_assignment_compatibility(business_id,assignment_id,policy_version_id) VALUES(bid,target,(x#>>'{}')::uuid);END LOOP;
 ELSIF op='assignment.revoke' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY[]::text[]);UPDATE ms_b1_design.booking_policy_assignment SET revoked_at=clock_timestamp() WHERE business_id=bid AND id=entity;
 ELSIF op='configuration.set' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['quoteTtlSeconds']);IF branch IS NULL OR jsonb_typeof(d->'quoteTtlSeconds')<>'string' OR ms_b1_design.b3_nat(d->>'quoteTtlSeconds',3600)<60 THEN PERFORM ms_b1_design.b3_fail('INVALID_TTL');END IF;
 INSERT INTO ms_b1_design.availability_configuration(business_id,branch_id,quote_ttl_seconds,created_by) VALUES(bid,branch,(d->>'quoteTtlSeconds')::int,uid)
 ON CONFLICT(business_id,branch_id) DO UPDATE SET quote_ttl_seconds=excluded.quote_ttl_seconds,row_version=availability_configuration.row_version+1,configuration_version=availability_configuration.configuration_version+1;
 ELSIF op='quote.create' THEN
 IF branch IS NULL THEN PERFORM ms_b1_design.b3_fail('BRANCH_REQUIRED');END IF;
 calc:=ms_b1_design.b3_calculate(bid,branch,d);content:=calc->'content';hash:=ms_b1_design.b3_digest(content);now_at:=clock_timestamp();
 INSERT INTO ms_b1_design.pricing_proposal(id,business_id,branch_id,created_by,policy_version_id,total_rial,deposit_rial,remaining_rial,configuration_fingerprint,content_hash,content_document,selectors,created_at,expires_at)
 VALUES(target,bid,branch,uid,(content->'policy'->>'versionId')::uuid,(content->>'totalRial')::bigint,(content->>'depositRial')::bigint,(content->>'remainingRial')::bigint,decode(content->>'configurationFingerprint','hex'),hash,content,d,now_at,now_at+make_interval(secs=>(calc->>'ttlSeconds')::int));
 FOR x IN SELECT value FROM jsonb_array_elements(content->'items') LOOP INSERT INTO ms_b1_design.pricing_proposal_item(business_id,proposal_id,offering_id,branch_id,service_id,position,offering_version,unit_price_rial,duration_minutes,buffer_before_minutes,buffer_after_minutes)
 VALUES(bid,target,(x->>'offeringId')::uuid,branch,(x->>'serviceId')::uuid,(x->>'position')::int,(x->>'offeringVersion')::bigint,(x->>'unitPriceRial')::bigint,(x->>'durationMinutes')::int,(x->>'bufferBeforeMinutes')::int,(x->>'bufferAfterMinutes')::int);END LOOP;
 FOR x IN SELECT DISTINCT jsonb_build_object('id',value->>'assignmentId') FROM jsonb_array_elements(content->'policy'->'sourceAssignments') LOOP INSERT INTO ms_b1_design.pricing_proposal_source(business_id,proposal_id,assignment_id) VALUES(bid,target,(x->>'id')::uuid);END LOOP;
 body:=jsonb_build_object('content',content,'contentHash',encode(hash,'hex'),'hashVersion','MS_COMMERCIAL_PROPOSAL_V1','issuedAt',ms_b1_design.b3_iso(now_at),'expiresAt',ms_b1_design.b3_iso(now_at+make_interval(secs=>(calc->>'ttlSeconds')::int)),'bookable',false,'capacityReserved',false,'finalQuoteAvailable',false);
 ELSE
 SELECT * INTO proposal FROM ms_b1_design.pricing_proposal p WHERE p.business_id=bid AND p.id=entity AND p.branch_id=branch AND p.created_by=uid;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF proposal.content_hash<>ms_b1_design.b3_digest(proposal.content_document) THEN PERFORM ms_b1_design.b3_fail('QUOTE_INTEGRITY','MS409');END IF;
 IF op='quote.validate' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['contentHash']);IF jsonb_typeof(d->'contentHash')<>'string' OR d->>'contentHash' IS DISTINCT FROM encode(proposal.content_hash,'hex') THEN PERFORM ms_b1_design.b3_fail('QUOTE_TAMPERED','MS409');END IF;
 IF proposal.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('QUOTE_EXPIRED','MS409');END IF;
 BEGIN calc:=ms_b1_design.b3_calculate(bid,branch,proposal.selectors);EXCEPTION WHEN SQLSTATE 'MS409' OR SQLSTATE 'MS422' OR SQLSTATE 'MS404' THEN PERFORM ms_b1_design.b3_fail('QUOTE_STALE','MS409');END;
 IF proposal.content_hash<>ms_b1_design.b3_digest(calc->'content') THEN PERFORM ms_b1_design.b3_fail('QUOTE_STALE','MS409');END IF;
 body:=jsonb_build_object('commerciallyCurrent',true,'finalQuoteAvailable',false,'capacityReserved',false);
 ELSE
 PERFORM ms_b1_design.b3_keys(d,ARRAY['cancellationAt']);starts:=ms_b1_design.b3_instant(proposal.content_document->>'startsAt');ends:=ms_b1_design.b3_instant(d->>'cancellationAt');t:=proposal.content_document->'policy'->'terms';
 minutes_before:=floor(extract(epoch FROM starts-ends)/60);rate:=(t->>'outsideRefundBps')::integer;
 IF ends<=starts THEN SELECT (value->>'refundBps')::integer INTO rate FROM jsonb_array_elements(t->'refundWindows') WHERE(value->>'thresholdMinutes')::int<=minutes_before ORDER BY(value->>'thresholdMinutes')::int DESC LIMIT 1;rate:=coalesce(rate,(t->>'outsideRefundBps')::int);END IF;
 base:=CASE WHEN t->>'refundBase'='DEPOSIT_PAID' THEN proposal.deposit_rial ELSE proposal.total_rial END;refund:=least(base,floor((base*rate+50000)/100000)*10);
 body:=jsonb_build_object('previewOnly',true,'usesFrozenTerms',true,'cancellationAllowed',minutes_before>=(t->>'cancellationDeadlineMinutes')::int,'minutesBeforeStart',minutes_before::text,'refundBps',rate::text,'illustrationAssumesPaidRial',base::text,'refundPreviewRial',refund::text,'moneyExecuted',false);
 END IF;END IF;
 IF op NOT LIKE 'quote.%' THEN UPDATE ms_b1_design.pricing_configuration_revision SET revision=pricing_configuration_revision.revision+1 WHERE business_id=bid RETURNING pricing_configuration_revision.revision INTO revision;END IF;
 body:=coalesce(body,'{}')||jsonb_build_object('id',target,'version',revision::text,'operation',op);result:=jsonb_build_object('status',200,'body',body);
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,branch_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES(bid,uid,branch,'b3.'||op,'pricing',target,requestid,jsonb_build_object('version',revision::text,'fields',(SELECT jsonb_agg(k ORDER BY k) FROM jsonb_object_keys(d) k)),uid);
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at,created_by) VALUES(bid,'pricing.command',requestid,1,'b3.'||op||'.committed',1,jsonb_build_object('id',target,'version',revision::text,'operation',op),clock_timestamp(),uid);
 INSERT INTO ms_b1_design.idempotency_record(business_id,actor_key,route_key,idempotency_key,request_hash,state,response_code,response_snapshot,expires_at,created_by) VALUES(bid,uid::text,route,idem,request_hash,'COMPLETE',200,result,clock_timestamp()+interval '24 hours',uid);
 RETURN result;END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA ms_b1_design FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ms_b1_design.b3_read(bytea,text,uuid,uuid,boolean,integer),ms_b1_design.b3_command(bytea,bytea,text,uuid,uuid,bigint,text,uuid,jsonb) TO ms_b1b_api;
