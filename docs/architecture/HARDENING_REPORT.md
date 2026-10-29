# Phase03A architecture review hardening — technical report

Architecture/specification only. Private review baseline ab62e845bcbf7c351c29c6d77078d3bcfb97793a on feature/phase03a-architecture. Original Homepage, Booking, assets, dependencies and tests unchanged. No03B implementation/migration/backend execution.

| Finding | Resolution and review evidence |
| --- | --- |
| Quote hash uniqueness | Removed digest uniqueness; exact recursive MS_QUOTE_CONTENT_V2 payload/schema/JCS contract, reproducible immutable artifact, separate actor/idempotency/TTL identity. Independent customers can have equal hashes and different quote IDs. [Contract](QUOTE_HASH_CONTRACT.md), [schema](schema/quote-content.schema.json), [synthetic vectors](schema/quote-hash-vectors.json) |
| Leave/rejoin history | One membership UUID per half-open period, exclusion protecting non-voided historical periods, period-specific offering eligibility and same-stint rule/shift reference. Explicit close/correction gates. [Temporal model](TEMPORAL_STAFF_ASSIGNMENT.md) |
| Draft invariants | Revisionless DRAFT/CANCELLED/EXPIRED with finite draft expiry, monotonic plan_committed for admitted plans; atomic state/flag/pointer update, disjoint future DTOs. [Row/transition contract](BOOKING_DRAFT_INVARIANTS.md) |
| Index review |193→85 standalone definitions;46 unused identity helpers plus quote-hash unique removed. Integrity/FK-support/recovery/exclusion categories separate;15 query candidates await EXPLAIN; no blind created_by indexes. Composite FK targets retained. [Audit](INDEX_REVIEW.md), [inventory](schema/index-inventory.json) |
| Staged B1 |Exactly16 dependency-closed foundation tables, create-before-FK order and inactive branch/offering gates.56 tables deferred; later cyclic cohort explicit, no all72 migration. [Inventory/order](B1_SCHEMA_SCOPE.md), [draft SQL](schema/b1-draft-postgresql.sql) |
| Mixed service policies |Unified whole terms / per-item allocation / grouped separate bookings / restricted combinations compared. Owner has selected none; heterogeneous winners remain409 and no automatic money/terms merge. [Alternatives](MULTI_SERVICE_POLICY_OPTIONS.md) |
| Visual review |Complete72-table source ERD preserved,16 context projections, readable module map plus exact DAG, straight-arrow payment sequence with explicit alternate outcomes;26 actual rendered pairs. [Visual index](REVIEW.html), [individual links](VISUAL_REVIEW_PACKAGE.md) |

## Changed files and consistency

The full dictionary/SQL/model and OpenAPI were updated together. Complete target remains72 tables/254 FKs; local CHECKs are250 and exclusions4. Proposed API now69 paths/71 operations/82 schemas, reflecting draft creation/response shapes and explicit membership-period closing. These are future contracts only; no frontend integration or current UI behavior changed.19 ADRs and29 future acceptance scenarios now cover the findings.

Index counts are design definitions, not a catalog/performance benchmark. Quote digest is not authentication, TTL or global identity. Draft flag monotonicity, period containment and evidence freeze still require future application/grant/trigger tests. Per-item/grouped policy options are not schema-complete in the current target; no business aggregation rule was invented.

## Actual verification

See [VALIDATION_RESULTS.md](VALIDATION_RESULTS.md) and JSON for18 static check groups: PostgreSQL18 parser accepts423 full and70 B1 statements; model/FK/index/stage/dictionary checks, exact hash schema/vectors, draft-shape and membership specification examples, OpenAPI/ref validity, acyclic dependencies and complete/context diagram coverage. No SQL ran on PostgreSQL, no migration/concurrency/EXPLAIN test was performed. Review-page browser results are separate and explicitly not Next.js QA. Frontend commands were not rerun because no source/dependency/test changed.

## Git / safe public delivery

Commit on the original private architecture branch; update the same sanitized public review/phase03a-architecture branch and Draft PR2 targeting review/phase02-booking. Public main/Phase02/PR1 remain unchanged and neither PR is merged. Transfer only derived architecture files and generated diagrams; no private photos/fonts/references/screenshots/credentials/Git objects. Exact new SHAs/PR metadata and final file hashes are supplied in the external delivery receipts after committing.

## Remaining decisions and stop gate

Owner mixed-policy strategy; actual staff/branch/config/prices/durations/hours/resources; draft/hold TTL and retention; legal/merchant units and real policy terms; correction authority; approved03B environment/DDL/permission/constraint/restore testing. No publication blocker is presumed. Stop after03A for architecture approval; do not begin03B.
