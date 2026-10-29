# Implemented B2B table dictionary

Actual catalog; all28 tables, not the72-table target envelope. Shared source architecture/B2A dictionaries remain preserved.

## app_user

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| display_name | text | YES | — |
| status | text | NO | 'PENDING'::text |
| pii_redacted_at | timestamptz | YES | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |

- app_user_created_at_not_null: NOT NULL created_at
- app_user_id_not_null: NOT NULL id
- app_user_pkey: PRIMARY KEY (id)
- app_user_row_version_not_null: NOT NULL row_version
- app_user_status_not_null: NOT NULL status
- app_user_updated_at_not_null: NOT NULL updated_at
- ck_app_user_0: CHECK ((row_version > 0))
- ck_app_user_1: CHECK ((status = ANY (ARRAY['PENDING'::text, 'ACTIVE'::text, 'SUSPENDED'::text, 'CLOSED'::text])))
- fk_app_user_0: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE

## audit_log

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| actor_user_id | uuid | YES | — |
| branch_id | uuid | YES | — |
| action | text | NO | — |
| target_type | text | NO | — |
| target_id | uuid | YES | — |
| request_id | uuid | NO | — |
| reason_code | text | YES | — |
| redacted_change | jsonb | YES | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |

- audit_log_action_not_null: NOT NULL action
- audit_log_business_id_not_null: NOT NULL business_id
- audit_log_created_at_not_null: NOT NULL created_at
- audit_log_id_not_null: NOT NULL id
- audit_log_pkey: PRIMARY KEY (id)
- audit_log_request_id_not_null: NOT NULL request_id
- audit_log_target_type_not_null: NOT NULL target_type
- fk_audit_log_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_audit_log_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_audit_log_2: FOREIGN KEY (actor_user_id) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_audit_log_3: FOREIGN KEY (business_id, branch_id) REFERENCES ms_b1_design.branch(business_id, id) ON DELETE RESTRICT DEFERRABLE

## auth_identity

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| user_id | uuid | NO | — |
| provider | text | NO | — |
| subject_hash | bytea | NO | — |
| verified_at | timestamptz | YES | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |

- auth_identity_created_at_not_null: NOT NULL created_at
- auth_identity_id_not_null: NOT NULL id
- auth_identity_pkey: PRIMARY KEY (id)
- auth_identity_provider_not_null: NOT NULL provider
- auth_identity_row_version_not_null: NOT NULL row_version
- auth_identity_subject_hash_not_null: NOT NULL subject_hash
- auth_identity_updated_at_not_null: NOT NULL updated_at
- auth_identity_user_id_not_null: NOT NULL user_id
- ck_auth_identity_0: CHECK ((row_version > 0))
- ck_auth_identity_1: CHECK ((octet_length(subject_hash) = 32))
- fk_auth_identity_0: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_auth_identity_1: FOREIGN KEY (user_id) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- uq_auth_identity_0: UNIQUE (provider, subject_hash)

## auth_session

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| user_id | uuid | NO | — |
| token_hash | bytea | NO | — |
| expires_at | timestamptz | NO | — |
| revoked_at | timestamptz | YES | — |
| last_seen_at | timestamptz | YES | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| business_id | uuid | YES | — |
| csrf_hash | bytea | YES | — |
| idle_expires_at | timestamptz | YES | — |

- auth_session_business_id_fkey: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT
- auth_session_created_at_not_null: NOT NULL created_at
- auth_session_expires_at_not_null: NOT NULL expires_at
- auth_session_id_not_null: NOT NULL id
- auth_session_pkey: PRIMARY KEY (id)
- auth_session_row_version_not_null: NOT NULL row_version
- auth_session_token_hash_not_null: NOT NULL token_hash
- auth_session_updated_at_not_null: NOT NULL updated_at
- auth_session_user_id_not_null: NOT NULL user_id
- b1b_csrf_length: CHECK (((csrf_hash IS NULL) OR (octet_length(csrf_hash) = 32)))
- b1b_idle_expiry: CHECK (((idle_expires_at IS NULL) OR (isfinite(idle_expires_at) AND (idle_expires_at > created_at) AND (idle_expires_at <= expires_at))))
- ck_auth_session_0: CHECK ((row_version > 0))
- ck_auth_session_1: CHECK ((expires_at > created_at))
- ck_auth_session_2: CHECK ((octet_length(token_hash) = 32))
- ck_auth_session_3: CHECK (isfinite(expires_at))
- fk_auth_session_0: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_auth_session_1: FOREIGN KEY (user_id) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- uq_auth_session_0: UNIQUE (token_hash)

## availability_configuration

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| branch_id | uuid | NO | — |
| enabled | bool | NO | false |
| slot_stride_minutes | int4 | YES | — |
| lead_minutes | int4 | YES | — |
| horizon_days | int4 | YES | — |
| hold_ttl_seconds | int4 | YES | — |
| quote_ttl_seconds | int4 | YES | — |
| configuration_version | int8 | NO | 1 |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |

