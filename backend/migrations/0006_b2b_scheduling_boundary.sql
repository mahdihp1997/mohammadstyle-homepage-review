-- Forward-only B2B. No seeds, Booking tables, capacity allocation or payments.
SET search_path=pg_catalog;
CREATE TABLE ms_b1_design.workforce_calendar_revision(
 business_id uuid PRIMARY KEY REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT,
 version bigint NOT NULL DEFAULT 1 CHECK(version>0));
ALTER TABLE ms_b1_design.branch ADD COLUMN schedule_version bigint NOT NULL DEFAULT 1 CHECK(schedule_version>0);
ALTER TABLE ms_b1_design.staff ADD COLUMN identity_link_evidence_hash bytea CHECK(identity_link_evidence_hash IS NULL OR octet_length(identity_link_evidence_hash)=32);
ALTER TABLE ms_b1_design.staff_service_eligibility
 ADD COLUMN verification_evidence_hash bytea CHECK(verification_evidence_hash IS NULL OR octet_length(verification_evidence_hash)=32),
 ADD COLUMN verified_by uuid REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT;
ALTER TABLE ms_b1_design.staff_schedule_rule
 ADD COLUMN service_id uuid,
 ADD COLUMN qualification_id uuid,
 ADD COLUMN offering_id uuid,
 ADD CONSTRAINT b2b_rule_qualification FOREIGN KEY(business_id,qualification_id,staff_id,service_id)
 REFERENCES ms_b1_design.staff_service_eligibility(business_id,id,staff_id,service_id),
 ADD CONSTRAINT b2b_rule_offering FOREIGN KEY(business_id,offering_id,branch_id,service_id)
 REFERENCES ms_b1_design.branch_service_offering(business_id,id,branch_id,service_id),
 ADD CONSTRAINT b2b_rule_context CHECK((service_id IS NULL)=(qualification_id IS NULL));
ALTER TABLE ms_b1_design.staff_shift
 ADD COLUMN plan_id uuid, ADD COLUMN local_date date, ADD COLUMN time_zone text,
 ADD COLUMN start_minute smallint, ADD COLUMN end_minute smallint,
 ADD COLUMN start_resolution text, ADD COLUMN end_resolution text,
 ADD CONSTRAINT b2b_shift_local CHECK(local_date IS NULL OR
 (isfinite(local_date) AND time_zone IS NOT NULL AND start_minute>=0 AND end_minute<=1440 AND end_minute>start_minute
 AND start_resolution IN ('reject','earlier','later') AND end_resolution IN ('reject','earlier','later')));
-- Old exception approval was deliberately unspecified. Never promote it by inference.
ALTER TABLE ms_b1_design.staff_time_off ADD COLUMN review_status text NOT NULL DEFAULT 'LEGACY_UNREVIEWED',ADD COLUMN supersedes_id uuid,
 ADD CONSTRAINT b2b_timeoff_review CHECK(review_status IN ('LEGACY_UNREVIEWED','REQUESTED','APPROVED','REJECTED')
 AND (review_status NOT IN ('APPROVED','REJECTED') OR (approved_by IS NOT NULL AND supersedes_id IS NOT NULL))),
 ADD CONSTRAINT b2b_timeoff_review_identity UNIQUE(business_id,id),
 ADD CONSTRAINT b2b_timeoff_successor UNIQUE(business_id,supersedes_id),
 ADD CONSTRAINT b2b_timeoff_parent FOREIGN KEY(business_id,supersedes_id) REFERENCES ms_b1_design.staff_time_off(business_id,id);
ALTER TABLE ms_b1_design.branch_closure ADD COLUMN review_status text NOT NULL DEFAULT 'LEGACY_UNREVIEWED',ADD COLUMN supersedes_id uuid,
 ADD CONSTRAINT b2b_closure_review CHECK(review_status IN ('LEGACY_UNREVIEWED','REQUESTED','APPROVED','REJECTED')
 AND (review_status NOT IN ('APPROVED','REJECTED') OR (approved_by IS NOT NULL AND supersedes_id IS NOT NULL))),
 ADD CONSTRAINT b2b_closure_review_identity UNIQUE(business_id,id),
 ADD CONSTRAINT b2b_closure_successor UNIQUE(business_id,supersedes_id),
 ADD CONSTRAINT b2b_closure_parent FOREIGN KEY(business_id,supersedes_id) REFERENCES ms_b1_design.branch_closure(business_id,id);

