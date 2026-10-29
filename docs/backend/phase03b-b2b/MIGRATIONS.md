# Forward-only migration evidence

0001..0005 preserve original normalized checksums and exact tracked source.0006 adds workforce_calendar_revision plus reviewed relational rule/shift evidence, exception states/successors and verification digests.0007 implements the command transaction.0008 adds queries/projections and coordinates legacy commands.

New table depends only on Business; new rule FKs bind qualification staff/service and offering branch/service; new exception successor FKs bind same business; verified_by is an IAM actor derived by the command. No booking/payment/notification tables.

Actual schema summary: {"sha256":"d0fcf866ee251c6470871f06087dc051e5d1fecc949b0f0ab670f0b7cbb604ae","tables":28,"indexes":89,"functions":18,"foreignKeys":88,"checks":101}. Index count84->89 consists of five mandatory PK/UNIQUE integrity indexes (calendar PK and two keys per exception table). No speculative query/created_by indexes. Existing GiST exclusions/generated ranges and old grants remain. API gets only five reviewed functions and no table/metadata/create/temp/owner membership.

Fresh8 versions, data-preserving upgrade5->8, no-op, applied checksum tamper, catalog drift, failure rollback, actual backup+separate restore and restored API denial passed. SQL parser acceptance is separately reported and never substitutes for this execution evidence.
