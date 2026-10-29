-- B2A dependency-closed approved11-table tranche; no seeds or booking cohort.
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;
SET search_path=ms_b1_design,public;

-- Scheduling; B2; archive
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
  CONSTRAINT uq_branch_working_hours_0 UNIQUE (business_id, branch_id, iso_weekday, start_minute, valid_from),
  CONSTRAINT ck_branch_working_hours_0 CHECK (row_version > 0),
  CONSTRAINT ck_branch_working_hours_1 CHECK (iso_weekday BETWEEN 1 AND 7),
  CONSTRAINT ck_branch_working_hours_2 CHECK (start_minute >= 0 AND end_minute <= 1440 AND end_minute > start_minute),
  CONSTRAINT ck_branch_working_hours_3 CHECK (valid_to IS NULL OR valid_to > valid_from)
);

-- Scheduling; B2; archive
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
  CONSTRAINT uq_branch_closure_0 UNIQUE (business_id, id, branch_id),
  CONSTRAINT ck_branch_closure_0 CHECK (row_version > 0),
  CONSTRAINT ck_branch_closure_1 CHECK (ends_at > starts_at),
  CONSTRAINT ck_branch_closure_2 CHECK (isfinite(starts_at)),
  CONSTRAINT ck_branch_closure_3 CHECK (isfinite(ends_at))
);

-- Scheduling; B2; archive
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
  CONSTRAINT uq_resource_0 UNIQUE (business_id, id, kind),
  CONSTRAINT uq_resource_1 UNIQUE (business_id, id, branch_id),
  CONSTRAINT ck_resource_0 CHECK (row_version > 0),
  CONSTRAINT ck_resource_1 CHECK (kind IN ('STAFF','CHAIR','ROOM','DEVICE')),
  CONSTRAINT ck_resource_2 CHECK ((kind = 'STAFF' AND branch_id IS NULL) OR (kind <> 'STAFF' AND branch_id IS NOT NULL))
);

-- Staff; B2; archive
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

-- Staff; B2; archive
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
  voided_at timestamptz,
  void_reason text,
  CONSTRAINT uq_staff_branch_assignment_0 UNIQUE (business_id, id, staff_id, branch_id),
  CONSTRAINT ck_staff_branch_assignment_0 CHECK (row_version > 0),
  CONSTRAINT ck_staff_branch_assignment_1 CHECK (valid_to IS NULL OR valid_to > valid_from),
  CONSTRAINT ck_staff_branch_assignment_2 CHECK (isfinite(valid_from)),
  CONSTRAINT ck_staff_branch_assignment_3 CHECK (valid_to IS NULL OR isfinite(valid_to)),
  CONSTRAINT ck_staff_branch_assignment_4 CHECK ((voided_at IS NULL AND void_reason IS NULL) OR (voided_at IS NOT NULL AND void_reason IS NOT NULL AND length(btrim(void_reason)) > 0)),
  CONSTRAINT ck_staff_branch_assignment_5 CHECK (NOT active OR voided_at IS NULL)
);

-- Staff; B2; archive
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
  CONSTRAINT uq_staff_service_eligibility_0 UNIQUE (business_id, staff_id, service_id),
  CONSTRAINT uq_staff_service_eligibility_1 UNIQUE (business_id, id, staff_id, service_id),
  CONSTRAINT ck_staff_service_eligibility_0 CHECK (row_version > 0),
  CONSTRAINT ck_staff_service_eligibility_1 CHECK (NOT active OR verified_at IS NOT NULL)
);

-- Offerings; B2; archive
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
  CONSTRAINT uq_offering_staff_eligibility_0 UNIQUE (business_id, offering_id, staff_id, assignment_id),
  CONSTRAINT ck_offering_staff_eligibility_0 CHECK (row_version > 0)
);

-- Scheduling; B2; archive
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
  CONSTRAINT uq_staff_schedule_rule_0 UNIQUE (business_id, id, staff_id, branch_id, assignment_id),
  CONSTRAINT ck_staff_schedule_rule_0 CHECK (row_version > 0),
  CONSTRAINT ck_staff_schedule_rule_1 CHECK (iso_weekday BETWEEN 1 AND 7),
  CONSTRAINT ck_staff_schedule_rule_2 CHECK (start_minute >= 0 AND end_minute <= 1440 AND end_minute > start_minute),
  CONSTRAINT ck_staff_schedule_rule_3 CHECK (valid_to IS NULL OR valid_to > valid_from),
  CONSTRAINT ck_staff_schedule_rule_4 CHECK (configuration_version > 0)
);

