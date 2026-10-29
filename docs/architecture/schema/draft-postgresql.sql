-- PHASE 03A REVIEW-ONLY DRAFT. NOT A MIGRATION. NOT EXECUTED.
-- Proposed PostgreSQL 18; application/trigger invariants and hardening gates are documented separately.
-- No INSERT statements or business/demo seed values. All timestamps are instants unless explicitly local rules.
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE SCHEMA ms_design;
SET search_path = ms_design, public;

-- Owner: Business; rollout: MVP; lifecycle: archive
CREATE TABLE business (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_name text NOT NULL,
  legal_name text,
  slug text NOT NULL,
  currency_code text NOT NULL DEFAULT 'IRR',
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_business_0 UNIQUE (slug),
  CONSTRAINT ck_business_0 CHECK (row_version > 0),
  CONSTRAINT ck_business_1 CHECK (currency_code = 'IRR'),
  CONSTRAINT ck_business_2 CHECK (length(slug) > 0)
);

-- Owner: IAM; rollout: MVP; lifecycle: archive
CREATE TABLE app_user (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  display_name text,
  status text NOT NULL DEFAULT 'PENDING',
  pii_redacted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT ck_app_user_0 CHECK (row_version > 0),
  CONSTRAINT ck_app_user_1 CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','CLOSED'))
);

-- Owner: IAM; rollout: MVP; lifecycle: purge
CREATE TABLE auth_identity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  provider text NOT NULL,
  subject_hash bytea NOT NULL,
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT uq_auth_identity_0 UNIQUE (provider, subject_hash),
  CONSTRAINT ck_auth_identity_0 CHECK (row_version > 0),
  CONSTRAINT ck_auth_identity_1 CHECK (octet_length(subject_hash) = 32)
);

-- Owner: IAM; rollout: MVP; lifecycle: purge
CREATE TABLE auth_session (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  token_hash bytea NOT NULL,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  last_seen_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT uq_auth_session_0 UNIQUE (token_hash),
  CONSTRAINT ck_auth_session_0 CHECK (row_version > 0),
  CONSTRAINT ck_auth_session_1 CHECK (expires_at > created_at),
  CONSTRAINT ck_auth_session_2 CHECK (octet_length(token_hash) = 32),
  CONSTRAINT ck_auth_session_3 CHECK (isfinite(expires_at))
);

-- Owner: IAM; rollout: MVP; lifecycle: archive
CREATE TABLE permission (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  permission_key text NOT NULL,
  description text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_permission_0 UNIQUE (permission_key),
  CONSTRAINT ck_permission_0 CHECK (row_version > 0)
);

-- Owner: IAM; rollout: MVP; lifecycle: archive
CREATE TABLE role (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  role_key text NOT NULL,
  display_name text NOT NULL,
  system_role boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_role_0 UNIQUE (business_id, id),
  CONSTRAINT uq_role_1 UNIQUE (business_id, role_key),
  CONSTRAINT ck_role_0 CHECK (row_version > 0)
);

-- Owner: IAM; rollout: MVP; lifecycle: archive
CREATE TABLE role_permission (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  role_id uuid NOT NULL,
  permission_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_role_permission_0 UNIQUE (business_id, id),
  CONSTRAINT uq_role_permission_1 UNIQUE (business_id, role_id, permission_id),
  CONSTRAINT ck_role_permission_0 CHECK (row_version > 0)
);

-- Owner: Business; rollout: MVP; lifecycle: archive
CREATE TABLE branch (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  code text NOT NULL,
  display_name text NOT NULL,
  address text,
  time_zone text NOT NULL,
  active boolean NOT NULL DEFAULT false,
  bookable boolean NOT NULL DEFAULT false,
  configuration_version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_branch_0 UNIQUE (business_id, id),
  CONSTRAINT uq_branch_1 UNIQUE (business_id, code),
  CONSTRAINT ck_branch_0 CHECK (row_version > 0),
  CONSTRAINT ck_branch_1 CHECK (configuration_version > 0),
  CONSTRAINT ck_branch_2 CHECK (NOT bookable OR active)
);

-- Owner: IAM; rollout: MVP; lifecycle: archive
CREATE TABLE user_role_assignment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role_id uuid NOT NULL,
  branch_id uuid,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_user_role_assignment_0 UNIQUE (business_id, id),
  CONSTRAINT ck_user_role_assignment_0 CHECK (row_version > 0)
);

-- Owner: Scheduling; rollout: MVP; lifecycle: archive
CREATE TABLE branch_working_hours (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  iso_weekday smallint NOT NULL,
  start_minute smallint NOT NULL,
  end_minute smallint NOT NULL,
  valid_from date NOT NULL,
  valid_to date,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_branch_working_hours_0 UNIQUE (business_id, id),
  CONSTRAINT uq_branch_working_hours_1 UNIQUE (business_id, branch_id, iso_weekday, start_minute, valid_from),
  CONSTRAINT ck_branch_working_hours_0 CHECK (row_version > 0),
  CONSTRAINT ck_branch_working_hours_1 CHECK (iso_weekday BETWEEN 1 AND 7),
  CONSTRAINT ck_branch_working_hours_2 CHECK (start_minute >= 0 AND end_minute <= 1440 AND end_minute > start_minute),
  CONSTRAINT ck_branch_working_hours_3 CHECK (valid_to IS NULL OR valid_to > valid_from)
);

-- Owner: Scheduling; rollout: MVP; lifecycle: archive
CREATE TABLE branch_closure (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  reason_code text NOT NULL,
  approved_by uuid,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_branch_closure_0 UNIQUE (business_id, id),
  CONSTRAINT uq_branch_closure_1 UNIQUE (business_id, id, branch_id),
  CONSTRAINT ck_branch_closure_0 CHECK (row_version > 0),
  CONSTRAINT ck_branch_closure_1 CHECK (ends_at > starts_at),
  CONSTRAINT ck_branch_closure_2 CHECK (isfinite(starts_at)),
  CONSTRAINT ck_branch_closure_3 CHECK (isfinite(ends_at))
);

-- Owner: Scheduling; rollout: MVP; lifecycle: archive
CREATE TABLE resource (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  branch_id uuid,
  kind text NOT NULL,
  label text NOT NULL,
  active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_resource_0 UNIQUE (business_id, id),
  CONSTRAINT uq_resource_1 UNIQUE (business_id, id, kind),
  CONSTRAINT uq_resource_2 UNIQUE (business_id, id, branch_id),
  CONSTRAINT ck_resource_0 CHECK (row_version > 0),
  CONSTRAINT ck_resource_1 CHECK (kind IN ('STAFF','CHAIR','ROOM','DEVICE')),
  CONSTRAINT ck_resource_2 CHECK ((kind = 'STAFF' AND branch_id IS NULL) OR (kind <> 'STAFF' AND branch_id IS NOT NULL))
);

-- Owner: Catalog; rollout: MVP; lifecycle: archive
CREATE TABLE service (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  code text NOT NULL,
  display_name text NOT NULL,
  description text,
  active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_service_0 UNIQUE (business_id, id),
  CONSTRAINT uq_service_1 UNIQUE (business_id, code),
  CONSTRAINT ck_service_0 CHECK (row_version > 0)
);

-- Owner: Offerings; rollout: MVP; lifecycle: archive
CREATE TABLE branch_service_offering (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  service_id uuid NOT NULL,
  active boolean NOT NULL DEFAULT false,
  price_rial bigint,
  duration_minutes integer,
  buffer_before_minutes integer,
  buffer_after_minutes integer,
  configuration_version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  resources_confirmed boolean NOT NULL DEFAULT false,
  CONSTRAINT uq_branch_service_offering_0 UNIQUE (business_id, id),
  CONSTRAINT uq_branch_service_offering_1 UNIQUE (business_id, branch_id, service_id),
  CONSTRAINT uq_branch_service_offering_2 UNIQUE (business_id, id, branch_id, service_id),
  CONSTRAINT ck_branch_service_offering_0 CHECK (row_version > 0),
  CONSTRAINT ck_branch_service_offering_1 CHECK (price_rial IS NULL OR (price_rial >= 0 AND price_rial % 10 = 0)),
  CONSTRAINT ck_branch_service_offering_2 CHECK (duration_minutes IS NULL OR duration_minutes > 0),
  CONSTRAINT ck_branch_service_offering_3 CHECK (buffer_before_minutes IS NULL OR buffer_before_minutes >= 0),
  CONSTRAINT ck_branch_service_offering_4 CHECK (buffer_after_minutes IS NULL OR buffer_after_minutes >= 0),
  CONSTRAINT ck_branch_service_offering_5 CHECK (configuration_version > 0),
  CONSTRAINT ck_branch_service_offering_6 CHECK (NOT active OR (price_rial IS NOT NULL AND duration_minutes IS NOT NULL AND buffer_before_minutes IS NOT NULL AND buffer_after_minutes IS NOT NULL)),
  CONSTRAINT ck_branch_service_offering_7 CHECK (NOT active OR resources_confirmed)
);

-- Owner: Staff; rollout: MVP; lifecycle: archive
CREATE TABLE staff (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  user_id uuid,
  resource_id uuid NOT NULL,
  resource_kind text NOT NULL DEFAULT 'STAFF',
  display_name text NOT NULL,
  active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_staff_0 UNIQUE (business_id, id),
  CONSTRAINT uq_staff_1 UNIQUE (business_id, resource_id),
  CONSTRAINT uq_staff_2 UNIQUE (business_id, user_id),
  CONSTRAINT uq_staff_3 UNIQUE (business_id, id, resource_id),
  CONSTRAINT ck_staff_0 CHECK (row_version > 0),
  CONSTRAINT ck_staff_1 CHECK (resource_kind = 'STAFF')
);

-- Owner: Staff; rollout: MVP; lifecycle: archive
CREATE TABLE staff_branch_assignment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  valid_from date NOT NULL,
  valid_to date,
  active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_staff_branch_assignment_0 UNIQUE (business_id, id),
  CONSTRAINT uq_staff_branch_assignment_1 UNIQUE (business_id, staff_id, branch_id),
  CONSTRAINT uq_staff_branch_assignment_2 UNIQUE (business_id, id, staff_id, branch_id),
  CONSTRAINT ck_staff_branch_assignment_0 CHECK (row_version > 0),
  CONSTRAINT ck_staff_branch_assignment_1 CHECK (valid_to IS NULL OR valid_to > valid_from)
);

-- Owner: Staff; rollout: MVP; lifecycle: archive
CREATE TABLE staff_service_eligibility (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  service_id uuid NOT NULL,
  verified_at timestamptz,
  active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_staff_service_eligibility_0 UNIQUE (business_id, id),
  CONSTRAINT uq_staff_service_eligibility_1 UNIQUE (business_id, staff_id, service_id),
  CONSTRAINT uq_staff_service_eligibility_2 UNIQUE (business_id, id, staff_id, service_id),
  CONSTRAINT ck_staff_service_eligibility_0 CHECK (row_version > 0),
  CONSTRAINT ck_staff_service_eligibility_1 CHECK (NOT active OR verified_at IS NOT NULL)
);

-- Owner: Offerings; rollout: MVP; lifecycle: archive
CREATE TABLE offering_staff_eligibility (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  offering_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  service_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  assignment_id uuid NOT NULL,
  qualification_id uuid NOT NULL,
  active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_offering_staff_eligibility_0 UNIQUE (business_id, id),
  CONSTRAINT uq_offering_staff_eligibility_1 UNIQUE (business_id, offering_id, staff_id),
  CONSTRAINT ck_offering_staff_eligibility_0 CHECK (row_version > 0)
);

-- Owner: Scheduling; rollout: MVP; lifecycle: archive
CREATE TABLE staff_schedule_rule (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  assignment_id uuid NOT NULL,
  iso_weekday smallint NOT NULL,
  start_minute smallint NOT NULL,
  end_minute smallint NOT NULL,
  valid_from date NOT NULL,
  valid_to date,
  configuration_version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_staff_schedule_rule_0 UNIQUE (business_id, id),
  CONSTRAINT uq_staff_schedule_rule_1 UNIQUE (business_id, id, staff_id, branch_id),
  CONSTRAINT ck_staff_schedule_rule_0 CHECK (row_version > 0),
  CONSTRAINT ck_staff_schedule_rule_1 CHECK (iso_weekday BETWEEN 1 AND 7),
  CONSTRAINT ck_staff_schedule_rule_2 CHECK (start_minute >= 0 AND end_minute <= 1440 AND end_minute > start_minute),
  CONSTRAINT ck_staff_schedule_rule_3 CHECK (valid_to IS NULL OR valid_to > valid_from),
  CONSTRAINT ck_staff_schedule_rule_4 CHECK (configuration_version > 0)
);

-- Owner: Scheduling; rollout: MVP; lifecycle: archive
CREATE TABLE staff_shift (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  assignment_id uuid NOT NULL,
  schedule_rule_id uuid,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  published boolean NOT NULL DEFAULT false,
  schedule_version bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_staff_shift_0 UNIQUE (business_id, id),
  CONSTRAINT ck_staff_shift_0 CHECK (row_version > 0),
  CONSTRAINT ck_staff_shift_1 CHECK (ends_at > starts_at),
  CONSTRAINT ck_staff_shift_2 CHECK (schedule_version > 0),
  CONSTRAINT ck_staff_shift_3 CHECK (isfinite(starts_at)),
  CONSTRAINT ck_staff_shift_4 CHECK (isfinite(ends_at))
);

-- Owner: Scheduling; rollout: MVP; lifecycle: archive
CREATE TABLE staff_time_off (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  resource_id uuid NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  reason_code text NOT NULL,
  approved_by uuid,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_staff_time_off_0 UNIQUE (business_id, id),
  CONSTRAINT uq_staff_time_off_1 UNIQUE (business_id, id, resource_id),
  CONSTRAINT ck_staff_time_off_0 CHECK (row_version > 0),
  CONSTRAINT ck_staff_time_off_1 CHECK (ends_at > starts_at),
  CONSTRAINT ck_staff_time_off_2 CHECK (isfinite(starts_at)),
  CONSTRAINT ck_staff_time_off_3 CHECK (isfinite(ends_at))
);