- availability_configuration_branch_id_not_null: NOT NULL branch_id
- availability_configuration_business_id_not_null: NOT NULL business_id
- availability_configuration_configuration_version_not_null: NOT NULL configuration_version
- availability_configuration_created_at_not_null: NOT NULL created_at
- availability_configuration_enabled_not_null: NOT NULL enabled
- availability_configuration_id_not_null: NOT NULL id
- availability_configuration_pkey: PRIMARY KEY (id)
- availability_configuration_row_version_not_null: NOT NULL row_version
- availability_configuration_updated_at_not_null: NOT NULL updated_at
- ck_availability_configuration_0: CHECK ((row_version > 0))
- ck_availability_configuration_1: CHECK (((slot_stride_minutes IS NULL) OR (slot_stride_minutes > 0)))
- ck_availability_configuration_2: CHECK (((lead_minutes IS NULL) OR (lead_minutes >= 0)))
- ck_availability_configuration_3: CHECK (((horizon_days IS NULL) OR (horizon_days > 0)))
- ck_availability_configuration_4: CHECK (((hold_ttl_seconds IS NULL) OR (hold_ttl_seconds > 0)))
- ck_availability_configuration_5: CHECK (((quote_ttl_seconds IS NULL) OR (quote_ttl_seconds > 0)))
- ck_availability_configuration_6: CHECK ((configuration_version > 0))
- ck_availability_configuration_7: CHECK (((NOT enabled) OR ((slot_stride_minutes IS NOT NULL) AND (lead_minutes IS NOT NULL) AND (horizon_days IS NOT NULL) AND (hold_ttl_seconds IS NOT NULL) AND (quote_ttl_seconds IS NOT NULL))))
- fk_availability_configuration_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_availability_configuration_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_availability_configuration_2: FOREIGN KEY (business_id, branch_id) REFERENCES ms_b1_design.branch(business_id, id) ON DELETE RESTRICT DEFERRABLE
- uq_availability_configuration_0: UNIQUE (business_id, branch_id)

## branch

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| code | text | NO | — |
| display_name | text | NO | — |
| address | text | YES | — |
| time_zone | text | NO | — |
| active | bool | NO | false |
| bookable | bool | NO | false |
| configuration_version | int8 | NO | 1 |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |
| schedule_version | int8 | NO | 1 |

- b1_branch_inactive: CHECK ((NOT bookable))
- branch_active_not_null: NOT NULL active
- branch_bookable_not_null: NOT NULL bookable
- branch_business_id_not_null: NOT NULL business_id
- branch_code_not_null: NOT NULL code
- branch_configuration_version_not_null: NOT NULL configuration_version
- branch_created_at_not_null: NOT NULL created_at
- branch_display_name_not_null: NOT NULL display_name
- branch_id_not_null: NOT NULL id
- branch_pkey: PRIMARY KEY (id)
- branch_row_version_not_null: NOT NULL row_version
- branch_schedule_version_check: CHECK ((schedule_version > 0))
- branch_schedule_version_not_null: NOT NULL schedule_version
- branch_time_zone_not_null: NOT NULL time_zone
- branch_updated_at_not_null: NOT NULL updated_at
- ck_branch_0: CHECK ((row_version > 0))
- ck_branch_1: CHECK ((configuration_version > 0))
- ck_branch_2: CHECK (((NOT bookable) OR active))
- fk_branch_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_branch_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- uq_branch_0: UNIQUE (business_id, id)
- uq_branch_1: UNIQUE (business_id, code)

## branch_closure

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| branch_id | uuid | NO | — |
| starts_at | timestamptz | NO | — |
| ends_at | timestamptz | NO | — |
| reason_code | text | NO | — |
| approved_by | uuid | YES | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |
| review_status | text | NO | 'LEGACY_UNREVIEWED'::text |
| supersedes_id | uuid | YES | — |

