# Mixed service policy strategy — owner decision pending

**PROPOSED / Phase03A architecture hardening only.** No backend, migration, database execution, payment or messaging implementation. Original Homepage/Booking/source/assets/tests are unchanged.

Different service-level winning deposit/refund policies in one booking are a **business decision**, not an implementation detail. The owner has not selected an aggregation strategy. Current proposed engineering guard remains409 POLICY_CONFLICT for heterogeneous winners; no charge/hold/acceptance proceeds with invented combined terms. Equal policy IDs/versions are required by that guard, not merely equal numeric deposits. An unrelated service/branch/booking override cannot leak into the context.

| Alternative for owner review | Deposit/refund behavior requiring approval | Data/workflow consequences | Trade-off |
| --- | --- | --- | --- |
| A. Explicit unified whole-booking policy | Owner configures a single disclosed policy applicable to the selected combination; customer accepts it | Current whole-booking resolution/snapshot model can represent this, with explicit authorized routing/override | Simple totals/terms, but owner must decide which whole-booking terms are appropriate; do not auto-pick a service's policy |
| B. Per-service policy snapshots and allocated money | Each item retains its own deposit/refund terms; aggregation, optional deposits, fixed amounts/min/max and cancellation must be defined | Requires per-item resolution/acceptance plus capture/refund allocation records, whole-capture ceiling and reproducible rounding; current72-table envelope does not yet model the whole extension | Flexible but materially more complex, especially packages, partial cancellation, fees and multiple captures |
| C. Separate bookings under an explicit booking group | Each booking uses one policy; owner decides whether group holds/payments/cancellation are atomic or independent | Needs group/order/coordinator and reviewed all-or-nothing/saga/compensation behavior; not currently implemented/schema-complete | Clear per-booking terms but more appointments/payments/customer friction and partial-failure decisions |
| D. Disallow mixed-policy combinations | Customer selects a compatible set or separately books according to an owner-approved rule | Existing fail-closed guard can remain; copy/availability suggestions need later approved UI integration | Least complexity, limits combinations; temporary safety guard does not mean owner has approved this permanent business rule |

No alternative is selected by this hardening task. A permissioned whole-booking override is an explicit proposal under A, never automatic conflict resolution. Publishing such terms requires authority/reason/scope/legal review and customer re-consent; policy configuration alone cannot authorize a refund/charge. No highest-deposit/strictest-refund/first-service/majority/lexical-ID merge is allowed.

## Decision checklist

Owner must choose the supported combination strategy; define whole versus item optional-deposit choice; fixed/min/max basis and application count; package/add-on attribution; discount/tax/fee allocation (none invented); rounding/remainder and capture allocation; partial cancellation/no-show/refund base and original-time boundaries; payment/refund evidence; group atomicity; explicit customer disclosure and legal exceptions. For B, the sum of per-item reserved/completed refunds must also obey every capture's total ceiling. Competing services cannot each refund the same captured money. For C, a failed second payment cannot leave a misleading all-confirmed group.

Record the owner's selected strategy and legal/consent terms in a superseding ADR before changing the guard/schema/API/UI. Until then heterogeneous resolution409 is the only permitted technical behavior. V29 specifies this guard and extension gates without claiming business-rule or runtime-policy approval.