-- Owner: Catalog; rollout: Later; lifecycle: archive
CREATE TABLE package (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  code text NOT NULL,
  display_name text NOT NULL,
  active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_package_0 UNIQUE (business_id, id),
  CONSTRAINT uq_package_1 UNIQUE (business_id, code),
  CONSTRAINT ck_package_0 CHECK (row_version > 0)
);

-- Owner: Catalog; rollout: Later; lifecycle: archive
CREATE TABLE package_service (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  package_id uuid NOT NULL,
  service_id uuid NOT NULL,
  position integer NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_package_service_0 UNIQUE (business_id, id),
  CONSTRAINT uq_package_service_1 UNIQUE (business_id, package_id, position),
  CONSTRAINT ck_package_service_0 CHECK (row_version > 0),
  CONSTRAINT ck_package_service_1 CHECK (position >= 0),
  CONSTRAINT ck_package_service_2 CHECK (quantity > 0)
);

-- Owner: Customers; rollout: MVP; lifecycle: archive
CREATE TABLE customer (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  user_id uuid,
  display_name text,
  contact_ciphertext bytea,
  contact_lookup_hash bytea,
  contact_verified_at timestamptz,
  privacy_notice_version text,
  redacted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_customer_0 UNIQUE (business_id, id),
  CONSTRAINT uq_customer_1 UNIQUE (business_id, user_id),
  CONSTRAINT ck_customer_0 CHECK (row_version > 0),
  CONSTRAINT ck_customer_1 CHECK (octet_length(contact_lookup_hash) = 32)
);

-- Owner: Availability; rollout: MVP; lifecycle: archive
CREATE TABLE availability_configuration (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  enabled boolean NOT NULL DEFAULT false,
  slot_stride_minutes integer,
  lead_minutes integer,
  horizon_days integer,
  hold_ttl_seconds integer,
  quote_ttl_seconds integer,
  configuration_version bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_availability_configuration_0 UNIQUE (business_id, id),
  CONSTRAINT uq_availability_configuration_1 UNIQUE (business_id, branch_id),
  CONSTRAINT ck_availability_configuration_0 CHECK (row_version > 0),
  CONSTRAINT ck_availability_configuration_1 CHECK (slot_stride_minutes IS NULL OR slot_stride_minutes > 0),
  CONSTRAINT ck_availability_configuration_2 CHECK (lead_minutes IS NULL OR lead_minutes >= 0),
  CONSTRAINT ck_availability_configuration_3 CHECK (horizon_days IS NULL OR horizon_days > 0),
  CONSTRAINT ck_availability_configuration_4 CHECK (hold_ttl_seconds IS NULL OR hold_ttl_seconds > 0),
  CONSTRAINT ck_availability_configuration_5 CHECK (quote_ttl_seconds IS NULL OR quote_ttl_seconds > 0),
  CONSTRAINT ck_availability_configuration_6 CHECK (configuration_version > 0),
  CONSTRAINT ck_availability_configuration_7 CHECK (NOT enabled OR (slot_stride_minutes IS NOT NULL AND lead_minutes IS NOT NULL AND horizon_days IS NOT NULL AND hold_ttl_seconds IS NOT NULL AND quote_ttl_seconds IS NOT NULL))
);

-- Owner: Policies; rollout: MVP; lifecycle: archive
CREATE TABLE booking_policy (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  code text NOT NULL,
  name text NOT NULL,
  lifecycle text NOT NULL DEFAULT 'DRAFT',
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_booking_policy_0 UNIQUE (business_id, id),
  CONSTRAINT uq_booking_policy_1 UNIQUE (business_id, code),
  CONSTRAINT ck_booking_policy_0 CHECK (row_version > 0),
  CONSTRAINT ck_booking_policy_1 CHECK (lifecycle IN ('DRAFT','ACTIVE','SUPERSEDED','RETIRED'))
);

-- Owner: Policies; rollout: MVP; lifecycle: publish-freeze
CREATE TABLE booking_policy_version (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  policy_id uuid NOT NULL,
  version_number integer NOT NULL,
  lifecycle text NOT NULL DEFAULT 'DRAFT',
  effective_from timestamptz NOT NULL,
  effective_to timestamptz,
  deposit_requirement text NOT NULL,
  amount_kind text,
  fixed_rial bigint,
  basis_points integer,
  minimum_rial bigint,
  maximum_rial bigint,
  refundability text NOT NULL,
  refund_base text NOT NULL,
  outside_refund_bps integer NOT NULL,
  terms_text text NOT NULL,
  terms_locale text NOT NULL,
  content_hash bytea NOT NULL,
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT uq_booking_policy_version_0 UNIQUE (business_id, id),
  CONSTRAINT uq_booking_policy_version_1 UNIQUE (business_id, policy_id, version_number),
  CONSTRAINT ck_booking_policy_version_0 CHECK (lifecycle IN ('DRAFT','ACTIVE','SUPERSEDED','RETIRED')),
  CONSTRAINT ck_booking_policy_version_1 CHECK (version_number > 0),
  CONSTRAINT ck_booking_policy_version_2 CHECK (effective_to IS NULL OR effective_to > effective_from),
  CONSTRAINT ck_booking_policy_version_3 CHECK (deposit_requirement IN ('NONE','OPTIONAL','REQUIRED')),
  CONSTRAINT ck_booking_policy_version_4 CHECK ((deposit_requirement = 'NONE' AND amount_kind IS NULL AND fixed_rial IS NULL AND basis_points IS NULL AND minimum_rial IS NULL AND maximum_rial IS NULL) OR (deposit_requirement <> 'NONE' AND ((amount_kind = 'FIXED' AND fixed_rial > 0 AND fixed_rial % 10 = 0 AND basis_points IS NULL) OR (amount_kind = 'PERCENTAGE' AND basis_points BETWEEN 1 AND 10000 AND fixed_rial IS NULL)))),
  CONSTRAINT ck_booking_policy_version_5 CHECK (minimum_rial IS NULL OR (minimum_rial >= 0 AND minimum_rial % 10 = 0)),
  CONSTRAINT ck_booking_policy_version_6 CHECK (maximum_rial IS NULL OR (maximum_rial >= 0 AND maximum_rial % 10 = 0)),
  CONSTRAINT ck_booking_policy_version_7 CHECK (minimum_rial IS NULL OR maximum_rial IS NULL OR minimum_rial <= maximum_rial),
  CONSTRAINT ck_booking_policy_version_8 CHECK (refundability IN ('FULL','NONE','PARTIAL','CONDITIONAL')),
  CONSTRAINT ck_booking_policy_version_9 CHECK (refund_base IN ('DEPOSIT_PAID','ALL_PAID')),
  CONSTRAINT ck_booking_policy_version_10 CHECK (outside_refund_bps BETWEEN 0 AND 10000),
  CONSTRAINT ck_booking_policy_version_11 CHECK (lifecycle = 'DRAFT' OR published_at IS NOT NULL),
  CONSTRAINT ck_booking_policy_version_12 CHECK (row_version > 0),
  CONSTRAINT ck_booking_policy_version_13 CHECK (deposit_requirement='NONE' OR (amount_kind IS NOT NULL AND ((amount_kind='FIXED' AND fixed_rial IS NOT NULL AND basis_points IS NULL) OR (amount_kind='PERCENTAGE' AND basis_points IS NOT NULL AND fixed_rial IS NULL)))),
  CONSTRAINT ck_booking_policy_version_14 CHECK (isfinite(effective_from)),
  CONSTRAINT ck_booking_policy_version_15 CHECK (octet_length(content_hash) = 32)
);

-- Owner: Policies; rollout: MVP; lifecycle: append
CREATE TABLE policy_refund_window (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  policy_version_id uuid NOT NULL,
  threshold_minutes integer NOT NULL,
  refund_bps integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_policy_refund_window_0 UNIQUE (business_id, id),
  CONSTRAINT uq_policy_refund_window_1 UNIQUE (business_id, policy_version_id, threshold_minutes),
  CONSTRAINT ck_policy_refund_window_0 CHECK (threshold_minutes >= 0),
  CONSTRAINT ck_policy_refund_window_1 CHECK (refund_bps BETWEEN 0 AND 10000)
);

-- Owner: Policies; rollout: MVP; lifecycle: archive
CREATE TABLE booking_policy_assignment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  policy_version_id uuid NOT NULL,
  scope_kind text NOT NULL,
  branch_id uuid,
  service_id uuid,
  package_id uuid,
  booking_id uuid,
  priority integer NOT NULL DEFAULT 0,
  effective_from timestamptz NOT NULL,
  effective_to timestamptz,
  override_reason text,
  authorized_by uuid,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_booking_policy_assignment_0 UNIQUE (business_id, id),
  CONSTRAINT uq_booking_policy_assignment_1 UNIQUE (business_id, id, policy_version_id),
  CONSTRAINT ck_booking_policy_assignment_0 CHECK (row_version > 0),
  CONSTRAINT ck_booking_policy_assignment_1 CHECK (effective_to IS NULL OR effective_to > effective_from),
  CONSTRAINT ck_booking_policy_assignment_2 CHECK ((scope_kind = 'BUSINESS' AND num_nonnulls(branch_id,service_id,package_id,booking_id)=0) OR (scope_kind='BRANCH' AND branch_id IS NOT NULL AND num_nonnulls(service_id,package_id,booking_id)=0) OR (scope_kind='SERVICE' AND service_id IS NOT NULL AND package_id IS NULL AND booking_id IS NULL) OR (scope_kind='PACKAGE' AND package_id IS NOT NULL AND service_id IS NULL AND booking_id IS NULL) OR (scope_kind IN ('BOOKING','ADMIN_OVERRIDE') AND booking_id IS NOT NULL AND num_nonnulls(branch_id,service_id,package_id)=0)),
  CONSTRAINT ck_booking_policy_assignment_3 CHECK (scope_kind <> 'ADMIN_OVERRIDE' OR (override_reason IS NOT NULL AND authorized_by IS NOT NULL)),
  CONSTRAINT ck_booking_policy_assignment_4 CHECK (isfinite(effective_from))
);

-- Owner: Pricing; rollout: MVP; lifecycle: append
CREATE TABLE pricing_quote (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  customer_id uuid,
  currency_code text NOT NULL DEFAULT 'IRR',
  unit_version text NOT NULL DEFAULT 'IRR_RIAL_V1',
  total_rial bigint NOT NULL,
  deposit_rial bigint NOT NULL,
  remaining_rial bigint NOT NULL,
  expires_at timestamptz NOT NULL,
  configuration_fingerprint bytea NOT NULL,
  quote_hash bytea NOT NULL,
  source text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_pricing_quote_0 UNIQUE (business_id, id),
  CONSTRAINT uq_pricing_quote_1 UNIQUE (business_id, id, branch_id),
  CONSTRAINT uq_pricing_quote_2 UNIQUE (business_id, quote_hash),
  CONSTRAINT ck_pricing_quote_0 CHECK (currency_code='IRR' AND unit_version='IRR_RIAL_V1'),
  CONSTRAINT ck_pricing_quote_1 CHECK (total_rial >= 0 AND total_rial % 10 = 0),
  CONSTRAINT ck_pricing_quote_2 CHECK (deposit_rial >= 0 AND deposit_rial % 10 = 0),
  CONSTRAINT ck_pricing_quote_3 CHECK (remaining_rial >= 0 AND remaining_rial % 10 = 0),
  CONSTRAINT ck_pricing_quote_4 CHECK (deposit_rial + remaining_rial = total_rial),
  CONSTRAINT ck_pricing_quote_5 CHECK (expires_at > created_at),
  CONSTRAINT ck_pricing_quote_6 CHECK (source = 'SERVER'),
  CONSTRAINT ck_pricing_quote_7 CHECK (created_by IS NOT NULL),
  CONSTRAINT ck_pricing_quote_8 CHECK (isfinite(expires_at)),
  CONSTRAINT ck_pricing_quote_9 CHECK (octet_length(quote_hash) = 32)
);

-- Owner: Pricing; rollout: MVP; lifecycle: append
CREATE TABLE pricing_quote_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  quote_id uuid NOT NULL,
  offering_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  service_id uuid NOT NULL,
  package_id uuid,
  position integer NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  offering_version bigint NOT NULL,
  unit_price_rial bigint NOT NULL,
  duration_minutes integer NOT NULL,
  buffer_before_minutes integer NOT NULL,
  buffer_after_minutes integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_pricing_quote_item_0 UNIQUE (business_id, id),
  CONSTRAINT uq_pricing_quote_item_1 UNIQUE (business_id, quote_id, position),
  CONSTRAINT uq_pricing_quote_item_2 UNIQUE (business_id, id, quote_id),
  CONSTRAINT ck_pricing_quote_item_0 CHECK (position >= 0),
  CONSTRAINT ck_pricing_quote_item_1 CHECK (quantity > 0),
  CONSTRAINT ck_pricing_quote_item_2 CHECK (offering_version > 0),
  CONSTRAINT ck_pricing_quote_item_3 CHECK (unit_price_rial >= 0 AND unit_price_rial % 10 = 0),
  CONSTRAINT ck_pricing_quote_item_4 CHECK (duration_minutes > 0),
  CONSTRAINT ck_pricing_quote_item_5 CHECK (buffer_before_minutes >= 0 AND buffer_after_minutes >= 0)
);

