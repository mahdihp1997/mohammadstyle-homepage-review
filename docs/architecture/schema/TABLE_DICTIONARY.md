# Table dictionary (generated from the review model)

All tables use UUID primary keys. Composite business keys intentionally support tenant-safe references. FK deletes are RESTRICT. Immutable content is append-only; noted workflow metadata still changes under audited commands. No retention duration is assumed. See the lifecycle and remaining-enforcement matrix in 03_DATABASE_DESIGN.md.

## business

Owner: **Business**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (slug).

Foreign keys:

- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `currency_code = 'IRR'`
- `length(slug) > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## app_user

Owner: **IAM**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: PK only.

Foreign keys:

- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `status IN ('PENDING','ACTIVE','SUSPENDED','CLOSED')`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## auth_identity

Owner: **IAM**. Rollout: **MVP**. Lifecycle: **purge** (time-limited security/coordination data; purge only after safe recovery horizon).

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

Unique keys: (provider, subject_hash).

Foreign keys:

- (created_by) → app_user(id), RESTRICT; initially immediate.
- (user_id) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `octet_length(subject_hash) = 32`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## auth_session

Owner: **IAM**. Rollout: **MVP**. Lifecycle: **purge** (time-limited security/coordination data; purge only after safe recovery horizon).

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

Unique keys: (token_hash).

Foreign keys:

- (created_by) → app_user(id), RESTRICT; initially immediate.
- (user_id) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `expires_at > created_at`
- `octet_length(token_hash) = 32`
- `isfinite(expires_at)`

Explicit access-path indexes: (user_id, expires_at). Full generated FK/index DDL is authoritative.

## permission

Owner: **IAM**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (permission_key).

Foreign keys:

- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## role

Owner: **IAM**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, role_key).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## role_permission

Owner: **IAM**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, role_id, permission_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, role_id) → role(business_id, id), RESTRICT; initially immediate.
- (permission_id) → permission(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## branch

Owner: **Business**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, code).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `configuration_version > 0`
- `NOT bookable OR active`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## user_role_assignment

Owner: **IAM**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (user_id) → app_user(id), RESTRICT; initially immediate.
- (business_id, role_id) → role(business_id, id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`

Explicit access-path indexes: UNIQUE (business_id, user_id, role_id, branch_id) NULLS NOT DISTINCT WHERE revoked_at IS NULL. Full generated FK/index DDL is authoritative.

## branch_working_hours

Owner: **Scheduling**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, branch_id, iso_weekday, start_minute, valid_from).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `iso_weekday BETWEEN 1 AND 7`
- `start_minute >= 0 AND end_minute <= 1440 AND end_minute > start_minute`
- `valid_to IS NULL OR valid_to > valid_from`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## branch_closure

Owner: **Scheduling**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.
- (approved_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `ends_at > starts_at`
- `isfinite(starts_at)`
- `isfinite(ends_at)`

Explicit access-path indexes: (business_id, branch_id, starts_at, ends_at). Full generated FK/index DDL is authoritative.

## resource

Owner: **Scheduling**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, id, kind); (business_id, id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `kind IN ('STAFF','CHAIR','ROOM','DEVICE')`
- `(kind = 'STAFF' AND branch_id IS NULL) OR (kind <> 'STAFF' AND branch_id IS NOT NULL)`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## service

Owner: **Catalog**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, code).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## branch_service_offering

