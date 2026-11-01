# Current task: final product development — 2026-11-01

Private feature: feature/product-finalization. The approved MVP (d3896a9168738aff4a780dcbbe11696c819c901e plus owner-authorized logo/local-review-login changes through9c9c3156e81f272ae114f1b6265c19be9b0b4e0d) remains intact in its original checkout. This separate worktree contains production-capable customer OTP/accounts, password/MFA/recovery, DB-backed sessions, the approved server Booking UI, exact-Rial independently verified payment/refund boundaries, durable SMS delivery, administration and rights-gated CMS. No live payment/SMS or public deployment is performed. The unselected live gateway remains explicitly unconfigured.

Original migrations0001–0015 and existing tests are preserved. Product registry currently ends0040. Runtime has exact realm/head/provider/provenance checks and separate auth/API/worker/operator secrets. Next cookies/CSRF and a private bridge replace the development cookie issuer only in explicit product mode. DEMO stays separate for isolated review. Original private image/font/reference files remain internal; production packages physically contain only approved branding and code. Public CMS content requires current explicit rights/publication. The native editable SVG is derived from the owner-approved mark, not a complete identity-board screenshot.

Current docs: [product architecture](product/ARCHITECTURE.md), [deployment/recovery runbook](product/RUNBOOK.md), [validation](product/VALIDATION.md), [review report](product/REPORT.md). Local product test URL uses127.0.0.1:3006; separate production-Node staging validation uses HTTPS localhost:3446 and a dedicated PostgreSQL volume. Both are local review environments. No real staff/prices/hours/commercial rules or second-branch details were seeded.

Original B0–B4/MVP regression suites, four-size Homepage/DEMO92, management/CMS23, prior-login11 and SERVER12 browser tests were executed in isolated profiles. New actual PostgreSQL/HTTP/Chromium tests cover canonical identity, MFA/optional policy, recovery, capacity/expiry, payment duplication/failure/late/proof mismatch, notifications, scoped operations and encrypted restore. Exact final results are in VALIDATION.md. Parser/static analysis is not presented as database execution. Remaining prerequisites are genuine owner business/media configuration, provider/hosting credentials and final production acceptance. A new independent sanitized Draft PR is prepared against public review/mvp-admin-portfolio; no previous PR is merged or private history imported.

Earlier phase STOP instructions and snapshots below describe historical scope; the final-product task explicitly authorizes the implementation above.

---

## Latest task: MVP integration — 2026-10-30

Original private branch `feature/mvp-admin-portfolio` from approved B4 `a278995fdafde1f6a78738908866e7cd09d1a732`. Nine RTL admin workspaces, scoped original APIs, local/S3 portfolio CMS, explicit rights/publication, safe ZIP/native video and isolated SERVER integration are implemented. All original Homepage/Booking/DEMO/assets/facts/0001–0014 and seven original databases preserved. Actual PostgreSQL upgrade/rollback/55-table separate restore and 133-object local media restore pass. Typecheck/build pass; 41 integration +5 schema +7 SDK protocol cases; original B0–B4 regressions; 23 MVP +92 Homepage/DEMO +12 SERVER browser cases pass, no failures/flaky. Live S3 provider/production authentication/commercial configuration/rights evidence remain gates. No payment/SMS/scraping/deployment or PR merge. See `docs/backend/mvp-integration/README.md`. Public review must be independent on sanitized B4; stop for owner review. Earlier sections below are historical phase snapshots.

# Current B3 pricing/policy status

Explicitly authorized after B2H base a3612dd. B3 configurable integer-Rial pricing/versioned policy engine, immutable dependency-safe commercial proposals, strict conflict/authorization/idempotency/CAS/audit/outbox. Final MS_QUOTE_CONTENT_V2 plan/acceptance binding remains disabled until B4; no fake booking/plan/FK or salon price/rule. New0010/0011,38tables;78 actual PostgreSQL/Nest tests PASS and all42/71/69/83/47/14/35/Prisma/92frontend regressions PASS. Original0001–0009/data/UI/assets/tests/old refs preserved. See docs/backend/phase03b-b3/. Stop for B3 approval; no B4/payment/deployment/notifications/CMS.

