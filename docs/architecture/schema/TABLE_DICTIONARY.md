# Table dictionary — hardened review model

All tables have UUID PKs. Composite unique keys are retained where required as exact tenant/context FK targets or business uniqueness; unused identity helpers are removed. All FK deletes RESTRICT. DDL is unexecuted. Index categories and deferred candidates are explicit; child indexes are not required by PostgreSQL for FK correctness. Cross-row workflows/immutability require future tests.

## business

Owner: **Business**. Earliest stage: **B1** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| brand_name | text | no | — |
| legal_name | text | yes | — |
| slug | text | no | — |
| currency_code | text | no | 'IRR' |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (slug).

Foreign keys:

- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `currency_code = 'IRR'`
- `length(slug) > 0`

Indexes:

- **integrity** business_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_business_0: (slug); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## app_user

Owner: **IAM**. Earliest stage: **B1** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| display_name | text | yes | — |
| status | text | no | 'PENDING' |
| pii_redacted_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: PK only.

Foreign keys:

- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `status IN ('PENDING','ACTIVE','SUSPENDED','CLOSED')`

Indexes:

- **integrity** app_user_pkey: (id); Entity identity; PostgreSQL creates its index.

Deferred until EXPLAIN:

- None.

## auth_identity

Owner: **IAM**. Earliest stage: **B1** (MVP). Lifecycle: **purge**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| user_id | uuid | no | — |
| provider | text | no | — |
| subject_hash | bytea | no | — |
| verified_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |

Unique constraints: (provider, subject_hash).

Foreign keys:

- (created_by) → app_user(id), RESTRICT, initially immediate.
- (user_id) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `octet_length(subject_hash) = 32`

Indexes:

