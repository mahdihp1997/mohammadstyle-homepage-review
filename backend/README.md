# Phase 03B-B0 local foundation

Approved follow-on B1A persistence work is documented in [B1A.md](B1A.md). It uses a separate local cluster/roles and explicit migrations; the B0 API and default environment below remain unchanged.

This independent npm project contains infrastructure and disposable-database validation only. No application schema is installed in the API's control database. Homepage/Booking continue using the approved demo frontend. No operational booking, policy, payment, customer, messaging or authentication endpoint exists.

## Prerequisites and start

Node 24.16.x, npm 11.17.x, Docker with Linux containers and Compose. Windows PowerShell commands, from the repository root:

```powershell
Set-Location backend
npm ci
npm run env:init
npm run infra:up
Invoke-RestMethod http://127.0.0.1:3100/health/live
Invoke-RestMethod http://127.0.0.1:3100/health/ready
```

`env:init` creates random, ignored `.env.local` values without printing them. The Compose project is fixed to `mohammadstyle-b0`; PostgreSQL listens only on host loopback 55432, API only on loopback 3100. Both use a dedicated Compose bridge network. Docker on this Windows host omitted published ports on an internal network; the verified bridge configuration preserves explicit loopback-only ingress. Do not copy credentials into commands, logs, PRs or screenshots. Docker inspection and local administrators can see injected development environment values; this is not a production secrets manager.

`infra:up` creates a non-superuser, non-DDL `ms_b0_probe` health role, then builds/starts the API with only that role's credentials. Admin credentials remain in the host validation tool and PostgreSQL container. No schema migration runs at API startup. The image's volume uses PostgreSQL 18's `/var/lib/postgresql` layout. Versions are pinned; the validated image digest is recorded in the evidence report.

Use one checkout at a time. An existing B0 volume must use its original matching `.env.local`; a second checkout must not initialize different credentials against the running cluster. Use the original checkout or explicitly reset only the verified disposable B0 environment first.

## Reproduce checks

```powershell
npm run typecheck
npm run build
npm test
npm run test:db
npm run test:prisma
npm run check:secrets
npm run diagnostics
```

`test:db` first verifies the fixed loopback control database identity/marker and PostgreSQL major version. It creates or resets only `ms_b0_b1_test` and `ms_b0_full_test`. An existing database must carry the explicit B0 disposable marker before it can be dropped. Connections to arbitrary database names/hosts are refused. Close external introspection sessions before rerunning; the tool does not force-kill database users. Synthetic fixtures have no relationship to actual salon staff, tariffs, policies or customers. The two original SQL drafts remain unchanged and are executed directly; they are still specifications, not production migration files.

Results go to ignored `.local/results/`. Negative tests deliberately produce SQLSTATE failures: these are successful rejection assertions, listed separately from unexpected SQL errors. Tests exercise SQL constraints and the health foundation, not an authoritative Booking Engine or application authorization.

`test:prisma` runs validate/generate and real read-only introspection against only the disposable full database, followed by generated-client reads, raw range SQL, transaction isolation and rollback checks. It never invokes `db push`, `migrate dev`, `migrate deploy` or production migration generation. Generated client and full introspection output are ignored. Prisma is a dev-only compatibility probe; the runtime health module uses `pg`.

Host-only API alternative after `npm run build` and PostgreSQL/probe provisioning:

```powershell
node --env-file=.env.local dist/main.js
```

## Stop and reset

```powershell
npm run infra:stop
# Later: npm run infra:up (retains the isolated volume)
npm run infra:reset
# Later: npm run infra:up (fresh isolated cluster)
```

Stop removes only this Compose project's containers/network and retains its volume. Reset verifies the exact volume name plus Compose project and purpose labels, then removes only that project's volume. Never use `docker system prune`, wildcard volume removal or an unrelated Compose project. Random environment credentials are retained on reset. Changing credentials requires an explicit isolated reset or reviewed password rotation; startup does not silently change an existing role's password.

## Boundaries

`ConfigModule` supplies a validated B0-only DI token. `DatabaseModule` owns the bounded health connection pool. `HealthModule` owns liveness/readiness. The global filter/logging functions return generic errors with generated request IDs and omit URLs, query strings, exception payloads and secrets. There are no empty future domain modules. Readiness failure is 503; liveness remains 200 during DB outage. Runtime grants, production TLS/auth, backups, restore/PITR, cross-row guards and Booking Engine races remain separate future gates.
