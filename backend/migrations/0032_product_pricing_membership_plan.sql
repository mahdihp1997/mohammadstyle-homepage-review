-- Actual pg_stat_user_functions: 2,778 membership-window calls for six candidates;
-- join qualification/membership IDs and scope FIRST, then evaluate the identical temporal predicate.
-- This changes evaluation work, not pricing, eligibility, policy or snapshot semantics.
CREATE OR REPLACE FUNCTION ms_b1_design.b3_calculate(bid uuid,branch uuid,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
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
 AND ms_b1_design.b2h_membership_window(m::ms_b1_design.staff_branch_assignment,(st AT TIME ZONE br.time_zone)::date,(en AT TIME ZONE br.time_zone)::date+1,br.time_zone,false,clock_timestamp()) @> tstzrange(st,en,'[)');
 IF membership_evidence IS NULL THEN PERFORM ms_b1_design.b3_fail('STAFF_NOT_APPLICABLE');END IF;
 END IF;
 FOR entry IN SELECT value FROM jsonb_array_elements(items) LOOP
 IF sid IS NOT NULL AND NOT EXISTS(
 WITH matching_memberships AS MATERIALIZED (
 SELECT m.* FROM ms_b1_design.offering_staff_eligibility e
 JOIN ms_b1_design.staff_service_eligibility q ON q.id=e.qualification_id AND q.business_id=e.business_id
 JOIN ms_b1_design.staff_branch_assignment m ON m.id=e.assignment_id AND m.business_id=e.business_id
 WHERE e.business_id=bid AND e.branch_id=branch AND e.staff_id=sid AND e.offering_id=(entry->>'offeringId')::uuid
 AND e.active AND e.archived_at IS NULL AND q.active AND q.archived_at IS NULL AND q.verified_at IS NOT NULL
 AND m.active AND m.archived_at IS NULL AND m.voided_at IS NULL)
 SELECT 1 FROM matching_memberships m WHERE ms_b1_design.b2h_membership_window(m,(st AT TIME ZONE br.time_zone)::date,(en AT TIME ZONE br.time_zone)::date+1,br.time_zone,false,clock_timestamp()) @> tstzrange(st,en,'[)')) THEN PERFORM ms_b1_design.b3_fail('STAFF_NOT_ELIGIBLE');END IF;
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


