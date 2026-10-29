# B2B security review

| Boundary | Implemented behavior | Evidence / remaining limit |
| --- | --- | --- |
| Tenant/actor | Server session derives business/user; current permissions checked before idempotent replay | Forged body/scope and foreign branch tests deny |
| Owner | Explicit business-wide permissions, never role-name shortcut | Synthetic Owner grants only in harness |
| Manager | Assigned branch operations; no global identity/capability/deactivation or time-off approval | Cross-branch and global approval denials |
| Reception/Barber/Customer | Delegated reads / verified own schedule only / no admin grants | Actual Nest tests; no customer records |
| Session/CSRF | Reuses B1B hashes/expiry/revocation/Origin/custom CSRF/Secure cookie design and bounded limiter | No production IdP/MFA/browser login/HTTPS deployment |
| SQL/grants |5 explicit entry points; helpers INVOKER, fixed pg_catalog search_path, no dynamic SQL/table grants/schema ownership | Runtime/API direct table/helper/DDL/role abuse denied; restored role tested |
| Command | Strict fields, calendar CAS, gate, full checks, atomic audit/outbox/idempotency |53+ actual expected SQL rejections; real lock-wait races |
| Identity evidence | Verified account+membership+external reference digest; no name matching | Production verification source/custody/re-auth not selected |
| Errors/logs | Only constant reviewed conflict codes cross SQL boundary; generic fallback hides raw SQL | Request IDs/method/status only, no tokens/bodies/URLs |
| Evidence export | Synthetic rows/fingerprints/diagrams only | Private assets/fonts/references/history/dumps/env omitted |

Trusted migration/admin credentials can alter schema/data and are withheld from API. Legacy runtime grants from B1A are preserved but not used for B2B authority. No claim of production security certification, full booking safety or protection against a compromised migration owner. Distributed limiting, TLS/proxy settings, provider/MFA/recovery, retention and operational secret custody remain required.
