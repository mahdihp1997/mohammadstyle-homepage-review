-- Dependency-safe B3 commercial evidence. No booking/customer/payment/planner tables.
SET search_path=ms_b1_design,public;
CREATE TABLE pricing_configuration_revision (
 business_id uuid PRIMARY KEY REFERENCES business(id), revision bigint NOT NULL DEFAULT 1 CHECK(revision>0)
);
CREATE TABLE booking_policy (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL REFERENCES business(id),
 branch_id uuid,code text NOT NULL CHECK(code ~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'),name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 200),
 created_by uuid NOT NULL REFERENCES app_user(id),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,id),UNIQUE(business_id,code),FOREIGN KEY(business_id,branch_id) REFERENCES branch(business_id,id)
);
CREATE TABLE booking_policy_version (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,policy_id uuid NOT NULL,
 version_number integer NOT NULL CHECK(version_number>0),row_version bigint NOT NULL DEFAULT 1 CHECK(row_version>0),
 lifecycle text NOT NULL DEFAULT 'DRAFT' CHECK(lifecycle IN('DRAFT','ACTIVE','RETIRED')),
 effective_from timestamptz NOT NULL CHECK(isfinite(effective_from)),effective_to timestamptz,
 deposit_requirement text NOT NULL CHECK(deposit_requirement IN('NONE','OPTIONAL','REQUIRED')),
 amount_kind text,fixed_rial bigint,basis_points integer,minimum_rial bigint,maximum_rial bigint,
 refundability text NOT NULL CHECK(refundability IN('FULL','NONE','PARTIAL','CONDITIONAL')),
 refund_base text NOT NULL CHECK(refund_base IN('DEPOSIT_PAID','ALL_PAID')),
 outside_refund_bps integer NOT NULL CHECK(outside_refund_bps BETWEEN 0 AND 10000),
 cancellation_deadline_minutes integer NOT NULL CHECK(cancellation_deadline_minutes BETWEEN 0 AND 525600),
 terms_text text NOT NULL CHECK(length(btrim(terms_text)) BETWEEN 1 AND 8000),terms_locale text NOT NULL CHECK(terms_locale ~ '^[a-z]{2}(-[A-Z]{2})?$'),
 content_hash bytea,published_at timestamptz,created_by uuid NOT NULL REFERENCES app_user(id),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,id),UNIQUE(business_id,policy_id,version_number),
 FOREIGN KEY(business_id,policy_id) REFERENCES booking_policy(business_id,id),
 CHECK(effective_to IS NULL OR (isfinite(effective_to) AND effective_to>effective_from)),
 CHECK((deposit_requirement='NONE' AND num_nonnulls(amount_kind,fixed_rial,basis_points,minimum_rial,maximum_rial)=0) OR
 (deposit_requirement<>'NONE' AND amount_kind IS NOT NULL AND
 ((amount_kind='FIXED' AND fixed_rial IS NOT NULL AND fixed_rial>0 AND fixed_rial%10=0 AND basis_points IS NULL) OR
 (amount_kind='PERCENTAGE' AND basis_points IS NOT NULL AND basis_points BETWEEN 1 AND 10000 AND fixed_rial IS NULL)))),
 CHECK(minimum_rial IS NULL OR (minimum_rial>=0 AND minimum_rial%10=0)),CHECK(maximum_rial IS NULL OR (maximum_rial>=0 AND maximum_rial%10=0)),
 CHECK(minimum_rial IS NULL OR maximum_rial IS NULL OR minimum_rial<=maximum_rial),
 CHECK((lifecycle='DRAFT' AND published_at IS NULL AND content_hash IS NULL) OR
 (lifecycle<>'DRAFT' AND published_at IS NOT NULL AND content_hash IS NOT NULL AND octet_length(content_hash)=32))
);
CREATE TABLE policy_refund_window (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,policy_version_id uuid NOT NULL,
 threshold_minutes integer NOT NULL CHECK(threshold_minutes BETWEEN 0 AND 525600),refund_bps integer NOT NULL CHECK(refund_bps BETWEEN 0 AND 10000),
 UNIQUE(business_id,policy_version_id,threshold_minutes),FOREIGN KEY(business_id,policy_version_id) REFERENCES booking_policy_version(business_id,id)
);
CREATE TABLE booking_policy_assignment (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,policy_version_id uuid NOT NULL,
 scope_kind text NOT NULL CHECK(scope_kind IN('BUSINESS','BRANCH','SERVICE','STAFF','STAFF_SERVICE','WHOLE_BOOKING')),
 branch_id uuid,service_id uuid,staff_id uuid,priority integer NOT NULL CHECK(priority BETWEEN 0 AND 1000),
 effective_from timestamptz NOT NULL CHECK(isfinite(effective_from)),effective_to timestamptz,
 context_key text NOT NULL,override_reason text,revoked_at timestamptz,created_by uuid NOT NULL REFERENCES app_user(id),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 applicable_period tstzrange GENERATED ALWAYS AS(tstzrange(effective_from,effective_to,'[)')) STORED,
 UNIQUE(business_id,id),FOREIGN KEY(business_id,policy_version_id) REFERENCES booking_policy_version(business_id,id),
 FOREIGN KEY(business_id,branch_id) REFERENCES branch(business_id,id),FOREIGN KEY(business_id,service_id) REFERENCES service(business_id,id),
 FOREIGN KEY(business_id,staff_id) REFERENCES staff(business_id,id),
 CHECK(effective_to IS NULL OR (isfinite(effective_to) AND effective_to>effective_from)),
 CHECK((scope_kind='BUSINESS' AND num_nonnulls(branch_id,service_id,staff_id)=0) OR
 (scope_kind='BRANCH' AND branch_id IS NOT NULL AND service_id IS NULL AND staff_id IS NULL) OR
 (scope_kind='SERVICE' AND service_id IS NOT NULL AND staff_id IS NULL) OR
 (scope_kind='STAFF' AND branch_id IS NOT NULL AND staff_id IS NOT NULL AND service_id IS NULL) OR
 (scope_kind='STAFF_SERVICE' AND branch_id IS NOT NULL AND staff_id IS NOT NULL AND service_id IS NOT NULL) OR
 (scope_kind='WHOLE_BOOKING' AND branch_id IS NOT NULL AND service_id IS NULL AND staff_id IS NULL AND override_reason IS NOT NULL AND length(btrim(override_reason)) BETWEEN 1 AND 200)),
 EXCLUDE USING gist(business_id WITH =,context_key WITH =,priority WITH =,applicable_period WITH &&) WHERE(revoked_at IS NULL)
);
CREATE TABLE policy_assignment_service (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,assignment_id uuid NOT NULL,service_id uuid NOT NULL,
 UNIQUE(business_id,assignment_id,service_id),FOREIGN KEY(business_id,assignment_id) REFERENCES booking_policy_assignment(business_id,id),
 FOREIGN KEY(business_id,service_id) REFERENCES service(business_id,id)
);
CREATE TABLE policy_assignment_compatibility (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,assignment_id uuid NOT NULL,policy_version_id uuid NOT NULL,
 UNIQUE(business_id,assignment_id,policy_version_id),FOREIGN KEY(business_id,assignment_id) REFERENCES booking_policy_assignment(business_id,id),
 FOREIGN KEY(business_id,policy_version_id) REFERENCES booking_policy_version(business_id,id)
);
-- Commercial precursor only. Never substitute its hash for MS_QUOTE_CONTENT_V2.
CREATE TABLE pricing_proposal (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,branch_id uuid NOT NULL,created_by uuid NOT NULL REFERENCES app_user(id),
 policy_version_id uuid NOT NULL,total_rial bigint NOT NULL CHECK(total_rial>=0 AND total_rial%10=0),
 deposit_rial bigint NOT NULL CHECK(deposit_rial>=0 AND deposit_rial%10=0),remaining_rial bigint NOT NULL CHECK(remaining_rial>=0 AND remaining_rial%10=0),
 configuration_fingerprint bytea NOT NULL CHECK(octet_length(configuration_fingerprint)=32),content_hash bytea NOT NULL CHECK(octet_length(content_hash)=32),
 content_document jsonb NOT NULL CHECK(jsonb_typeof(content_document)='object' AND content_document->>'schema'='MS_COMMERCIAL_PROPOSAL_V1'),
 selectors jsonb NOT NULL CHECK(jsonb_typeof(selectors)='object'),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),expires_at timestamptz NOT NULL,
 UNIQUE(business_id,id),CHECK(deposit_rial::numeric+remaining_rial::numeric=total_rial::numeric),CHECK(isfinite(expires_at) AND expires_at>created_at),
 FOREIGN KEY(business_id,branch_id) REFERENCES branch(business_id,id),FOREIGN KEY(business_id,policy_version_id) REFERENCES booking_policy_version(business_id,id)
);
CREATE TABLE pricing_proposal_item (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,proposal_id uuid NOT NULL,offering_id uuid NOT NULL,branch_id uuid NOT NULL,service_id uuid NOT NULL,
 position integer NOT NULL CHECK(position BETWEEN 1 AND 12),offering_version bigint NOT NULL CHECK(offering_version>0),unit_price_rial bigint NOT NULL CHECK(unit_price_rial>=0 AND unit_price_rial%10=0),
 duration_minutes integer NOT NULL CHECK(duration_minutes BETWEEN 1 AND 1440),buffer_before_minutes integer NOT NULL CHECK(buffer_before_minutes BETWEEN 0 AND 1440),buffer_after_minutes integer NOT NULL CHECK(buffer_after_minutes BETWEEN 0 AND 1440),
 UNIQUE(business_id,proposal_id,position),FOREIGN KEY(business_id,proposal_id) REFERENCES pricing_proposal(business_id,id),
 FOREIGN KEY(business_id,offering_id,branch_id,service_id) REFERENCES branch_service_offering(business_id,id,branch_id,service_id)
);
CREATE TABLE pricing_proposal_source (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,proposal_id uuid NOT NULL,assignment_id uuid NOT NULL,
 UNIQUE(business_id,proposal_id,assignment_id),FOREIGN KEY(business_id,proposal_id) REFERENCES pricing_proposal(business_id,id),
 FOREIGN KEY(business_id,assignment_id) REFERENCES booking_policy_assignment(business_id,id)
);
-- Only FK/concurrency indexes beyond identity indexes. No speculative actor indexes.
CREATE INDEX policy_version_policy_fk ON booking_policy_version(business_id,policy_id);
CREATE INDEX policy_assignment_version_fk ON booking_policy_assignment(business_id,policy_version_id);
CREATE INDEX proposal_policy_fk ON pricing_proposal(business_id,policy_version_id);
CREATE INDEX proposal_offering_fk ON pricing_proposal_item(business_id,offering_id);
REVOKE ALL ON pricing_configuration_revision,booking_policy,booking_policy_version,policy_refund_window,booking_policy_assignment,
 policy_assignment_service,policy_assignment_compatibility,pricing_proposal,pricing_proposal_item,pricing_proposal_source FROM PUBLIC,ms_b1a_runtime,ms_b1b_api;
