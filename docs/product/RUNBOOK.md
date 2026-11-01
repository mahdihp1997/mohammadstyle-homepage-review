# Product deployment and recovery

This is the original private product implementation. Deployment files are prepared; no public deployment is authorized or performed. Local validation uses a separate PostgreSQL cluster and seven-day private QA certificates without changing an operating-system trust store.

## Prerequisites and first installation

The proxy is built from official nginx1.30.6 source with a pinned SHA256, because the available registry stable tag reported1.28.0. Version selection follows the [official security advisories](https://nginx.org/en/security_advisories.html); source is retrieved from [nginx.org](https://nginx.org/download/nginx-1.30.6.tar.gz). Node/PostgreSQL base images are digest-pinned.

Use an x86-64 Linux Docker host with current Docker Compose, Node 24.16.x for offline operator commands, DNS and an approved HTTPS hostname. Supply an HTTPS certificate/key and a PostgreSQL server certificate/key signed by a CA trusted by the application. The PostgreSQL certificate SAN must include `postgres` (or the configured database hostname). Never disable certificate verification. The proxy configuration assumes it is the direct Internet edge. If another proxy/CDN is added, explicitly restrict and authenticate that hop before trusting its client address; never expose Next or Nest directly.

From the repository root:

```sh
node deploy/product/init-secrets.mjs --directory=/srv/mohammadstyle/secrets
cp deploy/product/.env.example /srv/mohammadstyle/product.env
```

Set the non-secret settings in `product.env`: `PRODUCT_ENV=staging` initially, exact `PUBLIC_ORIGIN=https://…`, hostname-only `PUBLIC_HOST`, stable `PRODUCT_BUSINESS_ID` from the generated private `business-id`, a dedicated database name, `SECRETS_DIR`, `BACKUP_ROOT`, and an immutable `RELEASE_TAG`. Keep the default loopback bind until production acceptance. For the approved Internet edge only, use `BIND_ADDRESS=0.0.0.0`, HTTP port 80, HTTPS port 443. `MS_PRODUCT_PUBLISH=0` keeps staging/review out of indexing; enable it only on the accepted production origin.

Place the issued certificates at `pg_ca.crt`, `pg_server.crt`, `pg_server.key`, `https.crt`, `https.key` in the private secrets directory. On Linux, make the directory root-only and files root-owned. Compose mounts application secrets read-only; the nonroot application user must be able to read its mounted files. Use narrowly readable secret files (or a secret manager mounted at the same paths), while restricting host directory traversal. PostgreSQL's entrypoint copies its private key to a postgres-owned 0600 file. Keep `backup_key` separately in offline recovery custody. Do not put secrets in Git, image layers, command arguments, screenshots, or CI artifacts.

Create the writable backup directory for the nonroot `node` container user (UID 1000). Start the database, provision roles once, migrate explicitly, then start applications:

```sh
docker compose --env-file /srv/mohammadstyle/product.env -f deploy/product/compose.yml build
docker compose --env-file /srv/mohammadstyle/product.env -f deploy/product/compose.yml up -d --wait postgres
docker compose --env-file /srv/mohammadstyle/product.env -f deploy/product/compose.yml run --rm provision
docker compose --env-file /srv/mohammadstyle/product.env -f deploy/product/compose.yml up -d --wait
```

`provision` requires the privileged database operator secrets, verifies an existing database's owner/marker, and never resets it. Runtime containers receive neither the administrator nor migration password. The one-shot `migrate` service uses the migration role, checks contiguous SHA256 history and PostgreSQL 18, serializes concurrent migrators, applies the pending batch transactionally, and bootstraps only the verified brand, confirmed Poonak location and six brochure services. No users, staff, prices, hours, policies, publication rights or bookable offerings are invented. Re-running it preserves accepted data. The runtime refuses a different realm, unknown schema head, incompatible providers, or synthetic identity provenance outside the isolated test environment.

## Owner activation and business configuration

SMS is `none` and payment is `none` by default. Do not substitute a development password or cookie issuer. To connect approved Kavenegar SMS, supply a private `sms_key`, approved `SMS_OTP_TEMPLATE` and notification sender, set `SMS_PROVIDER=kavenegar`, and add `-f deploy/product/sms.kavenegar.yml` to every Compose command. The worker alone receives the SMS key. OTP uses the official lookup contract; normal notifications use the official SMS send contract. Verify provider account/template approval in its own staging process before accepting production traffic. Live SMS is forbidden in the isolated test profile.

Create a phone-bound, 24-hour, single-use administrator invitation with the trusted offline operator, using the same migration/identity secrets and verified TLS environment:

```sh
# ADMIN_INVITATION_OUTPUT must be a private writable mounted path.
node scripts/product/bootstrap.mjs --invite-mobile=OWNER_VERIFIED_IRANIAN_MOBILE --role=OWNER
```

In Docker, run this command through `migrate` with the private output directory mounted and `ADMIN_INVITATION_OUTPUT` supplied. The owner visits `/admin/activate`, verifies the real SMS, chooses a password of at least 12 characters, enrolls a six-digit/30-second TOTP authenticator and saves the once-displayed recovery codes. A recovery code alone cannot reset an account: verified mobile is also required; recovery rotates credentials/MFA and revokes existing sessions. OWNER always requires MFA. Branch-manager/operator invitations require `--branch=UUID`. The trusted `role-policy.mjs` CLI can explicitly configure an optional non-owner role with an audited reason; enrolling MFA later revokes password-only sessions and old recovery codes. Never make OWNER optional.

Configure actual branch offerings, integer Rial prices/durations/buffers/resources, verified staff eligibility and temporal memberships, hours/shifts, and published policy versions/assignments through administration. Confirm the owner-defined commercial terms before enabling bookability. The second branch remains unconfigured until its facts are supplied. Settings for reminder timing and no-show grace start disabled. Notification templates must be explicitly approved/enabled. Existing accepted quote/terms snapshots remain immutable.

Paid bookings require an approved live gateway adapter. None has been selected: the provider-independent create/verify/receipt/reconciliation/refund engine is implemented and tested; no live endpoint, merchant credential or payment success is invented. Implement the selected provider against its official contract and staging account, particularly request idempotency, independent exact-Rial verification and refund receipts, before enabling deposit-required production bookings. A definitive failed payment currently requires cancellation/rebooking; an ambiguous payment never permits a replacement charge. Paid rescheduling remains a review boundary; the supported self-service path is the approved zero-deposit/same-services/same-terms contract. Multi-policy service conflicts remain fail-closed.

## Private media storage

Local storage is a private persistent volume, served only through authorization/rights-checked application routes. Originals never have a public endpoint. The upload pipeline strips image metadata, makes bounded WebP thumbnails/displays, transcodes video to bounded H264/AAC with faststart, and supports ranged video delivery. ZIP import validates entries and bounded native processing. Upload, rights attestation and publication are separate permissions/actions. Publication requires current rights evidence, readable title/alt and explicit approval; later edits/revocation remove public access immediately. Do not upload internal client photos as publicly licensed content without confirmation.

For a dedicated owner-only S3-compatible bucket, add `-f deploy/product/storage.s3.yml`, set HTTPS `S3_ENDPOINT`, bucket/region and private S3 credential files. The official SDK signs requests; bucket ACL/policy and immutable-object conflicts are checked. The bucket must remain private, including its origin; no direct public/CDN URLs bypass rights checks. Retain versioning/offsite backups according to an owner-approved retention policy. No Instagram scraping is installed.

Edit public/brand/mohammadstyle-mark.svg as the single canonical mark and run npm run brand:icons to regenerate favicon/apple derivatives. BrandMark uses that same SVG rather than duplicated geometry.

Production web packaging copies only the approved editable SVG brand asset, generated icons and code. Original private photographs, font binaries, references and internal screenshots stay in the private source checkout. Runtime/optimizer private-image gates are additional protections. System fonts and brand artwork are intentional until approved public media is added through CMS. Check the final image against the release asset audit before distribution; do not distribute intermediate build images/caches.

## Updates, monitoring and recovery

Before updates, create an encrypted backup, retain the old immutable release image and verify certificate expiry/free disk space. Run explicit migrations with the new image. Do not rewrite applied migration files or automatically run down-migrations against financial/accepted history. On a failed pending batch, PostgreSQL rolls it back; inspect sanitized diagnostics. If a committed release needs reversal, stop traffic and restore a verified backup into a separate empty database, or deploy a reviewed forward correction. Do not delete an existing database or volume.

`GET /api/health` checks the actual schema/realm/database and fresh worker heartbeat. Container checks cover PostgreSQL readiness, Nest liveness, worker readiness and the Next bridge. Run `MONITOR_ORIGIN=https://… node scripts/product/monitor.mjs` from a separate monitoring host; use its nonzero exit for the owner's chosen alert channel. Schedule checks at least every minute. Schedule encrypted backups at the owner-approved RPO and a separate-host restore drill at least monthly; monitor disk usage, certificate renewal and backup freshness/exit status. Compose writes structured HTTP/worker diagnostics to stdout. The proxy logs the path, never callback query strings. No OTPs, phone numbers, passwords, provider payloads or raw exceptions are logged. SQLSTATE/request IDs support investigation. Restrict log access and retention. Review blocked/dead/unknown deliveries and refund cases in administration; never change financial status manually.

For local or S3 media, the same backup command exports a consistent PostgreSQL snapshot and the immutable objects referenced by it. Each dump/object and the completion manifest are AES-256-GCM encrypted with independent IVs and bound contexts. Only a completed authenticated manifest represents a usable backup. Preserve application encryption/identity/OTP secrets separately as well as the backup key; a database backup alone cannot decrypt contacts or MFA secrets. Do not blindly replace identity/encryption keys: rotation requires a planned migration/re-encryption and recovery-code strategy.

```sh
# Set BACKUP_SET to a NEW unique timestamp in the deployment settings.
docker compose --env-file /srv/mohammadstyle/product.env -f deploy/product/compose.yml run --rm backup
```

Copy the encrypted completed set to a restricted independent host/store; keep keys separately. Restore to a separately provisioned, correctly marked, EMPTY and OFFLINE database with the intended realm/business. Keep API/worker/traffic stopped for that target. Point the operator settings at this database, set `RESTORE_TARGET_DATABASE` to exactly its name and `BACKUP_SET` to the chosen completed set:

```sh
docker compose --env-file /srv/mohammadstyle/recovery.env -f deploy/product/compose.yml run --rm backup node scripts/product/backup.mjs restore
```

The tool authenticates the whole dump before executing it, verifies object hashes before writing immutable media, restores the DB in one transaction, then compares every table count, migration checksum and object SHA256. It refuses an active/nonempty target and never drops it. Stop on any mismatch. Confirm the restored runtime realm, secrets, storage, worker and health in isolation before directing traffic to it. An interrupted media-first restore may leave immutable objects but does not expose a partial public database. Keep evidence of the drill. Production payment reconciliation must consult the provider before retrying anything that could move money after disaster recovery.

For certificate renewal, replace the secret files atomically, restart PostgreSQL (to copy its owned key), restart clients when the CA changes, and reload/recreate the proxy; repeat verified health checks. Do not accept expired certificates, use `rejectUnauthorized=false`, or enable mock/test tools in staging/production.

## Evidence boundary

Validation uses actual PostgreSQL 18 execution, real isolated HTTP provider fixtures and actual Chromium pages. It includes separate database/media restore and a local production-Node HTTPS stack with verified PostgreSQL TLS. It is not a live gateway/SMS/cloud bucket, public-domain deployment, load/SLA certification or owner acceptance. The consolidated validation report records the exact results and intentional review-only differences.
