# Actual verification results

| Suite | Result |
|---|---|
| B4 core PostgreSQL/Nest |44 PASS /0 FAIL /35 expected denials|
| B4 additional boundaries |14 PASS /0 FAIL|
| B3 original |78 PASS /0 FAIL|
| B2H original |42 PASS /0 FAIL|
| B2B original |71 PASS /0 FAIL|
| B2A original |69 PASS /0 FAIL|
| B1B original |83 PASS /0 FAIL|
| B1A original |47 PASS /0 FAIL|
| B0 original |14 backend +35 SQL +Prisma probe PASS|
| Existing frontend |92 PASS /0 unexpected /0 flaky|
| SERVER frontend |12 PASS /0 unexpected /0 flaky, four viewports|
| Fresh/upgrade/no-op/rollback/catalog/grants |PASS on PostgreSQL18|
| Custom backup/separate restore |all50 tables/catalog/grants match|
| Old source/databases |478 protected files,11 original migration bytes and6 databases unchanged|

## Current named B4 cases

- PASS eleven-to-fourteen upgrade preserves B3 data and leaves all gates disabled
- PASS unconfigured branch cannot activate and failed activation rolls back all gates
- PASS ordinary customer cannot activate a branch
- PASS explicit reviewed activation proves complete future published capacity
- PASS gates cannot be enabled by ordinary runtime SQL or legacy implicit path
- PASS missing configuration and no approved verified identity fail closed
- PASS real multi-service availability has a single eligible provider and correct IANA date
- PASS selected provider is authoritative; forged provider returns no slots
- PASS slot objects, client prices and resource lists are rejected
- PASS final V2 has exact hash, normalized segments, dependency chain and frozen policy resolution
- PASS independent owners can receive identical quote hashes without unique conflict
- PASS commercial B3 proposals cannot substitute for verified final quotes
- PASS stale workforce snapshots cannot be quoted
- PASS stale price/policy context is revalidated at hold time
- PASS buffers and opening hours constrain the full busy envelope
- PASS legacy/unreviewed closure suppresses overlapping slots and restores after removal
- PASS unreviewed time off blocks the selected provider, not another eligible provider
- PASS missing physical device or staff qualification fails closed
- PASS revisionless draft cancellation is representable without dropping history
- PASS explicit exact-term acceptance is mandatory and tampered hashes are denied
- PASS outbox failure atomically rolls back hold, revision, consent and allocations
- PASS two authenticated concurrent sessions cannot hold the same multi-service capacity
- PASS adjacent per-service buffers are coalesced, native ledger has no live overlap
- PASS schedule/resource edits cannot displace accepted live capacity
- PASS ownership is enforced for reads, confirmation, cancellation and history
- PASS eligible zero-deposit confirmation preserves allocations and accepted snapshot
- PASS idempotent replay returns original identity/version/expiry without extending lease
- PASS native GiST exclusion arbitrates conflicting writes from two independent PostgreSQL sessions
- PASS controlled reschedule atomically replaces revision and capacity with identical accepted commercial terms
- PASS failed reschedule rolls back release and keeps original reservation intact
- PASS cancellation preview uses frozen policy and reports zero actual money movement
- PASS cancellation releases all resources and capacity is immediately reusable
- PASS required deposit cannot be fabricated into confirmed payment or rescheduled financially
- PASS unconfigured policy and incompatible service policies fail closed
- PASS forged quote documents and accepted snapshots remain immutable
- PASS expired hold reaper and competing cancellation/confirmation release exactly once
- PASS stale availability loses to capacity admitted after quote; no forged draft enters ledger
- PASS actual Nest catalog/availability/quote/draft/consent/hold/confirm/cancel flow
- PASS Nest rejects absent session, CSRF, invalid Origin, injected price and unknown operation
- PASS unknown tenant and quote identifiers cannot widen identity scope
- PASS fresh fourteen-migration install, no-op, catalog/grants and all eleven byte hashes
- PASS failed forward migration rolls DDL and metadata back
- PASS real pg_dump custom backup and separate restore match all50 table/catalog fingerprints
- PASS restored runtime ownership and frozen history remain functional
- PASS pagination covers later feasible times without accepting a forged cursor
- PASS retained published work at another branch conservatively blocks transfer
- PASS physical quantity requirements cannot reuse one device twice
- PASS inactive membership removes the provider from whole-booking applicability
- PASS active offering cannot lose a required price at the database boundary
- PASS no policy produces no final quote or slots, never a hidden default
- PASS policy routing changes stale an unaccepted final quote without rewriting its terms
- PASS revisionless persisted DRAFT can expire without a fictional active revision
- PASS two concurrent same-key holds replay one revision and one original TTL
- PASS schedule writer racing admission cannot deactivate capacity under a successful hold
- PASS required percentage rounded to zero is never silently confirmed without payment approval
- PASS expired quote is refused with server clock even when the client retains its handle
- PASS current session revocation prevents status changes despite retained CSRF
- PASS two fully configured branches can hold the same instant with distinct staff and branch resources

## Recorded races

```json
[
  {
    "scenario": "two customers / different staff / shared chair + multi-service room/device",
    "separatePooledSessions": true,
    "winners": 1,
    "losers": 1,
    "loser": "MS409"
  },
  {
    "scenario": "native exclusion independent sessions, advisory lock deliberately bypassed by trusted test",
    "blockedSessionsObserved": 1,
    "winners": 1,
    "sqlstate": "23P01"
  },
  {
    "scenario": "natural TTL / expiry sweep / confirm / cancel",
    "ttlSeconds": 30,
    "verifiedAt": "2026-10-30T10:46:36.099Z",
    "expiresAt": "2026-10-30T10:46:35.732Z",
    "finalStatus": "EXPIRED",
    "results": [
      "fulfilled",
      "rejected",
      "rejected"
    ]
  },
  {
    "scenario": "same-key concurrent admission",
    "responses": 2,
    "revisions": 1,
    "expiryUnchanged": true
  },
  {
    "scenario": "resource writer vs hold",
    "bothSucceeded": false,
    "outcomes": [
      "MS409",
      "committed"
    ]
  },
  {
    "scenario": "two configured branches / same instant / independent staff and physical units",
    "successfulHolds": 2,
    "wrongBranchAllocations": 0,
    "branchPricesRial": [
      "300000",
      "400000"
    ]
  }
]
```

Initial development iterations caught SQL alias/operator/generated-field issues and slow candidate scanning. Feasibility is now pruned before the complete B3 calculation and availability is bounded/paginated. npm ci recovered from a host cache stat error by using a separate task cache without changing lockfiles. The first frontend attempt could not launch absent bundled Chromium; the unchanged92-test rerun using installed Chrome passed. Browser testing exposed Next15 internal-host normalization; the proxy now checks original exact Host/Origin. Those failed/interrupted attempts are not presented as final passing Next.js QA. Source changes were rechecked with the current tests. GitHub CI receipts are separately delivered after the public commit.
