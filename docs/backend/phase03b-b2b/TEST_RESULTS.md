> Current read-scope refinement: [B2B hardening](../phase03b-b2b-hardening/README.md) supersedes read semantics below. This original phase report/evidence is retained as historical baseline.

# Actual validation results

B2B 71PASS/0FAIL;54 expected SQL rejections;8 distinct-session observed lock waits. Actual executions: 2026-10-29T21:19:18.144Z. Real Nest/controller/guard tests and direct production SQL entry-point assertions are identified by name. Trusted fixture/lifecycle/fault/monitor work is harness-only.

Preserved baseline regression results: B2A69/0; B1B83/0; B1A47/0; B0 backend14/0 + SQL35/0 + Prisma7.10.1 PASS. New B2B integration is a separate71-test suite, not the B2A suite. Frontend result is supplied in evidence/frontend.json after the real run completes. Backend npm ci/typecheck/build pass; root build/typecheck and frontend Playwright results are documented separately.

First attempt42/13 exposed UNION read-query ordering/name ambiguity, a snapshot PK assumption and insufficient harness monitoring privileges. Second51/4 isolated the remaining read-query ambiguity. Third55/0 passed; added hardening/regression cases then final71/0 passed. Earlier failure summaries remain preserved in review evidence; no failed run is counted as success. First init-up encountered temporary-server restart; TCP health readiness now avoids that initialization window.

| Executed assertion | Result |
| --- | --- |
| fresh install eight checksummed migrations,28 tables | PASS |
| migration rerun no-op with catalog verification | PASS |
| 0001..0005 registry/source exactly preserved | PASS |
| upgrade from B2A preserves rows and leaves legacy approvals explicitly unreviewed | PASS |
| failed forward migration rolls back all DDL and history | PASS |
| Nest Owner creates inactive global staff/resource | PASS |
| Nest branch manager cannot modify other branch | PASS |
| Nest receptionist cannot publish | PASS |
| Nest customer has no administrative access | PASS |
| Nest rejects forged role/businessId and unknown fields | PASS |
| Nest enforces Origin/CSRF and mandatory If-Match | PASS |
| Nest branch scope cannot select foreign tenant | PASS |
| API direct field allowlist independently denies mass assignment | PASS |
| qualification/rule does not automatically publish availability | PASS |
| Nest publishes reviewed UTC shift with local evidence and source version | PASS |
| Nest read-only calendar contains published shift and no reservation claim | PASS |
| membership closure conflicting with published shift is rejected | PASS |
| qualification revocation cannot silently invalidate published shifts | PASS |
| staff deactivation cannot invalidate published shifts | PASS |
| opening-hour rewrite with published shifts requires explicit review | PASS |
| published shift content cannot be edited directly by migration owner | PASS |
| legacy timezone/catalog command refuses configured calendar context | PASS |
| out-of-membership publication denied | PASS |
| inactive staff/resource cannot publish | PASS |
| stale source rule version denied | PASS |
| offering-specific qualification alone does not grant eligibility | PASS |
| approved time off blocks publication; request alone is not approval | PASS |
| time-off approval conflicting with published shifts fails closed | PASS |
| branch manager cannot approve global staff time off | PASS |
| reviewed closure blocks publication | PASS |
| closure approval conflicting with published shifts fails closed | PASS |
| DST gap fails closed in actual production materializer | PASS |
| DST fold requires explicit reviewed resolution | PASS |
| coherent overnight local segments publish atomically across midnight | PASS |
| incomplete overnight plan rolls back all inserted shifts | PASS |
| invalid recurrence weekday/window rejected by DB checks | PASS |
| same idempotency key replays one publication and one audit/outbox | PASS |
| versioned correction explicitly archives reviewed IDs and inserts new plan | PASS |
| explicit withdrawal preserves history before leave/rejoin with new UUID | PASS |
| adjacent cross-branch shifts reject unknown transfer feasibility | PASS |
| verified identity link requires persisted verified identity and membership | PASS |
| physical resource and inactive configuration commands work through Nest | PASS |
| API lacks direct tables/private helpers/DDL/role escalation | PASS |
| bookability gates and forbidden future tables remain | PASS |
| late outbox failure rolls data/audit/idempotency/calendar version back together | PASS |
| two concurrent publishers cannot both commit stale calendar versions | PASS |
| membership close vs publication serializes and revalidates | PASS |
| approved time off vs publication serializes and revalidates | PASS |
| closure vs publication serializes and revalidates | PASS |
| qualification revoke vs publication serializes and revalidates | PASS |
| two If-Match configuration writers have one winner | PASS |
| concurrent identical idempotency key replays without duplication | PASS |
| cross-branch simultaneous publication has one winner and safe transfer rejection | PASS |
| every administrative GET contract executes on actual Nest | PASS |
| unchanged B1B session/config controllers run through isolated B2B adapter | PASS |
| unchanged B1B self-session revoke works on B2B without privileged grants | PASS |
| bounded calendar query rejects oversized horizon and unknown selectors | PASS |
| requested time off is explicit pending evidence and does not block shifts | PASS |
| review rejection is a new immutable exception revision | PASS |
| partial overnight withdrawal cannot break coherent reviewed plan | PASS |
| null membership end cannot masquerade as a departure | PASS |
| nested rule/materialization mass assignment is rejected | PASS |
| opening hours fully cover every local minute of published shift | PASS |
| qualification verification retains actor and evidence digest without raw reference | PASS |
| legacy runtime cannot mutate workforce or call publication boundary | PASS |
| tenant-safe rule qualification FK rejects incompatible staff context | PASS |
| applied checksum tampering is detected without repair | PASS |
| catalog drift detected; no automatic repair | PASS |
| original databases are outside B2B lifecycle allowlist | PASS |
| actual backup/custom archive and separate restore preserve rows/catalog/grants | PASS |
| restored API role executes production schedule read and retains table denial | PASS |

SQL parser validation is separate static evidence. Fresh/upgrade/no-op/checksum/drift/rollback/grants/FK tests, concurrency and backup/restore above actually ran on PostgreSQL18.6. No production migration, customer capacity admission or payment test is claimed.

Final actual frontend: root typecheck PASS, production build PASS,92/92 Playwright PASS,0 failures/0 flaky, all four viewports. Original private tracked screenshots restored after collecting this run summary; no client-face screenshots exported.
