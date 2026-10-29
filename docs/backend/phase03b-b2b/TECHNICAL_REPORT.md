# Phase03B-B2B technical review

Implemented in the ORIGINAL PRIVATE repository from approved33b8934. Isolated PostgreSQL18.6 on127.0.0.1:55440; original B0/B1A/B1B/B2A data and evidence are preserved. No B3/B4, booking engine, customer availability, payments, notifications, CMS or deployment.

## 1. Implemented modules

WorkforceModule exposes18 authenticated commands and12 bounded queries, alongside the12 unchanged B1B session/configuration operations through an isolated adapter. Staff/resource identity, temporal memberships, capability verification, explicit offering eligibility, immutable recurring rules, versioned publication/withdrawal, explicit exception review and disabled availability settings share the reviewed DB transaction port. Existing B1B SessionGuard/opaque-session evidence, CSRF/Origin controls, bounded rate limits and diagnostics are reused. The legacy B1B application source is unchanged.

## 2. Complete new API inventory

| Method | Route | Operation |
| --- | --- | --- |
| POST | /api/v1/admin/staff | staff.create |
| GET | /api/v1/admin/staff | read.staff |
| PUT | /api/v1/admin/staff/{id} | staff.update |
| POST | /api/v1/admin/staff/{id}/verified-identity | staff.link |
| POST | /api/v1/admin/branches/{branchId}/branch-assignments | assignment.create |
| GET | /api/v1/admin/branches/{branchId}/branch-assignments | read.assignments |
| POST | /api/v1/admin/branches/{branchId}/branch-assignments/{id}/end | assignment.close |
| POST | /api/v1/admin/staff/qualifications | qualification.set |
| GET | /api/v1/admin/staff/qualifications | read.qualifications |
| PUT | /api/v1/admin/branches/{branchId}/offering-staff-eligibility | eligibility.set |
| GET | /api/v1/admin/branches/{branchId}/offering-staff-eligibility | read.eligibilities |
| POST | /api/v1/admin/branches/{branchId}/resources | resource.create |
| GET | /api/v1/admin/branches/{branchId}/resources | read.resources |
| PUT | /api/v1/admin/branches/{branchId}/resources/{id} | resource.update |
| PUT | /api/v1/admin/branches/{branchId}/working-hours | hours.replace |
| GET | /api/v1/admin/branches/{branchId}/working-hours | read.hours |
| PUT | /api/v1/admin/branches/{branchId}/schedule-rules | rule.create |
| GET | /api/v1/admin/branches/{branchId}/schedule-rules | read.rules |
| POST | /api/v1/admin/branches/{branchId}/schedule/publications | schedule.publish |
| POST | /api/v1/admin/branches/{branchId}/schedule/withdrawals | schedule.withdraw |
| POST | /api/v1/admin/branches/{branchId}/time-off | timeoff.create |
| POST | /api/v1/admin/branches/{branchId}/closures | closure.create |
| POST | /api/v1/admin/branches/{branchId}/time-off/{id}/review | timeoff.review |
| POST | /api/v1/admin/branches/{branchId}/closures/{id}/review | closure.review |
| PUT | /api/v1/admin/branches/{branchId}/availability-configuration | configuration.set |
| GET | /api/v1/admin/branches/{branchId}/availability-configuration | read.configuration |
| GET | /api/v1/admin/workforce/context | read.context |
| GET | /api/v1/admin/branches/{branchId}/staff/{id}/schedule | read.schedule |
| GET | /api/v1/admin/branches/{branchId}/calendar | read.calendar |
| GET | /api/v1/admin/branches/{branchId}/exceptions | read.exceptions |

All command routes return200 with an explicit receipt, not a customer booking confirmation. Every mutation requires the business-wide workforce calendar If-Match plus Idempotency-Key. Record versions and calendar versions are distinct; see CONTRACT_CHANGES.md. Queries require from/to with an exclusive end, at most31 days,100 rows/page and offset<=10000.

## 3. Authentication and authorization

Server-side opaque session revalidation derives actor and business. Current permission+assignment scope is checked before replay. Role names and caller IDs are never authority. Owner requires explicit business-wide permissions; managers manage assigned-branch configuration. Global staff activation/identity/qualification and global time-off approval require business-wide delegation. Reception has schedule/staff reads only; Barber requires schedule.read.own plus verified user-to-staff linkage and membership; Customer has no admin grants. No login/bootstrap/role-grant route or production IdP is added.

## 4. Publication/timezone