Owner: **Offerings**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, branch_id, service_id); (business_id, id, branch_id, service_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.
- (business_id, service_id) → service(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `price_rial IS NULL OR (price_rial >= 0 AND price_rial % 10 = 0)`
- `duration_minutes IS NULL OR duration_minutes > 0`
- `buffer_before_minutes IS NULL OR buffer_before_minutes >= 0`
- `buffer_after_minutes IS NULL OR buffer_after_minutes >= 0`
- `configuration_version > 0`
- `NOT active OR (price_rial IS NOT NULL AND duration_minutes IS NOT NULL AND buffer_before_minutes IS NOT NULL AND buffer_after_minutes IS NOT NULL)`
- `NOT active OR resources_confirmed`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## staff

Owner: **Staff**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, resource_id); (business_id, user_id); (business_id, id, resource_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (user_id) → app_user(id), RESTRICT; initially immediate.
- (business_id, resource_id, resource_kind) → resource(business_id, id, kind), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `resource_kind = 'STAFF'`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## staff_branch_assignment

Owner: **Staff**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, staff_id, branch_id); (business_id, id, staff_id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, staff_id) → staff(business_id, id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `valid_to IS NULL OR valid_to > valid_from`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## staff_service_eligibility

Owner: **Staff**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, staff_id, service_id); (business_id, id, staff_id, service_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, staff_id) → staff(business_id, id), RESTRICT; initially immediate.
- (business_id, service_id) → service(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `NOT active OR verified_at IS NOT NULL`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## offering_staff_eligibility

Owner: **Offerings**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, offering_id, staff_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, offering_id, branch_id, service_id) → branch_service_offering(business_id, id, branch_id, service_id), RESTRICT; initially immediate.
- (business_id, assignment_id, staff_id, branch_id) → staff_branch_assignment(business_id, id, staff_id, branch_id), RESTRICT; initially immediate.
- (business_id, qualification_id, staff_id, service_id) → staff_service_eligibility(business_id, id, staff_id, service_id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## staff_schedule_rule

Owner: **Scheduling**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, id, staff_id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, assignment_id, staff_id, branch_id) → staff_branch_assignment(business_id, id, staff_id, branch_id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `iso_weekday BETWEEN 1 AND 7`
- `start_minute >= 0 AND end_minute <= 1440 AND end_minute > start_minute`
- `valid_to IS NULL OR valid_to > valid_from`
- `configuration_version > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## staff_shift

Owner: **Scheduling**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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
| working_period | tstzrange GENERATED STORED | no explicit NOT NULL; computed from constrained inputs | tstzrange(starts_at,ends_at,'[)') |

Generated/exclusion invariants: no_cross_branch_staff_shift: staff_id = and working_period &&, published/unarchived only.

Unique keys: (business_id, id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, assignment_id, staff_id, branch_id) → staff_branch_assignment(business_id, id, staff_id, branch_id), RESTRICT; initially immediate.
- (business_id, schedule_rule_id, staff_id, branch_id) → staff_schedule_rule(business_id, id, staff_id, branch_id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `ends_at > starts_at`
- `schedule_version > 0`
- `isfinite(starts_at)`
- `isfinite(ends_at)`

Explicit access-path indexes: (business_id, branch_id, starts_at). Full generated FK/index DDL is authoritative.

## staff_time_off

Owner: **Scheduling**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, id, resource_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, staff_id, resource_id) → staff(business_id, id, resource_id), RESTRICT; initially immediate.
- (approved_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `ends_at > starts_at`
- `isfinite(starts_at)`
- `isfinite(ends_at)`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## package

Owner: **Catalog**. Rollout: **Later**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, code).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## package_service

Owner: **Catalog**. Rollout: **Later**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, package_id, position).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, package_id) → package(business_id, id), RESTRICT; initially immediate.
- (business_id, service_id) → service(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `position >= 0`
- `quantity > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## customer

Owner: **Customers**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, user_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (user_id) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `octet_length(contact_lookup_hash) = 32`

Explicit access-path indexes: UNIQUE (business_id, contact_lookup_hash) WHERE contact_verified_at IS NOT NULL AND contact_lookup_hash IS NOT NULL. Full generated FK/index DDL is authoritative.

## availability_configuration

Owner: **Availability**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `slot_stride_minutes IS NULL OR slot_stride_minutes > 0`
- `lead_minutes IS NULL OR lead_minutes >= 0`
- `horizon_days IS NULL OR horizon_days > 0`
- `hold_ttl_seconds IS NULL OR hold_ttl_seconds > 0`
- `quote_ttl_seconds IS NULL OR quote_ttl_seconds > 0`
- `configuration_version > 0`
- `NOT enabled OR (slot_stride_minutes IS NOT NULL AND lead_minutes IS NOT NULL AND horizon_days IS NOT NULL AND hold_ttl_seconds IS NOT NULL AND quote_ttl_seconds IS NOT NULL)`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## booking_policy

Owner: **Policies**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, code).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `lifecycle IN ('DRAFT','ACTIVE','SUPERSEDED','RETIRED')`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## booking_policy_version

Owner: **Policies**. Rollout: **MVP**. Lifecycle: **publish-freeze** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, policy_id, version_number).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, policy_id) → booking_policy(business_id, id), RESTRICT; initially immediate.

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

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## policy_refund_window

Owner: **Policies**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| policy_version_id | uuid | no | — |
| threshold_minutes | integer | no | — |
| refund_bps | integer | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique keys: (business_id, id); (business_id, policy_version_id, threshold_minutes).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, policy_version_id) → booking_policy_version(business_id, id), RESTRICT; initially immediate.