-- Owner: Policies; rollout: MVP; lifecycle: append
CREATE TABLE quote_policy_resolution (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  quote_id uuid NOT NULL,
  policy_version_id uuid NOT NULL,
  snapshot jsonb NOT NULL,
  snapshot_hash bytea NOT NULL,
  resolver_version text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_quote_policy_resolution_0 UNIQUE (business_id, id),
  CONSTRAINT uq_quote_policy_resolution_1 UNIQUE (business_id, quote_id),
  CONSTRAINT uq_quote_policy_resolution_2 UNIQUE (business_id, id, quote_id),
  CONSTRAINT uq_quote_policy_resolution_3 UNIQUE (business_id, id, policy_version_id),
  CONSTRAINT ck_quote_policy_resolution_0 CHECK (jsonb_typeof(snapshot) = 'object'),
  CONSTRAINT ck_quote_policy_resolution_1 CHECK (octet_length(snapshot_hash) = 32)
);

-- Owner: Policies; rollout: MVP; lifecycle: append
CREATE TABLE quote_policy_source (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  resolution_id uuid NOT NULL,
  assignment_id uuid NOT NULL,
  policy_version_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_quote_policy_source_0 UNIQUE (business_id, id),
  CONSTRAINT uq_quote_policy_source_1 UNIQUE (business_id, resolution_id, assignment_id)
);

-- Owner: Booking; rollout: MVP; lifecycle: archive
CREATE TABLE booking (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  customer_id uuid,
  status text NOT NULL DEFAULT 'DRAFT',
  origin text NOT NULL,
  active_revision_id uuid,
  cancelled_at timestamptz,
  cancellation_reason_code text,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_booking_0 UNIQUE (business_id, id),
  CONSTRAINT uq_booking_1 UNIQUE (business_id, id, branch_id),
  CONSTRAINT ck_booking_0 CHECK (row_version > 0),
  CONSTRAINT ck_booking_1 CHECK (status IN ('DRAFT','HELD','PENDING_PAYMENT','CONFIRMED','CHECKED_IN','IN_SERVICE','COMPLETED','CANCELLED','NO_SHOW','EXPIRED')),
  CONSTRAINT ck_booking_2 CHECK (origin IN ('CUSTOMER','STAFF','WALK_IN')),
  CONSTRAINT ck_booking_3 CHECK (origin <> 'CUSTOMER' OR customer_id IS NOT NULL),
  CONSTRAINT ck_booking_4 CHECK (status = 'DRAFT' OR active_revision_id IS NOT NULL)
);

-- Owner: Booking; rollout: MVP; lifecycle: append
CREATE TABLE booking_revision (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  booking_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  revision_number integer NOT NULL,
  quote_id uuid NOT NULL,
  state text NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  time_zone text NOT NULL,
  configuration_fingerprint bytea NOT NULL,
  supersedes_revision_id uuid,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_booking_revision_0 UNIQUE (business_id, id),
  CONSTRAINT uq_booking_revision_1 UNIQUE (business_id, booking_id, revision_number),
  CONSTRAINT uq_booking_revision_2 UNIQUE (business_id, id, booking_id),
  CONSTRAINT uq_booking_revision_3 UNIQUE (business_id, id, quote_id),
  CONSTRAINT uq_booking_revision_4 UNIQUE (business_id, id, branch_id),
  CONSTRAINT ck_booking_revision_0 CHECK (revision_number > 0),
  CONSTRAINT ck_booking_revision_1 CHECK (ends_at > starts_at),
  CONSTRAINT ck_booking_revision_2 CHECK (state IN ('PROPOSED','ACTIVE','SUPERSEDED')),
  CONSTRAINT ck_booking_revision_3 CHECK (isfinite(starts_at)),
  CONSTRAINT ck_booking_revision_4 CHECK (isfinite(ends_at))
);

-- Owner: Booking; rollout: MVP; lifecycle: append
CREATE TABLE booking_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  revision_id uuid NOT NULL,
  quote_item_id uuid NOT NULL,
  quote_id uuid NOT NULL,
  position integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_booking_item_0 UNIQUE (business_id, id),
  CONSTRAINT uq_booking_item_1 UNIQUE (business_id, revision_id, position),
  CONSTRAINT uq_booking_item_2 UNIQUE (business_id, id, revision_id),
  CONSTRAINT ck_booking_item_0 CHECK (position >= 0)
);

-- Owner: Booking; rollout: MVP; lifecycle: append
CREATE TABLE booking_service_segment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  revision_id uuid NOT NULL,
  item_id uuid NOT NULL,
  position integer NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  buffer_before_minutes integer NOT NULL,
  buffer_after_minutes integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_booking_service_segment_0 UNIQUE (business_id, id),
  CONSTRAINT uq_booking_service_segment_1 UNIQUE (business_id, revision_id, position),
  CONSTRAINT uq_booking_service_segment_2 UNIQUE (business_id, id, revision_id),
  CONSTRAINT ck_booking_service_segment_0 CHECK (ends_at > starts_at),
  CONSTRAINT ck_booking_service_segment_1 CHECK (position >= 0),
  CONSTRAINT ck_booking_service_segment_2 CHECK (buffer_before_minutes >= 0 AND buffer_after_minutes >= 0),
  CONSTRAINT ck_booking_service_segment_3 CHECK (isfinite(starts_at)),
  CONSTRAINT ck_booking_service_segment_4 CHECK (isfinite(ends_at))
);

-- Owner: Booking; rollout: Later; lifecycle: append
CREATE TABLE segment_dependency (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  revision_id uuid NOT NULL,
  segment_id uuid NOT NULL,
  predecessor_id uuid NOT NULL,
  minimum_gap_minutes integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_segment_dependency_0 UNIQUE (business_id, id),
  CONSTRAINT uq_segment_dependency_1 UNIQUE (business_id, segment_id, predecessor_id),
  CONSTRAINT ck_segment_dependency_0 CHECK (segment_id <> predecessor_id),
  CONSTRAINT ck_segment_dependency_1 CHECK (minimum_gap_minutes >= 0)
);

-- Owner: Booking; rollout: MVP; lifecycle: archive
CREATE TABLE booking_hold (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  booking_id uuid NOT NULL,
  revision_id uuid NOT NULL,
  expires_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'ACTIVE',
  released_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_booking_hold_0 UNIQUE (business_id, id),
  CONSTRAINT uq_booking_hold_1 UNIQUE (business_id, id, revision_id),
  CONSTRAINT ck_booking_hold_0 CHECK (row_version > 0),
  CONSTRAINT ck_booking_hold_1 CHECK (expires_at > created_at),
  CONSTRAINT ck_booking_hold_2 CHECK (status IN ('ACTIVE','CONSUMED','EXPIRED','RELEASED')),
  CONSTRAINT ck_booking_hold_3 CHECK ((status='ACTIVE' AND released_at IS NULL) OR (status<>'ACTIVE' AND released_at IS NOT NULL)),
  CONSTRAINT ck_booking_hold_4 CHECK (isfinite(expires_at))
);

-- Owner: Scheduling; rollout: MVP; lifecycle: archive
CREATE TABLE resource_allocation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  resource_id uuid NOT NULL,
  branch_id uuid,
  revision_id uuid,
  hold_id uuid,
  time_off_id uuid,
  closure_id uuid,
  allocation_kind text NOT NULL,
  busy_starts_at timestamptz NOT NULL,
  busy_ends_at timestamptz NOT NULL,
  released_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  resource_kind text NOT NULL,
  resource_branch_id uuid,
  CONSTRAINT uq_resource_allocation_0 UNIQUE (business_id, id),
  CONSTRAINT uq_resource_allocation_1 UNIQUE (business_id, id, revision_id, resource_id),
  CONSTRAINT ck_resource_allocation_0 CHECK (row_version > 0),
  CONSTRAINT ck_resource_allocation_1 CHECK (busy_ends_at > busy_starts_at),
  CONSTRAINT ck_resource_allocation_2 CHECK ((allocation_kind IN ('HOLD','BOOKING') AND revision_id IS NOT NULL AND branch_id IS NOT NULL AND time_off_id IS NULL AND closure_id IS NULL AND (allocation_kind <> 'HOLD' OR hold_id IS NOT NULL)) OR (allocation_kind='TIME_OFF' AND time_off_id IS NOT NULL AND num_nonnulls(revision_id,hold_id,closure_id)=0) OR (allocation_kind='CLOSURE' AND closure_id IS NOT NULL AND branch_id IS NOT NULL AND num_nonnulls(revision_id,hold_id,time_off_id)=0) OR (allocation_kind='MAINTENANCE' AND num_nonnulls(revision_id,hold_id,time_off_id,closure_id)=0)),
  CONSTRAINT ck_resource_allocation_3 CHECK ((resource_kind='STAFF' AND resource_branch_id IS NULL) OR (resource_kind IN ('CHAIR','ROOM','DEVICE') AND resource_branch_id IS NOT NULL AND branch_id IS NOT NULL AND branch_id=resource_branch_id)),
  CONSTRAINT ck_resource_allocation_4 CHECK (isfinite(busy_starts_at)),
  CONSTRAINT ck_resource_allocation_5 CHECK (isfinite(busy_ends_at))
);

-- Owner: Booking; rollout: MVP; lifecycle: append
CREATE TABLE booking_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  booking_id uuid NOT NULL,
  from_status text,
  to_status text NOT NULL,
  actor_kind text NOT NULL,
  reason_code text NOT NULL,
  request_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_booking_status_history_0 UNIQUE (business_id, id),
  CONSTRAINT ck_booking_status_history_0 CHECK (actor_kind IN ('CUSTOMER','STAFF','SYSTEM','PAYMENT_WORKFLOW')),
  CONSTRAINT ck_booking_status_history_1 CHECK ((from_status IS NULL AND to_status='DRAFT') OR (from_status IS NOT NULL AND ((from_status='DRAFT' AND to_status='HELD') OR (from_status='DRAFT' AND to_status='CANCELLED') OR (from_status='DRAFT' AND to_status='EXPIRED') OR (from_status='HELD' AND to_status='PENDING_PAYMENT') OR (from_status='HELD' AND to_status='CONFIRMED') OR (from_status='HELD' AND to_status='CANCELLED') OR (from_status='HELD' AND to_status='EXPIRED') OR (from_status='PENDING_PAYMENT' AND to_status='CONFIRMED') OR (from_status='PENDING_PAYMENT' AND to_status='CANCELLED') OR (from_status='PENDING_PAYMENT' AND to_status='EXPIRED') OR (from_status='CONFIRMED' AND to_status='CHECKED_IN') OR (from_status='CONFIRMED' AND to_status='CANCELLED') OR (from_status='CONFIRMED' AND to_status='NO_SHOW') OR (from_status='CHECKED_IN' AND to_status='IN_SERVICE') OR (from_status='CHECKED_IN' AND to_status='CANCELLED') OR (from_status='IN_SERVICE' AND to_status='COMPLETED') OR (from_status='IN_SERVICE' AND to_status='CANCELLED'))))
);

-- Owner: Policies; rollout: MVP; lifecycle: append
CREATE TABLE booking_policy_acceptance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  booking_id uuid NOT NULL,
  revision_id uuid NOT NULL,
  quote_id uuid NOT NULL,
  resolution_id uuid NOT NULL,
  actor_user_id uuid NOT NULL,
  accepted_at timestamptz NOT NULL,
  method text NOT NULL,
  consent_text_hash bytea NOT NULL,
  accepted_snapshot jsonb NOT NULL,
  snapshot_hash bytea NOT NULL,
  evidence_key text,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_booking_policy_acceptance_0 UNIQUE (business_id, id),
  CONSTRAINT uq_booking_policy_acceptance_1 UNIQUE (business_id, revision_id),
  CONSTRAINT ck_booking_policy_acceptance_0 CHECK (method IN ('WEB_EXPLICIT','SIGNED_OFFLINE')),
  CONSTRAINT ck_booking_policy_acceptance_1 CHECK (jsonb_typeof(accepted_snapshot) = 'object'),
  CONSTRAINT ck_booking_policy_acceptance_2 CHECK (octet_length(consent_text_hash) = 32),
  CONSTRAINT ck_booking_policy_acceptance_3 CHECK (octet_length(snapshot_hash) = 32)
);

-- Owner: Payments; rollout: MVP-if-payments; lifecycle: archive
CREATE TABLE payment_intent (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  revision_id uuid NOT NULL,
  hold_id uuid NOT NULL,
  purpose text NOT NULL,
  currency_code text NOT NULL DEFAULT 'IRR',
  unit_version text NOT NULL DEFAULT 'IRR_RIAL_V1',
  amount_rial bigint NOT NULL,
  provider_key text NOT NULL,
  provider_idempotency_key text NOT NULL,
  state text NOT NULL DEFAULT 'CREATED',
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_payment_intent_0 UNIQUE (business_id, id),
  CONSTRAINT uq_payment_intent_1 UNIQUE (business_id, provider_key, provider_idempotency_key),
  CONSTRAINT uq_payment_intent_2 UNIQUE (business_id, id, revision_id),
  CONSTRAINT ck_payment_intent_0 CHECK (row_version > 0),
  CONSTRAINT ck_payment_intent_1 CHECK (purpose IN ('DEPOSIT','REMAINDER','ADJUSTMENT')),
  CONSTRAINT ck_payment_intent_2 CHECK (currency_code='IRR' AND unit_version='IRR_RIAL_V1'),
  CONSTRAINT ck_payment_intent_3 CHECK (amount_rial > 0 AND amount_rial % 10 = 0),
  CONSTRAINT ck_payment_intent_4 CHECK (expires_at > created_at),
  CONSTRAINT ck_payment_intent_5 CHECK (state IN ('CREATED','PENDING','VERIFIED','FAILED','EXPIRED')),
  CONSTRAINT ck_payment_intent_6 CHECK (isfinite(expires_at))
);

-- Owner: Payments; rollout: MVP-if-payments; lifecycle: append
CREATE TABLE gateway_event (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  provider_key text NOT NULL,
  merchant_ref text NOT NULL,
  event_key text NOT NULL,
  payload_hash bytea NOT NULL,
  verification_state text NOT NULL,
  received_at timestamptz NOT NULL,
  redacted_metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_gateway_event_0 UNIQUE (business_id, id),
  CONSTRAINT uq_gateway_event_1 UNIQUE (business_id, provider_key, merchant_ref, event_key),
  CONSTRAINT uq_gateway_event_2 UNIQUE (provider_key, merchant_ref, event_key),
  CONSTRAINT ck_gateway_event_0 CHECK (verification_state IN ('UNVERIFIED','VALID','INVALID')),
  CONSTRAINT ck_gateway_event_1 CHECK (octet_length(payload_hash) = 32)
);

