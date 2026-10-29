# Actual validation matrix

| Requirement | Actual executable evidence |
| --- | --- |
| BEFORE: actual migration0008 reproduces former-branch time-off disclosure | PASS |
| BEFORE: actual migration0008 current calendar includes draft and withdrawn evidence | PASS |
| hardened API startup fails closed before migration0009 exists | PASS |
| upgrade from unchanged0001..0008 applies only0009 and preserves application rows | PASS |
| A: former Branch A manager cannot read later Branch B time off through SQL | PASS |
| A: actual Nest Branch A exceptions deny former-member disclosure | PASS |
| B/C: managers see only genuine membership-period time off | PASS |
| former-branch staff and qualification projections cannot reveal current global metadata | PASS |
| global staff metadata remains available only with explicit business-wide permission | PASS |
| D: concurrent valid memberships grant only corresponding clipped intervals | PASS |
| disjoint same-branch stints produce separate slices and never expose the gap | PASS |
| E: voided membership grants no current or historical exception visibility | PASS |
| E: inactive open-ended membership does not confer future history access | PASS |
| archived closed past membership requires explicit historical permission | PASS |
| F: exact Tehran exclusive midnight splits global leave without overlap | PASS |
| F: time off starting at membership exclusive end is invisible | PASS |
| query-local midnight clipping eliminates padded UTC disclosure | PASS |
| G: current calendar excludes draft/withdrawn shifts through SQL and Nest | PASS |
| H: explicit history shows all retained evidence with distinguishable state | PASS |
| H: current permission alone cannot request history through SQL or Nest | PASS |
| history grants remain branch-scoped | PASS |
| mutable staff/qualification records cannot masquerade as historical snapshots | PASS |
| I: forged branch/staff/tenant selectors cannot broaden actual HTTP scope | PASS |
| I: direct SQL session tenant cannot be replaced by caller context | PASS |
| J: API role cannot query protected tables or private read helpers | PASS |
| legacy offering staff IDs exclude former branch members | PASS |
| DST local-day window uses real IANA midnight instants rather than UTC padding | PASS |
| ambiguous local-midnight membership boundaries confer no guessed visibility | PASS |
| inactive finite future membership cannot authorize future historical leave | PASS |
| archived exception evidence is confined to explicit history and still clipped | PASS |
| Barber own schedule excludes draft/history and rejects other staff selectors | PASS |
| current staff schedule route also excludes withdrawn/draft evidence | PASS |
| slice pagination preserves deterministic membership-scoped ordering | PASS |
| fresh install nine versions; no new tables or broad grants | PASS |
| repeat migration is verified no-op | PASS |
| original eight registry entries/checksums remain exact | PASS |
| catalog drift detected without repair | PASS |
| failed forward migration atomically rolls DDL/history back | PASS |
| old databases are outside the hardening lifecycle allowlist | PASS |
| membership writer waits for a coherent branch-scoped read transaction | PASS |
| actual custom backup and separate restore preserve all rows/catalog/grants | PASS |
| restored API preserves the denial and current/history distinction | PASS |

New suite:42/0,17 expected SQL denials. Actual Nest tests are named explicitly; direct SQL cases use the production API-role entry points. Fixture inserts/monitoring/lifecycle are trusted harness work.

Original B2B71/B2A69/B1B83/B1A47/B0 backend14 + SQL35 + Prisma7.10.1 PASS in isolated unchanged-profile regressions. Frontend92/0/0flaky actual four-viewport results are recorded separately. Backend/root typecheck/build PASS. Static SQL parser/OpenAPI/render checks are separate from actual PostgreSQL execution.