Earlier phase records retain their historical scope/evidence.

# Current B2B read-scope hardening

Targeted0009 closes historical-membership/global-timeoff disclosure; interval clipping uses branch IANA half-open bounds. Current calendar published/nonarchived only; explicit permissioned history with evidence states. Related global metadata/legacy staff-ID leakage tightened. Hardened startup requires nine-version isolated profile; old databases/migrations/evidence/tests preserved.

42 targeted tests pass; unchanged71/69/83/47/14/35/Prisma and92 frontend pass. Actual migration/restore/concurrency verified. Same Draft PR7, no private assets/history, no merge. No B3/B4.

Earlier phase records below retain historical scope/evidence.

# Current B2B status — explicitly authorized after B2A approval

Approved B2A private baseline33b8934; B2B authenticated administrative workforce calendar implemented for isolated review.30 new operations,28 tables, verified opaque-session/permission scope, bounded IANA materialization, full membership/capability/opening/exception checks, explicit immutable exception successors, reviewed plan corrections, unknown travel blocked, business gate/CAS/audit/outbox/idempotency.

69 actual B2B tests pass/8 real races; original69/83/47/14/35/Prisma regressions pass. Frontend remains unchanged/disconnected; actual frontend run recorded separately. No real branch/staff/hours facts invented. Bookability gates remain; no customer slots/holds/bookings/payments/notifications/CMS/deployment. STOP for B2B approval.

The following B2A/B1B/B1A/B0/architecture records retain historical scope/evidence.

# Current B2A status — authorized after B1B review

Phase03B-B2A adds11 approved dependency-closed workforce/scheduling tables using0004/0005 on feature/phase03b-b2a-workforce-schema from2477f3bf369acf8fa73dc896c9479ccaa52235ec. New isolated PostgreSQL55438 only; original B0/B1A/B1B DBs, evidence and branches remain preserved.27 tables include global STAFF resources, period memberships/qualifications/offering eligibility, local recurrence, published shifts/time-off/closures/physical resources/config. Native generated ranges and two exclusions prevent tested membership/global staff-shift overlaps. History/identity/exact-version/IANA guards added without new API grants.69 B2A tests/100 expected SQL rejections/3 actual lock-wait races pass; prior83/47/14/35/Prisma and92 frontend tests pass. Existing migration0001–0003, application session/admin code, Homepage/Booking and private assets remain unchanged. No B2B API, availability materializer/booking/hold/allocation/payment/notification/CMS/deployment. Cross-row containment, exception reconciliation, travel/DST/publication workflows remain explicit B2B gates. See docs/backend/phase03b-b2a/. STOP for B2A approval.

The following B1B/B1A/B0/architecture records retain their historical scope/evidence.

# Current B1B status — explicitly authorized after B1A approval

Phase03B-B1B is implemented for isolated review on feature/phase03b-b1b-admin-api from045a013c0f096f6124758bd66ec3b53ffad2b3df. Twelve Nest admin/session operations use verified opaque session evidence, explicit current permission+branch scope,3 EXECUTE-only DB entry points and atomic config/audit/outbox/idempotency/version commands. New isolated PostgreSQL55436 environment; no original B0/B1A reset.0001/0002 and legacy grants preserved,0003 adds bound-session fields/functions;16 tables and inactive gates remain. Actual83 B1B tests plus47 B1A and14+35+Prisma B0 regressions pass; frontend actual results are in the B1B report. Homepage/Booking/assets/demo remain unchanged and disconnected. Production auth/MFA/recovery/HTTPS/rate distribution and real business configuration are unresolved; no booking engine/payment/notification/deployment. Stop for B1B approval. See docs/backend/phase03b-b1b/.

The following sections are historical B1A/B0/03A records; their earlier deferral statements describe those phases, not current B1B scope.

# Project context — Mohammad Style

Current task: **Phase03B-B1A persistence foundation**, explicitly authorized after technical approval of B0 commit7a51ae6ad2dde941e263d8b781cd0c52ba9bc213. Work is on feature/phase03b-b1a-persistence from that exact baseline. Only B1-A is authorized; B1-B, production authentication/deployment, operational booking, payments and notifications remain disabled. Homepage/Booking and frontend source/assets/tests/dependencies remain unchanged. B0 API/default environment are preserved.

