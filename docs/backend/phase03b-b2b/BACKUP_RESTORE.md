# Actual backup and restore

2026-10-29T21:19:36.759Z. Actual pg_dump custom archive: 290472bytes, SHA25646261198136431aad0be5b9d87098b786669146d2e67e45c0719622c77ba7d6e; source ms_b2b_dev, separate destination ms_b2b_restore. Source unchanged at restore linearization; rowsAndCatalogEqual=true. Actual catalog: {"sha256":"d0fcf866ee251c6470871f06087dc051e5d1fecc949b0f0ab670f0b7cbb604ae","tables":28,"indexes":89,"functions":18,"foreignKeys":88,"checks":101}.

Lossless row_to_json ordered fingerprints compare every domain table and migration history, including calendar revision ordered by its business_id PK. Effective ACL normalization handles pg_restore owner ACL representation. Native exclusions/functions/triggers/generated ranges and API privilege denial are verified on restore. The archive and credentials remain ignored and are NEVER included in public/review packages. Evidence is in evidence/backup.json and evidence/restore.json.
