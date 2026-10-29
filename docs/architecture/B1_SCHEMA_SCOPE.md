# Phase03B B1 — explicit bounded schema proposal

**PROPOSED / Phase03A architecture hardening only.** No backend, migration, database execution, payment or messaging implementation. Original Homepage/Booking/source/assets/tests are unchanged.

**B1 is16 tables, not72.** Its scope is identity/authorization foundations, inactive business/branch/catalog/offering configuration and audit/idempotency/outbox plumbing. No quotes, policies, bookings/holds, staff scheduling, payments, customer photos or messages become operational. Actual service/branch/staff/price facts remain unconfirmed; no demo seeds.

## Dependency-safe draft order

Pass0: choose PostgreSQL/version/privileged deployment role and disposable test environment after approval. Pass1 creates only the following tables and their local PK/unique/CHECK constraints. Pass2 adds all B1 FKs after those tables exist, including app_user's self actor reference. Pass3 adds only B1 selected indexes and temporary inactivity gates. All referenced tables belong to this inventory; static dependency closure is checked.

| Order | Table | Referenced B1 parent tables (self actor cycle handled in pass2) |
| --- | --- | --- |
| 1 | app_user | app_user |
| 2 | business | app_user |
| 3 | permission | app_user |
| 4 | auth_identity | app_user |
| 5 | auth_session | app_user |
| 6 | role | business, app_user |
| 7 | branch | business, app_user |
| 8 | role_permission | business, app_user, role, permission |
| 9 | user_role_assignment | business, app_user, role, branch |
| 10 | service | business, app_user |
| 11 | branch_service_offering | business, app_user, branch, service |
| 12 | offering_resource_requirement | business, app_user, branch_service_offering |
| 13 | audit_log | business, app_user, branch |
| 14 | idempotency_record | business, app_user |
| 15 | outbox_event | business, app_user |
| 16 | consumer_inbox | business, app_user, outbox_event |

Draft-only [B1 SQL](schema/b1-draft-postgresql.sql) and [stage inventory](schema/stages.json) are architecture review artifacts, **not generated production migrations**. They have never been executed. B1 has temporary NOT bookable on branch and NOT active on branch_service_offering, so configuration cannot advertise real bookability merely because scalar fields exist. Removing these gates requires reviewed B2/B3/B4 resource, policy and authoritative admission tests. Do not silently lift them during deployment.

## Explicitly deferred56 tables

- branch_working_hours — B2
- branch_closure — B2
- resource — B2
- staff — B2
- staff_branch_assignment — B2
- staff_service_eligibility — B2
- offering_staff_eligibility — B2
- staff_schedule_rule — B2
- staff_shift — B2
- staff_time_off — B2
- package — B3_B4_STRUCTURE_ONLY (disabled structural prerequisite; package functionality remains later)
- package_service — LATER
- customer — B3_B4_COHORT
- availability_configuration — B2
- booking_policy — B3_B4_COHORT
- booking_policy_version — B3_B4_COHORT
- policy_refund_window — B3_B4_COHORT
- booking_policy_assignment — B3_B4_COHORT
- pricing_quote — B3_B4_COHORT
- pricing_quote_item — B3_B4_COHORT
- quote_policy_resolution — B3_B4_COHORT
- quote_policy_source — B3_B4_COHORT
- booking — B3_B4_COHORT
- booking_revision — B3_B4_COHORT
- booking_item — B3_B4_COHORT
- booking_service_segment — B3_B4_COHORT
- segment_dependency — LATER
- booking_hold — B3_B4_COHORT
- resource_allocation — B3_B4_COHORT
- booking_status_history — B3_B4_COHORT
- booking_policy_acceptance — B3_B4_COHORT
- payment_intent — B6
- gateway_event — B6
- payment_transaction — B6
- payment_application — B6
- payment_balance — B6
- refund — B6
- financial_audit_record — B6
- media_asset — B8
- media_variant — B8
- media_publication_consent — B8
- portfolio_category — B8
- portfolio_item — B8
- portfolio_item_category — B8
- portfolio_service_relation — B8
- portfolio_media — B8
- portfolio_tag — B8
- portfolio_item_tag — B8
- notification_channel_config — B7
- notification_template — B7
- notification_preference — B7
- notification_link_challenge — B7
- channel_identity — B7
- notification_event — B7
- notification_delivery_attempt — B7
- segment_resource_assignment — B3_B4_COHORT

## Later dependency cohorts

B2 can introduce the staff/resource/rule/shift configuration and membership-period constraints, but the unified occupancy ledger's booking/hold references belong to the later booking cohort. B2 alone cannot claim to admit appointments. B3 can develop policy definition/version/refund-window semantics. The full target contains cycles among booking/revision/hold/allocation and booking-scoped policy/quote evidence; these need a reviewed **B3/B4 schema cohort** with create-tables-first/add-FKs-second, not a dangling FK or an implicit all72-table migration. Package targets must be supplied as disabled structural prerequisites in that cohort or explicitly removed together from a narrower reviewed migration; never silently omit a live FK or seed a package. Payment/media/notification tables remain separate gated tranches. Stage labels are planning minima, not executable batches for those later cycles.

Before real B1: actual catalog/constraint/grant validation, rollback/restore, tenant authorization negatives, temporary gate tests, schema drift and future-compatible migration review. B1 parser success does not prove any of these. Architecture approval remains required before generating or executing any production migration.
