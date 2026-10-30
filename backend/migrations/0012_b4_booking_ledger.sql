-- B4 dependency-closed booking cohort. No seeds, payments, activation or old-DDL edits.
SET search_path=ms_b1_design,public;
CREATE TABLE booking_plan (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,branch_id uuid NOT NULL,created_by uuid NOT NULL REFERENCES app_user(id),
 selectors jsonb NOT NULL,content_document jsonb NOT NULL,terms_document jsonb NOT NULL,content_hash bytea NOT NULL CHECK(octet_length(content_hash)=32),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),expires_at timestamptz NOT NULL CHECK(isfinite(expires_at)),
 UNIQUE(business_id,id),FOREIGN KEY(business_id,branch_id) REFERENCES branch(business_id,id),CHECK(expires_at>created_at)
);
CREATE TABLE pricing_quote (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,branch_id uuid NOT NULL,created_by uuid NOT NULL REFERENCES app_user(id),plan_id uuid NOT NULL,
 content_document jsonb NOT NULL CHECK(content_document->>'schema'='MS_QUOTE_CONTENT_V2'),terms_document jsonb NOT NULL,content_hash bytea NOT NULL CHECK(octet_length(content_hash)=32),
 policy_version_id uuid NOT NULL,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),expires_at timestamptz NOT NULL,
 UNIQUE(business_id,id),UNIQUE(business_id,id,branch_id),FOREIGN KEY(business_id,branch_id) REFERENCES branch(business_id,id),
 FOREIGN KEY(business_id,plan_id) REFERENCES booking_plan(business_id,id),FOREIGN KEY(business_id,policy_version_id) REFERENCES booking_policy_version(business_id,id),
 CHECK(isfinite(expires_at) AND expires_at>created_at)
);
-- Hash is content integrity, deliberately NONUNIQUE. Identity is quote UUID + owner.
CREATE TABLE pricing_quote_item (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,quote_id uuid NOT NULL,position integer NOT NULL CHECK(position BETWEEN 1 AND 12),
 offering_id uuid NOT NULL,branch_id uuid NOT NULL,service_id uuid NOT NULL,item_document jsonb NOT NULL,
 UNIQUE(business_id,quote_id,position),FOREIGN KEY(business_id,quote_id,branch_id) REFERENCES pricing_quote(business_id,id,branch_id),
 FOREIGN KEY(business_id,offering_id,branch_id,service_id) REFERENCES branch_service_offering(business_id,id,branch_id,service_id)
);
CREATE TABLE quote_policy_source (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,quote_id uuid NOT NULL,position integer NOT NULL,assignment_id uuid NOT NULL,
 UNIQUE(business_id,quote_id,position),FOREIGN KEY(business_id,quote_id,position) REFERENCES pricing_quote_item(business_id,quote_id,position),
 FOREIGN KEY(business_id,assignment_id) REFERENCES booking_policy_assignment(business_id,id)
);
CREATE TABLE booking (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,branch_id uuid NOT NULL,created_by uuid NOT NULL REFERENCES app_user(id),
 status text NOT NULL DEFAULT 'DRAFT' CHECK(status IN('DRAFT','HELD','PENDING_PAYMENT','CONFIRMED','CANCELLED','EXPIRED')),
 plan_committed boolean NOT NULL DEFAULT false,active_revision_id uuid,draft_expires_at timestamptz DEFAULT clock_timestamp()+interval '15 minutes',
 row_version bigint NOT NULL DEFAULT 1 CHECK(row_version>0),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,id),UNIQUE(business_id,id,branch_id),FOREIGN KEY(business_id,branch_id) REFERENCES branch(business_id,id),
 CHECK((NOT plan_committed AND active_revision_id IS NULL AND status IN('DRAFT','CANCELLED','EXPIRED') AND draft_expires_at IS NOT NULL AND isfinite(draft_expires_at)) OR
 (plan_committed AND active_revision_id IS NOT NULL AND status<>'DRAFT' AND draft_expires_at IS NULL))
);
CREATE TABLE booking_revision (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,booking_id uuid NOT NULL,branch_id uuid NOT NULL,quote_id uuid NOT NULL,
 revision_number integer NOT NULL CHECK(revision_number>0),supersedes_revision_id uuid,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,id),UNIQUE(business_id,id,booking_id),UNIQUE(business_id,id,quote_id),UNIQUE(business_id,id,branch_id),UNIQUE(business_id,booking_id,revision_number),UNIQUE(business_id,quote_id),
 FOREIGN KEY(business_id,booking_id,branch_id) REFERENCES booking(business_id,id,branch_id),FOREIGN KEY(business_id,quote_id,branch_id) REFERENCES pricing_quote(business_id,id,branch_id),
 FOREIGN KEY(business_id,supersedes_revision_id,booking_id) REFERENCES booking_revision(business_id,id,booking_id)
);
ALTER TABLE booking ADD CONSTRAINT booking_active_own_revision FOREIGN KEY(business_id,active_revision_id,id) REFERENCES booking_revision(business_id,id,booking_id) DEFERRABLE INITIALLY DEFERRED;
CREATE TABLE booking_service_segment (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,revision_id uuid NOT NULL,quote_id uuid NOT NULL,position integer NOT NULL,staff_id uuid NOT NULL,
 starts_at timestamptz NOT NULL,ends_at timestamptz NOT NULL,segment_document jsonb NOT NULL,
 UNIQUE(business_id,id,revision_id),UNIQUE(business_id,revision_id,position),CHECK(isfinite(starts_at) AND isfinite(ends_at) AND ends_at>starts_at),
 FOREIGN KEY(business_id,revision_id,quote_id) REFERENCES booking_revision(business_id,id,quote_id),
 FOREIGN KEY(business_id,quote_id,position) REFERENCES pricing_quote_item(business_id,quote_id,position),FOREIGN KEY(business_id,staff_id) REFERENCES staff(business_id,id)
);
CREATE TABLE booking_hold (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,booking_id uuid NOT NULL,revision_id uuid NOT NULL,expires_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),released_at timestamptz,
 UNIQUE(business_id,id,revision_id),UNIQUE(business_id,revision_id),FOREIGN KEY(business_id,revision_id,booking_id) REFERENCES booking_revision(business_id,id,booking_id),
 CHECK(isfinite(expires_at) AND expires_at>created_at),CHECK(released_at IS NULL OR isfinite(released_at))
);
CREATE TABLE resource_allocation (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,branch_id uuid NOT NULL,revision_id uuid NOT NULL,hold_id uuid NOT NULL,
 resource_id uuid NOT NULL,resource_kind text NOT NULL,resource_branch_id uuid,busy_starts_at timestamptz NOT NULL,busy_ends_at timestamptz NOT NULL,
 released_at timestamptz,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 busy_period tstzrange GENERATED ALWAYS AS(tstzrange(busy_starts_at,busy_ends_at,'[)')) STORED,
 UNIQUE(business_id,id,revision_id,resource_id),FOREIGN KEY(business_id,revision_id,branch_id) REFERENCES booking_revision(business_id,id,branch_id),
 FOREIGN KEY(business_id,hold_id,revision_id) REFERENCES booking_hold(business_id,id,revision_id),FOREIGN KEY(business_id,resource_id,resource_kind) REFERENCES resource(business_id,id,kind),
 FOREIGN KEY(business_id,resource_id,resource_branch_id) REFERENCES resource(business_id,id,branch_id),
 CHECK((resource_kind='STAFF' AND resource_branch_id IS NULL) OR(resource_kind<>'STAFF' AND resource_branch_id=branch_id AND resource_branch_id IS NOT NULL)),
 CHECK(isfinite(busy_starts_at) AND isfinite(busy_ends_at) AND busy_ends_at>busy_starts_at),CHECK(released_at IS NULL OR isfinite(released_at)),
 CONSTRAINT no_live_resource_overlap EXCLUDE USING gist(resource_id WITH =,busy_period WITH &&) WHERE(released_at IS NULL)
);
CREATE TABLE segment_resource_assignment (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,segment_id uuid NOT NULL,revision_id uuid NOT NULL,resource_id uuid NOT NULL,allocation_id uuid NOT NULL,
 UNIQUE(business_id,segment_id,resource_id),FOREIGN KEY(business_id,segment_id,revision_id) REFERENCES booking_service_segment(business_id,id,revision_id),
 FOREIGN KEY(business_id,allocation_id,revision_id,resource_id) REFERENCES resource_allocation(business_id,id,revision_id,resource_id)
);
CREATE TABLE booking_status_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,booking_id uuid NOT NULL,revision_id uuid,actor_user_id uuid REFERENCES app_user(id),
 from_status text,to_status text NOT NULL,event_type text NOT NULL,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(business_id,booking_id) REFERENCES booking(business_id,id),FOREIGN KEY(business_id,revision_id,booking_id) REFERENCES booking_revision(business_id,id,booking_id)
);
CREATE TABLE booking_policy_acceptance (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,booking_id uuid NOT NULL,revision_id uuid NOT NULL,quote_id uuid NOT NULL,
 accepted_by uuid NOT NULL REFERENCES app_user(id),quote_hash bytea NOT NULL CHECK(octet_length(quote_hash)=32),snapshot_hash bytea NOT NULL CHECK(octet_length(snapshot_hash)=32),
 accepted_at timestamptz NOT NULL DEFAULT clock_timestamp(),UNIQUE(business_id,revision_id),
 FOREIGN KEY(business_id,revision_id,booking_id) REFERENCES booking_revision(business_id,id,booking_id),FOREIGN KEY(business_id,revision_id,quote_id) REFERENCES booking_revision(business_id,id,quote_id)
);
CREATE INDEX booking_owner_history ON booking(business_id,created_by,created_at,id);
CREATE INDEX booking_expiring_drafts ON booking(draft_expires_at,id) WHERE status='DRAFT';
CREATE INDEX booking_expiring_holds ON booking_hold(expires_at,id) WHERE released_at IS NULL;
CREATE INDEX booking_revision_parent ON booking_revision(business_id,booking_id);
CREATE INDEX allocation_revision ON resource_allocation(business_id,revision_id);
CREATE INDEX segment_staff_fk ON booking_service_segment(business_id,staff_id);
CREATE INDEX quote_plan_fk ON pricing_quote(business_id,plan_id);
CREATE INDEX quote_policy_fk ON pricing_quote(business_id,policy_version_id);
CREATE INDEX quote_item_offering_fk ON pricing_quote_item(business_id,offering_id);
CREATE INDEX quote_source_assignment_fk ON quote_policy_source(business_id,assignment_id);
CREATE TRIGGER freeze_plan BEFORE UPDATE OR DELETE ON booking_plan FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_final_quote BEFORE UPDATE OR DELETE ON pricing_quote FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_final_item BEFORE UPDATE OR DELETE ON pricing_quote_item FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_final_source BEFORE UPDATE OR DELETE ON quote_policy_source FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_revision BEFORE UPDATE OR DELETE ON booking_revision FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_segment BEFORE UPDATE OR DELETE ON booking_service_segment FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_segment_assignment BEFORE UPDATE OR DELETE ON segment_resource_assignment FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_booking_acceptance BEFORE UPDATE OR DELETE ON booking_policy_acceptance FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
CREATE TRIGGER freeze_booking_history BEFORE UPDATE OR DELETE ON booking_status_history FOR EACH ROW EXECUTE FUNCTION ms_b1_design.b3_freeze();
REVOKE ALL ON booking_plan,pricing_quote,pricing_quote_item,quote_policy_source,booking,booking_revision,booking_service_segment,booking_hold,resource_allocation,segment_resource_assignment,booking_status_history,booking_policy_acceptance FROM PUBLIC,ms_b1a_runtime,ms_b1b_api;
