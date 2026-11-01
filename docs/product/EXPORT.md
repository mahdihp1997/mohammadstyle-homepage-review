# Sanitized product review

Base: existing public review/mvp-admin-portfolio (3dfdab285efcba93c464531539257468649ffa22). A new public branch only; no private Git objects/history were copied. Existing Draft PRs remain unchanged.

All actual application logic, server contracts, Booking state/validation/calculation/calendar, SQL, provider/worker/auth boundaries and new test bodies are copied unchanged from the private product implementation. Existing sanitized placeholder files retain their exact hashes.

Review-only differences:
- Root layout retains the public review disclosure and system-font CSS; indexing is always disabled. Private font CSS is omitted and its route returns404.
- The release-source audit uses the existing public baseline; existing public test bodies are checked while newly introduced unchanged legacy tests are permitted. No private history is imported to satisfy an audit tool.
- The two existing public test adaptations remain exactly as in the public base: Homepage asserts system fonts/review disclosure; the no-JavaScript Booking test uses its configured baseURL instead of a fixed private dev port. Every functional assertion remains intact. All private original tests remain unchanged in the private branch.
- Internal raster-logo provenance is omitted because it describes an earlier private-input preparation, not the current self-contained SVG.
- Private-input logo tracing utility is omitted; the approved editable canonical SVG and standalone icon generator are included.

Not exported: original client photographs, private font binaries, visual-reference boards, internal screenshots/artifacts, generated builds, dependencies, databases/dumps, local environment/certificate/secret/provider ledger files, internal drafting utilities and private history. Existing public sanitized placeholders remain. No replacement stock/client results are invented.

Deployment/tests need operator-supplied secrets generated in ignored local files. No live payment/SMS or business configuration is supplied. See RUNBOOK.md and VALIDATION.md. Public compilation and actual browser/transport results are recorded separately from private validation.
