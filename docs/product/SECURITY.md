# Security review checklist

Implemented/executed boundaries, with detailed results in [VALIDATION.md](VALIDATION.md):

- Verified Iranian OTP identity, encrypted OTP/contact/MFA data, bounded attempts/expiry/resend/peer limits, canonical returning-account identity; no browser-supplied identity authority.
- Bounded scrypt password work, mandatory OWNER TOTP, explicitly configurable non-owner policy, replay-safe MFA counters, phone-plus-single-use-code recovery and credential/session revocation.
- HttpOnly session cookies, Secure on HTTPS, SameSite/Origin/Host/CSRF enforcement, opaque tokens stored only as hashes, current role/branch/assurance revalidation and session management.
- No production development-login controller, synthetic identity provenance or mock provider. Startup checks exact database/schema/realm/provider configuration.
- Authenticated upload permission before buffering large bodies; incomplete-request tests reject missing/forged/customer-only sessions. API routes avoid body-cloning nonce middleware. The edge streams only the bounded upload path with concurrency limits; ordinary bodies are small and encoded path aliases are rejected.
- Server-generated plans, immutable acceptance artifacts, PostgreSQL allocation exclusions/canonical locking/SERIALIZABLE transactions and bounded whole-transaction retries. No client slot/price/policy authority.
- Independent exact-Rial payment verification, one intent per revision, unique immutable receipts, idempotent callbacks and no late capacity resurrection. No browser success or arbitrary administrator financial-state override.
- Authorized refund requests bounded by verified money/frozen terms; unknown/late/failed outcomes remain explicit reconciliation/review states.
- Durable leased/deduplicated notification work, frozen approved templates, OTP decryption only at dispatch, safe ambiguity handling, opt-in and operation-aware reminders; no actual SMS/payment in tests.
- Separate upload/rights/publication permissions, immutable private originals/variants, bounded ZIP/native processing, immediate publication revocation, private local/S3 delivery and ranged optimized video.
- Actual production-Node HTTPS with verified PostgreSQL CA/hostname defaults and plaintext/untrusted-CA rejection; private Nest/database networking, least-purpose secret files, explicit operator migrations and fresh-worker health.
- Official pinned-source nginx1.30.6; final web package hash-audited against private photos/fonts/references, zero matches. Public export uses independent sanitized history and existing safe placeholders/system fonts.
- Authenticated encrypted snapshot/media backups; real separate empty/offline restore, checksum/row/object verification, wrong-key and nonempty-target rejection. Raw credentials/provider payloads/callback queries are excluded from logs/artifacts.

Production acceptance still requires approved provider accounts/contracts, actual business configuration and media rights, trusted public certificates/domain/hosting, secret/backup custody and owner-selected monitoring/retention. Verification covers the recorded local execution and isolated protocol fixtures; it does not claim a live provider/cloud audit, all possible vulnerabilities, or an SLA. Never bypass a failed readiness/security gate to publish.
