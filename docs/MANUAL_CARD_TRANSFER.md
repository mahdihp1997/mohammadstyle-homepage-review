# Manual card transfer and receipt operations

This is an additional method on the existing payment ledger. `NONE` is the
initial configuration. Online and manual methods can be enabled independently
for a business or branch; an explicit branch inheritance record is versioned.
An unconfigured gateway is never enabled by a switch in the browser. A required
deposit without an eligible method fails closed before capacity admission.

## Destination cards

Only a bank name, recipient name and validated 16-digit PAN are collected.
Persian/Arabic digits and separators are normalized; checksum and repeated-digit
inputs are checked. No CVV, expiry, banking password, PIN or bank OTP is accepted.
PAN and recipient are authenticated encrypted with purpose/business/card/version
binding. A keyed fingerprint supports duplicate checks; list views are masked.
Card scopes, priorities and archive state are versioned. Each payment freezes its
exact destination version; later changes do not rewrite financial history.

## Settlement and capacity

Uploading an image records evidence, not payment. A reviewer needs the current
branch permission and a password/TOTP session authenticated within 15 minutes.
Approval requires a separate bank-statement attestation, actual integer Rial,
bank reference and arrival time. The decision records the reviewer and server
decision time. An image is never treated as independent proof of arrival.

`MANUAL_BANK_RECONCILED` and `PROVIDER_VERIFIED` remain distinct common receipt
sources. A keyed destination fingerprint/reference pair cannot settle two
payments, including across Booking and Order targets. Amount, date and customer
are deliberately excluded from that duplicate identity.

The existing business lock and B4 resource exclusions remain authoritative.
Settlement checks the current revision, original unexpired hold and allocations
after obtaining locks. Rejection/resubmission does not extend the deadline.
Late, mismatched or closed-target funds are retained as actual financial evidence
and sent to review; expired capacity/stock is never recreated. Manual refunds do
not enter an unsupported automatic gateway execution path. An Order never creates
a synthetic Booking or service row to use the ledger.

Permanent actor/operation/idempotency records bind the normalized semantic
request, excluding randomized encryption bytes. Callback routing returns only one
of two fixed account-history paths and still requests independent verification;
it never confirms payment from browser parameters.

## Private receipts

JPEG/PNG/WebP bytes are decoded, not trusted by extension or declared MIME.
Limits are 5 MiB, 25 million pixels, 12,000 pixels per side and one frame. Native
processing has a concurrency bound. The original and metadata-stripped WebP are
both immutable and AES-GCM encrypted with business/receipt/kind binding, beneath
a separate `receipts/` storage namespace. They never enter Portfolio CMS.

Both Next and Nest repeat session/CSRF/ownership/state admission before buffering
the larger upload body. Authenticated display uses an ownership or branch-finance
check, restrictive image headers and no public object URL. Object and plaintext
hashes are checked again on reading. Same-key storage retries read and verify the
existing encrypted object rather than overwriting a random-IV ciphertext.

Receipts and sensitive identifiers are excluded from logs and public review
artifacts. Uncommitted orphan objects are unreferenced and cannot be displayed;
storage inventory/housekeeping must preserve in-flight idempotent uploads and
must not treat absence from a single concurrent snapshot as deletion permission.

## Backup and retention

`backend/scripts/product/backup.mjs` takes a real PostgreSQL exported snapshot,
encrypted custom dump, authenticated manifest and every referenced original and
derivative object, including receipts. Restore authenticates every archive byte
before PostgreSQL restore, requires an explicitly named empty offline database,
and checks all row counts, migration hashes and media hashes independently.
Keep the backup encryption key separately from the archive. Historical archives
containing retained evidence remain protected and must follow the owner's
approved backup-retention policy; live deletion does not delete old archives.

A receipt retention deadline is frozen on submission. `NULL` retains the image;
no legal retention period is invented. A deadline alone is insufficient: review,
a closed/completed target and absence of an unresolved refund are also required.

The receipt-only offline operator is:

```text
node backend/scripts/product/receipt-retention.mjs
node backend/scripts/product/receipt-retention.mjs --execute
```

Configure the intended application/database realm, migrator secret source,
`BACKUP_DIRECTORY`, `BACKUP_ENCRYPTION_KEY` (or its `_FILE` source),
`RETENTION_BUSINESS_ID` and `RETENTION_RECEIPT_ID` through protected operator
configuration. Never put secrets in command arguments, tickets or logs. The first
command is a dry run. Stop the target's API/worker before explicit execution.

The operator authenticates the manifest, database archive and both exact receipt
objects against immutable metadata. Runtime/API/auth/worker roles cannot call
the retention functions. It records `REQUESTED` before deleting either object,
hiding image access first; a crash/retry uses the same authenticated manifest.
`PURGED` preserves receipt hashes, reviews and audit history. No generic gallery
delete function is exposed. Original immutable evidence remains in the verified
encrypted backup.

## Verification boundaries

Tests use isolated PostgreSQL and conspicuously synthetic cards/receipts/orders.
The retention fixture inserts historical timestamps at creation in a new scratch
database; it does not weaken the runtime clock or claim a real retention period
elapsed. S3 protocol fixtures are not live cloud acceptance. Browser emulation/CDP
touch is not a physical-phone test. Mock bank attestations are not real transfers,
mock provider results are not live acquiring-bank verification, and mock SMS is
not a production delivery claim.

Production requires owner-provided recipient details, commercial/retention terms,
approved provider credentials and templates, media publication rights, protected
hosting/storage/key management, monitoring and operator acceptance. None of these
external business facts are fabricated by enabling the feature.

## Owner-supplied rates and operational configuration

The 2026-11-01 confirmed Toman menu is informational content in `data/salon.ts`, sourced from business-facts.json. It is not a fictional booking seed. Current B3 quotes price a branch/service offering; there is no approved provider-specific tariff override in the persisted quote contract yet. Do not clone the haircut service three times or silently quote Mohammad's service at Amir's price. A future forward migration should bind a versioned staff/offering tariff to each selected service segment and its immutable quote snapshot, with an explicit fallback policy chosen by the owner. Main-branch live booking stays unconfigured until durations, schedules, verified staff eligibility/branch assignment and accepted commercial policy are supplied. Only massage's duration is currently confirmed. Existing synthetic UAT branches retain conspicuous synthetic prices and staff; they do not become real salon configuration.

### Persistent owner review clone

`ms_product_owner_review` is permitted only on loopback55461 with the original local3006 origin. It is deliberately outside `local.mjs` test DB allowlists and `freshScratch`, so regression/reset tools cannot adopt or delete owner review data. The one-time operator clone uses an authenticated encrypted exported-snapshot backup, an empty independent target, complete row/migration/media verification and forward migrations; original55460 and private source/history stay intact. Encryption/identity keys and owner credentials are preserved; cluster role passwords change to the new isolated cluster's credentials. Backup key protection uses Windows CurrentUser DPAPI outside Git. This convenience does not grant production authentication or publication rights.
