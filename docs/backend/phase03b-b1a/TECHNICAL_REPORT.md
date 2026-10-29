# Phase03B-B1A persistence foundation — actual execution

Approved private B0 baseline7a51ae6ad2dde941e263d8b781cd0c52ba9bc213. Branch feature/phase03b-b1a-persistence. B0 is technically approved; only B1-A progression is authorized. Homepage/Booking/source/assets/frontend tests/dependencies are preserved. Original B0 API, cluster/databases/volume and prior branch refs are not reset or migrated.

## Implemented migration path and environment

PostgreSQL 18.6 (Debian 18.6-1.pgdg12+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 12.2.0-14+deb12u1) 12.2.0, 64-bit

The dedicated mohammadstyle-b1a project owns a separate local PostgreSQL18.6 container and volume, only127.0.0.1:55434. ms_b1a_control is provisioning-only; ms_b1a_dev is the disposable persistence database; ms_b1a_failure isolates negative migration tests; ms_b1a_restore is an independently recreated restore destination. The image digest is pinned. Three ignored random credentials separate admin provisioning, non-superuser migration ownership and restricted runtime. No secret is in SQL, code, logs, screenshots or the public export. Default B0 remains at55432; its live API has no new controller/import/startup migration.

| Version | Scope | Result |
| --- | --- | --- |
|0001_b1_foundation | Approved16-table DDL; all tables before FK/index pass; inactive gates retained | Actual PostgreSQL execution PASS |
|0002_b1a_runtime_boundary | Four scoped configuration reads; column-limited version/timestamp updates; four RLS policies | Actual permission/tenant tests PASS |
| ms_b1_meta.schema_migration | Separate bookkeeping table, atomic version/checksum/time records | Prefix/checksum/no-op/concurrency/failure tests PASS |

Exactly16 domain tables,40 FKs,43 CHECKs,44 indexes,4 tenant-context RLS policies. Bookkeeping is outside the domain schema; no72-table migration or production rollout exists. The original approved architecture SQL/model/dictionary remain unchanged. Native0001 differs only in historical comments/header, not executable16-table definitions. No prices/durations/staff/customer/policy business facts are seeded; test fixtures are explicitly synthetic and unknown offering values remain null.

Version-controlled registry checks SHA256 after UTF-8/LF normalization. A transaction-scoped advisory lock serializes migrators. All pending DDL and history changes commit together; a failed SQL statement rolls them back. Unknown/non-prefix history, changed source/applied checksums, untracked schemas or catalog drift are refused. No automatic repair/adoption/down migration or API-startup migration is implemented. The reviewed actual-catalog manifest checks fields/defaults/owners, constraints, valid indexes, RLS, effective grants, role flags/membership and unexpected executable objects. It must never be regenerated to bless accidental drift.

## Actual verification

-47 B1A integration assertions pass;0 fail;30 deliberately provoked SQL/application rejections are recorded with code/root cause in SQL_FAILURES.md.
- Fresh/repeated installation, version history, simultaneous migrations, cross-tenant FKs/RLS, NULL-safe partial uniqueness, missing/invalid config, inactive gates, permission negatives and catalog drift all tested.
- Two runtime sessions read the same version: exactly one CAS writer advances1→2 and the other returns null. A later stale write cannot overwrite. Deliberate division-by-zero after a version update rolls the whole transaction back; the pool remains usable.
- A failed migration containing CREATE TABLE then SELECT1/0 produces actual SQLSTATE22012; neither its probe table nor history row survives. Invalid history/checksum/untracked-schema errors are application migration guards, not falsely labeled PostgreSQL SQLSTATEs.
- Existing14 B0 backend tests,35 SQL assertions and Prisma7.10.1 compatibility checks pass in a separate tmpfs clone55435, removed in finally. Existing SQL/test bodies are preserved. Only explicit helper profile/validated port routing/result paths changed; normal B0 defaults are unchanged. The clone's72-table execution is old regression validation only, never B1 persistence rollout.
- Backend typecheck/build and original frontend typecheck/build pass; all92 original Playwright tests pass on the actual private Next.js app at four viewport sizes. Generated client-image screenshots stay private and tracked old review artifacts are restored after collecting this run's summary.
- Pinned GitHub Actions workflow is prepared for the sanitized repository only. It checks public-review/source guards before builds, uses read-only permissions/no persistent checkout token, disposable data, and uploads only3 synthetic result JSONs. Remote CI state is reported separately in final delivery evidence; workflow creation is not a remote-pass claim.