-- Owner: Payments; rollout: MVP-if-payments; lifecycle: append
CREATE TABLE payment_transaction (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  intent_id uuid NOT NULL,
  revision_id uuid NOT NULL,
  gateway_event_id uuid NOT NULL,
  provider_key text NOT NULL,
  merchant_ref text NOT NULL,
  provider_transaction_ref text NOT NULL,
  amount_rial bigint NOT NULL,
  currency_code text NOT NULL DEFAULT 'IRR',
  verified_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_payment_transaction_0 UNIQUE (business_id, id),
  CONSTRAINT uq_payment_transaction_1 UNIQUE (business_id, provider_key, merchant_ref, provider_transaction_ref),
  CONSTRAINT uq_payment_transaction_2 UNIQUE (business_id, id, revision_id),
  CONSTRAINT uq_payment_transaction_3 UNIQUE (provider_key, merchant_ref, provider_transaction_ref),
  CONSTRAINT ck_payment_transaction_0 CHECK (amount_rial > 0 AND amount_rial % 10 = 0),
  CONSTRAINT ck_payment_transaction_1 CHECK (currency_code='IRR')
);

-- Owner: Payments; rollout: MVP-if-payments; lifecycle: append
CREATE TABLE payment_application (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  transaction_id uuid NOT NULL,
  revision_id uuid NOT NULL,
  purpose text NOT NULL,
  amount_rial bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_payment_application_0 UNIQUE (business_id, id),
  CONSTRAINT uq_payment_application_1 UNIQUE (business_id, transaction_id),
  CONSTRAINT uq_payment_application_2 UNIQUE (business_id, revision_id, purpose),
  CONSTRAINT ck_payment_application_0 CHECK (amount_rial > 0 AND amount_rial % 10 = 0),
  CONSTRAINT ck_payment_application_1 CHECK (purpose IN ('DEPOSIT','REMAINDER','ADJUSTMENT'))
);

-- Owner: Payments; rollout: MVP-if-payments; lifecycle: archive
CREATE TABLE payment_balance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  transaction_id uuid NOT NULL,
  captured_rial bigint NOT NULL,
  refund_reserved_rial bigint NOT NULL DEFAULT 0,
  refunded_rial bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_payment_balance_0 UNIQUE (business_id, id),
  CONSTRAINT uq_payment_balance_1 UNIQUE (business_id, transaction_id),
  CONSTRAINT ck_payment_balance_0 CHECK (row_version > 0),
  CONSTRAINT ck_payment_balance_1 CHECK (captured_rial > 0 AND captured_rial % 10 = 0),
  CONSTRAINT ck_payment_balance_2 CHECK (refund_reserved_rial >= 0 AND refund_reserved_rial % 10 = 0),
  CONSTRAINT ck_payment_balance_3 CHECK (refunded_rial >= 0 AND refunded_rial % 10 = 0),
  CONSTRAINT ck_payment_balance_4 CHECK (refunded_rial + refund_reserved_rial <= captured_rial)
);

-- Owner: Payments; rollout: MVP-if-payments; lifecycle: archive
CREATE TABLE refund (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  transaction_id uuid NOT NULL,
  requested_rial bigint NOT NULL,
  state text NOT NULL DEFAULT 'REQUESTED',
  reason_code text NOT NULL,
  provider_idempotency_key text NOT NULL,
  provider_ref text,
  policy_acceptance_id uuid,
  authorized_by uuid,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_refund_0 UNIQUE (business_id, id),
  CONSTRAINT uq_refund_1 UNIQUE (business_id, provider_idempotency_key),
  CONSTRAINT ck_refund_0 CHECK (row_version > 0),
  CONSTRAINT ck_refund_1 CHECK (requested_rial > 0 AND requested_rial % 10 = 0),
  CONSTRAINT ck_refund_2 CHECK (state IN ('REQUESTED','AUTHORIZED','SUBMITTED','SUCCEEDED','FAILED','UNKNOWN','CANCELLED'))
);

-- Owner: Payments; rollout: MVP-if-payments; lifecycle: append
CREATE TABLE financial_audit_record (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  transaction_id uuid NOT NULL,
  refund_id uuid,
  entry_kind text NOT NULL,
  amount_rial bigint NOT NULL,
  operation_key text NOT NULL,
  reason_code text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_financial_audit_record_0 UNIQUE (business_id, id),
  CONSTRAINT uq_financial_audit_record_1 UNIQUE (business_id, operation_key, entry_kind),
  CONSTRAINT ck_financial_audit_record_0 CHECK (entry_kind IN ('CAPTURE_VERIFIED','APPLIED','REFUND_RESERVED','REFUND_SUCCEEDED','REFUND_RELEASED','COMPENSATION_REQUIRED')),
  CONSTRAINT ck_financial_audit_record_1 CHECK (amount_rial > 0 AND amount_rial % 10 = 0)
);

-- Owner: Infrastructure; rollout: MVP; lifecycle: purge
CREATE TABLE idempotency_record (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  actor_key text NOT NULL,
  route_key text NOT NULL,
  idempotency_key text NOT NULL,
  request_hash bytea NOT NULL,
  state text NOT NULL,
  response_code integer,
  response_snapshot jsonb,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT uq_idempotency_record_0 UNIQUE (business_id, id),
  CONSTRAINT uq_idempotency_record_1 UNIQUE (business_id, actor_key, route_key, idempotency_key),
  CONSTRAINT ck_idempotency_record_0 CHECK (row_version > 0),
  CONSTRAINT ck_idempotency_record_1 CHECK (state IN ('PROCESSING','COMPLETE')),
  CONSTRAINT ck_idempotency_record_2 CHECK (expires_at > created_at),
  CONSTRAINT ck_idempotency_record_3 CHECK (state <> 'COMPLETE' OR (response_code IS NOT NULL AND response_snapshot IS NOT NULL)),
  CONSTRAINT ck_idempotency_record_4 CHECK (octet_length(request_hash) = 32),
  CONSTRAINT ck_idempotency_record_5 CHECK (isfinite(expires_at))
);

-- Owner: Infrastructure; rollout: MVP; lifecycle: append
CREATE TABLE outbox_event (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  aggregate_type text NOT NULL,
  aggregate_id uuid NOT NULL,
  aggregate_version bigint NOT NULL,
  event_type text NOT NULL,
  schema_version integer NOT NULL,
  payload jsonb NOT NULL,
  available_at timestamptz NOT NULL,
  published_at timestamptz,
  publish_attempts integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_outbox_event_0 UNIQUE (business_id, id),
  CONSTRAINT uq_outbox_event_1 UNIQUE (business_id, aggregate_type, aggregate_id, aggregate_version, event_type),
  CONSTRAINT ck_outbox_event_0 CHECK (aggregate_version > 0 AND schema_version > 0),
  CONSTRAINT ck_outbox_event_1 CHECK (publish_attempts >= 0),
  CONSTRAINT ck_outbox_event_2 CHECK (jsonb_typeof(payload) = 'object')
);

-- Owner: Infrastructure; rollout: MVP; lifecycle: purge
CREATE TABLE consumer_inbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  event_id uuid NOT NULL,
  consumer_key text NOT NULL,
  processed_at timestamptz,
  state text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT uq_consumer_inbox_0 UNIQUE (business_id, id),
  CONSTRAINT uq_consumer_inbox_1 UNIQUE (business_id, event_id, consumer_key),
  CONSTRAINT ck_consumer_inbox_0 CHECK (row_version > 0),
  CONSTRAINT ck_consumer_inbox_1 CHECK (state IN ('PROCESSING','COMPLETE'))
);

-- Owner: Media; rollout: Later-content; lifecycle: archive
CREATE TABLE media_asset (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  uploaded_by uuid NOT NULL,
  object_key text NOT NULL,
  mime_type text NOT NULL,
  byte_size bigint NOT NULL,
  sha256 bytea NOT NULL,
  status text NOT NULL DEFAULT 'QUARANTINED',
  visibility text NOT NULL DEFAULT 'PRIVATE',
  recognizable_person boolean,
  validated_at timestamptz,
  consent_checked_at timestamptz,
  purge_after timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_media_asset_0 UNIQUE (business_id, id),
  CONSTRAINT uq_media_asset_1 UNIQUE (business_id, object_key),
  CONSTRAINT ck_media_asset_0 CHECK (row_version > 0),
  CONSTRAINT ck_media_asset_1 CHECK (byte_size > 0),
  CONSTRAINT ck_media_asset_2 CHECK (status IN ('QUARANTINED','PROCESSING','READY','REJECTED','DELETED')),
  CONSTRAINT ck_media_asset_3 CHECK (visibility IN ('PRIVATE','PUBLISHED')),
  CONSTRAINT ck_media_asset_4 CHECK (visibility <> 'PUBLISHED' OR (status='READY' AND validated_at IS NOT NULL AND recognizable_person IS NOT NULL AND consent_checked_at IS NOT NULL)),
  CONSTRAINT ck_media_asset_5 CHECK (octet_length(sha256) = 32)
);

-- Owner: Media; rollout: Later-content; lifecycle: archive
CREATE TABLE media_variant (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  asset_id uuid NOT NULL,
  variant_key text NOT NULL,
  object_key text NOT NULL,
  mime_type text NOT NULL,
  byte_size bigint NOT NULL,
  width integer,
  height integer,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_media_variant_0 UNIQUE (business_id, id),
  CONSTRAINT uq_media_variant_1 UNIQUE (business_id, asset_id, variant_key),
  CONSTRAINT uq_media_variant_2 UNIQUE (business_id, object_key),
  CONSTRAINT ck_media_variant_0 CHECK (row_version > 0),
  CONSTRAINT ck_media_variant_1 CHECK (byte_size > 0),
  CONSTRAINT ck_media_variant_2 CHECK (width IS NULL OR width > 0),
  CONSTRAINT ck_media_variant_3 CHECK (height IS NULL OR height > 0)
);

-- Owner: Media; rollout: Later-content; lifecycle: append
CREATE TABLE media_publication_consent (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  asset_id uuid NOT NULL,
  subject_customer_id uuid,
  subject_ref_hash bytea NOT NULL,
  scope text NOT NULL,
  evidence_key text NOT NULL,
  text_version text NOT NULL,
  granted_at timestamptz NOT NULL,
  valid_until timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_media_publication_consent_0 UNIQUE (business_id, id),
  CONSTRAINT ck_media_publication_consent_0 CHECK (scope IN ('INTERNAL_REVIEW','WEBSITE','SOCIAL')),
  CONSTRAINT ck_media_publication_consent_1 CHECK (valid_until IS NULL OR valid_until > granted_at),
  CONSTRAINT ck_media_publication_consent_2 CHECK (revoked_at IS NULL OR revoked_at >= granted_at),
  CONSTRAINT ck_media_publication_consent_3 CHECK (octet_length(subject_ref_hash) = 32)
);

-- Owner: Media; rollout: Later-content; lifecycle: archive
CREATE TABLE portfolio_category (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  code text NOT NULL,
  display_name text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_portfolio_category_0 UNIQUE (business_id, id),
  CONSTRAINT uq_portfolio_category_1 UNIQUE (business_id, code),
  CONSTRAINT ck_portfolio_category_0 CHECK (row_version > 0),
  CONSTRAINT ck_portfolio_category_1 CHECK (sort_order >= 0)
);

-- Owner: Media; rollout: Later-content; lifecycle: archive
CREATE TABLE portfolio_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  branch_id uuid,
  staff_id uuid,
  title text NOT NULL,
  description text,
  kind text NOT NULL,
  status text NOT NULL DEFAULT 'DRAFT',
  sort_order integer NOT NULL DEFAULT 0,
  attribution_verified_at timestamptz,
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_portfolio_item_0 UNIQUE (business_id, id),
  CONSTRAINT ck_portfolio_item_0 CHECK (row_version > 0),
  CONSTRAINT ck_portfolio_item_1 CHECK (kind IN ('HAIRCUT','GROOM','BEFORE_AFTER','BARBER','INTERIOR','SERVICE')),
  CONSTRAINT ck_portfolio_item_2 CHECK (status IN ('DRAFT','PUBLISHED','UNPUBLISHED')),
  CONSTRAINT ck_portfolio_item_3 CHECK (sort_order >= 0),
  CONSTRAINT ck_portfolio_item_4 CHECK (status <> 'PUBLISHED' OR published_at IS NOT NULL)
);

-- Owner: Media; rollout: Later-content; lifecycle: archive
CREATE TABLE portfolio_item_category (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  item_id uuid NOT NULL,
  category_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_portfolio_item_category_0 UNIQUE (business_id, id),
  CONSTRAINT uq_portfolio_item_category_1 UNIQUE (business_id, item_id, category_id),
  CONSTRAINT ck_portfolio_item_category_0 CHECK (row_version > 0)
);

-- Owner: Media; rollout: Later-content; lifecycle: archive
CREATE TABLE portfolio_service_relation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  item_id uuid NOT NULL,
  service_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_portfolio_service_relation_0 UNIQUE (business_id, id),
  CONSTRAINT uq_portfolio_service_relation_1 UNIQUE (business_id, item_id, service_id),
  CONSTRAINT ck_portfolio_service_relation_0 CHECK (row_version > 0)
);

