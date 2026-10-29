# Phase03B-B1B — authentication, authorization and core admin APIs

Implemented from the approved ORIGINAL PRIVATE B1A commit045a013c0f096f6124758bd66ec3b53ffad2b3df on feature/phase03b-b1b-admin-api. Frontend source/assets/tests/dependency locks, approved Homepage/Booking, private architecture/Phase02 branches and B1A migration0001/0002 are preserved. This is an isolated administrative foundation, not production authentication or a booking engine.

## Modules and endpoints

Nest AdminCoreModule registers a narrow AdminRepository, verified SessionGuard and typed AdminCommands service. IamModule, BusinessModule, BranchModule, CatalogModule and OfferingModule contain real controllers. Audit/outbox/idempotency are one shared command boundary inside the core module, rather than empty wrapper modules or a separate unsafe second transaction.

| Method | Route | Permission/scope |
| --- | --- | --- |
| GET | /api/v1/session | Active session and current business membership |
| POST | /api/v1/session/revoke | Self session; Origin/CSRF/idempotency |
| GET | /api/v1/admin/business | business.read; session business |
| GET | /api/v1/admin/branches | branch.read; filter each branch before pagination |
| POST | /api/v1/admin/branches | branch.manage; business-wide assignment |
| PUT | /api/v1/admin/branches/{branchId} | branch.manage; target branch |
| GET | /api/v1/admin/services | catalog.read; business-wide assignment |
| POST | /api/v1/admin/services | catalog.manage; business-wide assignment |
| PUT | /api/v1/admin/services/{serviceId} | catalog.manage; business-wide assignment |
| GET | /api/v1/admin/branches/{branchId}/offerings | offering.read; target branch |
| POST | /api/v1/admin/branches/{branchId}/offerings | offering.manage; target branch |
| PUT | /api/v1/admin/branches/{branchId}/offerings/{offeringId} | offering.manage; target branch |

No role-grant/bootstrap/login, workforce scheduling, customer, booking, payment or notification endpoint exists. Stable branch/service codes cannot be renamed; offering service/branch association is immutable. Configuration rows remain historically referenced; there is no delete endpoint. Branch active/inactive is configuration only: bookable=false remains mandatory. Global service activation does not activate an offering. Existing resource configuration is projected honestly but edits to an offering with such configuration fail422 until a reviewed workforce/resource command exists.

## Server-verified sessions

Opaque256-bit random base64url session and separate CSRF secrets are minted only by the offline synthetic test helper, never accepted from a caller for issuance. Only SHA256 token/CSRF hashes persist. Session binds one business and user; every DB entry point rechecks current expiration, revocation, idle expiry, ACTIVE/non-archived user, business and active role membership. Test settings:1-hour absolute/15-minute sliding idle lifetime. These are isolated technical settings, not an approved production authentication policy.

Rotation locks user before sessions, revokes previous user/business sessions and creates fresh entropy. Repeated valid session use is supported until expiry/revocation; old rotated tokens fail401. Logout revokes durably, writes audit/outbox/idempotency and emits a clearing Secure/HttpOnly/SameSite=Strict host-only cookie. No token is logged or returned by GET session. CSRF material is handed to the harness in memory by the controlled helper. Normal browser login remains unavailable pending provider choice and HTTPS integration; Secure cookies are not weakened to make loopback HTTP a browser login.

The API/startup and provisioning reject production configuration, non-loopback connections, unexpected DB names/ports/roles and invalid secret shape. Provisioning additionally verifies the marked disposable DB and an existing B1B SYNTHETIC active user with membership. No hardcoded administrator, universal password, static bypass token, unauthenticated provisioning route or provider is introduced.

## Authorization and database boundary

Actor comes from session evidence, membership from non-revoked/non-archived UserRoleAssignment joined to active business-owned Role, and explicit permission from RolePermission/Permission. A null assignment branch means business-wide scope; a branch UUID narrows scope, never widens it. Role labels alone grant nothing. Client role/business/user headers confer no authority; strict bodies reject businessId/actor/role mass assignment. UUID targets are selectors only. Cross-tenant resources are404 within an otherwise permitted scope; absent scope permission is403.

Every function derives tenant and actor from token-hash evidence, then sets the transaction-local tenant context internally. The B1A arbitrary TenantContext/raw query interface is not imported into the HTTP application. AdminRepository exposes only fixed session/read/command operations with parameterized values; no public query(sql) port. A separate ms_b1b_api role has exactly3 EXECUTE grants, no table/schema ownership, table access, metadata access, role memberships, CREATE or TEMP privileges. Existing ms_b1a_runtime grants are unchanged and its credential must not be used for this API.

Seven reviewed functions use a pinned pg_catalog search_path, schema-qualified tables and no dynamic SQL. Only3 definer entry points are granted;4 private invoker helpers are inaccessible to API/PUBLIC. Owner is the non-superuser migration role, so that credential is privileged and isolated. API direct-call abuse, helper invocation, IAM/config/audit/outbox/idempotency/metadata reads or mutations, DDL, role elevation and RLS-variable switching are tested. Ordinary PostgreSQL session/builtin operations are not claimed impossible; unauthorized application SQL is denied. RLS remains defense in depth and is not authentication. A compromised legacy runtime/migration credential can select context or mutate privileged data; a captured valid bearer token remains usable until expiry/revocation.

