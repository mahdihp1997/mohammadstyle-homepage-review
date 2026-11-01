-- Preserve the canonical business mutex and fail-closed review for affected
-- reservations. An unrelated branch no longer freezes the entire business.
SET search_path=pg_catalog;
CREATE OR REPLACE FUNCTION ms_b1_design.b4_schedule_guard() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE bid uuid;o jsonb;n jsonb;branches uuid[];resources uuid[];staffids uuid[];
BEGIN
 IF TG_OP<>'INSERT' THEN o:=to_jsonb(OLD);END IF;
 IF TG_OP<>'DELETE' THEN n:=to_jsonb(NEW);END IF;
 bid:=coalesce((n->>'business_id')::uuid,(o->>'business_id')::uuid);
 PERFORM ms_b1_design.b2b_lock(bid);
 IF TG_TABLE_NAME='branch' THEN branches:=array_remove(ARRAY[(o->>'id')::uuid,(n->>'id')::uuid],NULL);
 ELSIF TG_TABLE_NAME IN('availability_configuration','branch_working_hours','branch_closure','staff_shift','staff_time_off','staff_branch_assignment','offering_staff_eligibility','offering_resource_requirement') THEN
  branches:=array_remove(ARRAY[(o->>'branch_id')::uuid,(n->>'branch_id')::uuid],NULL);
  -- Global staff time off has no branch: protect the employee in every branch.
  IF cardinality(branches)=0 THEN staffids:=array_remove(ARRAY[(o->>'staff_id')::uuid,(n->>'staff_id')::uuid],NULL);END IF;
 ELSIF TG_TABLE_NAME='resource' THEN resources:=array_remove(ARRAY[(o->>'id')::uuid,(n->>'id')::uuid],NULL);
 ELSIF TG_TABLE_NAME='staff' THEN staffids:=array_remove(ARRAY[(o->>'id')::uuid,(n->>'id')::uuid],NULL);
 ELSIF TG_TABLE_NAME='staff_service_eligibility' THEN staffids:=array_remove(ARRAY[(o->>'staff_id')::uuid,(n->>'staff_id')::uuid],NULL);
 END IF;
 IF staffids IS NOT NULL THEN SELECT array_agg(s.resource_id) INTO resources FROM ms_b1_design.staff s WHERE s.business_id=bid AND s.id=ANY(staffids);END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.resource_allocation a WHERE a.business_id=bid AND a.released_at IS NULL AND a.busy_ends_at>clock_timestamp()
  AND(CASE WHEN cardinality(branches)>0 THEN a.branch_id=ANY(branches) WHEN cardinality(resources)>0 THEN a.resource_id=ANY(resources) ELSE true END)) THEN
  PERFORM ms_b1_design.b3_fail('LIVE_RESERVATIONS_REQUIRE_REVIEW','MS409');
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD;ELSE RETURN NEW;END IF;
END $$;
