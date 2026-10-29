# Focused read-scope security review

Root cause: historical existence was incorrectly treated as temporal authority over a global staff record. The fix intersects validated intervals before projection and audits related global metadata/legacy staff-ID projections.

- Verified server session derives actor/business; current permission and branch/object scope precede projection. IDs/GUC/role strings are never authority.
- Private INVOKER core/helper have no API/PUBLIC EXECUTE. Only one narrow history DEFINER entry is added; all paths pin pg_catalog and qualify table/functions. No broad grants/DDL/login or production bypass.
- Current calendar filters published/nonarchived explicitly; history is distinguishable and permissioned. Voided membership never authorizes; deactivation alone never manufactures a historical end.
- Global time off is clipped before the safe field allowlist; gaps across stints and unrelated source extents are not returned. Current mutable metadata requires live membership for branch-only viewers.
- Branch SHARE lock keeps interpreted timezone/membership scope coherent with authorized writers. Actual lock wait and subsequent denial are recorded.
- The hardened CLI requires the new isolated profile and installed migration before serving. Legacy factory profile exists only for unchanged baseline validation.
- B2B command/publication/idempotency logic and old SQL remain unchanged. New history permissions are synthetic harness fixtures only; actual role grants require review.

Initial draft0009 failed42601 because WINDOW was used as a PL/pgSQL variable; atomic rollback was observed and it was renamed before final execution. A regression-harness route error temporarily recreated the old B2B service on a synthetic tmpfs configuration. The original persisted volume was untouched; original Compose settings were restored immediately, and all original B1A/B1B/B2A/B2B row/catalog fingerprints plus56 prior evidence/backup files and8 migration files matched before continuing. The final harness validates all copied helper routing/project names before startup and uses separate55445. No old DB reset or data loss occurred.

No production security certification or real PII exposure is claimed. Privacy/retention/history authority and historical timezone changes remain owner/operational gates.
