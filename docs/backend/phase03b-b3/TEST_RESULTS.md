# Actual test results

- B3 PostgreSQL18.6/Nest: 78PASS/0FAIL/52expected denials. Actual execution 2026-10-29T23:33:38.142Z. Full named assertions: evidence/integration.json.
- Prior unchanged tests in verified isolated clones: B2H42, B2B71, B2A69, B1B83, B1A47, B0 backend14/SQL35/Prisma PASS. Original assertions preserved; clone route/compiled local port allowlist rewrites only, no old DB reset.
- Backend/frontend typecheck/build PASS; final92 Playwright PASS/0FAIL/0flaky, four existing viewports. First91/92 local run failed one resource load with Chrome ERR_NO_BUFFER_SPACE; full unchanged rerun succeeds and both summaries retained. No approved UI changed.
- Actual11-version fresh install,9->11 data-preserving upgrade, checksum preservation, no-op, drift rejection, atomic failed-DDL/history rollback PASS.
- Natural60-second expiration with exact expired-key original identity/expiry replay PASS.
- CAS and durable same-key concurrency: {"connections":2,"committed":1,"rejected":1}; {"connections":2,"responses":2,"identities":1}.
- Custom pg_dump 394915bytes SHA25686460a5b98cba211a2fafe523444a18a271974d9cf5e95cbef3aede1c1dd84cd; independent ms_b3_restore preserves38 tables, ordered lossless row fingerprints, functions/catalog/effective grants. Restored SQL and real Nest reads/denials PASS. Dump remains ignored/excluded.
- Current-head CI is verified separately in CI_RESULTS.json/CI_JOBS.json/CI_ARTIFACT_INSPECTION.json at delivery. Static SQL parser/OpenAPI validation is separate from actual PostgreSQL execution.

1. PASS — upgrade nine-to-eleven preserves existing application rows
2. PASS — fixed deposit uses server price and immutable disclosed terms
3. PASS — multiple branch services sum exactly
4. PASS — branch-specific offering prices remain separate
5. PASS — percentage deposits use integer half-up whole-Toman-compatible rounding
6. PASS — exact half increment rounds up without floating point
7. PASS — explicit percentage minimum bound applies
8. PASS — explicit percentage maximum bound applies
9. PASS — optional declined deposit remains zero
10. PASS — optional chosen deposit is calculated
11. PASS — explicit NONE carries no hidden deposit
12. PASS — deposit larger than total is rejected rather than clamped
13. PASS — no optional choice can alter required deposit semantics
14. PASS — branch override outranks higher-priority business default
15. PASS — service override outranks branch override
16. PASS — mixed service winners fail POLICY_CONFLICT
17. PASS — explicit exact-set whole-booking policy resolves only configured compatible winners
18. PASS — whole-booking assignment never applies to an unrelated subset
19. PASS — whole policy cannot hide a changed incompatible service winner
20. PASS — whole policy requires explicit override permission
21. PASS — staff-specific policy outranks service policy for a verified eligible provider
22. PASS — staff-service scope is more specific than staff scope
23. PASS — forged provider and missing service eligibility fail closed
24. PASS — ending provider membership invalidates staff-selected commercial context
25. PASS — qualification version changes stale a provider-selected proposal
26. PASS — overlapping exact-rank scope assignments are rejected natively
27. PASS — missing policy fails closed
28. PASS — new version number is monotonic and old quote terms do not change
29. PASS — published policy content and refund windows cannot be rewritten
30. PASS — draft replacement validates and publishes the replacement
31. PASS — retired versions remain in authorized history, excluded from current
32. PASS — invalid refund modes/windows and duplicate thresholds are rejected
33. PASS — cancellation/refund boundary minutes=1440
34. PASS — cancellation/refund boundary minutes=1439
35. PASS — cancellation/refund boundary minutes=60
36. PASS — cancellation/refund boundary minutes=59
37. PASS — cancellation/refund boundary minutes=-1
38. PASS — flat PARTIAL refund uses frozen snapshot and exact amount
39. PASS — NONE refund is explicit zero and ALL_PAID preview is labeled hypothetical
40. PASS — effective policy end is exclusive and entire candidate must fit
41. PASS — independent actors may receive identical hash with different quote identities
42. PASS — same idempotency key replays exact identity and original expiry
43. PASS — same key with different request fails rather than mutating quote
44. PASS — client amounts and duration fields are rejected
45. PASS — stale offering versions and duplicate offerings are rejected
46. PASS — valid current proposal can be checked but never binds a booking
47. PASS — tampered hash fails before returning a current result
48. PASS — configuration changes stale unaccepted quote without changing stored terms
49. PASS — expired immutable fixture uses database clock and replay does not extend TTL
50. PASS — immutable quote artifacts/items reject updates and deletion
51. PASS — integer precision above Number safe range survives PostgreSQL and JSON
52. PASS — aggregate bigint overflow fails closed
53. PASS — invalid currency precision, exponent, negative and overflow input rejected
54. PASS — branch manager cannot configure global terms or other branch
55. PASS — authorized manager creates only own branch scoped policy/version
56. PASS — branch read cannot disclose unrelated unassigned global policy versions
57. PASS — cross-tenant branch and quote selectors never widen session tenant
58. PASS — forged branch/offering selector cannot cross branch prices
59. PASS — API role cannot read tables, execute private helpers or become owner
60. PASS — concurrent configuration changes yield one CAS winner
61. PASS — concurrent same-key quote requests create exactly one durable proposal
62. PASS — audit/outbox/data/idempotency rollback atomically on outbox failure
63. PASS — Nest real authenticated create/quote/read flow
64. PASS — Nest exposes exact policy conflict diagnostic
65. PASS — Nest rejects missing session, CSRF, origin and If-Match
66. PASS — Nest rejects duplicate JSON keys and malformed Unicode before DTO construction
67. PASS — Nest rejects forged tenant envelope and unknown command
68. PASS — SQL/JS canonical commercial hashes agree including Unicode
69. PASS — approved final V2 content hash vectors remain exact; identity is not hash input
70. PASS — fresh eleven-version install and verified no-op
71. PASS — old nine checksums remain exact
72. PASS — catalog drift rejected without automatic repair
73. PASS — failed forward migration rolls DDL/history back
74. PASS — bookability stays disabled and forbidden B4 tables do not exist
75. PASS — old databases are outside B3 reset allowlist
76. PASS — actual 60-second quote expiration and expired same-key replay retain original expiry
77. PASS — real custom backup and independent restore preserve all38 tables and grants
78. PASS — restored Nest API and SQL boundary retain immutable commercial evidence
