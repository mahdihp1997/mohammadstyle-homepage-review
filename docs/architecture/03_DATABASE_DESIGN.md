# 03 — PostgreSQL database design

**PROPOSED / REVIEW REQUIRED — Phase 03A specification only.** No backend, database, migration, gateway or notification service was installed or executed. The private Phase 02 frontend remains canonical and unchanged.

## Authoritative artifacts and inventory

The complete proposed inventory is schema/model.json (72 tables), schema/TABLE_DICTIONARY.md (every column/type/null/default/key/check/owner/lifecycle), and schema/draft-postgresql.sql (all DDL, constraints and indexes). The DOT/SVG ERD includes every entity and all254 foreign-key relationships. Shared business tenancy and created_by edges are dashed/light; the optional Mermaid summary omits these common edges for readability. All business columns appear in the DOT ERD; shared audit columns are omitted visually only and remain in the complete dictionary/model/DDL. SQL is a draft specification, not an executable migration delivered to a database.

## Tenant and aggregate identity

UUID PKs are globally unique; business-owned tables also expose UNIQUE(business_id,id) for composite FKs. Child relationships carry business_id so a valid foreign UUID from another business cannot accidentally satisfy a reference. Offering/qualification/assignment joins additionally bind staff, branch and service IDs; booking items bind quote items to the same quote/revision. Actor identities are global IAM IDs: role/resource authorization still checks the business and branch, rather than equating an FK with permission.

All FK deletes are RESTRICT. Business deactivation archives configuration, never cascades through reservations, accepted terms or receipts. Optional links are genuinely nullable, and local checks require all relevant link columns when an allocation kind needs them. The cyclic booking.active_revision_id relation is initially deferred so root, revision and active pointer can be created in one transaction; the pointer must identify a revision of that same booking.

## Important consolidations and separations

- A single resource entity represents STAFF globally within a business, or a physical CHAIR/ROOM/DEVICE in one branch. Staff has a one-to-one STAFF resource FK. There is no duplicate staff identity per branch.
- ResourceAllocation is the scheduling ledger for holds, bookings, time off, closures and maintenance. Holds are durable booking state plus expiry, not an unrelated Redis reservation system.
- Service is global metadata; BranchServiceOffering is the commercial/time configuration; StaffServiceEligibility is qualification; StaffBranchAssignment is membership; OfferingStaffEligibility is explicit branch-service assignment; rules/shifts/time off determine actual availability. None substitutes for the others.
- Recurring rules are local-date/weekday instructions. Published StaffShift rows are authoritative UTC intervals for the searchable horizon; there is no naive cross-timezone weekly overlap comparison.
- BookingRevision preserves rescheduling plans; BookingItem references immutable QuoteItem facts; BookingServiceSegment models execution. SegmentResourceAssignment links each segment to a coalesced per-resource ledger interval, avoiding self-conflicts between adjacent buffers.
- QuotePolicyResolution/Source, PolicyVersion/Assignment and BookingPolicyAcceptance have distinct lifecycles. PaymentIntent, verified Transaction, Application, Balance, Refund and FinancialAuditRecord separate workflow, actual money, credited money, locked refund budget and audit evidence.
- NotificationEvent is the scheduled business delivery; attempts are individual provider submissions; Outbox and Inbox are durable transport/consumer coordination, not notifications themselves.
- Reporting is read-only views/projections, not an unnecessary table for each metric. Packages/tags/bot linking are explicitly later.

## Types, indexing and interval rules