## Actual backup and restore

pg_dump (PostgreSQL) 18.6 (Debian 18.6-1.pgdg12+2). Custom archive bytes:68292. Archive SHA256:ebf04110cec0c85ac29459d4255659884368c79f2fb8bb44fa024580d0098406.

The trusted synthetic source was actually dumped and restored with pg_restore --no-owner --exit-on-error --single-transaction into ms_b1a_restore. SHA256, source identity, unchanged source snapshot and destination owner/marker are checked before destructive recreation. No source overwrite and no original B0 database access/reset is required. All21 rows across16 domain tables plus migration history match by ordered lossless row JSON hashes. Catalog schema objects, constraints/indexes/policies and effective permissions match independently. Runtime scoped reads and denied metadata access are retested on the restored database. The archive stays ignored and is not published.

First attempts found a CLI --version argument-order issue and an explicit-versus-default owner schema ACL representation difference. Neither was silently treated as success. Effective ACL expansion preserves privilege checking while equating identical implicit/explicit grants. A separate test granting extra DELETE still detects drift. Initial clone Prisma routing also exposed a hard-coded old port (P1000); it now uses the validated environment's host/port while preserving default behavior. Failed output and final successful evidence are both included.

## Persistence/module boundary and security limits

The explicit opt-in PersistenceModule registers TransactionManager through Nest DI; it is not imported by the running B0 AppModule. ConfigurationReader implements four typed read ports for future Business/Branch/Service/Offering modules. VersionedWriter changes only version/timestamp metadata with a CAS predicate; it is not a configuration command or customer API. Transaction-local tenant context, explicit shared transaction objects and closed-scope checks prevent ordinary context leakage and post-transaction reuse. No automatic callback retry risks repeating future external side effects.

Runtime cannot DDL, elevate role, read IAM/migration metadata, delete/truncate, edit business fields/gates or disable/bypass RLS. Migration owner remains privileged and must be isolated from an API. RLS is defense in depth for trusted application context, not authentication: a compromised runtime credential can choose another business context. Production identity/role/branch authorization is disabled and awaits separate review. CHECK(row_version>0) does not alone force monotonic/CAS writes; repository protocol is tested, while future commands must consistently use it. Database FKs are not application authorization. No complete security certification or booking/double-booking guarantee is claimed.

## Prisma/native SQL decision

Prisma7.10.1 remains a dev compatibility probe, unchanged apart from using its already validated connection port for isolated regression. Native SQL is authoritative for deferrable FKs, CHECKs, NULLS NOT DISTINCT/partial uniqueness, grants and RLS. Supported ordinary repositories may use Prisma later; no incomplete generated schema replaces SQL. No prisma db push, production migration, ORM schema overwrite or dependency upgrade occurred.

## B1-B readiness

The persistence foundation is ready for owner/code review and a separately authorized B1-B task. B1-B still needs authenticated server-derived tenant/branch scope, configuration command/field permissions, audit/idempotency transaction contracts, recovery/drift/upgrade operations and real verified business inputs. Retain inactive gates until the later scheduling/policy/admission cohorts. Production deployment/TLS/PITR/RPO/RTO/load and generalized disaster recovery are not proved by this synthetic logical restore. STOP at B1-A; no real bookings, payments, notifications or B1-B work has started.
