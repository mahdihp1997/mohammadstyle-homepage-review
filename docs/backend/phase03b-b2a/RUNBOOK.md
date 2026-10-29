# B2A local runbook

Use Node24.16.0 and Docker. Run from backend/. Keep original B0/B1A/B1B clusters and evidence untouched. Only marked B2A test DBs may be recreated; no FORCE/drop-session/global prune is used.

1. npm ci --ignore-scripts --no-audit --no-fund (local run used verified --offline cache,249 packages/45s).
2. npm run b2a:env; npm run b2a:up — independent project/credentials/volume/55438.
3. npm run typecheck; npm run build; npm run b2a:migrate — manual reviewed forward chain only.
4. npm run test:b2a — actual69 tests; recreates ONLY marked ms_b2a_dev/failure/restore; synthetic data only.
5. npm run test:b1b:isolated — unchanged83 B1B +47 B1A +14/35/Prisma B0 in copied ignored harnesses and separate tmpfs clusters55439/55437/55435; no prior result overwrite or DB reset. Local node_modules link remains ignored, never exported.
6. npm run b2a:verify; node scripts/b2a/check-schema.mjs; node scripts/b2a/check-secrets.mjs. The B2A secret scan writes only B2A evidence; original default secret-scan routing stays unchanged.
7. npm run b2a:backup; npm run b2a:restore — actual custom archive into separate restore DB, role/marker/source/checksum guards, ordered rows plus effective catalog equality. Dumps are ignored and unexported.
8. Root frontend: npm run typecheck; npm run build; PLAYWRIGHT_CHANNEL=chrome npm run test:ui locally, Chromium in CI. Restore only own generated tracked private artifacts after saving this run's JSON summary.
9. npm run b2a:stop stops only the new Compose project and retains its volume. No production deployment, B2B API or slot generation.

Existing admin/session API startup does not import a B2A migration or a raw staff-management port. Before B2B, review temporal containment, revision publication/withdrawal and authorization/audit/exception transactions listed in OPEN_DECISIONS.md.
