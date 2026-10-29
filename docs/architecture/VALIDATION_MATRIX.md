# Architecture validation matrix

**Design review scenarios, NOT executed backend tests.** Every case below is an acceptance specification for Phase03B. Static parser/schema/render results are separately recorded in VALIDATION_RESULTS.md. No live DB, API, payment gateway or messaging provider exists from this phase.

## V01 — Two customers request the same barber/time

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Only one whole plan holds; loser gets409, no partial booking |
| Domain invariant | One live global resource interval; search is not a reservation |
| Database constraint / enforcement limit | no_live_resource_overlap; one active hold; tenant FKs |
| Transaction strategy | Sorted branch/resources then booking; SERIALIZABLE + exclusion rollback/retry |
| API behavior | POST booking-holds409 SLOT_UNAVAILABLE |
| Failure recovery | Replay same idempotency result or explicitly choose another plan |
| Future executable tests | Two real PG sessions synchronize search then insert; assert one winner and no orphan allocation |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V02 — Same staff scheduled in two branches at once

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Reject overlapping shifts and appointments across branches |
| Domain invariant | One human/STAFF resource identity globally |
| Database constraint / enforcement limit | no_cross_branch_staff_shift + no_live_resource_overlap without branch key |
| Transaction strategy | Lock all affected branches sorted then global staff resource |
| API behavior | Admin schedule409 SCHEDULE_CONFLICT |
| Failure recovery | Keep prior published shifts/booking; do not silently reassign staff |
| Future executable tests | Two-branch concurrent shift writes and resource holds; adjacent half-open intervals accepted only with approved travel rules |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V03 — Two selected services have different durations/buffers

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Build one sequential full-provider plan with exact coverage |
| Domain invariant | Full segment/resource containment; unknown duration never zero |
| Database constraint / enforcement limit | positive duration/checks + segment/revision/resource FKs; cross-row gate remains future |
| Transaction strategy | Re-read offering versions; coalesce same-resource buffers; atomic admission |
| API behavior | Availability whole plan; hold rejects changed configuration409 |
| Failure recovery | Issue fresh explicit plan/quote; preserve client selection for review |
| Future executable tests | Golden plan sum/order/gaps/buffer cases and overlapping self-buffers; reject missing resources |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V04 — Selected offering is inactive/unconfigured in this branch

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | No quote/hold using another branch price or capability |
| Domain invariant | Service metadata differs from branch offering; null unknown |
| Database constraint / enforcement limit | composite offering/qualification/assignment FKs; active readiness CHECK |
| Transaction strategy | Branch/config/resource locks, re-read all current active states |
| API behavior | 422 OFFERING_UNAVAILABLE/CONFIGURATION_INCOMPLETE |
| Failure recovery | Admin completes verified configuration; no demo fallback |
| Future executable tests | Cross-branch forged offering and disabled/null configuration negative tests |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V05 — Hold expires while user submits confirmation

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Expiry and confirmation serialize, cannot resurrect expired hold |
| Domain invariant | DB-clock linearization after locks; every released plan freed entirely |
| Database constraint / enforcement limit | hold status/expiry shape; exclusion retained until release |
| Transaction strategy | Same branch/resource/booking/hold order for confirmer and reaper |
| API behavior | 409 HOLD_EXPIRED unless confirmation already won validly |
| Failure recovery | Periodic PG sweep if delayed job lost; replay confirmed result if already consumed |
| Future executable tests | Before/equal/after expiry with controllable server clock and transaction barriers; lost Redis job recovery |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V06 — Gateway captures after hold expiry

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Record money, keep EXPIRED, start full unapplied compensation |
| Domain invariant | Verified capture is money evidence, not proof of capacity |
| Database constraint / enforcement limit | unique provider merchant transaction; unique application; balance CHECK |
| Transaction strategy | Persist verified capture independently; same confirmation locks; compensation outbox |
| API behavior | Payment status COMPENSATION_REQUIRED; never false booking confirmation |
| Failure recovery | Query provider/void/refund; UNKNOWN retained for reconciliation |
| Future executable tests | Late/duplicate/distinct extra capture, DB outage and lost callback; assert no resurrection |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V07 — Owner changes a policy before quote accepted

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Stale unaccepted quote requires explicit refresh/re-consent |
| Domain invariant | No silent repricing or scope change |
| Database constraint / enforcement limit | version/source/assignment FKs; artifact hash shape; immutable-content gate |
| Transaction strategy | Policy publication/routing lock plus quote fingerprint validation |
| API behavior | 409 QUOTE_STALE/POLICY_CONFLICT as appropriate |
| Failure recovery | Show new server quote/terms; customer may abandon |
| Future executable tests | Change assignment/version/effective window between quote and hold; deny forged artifact |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V08 — Owner changes policy after terms accepted

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Old booking continues to use its accepted snapshot |
| Domain invariant | No retroactive mutation; statutory exceptions separately reviewed |
| Database constraint / enforcement limit | acceptance references same quote/revision/version; append-only grants/triggers future |
| Transaction strategy | Lock revision and accepted evidence; cancellation reads snapshot, not current routing |
| API behavior | Cancel response calculation uses accepted version |
| Failure recovery | Permissioned documented beneficial/legal override, no evidence overwrite |
| Future executable tests | Retire old version/publish new terms; cancel old booking and assert old entitlement/hash unchanged |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V09 — Customer cancellation and two partial refund requests race

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Single cancellation; reserved+completed refunds never exceed capture |
| Domain invariant | Accepted-policy entitlement and captured money ceiling |
| Database constraint / enforcement limit | payment_balance CHECK; stable refund operation keys; immutable ledger intent |
| Transaction strategy | Cancel/resource hierarchy then balance lock; provider outside transaction |
| API behavior | Idempotent cancel/refund; conflict422 REFUND_LIMIT_EXCEEDED |
| Failure recovery | UNKNOWN keeps budget reserved; query before resend; definitive failure releases reservation |
| Future executable tests | Concurrent refunds near ceiling, duplicate callback, lost response, retry and reversal accounting |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V10 — Upload/publication of recognizable media without public consent

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Private processing may succeed; public publication denied |
| Domain invariant | Internal review rights do not imply WEBSITE_PUBLIC rights |
| Database constraint / enforcement limit | subject/asset/scope relation and tenant FKs; publication transaction gate future |
| Transaction strategy | Lock item/assets/subjects/consents at publish and revoke |
| API behavior | 409/422 PUBLICATION_CONSENT_MISSING |
| Failure recovery | Keep private; obtain valid evidence or unpublish, purge derivative serving/caches |
| Future executable tests | One missing subject, expired/revoked/internal-only consent, overwrite race, EXIF leakage and cache revoke tests |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V11 — Notification provider fails or times out

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Retry safely or reconcile UNKNOWN; no duplicate business notification claim |
| Domain invariant | Consent/revision rechecked; at-least-once does not mean exactly-once provider delivery |
| Database constraint / enforcement limit | event dedup, attempt key, outbox/inbox uniqueness |
| Transaction strategy | Persist attempt before network; result update separate; consumer transaction inbox |
| API behavior | Status FAILED/UNKNOWN; retry command cannot bypass consent |
| Failure recovery | Backoff/DLQ, permitted SMS fallback only; unknown provider capability gate |
| Future executable tests | Provider timeout before/after accepted message, replayed outbox and current opt-out/cancelled reminder |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V12 — Staff schedule changes after availability/quote

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Fresh hold/confirmation rechecks; conflicting edit rejected for live held capacity |
| Domain invariant | Eligibility alone never guarantees working coverage |
| Database constraint / enforcement limit | global shift/resource exclusions; schedule-version fingerprint |
| Transaction strategy | Same canonical locks for edit and acquisition; reject unauthorized displacement |
| API behavior | 409 QUOTE_STALE/SCHEDULE_CONFLICT |
| Failure recovery | Requote if unheld; emergency closure requires explicit affected-booking remediation |
| Future executable tests | Edit/hold/confirm barriers, new time off, inactive resources and branch closure |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V13 — Forged plan/quote IDs or customer changes branch context

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | No cross-business/customer/branch object access or fake slot acceptance |
| Domain invariant | Opaque IDs are selectors, not authority; ownership + current context |
| Database constraint / enforcement limit | tenant/quote/revision composite FKs; authorization mandatory |
| Transaction strategy | Authorize before reads; recompute all selected plan facts under admission locks |
| API behavior | 404/403 unauthorized or409 stale; no price/duration from request |
| Failure recovery | Safe refresh; audit relevant denied privileged actions without PII |
| Future executable tests | Customer A reads B, altered branch/time/timezone/provider, expired plan and key replay with new body |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V14 — Reschedule collides with another booking or own old interval

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Atomic same-terms swap; conflict preserves original revision/occupancy |
| Domain invariant | No self-overlap exemption or partial release |
| Database constraint / enforcement limit | resource exclusion; active revision same booking FK |
| Transaction strategy | Lock union old/new resources; release+insert+active pointer within one transaction |
| API behavior | 409 SLOT_UNAVAILABLE or422 RESCHEDULE_REQUIRES_REVIEW for financial changes |
| Failure recovery | Rollback original unchanged; refresh available plan |
| Future executable tests | Concurrent reschedules, overlapping self interval, failure after release before insert, unsupported paid renegotiation |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V15 — API worker crashes after commit but before provider/queue acknowledgement

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Committed result/outbox remains discoverable; repeat is safe |
| Domain invariant | Durable local atomicity, external idempotency/reconciliation |
| Database constraint / enforcement limit | idempotency request hash/result, outbox/inbox unique keys |
| Transaction strategy | One transaction for command+evidence+outbox; provider outside locks |
| API behavior | Replay same result; mismatched idempotency body409 |
| Failure recovery | PG outbox scan and bounded worker retry; retain dedup beyond recovery horizon |
| Future executable tests | Crash injection each boundary, queue loss, broker restart, provider unknown capability |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V16 — Cross-service/package policy conflict or unrelated override

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Explicit conflict unless authorized whole-booking policy resolves all items |
| Domain invariant | No arbitrary merge or unrelated-context policy persistence |
| Database constraint / enforcement limit | exact-scope exclusion; source/version FKs; multi-item resolver gate |
| Transaction strategy | Resolve all items at same instant; validate override actor/reason/scope |
| API behavior | 409 POLICY_CONFLICT,403 unpermitted override |
| Failure recovery | Configure coherent assignments or approved re-consented whole-booking override |
| Future executable tests | Tie rank, mixed services, branch change, mixed package/add-on, unrelated booking override |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V17 — Rial/Toman rounding or gateway amount/unit mismatch

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Exact integer conversion; mismatch cannot confirm |
| Domain invariant | Versioned units; no float/unsafe Number conversion |
| Database constraint / enforcement limit | bigint bounds, whole-Toman modulo10 and sum CHECKs |
| Transaction strategy | Verify provider outside transaction; persist only verified receipt; lock application |
| API behavior | 422 configuration error or pending reconciliation; never trust callback amount |
| Failure recovery | Quarantine mismatch, alert finance, exact-unit manual review |
| Future executable tests | Boundary bigint values, non-divisible conversion, half-up ties, min>total, wrong merchant/currency/amount |
| Current evidence | Specification cross-review only; NOT RUN against backend |

## V18 — Barber requests another barber customer or branch finance

| Aspect | Proposed requirement |
| --- | --- |
| Expected behavior | Deny unrelated scope; minimal assigned appointment projection |
| Domain invariant | Role alone does not grant customer contacts/receipts |
| Database constraint / enforcement limit | Role/assignment FKs only; not sufficient for authorization |
| Transaction strategy | Resolve actor+permission+branch/resource on every request/worker |
| API behavior | 403/404; no totals/contacts leaked through list/export/media URLs |
| Failure recovery | Audit privileged access/denials; revoke sessions on permission change |
| Future executable tests | Object/list/cursor/export/cache scope negatives, customer self only and revoked role tests |
| Current evidence | Specification cross-review only; NOT RUN against backend |