-- Scheduling; B2; archive
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
  CONSTRAINT ck_staff_shift_0 CHECK (row_version > 0),
  CONSTRAINT ck_staff_shift_1 CHECK (ends_at > starts_at),
  CONSTRAINT ck_staff_shift_2 CHECK (schedule_version > 0),
  CONSTRAINT ck_staff_shift_3 CHECK (isfinite(starts_at)),
  CONSTRAINT ck_staff_shift_4 CHECK (isfinite(ends_at))
);

-- Scheduling; B2; archive
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
  CONSTRAINT uq_staff_time_off_0 UNIQUE (business_id, id, resource_id),
  CONSTRAINT ck_staff_time_off_0 CHECK (row_version > 0),
  CONSTRAINT ck_staff_time_off_1 CHECK (ends_at > starts_at),
  CONSTRAINT ck_staff_time_off_2 CHECK (isfinite(starts_at)),
  CONSTRAINT ck_staff_time_off_3 CHECK (isfinite(ends_at))
);

-- Availability; B2; archive
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
  CONSTRAINT uq_availability_configuration_0 UNIQUE (business_id, branch_id),
  CONSTRAINT ck_availability_configuration_0 CHECK (row_version > 0),
  CONSTRAINT ck_availability_configuration_1 CHECK (slot_stride_minutes IS NULL OR slot_stride_minutes > 0),
  CONSTRAINT ck_availability_configuration_2 CHECK (lead_minutes IS NULL OR lead_minutes >= 0),
  CONSTRAINT ck_availability_configuration_3 CHECK (horizon_days IS NULL OR horizon_days > 0),
  CONSTRAINT ck_availability_configuration_4 CHECK (hold_ttl_seconds IS NULL OR hold_ttl_seconds > 0),
  CONSTRAINT ck_availability_configuration_5 CHECK (quote_ttl_seconds IS NULL OR quote_ttl_seconds > 0),
  CONSTRAINT ck_availability_configuration_6 CHECK (configuration_version > 0),
  CONSTRAINT ck_availability_configuration_7 CHECK (NOT enabled OR (slot_stride_minutes IS NOT NULL AND lead_minutes IS NOT NULL AND horizon_days IS NOT NULL AND hold_ttl_seconds IS NOT NULL AND quote_ttl_seconds IS NOT NULL))
);

