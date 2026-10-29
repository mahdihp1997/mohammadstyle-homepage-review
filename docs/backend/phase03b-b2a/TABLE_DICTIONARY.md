# Implemented B2A dictionary

Actual27-table catalog; below are the11 added tables. Original B1 dictionary remains unchanged. Nullable/default/type values and generated expressions come from the executed catalog.

## branch_working_hours

| Column | PostgreSQL type | Nullable | Default/generated expression |
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

## branch_closure

| Column | PostgreSQL type | Nullable | Default/generated expression |
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

- branch_closure_branch_id_not_null: NOT NULL branch_id
- branch_closure_business_id_not_null: NOT NULL business_id
- branch_closure_created_at_not_null: NOT NULL created_at
- branch_closure_ends_at_not_null: NOT NULL ends_at
- branch_closure_id_not_null: NOT NULL id
- branch_closure_pkey: PRIMARY KEY (id)
- branch_closure_reason_code_not_null: NOT NULL reason_code
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

## resource

| Column | PostgreSQL type | Nullable | Default/generated expression |
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

## staff

| Column | PostgreSQL type | Nullable | Default/generated expression |
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

| Column | PostgreSQL type | Nullable | Default/generated expression |
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
| membership_period | daterange | YES | daterange(valid_from, valid_to, '[)'::text) |

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

## staff_service_eligibility

| Column | PostgreSQL type | Nullable | Default/generated expression |
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
- uq_staff_service_eligibility_0: UNIQUE (business_id, staff_id, service_id)
- uq_staff_service_eligibility_1: UNIQUE (business_id, id, staff_id, service_id)

## offering_staff_eligibility

| Column | PostgreSQL type | Nullable | Default/generated expression |
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

## staff_schedule_rule

| Column | PostgreSQL type | Nullable | Default/generated expression |
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

- b2a_rule_finite_from: CHECK (isfinite(valid_from))
- b2a_rule_finite_to: CHECK (((valid_to IS NULL) OR isfinite(valid_to)))
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

## staff_shift

| Column | PostgreSQL type | Nullable | Default/generated expression |
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
| working_period | tstzrange | YES | tstzrange(starts_at, ends_at, '[)'::text) |

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

| Column | PostgreSQL type | Nullable | Default/generated expression |
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
- staff_time_off_row_version_not_null: NOT NULL row_version
- staff_time_off_staff_id_not_null: NOT NULL staff_id
- staff_time_off_starts_at_not_null: NOT NULL starts_at
- staff_time_off_updated_at_not_null: NOT NULL updated_at
- uq_staff_time_off_0: UNIQUE (business_id, id, resource_id)

## availability_configuration

| Column | PostgreSQL type | Nullable | Default/generated expression |
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

## Additional implemented guards

0005 applies b2a_revision to all11 tables, plus b2a_branch_timezone to the existing branch table. Invoker functions pin pg_catalog and add no API grants. Exact per-field history/version behavior and all deferred cross-row invariants are documented in TECHNICAL_REPORT.md and OPEN_DECISIONS.md.
