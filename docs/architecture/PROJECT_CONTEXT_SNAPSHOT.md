# Project context — Mohammad Style

Current task: **Phase03A architecture/specification only**, explicitly authorized2026-10-29. Architecture approval is pending. No03B backend implementation is authorized. The original private source and approved Homepage/Booking presentation remain unchanged.

## Confirmed business facts

- Brand: محمد استایل. Brochure title: سالن ممتاز پونک.
- Confirmed address: پونک، ساختمان رونیکا پالاس، لابی. Instagram: @mohammadstyle1.
- Two active business branches; owner personally performs most services in one branch. This fact does not supply a roster, shifts or branch-two booking readiness.
- Exactly six brochure services: استایل دامادی، هیرکات مو، فیشیال صورت، ماساژ، مانیکور، پدیکور.
- Existing client imagery is approved for internal review only. Public rights/private font redistribution remain unconfirmed.

## Existing source and preservation

Original private feature/booking-ui remains at2155872cc626d7463d94500b678d875bec0e4dc6. Phase03A branches from that commit as feature/phase03a-architecture. No application/dependency/test/asset changes are included. Phase02 retains its five-step demo-only Booking flow, reducer-owned validated availability, branch offerings, scoped policy preview and single-provider behavior. Historical Phase02 build/typecheck/92 Playwright checks are recorded in its own reports, not claimed as backend tests here.

Original user sources/prior context remain private and are omitted from this sanitized export. They are source material, excluded from the public export. Numbered architecture docs, SQL/model, OpenAPI, ADRs and diagrams are derived proposals. data/business-facts.json remains unchanged. Demo fixtures are not production seeds.

## Architecture decisions — proposed, pending review

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

All backend services/migrations/API implementation/real reservations/payments/messaging. Also packages, parallel/multi-provider scheduling, advanced CRM/accounting/analytics, paid reschedule financial saga and bot/marketing/content tranches until their gates are met. Existing frontend integration needs an explicitly reviewed SERVER-source contract; never disguise real data as demo.

## Open questions

Real branch-two details, staff identities/branch days, prices/durations/buffers/resources, hours/closures, hold TTL/horizon/lead time, deposit/cancellation/no-show/legal rules, merchant/gateway units, auth/recovery/MFA, consent/retention/data residency, cross-branch travel and parallel-service feasibility. Unknown values remain unknown and block public bookability.

## Completed deliverables

Phase03A specifications/ERD/SQL/OpenAPI/ADRs/visual review package and actual static parser/model/DAG/schema/render checks. No database was used or migrated. Source/ref guards preserve the original feature branch and all frontend/test files. A separately sanitized public architecture branch is based on the existing public Phase02 branch, with its own draft PR targeting that branch; PR1/main are preserved, never merged.

## Known risks

Static syntax/schema validation does not prove runtime constraints, transaction races, performance or authorization. Mandatory cross-row immutability/coverage/consent/financial command and grant/trigger gates are specified for03B. Actual provider idempotency/status capabilities, legal enforceability, privacy retention and restoration need review. Prior frontend dependency audit findings remain documented; no unrelated upgrades were made.

## Change log

- 2026-10-28: Existing cinematic Homepage refined and reviewed; original visual direction retained.
- 2026-10-29: Explicit Phase02 authorization; five-step demo Booking UI and private review fixes completed. feature/booking-ui baseline2155872 retained.
- 2026-10-29: Explicit Phase03A authorization; documentation branch created from verified baseline. Architecture and safe public-review export prepared. No03B implementation started; architecture review/approval is the next gate.


## Phase03A architecture hardening —2026-10-29

Review baseline ab62e845bcbf7c351c29c6d77078d3bcfb97793a retained. Quote content hash V2 is non-unique and exactly specified; request idempotency/ownership are separate. Temporal membership periods preserve leave/rejoin history. Monotonic plan_committed distinguishes persisted revisionless draft aborts from admitted terminal bookings. Index inventory removes blind actor/helper indexes and defers15 query candidates. B1 is16 dependency-closed inactive foundation tables. Mixed-service policy strategy remains owner-undecided with fail-closed conflict handling. Full ERD is preserved; context ERDs/module/sequence diagrams improve review readability. No frontend/asset/test changes or03B implementation; architecture approval pending.