CREATE FUNCTION ms_b1_design.b2b_fail(reason text, state text DEFAULT 'MS409') RETURNS void
 LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 RAISE EXCEPTION USING ERRCODE=state,MESSAGE=reason; END $$;

-- Bounded minute-precision Gregorian scheduling2020..2100. Enumerate, round-trip,
-- count all possible UTC instants; PostgreSQL's implicit fold choice is never used.
CREATE FUNCTION ms_b1_design.b2b_local_instant(local_value timestamp,zone text,resolution text)
 RETURNS timestamptz LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE candidates timestamptz[];
BEGIN
 IF local_value IS NULL OR local_value<'2020-01-01' OR local_value>='2101-01-01'
 OR resolution IS NULL OR resolution NOT IN ('reject','earlier','later') OR NOT EXISTS
 (SELECT 1 FROM pg_timezone_names WHERE name=zone AND name !~ '^(posix|right)/' AND (name='UTC' OR position('/' IN name)>0)) THEN
 PERFORM ms_b1_design.b2b_fail('INVALID_LOCAL_TIME','MS422'); END IF;
 SELECT array_agg(t ORDER BY t) INTO candidates FROM generate_series(
 local_value AT TIME ZONE 'UTC'-interval '16 hours',local_value AT TIME ZONE 'UTC'+interval '16 hours',interval '1 minute') t
 WHERE t AT TIME ZONE zone=local_value;
 IF cardinality(candidates) IS NULL THEN PERFORM ms_b1_design.b2b_fail('DST_GAP','MS422'); END IF;
 IF cardinality(candidates)>1 AND resolution='reject' THEN PERFORM ms_b1_design.b2b_fail('DST_FOLD_REVIEW_REQUIRED','MS422'); END IF;
 RETURN CASE WHEN resolution='later' THEN candidates[cardinality(candidates)] ELSE candidates[1] END;
END $$;

CREATE FUNCTION ms_b1_design.b2b_validate(op text,d jsonb) RETURNS void
 LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE keys text[];k text;v jsonb;