-- Owner: Media; rollout: Later-content; lifecycle: archive
CREATE TABLE portfolio_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  item_id uuid NOT NULL,
  asset_id uuid NOT NULL,
  role text NOT NULL,
  comparison_group uuid,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_portfolio_media_0 UNIQUE (business_id, id),
  CONSTRAINT uq_portfolio_media_1 UNIQUE (business_id, item_id, sort_order),
  CONSTRAINT ck_portfolio_media_0 CHECK (row_version > 0),
  CONSTRAINT ck_portfolio_media_1 CHECK (role IN ('COVER','GALLERY','BEFORE','AFTER')),
  CONSTRAINT ck_portfolio_media_2 CHECK (sort_order >= 0),
  CONSTRAINT ck_portfolio_media_3 CHECK ((role IN ('BEFORE','AFTER') AND comparison_group IS NOT NULL) OR (role NOT IN ('BEFORE','AFTER') AND comparison_group IS NULL))
);

-- Owner: Media; rollout: Later-content; lifecycle: archive
CREATE TABLE portfolio_tag (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  slug text NOT NULL,
  label text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_portfolio_tag_0 UNIQUE (business_id, id),
  CONSTRAINT uq_portfolio_tag_1 UNIQUE (business_id, slug),
  CONSTRAINT ck_portfolio_tag_0 CHECK (row_version > 0)
);

-- Owner: Media; rollout: Later-content; lifecycle: archive
CREATE TABLE portfolio_item_tag (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  item_id uuid NOT NULL,
  tag_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_portfolio_item_tag_0 UNIQUE (business_id, id),
  CONSTRAINT uq_portfolio_item_tag_1 UNIQUE (business_id, item_id, tag_id),
  CONSTRAINT ck_portfolio_item_tag_0 CHECK (row_version > 0)
);

-- Owner: Notifications; rollout: MVP; lifecycle: archive
CREATE TABLE notification_channel_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  branch_id uuid,
  channel text NOT NULL,
  provider_key text NOT NULL,
  secret_ref text NOT NULL,
  enabled boolean NOT NULL DEFAULT false,
  settings_revision bigint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_notification_channel_config_0 UNIQUE (business_id, id),
  CONSTRAINT ck_notification_channel_config_0 CHECK (row_version > 0),
  CONSTRAINT ck_notification_channel_config_1 CHECK (channel IN ('SMS','TELEGRAM','BALE')),
  CONSTRAINT ck_notification_channel_config_2 CHECK (settings_revision > 0)
);

-- Owner: Notifications; rollout: MVP; lifecycle: append
CREATE TABLE notification_template (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  branch_id uuid,
  code text NOT NULL,
  channel text NOT NULL,
  version_number integer NOT NULL,
  locale text NOT NULL,
  body text NOT NULL,
  active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_notification_template_0 UNIQUE (business_id, id),
  CONSTRAINT ck_notification_template_0 CHECK (channel IN ('SMS','TELEGRAM','BALE')),
  CONSTRAINT ck_notification_template_1 CHECK (version_number > 0)
);

-- Owner: Notifications; rollout: MVP; lifecycle: archive
CREATE TABLE notification_preference (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  channel text NOT NULL,
  purpose text NOT NULL,
  opted_in boolean NOT NULL DEFAULT false,
  consented_at timestamptz,
  consent_text_version text,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_notification_preference_0 UNIQUE (business_id, id),
  CONSTRAINT uq_notification_preference_1 UNIQUE (business_id, customer_id, channel, purpose),
  CONSTRAINT ck_notification_preference_0 CHECK (row_version > 0),
  CONSTRAINT ck_notification_preference_1 CHECK (channel IN ('SMS','TELEGRAM','BALE')),
  CONSTRAINT ck_notification_preference_2 CHECK (purpose IN ('TRANSACTIONAL','MARKETING')),
  CONSTRAINT ck_notification_preference_3 CHECK (NOT opted_in OR (consented_at IS NOT NULL AND consent_text_version IS NOT NULL AND revoked_at IS NULL))
);

-- Owner: Notifications; rollout: Later; lifecycle: purge
CREATE TABLE notification_link_challenge (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  channel text NOT NULL,
  token_hash bytea NOT NULL,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  CONSTRAINT uq_notification_link_challenge_0 UNIQUE (business_id, id),
  CONSTRAINT uq_notification_link_challenge_1 UNIQUE (business_id, token_hash),
  CONSTRAINT ck_notification_link_challenge_0 CHECK (row_version > 0),
  CONSTRAINT ck_notification_link_challenge_1 CHECK (channel IN ('TELEGRAM','BALE')),
  CONSTRAINT ck_notification_link_challenge_2 CHECK (expires_at > created_at),
  CONSTRAINT ck_notification_link_challenge_3 CHECK (octet_length(token_hash) = 32),
  CONSTRAINT ck_notification_link_challenge_4 CHECK (isfinite(expires_at))
);

-- Owner: Notifications; rollout: Later; lifecycle: archive
CREATE TABLE channel_identity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  channel text NOT NULL,
  external_id_ciphertext bytea NOT NULL,
  external_id_hash bytea NOT NULL,
  linked_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_channel_identity_0 UNIQUE (business_id, id),
  CONSTRAINT uq_channel_identity_1 UNIQUE (business_id, customer_id, channel),
  CONSTRAINT uq_channel_identity_2 UNIQUE (business_id, channel, external_id_hash),
  CONSTRAINT ck_channel_identity_0 CHECK (row_version > 0),
  CONSTRAINT ck_channel_identity_1 CHECK (channel IN ('TELEGRAM','BALE')),
  CONSTRAINT ck_channel_identity_2 CHECK (octet_length(external_id_hash) = 32)
);

-- Owner: Notifications; rollout: MVP; lifecycle: archive
CREATE TABLE notification_event (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  booking_id uuid,
  booking_revision_id uuid,
  template_id uuid NOT NULL,
  source_event_id uuid NOT NULL,
  channel text NOT NULL,
  purpose text NOT NULL,
  state text NOT NULL DEFAULT 'SCHEDULED',
  scheduled_at timestamptz NOT NULL,
  dedup_key text NOT NULL,
  template_parameters jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_notification_event_0 UNIQUE (business_id, id),
  CONSTRAINT uq_notification_event_1 UNIQUE (business_id, dedup_key),
  CONSTRAINT ck_notification_event_0 CHECK (row_version > 0),
  CONSTRAINT ck_notification_event_1 CHECK (channel IN ('SMS','TELEGRAM','BALE')),
  CONSTRAINT ck_notification_event_2 CHECK (purpose IN ('TRANSACTIONAL','MARKETING')),
  CONSTRAINT ck_notification_event_3 CHECK (state IN ('SCHEDULED','SENDING','DELIVERED','FAILED','CANCELLED','UNKNOWN')),
  CONSTRAINT ck_notification_event_4 CHECK (jsonb_typeof(template_parameters) = 'object'),
  CONSTRAINT ck_notification_event_5 CHECK (isfinite(scheduled_at))
);

-- Owner: Notifications; rollout: MVP; lifecycle: append
CREATE TABLE notification_delivery_attempt (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  notification_event_id uuid NOT NULL,
  attempt_number integer NOT NULL,
  provider_key text NOT NULL,
  provider_message_ref text,
  state text NOT NULL,
  retry_after timestamptz,
  failure_code text,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_notification_delivery_attempt_0 UNIQUE (business_id, id),
  CONSTRAINT uq_notification_delivery_attempt_1 UNIQUE (business_id, notification_event_id, attempt_number),
  CONSTRAINT ck_notification_delivery_attempt_0 CHECK (attempt_number > 0),
  CONSTRAINT ck_notification_delivery_attempt_1 CHECK (state IN ('SUBMITTED','DELIVERED','FAILED','UNKNOWN'))
);

-- Owner: Audit; rollout: MVP; lifecycle: append
CREATE TABLE audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  actor_user_id uuid,
  branch_id uuid,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id uuid,
  request_id uuid NOT NULL,
  reason_code text,
  redacted_change jsonb,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_audit_log_0 UNIQUE (business_id, id)
);

-- Owner: Offerings; rollout: MVP; lifecycle: archive
CREATE TABLE offering_resource_requirement (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  offering_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  service_id uuid NOT NULL,
  resource_kind text NOT NULL,
  quantity integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  row_version bigint NOT NULL DEFAULT 1,
  archived_at timestamptz,
  CONSTRAINT uq_offering_resource_requirement_0 UNIQUE (business_id, id),
  CONSTRAINT uq_offering_resource_requirement_1 UNIQUE (business_id, offering_id, resource_kind),
  CONSTRAINT ck_offering_resource_requirement_0 CHECK (row_version > 0),
  CONSTRAINT ck_offering_resource_requirement_1 CHECK (resource_kind IN ('CHAIR','ROOM','DEVICE')),
  CONSTRAINT ck_offering_resource_requirement_2 CHECK (quantity > 0)
);

-- Owner: Booking; rollout: MVP; lifecycle: append
CREATE TABLE segment_resource_assignment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL,
  revision_id uuid NOT NULL,
  segment_id uuid NOT NULL,
  resource_id uuid NOT NULL,
  allocation_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by uuid,
  CONSTRAINT uq_segment_resource_assignment_0 UNIQUE (business_id, id),
  CONSTRAINT uq_segment_resource_assignment_1 UNIQUE (business_id, segment_id, resource_id)
);

