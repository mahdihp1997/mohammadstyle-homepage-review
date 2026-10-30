# Technical report

## Application boundary

The new Nest integration module reuses `SessionGuard`, B1B business/catalog controllers, hardened workforce controllers, pricing controllers and the original Booking controller. Repository adapters call their existing SQL functions. `MvpRepository` extends the original Booking repository to retain SERIALIZABLE transactions, lock ordering/retry, expiry sweeps and final V2 quote integrity. Minimal existing edits export controllers, expose protected transaction/pool members and admit one exact, environment-gated local profile. There is no replacement Booking implementation.

`MS_MVP_ENABLED=1` gates Next routes; `MS_BOOKING_SERVER_PROFILE=mvp-local` separately selects the fixed port 3112 upstream. Production disables both the new UI and proxy. The original port 3110 profile and DEMO flow remain available independently. Neither browser input nor a URL can select an upstream, tenant, storage path or authenticated user.

## Admin workspaces

- Overview: actual loaded reservation/media counts, scoped operations links, empty states; no invented commercial metrics.
- Branches/services: create and edit metadata with server validation and row versions. New branches stay unbookable; a new branch offering stays inactive, unpriced and unconfigured. Homepage brochure data is not rewritten by catalog edits.
- Prices/resources: integer rial amounts, duration/buffers and individually confirmed resource quantities. Upserting one resource kind preserves other kinds. Accepted quotes are immutable. Live reservations block incompatible capacity changes.
- Staff: names/active status, temporal memberships, verified identity links, service qualifications and offering eligibility through the approved workforce API.
- Calendar: branch-local weekly view, evidence/history, working hours, physical resources, recurring rules, publication/withdrawal, time-off/closure review and explicit planner activation. Replacing selected weekdays preserves unselected days. The current hours editor accepts one new interval per selected weekday; the underlying API still supports multiple intervals. Dates are labeled Gregorian; the existing Booking Jalali calendar is unchanged.
- Policies: policy headers, complete versioned deposit/refund terms and windows, draft edits, explicit publication/retirement and scoped effective assignments. Existing accepted commercial snapshots are preserved. Incompatible multi-service policies still fail closed; no owner strategy is invented.
- Reservations: status, accepted quote/terms, immutable transition/cancellation history. Admin cancellation requires permission, current version, affirmative confirmation and a reason. The original frozen cancellation policy determines eligibility. There is no arbitrary status editor, customer impersonation or fake paid state.
- Media: manual upload/ZIP, private previews, metadata/categories, separate evidence/rights and publication permissions, revoke/unpublish/archive history.

## Persistence

Migration `0015_mvp_admin_media` adds five tables (`media_asset`, `media_variant`, `media_category`, `media_asset_category`, `media_rights_event`) and nullable admin cancellation reason on existing history. Original 0001–0014 bytes are retained. Native functions use fixed search paths and explicit execute grants. The API role has no direct table access, role membership or helper execution. Sources, derivatives and rights evidence are immutable. Commands use original canonical locks/CAS plus actor/route-scoped idempotency, audit and outbox records.

Workspace reads compose existing permission-filtered projections in one consistent SERIALIZABLE snapshot. Weekly scheduling and bounded catalog/staff projections avoid unbounded requests. Reservations/media paginate at 25; public media at 24. Large staff/catalog directory pagination remains a future usability extension beyond current bounded projections. This does not widen API permissions.

## Storage and native processing

Media derivative authorization is a single authoritative SQL statement at READ COMMITTED. The original session function updates its keep-alive row, so wrapping every parallel image request in a separate SERIALIZABLE snapshot caused avoidable serialization failures. The statement still revalidates current identity/scope/rights, and parallel authenticated derivative delivery is regression-tested. Booking admission and the consistent multi-projection workspace retain their original SERIALIZABLE behavior.

New pinned dependencies are Sharp 0.35.5, yauzl 3.4.0 and official AWS S3 SDK 3.1160.0 (plus yauzl types 3.4.0). No prior direct dependency versions were upgraded. FFmpeg/FFprobe are external native prerequisites.

Local and S3-compatible adapters implement immutable content-addressed private objects. Local paths reject traversal/symlinks and writes use exclusive creation. S3 uses official SDK signing, conditional PUT, bounded requests and owner-only bucket checks. No presigned source URL or original-file delivery route exists. Switch providers only after an explicit object migration/verification; storage selection is deployment configuration, not a per-request setting.

Native processing produces metadata-stripped WebP thumbnails/display images and actual H264/AAC faststart MP4 plus WebP poster/thumbnail. Delivery streams safe derivatives with GET/HEAD and one validated byte range, `no-store`, `nosniff` and same-origin resource policy. No autoplay. Image details retain the complete crop through `object-fit: contain`.

## Verification and limits

`evidence/VALIDATION.json` records actual commands/results. Native PostgreSQL 18 migration/upgrade, privileges, races, rollback and separate restore were executed; these are not parser-only claims. Existing B0–B4 test bodies rerun against disposable cloned profiles. Original databases are fingerprinted separately and preserved.

S3 checks use the actual official SDK against an independently signature-verifying local protocol fixture. A live cloud account/provider was not configured or tested; an attempted official MinIO image pull was rejected by its registry. No live-cloud success is claimed.

Production identity/login/recovery/MFA, real salon workforce/pricing/policies, legal consent verification/retention, production S3/provider recovery, CDN strategy and operational deployment remain approval decisions. There is no production auth bypass. Synthetic fixtures are explicitly separate from real salon data. This phase is ready for review, not production release.

## Final upload admission hardening

The process-wide media gate is acquired synchronously before the first authorization/receipt await and released in finally, including authorization failures and idempotent returns. Two uploads racing during actual database authorization now admit exactly one processor; the other receives a retryable 429. A real HTTP/SQL barrier regression verifies admission and later gate release. All 41 integration cases pass; Booking isolation, authorization and commercial behavior are unchanged.