## Confirmed B1A implementation and evidence

- Separate PostgreSQL18.6 Compose project mohammadstyle-b1a, loopback55434, its own volume/control database and random ignored admin/migrator/runtime credentials. Original B0 databases/volume remain intact. Guarded lifecycle operations accept only marked ms_b1a_dev/ms_b1a_failure/ms_b1a_restore databases and verify identity/owner before recreation.
- Two reviewed versioned native SQL migrations create exactly16 approved B1 domain tables,40 FK,43 CHECK,44 indexes; the second adds four tenant-context RLS policies and limited configuration-read/version-metadata grants. Both inactive gates, audit fields and optimistic-version fields remain. Migration tracking is one separate metadata table, not an extra domain table. Checksummed registry, transaction-scoped advisory lock, atomic version recording, verified no-op reruns and catalog drift checks are implemented. API startup never migrates.
- Explicit opt-in Nest PersistenceModule, shared transaction scope, four typed read repository ports and metadata-only CAS writer are prepared. Existing health AppModule does not import them. No configuration or customer-facing business controller exists. Tenant context is not authentication; verified identity/permissions and real write commands require B1-B review.
-47 actual B1A integration assertions pass, including30 expected SQL/application rejections; simultaneous migrators apply versions once, two runtime writers yield one CAS winner, failed transactions/migrations roll back, invalid history/checksums/drift/unauthorized operations fail closed.
- Actual pg_dump custom backup and pg_restore into a separate database succeed. All21 synthetic/tracking rows,16 domain tables, constraints/indexes/RLS/effective permissions match; no source overwrite. Default ACLs are normalized to effective privileges after a real restore exposed explicit-versus-implicit owner ACL representation. Failed attempts and fixes remain documented.
- All existing14 B0 backend tests,35 SQL assertions and Prisma7.10.1 compatibility checks pass in a separate tmpfs regression clone55435; no original B0 reset. Default B0 helper behavior remains55432; a strictly selected test-only profile redirects regression connections/results. Frontend typecheck/build and all92 Playwright tests pass. Private UI screenshots stay private; generated tracked review artifacts are restored after collecting this run's summary.
- GitHub Actions workflow is prepared for the sanitized public review repository only, with pinned actions, source guards, read-only token permissions, disposable clusters and a result-JSON-only artifact allowlist. Remote run status is reported separately from local results.
- See docs/backend/phase03b-b1a/ and backend/B1A.md for migrations, exact commands, security limits, backup/restore and B1-B readiness. Existing B0/03A reports below retain their historical evidence boundaries.

Remaining B1-B gates: authenticate/authorize tenant and branch context, reviewed configuration commands/field permissions/audit, production grants and immutable evidence guards, drift/upgrade/recovery operations, real business facts. RLS does not protect against a compromised runtime credential selecting another context; row_version CHECK alone does not enforce CAS. No operational booking/payment/notification or production readiness is claimed.

## Confirmed B0 implementation and evidence

- Independent backend/ npm project: NestJS12.3.2, TypeScript5.9.3, pg8.23.1; Node24.16.0. ConfigModule, DatabaseModule and HealthModule only; no empty domain modules or business controllers.
- Isolated Docker Compose project mohammadstyle-b0 with pinned PostgreSQL18.6 and Node24.16.0 image digests, explicit loopback host bindings55432/3100, non-root API and a separate non-DDL health role. Random local credentials are ignored and withheld. No app tables are installed in the runtime control DB.
- Approved SQL files remain byte-for-byte baseline content. Actual PostgreSQL execution created16 B1 tables/40FK/43CHECK/44indexes and72 full-draft tables/254FK/250CHECK/266indexes/5generated/4exclusions in separate disposable databases. No unexpected DDL error; this is not a production migration.
-35 real database assertions pass, including23 deliberate SQLSTATE rejections and a separate-session observed lock wait/23P01 exclusion conflict.14 backend config/startup/health/security tests pass. Prisma7.10.1 validate/generate/introspect/client/transaction probe passes; Prisma is dev-only, not the health runtime repository.
- Existing frontend typecheck/build and all92 Playwright tests pass after the root tsconfig boundary change. Private generated UI screenshots remain private and are not exported; tracked previous review artifacts were restored after collecting this run's summary.
- First internal-network host-connection attempt failed because this Docker host omitted port bindings; the dedicated bridge with explicit127.0.0.1 bindings is verified. An initial image build hit a registry ECONNRESET; cached, bounded retry settings resolved it. Failed attempts remain recorded separately.
- Detailed current results, limitations, commands and lightweight visual package: docs/backend/phase03b-b0/. The following older Phase03A sections/documents describe their historical specification-only state; their old NOT RUN labels are not B0 results.

