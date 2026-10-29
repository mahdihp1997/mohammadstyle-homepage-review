# B0 validation matrix and limits

| Concern | Actual B0 evidence | Still deferred |
| --- | --- | --- |
| SQL/schema |70 B1 and423 full statements execute,16/72 tables; catalog FK/CHECK/index/generated/exclusion counts recorded | Production migrations/drift/restore/grants |
| Tenant FK | Cross-business offering references rejected23503 in both schemas | Actor/object authorization, API/list/export isolation |
| Uniqueness | Duplicate branch code23505; quote content digest intentionally non-unique across2 customers | Quote idempotent API/ownership/TTL/document recomputation |
| Unknown config | Missing timezone23502; negative price/zero duration23514; active incomplete offering rejected | IANA semantic timezone validation, resource/config cross-row readiness |
| B1 gates | Bookable branch and active fully populated offering rejected23514 | Gate removal requires separately approved later tranches |
| Membership | Archived inactive overlap rejected23P01, adjacent new stint accepted; generated daterange verified | Publish/close coverage, permissions and immutable prior references |
| Revisionless draft | DRAFT/CANCELLED/EXPIRED rows accepted; confirmed without revision and infinite TTL rejected | Audited transition/history/outbox/monotonicity, admitted aggregate creation |
| Occupancy | Overlap23P01, adjacent range accepted, released historical row accepted;2 backend sessions observe Lock then23P01 | Actual Booking Engine/hold expiry/full resource set/lock retry races |
| Shift and policy routing | Cross-branch published shift and equal-rank policy overlap23P01; generated working/effective/scope values verified | Recurrence/timezone/travel semantics, Policy Engine/business strategy |
| Transactions | ROLLBACK discards writes; deferred FK resolves at COMMIT or fails23503; Prisma SERIALIZABLE observed | Fault injection, booking command serialization retries and idempotent recovery |
| Foundation |14 config/process/HTTP/connection/security tests pass; actual Compose containers healthy and loopback-only | Production deployment/auth/TLS/backup/PITR/security certification |
| Frontend | Existing typecheck/build/92 Playwright tests pass; unchanged visual code and assets | Future explicit SERVER adapter; current UI stays demo |

## Individual actual SQL assertions

- PASS: B1: cross-tenant composite FK rejects foreign branch — {"sqlstate":"23503","constraint":"fk_branch_service_offering_2"}
- PASS: B1: per-tenant branch code uniqueness — {"sqlstate":"23505","constraint":"uq_branch_1"}
- PASS: B1: absent mandatory timezone rejected — {"sqlstate":"23502","constraint":null}
- PASS: B1: negative price rejected — {"sqlstate":"23514","constraint":"ck_branch_service_offering_1"}
- PASS: B1: zero duration rejected — {"sqlstate":"23514","constraint":"ck_branch_service_offering_2"}
- PASS: B1: transaction rollback removes synthetic write
- PASS: B1: FK deferral supports child-before-parent commit
- PASS: B1: unresolved deferred FK fails COMMIT and rolls back — {"sqlstate":"23503","constraint":"fk_auth_identity_1"}
- PASS: B1: bookable branch gate even with active branch — {"sqlstate":"23514","constraint":"b1_branch_inactive"}
- PASS: B1: active offering gate even with all scalar configuration — {"sqlstate":"23514","constraint":"b1_branch_service_offering_inactive"}
- PASS: FULL: cross-tenant composite FK rejects foreign branch — {"sqlstate":"23503","constraint":"fk_branch_service_offering_2"}
- PASS: FULL: per-tenant branch code uniqueness — {"sqlstate":"23505","constraint":"uq_branch_1"}
- PASS: FULL: absent mandatory timezone rejected — {"sqlstate":"23502","constraint":null}
- PASS: FULL: negative price rejected — {"sqlstate":"23514","constraint":"ck_branch_service_offering_1"}
- PASS: FULL: zero duration rejected — {"sqlstate":"23514","constraint":"ck_branch_service_offering_2"}
- PASS: FULL: transaction rollback removes synthetic write
- PASS: FULL: FK deferral supports child-before-parent commit
- PASS: FULL: unresolved deferred FK fails COMMIT and rolls back — {"sqlstate":"23503","constraint":"fk_auth_identity_1"}
- PASS: FULL: activating missing offering configuration fails closed — {"sqlstate":"23514","constraint":"ck_branch_service_offering_6"}
- PASS: FULL: independent customers may retain identical content hashes
- PASS: FULL: inactive archived membership overlap still rejected — {"sqlstate":"23P01","constraint":"no_overlapping_membership_period"}
- PASS: FULL: adjacent rejoin creates new historical stint and generated range
- PASS: FULL: unreasoned void rejected — {"sqlstate":"23514","constraint":"ck_staff_branch_assignment_4"}
- PASS: FULL: global staff shift exclusion across different branches — {"sqlstate":"23P01","constraint":"no_cross_branch_staff_shift"}
- PASS: FULL: policy scope/range generation and equal-rank exclusion — {"sqlstate":"23P01","constraint":"no_equal_rank_policy_assignment"}
- PASS: FULL: revisionless DRAFT row representable
- PASS: FULL: revisionless CANCELLED row representable
- PASS: FULL: revisionless EXPIRED row representable
- PASS: FULL: revisionless confirmed state rejected — {"sqlstate":"23514","constraint":"ck_booking_4"}
- PASS: FULL: draft without finite expiry rejected — {"sqlstate":"23514","constraint":"ck_booking_5"}
- PASS: FULL: live resource overlap rejected — {"sqlstate":"23P01","constraint":"no_live_resource_overlap"}
- PASS: FULL: adjacent half-open occupancy accepted
- PASS: FULL: released ledger history does not block new live interval
- PASS: FULL: separate sessions block then reject overlapping uncommitted interval — {"backendPids":[2208,2209],"observedWait":"Lock","winner":"session A committed","loser":"session B SQLSTATE 23P01"}
- PASS: FULL: real catalog has all generated and exclusion definitions; indexes valid — {"tables":72,"foreign_keys":254,"checks":250,"exclusions":4,"indexes":266,"generated":5}