Checks:

- `threshold_minutes >= 0`
- `refund_bps BETWEEN 0 AND 10000`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## booking_policy_assignment

Owner: **Policies**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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
| scope_key | text GENERATED STORED | no explicit NOT NULL; computed from constrained inputs | scope_kind || ':' || coalesce(branch_id::text,'*') || ':' || coalesce(service_id::text,'*') || ':' || coalesce(package_id::text,'*') || ':' || coalesce(booking_id::text,'*') |
| effective_period | tstzrange GENERATED STORED | no explicit NOT NULL; computed from constrained inputs | tstzrange(effective_from,effective_to,'[)') |

Generated/exclusion invariants: exact scope key; no_equal_rank_policy_assignment: business_id =, scope_key =, priority =, effective_period &&, active routing only.

Unique keys: (business_id, id); (business_id, id, policy_version_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, policy_version_id) → booking_policy_version(business_id, id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.
- (business_id, service_id) → service(business_id, id), RESTRICT; initially immediate.
- (business_id, package_id) → package(business_id, id), RESTRICT; initially immediate.
- (business_id, booking_id) → booking(business_id, id), RESTRICT; initially immediate.
- (authorized_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `effective_to IS NULL OR effective_to > effective_from`
- `(scope_kind = 'BUSINESS' AND num_nonnulls(branch_id,service_id,package_id,booking_id)=0) OR (scope_kind='BRANCH' AND branch_id IS NOT NULL AND num_nonnulls(service_id,package_id,booking_id)=0) OR (scope_kind='SERVICE' AND service_id IS NOT NULL AND package_id IS NULL AND booking_id IS NULL) OR (scope_kind='PACKAGE' AND package_id IS NOT NULL AND service_id IS NULL AND booking_id IS NULL) OR (scope_kind IN ('BOOKING','ADMIN_OVERRIDE') AND booking_id IS NOT NULL AND num_nonnulls(branch_id,service_id,package_id)=0)`
- `scope_kind <> 'ADMIN_OVERRIDE' OR (override_reason IS NOT NULL AND authorized_by IS NOT NULL)`
- `isfinite(effective_from)`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## pricing_quote

Owner: **Pricing**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, id, branch_id); (business_id, quote_hash).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.
- (business_id, customer_id) → customer(business_id, id), RESTRICT; initially immediate.

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

Explicit access-path indexes: (business_id, customer_id, created_at DESC). Full generated FK/index DDL is authoritative.

## pricing_quote_item

Owner: **Pricing**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, quote_id, position); (business_id, id, quote_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, quote_id, branch_id) → pricing_quote(business_id, id, branch_id), RESTRICT; initially immediate.
- (business_id, offering_id, branch_id, service_id) → branch_service_offering(business_id, id, branch_id, service_id), RESTRICT; initially immediate.
- (business_id, package_id) → package(business_id, id), RESTRICT; initially immediate.

Checks:

