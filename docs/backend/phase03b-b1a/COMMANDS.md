# Commands actually run

- npm run b1a:env / npm run b1a:up: separate PostgreSQL18.6 project and random ignored credentials; no automatic migrations.
- npm run b1a:migrate, repeated invocation and npm run b1a:verify: actual version/catalog verification. Two native versions apply once, then verified no-op.
- npm run typecheck / npm run build (backend): PASS.
- npm run test:b1a:47 passed,30 expected rejections, actual dump/restore and row/catalog comparisons PASS.
- npm test: original14 backend tests PASS. npm run test:b0:isolated: all14 existing backend tests,35 SQL assertions and Prisma7.10.1 probe PASS in a tmpfs clone; cleanup executed.
- npm run check:secrets: known local credentials/signature/path-ignore checks PASS; a bounded scan, not universal secret-proof.
- npm run typecheck / npm run build (frontend): PASS. PLAYWRIGHT_CHANNEL=chrome npm run test:ui:92 passed;0 failures/skips/flakes. Actual Next.js renders, not static-preview QA.
- Native GitHub action refs resolved and pinned: checkout v5, setup-node v6, upload-artifact v4. Remote CI run status is separate final evidence.

Text logs retain actual outputs with workspace prefixes redacted and trailing whitespace normalized. Diagnostic images are actual Chromium screenshots of recorded executed output displayed in HTML, not terminal-window screenshots. Client images/fonts/private references and UI screenshots are excluded. Exact start/stop/backup/restore commands, reset guards and assumptions are in RUNBOOK.md. The local dump is ignored and never uploaded. No db push, production migration, original B0 reset, real booking/payment/notification or B1-B command was run.

Primary semantics checked against PostgreSQL18 official row-security, pg_dump and locking documentation and GitHub Actions secure-use documentation. Runtime results are distinguished from documentation assumptions.

Sources: [PostgreSQL18 row security](https://www.postgresql.org/docs/18/ddl-rowsecurity.html), [pg_dump](https://www.postgresql.org/docs/18/app-pgdump.html), [locking](https://www.postgresql.org/docs/18/explicit-locking.html), [GitHub Actions secure use](https://docs.github.com/en/actions/reference/security/secure-use).
