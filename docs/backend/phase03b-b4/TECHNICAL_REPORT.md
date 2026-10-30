# Phase03B-B4 technical report

## Result

An authenticated verified synthetic customer can select a configured branch, multiple services, one common qualified provider or no preference, an actual feasible slot, read the immutable final quote and explicitly accept its exact terms. Admission persists a booking revision, service/resource plan, bounded hold and consent in PostgreSQL. Explicit NONE / declined OPTIONAL with zero deposit can confirm. Required or chosen deposits remain PENDING_PAYMENT, including a required percentage rounded to zero. There is no payment success, real settlement, SMS or production deployment.

## Application flow and contracts

1. Existing SessionGuard, exact Origin/CSRF/JSON, verified auth_identity and tenant-derived membership protect B4. Customer ownership is checked for every plan, quote, booking, event and cancellation target. There is no HTTP login/provisioning endpoint. Trusted CLI fixtures use a separately marked disposable profile and clearly synthetic identities/configuration.
2. Availability reads published shifts and branch hours; checks current membership, verified service qualifications and per-offering eligibility, conservative cross-branch restrictions, leaf time-off/closures, one-provider intersection, identified CHAIR/ROOM/DEVICE units, quantities and buffers. IANA conversion rejects gaps and ambiguous folds; Jalali is presentation. Missing configuration fails closed. Up to six complete feasible plans are returned per bounded cursor page.
3. Availability handles reference immutable, actor-owned PostgreSQL plan rows. Quote creation and hold admission regenerate the complete plan from current database rows, run unchanged B3 pricing/routing again, compare configuration/plan/terms and check expiry with the DB clock again after calculation. Client amounts, durations, resource lists and arbitrary slot objects are never accepted.
4. MS_QUOTE_CONTENT_V2 uses the approved exact field set and canonical hash validator. Frozen policy resolution binds human terms, locale, effective dates, all bounds/refund windows and underlying routing evidence. Final per-item policy sources never reuse the commercial proposal's position-zero source shape. Quote UUID/owner/TTL/idempotency identity remain separate from the nonunique content digest.
5. Draft → hold admission atomically creates an immutable revision/segments, coalesced global resource allocations, accepted quote+snapshot hashes, status history, audit/outbox and actor/key receipt. A content digest is neither authorization nor a signature. Revisionless DRAFT can cancel/expire; committed terminal bookings retain their revision.
6. Confirmation closes only an explicitly permitted non-payment hold. A required/chosen deposit is never fabricated as paid. Expiry and cancellation release capacity atomically. Cancellation previews use the accepted policy and current DB time; actual paid/refund amounts are zero because no payment ledger exists.
7. Rescheduling is a same-branch, exact-commercial-item/terms, explicit non-payment operation. It locks the complete resource set, releases old allocations and admits a new immutable revision atomically. Failure restores the old reservation. An unpaid hold retains its original expiry; confirmed non-payment reservations stay confirmed. Financial or policy changes require review.

## Transaction and database evidence

14 checksummed migrations;0001–0011 remain byte-identical. Three dependency-closed forward migrations add12 tables, not the full72-table draft. Actual catalog: 50 tables / 143 FKs / 160 CHECKs / 158 indexes / 50 functions /4 exclusions; API role has11 reviewed EXECUTE entry points, no owner membership, public/private-helper execution or new table grants. Catalog fingerprint: 51cc54f8b2be350237645d2f3dbbcfa2d9cc32931a97ef0feecfbee712bc1cda.

The B4 repository uses SERIALIZABLE and at most3 attempts for40001/40P01. It authenticates before pricing-revision / inherited B2B business mutex / sorted branch / sorted global resource / booking locks. The coarse complete business resource set also covers rescheduling and expiry; it is conservative and intentionally favors correctness. Native global GiST resource exclusion is authoritative even if the advisory path is bypassed by a trusted test.23P01 maps to409. Unknown transport outcomes return503; clients retry the same durable key. Replays retain original identity/version/expiry and never extend a lease.

Actual races include two customers/different staff/shared chair+room/device, same-key admission, a resource writer versus admission, native two-session GiST blocking/23P01, and natural hold expiry versus confirm/cancel. Failure injection proves revision/consent/allocation/history/audit/outbox/idempotency rollback, including rollback of a reschedule release. Named cases and results are in TEST_RESULTS.md and evidence/.

The actual pg_dump custom backup was restored to a separately created database. Ordered fingerprints of all50 tables, schema history, native definitions and grants matched. Archive SHA256: ca99dae28a27849aad2b5b155139ca5194780c4a505770e462f14b5946819382; 705815 bytes. The restored SQL/runtime ownership and history boundary passed. Dump and credentials are omitted. No production migration or production concurrency claim is made; static parser validation is separately recorded.

## Frontend and intentional implementation differences

The original Homepage and DEMO reducer/provider/calculations/policies/tests remain unchanged. Existing CSS, Stepper and JalaliCalendar are reused. Stepper only gains optional disabled/label props with the old defaults. SERVER has truthful loading/error/focus feedback, context-bound slot results, BigInt Rial display, complete frozen terms/consent, status/history, cancellation review and safe rescheduling. Its review sidebar contains no client photograph. All four requested viewport sizes have genuine full-page and above-fold captures.

The approved design described signed self-contained plan handles. B4 instead uses immutable server-persisted opaque UUID references with mandatory tenant/owner/TTL lookup and full recalculation. This preserves server authentication of plan evidence without treating a digest or bearer handle as permission; it requires database access. Final quotes and exact hash semantics are unchanged. Booking items are obtained through their immutable revision→quote relationship rather than a duplicate booking_item copy. Verified app_user ownership is used; a separate PII customer-profile table is deferred.

Deliberate conservative limits: one provider, one local day, minute precision, ambiguous folds/overnight and unreviewed transfers fail closed; configured physical requirements must be present/confirmed; up to32 candidate providers and16 units per kind; page size6. Current/future accepted allocations freeze workforce/configuration writes for the business until cancellation/expiry/review. Historical past ranges do not freeze future configuration. Fine-grained non-displacing edits and emergency compensation need a later approved design. Rescheduling requires exact item snapshots, versions and terms; it does not recalculate an accepted financial agreement silently.

## Concrete wire adaptation

REST_MAPPING.md maps the preserved03A proposal to B3-style authenticated local command/read POSTs, exact body-version CAS and persistent owned plan references. Public stateless search and the proposed external REST facade remain disabled; their wire strategy needs approval before production integration. No exact implementation of every proposed REST path is claimed. All B4 customer actions above are implemented and tested through the concrete local contract.

## Delivery boundary

Private source branch: feature/phase03b-b4-booking, from e74bec2fd6a08f280070d02ecb0ea9d7a2ec4070. Public review/phase03b-b4 is an independent sanitized export on public8b0a0df64bd3e87e76892bd0ba8cd0f36a3e38dc / review/phase03b-b3. Public placeholders/system fonts and all prior PRs are preserved. Final commit/PR/CI receipts are supplied in the owner package after delivery. No PR is merged, no private history/assets/credentials/dump are exported and no next phase begins.

The optional-deposit choice and consent are cleared when branch, services, provider or date changes. An actual OPTIONAL-to-NONE provider transition is tested at all four viewports against the database/API, alongside the full reservation flow and missing-authentication recovery.
