# Focused security review — isolated B1B

Reviewed implemented source, PostgreSQL grants/function definitions, actual HTTP and direct SQL abuse tests. This is not production security certification.

| Area | Result and evidence | Remaining decision / severity |
| --- | --- | --- |
| BOLA / tenant | Session-fixed business; composite FKs and in-function target checks; cross-tenant branch/offering/service tests deny | No unresolved high finding in scoped tests |
| BFLA / branch | Current role+permission+branch evidence, not role names/client selectors; receptionist pricing and unrelated-manager mutations denied | Future role-grant administration not exposed |
| Session / fixation | Random256-bit secrets, hashes only, absolute/idle expiry, active user, revocation, rotation, user-before-session locks | MEDIUM production gate: provider/MFA/recovery/re-authentication unresolved |
| Bearer replay | Reuse valid until expiry/revoke; old rotated/revoked tokens fail; command replay guarded by durable idempotency | MEDIUM production gate: TLS, theft response and approved lifetimes; no claim of zero token-theft replay |
| CSRF / cookies | Exact Origin, synchronizer secret hash, JSON and same-origin fetch metadata; Secure/HttpOnly/Strict host-only cookie | MEDIUM: HTTPS/browser login integration deliberately disabled |
| Privilege / SQL | API has3 EXECUTE grants only; no tables/private helpers/DDL/metadata/roles; fixed parameterized calls | Migration owner is trusted; legacy runtime not suitable as API credential; RLS not auth |
| Mass assignment | Strict required DTO keys at Nest and DB; UUID/nullable/bigint/IANA checks | Resource/staff modifications reject422 until later reviewed command |
| Sensitive output | Generic codes/request IDs; no SQL/cookies/tokens/bodies in server diagnostics | Operational retention/access controls remain undecided |
| Audit integrity | Atomic redacted audit+unpublished outbox+idempotency; runtime append/tamper unavailable | MEDIUM production gate: migration credential custody, audit retention/tamper evidence |
| Rate limiting | Bounded per-IP/per-session/per-write in-process limits; no trust in forwarding headers;429 and Retry-After tested | MEDIUM production gate: distributed/process-restart limits and monitoring |
| Dev bypass | No HTTP login/bootstrap/role-grant route; helper requires local marked DB, migration credential, synthetic active identity/membership; production options rejected | No general development bypass enabled in production |

Initial migration attempt returned actual42601 for an unparenthesized CASE expression in PL/pgSQL validation. The whole migration transaction rolled back; syntax was corrected before baseline generation and all final execution tests. No migration/version was silently marked successful. The first infra invocation overlapped dependency installation and failed to resolve pg; it was rerun after npm ci completed. Neither failure is counted as a passing test.

Primary design references: [OWASP session guidance](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html), [OWASP CSRF guidance](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html), [PostgreSQL18 secure definer functions](https://www.postgresql.org/docs/18/sql-createfunction.html). These informed the design; actual project tests provide implementation evidence.