- `position >= 0`
- `quantity > 0`
- `offering_version > 0`
- `unit_price_rial >= 0 AND unit_price_rial % 10 = 0`
- `duration_minutes > 0`
- `buffer_before_minutes >= 0 AND buffer_after_minutes >= 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## quote_policy_resolution

Owner: **Policies**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, quote_id); (business_id, id, quote_id); (business_id, id, policy_version_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, quote_id) → pricing_quote(business_id, id), RESTRICT; initially immediate.
- (business_id, policy_version_id) → booking_policy_version(business_id, id), RESTRICT; initially immediate.

Checks:

- `jsonb_typeof(snapshot) = 'object'`
- `octet_length(snapshot_hash) = 32`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## quote_policy_source

Owner: **Policies**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

| Column | PostgreSQL type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | no | gen_random_uuid() |
| business_id | uuid | no | — |
| resolution_id | uuid | no | — |
| assignment_id | uuid | no | — |
| policy_version_id | uuid | no | — |
| created_at | timestamptz | no | CURRENT_TIMESTAMP |
| created_by | uuid | yes | — |

Unique keys: (business_id, id); (business_id, resolution_id, assignment_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, policy_version_id) → booking_policy_version(business_id, id), RESTRICT; initially immediate.
- (business_id, resolution_id, policy_version_id) → quote_policy_resolution(business_id, id, policy_version_id), RESTRICT; initially immediate.
- (business_id, assignment_id, policy_version_id) → booking_policy_assignment(business_id, id, policy_version_id), RESTRICT; initially immediate.

Checks:

- No additional local checks.

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## booking

Owner: **Booking**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.
- (business_id, customer_id) → customer(business_id, id), RESTRICT; initially immediate.
- (business_id, active_revision_id, id) → booking_revision(business_id, id, booking_id), RESTRICT; initially deferred.

Checks:

- `row_version > 0`
- `status IN ('DRAFT','HELD','PENDING_PAYMENT','CONFIRMED','CHECKED_IN','IN_SERVICE','COMPLETED','CANCELLED','NO_SHOW','EXPIRED')`
- `origin IN ('CUSTOMER','STAFF','WALK_IN')`
- `origin <> 'CUSTOMER' OR customer_id IS NOT NULL`
- `status = 'DRAFT' OR active_revision_id IS NOT NULL`

Explicit access-path indexes: (business_id, branch_id, status, created_at DESC); (business_id, customer_id, created_at DESC). Full generated FK/index DDL is authoritative.

## booking_revision

Owner: **Booking**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, booking_id, revision_number); (business_id, id, booking_id); (business_id, id, quote_id); (business_id, id, branch_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, booking_id, branch_id) → booking(business_id, id, branch_id), RESTRICT; initially immediate.
- (business_id, quote_id, branch_id) → pricing_quote(business_id, id, branch_id), RESTRICT; initially immediate.
- (business_id, supersedes_revision_id, booking_id) → booking_revision(business_id, id, booking_id), RESTRICT; initially immediate.

Checks:

- `revision_number > 0`
- `ends_at > starts_at`
- `state IN ('PROPOSED','ACTIVE','SUPERSEDED')`
- `isfinite(starts_at)`
- `isfinite(ends_at)`

Explicit access-path indexes: UNIQUE (business_id, booking_id) WHERE state = 'ACTIVE'. Full generated FK/index DDL is authoritative.

## booking_item

Owner: **Booking**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, revision_id, position); (business_id, id, revision_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, revision_id, quote_id) → booking_revision(business_id, id, quote_id), RESTRICT; initially immediate.
- (business_id, quote_item_id, quote_id) → pricing_quote_item(business_id, id, quote_id), RESTRICT; initially immediate.

Checks:

- `position >= 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## booking_service_segment

Owner: **Booking**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, revision_id, position); (business_id, id, revision_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, item_id, revision_id) → booking_item(business_id, id, revision_id), RESTRICT; initially immediate.

Checks:

- `ends_at > starts_at`
- `position >= 0`
- `buffer_before_minutes >= 0 AND buffer_after_minutes >= 0`
- `isfinite(starts_at)`
- `isfinite(ends_at)`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## segment_dependency

Owner: **Booking**. Rollout: **Later**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, segment_id, predecessor_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, segment_id, revision_id) → booking_service_segment(business_id, id, revision_id), RESTRICT; initially immediate.
- (business_id, predecessor_id, revision_id) → booking_service_segment(business_id, id, revision_id), RESTRICT; initially immediate.

Checks:

