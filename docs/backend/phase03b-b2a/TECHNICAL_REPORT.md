# B2A — implemented workforce and scheduling persistence

Implemented only B2A in the ORIGINAL PRIVATE repository from approved B1B2477f3bf369acf8fa73dc896c9479ccaa52235ec, on feature/phase03b-b2a-workforce-schema. Approved frontend/Booking source, dependencies, B1B session/admin application code, migration0001/0002/0003 and prior branches/reports/tests are unchanged. Original B1A/B1B data/catalog fingerprints match approved backups;36 prior evidence/backup files remain byte-identical. B0/B1A/B1B clusters were not reset.

## Exact dependency-closed tranche

1. branch_working_hours
2. branch_closure
3. resource
4. staff
5. staff_branch_assignment
6. staff_service_eligibility
7. offering_staff_eligibility
8. staff_schedule_rule
9. staff_shift
10. staff_time_off
11. availability_configuration

The approved stages.json inventory and all model prerequisites were checked before generation.0004_b2a_workforce_foundation copies exactly68 approved executable table/ALTER/index statements, plus extension/search_path setup. All11 tables are created in dependency-safe order, then FKs/indexes/generated columns and native exclusions.0005_b2a_history_guards adds reviewed local-row guards without adding another table. BookingRevision, BookingHold, ResourceAllocation and every later customer/policy/financial/media/notification table remain absent. Existing original architecture model/dictionary/SQL are preserved as the broader approved envelope; IMPLEMENTED_MODEL.json and TABLE_DICTIONARY.md describe this implemented subset and explicit hardening differences.

Current app catalog:27 tables,82 FK,93 CHECK,84 indexes,2 stored generated ranges,2 native exclusion constraints,4 existing RLS policies,9 functions and12 application triggers. Relative to B1B:11 tables,41 FK,48 CHECK,40 indexes,2 invoker trigger functions and12 triggers; existing3 API EXECUTE grants and legacy runtime grants are unchanged. No speculative performance index is introduced.

## Staff, membership and resources

One staff UUID and one globally scoped STAFF resource represent a known staff identity in one business. Resource.kind=STAFF requires null branch_id; CHAIR/ROOM/DEVICE require exactly one tenant-owned branch. Each physical row is one capacity unit, with stable identity and inactive/archive metadata. Staff's composite resource FK requires the same business and STAFF kind; unique business/resource and business/user keys prevent duplicating a linked identity. Unlinked null users still require future human identity verification/deduplication; names are not identity proof. A STAFF resource may exist temporarily before its Staff link in a trusted creation transaction; reverse total participation is not an extra DB constraint.

StaffBranchAssignment uses a UUID per stint, finite local valid_from, exclusive nullable valid_to and generated daterange [from,to). Same business/staff/branch non-voided overlap is rejected even if archived/inactive; membership at different branches may coexist. Closing an open stint advances row version and retains it; rejoin creates another UUID. Closed periods cannot reopen/extend, identity/start cannot be repointed, and void/archive cannot be silently reversed. Correction/void permissions and referenced-future-shift reconciliation remain B2B workflow gates, not an unauthenticated API.

StaffServiceEligibility is qualification, not a schedule or implicit branch offering assignment. OfferingStaffEligibility binds exact business/offering/service/staff/branch/qualification/stint via composite FKs; returning staff get new eligibility rows without repointing historical rows. FKs validate identity, not current active/verified/temporal readiness across rows. Inactive references remain historical, and no active-row shortcut bypasses membership exclusion.

## Rules, instants and revision semantics

Branch opening hours and recurring staff rules store Gregorian local dates, ISO weekday1..7 and minute intervals0..1440 with end>start. Overnight rules must be split across two explicit local-day entries, such as Sunday22:00–24:00 and Monday00:00–02:00. No wrapping rule is inferred. Branch retains a validated IANA timezone; a trigger validates new/timezone-updated branch rows and the migration refuses invalid existing timezone values without silently correcting them. Extra finite-date checks protect recurrence/opening effective windows. There is no automatic recurrence materializer, Jalali persistence, fixed Tehran offset or invented working schedule.

Published shifts store finite timestamptz starts/ends, explicit schedule_version, same-stint rule reference and generated tstzrange [start,end). Native no_cross_branch_staff_shift excludes published, non-archived overlaps by global staff_id across branches. Adjacent intervals are allowed mathematically; no travel-time feasibility is implied. Draft shifts can overlap and do not constitute availability. Archived shift evidence remains stored; accepted booking impact is not handled because no booking cohort exists.

