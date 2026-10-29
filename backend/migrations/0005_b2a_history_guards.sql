-- B2A reviewed local-row hardening. No new management API/grants or slot resolver.
SET search_path=pg_catalog;
ALTER TABLE ms_b1_design.branch_working_hours
 ADD CONSTRAINT b2a_hours_finite_from CHECK(isfinite(valid_from)),
 ADD CONSTRAINT b2a_hours_finite_to CHECK(valid_to IS NULL OR isfinite(valid_to));
ALTER TABLE ms_b1_design.staff_schedule_rule
 ADD CONSTRAINT b2a_rule_finite_from CHECK(isfinite(valid_from)),
 ADD CONSTRAINT b2a_rule_finite_to CHECK(valid_to IS NULL OR isfinite(valid_to));

CREATE FUNCTION ms_b1_design.b2a_revision_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE before_row jsonb; after_row jsonb; identity_keys text[]; key text;
BEGIN
 IF TG_OP='DELETE' THEN
  RAISE EXCEPTION USING ERRCODE='23514',CONSTRAINT='b2a_history_retained',MESSAGE='Archive history instead of deleting';
 END IF;
 before_row:=to_jsonb(OLD);after_row:=to_jsonb(NEW);
 IF NEW.row_version<>OLD.row_version+1 THEN
  RAISE EXCEPTION USING ERRCODE='23514',CONSTRAINT='b2a_next_row_version',MESSAGE='Exact next row version required';
 END IF;
 identity_keys:=ARRAY['id','business_id','created_at','created_by'];
 CASE TG_TABLE_NAME
 WHEN 'resource' THEN identity_keys:=identity_keys||ARRAY['kind','branch_id'];
 WHEN 'staff' THEN identity_keys:=identity_keys||ARRAY['resource_id','resource_kind'];
  IF OLD.user_id IS NOT NULL AND NEW.user_id IS DISTINCT FROM OLD.user_id THEN
   RAISE EXCEPTION USING ERRCODE='23514',CONSTRAINT='b2a_identity_frozen',MESSAGE='Linked staff user cannot change'; END IF;
 WHEN 'staff_branch_assignment' THEN
  identity_keys:=identity_keys||ARRAY['staff_id','branch_id','valid_from'];
  IF OLD.valid_to IS NOT NULL AND NEW.valid_to IS DISTINCT FROM OLD.valid_to THEN
   RAISE EXCEPTION USING ERRCODE='23514',CONSTRAINT='b2a_membership_end_frozen',MESSAGE='Closed membership remains historical'; END IF;
  IF OLD.voided_at IS NOT NULL AND (NEW.voided_at IS DISTINCT FROM OLD.voided_at OR NEW.void_reason IS DISTINCT FROM OLD.void_reason) THEN
   RAISE EXCEPTION USING ERRCODE='23514',CONSTRAINT='b2a_void_frozen',MESSAGE='Void correction cannot be silently undone'; END IF;
 WHEN 'staff_service_eligibility' THEN identity_keys:=identity_keys||ARRAY['staff_id','service_id'];
 WHEN 'offering_staff_eligibility' THEN identity_keys:=identity_keys||ARRAY['offering_id','branch_id','service_id','staff_id','assignment_id','qualification_id'];
 WHEN 'staff_shift' THEN identity_keys:=identity_keys||ARRAY['staff_id','branch_id','assignment_id'];
 WHEN 'availability_configuration' THEN
  identity_keys:=identity_keys||ARRAY['branch_id'];
  IF NEW.configuration_version<>OLD.configuration_version+1 THEN
   RAISE EXCEPTION USING ERRCODE='23514',CONSTRAINT='b2a_next_configuration_version',MESSAGE='Exact next configuration version required'; END IF;
 ELSE NULL;
 END CASE;
 FOREACH key IN ARRAY identity_keys LOOP
  IF after_row->key IS DISTINCT FROM before_row->key THEN
   RAISE EXCEPTION USING ERRCODE='23514',CONSTRAINT='b2a_identity_frozen',MESSAGE='Stable identity or reference cannot change'; END IF;
 END LOOP;
 IF OLD.archived_at IS NOT NULL AND NEW.archived_at IS DISTINCT FROM OLD.archived_at THEN
  RAISE EXCEPTION USING ERRCODE='23514',CONSTRAINT='b2a_archive_frozen',MESSAGE='Historical archive cannot be silently undone'; END IF;
 -- Rules/exceptions are immutable revisions. Published instants never move in place.
 -- Archive old evidence and insert a distinct successor; no automatic publication.
 IF TG_TABLE_NAME IN ('branch_working_hours','staff_schedule_rule','staff_time_off','branch_closure')
  OR (TG_TABLE_NAME='staff_shift' AND (before_row->>'published')::boolean) THEN
  -- Stored generated fields are not populated in NEW during a BEFORE trigger.
  -- Their source columns remain frozen; PostgreSQL itself forbids overriding them.
  IF (after_row-ARRAY['row_version','updated_at','archived_at','working_period','membership_period']) IS DISTINCT FROM
     (before_row-ARRAY['row_version','updated_at','archived_at','working_period','membership_period']) THEN
   RAISE EXCEPTION USING ERRCODE='23514',CONSTRAINT='b2a_revision_immutable',MESSAGE='Create a new schedule or exception revision'; END IF;
 END IF;
 NEW.updated_at:=clock_timestamp();RETURN NEW;
