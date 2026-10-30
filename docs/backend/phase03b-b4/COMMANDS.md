# Commands and observed output

| Command | Observed result |
|---|---|
| frontend npm ci --no-audit --no-fund --cache task-cache |added29 packages;0 exit; unchanged lockfile|
| backend npm ci --offline --ignore-scripts --no-audit --no-fund --cache task-cache |added249 packages;0 exit|
| backend npm run typecheck / npm run build |tsc successful;0 exit|
| frontend npm run typecheck / npm run build |Next15.5.28 compiled, types and route generation pass;0 exit|
| npm run b4:env / b4:up / b4:migrate |isolated18.6 cluster;14 checksummed migrations|
| npm run test:b3:isolated |unchanged B3/B2H/B2B/B2A/B1B/B1A/B0 assertions pass in separate temporary clusters|
| npm run test:b4 |44 core +14 extra pass; actual races, rollback and restore|
| npm run b4:verify; node scripts/b4/check-schema.mjs |no-op/catalog/grant verification PASS;50 tables/4 exclusions|
| node scripts/b4/check-secrets.mjs |known credentials/signatures/paths absent from scoped source|
| PLAYWRIGHT_CHANNEL=chrome npm run test:ui |92 passed, four viewports|
| APP_ENV=b4-local npm run b4:ui-fixture; npm run b4:start |isolated verified synthetic sessions; values withheld; real API3110|
| PLAYWRIGHT_CHANNEL=chrome npm run test:ui:server |12 passed; actual Next/API/DB flow and screenshots|
| npm run b4:backup / npm run b4:restore |custom archive independently restored; all50 ordered row/catalog/grant fingerprints match|

PowerShell uses environment assignments before the corresponding commands; CI uses equivalent shell environment values. Credentials, dumps, browser session state and traces are omitted. Result JSON contains actual execution times/case names. Static parser/OpenAPI/diagram/link checks and final current-head CI results are separate evidence, not substitutes for these executions.