- **integrity** auth_identity_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_auth_identity_0: (provider, subject_hash); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_auth_identity_fk_0: (user_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## auth_session

Owner: **IAM**. Earliest stage: **B1** (MVP). Lifecycle: **purge**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| user_id | uuid | no | — |
| token_hash | bytea | no | — |
| expires_at | timestamptz | no | — |
| revoked_at | timestamptz | yes | — |
| last_seen_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |

Unique constraints: (token_hash).

Foreign keys:

- (created_by) → app_user(id), RESTRICT, initially immediate.
- (user_id) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `expires_at > created_at`
- `octet_length(token_hash) = 32`
- `isfinite(expires_at)`

Indexes:

- **integrity** auth_session_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_auth_session_0: (token_hash); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_auth_session_fk_0: (user_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- (user_id, expires_at): Revoke/expire a user session list.

## permission

Owner: **IAM**. Earliest stage: **B1** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| permission_key | text | no | — |
| description | text | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (permission_key).

Foreign keys:

- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`

Indexes:

- **integrity** permission_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_permission_0: (permission_key); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## role

Owner: **IAM**. Earliest stage: **B1** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| role_key | text | no | — |
| display_name | text | no | — |
| system_role | boolean | no | false |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, role_key).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`

Indexes:

- **integrity** role_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_role_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_role_1: (business_id, role_key); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## role_permission

Owner: **IAM**. Earliest stage: **B1** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| role_id | uuid | no | — |
| permission_id | uuid | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, role_id, permission_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, role_id) → role(business_id, id), RESTRICT, initially immediate.
- (permission_id) → permission(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`

Indexes:

- **integrity** role_permission_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_role_permission_0: (business_id, role_id, permission_id); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_role_permission_fk_0: (permission_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## branch

Owner: **Business**. Earliest stage: **B1** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| code | text | no | — |
| display_name | text | no | — |
| address | text | yes | — |
| time_zone | text | no | — |
| active | boolean | no | false |
| bookable | boolean | no | false |
| configuration_version | bigint | no | 1 |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, code).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `configuration_version > 0`
- `NOT bookable OR active`

Indexes:

- **integrity** branch_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_branch_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_branch_1: (business_id, code); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## user_role_assignment

Owner: **IAM**. Earliest stage: **B1** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| user_id | uuid | no | — |
| role_id | uuid | no | — |
| branch_id | uuid | yes | — |
| revoked_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: PK only.

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (user_id) → app_user(id), RESTRICT, initially immediate.
- (business_id, role_id) → role(business_id, id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`

Indexes:

- **integrity** user_role_assignment_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** ix_user_role_assignment_integrity_0: UNIQUE (business_id, user_id, role_id, branch_id) NULLS NOT DISTINCT WHERE revoked_at IS NULL; Conditional/NULL-safe business uniqueness.
- **fk-support** ix_user_role_assignment_fk_0: (user_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_user_role_assignment_fk_1: (business_id, role_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_user_role_assignment_fk_2: (business_id, branch_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## branch_working_hours

Owner: **Scheduling**. Earliest stage: **B2** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| branch_id | uuid | no | — |
| iso_weekday | smallint | no | — |
| start_minute | smallint | no | — |
| end_minute | smallint | no | — |
| valid_from | date | no | — |
| valid_to | date | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, branch_id, iso_weekday, start_minute, valid_from).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `iso_weekday BETWEEN 1 AND 7`
- `start_minute >= 0 AND end_minute <= 1440 AND end_minute > start_minute`
- `valid_to IS NULL OR valid_to > valid_from`

Indexes:

- **integrity** branch_working_hours_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_branch_working_hours_0: (business_id, branch_id, iso_weekday, start_minute, valid_from); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## branch_closure

Owner: **Scheduling**. Earliest stage: **B2** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| branch_id | uuid | no | — |
| starts_at | timestamptz | no | — |
| ends_at | timestamptz | no | — |
| reason_code | text | no | — |
| approved_by | uuid | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.
- (approved_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `ends_at > starts_at`
- `isfinite(starts_at)`
- `isfinite(ends_at)`

Indexes:

- **integrity** branch_closure_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_branch_closure_0: (business_id, id, branch_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_branch_closure_fk_0: (business_id, branch_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- (business_id, branch_id, starts_at, ends_at): Intersect closures for a branch time window.

## resource

Owner: **Scheduling**. Earliest stage: **B2** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| branch_id | uuid | yes | — |
| kind | text | no | — |
| label | text | no | — |
| active | boolean | no | false |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id, kind); (business_id, id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `kind IN ('STAFF','CHAIR','ROOM','DEVICE')`
- `(kind = 'STAFF' AND branch_id IS NULL) OR (kind <> 'STAFF' AND branch_id IS NOT NULL)`

Indexes:

- **integrity** resource_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_resource_0: (business_id, id, kind); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_resource_1: (business_id, id, branch_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_resource_fk_0: (business_id, branch_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## service

Owner: **Catalog**. Earliest stage: **B1** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| code | text | no | — |
| display_name | text | no | — |
| description | text | yes | — |
| active | boolean | no | false |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, code).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`

Indexes:

- **integrity** service_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_service_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_service_1: (business_id, code); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## branch_service_offering

Owner: **Offerings**. Earliest stage: **B1** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| branch_id | uuid | no | — |
| service_id | uuid | no | — |
| active | boolean | no | false |
| price_rial | bigint | yes | — |
| duration_minutes | integer | yes | — |
| buffer_before_minutes | integer | yes | — |
| buffer_after_minutes | integer | yes | — |
| configuration_version | bigint | no | 1 |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |
| resources_confirmed | boolean | no | false |

Unique constraints: (business_id, branch_id, service_id); (business_id, id, branch_id, service_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.
- (business_id, service_id) → service(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `price_rial IS NULL OR (price_rial >= 0 AND price_rial % 10 = 0)`
- `duration_minutes IS NULL OR duration_minutes > 0`
- `buffer_before_minutes IS NULL OR buffer_before_minutes >= 0`
- `buffer_after_minutes IS NULL OR buffer_after_minutes >= 0`
- `configuration_version > 0`
- `NOT active OR (price_rial IS NOT NULL AND duration_minutes IS NOT NULL AND buffer_before_minutes IS NOT NULL AND buffer_after_minutes IS NOT NULL)`
- `NOT active OR resources_confirmed`

Indexes:

- **integrity** branch_service_offering_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_branch_service_offering_0: (business_id, branch_id, service_id); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_branch_service_offering_1: (business_id, id, branch_id, service_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_branch_service_offering_fk_0: (business_id, service_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## staff

Owner: **Staff**. Earliest stage: **B2** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| user_id | uuid | yes | — |
| resource_id | uuid | no | — |
| resource_kind | text | no | 'STAFF' |
| display_name | text | no | — |
| active | boolean | no | false |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, resource_id); (business_id, user_id); (business_id, id, resource_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (user_id) → app_user(id), RESTRICT, initially immediate.
- (business_id, resource_id, resource_kind) → resource(business_id, id, kind), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `resource_kind = 'STAFF'`

Indexes:

- **integrity** staff_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_staff_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_staff_1: (business_id, resource_id); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_staff_2: (business_id, user_id); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_staff_3: (business_id, id, resource_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_staff_fk_0: (user_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## staff_branch_assignment

Owner: **Staff**. Earliest stage: **B2** (MVP). Lifecycle: **archive**. Each row is one membership period; archive/inactive does not erase historical overlap protection. Void requires recorded correction evidence.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| staff_id | uuid | no | — |
| branch_id | uuid | no | — |
| valid_from | date | no | — |
| valid_to | date | yes | — |
| active | boolean | no | false |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |
| voided_at | timestamptz | yes | — |
| void_reason | text | yes | — |
| membership_period | daterange GENERATED STORED | no explicit NOT NULL; constrained inputs | daterange(valid_from,valid_to,'[)') |

Unique constraints: (business_id, id, staff_id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, staff_id) → staff(business_id, id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `valid_to IS NULL OR valid_to > valid_from`
- `isfinite(valid_from)`
- `valid_to IS NULL OR isfinite(valid_to)`
- `(voided_at IS NULL AND void_reason IS NULL) OR (voided_at IS NOT NULL AND void_reason IS NOT NULL AND length(btrim(void_reason)) > 0)`
- `NOT active OR voided_at IS NULL`

Indexes:

- **integrity** staff_branch_assignment_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_staff_branch_assignment_0: (business_id, id, staff_id, branch_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_staff_branch_assignment_fk_0: (business_id, staff_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_staff_branch_assignment_fk_1: (business_id, branch_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **exclusion** no_overlapping_membership_period: business_id WITH =, staff_id WITH =, branch_id WITH =, membership_period WITH &&; Integrity/concurrency arbiter; cannot be deferred for EXPLAIN.

Deferred until EXPLAIN:

- None.

## staff_service_eligibility

Owner: **Staff**. Earliest stage: **B2** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| staff_id | uuid | no | — |
| service_id | uuid | no | — |
| verified_at | timestamptz | yes | — |
| active | boolean | no | false |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, staff_id, service_id); (business_id, id, staff_id, service_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, staff_id) → staff(business_id, id), RESTRICT, initially immediate.
- (business_id, service_id) → service(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `NOT active OR verified_at IS NOT NULL`

Indexes:

- **integrity** staff_service_eligibility_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_staff_service_eligibility_0: (business_id, staff_id, service_id); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_staff_service_eligibility_1: (business_id, id, staff_id, service_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_staff_service_eligibility_fk_0: (business_id, service_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## offering_staff_eligibility

Owner: **Offerings**. Earliest stage: **B2** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| offering_id | uuid | no | — |
| branch_id | uuid | no | — |
| service_id | uuid | no | — |
| staff_id | uuid | no | — |
| assignment_id | uuid | no | — |
| qualification_id | uuid | no | — |
| active | boolean | no | false |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, offering_id, staff_id, assignment_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, offering_id, branch_id, service_id) → branch_service_offering(business_id, id, branch_id, service_id), RESTRICT, initially immediate.
- (business_id, assignment_id, staff_id, branch_id) → staff_branch_assignment(business_id, id, staff_id, branch_id), RESTRICT, initially immediate.
- (business_id, qualification_id, staff_id, service_id) → staff_service_eligibility(business_id, id, staff_id, service_id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`

Indexes:

- **integrity** offering_staff_eligibility_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_offering_staff_eligibility_0: (business_id, offering_id, staff_id, assignment_id); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_offering_staff_eligibility_fk_0: (business_id, assignment_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_offering_staff_eligibility_fk_1: (business_id, qualification_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## staff_schedule_rule

Owner: **Scheduling**. Earliest stage: **B2** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| staff_id | uuid | no | — |
| branch_id | uuid | no | — |
| assignment_id | uuid | no | — |
| iso_weekday | smallint | no | — |
| start_minute | smallint | no | — |
| end_minute | smallint | no | — |
| valid_from | date | no | — |
| valid_to | date | yes | — |
| configuration_version | bigint | no | 1 |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id, staff_id, branch_id, assignment_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, assignment_id, staff_id, branch_id) → staff_branch_assignment(business_id, id, staff_id, branch_id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `iso_weekday BETWEEN 1 AND 7`
- `start_minute >= 0 AND end_minute <= 1440 AND end_minute > start_minute`
- `valid_to IS NULL OR valid_to > valid_from`
- `configuration_version > 0`

Indexes:

- **integrity** staff_schedule_rule_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_staff_schedule_rule_0: (business_id, id, staff_id, branch_id, assignment_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_staff_schedule_rule_fk_0: (business_id, assignment_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## staff_shift

Owner: **Scheduling**. Earliest stage: **B2** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| staff_id | uuid | no | — |
| branch_id | uuid | no | — |
| assignment_id | uuid | no | — |
| schedule_rule_id | uuid | yes | — |
| starts_at | timestamptz | no | — |
| ends_at | timestamptz | no | — |
| published | boolean | no | false |
| schedule_version | bigint | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |
| working_period | tstzrange GENERATED STORED | no explicit NOT NULL; constrained inputs | tstzrange(starts_at,ends_at,'[)') |

Unique constraints: PK only.

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, assignment_id, staff_id, branch_id) → staff_branch_assignment(business_id, id, staff_id, branch_id), RESTRICT, initially immediate.
- (business_id, schedule_rule_id, staff_id, branch_id, assignment_id) → staff_schedule_rule(business_id, id, staff_id, branch_id, assignment_id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `ends_at > starts_at`
- `schedule_version > 0`
- `isfinite(starts_at)`
- `isfinite(ends_at)`

Indexes:

- **integrity** staff_shift_pkey: (id); Entity identity; PostgreSQL creates its index.
- **fk-support** ix_staff_shift_fk_0: (business_id, assignment_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_staff_shift_fk_1: (business_id, schedule_rule_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **exclusion** no_cross_branch_staff_shift: staff_id WITH =, working_period WITH &&; Integrity/concurrency arbiter; cannot be deferred for EXPLAIN.

Deferred until EXPLAIN:

- (business_id, branch_id, starts_at): Read branch calendar horizon.

## staff_time_off

Owner: **Scheduling**. Earliest stage: **B2** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| staff_id | uuid | no | — |
| resource_id | uuid | no | — |
| starts_at | timestamptz | no | — |
| ends_at | timestamptz | no | — |
| reason_code | text | no | — |
| approved_by | uuid | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id, resource_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, staff_id, resource_id) → staff(business_id, id, resource_id), RESTRICT, initially immediate.
- (approved_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `ends_at > starts_at`
- `isfinite(starts_at)`
- `isfinite(ends_at)`

Indexes:

- **integrity** staff_time_off_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_staff_time_off_0: (business_id, id, resource_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_staff_time_off_fk_0: (business_id, staff_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## package

Owner: **Catalog**. Earliest stage: **B3_B4_STRUCTURE_ONLY** (Later). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| code | text | no | — |
| display_name | text | no | — |
| active | boolean | no | false |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, code).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`

Indexes:

- **integrity** package_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_package_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_package_1: (business_id, code); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## package_service

Owner: **Catalog**. Earliest stage: **LATER** (Later). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| package_id | uuid | no | — |
| service_id | uuid | no | — |
| position | integer | no | — |
| quantity | integer | no | 1 |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, package_id, position).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, package_id) → package(business_id, id), RESTRICT, initially immediate.
- (business_id, service_id) → service(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `position >= 0`
- `quantity > 0`

Indexes:

- **integrity** package_service_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_package_service_0: (business_id, package_id, position); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_package_service_fk_0: (business_id, service_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## customer

Owner: **Customers**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| user_id | uuid | yes | — |
| display_name | text | yes | — |
| contact_ciphertext | bytea | yes | — |
| contact_lookup_hash | bytea | yes | — |
| contact_verified_at | timestamptz | yes | — |
| privacy_notice_version | text | yes | — |
| redacted_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, user_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (user_id) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `octet_length(contact_lookup_hash) = 32`

Indexes:

- **integrity** customer_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_customer_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_customer_1: (business_id, user_id); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** ix_customer_integrity_0: UNIQUE (business_id, contact_lookup_hash) WHERE contact_verified_at IS NOT NULL AND contact_lookup_hash IS NOT NULL; Conditional/NULL-safe business uniqueness.
- **fk-support** ix_customer_fk_0: (user_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## availability_configuration

Owner: **Availability**. Earliest stage: **B2** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| branch_id | uuid | no | — |
| enabled | boolean | no | false |
| slot_stride_minutes | integer | yes | — |
| lead_minutes | integer | yes | — |
| horizon_days | integer | yes | — |
| hold_ttl_seconds | integer | yes | — |
| quote_ttl_seconds | integer | yes | — |
| configuration_version | bigint | no | 1 |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `slot_stride_minutes IS NULL OR slot_stride_minutes > 0`
- `lead_minutes IS NULL OR lead_minutes >= 0`
- `horizon_days IS NULL OR horizon_days > 0`
- `hold_ttl_seconds IS NULL OR hold_ttl_seconds > 0`
- `quote_ttl_seconds IS NULL OR quote_ttl_seconds > 0`
- `configuration_version > 0`
- `NOT enabled OR (slot_stride_minutes IS NOT NULL AND lead_minutes IS NOT NULL AND horizon_days IS NOT NULL AND hold_ttl_seconds IS NOT NULL AND quote_ttl_seconds IS NOT NULL)`

Indexes:

- **integrity** availability_configuration_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_availability_configuration_0: (business_id, branch_id); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## booking_policy

Owner: **Policies**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| code | text | no | — |
| name | text | no | — |
| lifecycle | text | no | 'DRAFT' |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, code).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `lifecycle IN ('DRAFT','ACTIVE','SUPERSEDED','RETIRED')`

Indexes:

- **integrity** booking_policy_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_booking_policy_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_booking_policy_1: (business_id, code); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## booking_policy_version

Owner: **Policies**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **publish-freeze**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| policy_id | uuid | no | — |
| version_number | integer | no | — |
| lifecycle | text | no | 'DRAFT' |
| effective_from | timestamptz | no | — |
| effective_to | timestamptz | yes | — |
| deposit_requirement | text | no | — |
| amount_kind | text | yes | — |
| fixed_rial | bigint | yes | — |
| basis_points | integer | yes | — |
| minimum_rial | bigint | yes | — |
| maximum_rial | bigint | yes | — |
| refundability | text | no | — |
| refund_base | text | no | — |
| outside_refund_bps | integer | no | — |
| terms_text | text | no | — |
| terms_locale | text | no | — |
| content_hash | bytea | no | — |
| published_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |

Unique constraints: (business_id, id); (business_id, policy_id, version_number).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, policy_id) → booking_policy(business_id, id), RESTRICT, initially immediate.

Checks:

- `lifecycle IN ('DRAFT','ACTIVE','SUPERSEDED','RETIRED')`
- `version_number > 0`
- `effective_to IS NULL OR effective_to > effective_from`
- `deposit_requirement IN ('NONE','OPTIONAL','REQUIRED')`
- `(deposit_requirement = 'NONE' AND amount_kind IS NULL AND fixed_rial IS NULL AND basis_points IS NULL AND minimum_rial IS NULL AND maximum_rial IS NULL) OR (deposit_requirement <> 'NONE' AND ((amount_kind = 'FIXED' AND fixed_rial > 0 AND fixed_rial % 10 = 0 AND basis_points IS NULL) OR (amount_kind = 'PERCENTAGE' AND basis_points BETWEEN 1 AND 10000 AND fixed_rial IS NULL)))`
- `minimum_rial IS NULL OR (minimum_rial >= 0 AND minimum_rial % 10 = 0)`
- `maximum_rial IS NULL OR (maximum_rial >= 0 AND maximum_rial % 10 = 0)`
- `minimum_rial IS NULL OR maximum_rial IS NULL OR minimum_rial <= maximum_rial`
- `refundability IN ('FULL','NONE','PARTIAL','CONDITIONAL')`
- `refund_base IN ('DEPOSIT_PAID','ALL_PAID')`
- `outside_refund_bps BETWEEN 0 AND 10000`
- `lifecycle = 'DRAFT' OR published_at IS NOT NULL`
- `row_version > 0`
- `deposit_requirement='NONE' OR (amount_kind IS NOT NULL AND ((amount_kind='FIXED' AND fixed_rial IS NOT NULL AND basis_points IS NULL) OR (amount_kind='PERCENTAGE' AND basis_points IS NOT NULL AND fixed_rial IS NULL)))`
- `isfinite(effective_from)`
- `octet_length(content_hash) = 32`

Indexes:

- **integrity** booking_policy_version_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_booking_policy_version_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_booking_policy_version_1: (business_id, policy_id, version_number); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## policy_refund_window

Owner: **Policies**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| policy_version_id | uuid | no | — |
| threshold_minutes | integer | no | — |
| refund_bps | integer | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, policy_version_id, threshold_minutes).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, policy_version_id) → booking_policy_version(business_id, id), RESTRICT, initially immediate.

Checks:

- `threshold_minutes >= 0`
- `refund_bps BETWEEN 0 AND 10000`

Indexes:

- **integrity** policy_refund_window_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_policy_refund_window_0: (business_id, policy_version_id, threshold_minutes); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## booking_policy_assignment

Owner: **Policies**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| policy_version_id | uuid | no | — |
| scope_kind | text | no | — |
| branch_id | uuid | yes | — |
| service_id | uuid | yes | — |
| package_id | uuid | yes | — |
| booking_id | uuid | yes | — |
| priority | integer | no | 0 |
| effective_from | timestamptz | no | — |
| effective_to | timestamptz | yes | — |
| override_reason | text | yes | — |
| authorized_by | uuid | yes | — |
| revoked_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |
| scope_key | text GENERATED STORED | no explicit NOT NULL; constrained inputs | scope_kind || ':' || coalesce(branch_id::text,'*') || ':' || coalesce(service_id::text,'*') || ':' || coalesce(package_id::text,'*') || ':' || coalesce(booking_id::text,'*') |
| effective_period | tstzrange GENERATED STORED | no explicit NOT NULL; constrained inputs | tstzrange(effective_from,effective_to,'[)') |

Unique constraints: (business_id, id, policy_version_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, policy_version_id) → booking_policy_version(business_id, id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.
- (business_id, service_id) → service(business_id, id), RESTRICT, initially immediate.
- (business_id, package_id) → package(business_id, id), RESTRICT, initially immediate.
- (business_id, booking_id) → booking(business_id, id), RESTRICT, initially immediate.
- (authorized_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `effective_to IS NULL OR effective_to > effective_from`
- `(scope_kind = 'BUSINESS' AND num_nonnulls(branch_id,service_id,package_id,booking_id)=0) OR (scope_kind='BRANCH' AND branch_id IS NOT NULL AND num_nonnulls(service_id,package_id,booking_id)=0) OR (scope_kind='SERVICE' AND service_id IS NOT NULL AND package_id IS NULL AND booking_id IS NULL) OR (scope_kind='PACKAGE' AND package_id IS NOT NULL AND service_id IS NULL AND booking_id IS NULL) OR (scope_kind IN ('BOOKING','ADMIN_OVERRIDE') AND booking_id IS NOT NULL AND num_nonnulls(branch_id,service_id,package_id)=0)`
- `scope_kind <> 'ADMIN_OVERRIDE' OR (override_reason IS NOT NULL AND authorized_by IS NOT NULL)`
- `isfinite(effective_from)`

Indexes:

- **integrity** booking_policy_assignment_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_booking_policy_assignment_0: (business_id, id, policy_version_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_booking_policy_assignment_fk_0: (business_id, policy_version_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_booking_policy_assignment_fk_1: (business_id, branch_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_booking_policy_assignment_fk_2: (business_id, service_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_booking_policy_assignment_fk_3: (business_id, package_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_booking_policy_assignment_fk_4: (business_id, booking_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **exclusion** no_equal_rank_policy_assignment: business_id WITH =, scope_key WITH =, priority WITH =, effective_period WITH &&; Integrity/concurrency arbiter; cannot be deferred for EXPLAIN.

Deferred until EXPLAIN:

- None.

## pricing_quote

Owner: **Pricing**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **append**. Content hash is non-unique and excludes identity/expiry; ownership/idempotency remain independent.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| branch_id | uuid | no | — |
| customer_id | uuid | yes | — |
| currency_code | text | no | 'IRR' |
| unit_version | text | no | 'IRR_RIAL_V1' |
| total_rial | bigint | no | — |
| deposit_rial | bigint | no | — |
| remaining_rial | bigint | no | — |
| expires_at | timestamptz | no | — |
| configuration_fingerprint | bytea | no | — |
| quote_hash | bytea | no | — |
| source | text | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| hash_version | text | no | 'MS_QUOTE_CONTENT_V2' |
| content_document | jsonb | no | — |

Unique constraints: (business_id, id); (business_id, id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.
- (business_id, customer_id) → customer(business_id, id), RESTRICT, initially immediate.

Checks:

- `currency_code='IRR' AND unit_version='IRR_RIAL_V1'`
- `total_rial >= 0 AND total_rial % 10 = 0`
- `deposit_rial >= 0 AND deposit_rial % 10 = 0`
- `remaining_rial >= 0 AND remaining_rial % 10 = 0`
- `deposit_rial + remaining_rial = total_rial`
- `expires_at > created_at`
- `source = 'SERVER'`
- `created_by IS NOT NULL`
- `isfinite(expires_at)`
- `octet_length(quote_hash) = 32`
- `hash_version = 'MS_QUOTE_CONTENT_V2'`
- `jsonb_typeof(content_document) = 'object'`
- `content_document->>'schema' IS NOT DISTINCT FROM hash_version`

Indexes:

- **integrity** pricing_quote_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_pricing_quote_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_pricing_quote_1: (business_id, id, branch_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_pricing_quote_fk_0: (business_id, branch_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_pricing_quote_fk_1: (business_id, customer_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- (business_id, customer_id, created_at DESC): Customer quote history (hash is not identity).

## pricing_quote_item

Owner: **Pricing**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| quote_id | uuid | no | — |
| offering_id | uuid | no | — |
| branch_id | uuid | no | — |
| service_id | uuid | no | — |
| package_id | uuid | yes | — |
| position | integer | no | — |
| quantity | integer | no | 1 |
| offering_version | bigint | no | — |
| unit_price_rial | bigint | no | — |
| duration_minutes | integer | no | — |
| buffer_before_minutes | integer | no | — |
| buffer_after_minutes | integer | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, quote_id, position); (business_id, id, quote_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, quote_id, branch_id) → pricing_quote(business_id, id, branch_id), RESTRICT, initially immediate.
- (business_id, offering_id, branch_id, service_id) → branch_service_offering(business_id, id, branch_id, service_id), RESTRICT, initially immediate.
- (business_id, package_id) → package(business_id, id), RESTRICT, initially immediate.

Checks:

- `position >= 0`
- `quantity > 0`
- `offering_version > 0`
- `unit_price_rial >= 0 AND unit_price_rial % 10 = 0`
- `duration_minutes > 0`
- `buffer_before_minutes >= 0 AND buffer_after_minutes >= 0`

Indexes:

- **integrity** pricing_quote_item_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_pricing_quote_item_0: (business_id, quote_id, position); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_pricing_quote_item_1: (business_id, id, quote_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_pricing_quote_item_fk_0: (business_id, offering_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_pricing_quote_item_fk_1: (business_id, package_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## quote_policy_resolution

Owner: **Policies**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| quote_id | uuid | no | — |
| policy_version_id | uuid | no | — |
| snapshot | jsonb | no | — |
| snapshot_hash | bytea | no | — |
| resolver_version | text | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, quote_id); (business_id, id, quote_id); (business_id, id, policy_version_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, quote_id) → pricing_quote(business_id, id), RESTRICT, initially immediate.
- (business_id, policy_version_id) → booking_policy_version(business_id, id), RESTRICT, initially immediate.

Checks:

- `jsonb_typeof(snapshot) = 'object'`
- `octet_length(snapshot_hash) = 32`

Indexes:

- **integrity** quote_policy_resolution_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_quote_policy_resolution_0: (business_id, quote_id); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_quote_policy_resolution_1: (business_id, id, quote_id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_quote_policy_resolution_2: (business_id, id, policy_version_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_quote_policy_resolution_fk_0: (business_id, policy_version_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## quote_policy_source

Owner: **Policies**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| resolution_id | uuid | no | — |
| assignment_id | uuid | no | — |
| policy_version_id | uuid | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, resolution_id, assignment_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, policy_version_id) → booking_policy_version(business_id, id), RESTRICT, initially immediate.
- (business_id, resolution_id, policy_version_id) → quote_policy_resolution(business_id, id, policy_version_id), RESTRICT, initially immediate.
- (business_id, assignment_id, policy_version_id) → booking_policy_assignment(business_id, id, policy_version_id), RESTRICT, initially immediate.

Checks:



Indexes:

- **integrity** quote_policy_source_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_quote_policy_source_0: (business_id, resolution_id, assignment_id); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_quote_policy_source_fk_0: (business_id, policy_version_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_quote_policy_source_fk_1: (business_id, assignment_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## booking

Owner: **Booking**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **archive**. Revisionless drafts and their aborted terminal states use plan_committed=false. Admitted plans retain revision evidence permanently.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| branch_id | uuid | no | — |
| customer_id | uuid | yes | — |
| status | text | no | 'DRAFT' |
| origin | text | no | — |
| active_revision_id | uuid | yes | — |
| cancelled_at | timestamptz | yes | — |
| cancellation_reason_code | text | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |
| plan_committed | boolean | no | false |
| draft_expires_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.
- (business_id, customer_id) → customer(business_id, id), RESTRICT, initially immediate.
- (business_id, active_revision_id, id) → booking_revision(business_id, id, booking_id), RESTRICT, initially deferred.

Checks:

- `row_version > 0`
- `status IN ('DRAFT','HELD','PENDING_PAYMENT','CONFIRMED','CHECKED_IN','IN_SERVICE','COMPLETED','CANCELLED','NO_SHOW','EXPIRED')`
- `origin IN ('CUSTOMER','STAFF','WALK_IN')`
- `origin <> 'CUSTOMER' OR customer_id IS NOT NULL`
- `(NOT plan_committed AND active_revision_id IS NULL AND status IN ('DRAFT','CANCELLED','EXPIRED') AND draft_expires_at IS NOT NULL) OR (plan_committed AND active_revision_id IS NOT NULL AND status <> 'DRAFT' AND draft_expires_at IS NULL)`
- `draft_expires_at IS NULL OR (isfinite(draft_expires_at) AND draft_expires_at > created_at)`

Indexes:

- **integrity** booking_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_booking_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_booking_1: (business_id, id, branch_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_booking_fk_0: (business_id, branch_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_booking_fk_1: (business_id, customer_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_booking_fk_2: (business_id, active_revision_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- (business_id, branch_id, status, created_at DESC): Scoped booking calendar/history.
- (business_id, customer_id, created_at DESC): Scoped booking calendar/history.

## booking_revision

Owner: **Booking**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| booking_id | uuid | no | — |
| branch_id | uuid | no | — |
| revision_number | integer | no | — |
| quote_id | uuid | no | — |
| state | text | no | — |
| starts_at | timestamptz | no | — |
| ends_at | timestamptz | no | — |
| time_zone | text | no | — |
| configuration_fingerprint | bytea | no | — |
| supersedes_revision_id | uuid | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, id); (business_id, booking_id, revision_number); (business_id, id, booking_id); (business_id, id, quote_id); (business_id, id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, booking_id, branch_id) → booking(business_id, id, branch_id), RESTRICT, initially immediate.
- (business_id, quote_id, branch_id) → pricing_quote(business_id, id, branch_id), RESTRICT, initially immediate.
- (business_id, supersedes_revision_id, booking_id) → booking_revision(business_id, id, booking_id), RESTRICT, initially immediate.

Checks:

- `revision_number > 0`
- `ends_at > starts_at`
- `state IN ('PROPOSED','ACTIVE','SUPERSEDED')`
- `isfinite(starts_at)`
- `isfinite(ends_at)`

Indexes:

- **integrity** booking_revision_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_booking_revision_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_booking_revision_1: (business_id, booking_id, revision_number); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_booking_revision_2: (business_id, id, booking_id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_booking_revision_3: (business_id, id, quote_id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_booking_revision_4: (business_id, id, branch_id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** ix_booking_revision_integrity_0: UNIQUE (business_id, booking_id) WHERE state = 'ACTIVE'; Conditional/NULL-safe business uniqueness.
- **fk-support** ix_booking_revision_fk_0: (business_id, quote_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_booking_revision_fk_1: (business_id, supersedes_revision_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## booking_item

Owner: **Booking**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| revision_id | uuid | no | — |
| quote_item_id | uuid | no | — |
| quote_id | uuid | no | — |
| position | integer | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, revision_id, position); (business_id, id, revision_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, revision_id, quote_id) → booking_revision(business_id, id, quote_id), RESTRICT, initially immediate.
- (business_id, quote_item_id, quote_id) → pricing_quote_item(business_id, id, quote_id), RESTRICT, initially immediate.

Checks:

- `position >= 0`

Indexes:

- **integrity** booking_item_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_booking_item_0: (business_id, revision_id, position); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_booking_item_1: (business_id, id, revision_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_booking_item_fk_0: (business_id, quote_item_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## booking_service_segment

Owner: **Booking**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| revision_id | uuid | no | — |
| item_id | uuid | no | — |
| position | integer | no | — |
| starts_at | timestamptz | no | — |
| ends_at | timestamptz | no | — |
| buffer_before_minutes | integer | no | — |
| buffer_after_minutes | integer | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, revision_id, position); (business_id, id, revision_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, item_id, revision_id) → booking_item(business_id, id, revision_id), RESTRICT, initially immediate.

Checks:

- `ends_at > starts_at`
- `position >= 0`
- `buffer_before_minutes >= 0 AND buffer_after_minutes >= 0`
- `isfinite(starts_at)`
- `isfinite(ends_at)`

Indexes:

- **integrity** booking_service_segment_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_booking_service_segment_0: (business_id, revision_id, position); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_booking_service_segment_1: (business_id, id, revision_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_booking_service_segment_fk_0: (business_id, item_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## segment_dependency

Owner: **Booking**. Earliest stage: **LATER** (Later). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| revision_id | uuid | no | — |
| segment_id | uuid | no | — |
| predecessor_id | uuid | no | — |
| minimum_gap_minutes | integer | no | 0 |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, segment_id, predecessor_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, segment_id, revision_id) → booking_service_segment(business_id, id, revision_id), RESTRICT, initially immediate.
- (business_id, predecessor_id, revision_id) → booking_service_segment(business_id, id, revision_id), RESTRICT, initially immediate.

Checks:

- `segment_id <> predecessor_id`
- `minimum_gap_minutes >= 0`

Indexes:

- **integrity** segment_dependency_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_segment_dependency_0: (business_id, segment_id, predecessor_id); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_segment_dependency_fk_0: (business_id, predecessor_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## booking_hold

Owner: **Booking**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| booking_id | uuid | no | — |
| revision_id | uuid | no | — |
| expires_at | timestamptz | no | — |
| status | text | no | 'ACTIVE' |
| released_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id, revision_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, revision_id, booking_id) → booking_revision(business_id, id, booking_id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `expires_at > created_at`
- `status IN ('ACTIVE','CONSUMED','EXPIRED','RELEASED')`
- `(status='ACTIVE' AND released_at IS NULL) OR (status<>'ACTIVE' AND released_at IS NOT NULL)`
- `isfinite(expires_at)`

Indexes:

- **integrity** booking_hold_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_booking_hold_0: (business_id, id, revision_id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** ix_booking_hold_integrity_0: UNIQUE (business_id, booking_id) WHERE status = 'ACTIVE'; Conditional/NULL-safe business uniqueness.
- **operational-recovery** ix_booking_hold_recovery_0: (expires_at) WHERE status = 'ACTIVE'; Bounded durable expiry/outbox/reminder scan; baseline recovery choice, not a correctness or measured performance claim.
- **fk-support** ix_booking_hold_fk_0: (business_id, revision_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## resource_allocation

Owner: **Scheduling**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| resource_id | uuid | no | — |
| branch_id | uuid | yes | — |
| revision_id | uuid | yes | — |
| hold_id | uuid | yes | — |
| time_off_id | uuid | yes | — |
| closure_id | uuid | yes | — |
| allocation_kind | text | no | — |
| busy_starts_at | timestamptz | no | — |
| busy_ends_at | timestamptz | no | — |
| released_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |
| resource_kind | text | no | — |
| resource_branch_id | uuid | yes | — |
| busy_period | tstzrange GENERATED STORED | no explicit NOT NULL; constrained inputs | tstzrange(busy_starts_at,busy_ends_at,'[)') |

Unique constraints: (business_id, id, revision_id, resource_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.
- (business_id, revision_id, branch_id) → booking_revision(business_id, id, branch_id), RESTRICT, initially immediate.
- (business_id, hold_id, revision_id) → booking_hold(business_id, id, revision_id), RESTRICT, initially immediate.
- (business_id, time_off_id, resource_id) → staff_time_off(business_id, id, resource_id), RESTRICT, initially immediate.
- (business_id, resource_id, resource_kind) → resource(business_id, id, kind), RESTRICT, initially immediate.
- (business_id, resource_id, resource_branch_id) → resource(business_id, id, branch_id), RESTRICT, initially immediate.
- (business_id, closure_id, branch_id) → branch_closure(business_id, id, branch_id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `busy_ends_at > busy_starts_at`
- `(allocation_kind IN ('HOLD','BOOKING') AND revision_id IS NOT NULL AND branch_id IS NOT NULL AND time_off_id IS NULL AND closure_id IS NULL AND (allocation_kind <> 'HOLD' OR hold_id IS NOT NULL)) OR (allocation_kind='TIME_OFF' AND time_off_id IS NOT NULL AND num_nonnulls(revision_id,hold_id,closure_id)=0) OR (allocation_kind='CLOSURE' AND closure_id IS NOT NULL AND branch_id IS NOT NULL AND num_nonnulls(revision_id,hold_id,time_off_id)=0) OR (allocation_kind='MAINTENANCE' AND num_nonnulls(revision_id,hold_id,time_off_id,closure_id)=0)`
- `(resource_kind='STAFF' AND resource_branch_id IS NULL) OR (resource_kind IN ('CHAIR','ROOM','DEVICE') AND resource_branch_id IS NOT NULL AND branch_id IS NOT NULL AND branch_id=resource_branch_id)`
- `isfinite(busy_starts_at)`
- `isfinite(busy_ends_at)`

Indexes:

- **integrity** resource_allocation_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_resource_allocation_0: (business_id, id, revision_id, resource_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_resource_allocation_fk_0: (business_id, branch_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_resource_allocation_fk_1: (business_id, revision_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_resource_allocation_fk_2: (business_id, hold_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_resource_allocation_fk_3: (business_id, time_off_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_resource_allocation_fk_4: (business_id, resource_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_resource_allocation_fk_5: (business_id, closure_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **exclusion** no_live_resource_overlap: resource_id WITH =, busy_period WITH &&; Integrity/concurrency arbiter; cannot be deferred for EXPLAIN.

Deferred until EXPLAIN:

- (business_id, revision_id) WHERE released_at IS NULL: Live revision/resource reads; GiST and unfiltered FK support already exist.
- (business_id, resource_id, busy_starts_at) WHERE released_at IS NULL: Live revision/resource reads; GiST and unfiltered FK support already exist.

## booking_status_history

Owner: **Booking**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| booking_id | uuid | no | — |
| from_status | text | yes | — |
| to_status | text | no | — |
| actor_kind | text | no | — |
| reason_code | text | no | — |
| request_id | uuid | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: PK only.

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, booking_id) → booking(business_id, id), RESTRICT, initially immediate.

Checks:

- `actor_kind IN ('CUSTOMER','STAFF','SYSTEM','PAYMENT_WORKFLOW')`
- `(from_status IS NULL AND to_status='DRAFT') OR (from_status IS NOT NULL AND ((from_status='DRAFT' AND to_status='HELD') OR (from_status='DRAFT' AND to_status='CANCELLED') OR (from_status='DRAFT' AND to_status='EXPIRED') OR (from_status='HELD' AND to_status='PENDING_PAYMENT') OR (from_status='HELD' AND to_status='CONFIRMED') OR (from_status='HELD' AND to_status='CANCELLED') OR (from_status='HELD' AND to_status='EXPIRED') OR (from_status='PENDING_PAYMENT' AND to_status='CONFIRMED') OR (from_status='PENDING_PAYMENT' AND to_status='CANCELLED') OR (from_status='PENDING_PAYMENT' AND to_status='EXPIRED') OR (from_status='CONFIRMED' AND to_status='CHECKED_IN') OR (from_status='CONFIRMED' AND to_status='CANCELLED') OR (from_status='CONFIRMED' AND to_status='NO_SHOW') OR (from_status='CHECKED_IN' AND to_status='IN_SERVICE') OR (from_status='CHECKED_IN' AND to_status='CANCELLED') OR (from_status='IN_SERVICE' AND to_status='COMPLETED') OR (from_status='IN_SERVICE' AND to_status='CANCELLED')))`

Indexes:

- **integrity** booking_status_history_pkey: (id); Entity identity; PostgreSQL creates its index.
- **fk-support** ix_booking_status_history_fk_0: (business_id, booking_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- (business_id, booking_id, created_at, id): Booking event timeline.

## booking_policy_acceptance

Owner: **Policies**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| booking_id | uuid | no | — |
| revision_id | uuid | no | — |
| quote_id | uuid | no | — |
| resolution_id | uuid | no | — |
| actor_user_id | uuid | no | — |
| accepted_at | timestamptz | no | — |
| method | text | no | — |
| consent_text_hash | bytea | no | — |
| accepted_snapshot | jsonb | no | — |
| snapshot_hash | bytea | no | — |
| evidence_key | text | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, id); (business_id, revision_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, revision_id, booking_id) → booking_revision(business_id, id, booking_id), RESTRICT, initially immediate.
- (business_id, revision_id, quote_id) → booking_revision(business_id, id, quote_id), RESTRICT, initially immediate.
- (business_id, resolution_id, quote_id) → quote_policy_resolution(business_id, id, quote_id), RESTRICT, initially immediate.
- (actor_user_id) → app_user(id), RESTRICT, initially immediate.

Checks:

- `method IN ('WEB_EXPLICIT','SIGNED_OFFLINE')`
- `jsonb_typeof(accepted_snapshot) = 'object'`
- `octet_length(consent_text_hash) = 32`
- `octet_length(snapshot_hash) = 32`

Indexes:

- **integrity** booking_policy_acceptance_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_booking_policy_acceptance_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_booking_policy_acceptance_1: (business_id, revision_id); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_booking_policy_acceptance_fk_0: (business_id, resolution_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## payment_intent

Owner: **Payments**. Earliest stage: **B6** (MVP-if-payments). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| revision_id | uuid | no | — |
| hold_id | uuid | no | — |
| purpose | text | no | — |
| currency_code | text | no | 'IRR' |
| unit_version | text | no | 'IRR_RIAL_V1' |
| amount_rial | bigint | no | — |
| provider_key | text | no | — |
| provider_idempotency_key | text | no | — |
| state | text | no | 'CREATED' |
| expires_at | timestamptz | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, provider_key, provider_idempotency_key); (business_id, id, revision_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, revision_id) → booking_revision(business_id, id), RESTRICT, initially immediate.
- (business_id, hold_id, revision_id) → booking_hold(business_id, id, revision_id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `purpose IN ('DEPOSIT','REMAINDER','ADJUSTMENT')`
- `currency_code='IRR' AND unit_version='IRR_RIAL_V1'`
- `amount_rial > 0 AND amount_rial % 10 = 0`
- `expires_at > created_at`
- `state IN ('CREATED','PENDING','VERIFIED','FAILED','EXPIRED')`
- `isfinite(expires_at)`

Indexes:

- **integrity** payment_intent_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_payment_intent_0: (business_id, provider_key, provider_idempotency_key); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_payment_intent_1: (business_id, id, revision_id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_payment_intent_fk_0: (business_id, revision_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_payment_intent_fk_1: (business_id, hold_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## gateway_event

Owner: **Payments**. Earliest stage: **B6** (MVP-if-payments). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| provider_key | text | no | — |
| merchant_ref | text | no | — |
| event_key | text | no | — |
| payload_hash | bytea | no | — |
| verification_state | text | no | — |
| received_at | timestamptz | no | — |
| redacted_metadata | jsonb | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, id); (business_id, provider_key, merchant_ref, event_key); (provider_key, merchant_ref, event_key).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `verification_state IN ('UNVERIFIED','VALID','INVALID')`
- `octet_length(payload_hash) = 32`

Indexes:

- **integrity** gateway_event_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_gateway_event_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_gateway_event_1: (business_id, provider_key, merchant_ref, event_key); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_gateway_event_2: (provider_key, merchant_ref, event_key); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## payment_transaction

Owner: **Payments**. Earliest stage: **B6** (MVP-if-payments). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| intent_id | uuid | no | — |
| revision_id | uuid | no | — |
| gateway_event_id | uuid | no | — |
| provider_key | text | no | — |
| merchant_ref | text | no | — |
| provider_transaction_ref | text | no | — |
| amount_rial | bigint | no | — |
| currency_code | text | no | 'IRR' |
| verified_at | timestamptz | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, id); (business_id, provider_key, merchant_ref, provider_transaction_ref); (business_id, id, revision_id); (provider_key, merchant_ref, provider_transaction_ref).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, intent_id, revision_id) → payment_intent(business_id, id, revision_id), RESTRICT, initially immediate.
- (business_id, gateway_event_id) → gateway_event(business_id, id), RESTRICT, initially immediate.

Checks:

- `amount_rial > 0 AND amount_rial % 10 = 0`
- `currency_code='IRR'`

Indexes:

- **integrity** payment_transaction_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_payment_transaction_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_payment_transaction_1: (business_id, provider_key, merchant_ref, provider_transaction_ref); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_payment_transaction_2: (business_id, id, revision_id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_payment_transaction_3: (provider_key, merchant_ref, provider_transaction_ref); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_payment_transaction_fk_0: (business_id, intent_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_payment_transaction_fk_1: (business_id, gateway_event_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## payment_application

Owner: **Payments**. Earliest stage: **B6** (MVP-if-payments). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| transaction_id | uuid | no | — |
| revision_id | uuid | no | — |
| purpose | text | no | — |
| amount_rial | bigint | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, transaction_id); (business_id, revision_id, purpose).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, transaction_id, revision_id) → payment_transaction(business_id, id, revision_id), RESTRICT, initially immediate.

Checks:

- `amount_rial > 0 AND amount_rial % 10 = 0`
- `purpose IN ('DEPOSIT','REMAINDER','ADJUSTMENT')`

Indexes:

- **integrity** payment_application_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_payment_application_0: (business_id, transaction_id); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_payment_application_1: (business_id, revision_id, purpose); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## payment_balance

Owner: **Payments**. Earliest stage: **B6** (MVP-if-payments). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| transaction_id | uuid | no | — |
| captured_rial | bigint | no | — |
| refund_reserved_rial | bigint | no | 0 |
| refunded_rial | bigint | no | 0 |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, transaction_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, transaction_id) → payment_transaction(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `captured_rial > 0 AND captured_rial % 10 = 0`
- `refund_reserved_rial >= 0 AND refund_reserved_rial % 10 = 0`
- `refunded_rial >= 0 AND refunded_rial % 10 = 0`
- `refunded_rial + refund_reserved_rial <= captured_rial`

Indexes:

- **integrity** payment_balance_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_payment_balance_0: (business_id, transaction_id); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## refund

Owner: **Payments**. Earliest stage: **B6** (MVP-if-payments). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| transaction_id | uuid | no | — |
| requested_rial | bigint | no | — |
| state | text | no | 'REQUESTED' |
| reason_code | text | no | — |
| provider_idempotency_key | text | no | — |
| provider_ref | text | yes | — |
| policy_acceptance_id | uuid | yes | — |
| authorized_by | uuid | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, provider_idempotency_key).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, transaction_id) → payment_transaction(business_id, id), RESTRICT, initially immediate.
- (business_id, policy_acceptance_id) → booking_policy_acceptance(business_id, id), RESTRICT, initially immediate.
- (authorized_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `requested_rial > 0 AND requested_rial % 10 = 0`
- `state IN ('REQUESTED','AUTHORIZED','SUBMITTED','SUCCEEDED','FAILED','UNKNOWN','CANCELLED')`

Indexes:

- **integrity** refund_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_refund_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_refund_1: (business_id, provider_idempotency_key); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_refund_fk_0: (business_id, transaction_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_refund_fk_1: (business_id, policy_acceptance_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- (business_id, transaction_id, state): Per-capture refund state history.

## financial_audit_record

Owner: **Payments**. Earliest stage: **B6** (MVP-if-payments). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| transaction_id | uuid | no | — |
| refund_id | uuid | yes | — |
| entry_kind | text | no | — |
| amount_rial | bigint | no | — |
| operation_key | text | no | — |
| reason_code | text | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, operation_key, entry_kind).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, transaction_id) → payment_transaction(business_id, id), RESTRICT, initially immediate.
- (business_id, refund_id) → refund(business_id, id), RESTRICT, initially immediate.

Checks:

- `entry_kind IN ('CAPTURE_VERIFIED','APPLIED','REFUND_RESERVED','REFUND_SUCCEEDED','REFUND_RELEASED','COMPENSATION_REQUIRED')`
- `amount_rial > 0 AND amount_rial % 10 = 0`

Indexes:

- **integrity** financial_audit_record_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_financial_audit_record_0: (business_id, operation_key, entry_kind); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_financial_audit_record_fk_0: (business_id, transaction_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_financial_audit_record_fk_1: (business_id, refund_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## idempotency_record

Owner: **Infrastructure**. Earliest stage: **B1** (MVP). Lifecycle: **purge**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| actor_key | text | no | — |
| route_key | text | no | — |
| idempotency_key | text | no | — |
| request_hash | bytea | no | — |
| state | text | no | — |
| response_code | integer | yes | — |
| response_snapshot | jsonb | yes | — |
| expires_at | timestamptz | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |

Unique constraints: (business_id, actor_key, route_key, idempotency_key).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `state IN ('PROCESSING','COMPLETE')`
- `expires_at > created_at`
- `state <> 'COMPLETE' OR (response_code IS NOT NULL AND response_snapshot IS NOT NULL)`
- `octet_length(request_hash) = 32`
- `isfinite(expires_at)`

Indexes:

- **integrity** idempotency_record_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_idempotency_record_0: (business_id, actor_key, route_key, idempotency_key); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- (expires_at): Purge expired idempotency records only after recovery horizon.

## outbox_event

Owner: **Infrastructure**. Earliest stage: **B1** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| aggregate_type | text | no | — |
| aggregate_id | uuid | no | — |
| aggregate_version | bigint | no | — |
| event_type | text | no | — |
| schema_version | integer | no | — |
| payload | jsonb | no | — |
| available_at | timestamptz | no | — |
| published_at | timestamptz | yes | — |
| publish_attempts | integer | no | 0 |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, id); (business_id, aggregate_type, aggregate_id, aggregate_version, event_type).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `aggregate_version > 0 AND schema_version > 0`
- `publish_attempts >= 0`
- `jsonb_typeof(payload) = 'object'`

Indexes:

- **integrity** outbox_event_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_outbox_event_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_outbox_event_1: (business_id, aggregate_type, aggregate_id, aggregate_version, event_type); Business/idempotency uniqueness, not speculative query acceleration.
- **operational-recovery** ix_outbox_event_recovery_0: (available_at, id) WHERE published_at IS NULL; Bounded durable expiry/outbox/reminder scan; baseline recovery choice, not a correctness or measured performance claim.

Deferred until EXPLAIN:

- None.

## consumer_inbox

Owner: **Infrastructure**. Earliest stage: **B1** (MVP). Lifecycle: **purge**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| event_id | uuid | no | — |
| consumer_key | text | no | — |
| processed_at | timestamptz | yes | — |
| state | text | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |

Unique constraints: (business_id, event_id, consumer_key).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, event_id) → outbox_event(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `state IN ('PROCESSING','COMPLETE')`

Indexes:

- **integrity** consumer_inbox_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_consumer_inbox_0: (business_id, event_id, consumer_key); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## media_asset

Owner: **Media**. Earliest stage: **B8** (Later-content). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| uploaded_by | uuid | no | — |
| object_key | text | no | — |
| mime_type | text | no | — |
| byte_size | bigint | no | — |
| sha256 | bytea | no | — |
| status | text | no | 'QUARANTINED' |
| visibility | text | no | 'PRIVATE' |
| recognizable_person | boolean | yes | — |
| validated_at | timestamptz | yes | — |
| consent_checked_at | timestamptz | yes | — |
| purge_after | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, object_key).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (uploaded_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `byte_size > 0`
- `status IN ('QUARANTINED','PROCESSING','READY','REJECTED','DELETED')`
- `visibility IN ('PRIVATE','PUBLISHED')`
- `visibility <> 'PUBLISHED' OR (status='READY' AND validated_at IS NOT NULL AND recognizable_person IS NOT NULL AND consent_checked_at IS NOT NULL)`
- `octet_length(sha256) = 32`

Indexes:

- **integrity** media_asset_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_media_asset_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_media_asset_1: (business_id, object_key); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## media_variant

Owner: **Media**. Earliest stage: **B8** (Later-content). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| asset_id | uuid | no | — |
| variant_key | text | no | — |
| object_key | text | no | — |
| mime_type | text | no | — |
| byte_size | bigint | no | — |
| width | integer | yes | — |
| height | integer | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, asset_id, variant_key); (business_id, object_key).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, asset_id) → media_asset(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `byte_size > 0`
- `width IS NULL OR width > 0`
- `height IS NULL OR height > 0`

Indexes:

- **integrity** media_variant_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_media_variant_0: (business_id, asset_id, variant_key); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_media_variant_1: (business_id, object_key); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## media_publication_consent

Owner: **Media**. Earliest stage: **B8** (Later-content). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| asset_id | uuid | no | — |
| subject_customer_id | uuid | yes | — |
| subject_ref_hash | bytea | no | — |
| scope | text | no | — |
| evidence_key | text | no | — |
| text_version | text | no | — |
| granted_at | timestamptz | no | — |
| valid_until | timestamptz | yes | — |
| revoked_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: PK only.

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, asset_id) → media_asset(business_id, id), RESTRICT, initially immediate.
- (business_id, subject_customer_id) → customer(business_id, id), RESTRICT, initially immediate.

Checks:

- `scope IN ('INTERNAL_REVIEW','WEBSITE','SOCIAL')`
- `valid_until IS NULL OR valid_until > granted_at`
- `revoked_at IS NULL OR revoked_at >= granted_at`
- `octet_length(subject_ref_hash) = 32`

Indexes:

- **integrity** media_publication_consent_pkey: (id); Entity identity; PostgreSQL creates its index.
- **fk-support** ix_media_publication_consent_fk_0: (business_id, asset_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_media_publication_consent_fk_1: (business_id, subject_customer_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- (business_id, asset_id, scope, revoked_at): Asset scope consent lookup.

## portfolio_category

Owner: **Media**. Earliest stage: **B8** (Later-content). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| code | text | no | — |
| display_name | text | no | — |
| sort_order | integer | no | 0 |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, code).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `sort_order >= 0`

Indexes:

- **integrity** portfolio_category_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_portfolio_category_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_portfolio_category_1: (business_id, code); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## portfolio_item

Owner: **Media**. Earliest stage: **B8** (Later-content). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| branch_id | uuid | yes | — |
| staff_id | uuid | yes | — |
| title | text | no | — |
| description | text | yes | — |
| kind | text | no | — |
| status | text | no | 'DRAFT' |
| sort_order | integer | no | 0 |
| attribution_verified_at | timestamptz | yes | — |
| published_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.
- (business_id, staff_id) → staff(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `kind IN ('HAIRCUT','GROOM','BEFORE_AFTER','BARBER','INTERIOR','SERVICE')`
- `status IN ('DRAFT','PUBLISHED','UNPUBLISHED')`
- `sort_order >= 0`
- `status <> 'PUBLISHED' OR published_at IS NOT NULL`

Indexes:

- **integrity** portfolio_item_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_portfolio_item_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **fk-support** ix_portfolio_item_fk_0: (business_id, branch_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_portfolio_item_fk_1: (business_id, staff_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- (business_id, status, sort_order, id): Published portfolio sorting.

## portfolio_item_category

Owner: **Media**. Earliest stage: **B8** (Later-content). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| item_id | uuid | no | — |
| category_id | uuid | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, item_id, category_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, item_id) → portfolio_item(business_id, id), RESTRICT, initially immediate.
- (business_id, category_id) → portfolio_category(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`

Indexes:

- **integrity** portfolio_item_category_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_portfolio_item_category_0: (business_id, item_id, category_id); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_portfolio_item_category_fk_0: (business_id, category_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## portfolio_service_relation

Owner: **Media**. Earliest stage: **B8** (Later-content). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| item_id | uuid | no | — |
| service_id | uuid | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, item_id, service_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, item_id) → portfolio_item(business_id, id), RESTRICT, initially immediate.
- (business_id, service_id) → service(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`

Indexes:

- **integrity** portfolio_service_relation_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_portfolio_service_relation_0: (business_id, item_id, service_id); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_portfolio_service_relation_fk_0: (business_id, service_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## portfolio_media

Owner: **Media**. Earliest stage: **B8** (Later-content). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| item_id | uuid | no | — |
| asset_id | uuid | no | — |
| role | text | no | — |
| comparison_group | uuid | yes | — |
| sort_order | integer | no | 0 |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, item_id, sort_order).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, item_id) → portfolio_item(business_id, id), RESTRICT, initially immediate.
- (business_id, asset_id) → media_asset(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `role IN ('COVER','GALLERY','BEFORE','AFTER')`
- `sort_order >= 0`
- `(role IN ('BEFORE','AFTER') AND comparison_group IS NOT NULL) OR (role NOT IN ('BEFORE','AFTER') AND comparison_group IS NULL)`

Indexes:

- **integrity** portfolio_media_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_portfolio_media_0: (business_id, item_id, sort_order); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** ix_portfolio_media_integrity_0: UNIQUE (business_id, item_id, comparison_group, role) WHERE role IN ('BEFORE','AFTER'); Conditional/NULL-safe business uniqueness.
- **fk-support** ix_portfolio_media_fk_0: (business_id, asset_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## portfolio_tag

Owner: **Media**. Earliest stage: **B8** (Later-content). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| slug | text | no | — |
| label | text | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, slug).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`

Indexes:

- **integrity** portfolio_tag_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_portfolio_tag_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_portfolio_tag_1: (business_id, slug); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## portfolio_item_tag

Owner: **Media**. Earliest stage: **B8** (Later-content). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| item_id | uuid | no | — |
| tag_id | uuid | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, item_id, tag_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, item_id) → portfolio_item(business_id, id), RESTRICT, initially immediate.
- (business_id, tag_id) → portfolio_tag(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`

Indexes:

- **integrity** portfolio_item_tag_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_portfolio_item_tag_0: (business_id, item_id, tag_id); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_portfolio_item_tag_fk_0: (business_id, tag_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## notification_channel_config

Owner: **Notifications**. Earliest stage: **B7** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| branch_id | uuid | yes | — |
| channel | text | no | — |
| provider_key | text | no | — |
| secret_ref | text | no | — |
| enabled | boolean | no | false |
| settings_revision | bigint | no | 1 |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: PK only.

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `channel IN ('SMS','TELEGRAM','BALE')`
- `settings_revision > 0`

Indexes:

- **integrity** notification_channel_config_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** ix_notification_channel_config_integrity_0: UNIQUE (business_id, branch_id, channel) NULLS NOT DISTINCT; Conditional/NULL-safe business uniqueness.

Deferred until EXPLAIN:

- None.

## notification_template

Owner: **Notifications**. Earliest stage: **B7** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| branch_id | uuid | yes | — |
| code | text | no | — |
| channel | text | no | — |
| version_number | integer | no | — |
| locale | text | no | — |
| body | text | no | — |
| active | boolean | no | false |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.

Checks:

- `channel IN ('SMS','TELEGRAM','BALE')`
- `version_number > 0`

Indexes:

- **integrity** notification_template_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_notification_template_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** ix_notification_template_integrity_0: UNIQUE (business_id, branch_id, code, channel, locale, version_number) NULLS NOT DISTINCT; Conditional/NULL-safe business uniqueness.

Deferred until EXPLAIN:

- None.

## notification_preference

Owner: **Notifications**. Earliest stage: **B7** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| customer_id | uuid | no | — |
| channel | text | no | — |
| purpose | text | no | — |
| opted_in | boolean | no | false |
| consented_at | timestamptz | yes | — |
| consent_text_version | text | yes | — |
| revoked_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, customer_id, channel, purpose).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, customer_id) → customer(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `channel IN ('SMS','TELEGRAM','BALE')`
- `purpose IN ('TRANSACTIONAL','MARKETING')`
- `NOT opted_in OR (consented_at IS NOT NULL AND consent_text_version IS NOT NULL AND revoked_at IS NULL)`

Indexes:

- **integrity** notification_preference_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_notification_preference_0: (business_id, customer_id, channel, purpose); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## notification_link_challenge

Owner: **Notifications**. Earliest stage: **B7** (Later). Lifecycle: **purge**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| customer_id | uuid | no | — |
| channel | text | no | — |
| token_hash | bytea | no | — |
| expires_at | timestamptz | no | — |
| consumed_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |

Unique constraints: (business_id, token_hash).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, customer_id) → customer(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `channel IN ('TELEGRAM','BALE')`
- `expires_at > created_at`
- `octet_length(token_hash) = 32`
- `isfinite(expires_at)`

Indexes:

- **integrity** notification_link_challenge_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_notification_link_challenge_0: (business_id, token_hash); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_notification_link_challenge_fk_0: (business_id, customer_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## channel_identity

Owner: **Notifications**. Earliest stage: **B7** (Later). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| customer_id | uuid | no | — |
| channel | text | no | — |
| external_id_ciphertext | bytea | no | — |
| external_id_hash | bytea | no | — |
| linked_at | timestamptz | no | — |
| revoked_at | timestamptz | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, customer_id, channel); (business_id, channel, external_id_hash).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, customer_id) → customer(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `channel IN ('TELEGRAM','BALE')`
- `octet_length(external_id_hash) = 32`

Indexes:

- **integrity** channel_identity_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_channel_identity_0: (business_id, customer_id, channel); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** uq_channel_identity_1: (business_id, channel, external_id_hash); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## notification_event

Owner: **Notifications**. Earliest stage: **B7** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| customer_id | uuid | no | — |
| booking_id | uuid | yes | — |
| booking_revision_id | uuid | yes | — |
| template_id | uuid | no | — |
| source_event_id | uuid | no | — |
| channel | text | no | — |
| purpose | text | no | — |
| state | text | no | 'SCHEDULED' |
| scheduled_at | timestamptz | no | — |
| dedup_key | text | no | — |
| template_parameters | jsonb | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, id); (business_id, dedup_key).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, customer_id) → customer(business_id, id), RESTRICT, initially immediate.
- (business_id, booking_id) → booking(business_id, id), RESTRICT, initially immediate.
- (business_id, booking_revision_id, booking_id) → booking_revision(business_id, id, booking_id), RESTRICT, initially immediate.
- (business_id, template_id) → notification_template(business_id, id), RESTRICT, initially immediate.
- (business_id, source_event_id) → outbox_event(business_id, id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `channel IN ('SMS','TELEGRAM','BALE')`
- `purpose IN ('TRANSACTIONAL','MARKETING')`
- `state IN ('SCHEDULED','SENDING','DELIVERED','FAILED','CANCELLED','UNKNOWN')`
- `jsonb_typeof(template_parameters) = 'object'`
- `isfinite(scheduled_at)`

Indexes:

- **integrity** notification_event_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_notification_event_0: (business_id, id); Required exact composite FK target; retain despite logical PK implication.
- **integrity** uq_notification_event_1: (business_id, dedup_key); Business/idempotency uniqueness, not speculative query acceleration.
- **operational-recovery** ix_notification_event_recovery_0: (scheduled_at, id) WHERE state = 'SCHEDULED'; Bounded durable expiry/outbox/reminder scan; baseline recovery choice, not a correctness or measured performance claim.
- **fk-support** ix_notification_event_fk_0: (business_id, customer_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_notification_event_fk_1: (business_id, booking_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_notification_event_fk_2: (business_id, booking_revision_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_notification_event_fk_3: (business_id, template_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.
- **fk-support** ix_notification_event_fk_4: (business_id, source_event_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.

## notification_delivery_attempt

Owner: **Notifications**. Earliest stage: **B7** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| notification_event_id | uuid | no | — |
| attempt_number | integer | no | — |
| provider_key | text | no | — |
| provider_message_ref | text | yes | — |
| state | text | no | — |
| retry_after | timestamptz | yes | — |
| failure_code | text | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, notification_event_id, attempt_number).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, notification_event_id) → notification_event(business_id, id), RESTRICT, initially immediate.

Checks:

- `attempt_number > 0`
- `state IN ('SUBMITTED','DELIVERED','FAILED','UNKNOWN')`

Indexes:

- **integrity** notification_delivery_attempt_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_notification_delivery_attempt_0: (business_id, notification_event_id, attempt_number); Business/idempotency uniqueness, not speculative query acceleration.
- **integrity** ix_notification_delivery_attempt_integrity_0: UNIQUE (business_id, provider_key, provider_message_ref) WHERE provider_message_ref IS NOT NULL; Conditional/NULL-safe business uniqueness.

Deferred until EXPLAIN:

- None.

## audit_log

Owner: **Audit**. Earliest stage: **B1** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| actor_user_id | uuid | yes | — |
| branch_id | uuid | yes | — |
| action | text | no | — |
| target_type | text | no | — |
| target_id | uuid | yes | — |
| request_id | uuid | no | — |
| reason_code | text | yes | — |
| redacted_change | jsonb | yes | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: PK only.

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (actor_user_id) → app_user(id), RESTRICT, initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT, initially immediate.

Checks:



Indexes:

- **integrity** audit_log_pkey: (id); Entity identity; PostgreSQL creates its index.
- **fk-support** ix_audit_log_fk_0: (business_id, branch_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- (business_id, target_type, target_id, created_at DESC): Actor/object audit history.
- (business_id, actor_user_id, created_at DESC): Actor/object audit history.

## offering_resource_requirement

Owner: **Offerings**. Earliest stage: **B1** (MVP). Lifecycle: **archive**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| offering_id | uuid | no | — |
| branch_id | uuid | no | — |
| service_id | uuid | no | — |
| resource_kind | text | no | — |
| quantity | integer | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |
| updated_at | timestamptz | no | CURRENT_TIMESTAMP |
| row_version | bigint | no | 1 |
| archived_at | timestamptz | yes | — |

Unique constraints: (business_id, offering_id, resource_kind).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, offering_id, branch_id, service_id) → branch_service_offering(business_id, id, branch_id, service_id), RESTRICT, initially immediate.

Checks:

- `row_version > 0`
- `resource_kind IN ('CHAIR','ROOM','DEVICE')`
- `quantity > 0`

Indexes:

- **integrity** offering_resource_requirement_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_offering_resource_requirement_0: (business_id, offering_id, resource_kind); Business/idempotency uniqueness, not speculative query acceleration.

Deferred until EXPLAIN:

- None.

## segment_resource_assignment

Owner: **Booking**. Earliest stage: **B3_B4_COHORT** (MVP). Lifecycle: **append**. Archive/redact referenced history; append/frozen content follows documented publication and retention gates.

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| revision_id | uuid | no | — |
| segment_id | uuid | no | — |
| resource_id | uuid | no | — |
| allocation_id | uuid | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique constraints: (business_id, segment_id, resource_id).

Foreign keys:

- (business_id) → business(id), RESTRICT, initially immediate.
- (created_by) → app_user(id), RESTRICT, initially immediate.
- (business_id, segment_id, revision_id) → booking_service_segment(business_id, id, revision_id), RESTRICT, initially immediate.
- (business_id, allocation_id, revision_id, resource_id) → resource_allocation(business_id, id, revision_id, resource_id), RESTRICT, initially immediate.

Checks:



Indexes:

- **integrity** segment_resource_assignment_pkey: (id); Entity identity; PostgreSQL creates its index.
- **integrity** uq_segment_resource_assignment_0: (business_id, segment_id, resource_id); Business/idempotency uniqueness, not speculative query acceleration.
- **fk-support** ix_segment_resource_assignment_fk_0: (business_id, allocation_id); Selected baseline child lookup by business+referenced UUID (or global UUID); context suffix remains fully FK-checked. PostgreSQL does not require a child index for FK validity.

Deferred until EXPLAIN:

- None.
