# 08 — Security, roles, customer privacy and media

**PROPOSAL / ARCHITECTURE ONLY.** No implementation, real booking, payment, external message, database service or migration was executed.

## Authentication and trust boundaries

Proposed browser strategy: same-origin Nginx API routing and opaque, random, hashed-at-rest server sessions in Secure/HttpOnly/SameSite cookies. Rotate after sign-in/privilege change, enforce absolute/idle expiry, revoke durably, validate Origin/CSRF on state-changing cookie requests, and avoid localStorage bearer tokens. Session design must be tested across Next/Nginx/Nest deployment before release; [OWASP session guidance](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) supports separating session identifiers from client-readable storage. Staff/owner authentication should support MFA and privileged re-authentication. Identity-provider/OTP method and recovery are open; no production auth was implemented or credentials invented.

IAM roles are business-owned definitions with Permission keys and branch-scoped UserRoleAssignment. Session resolves actor identity; every request and worker command derives allowed business/branch/resource scope on the server. Caller IDs are selectors, never authority. Object checks extend to list queries, exports, media URLs, rescheduling, callbacks and jobs. Deny-by-default and per-request resource checks are deliberate controls ([OWASP authorization](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)). Physical business FKs are not access checks.

## Proposed permission matrix

| Capability | Owner | Branch manager | Receptionist | Barber | Customer |
| --- | --- | --- | --- | --- | --- |
| Branch/configuration administration | All business branches | Assigned branch, delegated only | No | No | No |
| Staff/offering/schedule management | All | Assigned branch, delegated | Read only needed booking facts | Own schedule; requests only | Public eligible profiles only |
| Create/view/change booking | All | Assigned branch | Assigned branch operational scope | Assigned appointments; permitted status changes | Own bookings/holds only |
| Customer contact/detail | Need-to-know across business, audited export | Assigned branch bookings | Minimal assigned-branch contact | Minimal currently assigned appointment details; no other barber list | Own profile only |
| Financial detail/reconciliation | Explicit finance permission | Delegated branch finance | Payment-required/status only unless delegated | No amounts, receipts or refunds | Own quote/payments/refund status |
| Policy publication/override | Separate policy.manage / policy.override | Only explicit delegation | No | No | Read/accept own quote terms |
| Refund execution | Separate finance.refund permission and reason | Only explicit delegation | No by role default | No | Request own cancellation/refund review only |
| Media upload/publication | Separate media.manage/publish | Delegated branch assets | No by default | Own drafts only if delegated; no consent bypass | Manage own consent where supported |
| Notifications/templates/audit/reports | Explicit rights, consolidated view | Branch rights | Operational delivery status only | Own operational view | Own preferences |

Owner role does not erase audit or consent requirements. A role named Barber is not automatically a staff profile; link explicitly to a real staff identity when configured. Enforce both role permission and relational scope. A branch manager cannot grant business-wide roles; receptionist cannot elevate self. Customer A gets 404/403 for Customer B objects, with a consistent anti-enumeration policy. Job service accounts carry narrowly scoped operations and revalidate current aggregate revisions.

## Customer and sensitive-data boundaries

Account identity is separate from customer profile and staff employment. Optional unknown contact/name stays null; public booking authentication/ownership remains required. Encrypt necessary contact/identity fields with managed keys; keyed lookup HMAC permits normalized matching without indexing plaintext. Do not infer customer/staff records from uploaded photos or demo fixtures. Minimize staff-visible contact/financial projections; cache after authorization with actor/scope-aware keys. Audit changes/exports and privileged denials without logging tokens, OTPs, PAN/CVV, full callback payloads or private customer content.

Retention, erasure, access requests, backup expiration and financial/consent evidence holds need a jurisdiction-specific approved schedule. Do not invent a retention period or claim GDPR universally governs this business. Redact profile PII when permitted while retaining non-identifying financial/control evidence under lawful retention. Session/challenge, idempotency and Inbox TTLs differ; never erase dedup evidence before gateway retry/recovery horizons. Production startup/config readiness must reject missing secret references; secrets are injected from a manager/mount, not committed .env files.

## Media administration and consent

Admin CMS must support photos/video, categories/tags/service links, branch/staff attribution, sort order, draft/public/unpublished state, Before/After pairs and later package galleries. Unknown attribution remains unknown. MediaAsset owns original/object metadata; variants own optimized derivatives; PortfolioMedia assigns cover/gallery/before/after roles. A before/after group requires exactly one valid before and one valid after before publication; uniqueness prevents duplicates while the command checks completeness. Every identifiable subject needs a WEBSITE-scoped, current evidence-backed consent; INTERNAL_REVIEW consent is insufficient. Publication also checks staff/branch attribution permission. One person's consent does not clear every recognizable person in a frame.

Upload authorization checks role/business/branch/quota and creates a new unguessable quarantine key. Use short-lived, narrowly scoped presigned POST/PUT policies with exact key/checksum/size conditions, not storage credentials. Presigned URLs can be reused before expiry and overwrite the same key, so they are not one-time authorization by themselves ([S3 presigned URL behavior](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html)). The service must validate the completed object and copy/version the validated bytes into a new immutable processing key; later quarantine overwrites cannot replace approved content.

Proposed engineering limits, not confirmed salon facts: maximum image upload 12 MiB / 40 megapixels; video 100 MiB with approved duration/codec limits configured before enabling video. Allowlist JPEG/PNG/WebP and approved MP4 inputs. Ignore claimed MIME/extension as proof: verify file signatures, decode safely, bound dimensions/decompression, reject polyglots/malware and execute processors in an isolated worker. Strip EXIF/GPS/private metadata by controlled re-encoding; generate thumbnails and optimized variants; public delivery uses only validated derivatives. Follow layered upload checks, not a single extension test ([OWASP file upload](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html)).

Buckets/originals/consent evidence remain private. A publication resolver or controlled derivative/CDN path checks current rights; signed private previews expire. Revocation transaction unpublishes affected items/assets, records audit/outbox and initiates cache invalidation/derivative access removal. Delete requests first tombstone metadata, revoke serving and queue idempotent storage purge, respecting legal holds and backup lifecycle. Already downloaded public copies cannot be recalled; short cache TTLs/purge bound future serving, not historical copies. No private photographs appear in architecture diagrams/exports.

## Other controls and gates

Validate DTO sizes/enums/IDs, reject unknown writable fields and mass assignment, parameterize raw SQL, scope cursor pagination and avoid arbitrary sort SQL. Rate-limit auth, availability search, quotes/holds, uploads and callbacks by actor/business plus network signals; expensive endpoints fail safely if required limiter state is unavailable. Use TLS, restrictive CORS/CSP, safe headers, Nginx body limits and minimal container privileges. Prevent SSRF by accepting object IDs rather than arbitrary URLs for media processing. Separate migration/API/worker/report roles, encrypted secrets/backups, security patch/SBOM monitoring and restoration drills. Read-only reporting cannot mutate financial records. Field-level permissions, tenant negative tests and immutable evidence grants/triggers are Phase 03B gates, not already-tested security claims.
