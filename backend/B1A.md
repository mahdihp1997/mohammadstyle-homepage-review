# B1A persistence foundation — isolated local environment

B0 is approved as the baseline. This tranche adds reviewed migrations for exactly16 B1 foundation tables, restricted repository/transaction boundaries and executable backup/restore checks. Production authentication, configuration APIs, operational booking/payment/messaging and deployment remain disabled. The existing B0 AppModule does not import PersistenceModule or run migrations.

## Start and validate

From the existing project root, use Node24.16.x/Docker Linux containers:

```powershell
Set-Location backend
npm ci --ignore-scripts --no-audit --no-fund
npm run b1a:env
npm run b1a:up
npm run typecheck
npm run build
npm run b1a:migrate
npm run b1a:migrate
npm run b1a:verify
npm run test:b1a
npm run test:b0:isolated
npm run check:secrets
```

The second migration invocation is a verified no-op. `test:b1a` explicitly recreates only its marked disposable B1A databases and fills them with synthetic fixtures. It is not a seed or a production command. Exact database names are ms_b1a_dev, ms_b1a_failure and ms_b1a_restore. The separate project mohammadstyle-b1a owns only its own PostgreSQL18.6 container/volume, published at127.0.0.1:55434. The original B0 project/volume/databases stay intact. B1A admin/migration/runtime credentials are independently random and ignored in .env.b1a.local; example configuration contains placeholders only.

`b1a:up` provisions roles/database only. It applies no application migration. The admin role is used solely for this cluster's role/database lifecycle; ms_b1a_migrator is a non-superuser/non-CREATEDB/non-CREATEROLE/non-BYPASSRLS login and owns only the disposable B1A databases. ms_b1a_runtime has no membership in it. Destructive provisioning checks the exact allowlist, host/port configuration, control identity/marker and target database owner/marker. It never uses DROP DATABASE FORCE, kills sessions, resets a volume or runs global prune.

## Reviewed migration path

-0001_b1_foundation.sql copies the approved16-table B1 DDL after replacing its historical header. Table definitions,40 FKs,43 CHECKs,44 indexes, audit/version fields and both inactive gates are unchanged. All tables are created before FK creation, including the self actor reference.
-0002_b1a_runtime_boundary.sql grants only four configuration read surfaces, column-limited version/timestamp updates, and tenant-context RLS. It adds no domain tables or business workflow. IAM, audit, idempotency, outbox/inbox and migration metadata remain inaccessible to runtime.
- ms_b1_meta.schema_migration is a separate bookkeeping table, not a seventeenth domain table. Versions/checksums/timestamps are transactionally recorded under a database-scoped advisory transaction lock. SQL source integrity uses UTF-8/LF normalization; all other bytes matter. Unknown/non-prefix history, altered checksums and untracked schemas fail closed. There is no automatic adoption/repair/down migration.
- migrations/catalog.expected.json is a reviewed actual-catalog snapshot checked after application and on every repeated invocation. It covers columns/defaults, owners, FKs/CHECKs/index definitions and validity, RLS, effective schema/table/column grants, role flags/memberships and unexpected executable/schema objects. A drift failure requires explicit review, never a regenerated manifest from a drifted environment.

Native SQL is authoritative for CHECKs, deferrable FKs, NULLS NOT DISTINCT/partial uniqueness and privilege/RLS semantics. Prisma7 remains a compatibility probe and may later serve supported repositories. No db push, Prisma migration generation, schema overwrite or API-startup migration occurs.

## Repository/security boundary

PersistenceModule.forLocal is an explicit DI opt-in, unconnected to the running health API. Four typed read ports share one small ConfigurationReader. TransactionManager passes an explicit transaction-local business context and closes the scope before returning the pooled connection. VersionedWriter only advances row_version/updated_at with a compare-and-swap predicate; it implements no configuration command. Stale/foreign/missing rows return the same null result. Callers must use the same provided transaction for compound operations. Callback retries are not automatic.

RLS limits accidentally unscoped runtime SQL and denies absent contexts. A future authorized application must derive TenantContext from verified identity/permissions; a caller-supplied business UUID is not authorization. Anyone holding runtime DB credentials can set another tenant context, so this is defense in depth, not protection from a compromised runtime or proof of production tenant authorization. The migration owner bypasses RLS and can alter gates, which is why its credential is separate and never supplied to an API. The CHECK(row_version>0) does not universally enforce monotonic increments; the tested repository CAS protocol supplies optimistic concurrency. Business writes/auth/role administration require B1-B review.

## Actual backup / separate restore

```powershell
# After test:b1a creates synthetic rows:
npm run b1a:backup
npm run b1a:restore
npm run b1a:verify
```

The trusted local source is dumped with the PostgreSQL18 pg_dump client in custom format. The ignored archive is .local/b1a/backup/b1a.dump; it is never uploaded. The tool verifies its SHA256 and unchanged source snapshot, identifies/recreates only ms_b1a_restore, then actually runs pg_restore --no-owner --exit-on-error --single-transaction. Every row in16 domain tables plus migration metadata is compared by ordered lossless JSON text hashes; schema/constraints/indexes/policies/effective grants are compared independently. It does not restore over the source. Existing matching roles are required; pg_dump does not back up cluster roles.

Schema ACL comparison expands default ACLs with aclexplode/acldefault: an implicit owner grant and an explicit identical owner grant are semantically equal. This normalization was added after a real restore comparison exposed that representation difference. Runtime privilege differences still fail drift checks. Reports retain actual failed attempts/resolutions. This is a local synthetic logical-restore test, not a production PITR/RPO/RTO guarantee or a generalized disaster-recovery tool.

## Existing B0 regression without resetting approved B0 data

`test:b0:isolated` runs all existing14 backend tests,35 SQL assertions and the Prisma probe in a separate tmpfs PostgreSQL clone on127.0.0.1:55435. A validated explicit test-only profile changes only helper connection/results paths; normal B0 behavior still defaults to55432. The original B0 SQL/test bodies stay unchanged. The clone's full72-table draft is regression validation only, never a B1A migration or persistent domain rollout. The clone is removed in finally; no original B0 volume is mounted or reset.

## Stop / reset discipline and CI

```powershell
npm run b1a:stop
# Preserves only this project's volume. Later: npm run b1a:up
```

No volume-reset command is supplied. For a fresh synthetic database, the integration harness performs guarded per-database recreation. Do not manually drop unrelated databases or use global Docker cleanup. Use one checkout at a time for this fixed B1A project and matching ignored credentials.

The GitHub Actions workflow is limited to the sanitized public repository/branches, requires the public-review marker and absence of tracked private asset/font paths, uses pinned action SHAs/read-only permissions and no persistent checkout token, and builds/tests only disposable data. Its upload allowlist contains three synthetic result JSON files, excluding env files, dumps, caches, private assets and UI screenshots. The B0 clone and B1A project are stopped separately. CI execution status is reported as observed; adding a workflow is not a claim that it passed remotely.

STOP after B1A. B1-B configuration/auth commands, production deployment, real bookings, payments and notifications require separate authorization.