ALTER TABLE branch_working_hours ADD CONSTRAINT fk_branch_working_hours_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE branch_working_hours ADD CONSTRAINT fk_branch_working_hours_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE branch_working_hours ADD CONSTRAINT fk_branch_working_hours_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE branch_closure ADD CONSTRAINT fk_branch_closure_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE branch_closure ADD CONSTRAINT fk_branch_closure_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE branch_closure ADD CONSTRAINT fk_branch_closure_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE branch_closure ADD CONSTRAINT fk_branch_closure_3 FOREIGN KEY (approved_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_branch_closure_fk_0 ON branch_closure (business_id, branch_id);

ALTER TABLE resource ADD CONSTRAINT fk_resource_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE resource ADD CONSTRAINT fk_resource_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE resource ADD CONSTRAINT fk_resource_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_resource_fk_0 ON resource (business_id, branch_id);

ALTER TABLE staff ADD CONSTRAINT fk_staff_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff ADD CONSTRAINT fk_staff_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff ADD CONSTRAINT fk_staff_2 FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff ADD CONSTRAINT fk_staff_3 FOREIGN KEY (business_id, resource_id, resource_kind) REFERENCES resource (business_id, id, kind) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_staff_fk_0 ON staff (user_id);

ALTER TABLE staff_branch_assignment ADD CONSTRAINT fk_staff_branch_assignment_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_branch_assignment ADD CONSTRAINT fk_staff_branch_assignment_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_branch_assignment ADD CONSTRAINT fk_staff_branch_assignment_2 FOREIGN KEY (business_id, staff_id) REFERENCES staff (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_branch_assignment ADD CONSTRAINT fk_staff_branch_assignment_3 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_staff_branch_assignment_fk_0 ON staff_branch_assignment (business_id, staff_id);

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_staff_branch_assignment_fk_1 ON staff_branch_assignment (business_id, branch_id);

ALTER TABLE staff_branch_assignment ADD COLUMN membership_period daterange GENERATED ALWAYS AS (daterange(valid_from,valid_to,'[)')) STORED;

ALTER TABLE staff_service_eligibility ADD CONSTRAINT fk_staff_service_eligibility_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_service_eligibility ADD CONSTRAINT fk_staff_service_eligibility_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_service_eligibility ADD CONSTRAINT fk_staff_service_eligibility_2 FOREIGN KEY (business_id, staff_id) REFERENCES staff (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_service_eligibility ADD CONSTRAINT fk_staff_service_eligibility_3 FOREIGN KEY (business_id, service_id) REFERENCES service (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_staff_service_eligibility_fk_0 ON staff_service_eligibility (business_id, service_id);

ALTER TABLE offering_staff_eligibility ADD CONSTRAINT fk_offering_staff_eligibility_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE offering_staff_eligibility ADD CONSTRAINT fk_offering_staff_eligibility_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE offering_staff_eligibility ADD CONSTRAINT fk_offering_staff_eligibility_2 FOREIGN KEY (business_id, offering_id, branch_id, service_id) REFERENCES branch_service_offering (business_id, id, branch_id, service_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE offering_staff_eligibility ADD CONSTRAINT fk_offering_staff_eligibility_3 FOREIGN KEY (business_id, assignment_id, staff_id, branch_id) REFERENCES staff_branch_assignment (business_id, id, staff_id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE offering_staff_eligibility ADD CONSTRAINT fk_offering_staff_eligibility_4 FOREIGN KEY (business_id, qualification_id, staff_id, service_id) REFERENCES staff_service_eligibility (business_id, id, staff_id, service_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_offering_staff_eligibility_fk_0 ON offering_staff_eligibility (business_id, assignment_id);

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_offering_staff_eligibility_fk_1 ON offering_staff_eligibility (business_id, qualification_id);

ALTER TABLE staff_schedule_rule ADD CONSTRAINT fk_staff_schedule_rule_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_schedule_rule ADD CONSTRAINT fk_staff_schedule_rule_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_schedule_rule ADD CONSTRAINT fk_staff_schedule_rule_2 FOREIGN KEY (business_id, assignment_id, staff_id, branch_id) REFERENCES staff_branch_assignment (business_id, id, staff_id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_staff_schedule_rule_fk_0 ON staff_schedule_rule (business_id, assignment_id);

ALTER TABLE staff_shift ADD CONSTRAINT fk_staff_shift_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_shift ADD CONSTRAINT fk_staff_shift_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_shift ADD CONSTRAINT fk_staff_shift_2 FOREIGN KEY (business_id, assignment_id, staff_id, branch_id) REFERENCES staff_branch_assignment (business_id, id, staff_id, branch_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_shift ADD CONSTRAINT fk_staff_shift_3 FOREIGN KEY (business_id, schedule_rule_id, staff_id, branch_id, assignment_id) REFERENCES staff_schedule_rule (business_id, id, staff_id, branch_id, assignment_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_staff_shift_fk_0 ON staff_shift (business_id, assignment_id);

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_staff_shift_fk_1 ON staff_shift (business_id, schedule_rule_id);

ALTER TABLE staff_shift ADD COLUMN working_period tstzrange GENERATED ALWAYS AS (tstzrange(starts_at,ends_at,'[)')) STORED;

ALTER TABLE staff_time_off ADD CONSTRAINT fk_staff_time_off_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_time_off ADD CONSTRAINT fk_staff_time_off_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_time_off ADD CONSTRAINT fk_staff_time_off_2 FOREIGN KEY (business_id, staff_id, resource_id) REFERENCES staff (business_id, id, resource_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_time_off ADD CONSTRAINT fk_staff_time_off_3 FOREIGN KEY (approved_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_staff_time_off_fk_0 ON staff_time_off (business_id, staff_id);

ALTER TABLE availability_configuration ADD CONSTRAINT fk_availability_configuration_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE availability_configuration ADD CONSTRAINT fk_availability_configuration_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE availability_configuration ADD CONSTRAINT fk_availability_configuration_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE staff_branch_assignment ADD CONSTRAINT no_overlapping_membership_period EXCLUDE USING gist (business_id WITH =, staff_id WITH =, branch_id WITH =, membership_period WITH &&) WHERE (voided_at IS NULL);

ALTER TABLE staff_shift ADD CONSTRAINT no_cross_branch_staff_shift EXCLUDE USING gist (staff_id WITH =, working_period WITH &&) WHERE (published AND archived_at IS NULL);