BEGIN
 keys:=CASE op
 WHEN 'staff.create' THEN ARRAY['displayName']
 WHEN 'staff.update' THEN ARRAY['displayName','active']
 WHEN 'staff.link' THEN ARRAY['userId','evidenceReference']
 WHEN 'assignment.create' THEN ARRAY['staffId','validFrom','validTo']
 WHEN 'assignment.close' THEN ARRAY['validTo','reason']
 WHEN 'qualification.set' THEN ARRAY['staffId','serviceId','active','evidenceReference']
 WHEN 'eligibility.set' THEN ARRAY['offeringId','assignmentId','qualificationId','active']
 WHEN 'resource.create' THEN ARRAY['kind','label','active']
 WHEN 'resource.update' THEN ARRAY['label','active']
 WHEN 'hours.replace' THEN ARRAY['segments','reason']
 WHEN 'rule.create' THEN ARRAY['staffId','assignmentId','qualificationId','offeringId','isoWeekday','startMinute','endMinute','validFrom','validTo']
 WHEN 'schedule.publish' THEN ARRAY['staffId','segments','replaces','reason','overnight']
 WHEN 'schedule.withdraw' THEN ARRAY['staffId','shiftIds','reason']
 WHEN 'timeoff.create' THEN ARRAY['staffId','startsAt','endsAt','reason']
 WHEN 'closure.create' THEN ARRAY['startsAt','endsAt','reason']
 WHEN 'timeoff.review' THEN ARRAY['approve','reason']
 WHEN 'closure.review' THEN ARRAY['approve','reason']
 WHEN 'configuration.set' THEN ARRAY['slotStrideMinutes','leadMinutes','horizonDays','holdTtlSeconds','quoteTtlSeconds']
 ELSE NULL END;
 IF keys IS NULL OR d IS NULL OR jsonb_typeof(d)<>'object' OR
 (SELECT array_agg(x ORDER BY x) FROM jsonb_object_keys(d) x) IS DISTINCT FROM (SELECT array_agg(x ORDER BY x) FROM unnest(keys) x) THEN
 PERFORM ms_b1_design.b2b_fail('INVALID_FIELDS','MS422'); END IF;
 FOREACH k IN ARRAY keys LOOP
 v:=d->k;
 IF k IN ('active','approve','overnight') AND jsonb_typeof(v)<>'boolean' THEN PERFORM ms_b1_design.b2b_fail('INVALID_BOOLEAN','MS422'); END IF;
 IF k IN ('displayName','label','reason','evidenceReference','kind') AND
 (jsonb_typeof(v)<>'string' OR length(btrim(d->>k)) NOT BETWEEN 1 AND 200) THEN PERFORM ms_b1_design.b2b_fail('INVALID_TEXT','MS422'); END IF;
 IF k LIKE '%Id' AND NOT(k='offeringId' AND v='null') AND
 (jsonb_typeof(v)<>'string' OR d->>k !~ '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$') THEN PERFORM ms_b1_design.b2b_fail('INVALID_ID','MS422'); END IF;
 IF k IN ('segments','replaces','shiftIds') AND (jsonb_typeof(v)<>'array' OR jsonb_array_length(v)>62) THEN PERFORM ms_b1_design.b2b_fail('INVALID_BOUND','MS422'); END IF;
 IF k IN ('validFrom','validTo') AND NOT(k='validTo' AND v='null') AND
 (jsonb_typeof(v)<>'string' OR d->>k !~ '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' OR (d->>k)::date<'2020-01-01' OR (d->>k)::date>='2101-01-01') THEN PERFORM ms_b1_design.b2b_fail('INVALID_DATE','MS422'); END IF;
 IF k IN ('startsAt','endsAt') AND (jsonb_typeof(v)<>'string' OR d->>k !~ '^20[0-9T:Z.\-]+Z$' OR NOT isfinite((d->>k)::timestamptz)) THEN PERFORM ms_b1_design.b2b_fail('INVALID_INSTANT','MS422'); END IF;
 IF k IN ('isoWeekday','startMinute','endMinute','slotStrideMinutes','leadMinutes','horizonDays','holdTtlSeconds','quoteTtlSeconds') AND
 NOT(v='null' AND op='configuration.set') AND (jsonb_typeof(v)<>'number' OR d->>k !~ '^[0-9]{1,5}$') THEN PERFORM ms_b1_design.b2b_fail('INVALID_INTEGER','MS422'); END IF;
 END LOOP;
END $$;

-- The business advisory gate serializes this small administrative workload.
-- Auth user/session -> business gate -> sorted branches -> sorted global resources
-- -> existing version/exception rows. No out-of-order lock set expansion.
CREATE FUNCTION ms_b1_design.b2b_lock(bid uuid) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('b2b:'||bid::text,0));
 PERFORM 1 FROM ms_b1_design.branch WHERE business_id=bid ORDER BY id FOR UPDATE;
 PERFORM 1 FROM ms_b1_design.resource WHERE business_id=bid ORDER BY id FOR UPDATE;
END $$;

