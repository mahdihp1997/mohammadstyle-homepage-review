# B3 database changes

0010 creates exactly10 dependency-safe tables;0011 installs immutable guards, deterministic resolver/calculator and two permissioned API boundaries. Complete old0001–0009 history/checksums remain unchanged. No72-table rollout or fake cyclic FK target.

| Table | Purpose |
| --- | --- |
|`pricing_configuration_revision`|Business-wide pricing CAS and serialized configuration epoch|
|`booking_policy`|Named business or branch policy definition|
|`booking_policy_version`|Versioned structured deposit/cancellation/refund terms; frozen after publication|
|`policy_refund_window`|Relational inclusive refund thresholds of an immutable version|
|`booking_policy_assignment`|Temporal scoped routing and reviewed revocation; native overlap exclusion|
|`policy_assignment_service`|Exact selected service set for explicit whole-booking override|
|`policy_assignment_compatibility`|Exact compatible underlying winning version set for whole override|
|`pricing_proposal`|Immutable actor-owned commercial precursor, TTL/content digest independent of identity|
|`pricing_proposal_item`|Normalized immutable server price/duration/version line snapshots|
|`pricing_proposal_source`|Normalized immutable routing evidence references|

Actual full columns/checks/FKs are in SCHEMA_INVENTORY.json and full expected catalog. Existing availability_configuration gains no column; B3 only sets its explicitly configured quote TTL through a guarded command. Existing branches/offering bookability remains disabled. All new API access is EXECUTE-only; there are no broad table grants. Four selected FK-support indexes plus identity/unique/concurrency indexes; defer additional query indexes to EXPLAIN evidence. No automatic actor indexes.

The four policy concepts follow the approved architecture; package/booking/acceptance scopes remain outside this dependency-safe cohort. Staff and exact-set compatible whole-booking scopes are explicit reviewed B3 extensions. Three commercial precursor tables keep final pricing_quote and booking/resource/consent dependencies out until B4. Policy/routing history is retained; only idempotency lifecycle metadata is reusable under existing bounds. No new production retention rule is selected.
