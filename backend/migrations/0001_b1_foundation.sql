-- B1A migration0001: approved16-table B1 foundation, no seeds.
-- Manual local migration runner only; never run at API startup.
CREATE SCHEMA ms_b1_design;

SET search_path = ms_b1_design, public;

-- IAM; B1; archive
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

-- Business; B1; archive
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

-- IAM; B1; archive
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

-- IAM; B1; purge
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

-- IAM; B1; purge
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

-- IAM; B1; archive
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

-- Business; B1; archive
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

-- IAM; B1; archive
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
  CONSTRAINT uq_role_permission_0 UNIQUE (business_id, role_id, permission_id),
  CONSTRAINT ck_role_permission_0 CHECK (row_version > 0)
);

-- IAM; B1; archive
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
  CONSTRAINT ck_user_role_assignment_0 CHECK (row_version > 0)
);

-- Catalog; B1; archive
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

-- Offerings; B1; archive
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
  CONSTRAINT uq_branch_service_offering_0 UNIQUE (business_id, branch_id, service_id),
  CONSTRAINT uq_branch_service_offering_1 UNIQUE (business_id, id, branch_id, service_id),
  CONSTRAINT ck_branch_service_offering_0 CHECK (row_version > 0),
  CONSTRAINT ck_branch_service_offering_1 CHECK (price_rial IS NULL OR (price_rial >= 0 AND price_rial % 10 = 0)),
  CONSTRAINT ck_branch_service_offering_2 CHECK (duration_minutes IS NULL OR duration_minutes > 0),
  CONSTRAINT ck_branch_service_offering_3 CHECK (buffer_before_minutes IS NULL OR buffer_before_minutes >= 0),
  CONSTRAINT ck_branch_service_offering_4 CHECK (buffer_after_minutes IS NULL OR buffer_after_minutes >= 0),
  CONSTRAINT ck_branch_service_offering_5 CHECK (configuration_version > 0),
  CONSTRAINT ck_branch_service_offering_6 CHECK (NOT active OR (price_rial IS NOT NULL AND duration_minutes IS NOT NULL AND buffer_before_minutes IS NOT NULL AND buffer_after_minutes IS NOT NULL)),
  CONSTRAINT ck_branch_service_offering_7 CHECK (NOT active OR resources_confirmed)
);

-- Offerings; B1; archive
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
  CONSTRAINT uq_offering_resource_requirement_0 UNIQUE (business_id, offering_id, resource_kind),
  CONSTRAINT ck_offering_resource_requirement_0 CHECK (row_version > 0),
  CONSTRAINT ck_offering_resource_requirement_1 CHECK (resource_kind IN ('CHAIR','ROOM','DEVICE')),
  CONSTRAINT ck_offering_resource_requirement_2 CHECK (quantity > 0)
);

-- Audit; B1; append
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
  created_by uuid
);

-- Infrastructure; B1; purge
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
  CONSTRAINT uq_idempotency_record_0 UNIQUE (business_id, actor_key, route_key, idempotency_key),
  CONSTRAINT ck_idempotency_record_0 CHECK (row_version > 0),
  CONSTRAINT ck_idempotency_record_1 CHECK (state IN ('PROCESSING','COMPLETE')),
  CONSTRAINT ck_idempotency_record_2 CHECK (expires_at > created_at),
  CONSTRAINT ck_idempotency_record_3 CHECK (state <> 'COMPLETE' OR (response_code IS NOT NULL AND response_snapshot IS NOT NULL)),
  CONSTRAINT ck_idempotency_record_4 CHECK (octet_length(request_hash) = 32),
  CONSTRAINT ck_idempotency_record_5 CHECK (isfinite(expires_at))
);

-- Infrastructure; B1; append
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

-- Infrastructure; B1; purge
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
  CONSTRAINT uq_consumer_inbox_0 UNIQUE (business_id, event_id, consumer_key),
  CONSTRAINT ck_consumer_inbox_0 CHECK (row_version > 0),
  CONSTRAINT ck_consumer_inbox_1 CHECK (state IN ('PROCESSING','COMPLETE'))
);

ALTER TABLE app_user ADD CONSTRAINT fk_app_user_0 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE business ADD CONSTRAINT fk_business_0 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE permission ADD CONSTRAINT fk_permission_0 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE auth_identity ADD CONSTRAINT fk_auth_identity_0 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE auth_identity ADD CONSTRAINT fk_auth_identity_1 FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_auth_identity_fk_0 ON auth_identity (user_id);

ALTER TABLE auth_session ADD CONSTRAINT fk_auth_session_0 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE auth_session ADD CONSTRAINT fk_auth_session_1 FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_auth_session_fk_0 ON auth_session (user_id);

