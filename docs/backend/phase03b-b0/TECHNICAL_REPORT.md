# B0 technical report — actual local execution

Approved private baseline:23c92360b8cbd87099459955c2636f041b988fc7. New branch:feature/phase03b-b0-infra. The private feature/booking-ui and feature/phase03a-architecture refs remain untouched. The public review is independently based on review/phase03a-architecture; no private commit is used as a public parent.

## Implemented environment

Independent backend/ package with NestJS12.3.2, TypeScript5.9.3, pg8.23.1, reflect-metadata0.2.2 and RxJS7.8.2. Prisma/client/adapter7.10.1 are dev-only probes. Node isv24.16.0, host npm11.17.0; container Nodev24.16.0, npm11.13.0. Docker29.5.2, Compose5.1.3. Pinned image digests are in compose.yaml/Dockerfile and environment-results.json. Prisma8 was an RC at selection; stable7.10.1 was explicitly pinned. No existing frontend dependency was upgraded.

The dedicated Compose bridge publishes PostgreSQL only127.0.0.1:55432 and API only127.0.0.1:3100. Both containers actually became healthy. API runs as UID1000 with a read-only root filesystem, dropped capabilities and no-new-privileges. Random ignored development credentials are not delivered. The health API has only a non-superuser/non-DDL role; the host validation tool has separate disposable-cluster admin credentials. API startup creates no business tables. The control database has0 application tables.

Health liveness/readiness return200 during normal operation. Outage tests keep liveness200/readiness503. Config validation rejects missing/invalid/production targets, and startup failure exits1. Centralized HTTP errors return generic codes and generated request IDs; structured JSON logs omit exception payloads, credentials and URL/query strings. No Booking/Payment/Policy Controllers or empty future domain modules exist.

## Backend folder structure

```text
backend/
  package.json + package-lock.json  independent pinned npm project
  tsconfig.json                    independent NodeNext compilation
  compose.yaml + Dockerfile        isolated local PostgreSQL / API
  .env.example                     placeholders only; actual env ignored
  src/
    main.ts / app.ts               bootstrap / AppModule
    config.ts                      validated ConfigModule DI token
    database.ts                    DatabaseModule / bounded health pool
    health.ts                      HealthModule / live + ready
    observability.ts               generic errors / JSON logs / request IDs
  scripts/
    local.mjs / infra.mjs          marked B0 environment / lifecycle guards
    validate-db.mjs                real SQL/constraint/concurrency harness
    prisma-probe.mjs               selected-version compatibility checks
    diagnostics.mjs                actual runtime identity/health checks
    check-secrets.mjs              known-value/signature/ignore checks
  test/                            config and real process/HTTP tests
  prisma/                          small explicit compatibility probe only
docs/backend/phase03b-b0/           reports, figures and sanitized evidence
```

## Actual PostgreSQL results

PostgreSQL 18.6 (Debian 18.6-1.pgdg12+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 12.2.0-14+deb12u1) 12.2.0, 64-bit

| Database/schema | Statements executed | Tables | FK | CHECK | Indexes | Generated | Exclusions |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| ms_b0_b1_test/ms_b1_design | 70 | 16 | 40 | 43 | 44 | 0 | 0 |
| ms_b0_full_test/ms_design | 423 | 72 | 254 | 250 | 266 | 5 | 4 |

The complete files were executed directly, with SHA256 recorded, and all statements succeeded. btree_gist1.8 is installed in the full database. There were zero unexpected SQL errors or DDL corrections. The B1 schema creates exactly16 dependency-closed tables and both temporary inactive gates reject activation. The runtime control database remains empty. The unchanged03A SQL files and older architecture reports retain their historical review-only/never-executed comments; this B0 report is the new execution evidence. No approved architecture file was silently rewritten and no production migration was generated.

## Actual tests

-35 PostgreSQL assertions pass,0 fail;23 deliberate SQLSTATE rejections are successful negative tests. SQLSTATE, exact parameterized failing statement, constraint/root cause and correction guidance appear in SQL_ERROR_LOG.md and database-results.json.
-14 backend tests pass: configuration, actual least-privilege connection/denied DDL, process startup, HTTP readiness/liveness/404, outage and secret-safe startup/logging.
- Prisma7.10.1 validate/generate, real72-model introspection, generated ordinary model read, raw range SQL, interactive SERIALIZABLE isolation and rollback all pass. Catalog constraints/indexes/generated expressions are unchanged by the probe. See PRISMA_COMPATIBILITY.md.
- Actual existing Next.js typecheck/build pass;92 Playwright tests pass across1440x900,1024x768,390x844,375x812. No skips/flakes/failures. Root tsconfig adds only backend to exclude; existing app/components/data/lib/tests/assets/package/lock content is preserved. Test-generated private UI artifacts were restored after collecting this run's logs/summary.
- Secret checks verify ignored local environment, known local credential values absent from selected source/docs, path allowlist and credential signatures. Public export additionally compares private binary hashes and excludes private Git objects. This is a bounded scan, not a universal proof of absence of every possible secret.

Separate PostgreSQL sessions used different backend PIDs. Session B was observed waiting on a PostgreSQL Lock while A held an uncommitted overlapping MAINTENANCE allocation. A committed; B failed23P01/no_live_resource_overlap and rolled back. Adjacent half-open intervals pass. This proves that tested exclusion arbitration, not a complete booking/hold workflow.

## Scope and unimplemented invariants

Synthetic quote rows exercise hash non-uniqueness/row shape for two different customers, not full canonical document/relational snapshot consistency or actor-owned quote APIs. Revisionless DRAFT/CANCELLED/EXPIRED row shapes are representable; command state transitions/history and plan_committed monotonicity remain unimplemented. Membership/shift/occupancy/policy routing exclusions are exercised; temporal coverage, qualifications, resource completeness, travel rules, immutable policy/quote evidence and grants are not provided by those predicates.

There is no transactional Booking Engine, authoritative availability API, hold expiry/callback race, whole-plan rollback/retry, application tenant authorization or end-to-end double-booking guarantee. No real customer/staff/financial data, real policies, prices or production seeds were used. Production roles/TLS/auth/backups/PITR/restore/load/incident controls remain future gates. No measured query performance/EXPLAIN result or security certification is claimed.

## Failed attempts and explicit resolutions

Initial internal Compose networking omitted host port bindings on this Docker Desktop host; host connections failed ECONNREFUSED and two readiness/connection assertions failed. Switching to a dedicated bridge while preserving loopback bindings resolved it. The original failed outputs are retained separately. Initial image dependency transfer failed ECONNRESET; bounded retries, lower socket concurrency, disabled audit/fund requests and a BuildKit cache completed the build. Initial host npm registry/cache transport also failed; a temporary loopback native-curl registry bridge retrieved official npm tarballs, with npm integrity verification. Delivered lockfile URLs are canonical registry.npmjs.org; the bridge and caches are not product dependencies or export artifacts. A clean host npm ci using the verified offline content cache passed. No test was weakened for these failures.

## B1 recommendations — require separate approval

Review the existing16-table B1 inventory and dependency-safe create-tables/add-FKs order only. Produce reviewed forward/restore migrations and schema-drift assertions; prove backup/restore and least-privilege config/IAM authorization before any persistent tranche. Confirm real business configuration rather than importing demo values. Preserve inactive gates until later resource/policy/admission tests. Keep mixed-service policy conflict fail-closed until the owner selects a strategy. Do not promote the72-table disposable validation into an all-at-once migration. No B1 implementation begins here.
