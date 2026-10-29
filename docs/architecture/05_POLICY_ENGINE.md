# 05 — Configurable booking policy engine

**PROPOSED / REVIEW REQUIRED — Phase 03A specification only.** No backend, database, migration, gateway or notification service was installed or executed. The private Phase 02 frontend remains canonical and unchanged.

## Separate concepts and immutable evidence

BookingPolicy is a named definition. BookingPolicyVersion is a numbered rule/terms document with lifecycle, effective window, deposit and refund fields plus relational refund windows. BookingPolicyAssignment routes a version to business, branch, service, package, specific booking or permissioned override scope. QuotePolicyResolution records the chosen version, matching source assignments, resolver version and canonical resolved artifact/hash. BookingPolicyAcceptance records explicit consent to that exact quote/revision/artifact, not simply a mutable policy ID. Refund calculation uses accepted evidence; Payment/Refund execution is a separate module.

Lifecycle: DRAFT can be edited with version checks; publishing validates all fields/conflicts, sets content hash and makes content/refund windows immutable. ACTIVE versions can serve matching assignments/effective dates. SUPERSEDED/RETIRED versions remain readable for historical accepted bookings, with no new routing. Activation/routing/lifecycle metadata changes are audited; never rewrite accepted rules, snapshot or old evidence. Retiring an open-ended version closes/revokes its assignment for future resolutions or publishes a replacement; it does not edit old accepted content. A service configuration or policy change invalidates an unaccepted quote, while accepted live terms require explicit replacement consent for material changes.

## Rule representation

Deposit NONE, OPTIONAL, REQUIRED. Amount FIXED integer Rial or PERCENTAGE integer basis points; optional min/max integer Rial bounds. NONE carries no hidden amount. Clamp to configured min/max only when the version explicitly contains them; a resulting amount greater than total is a configuration error (422 POLICY_UNCALCULABLE), not a negative remainder or silent clamp to total. Optional deposit requires an explicit customer choice. Version publication rejects contradictory amount fields/min>max/out-of-range bps.

Refund modes FULL/NONE/PARTIAL/CONDITIONAL use a configured refund base (DEPOSIT_PAID or ALL_PAID) and ordered threshold windows. At cancellation, calculate whole minutes before the original scheduled start using accepted instants; thresholds are inclusive. Choose the greatest threshold not exceeding minutes-before-start; otherwise use outside_refund_bps. After-start cancellation falls outside. Bound refundable money by actually captured/unrefunded funds; pending/unknown refunds remain reserved. Rounding/unit rules follow ADR-007. No frontend clock, current admin policy or queue time determines the entitlement.

Publication validation additionally defines FULL as10000bps with no thresholds, NONE as0bps with no thresholds, PARTIAL as an explicit0<bps<10000 flat refund with no thresholds, and CONDITIONAL as configured threshold rows plus explicit outside rate. These are proposed semantics; actual terms require review. Cross-row window/mode consistency is a publication gate. Draft policy versions carry row_version/updated_at for If-Match; published content/windows freeze while audited lifecycle metadata may change.

## Deterministic resolution proposal

Capture one resolution instant and input context. Filter business, active/published version, version+assignment effective windows and matching configured targets. Ignore revoked routing; reject missing verified default/configuration rather than inventing non-refundable/no-deposit terms. Sort lexicographically: ADMIN_OVERRIDE > BOOKING > PACKAGE > SERVICE > BRANCH > BUSINESS; then explicit branch specificity; then explicit priority within the same rank. Priority never promotes a business rule above a service rule. Equal-ranked, equally specific winning assignments to different versions are POLICY_CONFLICT, not a lexical UUID winner. The SQL exclusion blocks same exact scope+priority+overlapping assignment windows; the resolver must still catch overlapping broader/specific/multi-item conflicts.

Whole-booking ADMIN_OVERRIDE/BOOKING can deliberately select one version for all items. Otherwise resolve each quote item (including package context) independently. A whole-booking quote can proceed only if all items resolve to the same version, or a reviewed explicit whole-booking version overrides them. Do not silently combine deposits, take the harshest cancellation rule or apply one service's policy to unrelated services. Mixed-package/add-on ambiguity is a conflict until explicitly configured. Source assignments are recorded relationally; canonical snapshot/hash includes amount, bounds, thresholds, base, text/locale, effective context and resolver version.

## Hypothetical examples — not salon rules

| Configuration | Result |
| --- | --- |
| Business A/v1; selected branch routes B/v2 | B/v2 wins branch over business |
| Branch B/v2; hair service C/v3; hair only | C/v3 wins service rank |
| Hair C/v3 plus facial falling back to B/v2 | POLICY_CONFLICT: heterogeneous whole-booking terms; no automatic merge |
| Exact selected package routes P/v4 and member service C/v3 | Package rank wins for those package members; unrelated add-on may still conflict |
| Same branch/scope/priority overlapping assignments | Publishing rejected by exclusion/conflict validation |
| Manager attempts override without policy.override permission/reason | 403; no assignment/acceptance change |
| Authorized whole-booking override O/v5, customer sees/accepts new quote | O/v5 wins explicitly; original evidence retained |
| Owner retires a previously accepted non-refundable v1, publishes refundable v2 | Old booking uses v1 evidence; statutory/customer-rights exceptions and explicit beneficial overrides are separately audited |

Specific-booking overrides require an existing draft/booking identity. Initial public quotes cannot claim an invented booking scope. Admin overrides require least privilege, target/reason/effective window, conflict checks and audit; any material accepted-term change requires explicit customer re-consent. Permission to configure policies is separate from permission to issue refunds.

## Non-refundable conditions and compliance gate

The system can represent a zero-refund/non-refundable deposit; representation is not a legal conclusion. Applicable jurisdiction, consumer remedies, proportionality/penalties, disclosure, cancellation causes and statutory exceptions must be reviewed by qualified local counsel before enabling such terms. Clear pre-payment text, locale/version, affirmative consent and evidence are required; no preselected consent or policy hidden behind a mutable link. For illustration only, UK consumer guidance explains that retaining advance payments can be limited by fairness/loss considerations; it does not determine the law applicable to this Tehran business ([CMA guidance](https://www.gov.uk/government/publications/cancelling-goods-or-services-guide-for-consumers/cancelling-goods-or-services)).

No Iranian-law enforceability claim, real cancellation cutoff or deposit amount is supplied here. Legal override/dispute/mandatory refund decisions require authorized documented review, independent of the arithmetic engine. Accepted snapshots must remain available even after policies are retired; privacy/financial retention requirements need an approved schedule. No real Policy Engine implementation was created.
