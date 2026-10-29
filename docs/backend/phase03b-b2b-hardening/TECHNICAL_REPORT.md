# Targeted B2B read-scope hardening report

## 1. Root cause and security impact

The old exceptions projection authorized a global staff-time-off row using any nonvoided branch membership, without testing the interval. A former Branch A membership could reveal later Branch B leave, including the entire global interval. Staff/global qualification and legacy eligibleStaffIds projections had similar historical-membership reach. Calendar/schedule projections also returned draft/archived rows without a current-versus-evidence distinction.

These were actual code-level privacy/projection flaws. The harness reproduces them on0008 using real API-role sessions before applying0009. This is synthetic verification, not evidence that real customer/staff data was exposed.

## 2. Exact change

0009 replaces the read boundary through a private INVOKER core and interval helper; the existing current SECURITY DEFINER entry point stays intact, and one explicit history entry point is added. Pinned pg_catalog search paths, qualified objects, strict kind/scope checks, no dynamic SQL and no table grants. Publication/command/state logic stays unchanged.

## 3. Exact temporal visibility policy

Time off is visible only as the nonempty intersection of its global half-open UTC interval, a valid selected-branch membership period interpreted in the branch IANA timezone, and the requested local-day window. Membership/query midnight is resolved by the existing reject-on-gap/fold resolver; no fixed offset or padded UTC window. Disjoint stints return separate slices and never bridge a gap. Original source id stays a command selector; scopeAssignmentId plus clipped starts_at/ends_at distinguishes a projection slice. Full source interval/reason/other-branch data are not returned.

Current requires active/nonarchived/nonvoided membership. Explicit history may use inactive/archived membership only if it has a finite reviewed end already in the past; it never revives voided membership or infers an end from archive/deactivation. Branch-only current staff/qualification metadata additionally requires membership applicable now and to the query; asking for an old window cannot reveal the current global profile of a former worker. Explicit business-wide staff.read can still read business-wide current metadata. No historical global capability/profile snapshot is invented.

This is a provisional least-privilege engineering interpretation pending owner privacy/retention review, not an invented salon privacy policy. See VISIBILITY_POLICY.md.

## 4. Calendar versus history

Existing GET routes default to view=current: only published=true, archived_at=NULL shifts in the selected branch/staff/local-date window. capacityReserved=false remains. view=history explicitly requires current branch-scoped schedule.history.read, or staff.history.read for assignment/eligibility evidence. No ordinary-read or own-schedule fallback. History returns retained evidence, including published rows, with projection=history and explicit PUBLISHED/DRAFT/WITHDRAWN/ARCHIVED_DRAFT state. No row is erased.

## 5. Migration and runtime

New0009 only; old0001..0008 are byte-identical and original registry.b2b.json remains the eight-version baseline. registry.b2h.json is the complete nine-version reviewed hardening profile. New isolated cluster55442/ms_b2h_dev,failure,restore preserves old B2B and older DBs.28 tables/88FK/101CHECK/89indexes/21functions; six API entry points. Catalog fingerprint 94804847f5fd4ff7ea7cfa359b3246510874e1e6037ee6f88af14d8d75e96dd4.

Current opt-in local entry uses APP_ENV=b2h-local, port3106, the isolated hardening DB and checks reviewed history-function availability before API startup. It refuses an unmigrated0008 DB and does not auto-migrate. The legacy factory/options remain for unchanged baseline regression; the CLI no longer serves the preserved old profile. Existing API paths and mutations are unchanged; test-only loopback server metadata/Origin now points to3106. No production endpoint was deployed.

A branch SHARE lock holds timezone/membership scope stable during projection and coordinates with the existing authorized branch-first writer locks. A real two-connection test observes the writer waiting, then verifies the next read sees the new membership end.

## 6. New tests / before-after

42 actual PostgreSQL/Nest assertions PASS,0FAIL;17 expected denials. Former-membership privacy, genuine overlap, sequential/concurrent memberships, disjoint slices, revoked/voided/archive semantics, Tehran midnight, New York DST day, Havana ambiguous midnight, strict current/history, own staff, forged selectors, SQL privilege abuse, legacy projection, startup gate, migration/restore and read/write consistency are covered. Fixture/lifecycle writes and monitoring are harness-only; scope checks execute production functions as API role and real Nest routes.

Before0008: unrelated Branch B leave visible to Branch A; current calendar3 rows included draft/withdrawn. After0009: unrelated leave0 rows; current calendar1 published row; authorized history retains all3 with explicit states. Actual records are in BEFORE_AFTER.json and evidence/integration.json.

## 7. Regressions

Unchanged original B2B71, B2A69, B1B83, B1A47, B0 backend14 + SQL35 + Prisma7.10.1 pass in verified-routing disposable clones. Exact original test-body hashes are preserved. These run their original migration profiles; targeted42 run0009. Root frontend typecheck/build and92/92 actual Playwright pass,0flaky, at all four existing viewports. Homepage/Booking/assets untouched.

## 8–9. PostgreSQL/CI/restore

Actual fresh9-version install, data-preserving8->9 upgrade, no-op, old checksums, drift detection, failed forward migration rollback and separate custom backup/restore pass. Backup230347bytes, SHA2563c6ace94de746a63ec7e9f696153e9fbfe380735622f7f63c5988b8ea0d74c61; restore all row/catalog/effective-grant fingerprints equal; restored API negatives pass. Archive/credentials are excluded. Parser validation is separate from these actual executions. Current-head GitHub Actions results and artifact receipts are delivered separately after push.

## 10–12. Git, files and visual package

Same private/public B2B branches and Draft PR7; no force push/merge/new PR. Exact SHAs in GIT_DELIVERY_RECEIPT.json, file inventory in CHANGED_FILES.md, implementation/export parity in PUBLIC_EXPORT_AUDIT.json. Individual DOT/SVG/PNG diagrams and captures of real recorded results are linked in REVIEW.html. The captures are not fictional terminal/application screenshots.

## 13. Remaining prerequisites

Owner-reviewed privacy/retention/history grants, custody of identity/capability evidence, recorded historical timezone-change handling, real staff/hours/resource configuration and cross-branch transfer policy remain open. Global approval must use original reviewed request evidence; a clipped branch projection does not disclose or define the whole global approval scope. Existing B2B conservative travel/CAS/bookability gates remain. Production authentication/HTTPS/distributed limiting and B3 policy/quote/booking structural decisions require separate authorization. STOP here; no financial policies/quotes/holds/allocations/customer bookings/payment/deployment.