CREATE FUNCTION ms_b1_design.b2b_check_shift(bid uuid,sid uuid,branchid uuid,assignmentid uuid,ruleid uuid,day date,sm int,em int,zone text,st timestamptz,en timestamptz)
 RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE r ms_b1_design.staff_schedule_rule; m ms_b1_design.staff_branch_assignment; q ms_b1_design.staff_service_eligibility;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.branch WHERE business_id=bid AND id=branchid AND active AND archived_at IS NULL AND time_zone=zone)
 OR NOT EXISTS(SELECT 1 FROM ms_b1_design.staff s JOIN ms_b1_design.resource u ON u.business_id=s.business_id AND u.id=s.resource_id
 WHERE s.business_id=bid AND s.id=sid AND s.active AND s.archived_at IS NULL AND u.active AND u.archived_at IS NULL AND u.kind='STAFF') THEN
 PERFORM ms_b1_design.b2b_fail('INACTIVE_CONTEXT'); END IF;
 SELECT * INTO m FROM ms_b1_design.staff_branch_assignment WHERE business_id=bid AND id=assignmentid AND staff_id=sid AND branch_id=branchid;
 IF NOT FOUND OR NOT m.active OR m.archived_at IS NOT NULL OR m.voided_at IS NOT NULL OR NOT(m.membership_period @> day)
 OR st < ms_b1_design.b2b_local_instant(m.valid_from::timestamp,zone,'reject') OR (m.valid_to IS NOT NULL AND en > ms_b1_design.b2b_local_instant(m.valid_to::timestamp,zone,'reject')) THEN
 PERFORM ms_b1_design.b2b_fail('MEMBERSHIP_NOT_COVERED'); END IF;
 SELECT * INTO r FROM ms_b1_design.staff_schedule_rule WHERE business_id=bid AND id=ruleid AND staff_id=sid AND branch_id=branchid AND assignment_id=assignmentid;
 IF NOT FOUND OR r.archived_at IS NOT NULL OR r.iso_weekday<>extract(isodow FROM day) OR r.start_minute<>sm OR r.end_minute<>em OR
 day<r.valid_from OR (r.valid_to IS NOT NULL AND day>=r.valid_to) OR r.qualification_id IS NULL THEN PERFORM ms_b1_design.b2b_fail('RULE_NOT_APPLICABLE'); END IF;
 SELECT * INTO q FROM ms_b1_design.staff_service_eligibility WHERE business_id=bid AND id=r.qualification_id AND staff_id=sid AND service_id=r.service_id;
 IF NOT FOUND OR NOT q.active OR q.verified_at IS NULL OR q.archived_at IS NOT NULL OR NOT EXISTS
 (SELECT 1 FROM ms_b1_design.service WHERE business_id=bid AND id=q.service_id AND active AND archived_at IS NULL) THEN PERFORM ms_b1_design.b2b_fail('QUALIFICATION_REQUIRED'); END IF;
 IF r.offering_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.offering_staff_eligibility e JOIN ms_b1_design.branch_service_offering o
 ON o.business_id=e.business_id AND o.id=e.offering_id WHERE e.business_id=bid AND e.staff_id=sid AND e.branch_id=branchid AND e.assignment_id=assignmentid
 AND e.offering_id=r.offering_id AND e.qualification_id=q.id AND e.active AND e.archived_at IS NULL AND o.archived_at IS NULL) THEN
 PERFORM ms_b1_design.b2b_fail('OFFERING_ELIGIBILITY_REQUIRED'); END IF;
 -- Every local minute must be covered by reviewed effective opening segments.
 IF EXISTS(SELECT 1 FROM generate_series(sm,em-1) minute WHERE NOT EXISTS(SELECT 1 FROM ms_b1_design.branch_working_hours h
 WHERE h.business_id=bid AND h.branch_id=branchid AND h.archived_at IS NULL AND h.iso_weekday=extract(isodow FROM day)
 AND day>=h.valid_from AND (h.valid_to IS NULL OR day<h.valid_to) AND minute>=h.start_minute AND minute<h.end_minute)) THEN
 PERFORM ms_b1_design.b2b_fail('OUTSIDE_OPENING_HOURS'); END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.staff_time_off x WHERE x.business_id=bid AND x.staff_id=sid AND x.archived_at IS NULL
 AND x.review_status IN ('APPROVED','LEGACY_UNREVIEWED') AND x.starts_at<en AND x.ends_at>st
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.staff_time_off n WHERE n.business_id=bid AND n.supersedes_id=x.id)) THEN
 PERFORM ms_b1_design.b2b_fail('TIME_OFF_CONFLICT'); END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.branch_closure x WHERE x.business_id=bid AND x.branch_id=branchid AND x.archived_at IS NULL
 AND x.review_status IN ('APPROVED','LEGACY_UNREVIEWED') AND x.starts_at<en AND x.ends_at>st
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch_closure n WHERE n.business_id=bid AND n.supersedes_id=x.id)) THEN
 PERFORM ms_b1_design.b2b_fail('CLOSURE_CONFLICT'); END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.staff_shift x WHERE x.business_id=bid AND x.staff_id=sid AND x.published AND x.archived_at IS NULL AND x.branch_id<>branchid) THEN
 PERFORM ms_b1_design.b2b_fail('TRANSFER_CONFIGURATION_REQUIRED'); END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.staff_shift x WHERE x.staff_id=sid AND x.published AND x.archived_at IS NULL AND x.starts_at<en AND x.ends_at>st) THEN
 PERFORM ms_b1_design.b2b_fail('SHIFT_OVERLAP'); END IF;
END $$;