- b2b_closure_parent: FOREIGN KEY (business_id, supersedes_id) REFERENCES ms_b1_design.branch_closure(business_id, id)
- b2b_closure_review: CHECK (((review_status = ANY (ARRAY['LEGACY_UNREVIEWED'::text, 'REQUESTED'::text, 'APPROVED'::text, 'REJECTED'::text])) AND ((review_status <> ALL (ARRAY['APPROVED'::text, 'REJECTED'::text])) OR ((approved_by IS NOT NULL) AND (supersedes_id IS NOT NULL)))))
- b2b_closure_review_identity: UNIQUE (business_id, id)
- b2b_closure_successor: UNIQUE (business_id, supersedes_id)
- branch_closure_branch_id_not_null: NOT NULL branch_id
- branch_closure_business_id_not_null: NOT NULL business_id
- branch_closure_created_at_not_null: NOT NULL created_at
- branch_closure_ends_at_not_null: NOT NULL ends_at
- branch_closure_id_not_null: NOT NULL id
- branch_closure_pkey: PRIMARY KEY (id)
- branch_closure_reason_code_not_null: NOT NULL reason_code
- branch_closure_review_status_not_null: NOT NULL review_status
- branch_closure_row_version_not_null: NOT NULL row_version
- branch_closure_starts_at_not_null: NOT NULL starts_at
- branch_closure_updated_at_not_null: NOT NULL updated_at
- ck_branch_closure_0: CHECK ((row_version > 0))
- ck_branch_closure_1: CHECK ((ends_at > starts_at))
- ck_branch_closure_2: CHECK (isfinite(starts_at))
- ck_branch_closure_3: CHECK (isfinite(ends_at))
- fk_branch_closure_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_branch_closure_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_branch_closure_2: FOREIGN KEY (business_id, branch_id) REFERENCES ms_b1_design.branch(business_id, id) ON DELETE RESTRICT DEFERRABLE
- fk_branch_closure_3: FOREIGN KEY (approved_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- uq_branch_closure_0: UNIQUE (business_id, id, branch_id)

## branch_service_offering

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| branch_id | uuid | NO | — |
| service_id | uuid | NO | — |
| active | bool | NO | false |
| price_rial | int8 | YES | — |
| duration_minutes | int4 | YES | — |
| buffer_before_minutes | int4 | YES | — |
| buffer_after_minutes | int4 | YES | — |
| configuration_version | int8 | NO | 1 |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |
| resources_confirmed | bool | NO | false |

- b1_branch_service_offering_inactive: CHECK ((NOT active))
- branch_service_offering_active_not_null: NOT NULL active
- branch_service_offering_branch_id_not_null: NOT NULL branch_id
- branch_service_offering_business_id_not_null: NOT NULL business_id
- branch_service_offering_configuration_version_not_null: NOT NULL configuration_version
- branch_service_offering_created_at_not_null: NOT NULL created_at
- branch_service_offering_id_not_null: NOT NULL id
- branch_service_offering_pkey: PRIMARY KEY (id)
- branch_service_offering_resources_confirmed_not_null: NOT NULL resources_confirmed
- branch_service_offering_row_version_not_null: NOT NULL row_version
- branch_service_offering_service_id_not_null: NOT NULL service_id
- branch_service_offering_updated_at_not_null: NOT NULL updated_at
- ck_branch_service_offering_0: CHECK ((row_version > 0))
- ck_branch_service_offering_1: CHECK (((price_rial IS NULL) OR ((price_rial >= 0) AND ((price_rial % (10)::bigint) = 0))))
- ck_branch_service_offering_2: CHECK (((duration_minutes IS NULL) OR (duration_minutes > 0)))
- ck_branch_service_offering_3: CHECK (((buffer_before_minutes IS NULL) OR (buffer_before_minutes >= 0)))
- ck_branch_service_offering_4: CHECK (((buffer_after_minutes IS NULL) OR (buffer_after_minutes >= 0)))
- ck_branch_service_offering_5: CHECK ((configuration_version > 0))
- ck_branch_service_offering_6: CHECK (((NOT active) OR ((price_rial IS NOT NULL) AND (duration_minutes IS NOT NULL) AND (buffer_before_minutes IS NOT NULL) AND (buffer_after_minutes IS NOT NULL))))
- ck_branch_service_offering_7: CHECK (((NOT active) OR resources_confirmed))
- fk_branch_service_offering_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_branch_service_offering_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_branch_service_offering_2: FOREIGN KEY (business_id, branch_id) REFERENCES ms_b1_design.branch(business_id, id) ON DELETE RESTRICT DEFERRABLE
- fk_branch_service_offering_3: FOREIGN KEY (business_id, service_id) REFERENCES ms_b1_design.service(business_id, id) ON DELETE RESTRICT DEFERRABLE
- uq_branch_service_offering_0: UNIQUE (business_id, branch_id, service_id)
- uq_branch_service_offering_1: UNIQUE (business_id, id, branch_id, service_id)

## branch_working_hours

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| branch_id | uuid | NO | — |
| iso_weekday | int2 | NO | — |
| start_minute | int2 | NO | — |
| end_minute | int2 | NO | — |
| valid_from | date | NO | — |
| valid_to | date | YES | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |

- b2a_hours_finite_from: CHECK (isfinite(valid_from))
- b2a_hours_finite_to: CHECK (((valid_to IS NULL) OR isfinite(valid_to)))
- branch_working_hours_branch_id_not_null: NOT NULL branch_id
- branch_working_hours_business_id_not_null: NOT NULL business_id
- branch_working_hours_created_at_not_null: NOT NULL created_at
- branch_working_hours_end_minute_not_null: NOT NULL end_minute
- branch_working_hours_id_not_null: NOT NULL id
- branch_working_hours_iso_weekday_not_null: NOT NULL iso_weekday
- branch_working_hours_pkey: PRIMARY KEY (id)
- branch_working_hours_row_version_not_null: NOT NULL row_version
- branch_working_hours_start_minute_not_null: NOT NULL start_minute
- branch_working_hours_updated_at_not_null: NOT NULL updated_at
- branch_working_hours_valid_from_not_null: NOT NULL valid_from
- ck_branch_working_hours_0: CHECK ((row_version > 0))
- ck_branch_working_hours_1: CHECK (((iso_weekday >= 1) AND (iso_weekday <= 7)))
- ck_branch_working_hours_2: CHECK (((start_minute >= 0) AND (end_minute <= 1440) AND (end_minute > start_minute)))
- ck_branch_working_hours_3: CHECK (((valid_to IS NULL) OR (valid_to > valid_from)))
- fk_branch_working_hours_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_branch_working_hours_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_branch_working_hours_2: FOREIGN KEY (business_id, branch_id) REFERENCES ms_b1_design.branch(business_id, id) ON DELETE RESTRICT DEFERRABLE
- uq_branch_working_hours_0: UNIQUE (business_id, branch_id, iso_weekday, start_minute, valid_from)

## business

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| brand_name | text | NO | — |
| legal_name | text | YES | — |
| slug | text | NO | — |
| currency_code | text | NO | 'IRR'::text |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |

- business_brand_name_not_null: NOT NULL brand_name
- business_created_at_not_null: NOT NULL created_at
- business_currency_code_not_null: NOT NULL currency_code
- business_id_not_null: NOT NULL id
- business_pkey: PRIMARY KEY (id)
- business_row_version_not_null: NOT NULL row_version
- business_slug_not_null: NOT NULL slug
- business_updated_at_not_null: NOT NULL updated_at
- ck_business_0: CHECK ((row_version > 0))
- ck_business_1: CHECK ((currency_code = 'IRR'::text))
- ck_business_2: CHECK ((length(slug) > 0))
- fk_business_0: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- uq_business_0: UNIQUE (slug)

## consumer_inbox

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| event_id | uuid | NO | — |
| consumer_key | text | NO | — |
| processed_at | timestamptz | YES | — |
| state | text | NO | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |

- ck_consumer_inbox_0: CHECK ((row_version > 0))
- ck_consumer_inbox_1: CHECK ((state = ANY (ARRAY['PROCESSING'::text, 'COMPLETE'::text])))
- consumer_inbox_business_id_not_null: NOT NULL business_id
- consumer_inbox_consumer_key_not_null: NOT NULL consumer_key
- consumer_inbox_created_at_not_null: NOT NULL created_at
- consumer_inbox_event_id_not_null: NOT NULL event_id
- consumer_inbox_id_not_null: NOT NULL id
- consumer_inbox_pkey: PRIMARY KEY (id)
- consumer_inbox_row_version_not_null: NOT NULL row_version
- consumer_inbox_state_not_null: NOT NULL state
- consumer_inbox_updated_at_not_null: NOT NULL updated_at
- fk_consumer_inbox_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_consumer_inbox_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_consumer_inbox_2: FOREIGN KEY (business_id, event_id) REFERENCES ms_b1_design.outbox_event(business_id, id) ON DELETE RESTRICT DEFERRABLE
- uq_consumer_inbox_0: UNIQUE (business_id, event_id, consumer_key)

## idempotency_record

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| actor_key | text | NO | — |
| route_key | text | NO | — |
| idempotency_key | text | NO | — |
| request_hash | bytea | NO | — |
| state | text | NO | — |
| response_code | int4 | YES | — |
| response_snapshot | jsonb | YES | — |
| expires_at | timestamptz | NO | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |

- ck_idempotency_record_0: CHECK ((row_version > 0))
- ck_idempotency_record_1: CHECK ((state = ANY (ARRAY['PROCESSING'::text, 'COMPLETE'::text])))
- ck_idempotency_record_2: CHECK ((expires_at > created_at))
- ck_idempotency_record_3: CHECK (((state <> 'COMPLETE'::text) OR ((response_code IS NOT NULL) AND (response_snapshot IS NOT NULL))))
- ck_idempotency_record_4: CHECK ((octet_length(request_hash) = 32))
- ck_idempotency_record_5: CHECK (isfinite(expires_at))
- fk_idempotency_record_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_idempotency_record_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- idempotency_record_actor_key_not_null: NOT NULL actor_key
- idempotency_record_business_id_not_null: NOT NULL business_id
- idempotency_record_created_at_not_null: NOT NULL created_at
- idempotency_record_expires_at_not_null: NOT NULL expires_at
- idempotency_record_id_not_null: NOT NULL id
- idempotency_record_idempotency_key_not_null: NOT NULL idempotency_key
- idempotency_record_pkey: PRIMARY KEY (id)
- idempotency_record_request_hash_not_null: NOT NULL request_hash
- idempotency_record_route_key_not_null: NOT NULL route_key
- idempotency_record_row_version_not_null: NOT NULL row_version
- idempotency_record_state_not_null: NOT NULL state
- idempotency_record_updated_at_not_null: NOT NULL updated_at
- uq_idempotency_record_0: UNIQUE (business_id, actor_key, route_key, idempotency_key)

## offering_resource_requirement

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| offering_id | uuid | NO | — |
| branch_id | uuid | NO | — |
| service_id | uuid | NO | — |
| resource_kind | text | NO | — |
| quantity | int4 | NO | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |

- ck_offering_resource_requirement_0: CHECK ((row_version > 0))
- ck_offering_resource_requirement_1: CHECK ((resource_kind = ANY (ARRAY['CHAIR'::text, 'ROOM'::text, 'DEVICE'::text])))
- ck_offering_resource_requirement_2: CHECK ((quantity > 0))
- fk_offering_resource_requirement_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_offering_resource_requirement_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_offering_resource_requirement_2: FOREIGN KEY (business_id, offering_id, branch_id, service_id) REFERENCES ms_b1_design.branch_service_offering(business_id, id, branch_id, service_id) ON DELETE RESTRICT DEFERRABLE
- offering_resource_requirement_branch_id_not_null: NOT NULL branch_id
- offering_resource_requirement_business_id_not_null: NOT NULL business_id
- offering_resource_requirement_created_at_not_null: NOT NULL created_at
- offering_resource_requirement_id_not_null: NOT NULL id
- offering_resource_requirement_offering_id_not_null: NOT NULL offering_id
- offering_resource_requirement_pkey: PRIMARY KEY (id)
- offering_resource_requirement_quantity_not_null: NOT NULL quantity
- offering_resource_requirement_resource_kind_not_null: NOT NULL resource_kind
- offering_resource_requirement_row_version_not_null: NOT NULL row_version
- offering_resource_requirement_service_id_not_null: NOT NULL service_id
- offering_resource_requirement_updated_at_not_null: NOT NULL updated_at
- uq_offering_resource_requirement_0: UNIQUE (business_id, offering_id, resource_kind)

## offering_staff_eligibility

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| offering_id | uuid | NO | — |
| branch_id | uuid | NO | — |
| service_id | uuid | NO | — |
| staff_id | uuid | NO | — |
| assignment_id | uuid | NO | — |
| qualification_id | uuid | NO | — |
| active | bool | NO | false |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |

- ck_offering_staff_eligibility_0: CHECK ((row_version > 0))
- fk_offering_staff_eligibility_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_offering_staff_eligibility_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_offering_staff_eligibility_2: FOREIGN KEY (business_id, offering_id, branch_id, service_id) REFERENCES ms_b1_design.branch_service_offering(business_id, id, branch_id, service_id) ON DELETE RESTRICT DEFERRABLE
- fk_offering_staff_eligibility_3: FOREIGN KEY (business_id, assignment_id, staff_id, branch_id) REFERENCES ms_b1_design.staff_branch_assignment(business_id, id, staff_id, branch_id) ON DELETE RESTRICT DEFERRABLE
- fk_offering_staff_eligibility_4: FOREIGN KEY (business_id, qualification_id, staff_id, service_id) REFERENCES ms_b1_design.staff_service_eligibility(business_id, id, staff_id, service_id) ON DELETE RESTRICT DEFERRABLE
- offering_staff_eligibility_active_not_null: NOT NULL active
- offering_staff_eligibility_assignment_id_not_null: NOT NULL assignment_id
- offering_staff_eligibility_branch_id_not_null: NOT NULL branch_id
- offering_staff_eligibility_business_id_not_null: NOT NULL business_id
- offering_staff_eligibility_created_at_not_null: NOT NULL created_at
- offering_staff_eligibility_id_not_null: NOT NULL id
- offering_staff_eligibility_offering_id_not_null: NOT NULL offering_id
- offering_staff_eligibility_pkey: PRIMARY KEY (id)
- offering_staff_eligibility_qualification_id_not_null: NOT NULL qualification_id
- offering_staff_eligibility_row_version_not_null: NOT NULL row_version
- offering_staff_eligibility_service_id_not_null: NOT NULL service_id
- offering_staff_eligibility_staff_id_not_null: NOT NULL staff_id
- offering_staff_eligibility_updated_at_not_null: NOT NULL updated_at
- uq_offering_staff_eligibility_0: UNIQUE (business_id, offering_id, staff_id, assignment_id)

## outbox_event

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| aggregate_type | text | NO | — |
| aggregate_id | uuid | NO | — |
| aggregate_version | int8 | NO | — |
| event_type | text | NO | — |
| schema_version | int4 | NO | — |
| payload | jsonb | NO | — |
| available_at | timestamptz | NO | — |
| published_at | timestamptz | YES | — |
| publish_attempts | int4 | NO | 0 |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |

- ck_outbox_event_0: CHECK (((aggregate_version > 0) AND (schema_version > 0)))
- ck_outbox_event_1: CHECK ((publish_attempts >= 0))
- ck_outbox_event_2: CHECK ((jsonb_typeof(payload) = 'object'::text))
- fk_outbox_event_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_outbox_event_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- outbox_event_aggregate_id_not_null: NOT NULL aggregate_id
- outbox_event_aggregate_type_not_null: NOT NULL aggregate_type
- outbox_event_aggregate_version_not_null: NOT NULL aggregate_version
- outbox_event_available_at_not_null: NOT NULL available_at
- outbox_event_business_id_not_null: NOT NULL business_id
- outbox_event_created_at_not_null: NOT NULL created_at
- outbox_event_event_type_not_null: NOT NULL event_type
- outbox_event_id_not_null: NOT NULL id
- outbox_event_payload_not_null: NOT NULL payload
- outbox_event_pkey: PRIMARY KEY (id)
- outbox_event_publish_attempts_not_null: NOT NULL publish_attempts
- outbox_event_schema_version_not_null: NOT NULL schema_version
- uq_outbox_event_0: UNIQUE (business_id, id)
- uq_outbox_event_1: UNIQUE (business_id, aggregate_type, aggregate_id, aggregate_version, event_type)

## permission

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| permission_key | text | NO | — |
| description | text | NO | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |

- ck_permission_0: CHECK ((row_version > 0))
- fk_permission_0: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- permission_created_at_not_null: NOT NULL created_at
- permission_description_not_null: NOT NULL description
- permission_id_not_null: NOT NULL id
- permission_permission_key_not_null: NOT NULL permission_key
- permission_pkey: PRIMARY KEY (id)
- permission_row_version_not_null: NOT NULL row_version
- permission_updated_at_not_null: NOT NULL updated_at
- uq_permission_0: UNIQUE (permission_key)

## resource

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| branch_id | uuid | YES | — |
| kind | text | NO | — |
| label | text | NO | — |
| active | bool | NO | false |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |

- ck_resource_0: CHECK ((row_version > 0))
- ck_resource_1: CHECK ((kind = ANY (ARRAY['STAFF'::text, 'CHAIR'::text, 'ROOM'::text, 'DEVICE'::text])))
- ck_resource_2: CHECK ((((kind = 'STAFF'::text) AND (branch_id IS NULL)) OR ((kind <> 'STAFF'::text) AND (branch_id IS NOT NULL))))
- fk_resource_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_resource_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_resource_2: FOREIGN KEY (business_id, branch_id) REFERENCES ms_b1_design.branch(business_id, id) ON DELETE RESTRICT DEFERRABLE
- resource_active_not_null: NOT NULL active
- resource_business_id_not_null: NOT NULL business_id
- resource_created_at_not_null: NOT NULL created_at
- resource_id_not_null: NOT NULL id
- resource_kind_not_null: NOT NULL kind
- resource_label_not_null: NOT NULL label
- resource_pkey: PRIMARY KEY (id)
- resource_row_version_not_null: NOT NULL row_version
- resource_updated_at_not_null: NOT NULL updated_at
- uq_resource_0: UNIQUE (business_id, id, kind)
- uq_resource_1: UNIQUE (business_id, id, branch_id)

## role

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| role_key | text | NO | — |
| display_name | text | NO | — |
| system_role | bool | NO | false |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |

- ck_role_0: CHECK ((row_version > 0))
- fk_role_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_role_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- role_business_id_not_null: NOT NULL business_id
- role_created_at_not_null: NOT NULL created_at
- role_display_name_not_null: NOT NULL display_name
- role_id_not_null: NOT NULL id
- role_pkey: PRIMARY KEY (id)
- role_role_key_not_null: NOT NULL role_key
- role_row_version_not_null: NOT NULL row_version
- role_system_role_not_null: NOT NULL system_role
- role_updated_at_not_null: NOT NULL updated_at
- uq_role_0: UNIQUE (business_id, id)
- uq_role_1: UNIQUE (business_id, role_key)

## role_permission

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| role_id | uuid | NO | — |
| permission_id | uuid | NO | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |

- ck_role_permission_0: CHECK ((row_version > 0))
- fk_role_permission_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_role_permission_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_role_permission_2: FOREIGN KEY (business_id, role_id) REFERENCES ms_b1_design.role(business_id, id) ON DELETE RESTRICT DEFERRABLE
- fk_role_permission_3: FOREIGN KEY (permission_id) REFERENCES ms_b1_design.permission(id) ON DELETE RESTRICT DEFERRABLE
- role_permission_business_id_not_null: NOT NULL business_id
- role_permission_created_at_not_null: NOT NULL created_at
- role_permission_id_not_null: NOT NULL id
- role_permission_permission_id_not_null: NOT NULL permission_id
- role_permission_pkey: PRIMARY KEY (id)
- role_permission_role_id_not_null: NOT NULL role_id
- role_permission_row_version_not_null: NOT NULL row_version
- role_permission_updated_at_not_null: NOT NULL updated_at
- uq_role_permission_0: UNIQUE (business_id, role_id, permission_id)

## service

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| code | text | NO | — |
| display_name | text | NO | — |
| description | text | YES | — |
| active | bool | NO | false |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |

- ck_service_0: CHECK ((row_version > 0))
- fk_service_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_service_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- service_active_not_null: NOT NULL active
- service_business_id_not_null: NOT NULL business_id
- service_code_not_null: NOT NULL code
- service_created_at_not_null: NOT NULL created_at
- service_display_name_not_null: NOT NULL display_name
- service_id_not_null: NOT NULL id
- service_pkey: PRIMARY KEY (id)
- service_row_version_not_null: NOT NULL row_version
- service_updated_at_not_null: NOT NULL updated_at
- uq_service_0: UNIQUE (business_id, id)
- uq_service_1: UNIQUE (business_id, code)

## staff

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| user_id | uuid | YES | — |
| resource_id | uuid | NO | — |
| resource_kind | text | NO | 'STAFF'::text |
| display_name | text | NO | — |
| active | bool | NO | false |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |
| identity_link_evidence_hash | bytea | YES | — |

- ck_staff_0: CHECK ((row_version > 0))
- ck_staff_1: CHECK ((resource_kind = 'STAFF'::text))
- fk_staff_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_2: FOREIGN KEY (user_id) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_3: FOREIGN KEY (business_id, resource_id, resource_kind) REFERENCES ms_b1_design.resource(business_id, id, kind) ON DELETE RESTRICT DEFERRABLE
- staff_active_not_null: NOT NULL active
- staff_business_id_not_null: NOT NULL business_id
- staff_created_at_not_null: NOT NULL created_at
- staff_display_name_not_null: NOT NULL display_name
- staff_id_not_null: NOT NULL id
- staff_identity_link_evidence_hash_check: CHECK (((identity_link_evidence_hash IS NULL) OR (octet_length(identity_link_evidence_hash) = 32)))
- staff_pkey: PRIMARY KEY (id)
- staff_resource_id_not_null: NOT NULL resource_id
- staff_resource_kind_not_null: NOT NULL resource_kind
- staff_row_version_not_null: NOT NULL row_version
- staff_updated_at_not_null: NOT NULL updated_at
- uq_staff_0: UNIQUE (business_id, id)
- uq_staff_1: UNIQUE (business_id, resource_id)
- uq_staff_2: UNIQUE (business_id, user_id)
- uq_staff_3: UNIQUE (business_id, id, resource_id)

## staff_branch_assignment

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| staff_id | uuid | NO | — |
| branch_id | uuid | NO | — |
| valid_from | date | NO | — |
| valid_to | date | YES | — |
| active | bool | NO | false |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |
| voided_at | timestamptz | YES | — |
| void_reason | text | YES | — |
| membership_period | daterange | YES | — |

- ck_staff_branch_assignment_0: CHECK ((row_version > 0))
- ck_staff_branch_assignment_1: CHECK (((valid_to IS NULL) OR (valid_to > valid_from)))
- ck_staff_branch_assignment_2: CHECK (isfinite(valid_from))
- ck_staff_branch_assignment_3: CHECK (((valid_to IS NULL) OR isfinite(valid_to)))
- ck_staff_branch_assignment_4: CHECK ((((voided_at IS NULL) AND (void_reason IS NULL)) OR ((voided_at IS NOT NULL) AND (void_reason IS NOT NULL) AND (length(btrim(void_reason)) > 0))))
- ck_staff_branch_assignment_5: CHECK (((NOT active) OR (voided_at IS NULL)))
- fk_staff_branch_assignment_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_branch_assignment_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_branch_assignment_2: FOREIGN KEY (business_id, staff_id) REFERENCES ms_b1_design.staff(business_id, id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_branch_assignment_3: FOREIGN KEY (business_id, branch_id) REFERENCES ms_b1_design.branch(business_id, id) ON DELETE RESTRICT DEFERRABLE
- no_overlapping_membership_period: EXCLUDE USING gist (business_id WITH =, staff_id WITH =, branch_id WITH =, membership_period WITH &&) WHERE ((voided_at IS NULL))
- staff_branch_assignment_active_not_null: NOT NULL active
- staff_branch_assignment_branch_id_not_null: NOT NULL branch_id
- staff_branch_assignment_business_id_not_null: NOT NULL business_id
- staff_branch_assignment_created_at_not_null: NOT NULL created_at
- staff_branch_assignment_id_not_null: NOT NULL id
- staff_branch_assignment_pkey: PRIMARY KEY (id)
- staff_branch_assignment_row_version_not_null: NOT NULL row_version
- staff_branch_assignment_staff_id_not_null: NOT NULL staff_id
- staff_branch_assignment_updated_at_not_null: NOT NULL updated_at
- staff_branch_assignment_valid_from_not_null: NOT NULL valid_from
- uq_staff_branch_assignment_0: UNIQUE (business_id, id, staff_id, branch_id)

## staff_schedule_rule

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| staff_id | uuid | NO | — |
| branch_id | uuid | NO | — |
| assignment_id | uuid | NO | — |
| iso_weekday | int2 | NO | — |
| start_minute | int2 | NO | — |
| end_minute | int2 | NO | — |
| valid_from | date | NO | — |
| valid_to | date | YES | — |
| configuration_version | int8 | NO | 1 |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |
| service_id | uuid | YES | — |
| qualification_id | uuid | YES | — |
| offering_id | uuid | YES | — |

- b2a_rule_finite_from: CHECK (isfinite(valid_from))
- b2a_rule_finite_to: CHECK (((valid_to IS NULL) OR isfinite(valid_to)))
- b2b_rule_context: CHECK (((service_id IS NULL) = (qualification_id IS NULL)))
- b2b_rule_offering: FOREIGN KEY (business_id, offering_id, branch_id, service_id) REFERENCES ms_b1_design.branch_service_offering(business_id, id, branch_id, service_id)
- b2b_rule_qualification: FOREIGN KEY (business_id, qualification_id, staff_id, service_id) REFERENCES ms_b1_design.staff_service_eligibility(business_id, id, staff_id, service_id)
- ck_staff_schedule_rule_0: CHECK ((row_version > 0))
- ck_staff_schedule_rule_1: CHECK (((iso_weekday >= 1) AND (iso_weekday <= 7)))
- ck_staff_schedule_rule_2: CHECK (((start_minute >= 0) AND (end_minute <= 1440) AND (end_minute > start_minute)))
- ck_staff_schedule_rule_3: CHECK (((valid_to IS NULL) OR (valid_to > valid_from)))
- ck_staff_schedule_rule_4: CHECK ((configuration_version > 0))
- fk_staff_schedule_rule_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_schedule_rule_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_schedule_rule_2: FOREIGN KEY (business_id, assignment_id, staff_id, branch_id) REFERENCES ms_b1_design.staff_branch_assignment(business_id, id, staff_id, branch_id) ON DELETE RESTRICT DEFERRABLE
- staff_schedule_rule_assignment_id_not_null: NOT NULL assignment_id
- staff_schedule_rule_branch_id_not_null: NOT NULL branch_id
- staff_schedule_rule_business_id_not_null: NOT NULL business_id
- staff_schedule_rule_configuration_version_not_null: NOT NULL configuration_version
- staff_schedule_rule_created_at_not_null: NOT NULL created_at
- staff_schedule_rule_end_minute_not_null: NOT NULL end_minute
- staff_schedule_rule_id_not_null: NOT NULL id
- staff_schedule_rule_iso_weekday_not_null: NOT NULL iso_weekday
- staff_schedule_rule_pkey: PRIMARY KEY (id)
- staff_schedule_rule_row_version_not_null: NOT NULL row_version
- staff_schedule_rule_staff_id_not_null: NOT NULL staff_id
- staff_schedule_rule_start_minute_not_null: NOT NULL start_minute
- staff_schedule_rule_updated_at_not_null: NOT NULL updated_at
- staff_schedule_rule_valid_from_not_null: NOT NULL valid_from
- uq_staff_schedule_rule_0: UNIQUE (business_id, id, staff_id, branch_id, assignment_id)

## staff_service_eligibility

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| staff_id | uuid | NO | — |
| service_id | uuid | NO | — |
| verified_at | timestamptz | YES | — |
| active | bool | NO | false |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |
| verification_evidence_hash | bytea | YES | — |
| verified_by | uuid | YES | — |

- ck_staff_service_eligibility_0: CHECK ((row_version > 0))
- ck_staff_service_eligibility_1: CHECK (((NOT active) OR (verified_at IS NOT NULL)))
- fk_staff_service_eligibility_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_service_eligibility_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_service_eligibility_2: FOREIGN KEY (business_id, staff_id) REFERENCES ms_b1_design.staff(business_id, id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_service_eligibility_3: FOREIGN KEY (business_id, service_id) REFERENCES ms_b1_design.service(business_id, id) ON DELETE RESTRICT DEFERRABLE
- staff_service_eligibility_active_not_null: NOT NULL active
- staff_service_eligibility_business_id_not_null: NOT NULL business_id
- staff_service_eligibility_created_at_not_null: NOT NULL created_at
- staff_service_eligibility_id_not_null: NOT NULL id
- staff_service_eligibility_pkey: PRIMARY KEY (id)
- staff_service_eligibility_row_version_not_null: NOT NULL row_version
- staff_service_eligibility_service_id_not_null: NOT NULL service_id
- staff_service_eligibility_staff_id_not_null: NOT NULL staff_id
- staff_service_eligibility_updated_at_not_null: NOT NULL updated_at
- staff_service_eligibility_verification_evidence_hash_check: CHECK (((verification_evidence_hash IS NULL) OR (octet_length(verification_evidence_hash) = 32)))
- staff_service_eligibility_verified_by_fkey: FOREIGN KEY (verified_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT
- uq_staff_service_eligibility_0: UNIQUE (business_id, staff_id, service_id)
- uq_staff_service_eligibility_1: UNIQUE (business_id, id, staff_id, service_id)

## staff_shift

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| staff_id | uuid | NO | — |
| branch_id | uuid | NO | — |
| assignment_id | uuid | NO | — |
| schedule_rule_id | uuid | YES | — |
| starts_at | timestamptz | NO | — |
| ends_at | timestamptz | NO | — |
| published | bool | NO | false |
| schedule_version | int8 | NO | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |
| working_period | tstzrange | YES | — |
| plan_id | uuid | YES | — |
| local_date | date | YES | — |
| time_zone | text | YES | — |
| start_minute | int2 | YES | — |
| end_minute | int2 | YES | — |
| start_resolution | text | YES | — |
| end_resolution | text | YES | — |

- b2b_shift_local: CHECK (((local_date IS NULL) OR (isfinite(local_date) AND (time_zone IS NOT NULL) AND (start_minute >= 0) AND (end_minute <= 1440) AND (end_minute > start_minute) AND (start_resolution = ANY (ARRAY['reject'::text, 'earlier'::text, 'later'::text])) AND (end_resolution = ANY (ARRAY['reject'::text, 'earlier'::text, 'later'::text])))))
- ck_staff_shift_0: CHECK ((row_version > 0))
- ck_staff_shift_1: CHECK ((ends_at > starts_at))
- ck_staff_shift_2: CHECK ((schedule_version > 0))
- ck_staff_shift_3: CHECK (isfinite(starts_at))
- ck_staff_shift_4: CHECK (isfinite(ends_at))
- fk_staff_shift_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_shift_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_shift_2: FOREIGN KEY (business_id, assignment_id, staff_id, branch_id) REFERENCES ms_b1_design.staff_branch_assignment(business_id, id, staff_id, branch_id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_shift_3: FOREIGN KEY (business_id, schedule_rule_id, staff_id, branch_id, assignment_id) REFERENCES ms_b1_design.staff_schedule_rule(business_id, id, staff_id, branch_id, assignment_id) ON DELETE RESTRICT DEFERRABLE
- no_cross_branch_staff_shift: EXCLUDE USING gist (staff_id WITH =, working_period WITH &&) WHERE ((published AND (archived_at IS NULL)))
- staff_shift_assignment_id_not_null: NOT NULL assignment_id
- staff_shift_branch_id_not_null: NOT NULL branch_id
- staff_shift_business_id_not_null: NOT NULL business_id
- staff_shift_created_at_not_null: NOT NULL created_at
- staff_shift_ends_at_not_null: NOT NULL ends_at
- staff_shift_id_not_null: NOT NULL id
- staff_shift_pkey: PRIMARY KEY (id)
- staff_shift_published_not_null: NOT NULL published
- staff_shift_row_version_not_null: NOT NULL row_version
- staff_shift_schedule_version_not_null: NOT NULL schedule_version
- staff_shift_staff_id_not_null: NOT NULL staff_id
- staff_shift_starts_at_not_null: NOT NULL starts_at
- staff_shift_updated_at_not_null: NOT NULL updated_at

## staff_time_off

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| staff_id | uuid | NO | — |
| resource_id | uuid | NO | — |
| starts_at | timestamptz | NO | — |
| ends_at | timestamptz | NO | — |
| reason_code | text | NO | — |
| approved_by | uuid | YES | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |
| review_status | text | NO | 'LEGACY_UNREVIEWED'::text |
| supersedes_id | uuid | YES | — |

- b2b_timeoff_parent: FOREIGN KEY (business_id, supersedes_id) REFERENCES ms_b1_design.staff_time_off(business_id, id)
- b2b_timeoff_review: CHECK (((review_status = ANY (ARRAY['LEGACY_UNREVIEWED'::text, 'REQUESTED'::text, 'APPROVED'::text, 'REJECTED'::text])) AND ((review_status <> ALL (ARRAY['APPROVED'::text, 'REJECTED'::text])) OR ((approved_by IS NOT NULL) AND (supersedes_id IS NOT NULL)))))
- b2b_timeoff_review_identity: UNIQUE (business_id, id)
- b2b_timeoff_successor: UNIQUE (business_id, supersedes_id)
- ck_staff_time_off_0: CHECK ((row_version > 0))
- ck_staff_time_off_1: CHECK ((ends_at > starts_at))
- ck_staff_time_off_2: CHECK (isfinite(starts_at))
- ck_staff_time_off_3: CHECK (isfinite(ends_at))
- fk_staff_time_off_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_time_off_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_time_off_2: FOREIGN KEY (business_id, staff_id, resource_id) REFERENCES ms_b1_design.staff(business_id, id, resource_id) ON DELETE RESTRICT DEFERRABLE
- fk_staff_time_off_3: FOREIGN KEY (approved_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- staff_time_off_business_id_not_null: NOT NULL business_id
- staff_time_off_created_at_not_null: NOT NULL created_at
- staff_time_off_ends_at_not_null: NOT NULL ends_at
- staff_time_off_id_not_null: NOT NULL id
- staff_time_off_pkey: PRIMARY KEY (id)
- staff_time_off_reason_code_not_null: NOT NULL reason_code
- staff_time_off_resource_id_not_null: NOT NULL resource_id
- staff_time_off_review_status_not_null: NOT NULL review_status
- staff_time_off_row_version_not_null: NOT NULL row_version
- staff_time_off_staff_id_not_null: NOT NULL staff_id
- staff_time_off_starts_at_not_null: NOT NULL starts_at
- staff_time_off_updated_at_not_null: NOT NULL updated_at
- uq_staff_time_off_0: UNIQUE (business_id, id, resource_id)

## user_role_assignment

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| id | uuid | NO | gen_random_uuid() |
| business_id | uuid | NO | — |
| user_id | uuid | NO | — |
| role_id | uuid | NO | — |
| branch_id | uuid | YES | — |
| revoked_at | timestamptz | YES | — |
| created_at | timestamptz | NO | CURRENT_TIMESTAMP |
| created_by | uuid | YES | — |
| updated_at | timestamptz | NO | CURRENT_TIMESTAMP |
| row_version | int8 | NO | 1 |
| archived_at | timestamptz | YES | — |

- ck_user_role_assignment_0: CHECK ((row_version > 0))
- fk_user_role_assignment_0: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT DEFERRABLE
- fk_user_role_assignment_1: FOREIGN KEY (created_by) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_user_role_assignment_2: FOREIGN KEY (user_id) REFERENCES ms_b1_design.app_user(id) ON DELETE RESTRICT DEFERRABLE
- fk_user_role_assignment_3: FOREIGN KEY (business_id, role_id) REFERENCES ms_b1_design.role(business_id, id) ON DELETE RESTRICT DEFERRABLE
- fk_user_role_assignment_4: FOREIGN KEY (business_id, branch_id) REFERENCES ms_b1_design.branch(business_id, id) ON DELETE RESTRICT DEFERRABLE
- user_role_assignment_business_id_not_null: NOT NULL business_id
- user_role_assignment_created_at_not_null: NOT NULL created_at
- user_role_assignment_id_not_null: NOT NULL id
- user_role_assignment_pkey: PRIMARY KEY (id)
- user_role_assignment_role_id_not_null: NOT NULL role_id
- user_role_assignment_row_version_not_null: NOT NULL row_version
- user_role_assignment_updated_at_not_null: NOT NULL updated_at
- user_role_assignment_user_id_not_null: NOT NULL user_id

## workforce_calendar_revision

| Column | Type | Nullable | Default |
| --- | --- | --- | --- |
| business_id | uuid | NO | — |
| version | int8 | NO | 1 |

- workforce_calendar_revision_business_id_fkey: FOREIGN KEY (business_id) REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT
- workforce_calendar_revision_business_id_not_null: NOT NULL business_id
- workforce_calendar_revision_pkey: PRIMARY KEY (business_id)
- workforce_calendar_revision_version_check: CHECK ((version > 0))
- workforce_calendar_revision_version_not_null: NOT NULL version