Remaining gates: no operational Booking Engine, application tenant authorization, cross-row immutability/coverage/monotonicity guards, merchant or real policy configuration, production grants/TLS/backups/PITR/restore/load/security tests. SQL predicates do not prove end-to-end double-booking protection. Mixed-service policy choice remains owner-undecided and fail-closed.

## Confirmed business facts

- Brand: محمد استایل. Brochure title: سالن ممتاز پونک.
- Confirmed address: پونک، ساختمان رونیکا پالاس، لابی. Instagram: @mohammadstyle1.
- Two active business branches; owner personally performs most services in one branch. This fact does not supply a roster, shifts or branch-two booking readiness.
- Exactly six brochure services: استایل دامادی، هیرکات مو، فیشیال صورت، ماساژ، مانیکور، پدیکور.
- Existing client imagery is approved for internal review only. Public rights/private font redistribution remain unconfirmed.

## Existing source and preservation

Original private feature/booking-ui remains at2155872cc626d7463d94500b678d875bec0e4dc6. Phase03A branches from that commit as feature/phase03a-architecture. No application/dependency/test/asset changes are included. Phase02 retains its five-step demo-only Booking flow, reducer-owned validated availability, branch offerings, scoped policy preview and single-provider behavior. Historical Phase02 build/typecheck/92 Playwright checks are recorded in its own reports, not claimed as backend tests here.

The original user request and prior context are retained in docs/architecture/sources/. They are source material, excluded from the public export. Numbered architecture docs, SQL/model, OpenAPI, ADRs and diagrams are derived proposals. data/business-facts.json remains unchanged. Demo fixtures are not production seeds.

## Approved Phase03A design baseline — historical specification

- NestJS/TypeScript modular monolith:16 domain contexts plus outer workflows, acyclic public-port dependencies.
- PostgreSQL authority, Prisma for ordinary access and reviewed SQL for global resource exclusion/locking; no Redis-only capacity.
- Immutable server whole plan, quote, accepted policy snapshot and booking revision; short SERIALIZABLE admission transactions, canonical locks, DB-clock expiry, idempotency and durable outbox/inbox.
- Branch offerings separate global service metadata, qualification, membership, published schedules and physical resources. One provider/sequential MVP, later segment-specific whole-plan providers.
- Deterministic configurable versioned policy precedence, explicit conflicts and no silent retroactive changes. Integer versioned Rial storage/API strings with checked Toman adapter is proposed and needs merchant/owner unit confirmation.
- Verified capture separate from booking application; unapplied late money compensated; locked partial-refund budgets. Provider operations outside database locks.
- Scoped opaque sessions, branch/resource permissions and least-data projections; private-first media/subject consent; user-initiated bot linking and consented notification adapters.

## Assumptions

One business initially; schema includes explicit business ownership to prevent accidental cross-context references. Resource capacity is represented by identified units. Gregorian instants/local dates and IANA timezone are domain data; Jalali remains presentation. Exact dependency versions, authentication provider, runtime costs and recovery targets require03B environment validation.

## Proposed solutions

See docs/architecture/00_README.md for11 technical specifications,72-table target envelope, full column dictionary/review-only SQL,71 proposed REST operations,19 proposed ADRs,29 future acceptance scenarios and actual complete/context rendered diagrams and static-validation evidence. This breadth is an envelope for staged implementation, not an instruction to build every table at once.

## Deferred features

