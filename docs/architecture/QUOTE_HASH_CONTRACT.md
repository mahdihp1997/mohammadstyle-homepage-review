# Quote content hash and independent request identity

**PROPOSED / Phase03A architecture hardening only.** No backend, migration, database execution, payment or messaging implementation. Original Homepage/Booking/source/assets/tests are unchanged.

## Decision and exact input contract

Remove UNIQUE(business_id,quote_hash). The key is the quote UUID; business/actor/customer ownership is checked independently. Hash lookup must never serve another actor's quote. Two customers may receive identical valid commercial content and therefore exactly the same digest while holding different quote IDs, expiry times and consent records. Even one actor requesting identical content under two different idempotency keys may create two rows. Nothing consumes availability merely by creating a quote.

hash_version is MS_QUOTE_CONTENT_V2. quote_hash = SHA256(UTF8(RFC8785-JCS(content_document))) stored as32 binary bytes and exposed as64 lowercase hex characters. The **complete allowlist**, including every recursively required key/type, is [quote-content.schema.json](schema/quote-content.schema.json); no unspecified field enters the hash and no unknown field is accepted. Every required nullable value is explicit null. Do not hash JSONB's text representation or an ORM object with incidental properties. Persist the immutable content_document so integrity is reproducible without an ephemeral plan token/cache.

| Included fields | Exact role |
| --- | --- |
| schema,businessId,branchId,source,currency,unitVersion | Algorithm domain/version and business/commercial unit; source must SERVER |
| configurationFingerprint,timeZone,startsAt,endsAt | Versioned configuration, IANA timezone and exact candidate UTC interval |
| optionalDepositChosen,totalRial,depositRial,remainingRial | Explicit choice and exact integer commercial amounts |
| items[] | position,offeringId,serviceId,packageId,offeringVersion,quantity,displayName,unitPriceRial,durationMinutes,bufferBeforeMinutes,bufferAfterMinutes |
| segments[] | sequence,quoteItemPosition,offeringId,staffId,startsAt,endsAt,durationMinutes,bufferBeforeMinutes,bufferAfterMinutes,resources[],dependsOnSequences[] |
| resources[] | resourceId,kind for the actual candidate allocation; no mutable availability status |
| policy | versionId,versionNumber,contentHash,snapshotHash,resolverVersion,sourceAssignments[] |
| sourceAssignments[] | quoteItemPosition,assignmentId; binds the actual policy routing used for each item |

The policy snapshotHash binds the complete separately persisted resolved policy artifact, including disclosed terms/locale/windows/bounds; it cannot point at mutable current policy text. Source assignments bind routing evidence. The planner snapshots the actual chosen provider/resources, not a union of potential eligible providers. Whole-plan ordering/buffers and commercial displayName are integrity-relevant.

## Canonicalization and semantic validation

Use a reviewed RFC8785 implementation in03B; these static vectors exercise only our restricted strings/booleans/null/arrays/objects domain. All integer values inside the hash document are canonical unsigned decimal **strings**, including positions, quantities, versions, minutes and money. Zero has one spelling; no signs/exponents/leading zeros/floating arithmetic. Amounts remain bigint-bounded and whole-Toman-compatible per ADR007. All instants use validated UTC YYYY-MM-DDTHH:mm:ss.SSSZ, timezone is a verified IANA name, UUIDs and hex hashes lowercase. Reject duplicate JSON property names before object construction, invalid Unicode/lone surrogates and invalid dates. Never normalize/change a string after acceptance; JCS itself does not perform Unicode normalization ([RFC8785](https://www.rfc-editor.org/rfc/rfc8785.html)).

Normalize arrays before computing: items by numeric position (contiguous1..n); segments by numeric sequence (contiguous1..n); resources by resourceId then kind, duplicates rejected; dependencies by numeric sequence, duplicates rejected; sourceAssignments by numeric quoteItemPosition then assignmentId, duplicate pairs rejected. Array order otherwise carries meaning and is not blindly sorted lexically. All references, durations, sums, containment, same provider/sequential MVP and policy-artifact equality must match the relational snapshot. Verify exact hash/document/row equality inside creation/acceptance transactions and freeze them with grants/content guards later. A hash CHECK cannot establish these cross-row facts.

## Excluded identity and envelope data

quote.id, customer_id, created_by/actor/session, booking/draft/revision/hold/payment IDs, Idempotency-Key, requestId, current availability request key, random plan-handle nonce/token ID, created_at/issuedAt, expires_at, consent timestamp and mutable workflow status are **not content hash input**. Other PII, gateway secrets and translated UI formatting are not in the payload. A booking-specific policy assignment may legitimately yield different source/version content; this does not make hash uniqueness safe.

Expiry is enforced against the actor-owned row using DB time and immutable server-owned metadata; the content digest is not a signature/authentication mechanism and deliberately does not authenticate TTL or ownership. Signed plan handles remain separately verified. Quote copies cannot extend expiry by reusing a hash. Acceptance binds the exact quote ID + content hash + policy hash, not a global digest lookup.

## Idempotency remains separate

idempotency_record is scoped by authenticated actor/business, route and Idempotency-Key, with its own canonical **request** hash and committed response/quote ID. Same key/body replays the original quote including original expiry. Same key/different body returns409 IDEMPOTENCY_CONFLICT. Another actor/key may create a different quote with identical content hash. Repeated expired-key replays do not create fresh capacity or extend TTL; the client must explicitly obtain a new quote under the documented retry lifecycle. This is not deduplication by content.

## Required scenarios

V19–V21 cover independent customers, same-key replay/mismatch, TTL/ownership and canonical mutation. [Static vectors](schema/quote-hash-vectors.json) are synthetic, never prices/staff/policies/customer production seed data. The32-byte/hash-version/JSON-object draft checks are local guards only; hash recomputation, ownership and snapshot equality require future transaction tests. No request or real quote was executed against a backend in03A.