Rules/opening hours/time-off/closures are immutable content revisions: archive old evidence and insert a successor UUID. Published shift instants/version/publication flag cannot be rewritten in place; draft edits require exact next row_version. Every new-table UPDATE requires old+1 row_version, preserves identity/creation evidence and sets updated_at. Configuration updates also require old+1 configuration_version. Two real writers with the same expected version produce one row update and one zero-row CAS result. A blind stale submitted version is rejected by the DB guard. This does not implement a branch-wide monotonic publication counter or an audited revision workflow; those require B2B locking and authorization.

Generated fields are excluded from BEFORE-trigger content comparison because PostgreSQL populates them afterward. Their input columns remain frozen and direct override is independently rejected428C9. The initial actual run found this defect in an archive test (64PASS/1FAIL); it was corrected without weakening immutability, and final 69 tests pass. Failed attempt evidence is retained separately.

Time off and branch closures retain bounded instants, reason/optional approver and correct tenant/resource references. Their cross-row intersection with shifts is explicitly NOT enforced in this tranche. Missing resource requirements never imply unlimited capacity: no availability search or resource allocator is implemented, and existing branch/offering inactive booking gates remain enforced.

## Security and prior API compatibility

There is no new management endpoint or production login. Neither ms_b1b_api nor ms_b1a_runtime can SELECT or mutate any new table; exactly3 original session-bound API functions remain callable, with no broad ownership, role membership or PUBLIC helper EXECUTE. Trigger functions are SECURITY INVOKER with pinned pg_catalog path and revoked PUBLIC EXECUTE. Data mutation in B2A integration is a trusted marked-local migration-role fixture operation, not application authorization.

Original83 B1B HTTP/security tests run unchanged in an isolated baseline clone. An additional B2A test invokes existing B1B session/read/atomic-command functions on the upgraded27-table schema and confirms tenant scope, branch creation, audit and unpublished outbox. B1B workforce-related projection fields and unsupported write restrictions remain unchanged; exposing the new eligibility/resource data requires a reviewed B2B DTO/permission change. RLS remains defense in depth, not authentication or protection against a compromised migration/legacy runtime credential. No synthetic authentication token, raw session hash, credential or dump is exported.

## Actual validation and recovery

Backend npm ci installed249 pinned packages using a verified offline cache/--ignore-scripts; backend typecheck/build passed. 69 B2A PostgreSQL18.6 assertions pass, with100 expected SQL rejections and3 separately observed lock-wait races. Cross-branch shift/membership conflicts use distinct real PostgreSQL pids, observed Lock waits and23P01; CAS uses the same pattern and one zero-row loser. Two concurrent migrators apply versions once (5/0). Source checksums/prefix history, fresh installation, B1B upgrade preserving data, no-op, failed DDL/history rollback, drift/FK/index/generated/trigger checks pass. Parser validation is separately labeled, never substituted for execution.

All83 B1B,47 B1A,14 B0 backend and35 B0 SQL assertions plus Prisma7.10.1 compatibility pass in disposable copied harnesses/tmpfs clusters55439/55437/55435. The unchanged B0 probe executes its historical72-table draft only inside its own tmpfs regression cluster; it is never part of the B2A migration rollout. Original test bodies, old test results and original volumes/databases remain intact. Only ignored harness routing/compiled local option literals are adapted; no approved test expectation is weakened. Root frontend typecheck/build and all92 actual Next.js Playwright tests pass across four existing viewports. Generated private UI screenshots are restored and not exported; static preview/diagram rendering is not frontend QA.

B2A uses a new project mohammadstyle-b2a at127.0.0.1:55438, independent credentials/volume/control DB and strict ms_b2a_dev/failure/restore allowlist. No startup migration, prisma db push, production DB or global Docker cleanup. Original0001/0002/0003 checksums are preserved; only the B2A registry/catalog extend the chain.

Actual pg_dump (PostgreSQL) 18.6 (Debian 18.6-1.pgdg12+2), custom archive163026 bytes, SHA256:848a16fb9db48e9af8309b2cb8449f1413c51a96df675fecd6f75c27033b60fb. Separate pg_restore into ms_b2a_restore compares ordered lossless row hashes for all27 tables plus migration history, every application catalog object, generated expressions, constraints/indexes, triggers/functions, effective grants/RLS and btree_gist version/owner/schema. Restored exclusion/immutability behavior is independently exercised. No success is inferred merely from archive creation. Roles are provisioned separately; archive stays ignored. This is not PITR/production recovery certification.

## Remaining gates

See OPEN_DECISIONS.md for every unimplemented scheduling invariant and B2B requirement. This is persistence plus local/native concurrency enforcement, not authoritative availability or complete double-booking prevention. Stop after B2A for approval; no B2B API, booking/hold/allocation, real slot search, payment, notification, CMS or deployment begins.