- `segment_id <> predecessor_id`
- `minimum_gap_minutes >= 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## booking_hold

Owner: **Booking**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, id, revision_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, revision_id, booking_id) → booking_revision(business_id, id, booking_id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `expires_at > created_at`
- `status IN ('ACTIVE','CONSUMED','EXPIRED','RELEASED')`
- `(status='ACTIVE' AND released_at IS NULL) OR (status<>'ACTIVE' AND released_at IS NOT NULL)`
- `isfinite(expires_at)`

Explicit access-path indexes: UNIQUE (business_id, booking_id) WHERE status = 'ACTIVE'; (expires_at) WHERE status = 'ACTIVE'. Full generated FK/index DDL is authoritative.

## resource_allocation

Owner: **Scheduling**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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
| busy_period | tstzrange GENERATED STORED | no explicit NOT NULL; computed from constrained inputs | tstzrange(busy_starts_at,busy_ends_at,'[)') |

Generated/exclusion invariants: no_live_resource_overlap: resource_id = and busy_period &&, live allocations only.

Unique keys: (business_id, id); (business_id, id, revision_id, resource_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.
- (business_id, revision_id, branch_id) → booking_revision(business_id, id, branch_id), RESTRICT; initially immediate.
- (business_id, hold_id, revision_id) → booking_hold(business_id, id, revision_id), RESTRICT; initially immediate.
- (business_id, time_off_id, resource_id) → staff_time_off(business_id, id, resource_id), RESTRICT; initially immediate.
- (business_id, resource_id, resource_kind) → resource(business_id, id, kind), RESTRICT; initially immediate.
- (business_id, resource_id, resource_branch_id) → resource(business_id, id, branch_id), RESTRICT; initially immediate.
- (business_id, closure_id, branch_id) → branch_closure(business_id, id, branch_id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `busy_ends_at > busy_starts_at`
- `(allocation_kind IN ('HOLD','BOOKING') AND revision_id IS NOT NULL AND branch_id IS NOT NULL AND time_off_id IS NULL AND closure_id IS NULL AND (allocation_kind <> 'HOLD' OR hold_id IS NOT NULL)) OR (allocation_kind='TIME_OFF' AND time_off_id IS NOT NULL AND num_nonnulls(revision_id,hold_id,closure_id)=0) OR (allocation_kind='CLOSURE' AND closure_id IS NOT NULL AND branch_id IS NOT NULL AND num_nonnulls(revision_id,hold_id,time_off_id)=0) OR (allocation_kind='MAINTENANCE' AND num_nonnulls(revision_id,hold_id,time_off_id,closure_id)=0)`
- `(resource_kind='STAFF' AND resource_branch_id IS NULL) OR (resource_kind IN ('CHAIR','ROOM','DEVICE') AND resource_branch_id IS NOT NULL AND branch_id IS NOT NULL AND branch_id=resource_branch_id)`
- `isfinite(busy_starts_at)`
- `isfinite(busy_ends_at)`

Explicit access-path indexes: (business_id, revision_id) WHERE released_at IS NULL; (business_id, resource_id, busy_starts_at) WHERE released_at IS NULL. Full generated FK/index DDL is authoritative.

## booking_status_history

Owner: **Booking**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, booking_id) → booking(business_id, id), RESTRICT; initially immediate.

Checks:

- `actor_kind IN ('CUSTOMER','STAFF','SYSTEM','PAYMENT_WORKFLOW')`
- `(from_status IS NULL AND to_status='DRAFT') OR (from_status IS NOT NULL AND ((from_status='DRAFT' AND to_status='HELD') OR (from_status='DRAFT' AND to_status='CANCELLED') OR (from_status='DRAFT' AND to_status='EXPIRED') OR (from_status='HELD' AND to_status='PENDING_PAYMENT') OR (from_status='HELD' AND to_status='CONFIRMED') OR (from_status='HELD' AND to_status='CANCELLED') OR (from_status='HELD' AND to_status='EXPIRED') OR (from_status='PENDING_PAYMENT' AND to_status='CONFIRMED') OR (from_status='PENDING_PAYMENT' AND to_status='CANCELLED') OR (from_status='PENDING_PAYMENT' AND to_status='EXPIRED') OR (from_status='CONFIRMED' AND to_status='CHECKED_IN') OR (from_status='CONFIRMED' AND to_status='CANCELLED') OR (from_status='CONFIRMED' AND to_status='NO_SHOW') OR (from_status='CHECKED_IN' AND to_status='IN_SERVICE') OR (from_status='CHECKED_IN' AND to_status='CANCELLED') OR (from_status='IN_SERVICE' AND to_status='COMPLETED') OR (from_status='IN_SERVICE' AND to_status='CANCELLED')))`

Explicit access-path indexes: (business_id, booking_id, created_at, id). Full generated FK/index DDL is authoritative.

## booking_policy_acceptance

Owner: **Policies**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, revision_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, revision_id, booking_id) → booking_revision(business_id, id, booking_id), RESTRICT; initially immediate.
- (business_id, revision_id, quote_id) → booking_revision(business_id, id, quote_id), RESTRICT; initially immediate.
- (business_id, resolution_id, quote_id) → quote_policy_resolution(business_id, id, quote_id), RESTRICT; initially immediate.
- (actor_user_id) → app_user(id), RESTRICT; initially immediate.

Checks:

- `method IN ('WEB_EXPLICIT','SIGNED_OFFLINE')`
- `jsonb_typeof(accepted_snapshot) = 'object'`
- `octet_length(consent_text_hash) = 32`
- `octet_length(snapshot_hash) = 32`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## payment_intent

Owner: **Payments**. Rollout: **MVP-if-payments**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, provider_key, provider_idempotency_key); (business_id, id, revision_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, revision_id) → booking_revision(business_id, id), RESTRICT; initially immediate.
- (business_id, hold_id, revision_id) → booking_hold(business_id, id, revision_id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `purpose IN ('DEPOSIT','REMAINDER','ADJUSTMENT')`
- `currency_code='IRR' AND unit_version='IRR_RIAL_V1'`
- `amount_rial > 0 AND amount_rial % 10 = 0`
- `expires_at > created_at`
- `state IN ('CREATED','PENDING','VERIFIED','FAILED','EXPIRED')`
- `isfinite(expires_at)`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## gateway_event

Owner: **Payments**. Rollout: **MVP-if-payments**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, provider_key, merchant_ref, event_key); (provider_key, merchant_ref, event_key).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `verification_state IN ('UNVERIFIED','VALID','INVALID')`
- `octet_length(payload_hash) = 32`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## payment_transaction

Owner: **Payments**. Rollout: **MVP-if-payments**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, provider_key, merchant_ref, provider_transaction_ref); (business_id, id, revision_id); (provider_key, merchant_ref, provider_transaction_ref).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, intent_id, revision_id) → payment_intent(business_id, id, revision_id), RESTRICT; initially immediate.
- (business_id, gateway_event_id) → gateway_event(business_id, id), RESTRICT; initially immediate.

Checks:

- `amount_rial > 0 AND amount_rial % 10 = 0`
- `currency_code='IRR'`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## payment_application

Owner: **Payments**. Rollout: **MVP-if-payments**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, transaction_id); (business_id, revision_id, purpose).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, transaction_id, revision_id) → payment_transaction(business_id, id, revision_id), RESTRICT; initially immediate.

Checks:

- `amount_rial > 0 AND amount_rial % 10 = 0`
- `purpose IN ('DEPOSIT','REMAINDER','ADJUSTMENT')`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## payment_balance

Owner: **Payments**. Rollout: **MVP-if-payments**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, transaction_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, transaction_id) → payment_transaction(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `captured_rial > 0 AND captured_rial % 10 = 0`
- `refund_reserved_rial >= 0 AND refund_reserved_rial % 10 = 0`
- `refunded_rial >= 0 AND refunded_rial % 10 = 0`
- `refunded_rial + refund_reserved_rial <= captured_rial`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## refund

Owner: **Payments**. Rollout: **MVP-if-payments**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, provider_idempotency_key).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, transaction_id) → payment_transaction(business_id, id), RESTRICT; initially immediate.
- (business_id, policy_acceptance_id) → booking_policy_acceptance(business_id, id), RESTRICT; initially immediate.
- (authorized_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `requested_rial > 0 AND requested_rial % 10 = 0`
- `state IN ('REQUESTED','AUTHORIZED','SUBMITTED','SUCCEEDED','FAILED','UNKNOWN','CANCELLED')`

Explicit access-path indexes: (business_id, transaction_id, state). Full generated FK/index DDL is authoritative.

## financial_audit_record

Owner: **Payments**. Rollout: **MVP-if-payments**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, operation_key, entry_kind).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, transaction_id) → payment_transaction(business_id, id), RESTRICT; initially immediate.
- (business_id, refund_id) → refund(business_id, id), RESTRICT; initially immediate.

Checks:

- `entry_kind IN ('CAPTURE_VERIFIED','APPLIED','REFUND_RESERVED','REFUND_SUCCEEDED','REFUND_RELEASED','COMPENSATION_REQUIRED')`
- `amount_rial > 0 AND amount_rial % 10 = 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## idempotency_record

