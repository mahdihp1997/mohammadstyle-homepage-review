# Media lifecycle and limits

Upload → READY/private → metadata/categories → affirmative documented rights attestation → separate explicit PUBLISHED action. There is no inferred consent, automatic ZIP approval, Instagram scraping or existing-photo import. Uploaded client assets in the original project remain internal and are not part of this CMS seed or public export.

Only the newest GRANT for PUBLIC_WEBSITE, unrevoked and unexpired, can authorize publication/delivery. Evidence references stay private. Rights events are append-only. A database record does not verify a legal document: the human owner must actually verify usage rights for every recognizable person. Synthetic test fixtures explicitly state they contain no clients.

Metadata edits and any grant/renewal/revocation reset state to private READY. Renewing rights never automatically republishes media. Unpublish hides it; archive preserves private originals and history. Expiry/revoke/unpublish are checked on each new gallery/derivative request; responses use no-store. Previously downloaded bytes or an already-open video stream cannot be recalled. Reloading the gallery obtains the current approved set.

| Input/processing bound | Value |
|---|---|
| File or ZIP transport | 32 MiB, strict canonical base64 JSON, bounded proxy/body parser |
| Images | actual JPEG/PNG/WebP, one page, ≤40 million pixels |
| ZIP | ≤20 media files, ≤100 total entries, ≤128 MiB expanded, ≤100:1 per-entry ratio |
| ZIP rejection | traversal/absolute/backslash/colon paths, symlinks, encrypted/duplicate names, nested ZIP/non-media and malformed members |
| Video | actual probe, ≤120 seconds, ≤33,177,600 pixels/frame, ≤8 streams |
| Outputs | WebP thumb ≤480, display ≤1920; H264/AAC MP4 ≤1280×720 envelope, metadata stripped, faststart |
| Processing | one active job/process; bounded native output, per-tool timeout and two-minute batch budget |

No filesystem extraction occurs for ZIPs. All members are validated/transformed before atomic registration. A bad member leaves no partial CMS records. Failed/expired transactions may leave immutable *private unreferenced objects*. These are not gallery-visible. Cleanup/retention is an owner/operations decision; no destructive automatic deletion is introduced. Break up a ZIP if the bounded synchronous processor times out. There is no hidden asynchronous queue/progress claim or resumable upload in this MVP.

Immutable keys include business UUID, asset UUID, original content SHA256 and derivative name. Original source keys/names/hashes and private evidence never appear in public projections. Originals are retained privately with no public delivery route. Switching storage providers requires copying and verifying those keys; changing an environment flag alone is not an object migration.

Local storage recovery was exercised separately from the actual PostgreSQL dump/restore. S3 signing, private-bucket checks, immutable PUT and range delivery were exercised with the actual AWS SDK against a local protocol fixture. Live S3-compatible provider and cloud backup/CDN tests remain pending deployment decisions. Do not expose the storage directory or bucket publicly.
