# 11 — Open decisions, assumptions and known risks

**PROPOSAL / ARCHITECTURE ONLY.** No implementation, real booking, payment, external message, database service or migration was executed.

## Confirmed versus proposed

Confirmed: brand/brochure/address/Instagram, six named services, two active branches, owner working mostly in one branch; existing private frontend contracts and commits. These come from the user's request and business-facts/context files. All architecture choices, limits, state semantics, currency/unit rules and rollout priorities below are proposals, not approved business operating rules.

## Blocking business inputs before real booking

| Decision | Current state | Safe behavior until confirmed |
| --- | --- | --- |
| Branch-two name/address/timezone/attribution | Unknown beyond active branch count | Keep business fact separate from bookability; no fabricated address or schedule |
| Staff identities/capabilities/branch days | Unknown; owner-role fact does not define roster | No production staff seed from fictional demo barbers |
| Real prices/durations/buffers/resources | Unknown per offering | Unconfigured offers cannot become bookable; no zero fallback |
| Opening hours/holidays/lead times/horizon/hold TTL | Unknown | Require explicit verified configuration |
| Deposit/refund/cancellation/no-show policy | Unknown | No inferred non-refundable/default no-deposit rule |
| Scope precedence and multi-service conflicts | Proposed deterministic fail-closed scheme | Owner/legal review before publication |
| Units/current Toman↔Rial meaning and gateway | Proposed 10 v1 Rial/Toman, integer money, versioned units | Block merchant integration until verified; no redenomination inference |
| Legal entity/jurisdiction/retention/consent | Unconfirmed | Counsel and owner review; no universal enforceability claim |
| Media publication rights and real imagery | Unverified, internal review only | Originals private; no publication/export |
| SMS/bot providers and consent workflows | No adapters chosen | No external messages or identity guessing |

## Architectural proposals requiring sign-off

- PostgreSQL 18 stable proposal, modular monolith, shared short DB transactions, resource-unit exclusion, sorted locks and SERIALIZABLE retries. Benchmark/driver/extension compatibility remains to be demonstrated.
- Global staff resources and actual shift intervals prevent cross-branch overlap. Travel time, customer occupancy and break/buffer semantics require explicit business decisions.
- One provider/sequential MVP. Future per-service staff plans require ordering/parallelism/resource handoff rules; do not guess whether a facial can overlap a manicure.
- Coalesced resource occupancy across adjacent segment buffers. Resource-kind/quantity requirements must be verified; zero/missing requirement does not mean no resources are needed.
- Quote invalidation before acceptance versus frozen terms after acceptance; reschedule financial renegotiation is not enabled in the MVP time-only swap.
- Whole-booking policy resolution requires homogeneous winning versions or explicit override. Deposit refund base, rounding and cancellation boundary require approved terms.
- Staff/owner MFA, customer identity method, account recovery and offline walk-in consent/evidence need selection and threat review.
- Proposed upload caps and recovery targets are engineering starting points; retention periods remain unspecified. Current-session/Redis/queue configuration cannot be claimed secure without runtime testing.

## Known risks and explicit limitations

Static SQL parsing does not instantiate types/extensions, prove runtime CHECK/FK behavior, validate generated-expression volatility or exercise deadlocks. Mandatory cross-row command/trigger/grant gates are listed in 03. OpenAPI validity proves a document's shape/references, not authorization or endpoint implementation. Diagrams are generated reviews, not screenshots of a running backend. There is no server, database migration, cache/queue/storage/payment/messaging integration in this branch.

Existing frontend dependency audit findings were previously recorded (Next/PostCSS); this architecture phase neither fixes nor hides them. Actual payment/notification adapters may lack external idempotency/status lookup; unknown outcomes then require reconciliation and documented duplicate/compensation risk. Redis loss, worker delays, callback races, PII leakage through logs/exports and consent cache invalidation require fault tests. Business details cannot be reconstructed from demo data or imagery. No architecture approval or production readiness certification is implied by delivering this review.