Owner: **Infrastructure**. Rollout: **MVP**. Lifecycle: **purge** (time-limited security/coordination data; purge only after safe recovery horizon).

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

Unique keys: (business_id, id); (business_id, actor_key, route_key, idempotency_key).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `state IN ('PROCESSING','COMPLETE')`
- `expires_at > created_at`
- `state <> 'COMPLETE' OR (response_code IS NOT NULL AND response_snapshot IS NOT NULL)`
- `octet_length(request_hash) = 32`
- `isfinite(expires_at)`

Explicit access-path indexes: (expires_at). Full generated FK/index DDL is authoritative.

## outbox_event

Owner: **Infrastructure**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, aggregate_type, aggregate_id, aggregate_version, event_type).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `aggregate_version > 0 AND schema_version > 0`
- `publish_attempts >= 0`
- `jsonb_typeof(payload) = 'object'`

Explicit access-path indexes: (available_at, id) WHERE published_at IS NULL. Full generated FK/index DDL is authoritative.

## consumer_inbox

Owner: **Infrastructure**. Rollout: **MVP**. Lifecycle: **purge** (time-limited security/coordination data; purge only after safe recovery horizon).

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

Unique keys: (business_id, id); (business_id, event_id, consumer_key).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, event_id) → outbox_event(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `state IN ('PROCESSING','COMPLETE')`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## media_asset

Owner: **Media**. Rollout: **Later-content**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, object_key).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (uploaded_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `byte_size > 0`
- `status IN ('QUARANTINED','PROCESSING','READY','REJECTED','DELETED')`
- `visibility IN ('PRIVATE','PUBLISHED')`
- `visibility <> 'PUBLISHED' OR (status='READY' AND validated_at IS NOT NULL AND recognizable_person IS NOT NULL AND consent_checked_at IS NOT NULL)`
- `octet_length(sha256) = 32`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## media_variant

Owner: **Media**. Rollout: **Later-content**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, asset_id, variant_key); (business_id, object_key).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, asset_id) → media_asset(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `byte_size > 0`
- `width IS NULL OR width > 0`
- `height IS NULL OR height > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## media_publication_consent

Owner: **Media**. Rollout: **Later-content**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, asset_id) → media_asset(business_id, id), RESTRICT; initially immediate.
- (business_id, subject_customer_id) → customer(business_id, id), RESTRICT; initially immediate.

Checks:

- `scope IN ('INTERNAL_REVIEW','WEBSITE','SOCIAL')`
- `valid_until IS NULL OR valid_until > granted_at`
- `revoked_at IS NULL OR revoked_at >= granted_at`
- `octet_length(subject_ref_hash) = 32`

Explicit access-path indexes: (business_id, asset_id, scope, revoked_at). Full generated FK/index DDL is authoritative.

## portfolio_category

Owner: **Media**. Rollout: **Later-content**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, code).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `sort_order >= 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## portfolio_item

Owner: **Media**. Rollout: **Later-content**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.
- (business_id, staff_id) → staff(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `kind IN ('HAIRCUT','GROOM','BEFORE_AFTER','BARBER','INTERIOR','SERVICE')`
- `status IN ('DRAFT','PUBLISHED','UNPUBLISHED')`
- `sort_order >= 0`
- `status <> 'PUBLISHED' OR published_at IS NOT NULL`

Explicit access-path indexes: (business_id, status, sort_order, id). Full generated FK/index DDL is authoritative.

## portfolio_item_category

Owner: **Media**. Rollout: **Later-content**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, item_id, category_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, item_id) → portfolio_item(business_id, id), RESTRICT; initially immediate.
- (business_id, category_id) → portfolio_category(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## portfolio_service_relation

Owner: **Media**. Rollout: **Later-content**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, item_id, service_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, item_id) → portfolio_item(business_id, id), RESTRICT; initially immediate.
- (business_id, service_id) → service(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## portfolio_media

Owner: **Media**. Rollout: **Later-content**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, item_id, sort_order).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, item_id) → portfolio_item(business_id, id), RESTRICT; initially immediate.
- (business_id, asset_id) → media_asset(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `role IN ('COVER','GALLERY','BEFORE','AFTER')`
- `sort_order >= 0`
- `(role IN ('BEFORE','AFTER') AND comparison_group IS NOT NULL) OR (role NOT IN ('BEFORE','AFTER') AND comparison_group IS NULL)`

Explicit access-path indexes: UNIQUE (business_id, item_id, comparison_group, role) WHERE role IN ('BEFORE','AFTER'). Full generated FK/index DDL is authoritative.

## portfolio_tag

Owner: **Media**. Rollout: **Later-content**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, slug).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## portfolio_item_tag