## Atomic commands and concurrency

The shared typed command enters one reviewed SQL function/implicit PostgreSQL transaction: re-verify session/CSRF/membership/permission; validate strict DTO and target tenant; lock durable actor+route+key identity; compare canonical request digest; check existence and lock target; compare If-Match; write data/version; append redacted audit and minimal outbox; store result; commit together. Any failure rolls everything back. No external effect occurs. DB role and grant evidence are locked until commit; session/user lock ordering matches rotation.

Idempotency identity is business+actor+route/resource+key. Digest is SHA256 of PostgreSQL jsonb text containing strict body and If-Match; it is not a globally unique content hash or an authorization capability. Same identity/body/version replays the stored status/body and original ETag; different payload/version conflicts409. Permissions are rechecked before replay. Keys expire after a local24-hour technical retention window and are rejected after expiry; no purge/reuse job is enabled. Concurrent duplicate commands persist once. Updates use positive bigint version predicates under target row lock; two independent authenticated writers with the same version yield200/412. Missing/stale If-Match412, duplicate identity409, invalid/unconfigured422, invisible resource404, unauthenticated401, forbidden403 and infrastructure503 are sanitized with request IDs.

Audit stores actor/tenant/branch/target/request ID, changed field names and version, without raw address/description/token/customer content. Outbox stores only aggregate ID/version and stays unpublished. Runtime cannot tamper with either. Migration owner remains a trusted administrative boundary; cryptographic tamper evidence/operational retention is not claimed. Redacted request diagnostics record only server request ID/method/status and denied/failed status, without URLs, cookies, bodies, credentials or exception strings.

## Migration, environment and recovery

New project mohammadstyle-b1b uses PostgreSQL18.6 at127.0.0.1:55436 with independent random ignored credentials/volume/control DB and guarded ms_b1b_dev/failure/restore allowlist. Existing B0/B1A clusters are never reset. Forward0003 adds business_id/CSRF hash/idle expiry to auth_session,1 FK and2 CHECKs, plus7 functions and3 API EXECUTE grants. Legacy sessions with null new evidence fail closed. No seed, extra domain table, speculative index or gate removal. Result:16 domain tables,41 FK,45 CHECK,44 indexes and4 RLS policies. Migration0001/0002, original registry/catalog and B1A tests remain unchanged; registry.b1b.json/catalog.b1b.expected.json describe the new version separately.

Checksummed prefix history, transaction advisory locking, native PostgreSQL parsing, one atomic migration/history transaction, unknown/checksum/drift rejection and explicit manual migration are retained. Startup never migrates. Actual fresh install, B1A upgrade preserving data, no-op rerun, failed migration rollback, grant/gate drift and backup/restore are tested. Catalog fingerprint: 1ed91cfcdaabab6fe8471cd7f7e919cd7b780e4df541db72bc8c34b3fa1b6fc3. Parser checks are reported separately and never substituted for actual PostgreSQL execution.

Actual pg_dump custom archive:102322 bytes; SHA256:d621e450fe4ef25339681c413b27cd95c2a8b7a10cf8ef86d2d4654a3bc658b4. pg_restore into separate ms_b1b_restore preserves every ordered row hash across16 tables plus history and effective catalog/function/permission fingerprints. Restored session verification and denied IAM access are independently retested. Archive and credentials remain ignored and unexported. Cluster roles must be provisioned separately; no production PITR/RPO/RTO/retention/encryption readiness is claimed.

## Actual verification

- Backend npm ci completed with pinned lock, offline cache, --ignore-scripts:249 packages; no dependency upgrade.
- Backend typecheck/build PASS; 83 B1B PostgreSQL/NestJS assertions PASS/0 FAIL.
- Exact47 original B1A assertions PASS/0 FAIL,30 expected rejections, in a copied ignored tmpfs harness55437. Only harness routing/compiled port literals are adapted; tracked B1A test/repository/migration source is unchanged.
- Existing14 B0 tests +35 actual SQL assertions + Prisma7.10.1 probe PASS in an independent tmpfs clone55435, cleaned afterward.
- Frontend typecheck/build and92 Playwright results are recorded in evidence/frontend.json after the actual run; no static preview QA is counted. Screenshots containing private client faces remain internal and generated tracked artifacts are restored.
- Contract/static/source/export checks and actual public CI are reported in their separate receipts. Preparing a workflow is not a remote CI pass claim.

## Review limits and next decisions

Choose real identity provider/login/enrollment, MFA/privileged reauthentication, recovery, session policy and HTTPS/trusted proxy deployment before production. Review distributed rate limits/monitoring, credential rotation/role separation, backup controls and audit retention. Configure verified business values through a separately approved operational process; synthetic fixture money is not a tariff. Future workforce/resource/schedule APIs, authoritative availability/policy/admission and customer integration need separate authorization. Mixed-service policy remains owner-undecided/fail-closed. No live booking/payment/notification, portfolio CMS or production deployment. STOP after B1B for approval.