ALTER TABLE business ADD CONSTRAINT fk_business_0 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE app_user ADD CONSTRAINT fk_app_user_0 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE auth_identity ADD CONSTRAINT fk_auth_identity_0 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE auth_identity ADD CONSTRAINT fk_auth_identity_1 FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE auth_session ADD CONSTRAINT fk_auth_session_0 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE auth_session ADD CONSTRAINT fk_auth_session_1 FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE permission ADD CONSTRAINT fk_permission_0 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE role ADD CONSTRAINT fk_role_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE role ADD CONSTRAINT fk_role_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE role_permission ADD CONSTRAINT fk_role_permission_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE role_permission ADD CONSTRAINT fk_role_permission_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE role_permission ADD CONSTRAINT fk_role_permission_2 FOREIGN KEY (business_id, role_id) REFERENCES role (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE role_permission ADD CONSTRAINT fk_role_permission_3 FOREIGN KEY (permission_id) REFERENCES permission (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch ADD CONSTRAINT fk_branch_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch ADD CONSTRAINT fk_branch_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE user_role_assignment ADD CONSTRAINT fk_user_role_assignment_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE user_role_assignment ADD CONSTRAINT fk_user_role_assignment_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE user_role_assignment ADD CONSTRAINT fk_user_role_assignment_2 FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE user_role_assignment ADD CONSTRAINT fk_user_role_assignment_3 FOREIGN KEY (business_id, role_id) REFERENCES role (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE user_role_assignment ADD CONSTRAINT fk_user_role_assignment_4 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch_working_hours ADD CONSTRAINT fk_branch_working_hours_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch_working_hours ADD CONSTRAINT fk_branch_working_hours_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch_working_hours ADD CONSTRAINT fk_branch_working_hours_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch_closure ADD CONSTRAINT fk_branch_closure_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch_closure ADD CONSTRAINT fk_branch_closure_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch_closure ADD CONSTRAINT fk_branch_closure_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch_closure ADD CONSTRAINT fk_branch_closure_3 FOREIGN KEY (approved_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE resource ADD CONSTRAINT fk_resource_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE resource ADD CONSTRAINT fk_resource_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE resource ADD CONSTRAINT fk_resource_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE service ADD CONSTRAINT fk_service_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE service ADD CONSTRAINT fk_service_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch_service_offering ADD CONSTRAINT fk_branch_service_offering_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch_service_offering ADD CONSTRAINT fk_branch_service_offering_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch_service_offering ADD CONSTRAINT fk_branch_service_offering_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE branch_service_offering ADD CONSTRAINT fk_branch_service_offering_3 FOREIGN KEY (business_id, service_id) REFERENCES service (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff ADD CONSTRAINT fk_staff_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff ADD CONSTRAINT fk_staff_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff ADD CONSTRAINT fk_staff_2 FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff ADD CONSTRAINT fk_staff_3 FOREIGN KEY (business_id, resource_id, resource_kind) REFERENCES resource (business_id, id, kind) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_branch_assignment ADD CONSTRAINT fk_staff_branch_assignment_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_branch_assignment ADD CONSTRAINT fk_staff_branch_assignment_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_branch_assignment ADD CONSTRAINT fk_staff_branch_assignment_2 FOREIGN KEY (business_id, staff_id) REFERENCES staff (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_branch_assignment ADD CONSTRAINT fk_staff_branch_assignment_3 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_service_eligibility ADD CONSTRAINT fk_staff_service_eligibility_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_service_eligibility ADD CONSTRAINT fk_staff_service_eligibility_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_service_eligibility ADD CONSTRAINT fk_staff_service_eligibility_2 FOREIGN KEY (business_id, staff_id) REFERENCES staff (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_service_eligibility ADD CONSTRAINT fk_staff_service_eligibility_3 FOREIGN KEY (business_id, service_id) REFERENCES service (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE offering_staff_eligibility ADD CONSTRAINT fk_offering_staff_eligibility_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE offering_staff_eligibility ADD CONSTRAINT fk_offering_staff_eligibility_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE offering_staff_eligibility ADD CONSTRAINT fk_offering_staff_eligibility_2 FOREIGN KEY (business_id, offering_id, branch_id, service_id) REFERENCES branch_service_offering (business_id, id, branch_id, service_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE offering_staff_eligibility ADD CONSTRAINT fk_offering_staff_eligibility_3 FOREIGN KEY (business_id, assignment_id, staff_id, branch_id) REFERENCES staff_branch_assignment (business_id, id, staff_id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE offering_staff_eligibility ADD CONSTRAINT fk_offering_staff_eligibility_4 FOREIGN KEY (business_id, qualification_id, staff_id, service_id) REFERENCES staff_service_eligibility (business_id, id, staff_id, service_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_schedule_rule ADD CONSTRAINT fk_staff_schedule_rule_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_schedule_rule ADD CONSTRAINT fk_staff_schedule_rule_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_schedule_rule ADD CONSTRAINT fk_staff_schedule_rule_2 FOREIGN KEY (business_id, assignment_id, staff_id, branch_id) REFERENCES staff_branch_assignment (business_id, id, staff_id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_shift ADD CONSTRAINT fk_staff_shift_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_shift ADD CONSTRAINT fk_staff_shift_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_shift ADD CONSTRAINT fk_staff_shift_2 FOREIGN KEY (business_id, assignment_id, staff_id, branch_id) REFERENCES staff_branch_assignment (business_id, id, staff_id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_shift ADD CONSTRAINT fk_staff_shift_3 FOREIGN KEY (business_id, schedule_rule_id, staff_id, branch_id) REFERENCES staff_schedule_rule (business_id, id, staff_id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_time_off ADD CONSTRAINT fk_staff_time_off_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_time_off ADD CONSTRAINT fk_staff_time_off_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_time_off ADD CONSTRAINT fk_staff_time_off_2 FOREIGN KEY (business_id, staff_id, resource_id) REFERENCES staff (business_id, id, resource_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE staff_time_off ADD CONSTRAINT fk_staff_time_off_3 FOREIGN KEY (approved_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE package ADD CONSTRAINT fk_package_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE package ADD CONSTRAINT fk_package_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE package_service ADD CONSTRAINT fk_package_service_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE package_service ADD CONSTRAINT fk_package_service_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE package_service ADD CONSTRAINT fk_package_service_2 FOREIGN KEY (business_id, package_id) REFERENCES package (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE package_service ADD CONSTRAINT fk_package_service_3 FOREIGN KEY (business_id, service_id) REFERENCES service (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE customer ADD CONSTRAINT fk_customer_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE customer ADD CONSTRAINT fk_customer_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE customer ADD CONSTRAINT fk_customer_2 FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE availability_configuration ADD CONSTRAINT fk_availability_configuration_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE availability_configuration ADD CONSTRAINT fk_availability_configuration_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE availability_configuration ADD CONSTRAINT fk_availability_configuration_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy ADD CONSTRAINT fk_booking_policy_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy ADD CONSTRAINT fk_booking_policy_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_version ADD CONSTRAINT fk_booking_policy_version_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_version ADD CONSTRAINT fk_booking_policy_version_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_version ADD CONSTRAINT fk_booking_policy_version_2 FOREIGN KEY (business_id, policy_id) REFERENCES booking_policy (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE policy_refund_window ADD CONSTRAINT fk_policy_refund_window_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE policy_refund_window ADD CONSTRAINT fk_policy_refund_window_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE policy_refund_window ADD CONSTRAINT fk_policy_refund_window_2 FOREIGN KEY (business_id, policy_version_id) REFERENCES booking_policy_version (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_assignment ADD CONSTRAINT fk_booking_policy_assignment_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_assignment ADD CONSTRAINT fk_booking_policy_assignment_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_assignment ADD CONSTRAINT fk_booking_policy_assignment_2 FOREIGN KEY (business_id, policy_version_id) REFERENCES booking_policy_version (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_assignment ADD CONSTRAINT fk_booking_policy_assignment_3 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_assignment ADD CONSTRAINT fk_booking_policy_assignment_4 FOREIGN KEY (business_id, service_id) REFERENCES service (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_assignment ADD CONSTRAINT fk_booking_policy_assignment_5 FOREIGN KEY (business_id, package_id) REFERENCES package (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_assignment ADD CONSTRAINT fk_booking_policy_assignment_6 FOREIGN KEY (business_id, booking_id) REFERENCES booking (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_assignment ADD CONSTRAINT fk_booking_policy_assignment_7 FOREIGN KEY (authorized_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE pricing_quote ADD CONSTRAINT fk_pricing_quote_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE pricing_quote ADD CONSTRAINT fk_pricing_quote_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE pricing_quote ADD CONSTRAINT fk_pricing_quote_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE pricing_quote ADD CONSTRAINT fk_pricing_quote_3 FOREIGN KEY (business_id, customer_id) REFERENCES customer (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE pricing_quote_item ADD CONSTRAINT fk_pricing_quote_item_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE pricing_quote_item ADD CONSTRAINT fk_pricing_quote_item_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE pricing_quote_item ADD CONSTRAINT fk_pricing_quote_item_2 FOREIGN KEY (business_id, quote_id, branch_id) REFERENCES pricing_quote (business_id, id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE pricing_quote_item ADD CONSTRAINT fk_pricing_quote_item_3 FOREIGN KEY (business_id, offering_id, branch_id, service_id) REFERENCES branch_service_offering (business_id, id, branch_id, service_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE pricing_quote_item ADD CONSTRAINT fk_pricing_quote_item_4 FOREIGN KEY (business_id, package_id) REFERENCES package (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE quote_policy_resolution ADD CONSTRAINT fk_quote_policy_resolution_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE quote_policy_resolution ADD CONSTRAINT fk_quote_policy_resolution_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE quote_policy_resolution ADD CONSTRAINT fk_quote_policy_resolution_2 FOREIGN KEY (business_id, quote_id) REFERENCES pricing_quote (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE quote_policy_resolution ADD CONSTRAINT fk_quote_policy_resolution_3 FOREIGN KEY (business_id, policy_version_id) REFERENCES booking_policy_version (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE quote_policy_source ADD CONSTRAINT fk_quote_policy_source_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE quote_policy_source ADD CONSTRAINT fk_quote_policy_source_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE quote_policy_source ADD CONSTRAINT fk_quote_policy_source_2 FOREIGN KEY (business_id, policy_version_id) REFERENCES booking_policy_version (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE quote_policy_source ADD CONSTRAINT fk_quote_policy_source_3 FOREIGN KEY (business_id, resolution_id, policy_version_id) REFERENCES quote_policy_resolution (business_id, id, policy_version_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE quote_policy_source ADD CONSTRAINT fk_quote_policy_source_4 FOREIGN KEY (business_id, assignment_id, policy_version_id) REFERENCES booking_policy_assignment (business_id, id, policy_version_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking ADD CONSTRAINT fk_booking_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking ADD CONSTRAINT fk_booking_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking ADD CONSTRAINT fk_booking_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking ADD CONSTRAINT fk_booking_3 FOREIGN KEY (business_id, customer_id) REFERENCES customer (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking ADD CONSTRAINT fk_booking_4 FOREIGN KEY (business_id, active_revision_id, id) REFERENCES booking_revision (business_id, id, booking_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_revision ADD CONSTRAINT fk_booking_revision_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_revision ADD CONSTRAINT fk_booking_revision_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_revision ADD CONSTRAINT fk_booking_revision_2 FOREIGN KEY (business_id, booking_id, branch_id) REFERENCES booking (business_id, id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_revision ADD CONSTRAINT fk_booking_revision_3 FOREIGN KEY (business_id, quote_id, branch_id) REFERENCES pricing_quote (business_id, id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_revision ADD CONSTRAINT fk_booking_revision_4 FOREIGN KEY (business_id, supersedes_revision_id, booking_id) REFERENCES booking_revision (business_id, id, booking_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_item ADD CONSTRAINT fk_booking_item_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_item ADD CONSTRAINT fk_booking_item_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_item ADD CONSTRAINT fk_booking_item_2 FOREIGN KEY (business_id, revision_id, quote_id) REFERENCES booking_revision (business_id, id, quote_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_item ADD CONSTRAINT fk_booking_item_3 FOREIGN KEY (business_id, quote_item_id, quote_id) REFERENCES pricing_quote_item (business_id, id, quote_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_service_segment ADD CONSTRAINT fk_booking_service_segment_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_service_segment ADD CONSTRAINT fk_booking_service_segment_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_service_segment ADD CONSTRAINT fk_booking_service_segment_2 FOREIGN KEY (business_id, item_id, revision_id) REFERENCES booking_item (business_id, id, revision_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE segment_dependency ADD CONSTRAINT fk_segment_dependency_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE segment_dependency ADD CONSTRAINT fk_segment_dependency_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE segment_dependency ADD CONSTRAINT fk_segment_dependency_2 FOREIGN KEY (business_id, segment_id, revision_id) REFERENCES booking_service_segment (business_id, id, revision_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE segment_dependency ADD CONSTRAINT fk_segment_dependency_3 FOREIGN KEY (business_id, predecessor_id, revision_id) REFERENCES booking_service_segment (business_id, id, revision_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_hold ADD CONSTRAINT fk_booking_hold_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_hold ADD CONSTRAINT fk_booking_hold_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_hold ADD CONSTRAINT fk_booking_hold_2 FOREIGN KEY (business_id, revision_id, booking_id) REFERENCES booking_revision (business_id, id, booking_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE resource_allocation ADD CONSTRAINT fk_resource_allocation_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE resource_allocation ADD CONSTRAINT fk_resource_allocation_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE resource_allocation ADD CONSTRAINT fk_resource_allocation_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE resource_allocation ADD CONSTRAINT fk_resource_allocation_3 FOREIGN KEY (business_id, revision_id, branch_id) REFERENCES booking_revision (business_id, id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE resource_allocation ADD CONSTRAINT fk_resource_allocation_4 FOREIGN KEY (business_id, hold_id, revision_id) REFERENCES booking_hold (business_id, id, revision_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE resource_allocation ADD CONSTRAINT fk_resource_allocation_5 FOREIGN KEY (business_id, time_off_id, resource_id) REFERENCES staff_time_off (business_id, id, resource_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE resource_allocation ADD CONSTRAINT fk_resource_allocation_6 FOREIGN KEY (business_id, resource_id, resource_kind) REFERENCES resource (business_id, id, kind) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE resource_allocation ADD CONSTRAINT fk_resource_allocation_7 FOREIGN KEY (business_id, resource_id, resource_branch_id) REFERENCES resource (business_id, id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE resource_allocation ADD CONSTRAINT fk_resource_allocation_8 FOREIGN KEY (business_id, closure_id, branch_id) REFERENCES branch_closure (business_id, id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_status_history ADD CONSTRAINT fk_booking_status_history_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_status_history ADD CONSTRAINT fk_booking_status_history_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_status_history ADD CONSTRAINT fk_booking_status_history_2 FOREIGN KEY (business_id, booking_id) REFERENCES booking (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_acceptance ADD CONSTRAINT fk_booking_policy_acceptance_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_acceptance ADD CONSTRAINT fk_booking_policy_acceptance_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_acceptance ADD CONSTRAINT fk_booking_policy_acceptance_2 FOREIGN KEY (business_id, revision_id, booking_id) REFERENCES booking_revision (business_id, id, booking_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_acceptance ADD CONSTRAINT fk_booking_policy_acceptance_3 FOREIGN KEY (business_id, revision_id, quote_id) REFERENCES booking_revision (business_id, id, quote_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_acceptance ADD CONSTRAINT fk_booking_policy_acceptance_4 FOREIGN KEY (business_id, resolution_id, quote_id) REFERENCES quote_policy_resolution (business_id, id, quote_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking_policy_acceptance ADD CONSTRAINT fk_booking_policy_acceptance_5 FOREIGN KEY (actor_user_id) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_intent ADD CONSTRAINT fk_payment_intent_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_intent ADD CONSTRAINT fk_payment_intent_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_intent ADD CONSTRAINT fk_payment_intent_2 FOREIGN KEY (business_id, revision_id) REFERENCES booking_revision (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_intent ADD CONSTRAINT fk_payment_intent_3 FOREIGN KEY (business_id, hold_id, revision_id) REFERENCES booking_hold (business_id, id, revision_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE gateway_event ADD CONSTRAINT fk_gateway_event_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE gateway_event ADD CONSTRAINT fk_gateway_event_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_transaction ADD CONSTRAINT fk_payment_transaction_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_transaction ADD CONSTRAINT fk_payment_transaction_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_transaction ADD CONSTRAINT fk_payment_transaction_2 FOREIGN KEY (business_id, intent_id, revision_id) REFERENCES payment_intent (business_id, id, revision_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_transaction ADD CONSTRAINT fk_payment_transaction_3 FOREIGN KEY (business_id, gateway_event_id) REFERENCES gateway_event (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_application ADD CONSTRAINT fk_payment_application_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_application ADD CONSTRAINT fk_payment_application_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_application ADD CONSTRAINT fk_payment_application_2 FOREIGN KEY (business_id, transaction_id, revision_id) REFERENCES payment_transaction (business_id, id, revision_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_balance ADD CONSTRAINT fk_payment_balance_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_balance ADD CONSTRAINT fk_payment_balance_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE payment_balance ADD CONSTRAINT fk_payment_balance_2 FOREIGN KEY (business_id, transaction_id) REFERENCES payment_transaction (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE refund ADD CONSTRAINT fk_refund_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE refund ADD CONSTRAINT fk_refund_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE refund ADD CONSTRAINT fk_refund_2 FOREIGN KEY (business_id, transaction_id) REFERENCES payment_transaction (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE refund ADD CONSTRAINT fk_refund_3 FOREIGN KEY (business_id, policy_acceptance_id) REFERENCES booking_policy_acceptance (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE refund ADD CONSTRAINT fk_refund_4 FOREIGN KEY (authorized_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE financial_audit_record ADD CONSTRAINT fk_financial_audit_record_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE financial_audit_record ADD CONSTRAINT fk_financial_audit_record_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE financial_audit_record ADD CONSTRAINT fk_financial_audit_record_2 FOREIGN KEY (business_id, transaction_id) REFERENCES payment_transaction (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE financial_audit_record ADD CONSTRAINT fk_financial_audit_record_3 FOREIGN KEY (business_id, refund_id) REFERENCES refund (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE idempotency_record ADD CONSTRAINT fk_idempotency_record_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE idempotency_record ADD CONSTRAINT fk_idempotency_record_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE outbox_event ADD CONSTRAINT fk_outbox_event_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE outbox_event ADD CONSTRAINT fk_outbox_event_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE consumer_inbox ADD CONSTRAINT fk_consumer_inbox_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE consumer_inbox ADD CONSTRAINT fk_consumer_inbox_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE consumer_inbox ADD CONSTRAINT fk_consumer_inbox_2 FOREIGN KEY (business_id, event_id) REFERENCES outbox_event (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE media_asset ADD CONSTRAINT fk_media_asset_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE media_asset ADD CONSTRAINT fk_media_asset_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE media_asset ADD CONSTRAINT fk_media_asset_2 FOREIGN KEY (uploaded_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE media_variant ADD CONSTRAINT fk_media_variant_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE media_variant ADD CONSTRAINT fk_media_variant_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE media_variant ADD CONSTRAINT fk_media_variant_2 FOREIGN KEY (business_id, asset_id) REFERENCES media_asset (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE media_publication_consent ADD CONSTRAINT fk_media_publication_consent_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE media_publication_consent ADD CONSTRAINT fk_media_publication_consent_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE media_publication_consent ADD CONSTRAINT fk_media_publication_consent_2 FOREIGN KEY (business_id, asset_id) REFERENCES media_asset (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE media_publication_consent ADD CONSTRAINT fk_media_publication_consent_3 FOREIGN KEY (business_id, subject_customer_id) REFERENCES customer (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_category ADD CONSTRAINT fk_portfolio_category_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_category ADD CONSTRAINT fk_portfolio_category_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_item ADD CONSTRAINT fk_portfolio_item_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_item ADD CONSTRAINT fk_portfolio_item_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_item ADD CONSTRAINT fk_portfolio_item_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_item ADD CONSTRAINT fk_portfolio_item_3 FOREIGN KEY (business_id, staff_id) REFERENCES staff (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_item_category ADD CONSTRAINT fk_portfolio_item_category_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_item_category ADD CONSTRAINT fk_portfolio_item_category_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_item_category ADD CONSTRAINT fk_portfolio_item_category_2 FOREIGN KEY (business_id, item_id) REFERENCES portfolio_item (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_item_category ADD CONSTRAINT fk_portfolio_item_category_3 FOREIGN KEY (business_id, category_id) REFERENCES portfolio_category (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_service_relation ADD CONSTRAINT fk_portfolio_service_relation_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_service_relation ADD CONSTRAINT fk_portfolio_service_relation_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_service_relation ADD CONSTRAINT fk_portfolio_service_relation_2 FOREIGN KEY (business_id, item_id) REFERENCES portfolio_item (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_service_relation ADD CONSTRAINT fk_portfolio_service_relation_3 FOREIGN KEY (business_id, service_id) REFERENCES service (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_media ADD CONSTRAINT fk_portfolio_media_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_media ADD CONSTRAINT fk_portfolio_media_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_media ADD CONSTRAINT fk_portfolio_media_2 FOREIGN KEY (business_id, item_id) REFERENCES portfolio_item (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_media ADD CONSTRAINT fk_portfolio_media_3 FOREIGN KEY (business_id, asset_id) REFERENCES media_asset (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_tag ADD CONSTRAINT fk_portfolio_tag_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_tag ADD CONSTRAINT fk_portfolio_tag_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_item_tag ADD CONSTRAINT fk_portfolio_item_tag_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_item_tag ADD CONSTRAINT fk_portfolio_item_tag_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_item_tag ADD CONSTRAINT fk_portfolio_item_tag_2 FOREIGN KEY (business_id, item_id) REFERENCES portfolio_item (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE portfolio_item_tag ADD CONSTRAINT fk_portfolio_item_tag_3 FOREIGN KEY (business_id, tag_id) REFERENCES portfolio_tag (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_channel_config ADD CONSTRAINT fk_notification_channel_config_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_channel_config ADD CONSTRAINT fk_notification_channel_config_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_channel_config ADD CONSTRAINT fk_notification_channel_config_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_template ADD CONSTRAINT fk_notification_template_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_template ADD CONSTRAINT fk_notification_template_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_template ADD CONSTRAINT fk_notification_template_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_preference ADD CONSTRAINT fk_notification_preference_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_preference ADD CONSTRAINT fk_notification_preference_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_preference ADD CONSTRAINT fk_notification_preference_2 FOREIGN KEY (business_id, customer_id) REFERENCES customer (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_link_challenge ADD CONSTRAINT fk_notification_link_challenge_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_link_challenge ADD CONSTRAINT fk_notification_link_challenge_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_link_challenge ADD CONSTRAINT fk_notification_link_challenge_2 FOREIGN KEY (business_id, customer_id) REFERENCES customer (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE channel_identity ADD CONSTRAINT fk_channel_identity_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE channel_identity ADD CONSTRAINT fk_channel_identity_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE channel_identity ADD CONSTRAINT fk_channel_identity_2 FOREIGN KEY (business_id, customer_id) REFERENCES customer (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_event ADD CONSTRAINT fk_notification_event_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_event ADD CONSTRAINT fk_notification_event_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_event ADD CONSTRAINT fk_notification_event_2 FOREIGN KEY (business_id, customer_id) REFERENCES customer (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_event ADD CONSTRAINT fk_notification_event_3 FOREIGN KEY (business_id, booking_id) REFERENCES booking (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_event ADD CONSTRAINT fk_notification_event_4 FOREIGN KEY (business_id, booking_revision_id, booking_id) REFERENCES booking_revision (business_id, id, booking_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_event ADD CONSTRAINT fk_notification_event_5 FOREIGN KEY (business_id, template_id) REFERENCES notification_template (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_event ADD CONSTRAINT fk_notification_event_6 FOREIGN KEY (business_id, source_event_id) REFERENCES outbox_event (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_delivery_attempt ADD CONSTRAINT fk_notification_delivery_attempt_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_delivery_attempt ADD CONSTRAINT fk_notification_delivery_attempt_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE notification_delivery_attempt ADD CONSTRAINT fk_notification_delivery_attempt_2 FOREIGN KEY (business_id, notification_event_id) REFERENCES notification_event (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE audit_log ADD CONSTRAINT fk_audit_log_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE audit_log ADD CONSTRAINT fk_audit_log_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE audit_log ADD CONSTRAINT fk_audit_log_2 FOREIGN KEY (actor_user_id) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE audit_log ADD CONSTRAINT fk_audit_log_3 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE offering_resource_requirement ADD CONSTRAINT fk_offering_resource_requirement_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE offering_resource_requirement ADD CONSTRAINT fk_offering_resource_requirement_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE offering_resource_requirement ADD CONSTRAINT fk_offering_resource_requirement_2 FOREIGN KEY (business_id, offering_id, branch_id, service_id) REFERENCES branch_service_offering (business_id, id, branch_id, service_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE segment_resource_assignment ADD CONSTRAINT fk_segment_resource_assignment_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE segment_resource_assignment ADD CONSTRAINT fk_segment_resource_assignment_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE segment_resource_assignment ADD CONSTRAINT fk_segment_resource_assignment_2 FOREIGN KEY (business_id, segment_id, revision_id) REFERENCES booking_service_segment (business_id, id, revision_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE segment_resource_assignment ADD CONSTRAINT fk_segment_resource_assignment_3 FOREIGN KEY (business_id, allocation_id, revision_id, resource_id) REFERENCES resource_allocation (business_id, id, revision_id, resource_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE booking ALTER CONSTRAINT fk_booking_4 DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX ix_business_0 ON business (created_by);
CREATE INDEX ix_app_user_0 ON app_user (created_by);
CREATE INDEX ix_auth_identity_0 ON auth_identity (created_by);
CREATE INDEX ix_auth_identity_1 ON auth_identity (user_id);
CREATE INDEX ix_auth_session_0 ON auth_session (created_by);
CREATE INDEX ix_auth_session_1 ON auth_session (user_id);
CREATE INDEX ix_auth_session_2 ON auth_session (user_id, expires_at);
CREATE INDEX ix_permission_0 ON permission (created_by);
CREATE INDEX ix_role_0 ON role (created_by);
CREATE INDEX ix_role_permission_0 ON role_permission (created_by);
CREATE INDEX ix_role_permission_1 ON role_permission (permission_id);
CREATE INDEX ix_branch_0 ON branch (created_by);
CREATE INDEX ix_user_role_assignment_0 ON user_role_assignment (created_by);
CREATE INDEX ix_user_role_assignment_1 ON user_role_assignment (user_id);
CREATE INDEX ix_user_role_assignment_2 ON user_role_assignment (business_id, role_id);
CREATE INDEX ix_user_role_assignment_3 ON user_role_assignment (business_id, branch_id);
CREATE UNIQUE INDEX ix_user_role_assignment_4 ON user_role_assignment (business_id, user_id, role_id, branch_id) NULLS NOT DISTINCT WHERE revoked_at IS NULL;
CREATE INDEX ix_branch_working_hours_0 ON branch_working_hours (created_by);
CREATE INDEX ix_branch_closure_0 ON branch_closure (created_by);
CREATE INDEX ix_branch_closure_1 ON branch_closure (business_id, branch_id);
CREATE INDEX ix_branch_closure_2 ON branch_closure (approved_by);
CREATE INDEX ix_branch_closure_3 ON branch_closure (business_id, branch_id, starts_at, ends_at);
CREATE INDEX ix_resource_0 ON resource (created_by);
CREATE INDEX ix_resource_1 ON resource (business_id, branch_id);
CREATE INDEX ix_service_0 ON service (created_by);
CREATE INDEX ix_branch_service_offering_0 ON branch_service_offering (created_by);
CREATE INDEX ix_branch_service_offering_1 ON branch_service_offering (business_id, service_id);
CREATE INDEX ix_staff_0 ON staff (created_by);
CREATE INDEX ix_staff_1 ON staff (user_id);
CREATE INDEX ix_staff_2 ON staff (business_id, resource_id, resource_kind);
CREATE INDEX ix_staff_branch_assignment_0 ON staff_branch_assignment (created_by);
CREATE INDEX ix_staff_branch_assignment_1 ON staff_branch_assignment (business_id, branch_id);
CREATE INDEX ix_staff_service_eligibility_0 ON staff_service_eligibility (created_by);
CREATE INDEX ix_staff_service_eligibility_1 ON staff_service_eligibility (business_id, service_id);
CREATE INDEX ix_offering_staff_eligibility_0 ON offering_staff_eligibility (created_by);
CREATE INDEX ix_offering_staff_eligibility_1 ON offering_staff_eligibility (business_id, offering_id, branch_id, service_id);
CREATE INDEX ix_offering_staff_eligibility_2 ON offering_staff_eligibility (business_id, assignment_id, staff_id, branch_id);
CREATE INDEX ix_offering_staff_eligibility_3 ON offering_staff_eligibility (business_id, qualification_id, staff_id, service_id);
CREATE INDEX ix_staff_schedule_rule_0 ON staff_schedule_rule (created_by);
CREATE INDEX ix_staff_schedule_rule_1 ON staff_schedule_rule (business_id, assignment_id, staff_id, branch_id);
CREATE INDEX ix_staff_shift_0 ON staff_shift (created_by);
CREATE INDEX ix_staff_shift_1 ON staff_shift (business_id, assignment_id, staff_id, branch_id);
CREATE INDEX ix_staff_shift_2 ON staff_shift (business_id, schedule_rule_id, staff_id, branch_id);
CREATE INDEX ix_staff_shift_3 ON staff_shift (business_id, branch_id, starts_at);
CREATE INDEX ix_staff_time_off_0 ON staff_time_off (created_by);
CREATE INDEX ix_staff_time_off_1 ON staff_time_off (business_id, staff_id, resource_id);
CREATE INDEX ix_staff_time_off_2 ON staff_time_off (approved_by);
CREATE INDEX ix_package_0 ON package (created_by);
CREATE INDEX ix_package_service_0 ON package_service (created_by);
CREATE INDEX ix_package_service_1 ON package_service (business_id, service_id);
CREATE INDEX ix_customer_0 ON customer (created_by);
CREATE INDEX ix_customer_1 ON customer (user_id);
CREATE UNIQUE INDEX ix_customer_2 ON customer (business_id, contact_lookup_hash) WHERE contact_verified_at IS NOT NULL AND contact_lookup_hash IS NOT NULL;
CREATE INDEX ix_availability_configuration_0 ON availability_configuration (created_by);
CREATE INDEX ix_booking_policy_0 ON booking_policy (created_by);
CREATE INDEX ix_booking_policy_version_0 ON booking_policy_version (created_by);
CREATE INDEX ix_policy_refund_window_0 ON policy_refund_window (created_by);
CREATE INDEX ix_booking_policy_assignment_0 ON booking_policy_assignment (created_by);
CREATE INDEX ix_booking_policy_assignment_1 ON booking_policy_assignment (business_id, policy_version_id);
CREATE INDEX ix_booking_policy_assignment_2 ON booking_policy_assignment (business_id, branch_id);
CREATE INDEX ix_booking_policy_assignment_3 ON booking_policy_assignment (business_id, service_id);
CREATE INDEX ix_booking_policy_assignment_4 ON booking_policy_assignment (business_id, package_id);
CREATE INDEX ix_booking_policy_assignment_5 ON booking_policy_assignment (business_id, booking_id);
CREATE INDEX ix_booking_policy_assignment_6 ON booking_policy_assignment (authorized_by);
CREATE INDEX ix_pricing_quote_0 ON pricing_quote (created_by);
CREATE INDEX ix_pricing_quote_1 ON pricing_quote (business_id, branch_id);
CREATE INDEX ix_pricing_quote_2 ON pricing_quote (business_id, customer_id);
CREATE INDEX ix_pricing_quote_3 ON pricing_quote (business_id, customer_id, created_at DESC);
CREATE INDEX ix_pricing_quote_item_0 ON pricing_quote_item (created_by);
CREATE INDEX ix_pricing_quote_item_1 ON pricing_quote_item (business_id, quote_id, branch_id);
CREATE INDEX ix_pricing_quote_item_2 ON pricing_quote_item (business_id, offering_id, branch_id, service_id);
CREATE INDEX ix_pricing_quote_item_3 ON pricing_quote_item (business_id, package_id);
CREATE INDEX ix_quote_policy_resolution_0 ON quote_policy_resolution (created_by);
CREATE INDEX ix_quote_policy_resolution_1 ON quote_policy_resolution (business_id, policy_version_id);
CREATE INDEX ix_quote_policy_source_0 ON quote_policy_source (created_by);
CREATE INDEX ix_quote_policy_source_1 ON quote_policy_source (business_id, policy_version_id);
CREATE INDEX ix_quote_policy_source_2 ON quote_policy_source (business_id, resolution_id, policy_version_id);
CREATE INDEX ix_quote_policy_source_3 ON quote_policy_source (business_id, assignment_id, policy_version_id);
CREATE INDEX ix_booking_0 ON booking (created_by);
CREATE INDEX ix_booking_1 ON booking (business_id, branch_id);
CREATE INDEX ix_booking_2 ON booking (business_id, customer_id);
CREATE INDEX ix_booking_3 ON booking (business_id, active_revision_id, id);
CREATE INDEX ix_booking_4 ON booking (business_id, branch_id, status, created_at DESC);
CREATE INDEX ix_booking_5 ON booking (business_id, customer_id, created_at DESC);
CREATE INDEX ix_booking_revision_0 ON booking_revision (created_by);
CREATE INDEX ix_booking_revision_1 ON booking_revision (business_id, booking_id, branch_id);
CREATE INDEX ix_booking_revision_2 ON booking_revision (business_id, quote_id, branch_id);
CREATE INDEX ix_booking_revision_3 ON booking_revision (business_id, supersedes_revision_id, booking_id);
CREATE UNIQUE INDEX ix_booking_revision_4 ON booking_revision (business_id, booking_id) WHERE state = 'ACTIVE';
CREATE INDEX ix_booking_item_0 ON booking_item (created_by);
CREATE INDEX ix_booking_item_1 ON booking_item (business_id, revision_id, quote_id);
CREATE INDEX ix_booking_item_2 ON booking_item (business_id, quote_item_id, quote_id);
CREATE INDEX ix_booking_service_segment_0 ON booking_service_segment (created_by);
CREATE INDEX ix_booking_service_segment_1 ON booking_service_segment (business_id, item_id, revision_id);
CREATE INDEX ix_segment_dependency_0 ON segment_dependency (created_by);
CREATE INDEX ix_segment_dependency_1 ON segment_dependency (business_id, segment_id, revision_id);
CREATE INDEX ix_segment_dependency_2 ON segment_dependency (business_id, predecessor_id, revision_id);
CREATE INDEX ix_booking_hold_0 ON booking_hold (created_by);
CREATE INDEX ix_booking_hold_1 ON booking_hold (business_id, revision_id, booking_id);
CREATE UNIQUE INDEX ix_booking_hold_2 ON booking_hold (business_id, booking_id) WHERE status = 'ACTIVE';
CREATE INDEX ix_booking_hold_3 ON booking_hold (expires_at) WHERE status = 'ACTIVE';
CREATE INDEX ix_resource_allocation_0 ON resource_allocation (created_by);
CREATE INDEX ix_resource_allocation_1 ON resource_allocation (business_id, branch_id);
CREATE INDEX ix_resource_allocation_2 ON resource_allocation (business_id, revision_id, branch_id);
CREATE INDEX ix_resource_allocation_3 ON resource_allocation (business_id, hold_id, revision_id);
CREATE INDEX ix_resource_allocation_4 ON resource_allocation (business_id, time_off_id, resource_id);
CREATE INDEX ix_resource_allocation_5 ON resource_allocation (business_id, resource_id, resource_kind);
CREATE INDEX ix_resource_allocation_6 ON resource_allocation (business_id, resource_id, resource_branch_id);
CREATE INDEX ix_resource_allocation_7 ON resource_allocation (business_id, closure_id, branch_id);
CREATE INDEX ix_resource_allocation_8 ON resource_allocation (business_id, revision_id) WHERE released_at IS NULL;
CREATE INDEX ix_resource_allocation_9 ON resource_allocation (business_id, resource_id, busy_starts_at) WHERE released_at IS NULL;
CREATE INDEX ix_booking_status_history_0 ON booking_status_history (created_by);
CREATE INDEX ix_booking_status_history_1 ON booking_status_history (business_id, booking_id);
CREATE INDEX ix_booking_status_history_2 ON booking_status_history (business_id, booking_id, created_at, id);
CREATE INDEX ix_booking_policy_acceptance_0 ON booking_policy_acceptance (created_by);
CREATE INDEX ix_booking_policy_acceptance_1 ON booking_policy_acceptance (business_id, revision_id, booking_id);
CREATE INDEX ix_booking_policy_acceptance_2 ON booking_policy_acceptance (business_id, revision_id, quote_id);
CREATE INDEX ix_booking_policy_acceptance_3 ON booking_policy_acceptance (business_id, resolution_id, quote_id);
CREATE INDEX ix_booking_policy_acceptance_4 ON booking_policy_acceptance (actor_user_id);
CREATE INDEX ix_payment_intent_0 ON payment_intent (created_by);
CREATE INDEX ix_payment_intent_1 ON payment_intent (business_id, revision_id);
CREATE INDEX ix_payment_intent_2 ON payment_intent (business_id, hold_id, revision_id);
CREATE INDEX ix_gateway_event_0 ON gateway_event (created_by);
CREATE INDEX ix_payment_transaction_0 ON payment_transaction (created_by);
CREATE INDEX ix_payment_transaction_1 ON payment_transaction (business_id, intent_id, revision_id);
CREATE INDEX ix_payment_transaction_2 ON payment_transaction (business_id, gateway_event_id);
CREATE INDEX ix_payment_application_0 ON payment_application (created_by);
CREATE INDEX ix_payment_application_1 ON payment_application (business_id, transaction_id, revision_id);
CREATE INDEX ix_payment_balance_0 ON payment_balance (created_by);
CREATE INDEX ix_refund_0 ON refund (created_by);
CREATE INDEX ix_refund_1 ON refund (business_id, transaction_id);
CREATE INDEX ix_refund_2 ON refund (business_id, policy_acceptance_id);
CREATE INDEX ix_refund_3 ON refund (authorized_by);
CREATE INDEX ix_refund_4 ON refund (business_id, transaction_id, state);
CREATE INDEX ix_financial_audit_record_0 ON financial_audit_record (created_by);
CREATE INDEX ix_financial_audit_record_1 ON financial_audit_record (business_id, transaction_id);
CREATE INDEX ix_financial_audit_record_2 ON financial_audit_record (business_id, refund_id);
CREATE INDEX ix_idempotency_record_0 ON idempotency_record (created_by);
CREATE INDEX ix_idempotency_record_1 ON idempotency_record (expires_at);
CREATE INDEX ix_outbox_event_0 ON outbox_event (created_by);
CREATE INDEX ix_outbox_event_1 ON outbox_event (available_at, id) WHERE published_at IS NULL;
CREATE INDEX ix_consumer_inbox_0 ON consumer_inbox (created_by);
CREATE INDEX ix_media_asset_0 ON media_asset (created_by);
CREATE INDEX ix_media_asset_1 ON media_asset (uploaded_by);
CREATE INDEX ix_media_variant_0 ON media_variant (created_by);
CREATE INDEX ix_media_publication_consent_0 ON media_publication_consent (created_by);
CREATE INDEX ix_media_publication_consent_1 ON media_publication_consent (business_id, asset_id);
CREATE INDEX ix_media_publication_consent_2 ON media_publication_consent (business_id, subject_customer_id);
CREATE INDEX ix_media_publication_consent_3 ON media_publication_consent (business_id, asset_id, scope, revoked_at);
CREATE INDEX ix_portfolio_category_0 ON portfolio_category (created_by);
CREATE INDEX ix_portfolio_item_0 ON portfolio_item (created_by);
CREATE INDEX ix_portfolio_item_1 ON portfolio_item (business_id, branch_id);
CREATE INDEX ix_portfolio_item_2 ON portfolio_item (business_id, staff_id);
CREATE INDEX ix_portfolio_item_3 ON portfolio_item (business_id, status, sort_order, id);
CREATE INDEX ix_portfolio_item_category_0 ON portfolio_item_category (created_by);
CREATE INDEX ix_portfolio_item_category_1 ON portfolio_item_category (business_id, category_id);
CREATE INDEX ix_portfolio_service_relation_0 ON portfolio_service_relation (created_by);
CREATE INDEX ix_portfolio_service_relation_1 ON portfolio_service_relation (business_id, service_id);
CREATE INDEX ix_portfolio_media_0 ON portfolio_media (created_by);
CREATE INDEX ix_portfolio_media_1 ON portfolio_media (business_id, asset_id);
CREATE UNIQUE INDEX ix_portfolio_media_2 ON portfolio_media (business_id, item_id, comparison_group, role) WHERE role IN ('BEFORE','AFTER');
CREATE INDEX ix_portfolio_tag_0 ON portfolio_tag (created_by);
CREATE INDEX ix_portfolio_item_tag_0 ON portfolio_item_tag (created_by);
CREATE INDEX ix_portfolio_item_tag_1 ON portfolio_item_tag (business_id, tag_id);
CREATE INDEX ix_notification_channel_config_0 ON notification_channel_config (created_by);
CREATE INDEX ix_notification_channel_config_1 ON notification_channel_config (business_id, branch_id);
CREATE UNIQUE INDEX ix_notification_channel_config_2 ON notification_channel_config (business_id, branch_id, channel) NULLS NOT DISTINCT;
CREATE INDEX ix_notification_template_0 ON notification_template (created_by);
CREATE INDEX ix_notification_template_1 ON notification_template (business_id, branch_id);
CREATE UNIQUE INDEX ix_notification_template_2 ON notification_template (business_id, branch_id, code, channel, locale, version_number) NULLS NOT DISTINCT;
CREATE INDEX ix_notification_preference_0 ON notification_preference (created_by);
CREATE INDEX ix_notification_link_challenge_0 ON notification_link_challenge (created_by);
CREATE INDEX ix_notification_link_challenge_1 ON notification_link_challenge (business_id, customer_id);
CREATE INDEX ix_channel_identity_0 ON channel_identity (created_by);
CREATE INDEX ix_notification_event_0 ON notification_event (created_by);
CREATE INDEX ix_notification_event_1 ON notification_event (business_id, customer_id);
CREATE INDEX ix_notification_event_2 ON notification_event (business_id, booking_id);
CREATE INDEX ix_notification_event_3 ON notification_event (business_id, booking_revision_id, booking_id);
CREATE INDEX ix_notification_event_4 ON notification_event (business_id, template_id);
CREATE INDEX ix_notification_event_5 ON notification_event (business_id, source_event_id);
CREATE INDEX ix_notification_event_6 ON notification_event (scheduled_at, id) WHERE state = 'SCHEDULED';
CREATE INDEX ix_notification_delivery_attempt_0 ON notification_delivery_attempt (created_by);
CREATE UNIQUE INDEX ix_notification_delivery_attempt_1 ON notification_delivery_attempt (business_id, provider_key, provider_message_ref) WHERE provider_message_ref IS NOT NULL;
CREATE INDEX ix_audit_log_0 ON audit_log (created_by);
CREATE INDEX ix_audit_log_1 ON audit_log (actor_user_id);
CREATE INDEX ix_audit_log_2 ON audit_log (business_id, branch_id);
CREATE INDEX ix_audit_log_3 ON audit_log (business_id, target_type, target_id, created_at DESC);
CREATE INDEX ix_audit_log_4 ON audit_log (business_id, actor_user_id, created_at DESC);
CREATE INDEX ix_offering_resource_requirement_0 ON offering_resource_requirement (created_by);
CREATE INDEX ix_offering_resource_requirement_1 ON offering_resource_requirement (business_id, offering_id, branch_id, service_id);
CREATE INDEX ix_segment_resource_assignment_0 ON segment_resource_assignment (created_by);
CREATE INDEX ix_segment_resource_assignment_1 ON segment_resource_assignment (business_id, segment_id, revision_id);
CREATE INDEX ix_segment_resource_assignment_2 ON segment_resource_assignment (business_id, allocation_id, revision_id, resource_id);

-- Database-final arbiter. Expiration is released transactionally; never use now() in this predicate.
ALTER TABLE resource_allocation ADD COLUMN busy_period tstzrange GENERATED ALWAYS AS (tstzrange(busy_starts_at,busy_ends_at,'[)')) STORED;
ALTER TABLE resource_allocation ADD CONSTRAINT no_live_resource_overlap EXCLUDE USING gist (resource_id WITH =, busy_period WITH &&) WHERE (released_at IS NULL);
ALTER TABLE staff_shift ADD COLUMN working_period tstzrange GENERATED ALWAYS AS (tstzrange(starts_at,ends_at,'[)')) STORED;
ALTER TABLE staff_shift ADD CONSTRAINT no_cross_branch_staff_shift EXCLUDE USING gist (staff_id WITH =, working_period WITH &&) WHERE (published AND archived_at IS NULL);
ALTER TABLE booking_policy_assignment ADD COLUMN scope_key text GENERATED ALWAYS AS (scope_kind || ':' || coalesce(branch_id::text,'*') || ':' || coalesce(service_id::text,'*') || ':' || coalesce(package_id::text,'*') || ':' || coalesce(booking_id::text,'*')) STORED;
ALTER TABLE booking_policy_assignment ADD COLUMN effective_period tstzrange GENERATED ALWAYS AS (tstzrange(effective_from,effective_to,'[)')) STORED;
ALTER TABLE booking_policy_assignment ADD CONSTRAINT no_equal_rank_policy_assignment EXCLUDE USING gist (business_id WITH =, scope_key WITH =, priority WITH =, effective_period WITH &&) WHERE (revoked_at IS NULL AND archived_at IS NULL);
-- This draft does NOT enforce table-spanning schedule, graph, acceptance or financial workflow invariants by magic.
-- See 03_DATABASE_DESIGN.md for mandatory transaction/constraint-trigger gates before production.