Owner: **Media**. Rollout: **Later-content**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, item_id, tag_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, item_id) → portfolio_item(business_id, id), RESTRICT; initially immediate.
- (business_id, tag_id) → portfolio_tag(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## notification_channel_config

Owner: **Notifications**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `channel IN ('SMS','TELEGRAM','BALE')`
- `settings_revision > 0`

Explicit access-path indexes: UNIQUE (business_id, branch_id, channel) NULLS NOT DISTINCT. Full generated FK/index DDL is authoritative.

## notification_template

Owner: **Notifications**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.

Checks:

- `channel IN ('SMS','TELEGRAM','BALE')`
- `version_number > 0`

Explicit access-path indexes: UNIQUE (business_id, branch_id, code, channel, locale, version_number) NULLS NOT DISTINCT. Full generated FK/index DDL is authoritative.

## notification_preference

Owner: **Notifications**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, customer_id, channel, purpose).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, customer_id) → customer(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `channel IN ('SMS','TELEGRAM','BALE')`
- `purpose IN ('TRANSACTIONAL','MARKETING')`
- `NOT opted_in OR (consented_at IS NOT NULL AND consent_text_version IS NOT NULL AND revoked_at IS NULL)`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## notification_link_challenge

Owner: **Notifications**. Rollout: **Later**. Lifecycle: **purge** (time-limited security/coordination data; purge only after safe recovery horizon).

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

Unique keys: (business_id, id); (business_id, token_hash).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, customer_id) → customer(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `channel IN ('TELEGRAM','BALE')`
- `expires_at > created_at`
- `octet_length(token_hash) = 32`
- `isfinite(expires_at)`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## channel_identity

Owner: **Notifications**. Rollout: **Later**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, customer_id, channel); (business_id, channel, external_id_hash).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, customer_id) → customer(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `channel IN ('TELEGRAM','BALE')`
- `octet_length(external_id_hash) = 32`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## notification_event

Owner: **Notifications**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, dedup_key).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, customer_id) → customer(business_id, id), RESTRICT; initially immediate.
- (business_id, booking_id) → booking(business_id, id), RESTRICT; initially immediate.
- (business_id, booking_revision_id, booking_id) → booking_revision(business_id, id, booking_id), RESTRICT; initially immediate.
- (business_id, template_id) → notification_template(business_id, id), RESTRICT; initially immediate.
- (business_id, source_event_id) → outbox_event(business_id, id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `channel IN ('SMS','TELEGRAM','BALE')`
- `purpose IN ('TRANSACTIONAL','MARKETING')`
- `state IN ('SCHEDULED','SENDING','DELIVERED','FAILED','CANCELLED','UNKNOWN')`
- `jsonb_typeof(template_parameters) = 'object'`
- `isfinite(scheduled_at)`

Explicit access-path indexes: (scheduled_at, id) WHERE state = 'SCHEDULED'. Full generated FK/index DDL is authoritative.

## notification_delivery_attempt

Owner: **Notifications**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, notification_event_id, attempt_number).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, notification_event_id) → notification_event(business_id, id), RESTRICT; initially immediate.