PostgreSQL itself resolves local Gregorian dates/minutes through IANA timezone rules by enumerating and round-tripping minute-precision UTC candidates within16 hours. Gaps reject; folds require explicit earlier/later. At most62 segments and31 local dates per atomic plan. Rule UUID/version, local date, IANA zone, minute boundaries, disambiguation, UTC instants and plan UUID persist. Jalali stays frontend presentation. Overnight=true requires contiguous paired local-day segments within the same reviewed plan.

## 5. Temporal containment

Under the business gate, publication rechecks full UTC and local-date membership containment, active/nonvoid/nonarchived stint, same staff/branch, active global staff/resource, verified capability and optional explicit offering eligibility. Every local opening minute must be covered. Closing a stint rejects any retained published shift extending beyond its exclusive end, including existing evidence. A rejoin creates a NEW UUID; no historical reassignment.

## 6. Exceptions

REQUESTED is explicitly pending and does not block. Review inserts a distinct APPROVED/REJECTED successor with reviewer identity; content and parent evidence remain immutable. Legacy rows become LEGACY_UNREVIEWED without interpreting approved_by; they block conservatively pending review. Approved leave/closure conflicting with a published shift is rejected. No automatic shift cancellations. See SCHEDULING.md.

## 7. Travel

No real transfer minutes are invented. Any retained published shift in another branch for the same global staff identity prevents new cross-branch publication, even if intervals are adjacent or distant. This deliberately restrictive B2B fail-closed rule needs owner-approved transfer policy before real multi-branch roster use.

## 8. Transactions/concurrency

READ COMMITTED plus a transaction-scoped business advisory gate serializes this small administrative workload. All relevant branches and global resources lock in UUID order, then calendar revision and affected rows. Shared gate covers old config commands too. Cross-row checks are re-read after locks, followed by data+audit+unpublished outbox+idempotency in one statement transaction. Native global shift exclusion remains the independent backstop. At most two retries for proven-aborted40001/40P01; no network or external effects inside locks. Transport ambiguity returns503 and durable-key retry.

## 9. Migrations/catalog

0001..0005 exact bytes/checksums preserved.0006 adds relational evidence/status fields and one small workforce_calendar_revision table;0007 implements authorized commands;0008 adds bounded projections and legacy coordination.28 total tables,88 FK,101 CHECK,89 indexes,18 functions,2 exclusions. New indexes are PK/UNIQUE integrity indexes; no speculative performance indexes. Actual catalog fingerprint: d0fcf866ee251c6470871f06087dc051e5d1fecc949b0f0ab670f0b7cbb604ae. No full72-table rollout.

## 10. Actual new tests

B2B 71PASS/0FAIL;54 expected SQL rejections;8 real distinct-session races. Nest requests exercise actual controllers/guard/DTO/filter/DB port; direct SQL cases execute production entry points as the EXECUTE-only API role. Only fixtures, monitoring, fault injection and database lifecycle use trusted harness credentials. This is not a booking-concurrency or production-authentication claim.

## 11. Regressions

Original B2A69/B1B83/B1A47/B0 backend14/B0 SQL35 and Prisma7.10.1 run unchanged in disposable regression clones; their old assumptions are tested on their original migration profiles. They are not represented as upgraded B2B assertions. Frontend typecheck/build/92 Playwright results are recorded separately in TEST_RESULTS.md.

## 12. Backup/restore

Actual pg_dump custom archive 290472bytes; actual separate pg_restore sourcems_b2b_dev -> ms_b2b_restore; all row/catalog/effective-grant fingerprints compare. Dump/hash authentication secrets remain ignored and are excluded from export.

## 13–16. Files/Git/review

CHANGED_FILES.md inventories the changes; source migrations, implemented model, full dictionary and explicit OpenAPI profile accompany this report. Exact private/public SHAs and Draft PR URL are recorded in external GIT_DELIVERY_RECEIPT.json after committing. Public base is review/phase03b-b2a; no private Git objects/assets are imported. PR1–6 remain open Draft/unmerged. Individual diagrams and real execution-record captures are linked in REVIEW.html.

## 17. Remaining B3/B4 prerequisites

Owner-approved real staff/hours/qualifications, identity evidence custody, transfer rules, production auth/MFA/HTTPS/rate limits/retention and measured scale; policy aggregation/legal/unit decisions; new reviewed quote/booking/hold/allocation cohort; complete capacity admission/revalidation/expiry/compensation tests. Existing bookable=false, offering.active=false and availability_configuration.enabled=false remain. STOP for B2B review; no progression authorization is implied.
