# 06 — Pricing, payments and refunds

**PROPOSAL / ARCHITECTURE ONLY.** No implementation, real booking, payment, external message, database service or migration was executed.

## Integer currency decision (proposed, gated)

Use signed PostgreSQL bigint for integer Rial with explicit currency_code=IRR and unit_version=IRR_RIAL_V1. Positive amounts are bounded to the signed bigint range. API monetary amounts are decimal **strings**, never IEEE-754 numbers. Version the unit separately from ISO currency code so redenomination cannot silently rescale old receipts. Before production, confirm the operational meaning of Rial/Toman and the actual gateway's units with the owner/merchant; no statement here decides a currency reform or assumes a gateway's current API.

The existing frontend's priceToman is an integer Number and its positive Math.round examples round at whole Toman. Proposed compatibility rule: one current UI Toman maps explicitly to ten v1 Rial; MVP configured prices, deposit bounds, charges and refunds must be multiples of ten Rial. Compute percentage deposits with integer round-half-up to a whole Toman, then multiply by ten. For nonnegative totalRial and bps: depositToman = floor((totalRial * bps + 50000) / 100000), depositRial = depositToman * 10, using arbitrary-precision integers for intermediates. Fixed/min/max values are likewise unit-tagged whole-Toman-compatible Rial. This preserves positive frontend example semantics without trusting its calculation.

An adapter converts only exactly divisible, Number-safe Rial values to priceToman; it rejects rather than truncates overflow or fractions. Future sub-Toman values/multicurrency require a reviewed versioned DTO/display change. No floating exchange rate, decimals, automatic rounding at gateway callback or unversioned unit inference. The gateway adapter declares its request/verification units and applies an exact checked conversion both ways. Frontend display values, bank receipt units and accounting units must never be assumed interchangeable.

## Quotation and acceptance

The server derives offering price/duration/buffers and policy from verified configuration. Quote/items/resolution are immutable with TTL, fingerprint and content hash. Quote total, deposit and remainder must add exactly; a missing value or min-deposit exceeding total blocks issuance. Service configuration/defaults/demo data cannot fill a production quote. Consent binds the quote hash and policy artifact to an actual booking revision. Unaccepted stale quotes return a new explicit quote for re-consent, not silent replacement. Tax, discounts, fees, invoices and any cash-credit adjustment remain open unless separately configured; do not invent a salon tax rate.

## Payment intent and verified capture

Create an intent only for positive deposit/remainder actually due, after an authorized current booking/hold check. Persist intent, stable provider idempotency key and outbox before external initiation. A zero-deposit flow does not fabricate a successful payment. Gateway initialization occurs outside locks; use a durable result update and bounded retry. If initialization outcome is unknown, query/reconcile with the same provider operation key before retrying a charge.

The browser redirect and unauthenticated callback content are untrusted signals. Store a deduplicated redacted gateway event; authenticate the provider by its selected protocol, then perform server-to-server verification of merchant, transaction reference, exact unit/amount, intent ownership and payment status. Callback route returns no customer or financial detail to an unauthenticated sender. A unique global provider/merchant/transaction reference protects receipts even if a merchant is reused across business contexts. Different valid extra captures are recorded, not discarded as an inconvenient duplicate; they become unapplied compensation/reconciliation cases.

PaymentTransaction is immutable verified money evidence; PaymentApplication credits at most one capture to a revision/purpose. PaymentBalance stores locked refund reservations/completions with a CHECK ceiling. FinancialAuditRecord is an immutable operational cash-event trail, **not a claim to a complete double-entry accounting system**. General accounting/tax exports are a later integration.

An outer workflow handles PaymentCaptured: lock branch/resources/booking/hold, then intent/capture/balance, revalidate active revision, accepted terms, expiry and required amount, apply the capture and confirm the booking atomically. PaymentsModule never imports BookingModule back; Booking core never imports Payments. A failed transaction rolls back the application/confirmation, not the external captured money. The durable capture remains available for retry/reconciliation.

## Failure paths and reconciliation

| Situation | Required result |
| --- | --- |
| Same callback repeated/concurrent | One verified receipt/application; replay acknowledged without a second confirmation |
| Payment verifies before expiry; DB outage after external success | Durable gateway/provider reconciliation retries; no success claim until booking confirmation is durable |
| Hold expired or resources cannot be confirmed after payment | Do not resurrect or double-book. Record COMPENSATION_REQUIRED, request full unapplied-capture refund/void as supported, show paid-but-not-booked/refund-pending state |
| Amount/unit/merchant/reference mismatch | No application or booking confirmation; quarantine/reconciliation alert with redacted evidence |
| Two distinct captures for one purpose | One application; record and compensate surplus captures |
| Callback arrives for a superseded revision | Cannot confirm current booking with stale terms; reconcile/compensate that capture |
| Refund timeout/ambiguous provider response | Keep budget reserved, mark UNKNOWN, query provider; never release and issue a new refund blindly |

Full compensation of an unapplied successful capture is a technical obligation proposed independently of a non-refundable **accepted booking** deposit. Actual void/refund capabilities, timing and legal remedies depend on the selected provider and applicable rules; no immediate gateway refund is promised. A reconciliation worker compares intent, receipt, application, balance, refund and provider settlement records. Unresolved discrepancies alert authorized finance/owner staff, not arbitrary barbers.

## Cancellation refund transaction

Calculate entitlement from accepted terms, original booked instants and actual paid base at one server cancellation instant. Record a refund request and lock PaymentBalance. Reserve proposed amount atomically only if completed+reserved+new ≤ captured; duplicate operation keys replay the same refund. An authorized worker invokes the provider outside the DB transaction with refund.id as a stable idempotency key. Verified success moves reserved→refunded and appends ledger/outbox; definitive failure releases reservation, ambiguous status retains it. Partial/multiple refunds cannot exceed the original capture. An administrative override requires permission, reason, recorded calculation and any required approval; configuring policy does not authorize executing a refund.

Payment expiry is separate from hold expiry. Intent expiry does not erase a later actual capture; late money is recorded and compensated. Required-deposit production rollout is blocked until duplicate callbacks, timeout, lost response, late success, partial refund and reconciliation cases are exercised against the selected sandbox. Phase 03A only specifies these flows. See payment-sequence.svg and ADR-007.


Quote hash identity is explicitly content-only and non-unique; see QUOTE_HASH_CONTRACT.md. Captures/applications reference actor-owned quote/revision IDs, not a global hash dedup lookup. Mixed-policy money allocation is not implemented or silently aggregated; owner alternatives and extra ledger requirements are in MULTI_SERVICE_POLICY_OPTIONS.md.