All appointment instants use timestamptz, with an explicit IANA branch timezone retained for interpretation. Local business rules use date/weekday/minute-of-day. PostgreSQL does not retain an original timezone name inside timestamptz; retain it separately ([date/time types](https://www.postgresql.org/docs/18/datatype-datetime.html)). Ranges are half-open [start,end); ends must exceed starts. Staff/resource periods must be finite in application validation before persistence. Overnight rules are split into two local-day entries; DST gaps/ambiguities are rejected or explicitly resolved by approved rules, never guessed from the browser offset.

PostgreSQL range overlap and GiST exclusion can reject conflicting intervals ([range types](https://www.postgresql.org/docs/18/rangetypes.html)). The central exclusion is (resource_id =, busy_period &&) WHERE released_at IS NULL. Staff shifts have a separate global staff/time exclusion across branches. Both operate without branch_id in the overlap identity. Do not put now() in a partial predicate: expired holds remain blocking until an expiry/reclaim transaction releases them. Safety wins over a stale slot appearing free.

PK/unique indexes support identity/configuration lookup; generated FK indexes cover referencing deletes/joins unless a left-prefix key already covers them. Booking indexes serve branch/status calendar and customer history. Active allocation indexes serve current-plan reads; GiST serves overlap. Holds index active expires_at; outbox indexes unpublished available_at; notifications index scheduled_at only while scheduled. Consent indexes asset/scope/revocation; public portfolio indexes status/sort. No speculative JSONB GIN indexes or duplicate universal btree indexes. Real query plans/cardinality/load need EXPLAIN and integration tests in 03B; no performance results are claimed now.

## JSONB exceptions

Relational columns model services/staff/prices/scopes/windows/allocations and financial amounts. JSONB is limited to immutable resolved/accepted policy artifacts and hashes, versioned outbox envelopes, redacted provider metadata, bounded idempotent response receipts, template parameter envelopes and redacted audit changes. They are evidence/envelopes, not alternate writable sources of structured domain facts. No PAN/CVV, bearer tokens, raw bot credentials or unnecessary customer PII belongs in these blobs. Policy source assignments and refund windows remain relational even though the accepted artifact is a snapshot.

## Lifecycle and required enforcement beyond local DDL

| Concern | Draft SQL enforces | Mandatory application/DB hardening before production |
| --- | --- | --- |
| Tenant/reference identity | Composite FKs/unique keys, RESTRICT | Object/branch authorization; no caller business_id trust |
| Double booking | Global active-resource GiST exclusion | Fresh schedule/eligibility checks under consistent locks; include all resources/buffers |
| Cross-branch shifts | Staff/time exclusion | Materialize recurrence horizon; validate assignment/local timezone; travel rule approval |
| Active offering | Non-null known amounts/times/buffers and confirmed resource config | Branch readiness, qualification validity, required-resource counts |
| Plan and allocation consistency | Same-revision/item/resource FKs, positive intervals | Segment containment, complete staff/resource coverage, acyclic dependencies, coalescing and single-provider/sequential MVP guard |
| Holds | One active hold per booking, expiry shape | Expiry/confirmation lock race; release every allocation; DB time at transition |
| Policy versions | Scope shape, scalar bounds, same-rank routing exclusion | Content/refund-window immutability after publication, effective-date consistency, permissioned overrides, full snapshot/hash matching |
| Status history | State vocabulary/allowed history edges | Audited command transition, exactly matching history/outbox, immutable prior history; revoke direct uncontrolled writes |
| Financial integrity | Money/checks, unique provider receipts, refund balance ceiling | Verified amounts/unit/merchant, reserved-balance+refund atomic writes, acceptance/quote ownership, append-only receipt/ledger grants |
| Media consent | Publication metadata shape, scope FK records | Atomic publication gate verifies every subject's WEBSITE consent; revocation unpublishes all uses and invalidates caches |
| Immutability | Append-oriented schema/lifecycle intent | Explicit GRANT/REVOKE and content-guard triggers for frozen quote/terms/receipt/history fields; audited workflow columns only |

Cross-row rules are not falsely expressed as CHECK subqueries. PostgreSQL CHECK constraints do not provide cross-table integrity ([constraint documentation](https://www.postgresql.org/docs/18/ddl-constraints.html)). Those gates must receive actual constraint-trigger/transaction integration tests before production; this draft deliberately does not pretend that static parse proves them.

Config rows have created/updated/version/archive metadata; evidence rows preserve created/actor data and immutable payloads. Published/consumed/revoked timestamps are audited workflow metadata, not permission to edit accepted content. Retention periods are unresolved legal/business inputs: sessions/challenges expire quickly by approved configuration; idempotency/inbox records survive the recovery horizon; financial/consent/audit evidence follows approved retention; customers are redacted only after lawful retention review. Backups and object derivatives participate in erasure/retention runbooks.

Prisma models ordinary relations; range/generated/exclusion or other unsupported features require reviewed SQL migrations later, schema-drift checks and explicit repository methods, not db push. See [Prisma unsupported features](https://www.prisma.io/docs/orm/v7/prisma-migrate/workflows/unsupported-database-features). No Prisma service, migration or database was installed or run in 03A.
