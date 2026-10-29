# 01 — System overview

**PROPOSED / REVIEW REQUIRED — Phase 03A specification only.** No backend, database, migration, gateway or notification service was installed or executed. The private Phase 02 frontend remains canonical and unchanged.

## Confirmed source of truth

Brand: محمد استایل. Brochure: سالن ممتاز پونک. Known address: پونک، ساختمان رونیکا پالاس، لابی. Instagram: @mohammadstyle1. Two branches are active as a business fact, but only one address is confirmed; booking configuration for branch two is unknown. The owner personally performs most services in one branch, without implying a staff record, name, schedule or exclusive eligibility.

The confirmed catalog is exactly: استایل دامادی، هیرکات مو، فیشیال صورت، ماساژ، مانیکور، پدیکور. Prices, durations, staff roster, shifts, resource counts, phone numbers and deposit/cancellation conditions remain unconfirmed. Empty configuration must disable real booking, never infer zero, a default schedule or a production tariff from the demo.

## Proposed runtime structure and responsibilities

| Technology | Responsibility | Boundary |
| --- | --- | --- |
| Existing Next.js/React/TypeScript | Marketing and booking presentation; same-origin API adapter; Jalali display | Never authoritative for eligibility, capacity, money or accepted terms |
| NestJS modular monolith | Typed commands/queries, permission checks, transaction orchestration | One deployable API; domain modules export narrow ports, not their tables |
| PostgreSQL 18 proposal | Durable business state, resource overlap constraints, quotes/consent, ledger/outbox | Final authority; no Redis lock substitutes; exact patch/support policy chosen before 03B |
| Prisma | Ordinary repositories and typed transaction client | Raw parameterized SQL for ranges/exclusion/locking where required; hand-reviewed migrations later |
| Redis + BullMQ | Cache and resumable background dispatch | At-least-once jobs; never sole hold/payment/capacity truth |
| S3-compatible storage | Private uploads/originals, consent evidence and approved derivatives | Buckets are private by default; metadata/rights remain in PostgreSQL |
| Docker | Separate web/API/worker images and reproducible deployment | No Docker service or backend scaffold created now |
| Nginx | TLS/same-origin routing, request limits, proxy hygiene | Public browser reaches web/API only; no direct PostgreSQL/Redis access |

Nest modules provide encapsulation and exported provider boundaries ([Nest module documentation](https://docs.nestjs.com/modules)). This design additionally forbids cross-module repository access. Features use a shared transaction context passed by application workflows; committing is the outer command's responsibility.

## Topology and failure domains

Browser → Nginx → Next.js or /api/v1 Nest API. A worker process uses the same module code/version, PostgreSQL and Redis. PostgreSQL, Redis and storage endpoints remain private network services. External payment/SMS/bot providers are adapters at the edge. No provider call is made while database row locks are held. Unavailable Redis reduces throughput, not correctness: PostgreSQL outbox/expiry recovery remain durable. Unavailable gateway yields pending/unknown payment, never invented success. Unavailable storage blocks media processing/publication.

API instances are stateless except bounded connections; sessions are durable hashed tokens. Connection budgets include web, workers, maintenance and migrations; a transaction-aware pool configuration must be proven with Prisma and locks before rollout. Migrations use a separate deployment role and are not run on application startup. Health probes distinguish process liveness from DB/worker readiness without returning credentials.

## Production controls to approve before implementation

Pin supported stable dependency versions and images; PostgreSQL 19 is not assumed merely because documentation mentions a release candidate. Resolve existing Next/PostCSS audit findings separately without silently upgrading the approved frontend here. TLS, secret mounts, least-privilege roles, encrypted backups/PITR, restoration drills, object lifecycle and queue persistence require environment-specific runbooks. Proposed recovery targets (not achieved service levels) are RPO ≤5 minutes and RTO ≤60 minutes, subject to owner/cost review. No real deployment or recovery test is claimed.

## First production capability boundary

The first booking MVP uses one provider for all services, sequential execution, branch-specific offerings and identified unit-capacity resources. Packages, parallel execution, bots, marketing, advanced CRM/reporting and full media CMS can follow. Financial endpoints stay disabled until merchant credentials, policy legality, reconciliation and compensation tests are approved. Public real bookings stay disabled until actual branch/staff/schedule/service/policy configuration is verified.