ALTER TABLE role ADD CONSTRAINT fk_role_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE role ADD CONSTRAINT fk_role_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE branch ADD CONSTRAINT fk_branch_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE branch ADD CONSTRAINT fk_branch_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE role_permission ADD CONSTRAINT fk_role_permission_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE role_permission ADD CONSTRAINT fk_role_permission_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE role_permission ADD CONSTRAINT fk_role_permission_2 FOREIGN KEY (business_id, role_id) REFERENCES role (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE role_permission ADD CONSTRAINT fk_role_permission_3 FOREIGN KEY (permission_id) REFERENCES permission (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_role_permission_fk_0 ON role_permission (permission_id);

ALTER TABLE user_role_assignment ADD CONSTRAINT fk_user_role_assignment_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE user_role_assignment ADD CONSTRAINT fk_user_role_assignment_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE user_role_assignment ADD CONSTRAINT fk_user_role_assignment_2 FOREIGN KEY (user_id) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE user_role_assignment ADD CONSTRAINT fk_user_role_assignment_3 FOREIGN KEY (business_id, role_id) REFERENCES role (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE user_role_assignment ADD CONSTRAINT fk_user_role_assignment_4 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- integrity: Conditional/NULL-safe business uniqueness.
CREATE UNIQUE INDEX ix_user_role_assignment_integrity_0 ON user_role_assignment (business_id, user_id, role_id, branch_id) NULLS NOT DISTINCT WHERE revoked_at IS NULL;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_user_role_assignment_fk_0 ON user_role_assignment (user_id);

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_user_role_assignment_fk_1 ON user_role_assignment (business_id, role_id);

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_user_role_assignment_fk_2 ON user_role_assignment (business_id, branch_id);

ALTER TABLE service ADD CONSTRAINT fk_service_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE service ADD CONSTRAINT fk_service_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE branch_service_offering ADD CONSTRAINT fk_branch_service_offering_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE branch_service_offering ADD CONSTRAINT fk_branch_service_offering_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE branch_service_offering ADD CONSTRAINT fk_branch_service_offering_2 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE branch_service_offering ADD CONSTRAINT fk_branch_service_offering_3 FOREIGN KEY (business_id, service_id) REFERENCES service (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_branch_service_offering_fk_0 ON branch_service_offering (business_id, service_id);

ALTER TABLE offering_resource_requirement ADD CONSTRAINT fk_offering_resource_requirement_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE offering_resource_requirement ADD CONSTRAINT fk_offering_resource_requirement_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE offering_resource_requirement ADD CONSTRAINT fk_offering_resource_requirement_2 FOREIGN KEY (business_id, offering_id, branch_id, service_id) REFERENCES branch_service_offering (business_id, id, branch_id, service_id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE audit_log ADD CONSTRAINT fk_audit_log_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE audit_log ADD CONSTRAINT fk_audit_log_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE audit_log ADD CONSTRAINT fk_audit_log_2 FOREIGN KEY (actor_user_id) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE audit_log ADD CONSTRAINT fk_audit_log_3 FOREIGN KEY (business_id, branch_id) REFERENCES branch (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- fk-support: Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
CREATE INDEX ix_audit_log_fk_0 ON audit_log (business_id, branch_id);

ALTER TABLE idempotency_record ADD CONSTRAINT fk_idempotency_record_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE idempotency_record ADD CONSTRAINT fk_idempotency_record_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE outbox_event ADD CONSTRAINT fk_outbox_event_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE outbox_event ADD CONSTRAINT fk_outbox_event_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- operational-recovery: Bounded durable expiry/outbox/reminder scan; baseline recovery choice, not a correctness or measured performance claim.
CREATE INDEX ix_outbox_event_recovery_0 ON outbox_event (available_at, id) WHERE published_at IS NULL;

ALTER TABLE consumer_inbox ADD CONSTRAINT fk_consumer_inbox_0 FOREIGN KEY (business_id) REFERENCES business (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE consumer_inbox ADD CONSTRAINT fk_consumer_inbox_1 FOREIGN KEY (created_by) REFERENCES app_user (id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE consumer_inbox ADD CONSTRAINT fk_consumer_inbox_2 FOREIGN KEY (business_id, event_id) REFERENCES outbox_event (business_id, id) ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

-- Temporary B1 safety gate; removal requires explicit later review.
ALTER TABLE branch ADD CONSTRAINT b1_branch_inactive CHECK (NOT bookable);

-- Temporary B1 safety gate; removal requires explicit later review.
ALTER TABLE branch_service_offering ADD CONSTRAINT b1_branch_service_offering_inactive CHECK (NOT active);

-- Mandatory command/grant/trigger cross-row gates are specified separately; syntax checks do not prove runtime safety.
