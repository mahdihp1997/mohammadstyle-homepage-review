# B4 migration inventory

0001–0011 are preserved byte-for-byte and in registry order.0012 adds the12 dependency-closed tables below, immutable evidence guards, native allocation GiST exclusion and access-pattern/FK/expiry indexes.0013 adds the verified planner, configuration fingerprint, shared locking and current/future-capacity writer guard.0014 replaces the two inactive gates with explicit safety activation and adds ownership/consent/lifecycle/read/command/sweep boundaries. There are no activation UPDATEs or seed data in migrations.

1. `booking_plan`
2. `pricing_quote`
3. `pricing_quote_item`
4. `quote_policy_source`
5. `booking`
6. `booking_revision`
7. `booking_service_segment`
8. `booking_hold`
9. `resource_allocation`
10. `segment_resource_assignment`
11. `booking_status_history`
12. `booking_policy_acceptance`

Dependency order: immutable plan→final quote→quote items/sources; booking→revision with deferred same-booking active-revision FK; segments→hold→allocations→segment assignments→history/acceptance. Existing IAM/business/catalog/workforce/B3 policy tables are reused. No payment/customer-PII/notification-consumer table or full72-table rollout is introduced.

RLS is not used as a substitute for the EXECUTE-only boundary. API/runtime have no new table grants; reviewed definer entry points perform tenant/owner/permission checks with pinned pg_catalog search paths. Local scalar checks are supported by actual planner/transaction tests; parser checks alone are not claimed as migrations.

Actual catalog: {"status":"PASS","sha256":"51cc54f8b2be350237645d2f3dbbcfa2d9cc32931a97ef0feecfbee712bc1cda","tables":50,"indexes":158,"functions":50,"foreignKeys":143,"checks":160,"exclusions":4,"apiEntryPoints":11,"publicExecute":false,"apiHasOwnerRole":false}