Checks:

- `attempt_number > 0`
- `state IN ('SUBMITTED','DELIVERED','FAILED','UNKNOWN')`

Explicit access-path indexes: UNIQUE (business_id, provider_key, provider_message_ref) WHERE provider_message_ref IS NOT NULL. Full generated FK/index DDL is authoritative.

## audit_log

Owner: **Audit**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (actor_user_id) → app_user(id), RESTRICT; initially immediate.
- (business_id, branch_id) → branch(business_id, id), RESTRICT; initially immediate.

Checks:

- No additional local checks.

Explicit access-path indexes: (business_id, target_type, target_id, created_at DESC); (business_id, actor_user_id, created_at DESC). Full generated FK/index DDL is authoritative.

## offering_resource_requirement

Owner: **Offerings**. Rollout: **MVP**. Lifecycle: **archive** (archive instead of deleting referenced history; privacy redaction is separately authorized).

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

Unique keys: (business_id, id); (business_id, offering_id, resource_kind).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, offering_id, branch_id, service_id) → branch_service_offering(business_id, id, branch_id, service_id), RESTRICT; initially immediate.

Checks:

- `row_version > 0`
- `resource_kind IN ('CHAIR','ROOM','DEVICE')`
- `quantity > 0`

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.

## segment_resource_assignment

Owner: **Booking**. Rollout: **MVP**. Lifecycle: **append** (immutable business/audit content; retain under approved retention schedule).

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

Unique keys: (business_id, id); (business_id, segment_id, resource_id).

Foreign keys:

- (business_id) → business(id), RESTRICT; initially immediate.
- (created_by) → app_user(id), RESTRICT; initially immediate.
- (business_id, segment_id, revision_id) → booking_service_segment(business_id, id, revision_id), RESTRICT; initially immediate.
- (business_id, allocation_id, revision_id, resource_id) → resource_allocation(business_id, id, revision_id, resource_id), RESTRICT; initially immediate.

Checks:

- No additional local checks.

Explicit access-path indexes: PK/unique and generated FK indexes. Full generated FK/index DDL is authoritative.
