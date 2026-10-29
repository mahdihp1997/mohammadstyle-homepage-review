# 04 — Authoritative booking engine

**PROPOSED / REVIEW REQUIRED — Phase 03A specification only.** No backend, database, migration, gateway or notification service was installed or executed. The private Phase 02 frontend remains canonical and unchanged.

## Plan semantics

Availability takes business/branch, service/offering IDs, local date, explicit timezone and provider preference; every field is re-derived from current server configuration. A result is a feasible whole-booking plan with quoteable offering versions, ordered segments, UTC start/end instants, local display values, resource assignments, configuration fingerprint and short-lived opaque plan ID. It is an offer to attempt a hold, not reserved capacity. Public requests cannot supply prices, durations, staff capability lists, resource allocations or trusted status.

The MVP chooses one provider eligible for all selected offerings. Segments are sequential; each has service duration and explicit before/after resource buffers. Staff is a global resource; chairs/rooms/devices are branch-scoped identified units. Requirements specify resource kind/quantity per offering; unknown requirements do not imply none. Coalesce overlapping/adjacent busy intervals for the same resource into a ledger interval and join it to all relevant segments. Do not insert two overlapping buffers for the same provider and then exempt self-overlap from the exclusion constraint.

Eligibility is the intersection of global qualification, active branch assignment and offering-specific eligibility. Actual availability additionally intersects published staff shifts, branch hours, approved time off/closures, resource activity, occupancy, lead time/horizon and buffer rules. One provider can belong to multiple branches, but shifts and occupied intervals cannot overlap globally. Same-day travel/handoff requirements remain an approval gate; until configured, do not offer a cross-branch schedule requiring an unverified transfer.

## Plan handle protocol proposal

A short-lived, versioned server-authenticated sealed plan handle carries only bounded search selectors, the exact candidate plan hash, configuration fingerprint, issued/expiry instants and nonce; the client treats it as opaque. Validate integrity/key version/expiry before decoding. IDs, dates and resource hints inside it are still selectors: the server regenerates the exact plan and checks its hash. A separate cache can accelerate this computation but is never trusted capacity. A malformed/expired handle fails closed; key rotation retains verification keys only for the accepted short horizon. No client-supplied allocation/status/duration becomes authoritative. The quote hash binds the exact plan content (time, staff, resources, ordering and buffers), item values and resolved policy. A changed feasible plan requires a new explicit quote/consent, not an invisible provider swap.

After acquisition the canonical plan lives in BookingRevision/Items/Segments/ResourceAllocation and the accepted artifact; confirmation/recovery use PostgreSQL rather than the ephemeral handle/cache. Exact sealed-handle format/crypto library/size/rate bounds are a03B security contract gate, not cryptography implemented here.

## Proposed state machine

| From | To | Actor and condition |
| --- | --- | --- |
| DRAFT | HELD | Customer/reception hold command; fresh authoritative quote/config/availability and consent |
| DRAFT | CANCELLED / EXPIRED | Owner of draft, or expiry process; no allocations survive |
| HELD | PENDING_PAYMENT | Workflow; accepted optional/required deposit >0, valid hold |
| HELD | CONFIRMED | Workflow; no deposit owed or separately authorized, consented override |
| HELD / PENDING_PAYMENT | CANCELLED | Customer/reception; cancel under lock, pending receipts still reconciled |
| HELD / PENDING_PAYMENT | EXPIRED | Expiry workflow at DB time, releasing allocations |
| PENDING_PAYMENT | CONFIRMED | Payment workflow; verified required amount, same active revision/hold, still live and valid |
| CONFIRMED | CHECKED_IN | Reception/branch manager |
| CONFIRMED | CANCELLED | Authorized customer/staff command with accepted-policy calculation |
| CONFIRMED | NO_SHOW | Reception/authorized worker after configured attendance/grace rule |
| CHECKED_IN | IN_SERVICE / CANCELLED | Assigned barber starts; manager/reception cancellation with reason |
| IN_SERVICE | COMPLETED | Assigned barber/manager; completion recorded |
| IN_SERVICE | CANCELLED | Owner/manager incident override only, audited financial review |
| COMPLETED / CANCELLED / NO_SHOW / EXPIRED | none | Terminal; correction is a new audited workflow, not a silent resurrection |

Rescheduling CONFIRMED bookings swaps immutable revisions, without pretending there was a new lifecycle transition. Every lifecycle change writes status history, row version, audit and outbox in the same transaction. Historical state edges are also represented in the SQL draft; matching current row/history is a required command/permission gate, not claimed implemented.

## Hold acquisition transaction