All operational backend services, production migrations, business API implementation, real reservations/payments/messaging remain deferred; only the B0 foundation/diagnostics and disposable SQL tests are now implemented. Also packages, parallel/multi-provider scheduling, advanced CRM/accounting/analytics, paid reschedule financial saga and bot/marketing/content tranches remain gated. Existing frontend integration needs an explicitly reviewed SERVER-source contract; never disguise real data as demo.

## Open questions

Real branch-two details, staff identities/branch days, prices/durations/buffers/resources, hours/closures, hold TTL/horizon/lead time, deposit/cancellation/no-show/legal rules, merchant/gateway units, auth/recovery/MFA, consent/retention/data residency, cross-branch travel and parallel-service feasibility. Unknown values remain unknown and block public bookability.

## Completed deliverables

Phase03A specifications/ERD/SQL/OpenAPI/ADRs/visual review package and actual static parser/model/DAG/schema/render checks. No database was used or migrated. Source/ref guards preserve the original feature branch and all frontend/test files. A separately sanitized public architecture branch is based on the existing public Phase02 branch, with its own draft PR targeting that branch; PR1/main are preserved, never merged.

## Known risks

Static syntax/schema validation does not prove runtime constraints, transaction races, performance or authorization. Mandatory cross-row immutability/coverage/consent/financial command and grant/trigger gates are specified for03B. Actual provider idempotency/status capabilities, legal enforceability, privacy retention and restoration need review. Prior frontend dependency audit findings remain documented; no unrelated upgrades were made.

## Change log

- 2026-10-29: B0 technically approved; B1-A explicitly authorized from7a51ae6. Added isolated16-table migrations/runtime boundaries,47 integration assertions, actual separate-database backup/restore, preserved B0 regression in tmpfs and92 frontend checks. Safe public B1A review/CI prepared; stop for B1-A approval before B1-B.

- 2026-10-29: Owner approved Phase03A baseline23c9236 and explicitly authorized B0 only. Created feature/phase03b-b0-infra; implemented independent Nest/Compose foundation, actual16/72-table disposable execution,35 SQL assertions,14 backend tests and Prisma7.10.1 compatibility probe; frontend regression92passed. Prepare sanitized separate Draft PR and stop for B0 approval before B1.

- 2026-10-28: Existing cinematic Homepage refined and reviewed; original visual direction retained.
- 2026-10-29: Explicit Phase02 authorization; five-step demo Booking UI and private review fixes completed. feature/booking-ui baseline2155872 retained.
- 2026-10-29: Explicit Phase03A authorization; documentation branch created from verified baseline. Architecture and safe public-review export prepared. No03B implementation started; architecture review/approval is the next gate.


## Phase03A architecture hardening —2026-10-29

Review baseline ab62e845bcbf7c351c29c6d77078d3bcfb97793a retained. Quote content hash V2 is non-unique and exactly specified; request idempotency/ownership are separate. Temporal membership periods preserve leave/rejoin history. Monotonic plan_committed distinguishes persisted revisionless draft aborts from admitted terminal bookings. Index inventory removes blind actor/helper indexes and defers15 query candidates. B1 is16 dependency-closed inactive foundation tables. Mixed-service policy strategy remains owner-undecided with fail-closed conflict handling. Full ERD is preserved; context ERDs/module/sequence diagrams improve review readability. No frontend/asset/test changes or03B implementation; architecture approval pending.

## PHASE03B-B4 — isolated real booking engine

Branch feature/phase03b-b4-booking from e74bec2fd6a08f280070d02ecb0ea9d7a2ec4070. Real verified isolated booking flow, V2 quotes, explicit policy consent, native GiST allocations, expiring holds, eligible confirmation, cancellation/rescheduling/history and feature-flagged SERVER UI implemented. Original Homepage/DEMO/assets/0001–0011/old databases preserved.14 migrations/50 tables;58 current DB/Nest +prior regressions +92 existing UI +12 SERVER UI pass. See docs/backend/phase03b-b4/TECHNICAL_REPORT.md and OPEN_DECISIONS.md. Production auth/configuration/payment/messaging/deployment remain closed. Export review/phase03b-b4 independently on public B3 ancestry; keep PRs1–8 unchanged and all PRs unmerged. Stop after B4 for review.
