# Sanitized employer-review code export

Private implementation: 46399ad863c48af43243d8cd2972bd9c77d71b56. This branch starts only from public review/product-finalization (35bbdf88860fd2363e107e0156dc74cf22a36c85). No private Git objects/history were imported. Draft PR12 remains unmerged; PR1–11 are unchanged.

Actual Booking, slot/quote/consent checks, auth, payment, inventory, CMS, SQL and tests are preserved. Current refinements include four-frame hero/swipe, multi-service drawer handoff with visible mobile footer, consistent type roles, contact shortcuts, sticky navigation/common footer and editorial Journal. Three original generated journal covers and the refined own-brand vector are safe public assets with provenance; they are not real salon/client photographs.

Sanitization differences: existing public abstract placeholders remain byte-for-byte unchanged; system fonts/disclosure/noindex remain; private-font route returns404; CinematicMedia disables owner film sources; privateFilms list remains empty. Homepage font assertions use Tahoma. Source audit uses this public branch's baseline. The original public no-JS test transport adaptation is retained. No Booking behavior was changed for sanitization.

Omitted: original/derived client photographs, private fonts/binaries, reference boards, original/optimized films and posters, face/receipt screenshots, raw internal logs/artifacts, local credentials/environment files, SSH key, sessions, backups/dumps, dependencies/build outputs and private history. Generated editorial assets are the explicit exception, not permission to publish private client media.

The owner separately authorized temporary schedules, staff eligibility, durations and sample terms so both existing branches can be exercised on the isolated employer-review database. Provisioning uses a normally authenticated MFA owner and guarded configuration.enable; it does not disable an authorization/planning guard. Private operational snapshots/session/provisioning artifacts are not exported or auto-run. Confirmed menu facts remain intact. Provider-specific real quote pricing is still an explicit architectural decision; see OWNER_REVIEW_SAMPLE.md. The source default does not automatically publish physical products or seed live policies.

Validation results and SHAs are reported from current GitHub CI, separately from previous/local runs. No real payment/SMS, production authentication bypass, PR merge or next phase.