1. Authenticate/authorize and claim an idempotency key bound to actor+route+request hash. Same key/body replays the committed result; another body yields 409 IDEMPOTENCY_CONFLICT. Do not trust a frontend slot object.
2. Resolve plan and quote server-side; determine all resource IDs. Start a short SERIALIZABLE transaction and use one shared Prisma transaction context. Lock branch rows in sorted ID order, resource rows in sorted global ID order, then booking/revision/hold and payment/balance rows as needed. All commands touching scheduling/config/cancellation follow the same hierarchy.
3. Re-read active configuration, permissions, shifts, exceptions, resource requirements and accepted quote/terms under locks. A changed unaccepted fingerprint yields 409 QUOTE_STALE; do not silently reprice. Accepted held terms are frozen, but resource availability still needs validation.
4. MVP admission does not inline-reclaim another booking while holding its own resource locks. If an expired blocking hold is found, roll back first; the expiry workflow acquires that booking's complete canonical lock set in a separate transaction, rechecks state/DB clock and releases it. Then retry the original admission boundedly, or return a safe conflict while the durable sweep runs. Never expand a held lock set out of order or delete another owner's live allocation.
5. Persist Booking DRAFT, Revision, Items/Segments, immutable accepted quote-policy evidence and ACTIVE Hold. Insert all coalesced HOLD allocations. GiST exclusion arbitrates even if two independent app instances missed each other's earlier search.
6. Transition HELD, append status/audit/outbox, complete idempotency receipt and commit. Return server expiry. Required/opted-in payment moves to PENDING_PAYMENT through a separate short workflow; no gateway request occurs inside this transaction.

Discover the complete affected branch/resource set before acquiring locks, including old/new revisions and blocking/time-off ownership. After locking, recheck aggregate/config versions and that the discovered set is still complete; if it changed, roll back and recompute instead of acquiring a newly discovered lower-ranked lock. The same rule applies to the reaper and schedule/cancellation edits.

The transition decision uses clock_timestamp() after locks. Define expiry at that linearization point; keep transactions bounded so waiting/network work cannot stretch a claim beyond its promised interval. Clock/transaction timeout configuration and the before/after-expiry boundary must be tested. Never extend a hold merely because a browser spinner or callback exists.

## Confirmation, expiry and concurrency cases

Payment confirmation locks the same branch/resources/booking/hold, checks immutable verified payment evidence, active revision, required amount, accepted terms and expiry, rechecks current operational eligibility and coverage, converts HOLD allocations to BOOKING without releasing the exclusion protection, consumes the hold and writes CONFIRMED/history/outbox atomically. If a changed schedule has not been approved to displace held capacity, reject that schedule edit; emergency closure requires an explicit affected-booking compensation workflow.

The expiry worker lists candidates without taking locks out of order, then runs the same per-booking lock hierarchy and rechecks ACTIVE+expiry. On expiry it releases all live allocations and transitions EXPIRED. A callback after this cannot resurrect the booking. A callback winning before the transition makes the reaper observe CONSUMED/CONFIRMED and do nothing. A missing Redis delayed job cannot strand correctness: periodic PostgreSQL scanning and admission-time conflict/reclaim recovery remain available.

Two customers: both search free; first allocation commits; second waits or fails exclusion 23P01 and receives 409 SLOT_UNAVAILABLE after rollback. SERIALIZABLE failure 40001 or deadlock 40P01 receives bounded whole-transaction retry with the same idempotency key; exhaustion returns a retryable conflict, never a half-created plan. A unique (provider, merchant, transaction reference) prevents duplicate capture records; a unique payment application prevents crediting two captures to one purpose. Neither is a substitute for hold/resource validation.

Schedule/config edits take the same branch/resource locks, inspect affected allocations and reject a conflicting edit (409 SCHEDULE_CONFLICT) unless an authorized explicit cancellation/rebooking plan is provided. Staff time off/maintenance blocks enter the same resource ledger; branch closures lock the branch and validate/release affected plans before blocking resources. Eligibility is never treated as an available shift.

## Cancellation, walk-ins and rescheduling

Cancellation evaluates the accepted snapshot at one server cancellation instant, records an auditable refundable quote, transitions/release occupancy in one transaction and emits a refund-request event. Actual gateway refund is asynchronous. No-show timing is configurable and cannot run before the configured appointment/grace boundary. Completion does not fabricate payment or marketing consent.

Reception may create a WALK_IN with unknown customer identity left null, a real staff actor and an explicit consent/evidence path where terms apply. It still obtains a quote and all resources transactionally. Lead-time exceptions require permission/reason; overlap constraints cannot be bypassed. No fake customer profile or placeholder identity is seeded.

MVP rescheduling changes time/provider for the same accepted commercial terms: lock the union of old/new resources in canonical order, validate the new plan, release old allocations and insert new ones within the same transaction, append a revision/consent linkage and switch active_revision_id. A conflict rolls back, preserving the original reservation. Historical accepted terms/revisions remain. Financial changes or delayed paid reschedule holds need an additional approved saga; do not attempt overlapping old/new self-holds or silently change accepted prices/policies. API rejects unsupported financial renegotiation with 422 RESCHEDULE_REQUIRES_REVIEW until that extension is approved.

## Multi-provider extension

The existing segment/dependency/resource-assignment structures can later hold different providers per service and approved parallel edges. A planner must return one feasible DAG/whole plan, validate per-segment staff/branch capability, cross-resource gaps/buffers and customer concurrency, then reserve the entire resource set atomically. Do not choose unrelated slots independently or relax the current provider intersection to a union. Ordering, parallelizable services, customer occupancy, travel, buffer ownership, partial failure/refund rules and per-segment versus whole-booking policy require business approval before enabling that mode. The UI is unchanged now.

PostgreSQL SERIALIZABLE still requires transaction retries after serialization failures; short transactions and constraint-backed invariants are deliberate design choices ([transaction isolation](https://www.postgresql.org/docs/18/transaction-iso.html)). No concurrency scenario was executed against a working backend in this phase.