END $$;

CREATE FUNCTION ms_b1_design.b2a_branch_timezone_guard()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=NEW.time_zone
  AND name !~ '^(posix|right)/' AND (name='UTC' OR position('/' IN name)>0)) THEN
  RAISE EXCEPTION USING ERRCODE='23514',CONSTRAINT='b2a_branch_timezone',MESSAGE='Known IANA timezone required';
 END IF;
 RETURN NEW;
END $$;
DO $$BEGIN
 IF EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE NOT EXISTS
  (SELECT 1 FROM pg_catalog.pg_timezone_names t WHERE t.name=b.time_zone AND t.name !~ '^(posix|right)/'
   AND (t.name='UTC' OR position('/' IN t.name)>0))) THEN
  RAISE EXCEPTION USING ERRCODE='23514',CONSTRAINT='b2a_branch_timezone',MESSAGE='Existing invalid timezone requires reviewed correction';
 END IF;
END $$;
CREATE TRIGGER b2a_branch_timezone BEFORE INSERT OR UPDATE OF time_zone ON ms_b1_design.branch
 FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b2a_branch_timezone_guard();
CREATE TRIGGER b2a_revision BEFORE UPDATE OR DELETE ON ms_b1_design.resource FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b2a_revision_guard();
CREATE TRIGGER b2a_revision BEFORE UPDATE OR DELETE ON ms_b1_design.staff FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b2a_revision_guard();
CREATE TRIGGER b2a_revision BEFORE UPDATE OR DELETE ON ms_b1_design.staff_branch_assignment FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b2a_revision_guard();
CREATE TRIGGER b2a_revision BEFORE UPDATE OR DELETE ON ms_b1_design.staff_service_eligibility FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b2a_revision_guard();
CREATE TRIGGER b2a_revision BEFORE UPDATE OR DELETE ON ms_b1_design.offering_staff_eligibility FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b2a_revision_guard();
CREATE TRIGGER b2a_revision BEFORE UPDATE OR DELETE ON ms_b1_design.staff_schedule_rule FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b2a_revision_guard();
CREATE TRIGGER b2a_revision BEFORE UPDATE OR DELETE ON ms_b1_design.staff_shift FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b2a_revision_guard();
CREATE TRIGGER b2a_revision BEFORE UPDATE OR DELETE ON ms_b1_design.staff_time_off FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b2a_revision_guard();
CREATE TRIGGER b2a_revision BEFORE UPDATE OR DELETE ON ms_b1_design.branch_working_hours FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b2a_revision_guard();
CREATE TRIGGER b2a_revision BEFORE UPDATE OR DELETE ON ms_b1_design.branch_closure FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b2a_revision_guard();
CREATE TRIGGER b2a_revision BEFORE UPDATE OR DELETE ON ms_b1_design.availability_configuration FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b2a_revision_guard();
REVOKE ALL ON FUNCTION ms_b1_design.b2a_revision_guard(),ms_b1_design.b2a_branch_timezone_guard() FROM PUBLIC;
-- No new API/runtime grants. Temporal cross-row publication/exception reconciliation
-- remains a B2B transactional gate; these are not booking-admission constraints.
