-- B1A migration0002: limited repository role, defense-in-depth tenant context.
-- Migration owner remains privileged; this is NOT production authentication.
REVOKE ALL ON SCHEMA ms_b1_design FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA ms_b1_design FROM PUBLIC;
GRANT USAGE ON SCHEMA ms_b1_design TO ms_b1a_runtime;
GRANT SELECT ON ms_b1_design.business TO ms_b1a_runtime;
GRANT UPDATE(row_version, updated_at) ON ms_b1_design.business TO ms_b1a_runtime;
ALTER TABLE ms_b1_design.business ENABLE ROW LEVEL SECURITY;
CREATE POLICY b1a_tenant_context ON ms_b1_design.business TO ms_b1a_runtime USING (id = nullif(current_setting('ms.business_id',true),'')::uuid) WITH CHECK (id = nullif(current_setting('ms.business_id',true),'')::uuid);
GRANT SELECT ON ms_b1_design.branch TO ms_b1a_runtime;
GRANT UPDATE(row_version, updated_at) ON ms_b1_design.branch TO ms_b1a_runtime;
ALTER TABLE ms_b1_design.branch ENABLE ROW LEVEL SECURITY;
CREATE POLICY b1a_tenant_context ON ms_b1_design.branch TO ms_b1a_runtime USING (business_id = nullif(current_setting('ms.business_id',true),'')::uuid) WITH CHECK (business_id = nullif(current_setting('ms.business_id',true),'')::uuid);
GRANT SELECT ON ms_b1_design.service TO ms_b1a_runtime;
GRANT UPDATE(row_version, updated_at) ON ms_b1_design.service TO ms_b1a_runtime;
ALTER TABLE ms_b1_design.service ENABLE ROW LEVEL SECURITY;
CREATE POLICY b1a_tenant_context ON ms_b1_design.service TO ms_b1a_runtime USING (business_id = nullif(current_setting('ms.business_id',true),'')::uuid) WITH CHECK (business_id = nullif(current_setting('ms.business_id',true),'')::uuid);
GRANT SELECT ON ms_b1_design.branch_service_offering TO ms_b1a_runtime;
GRANT UPDATE(row_version, updated_at) ON ms_b1_design.branch_service_offering TO ms_b1a_runtime;
ALTER TABLE ms_b1_design.branch_service_offering ENABLE ROW LEVEL SECURITY;
CREATE POLICY b1a_tenant_context ON ms_b1_design.branch_service_offering TO ms_b1a_runtime USING (business_id = nullif(current_setting('ms.business_id',true),'')::uuid) WITH CHECK (business_id = nullif(current_setting('ms.business_id',true),'')::uuid);
-- No INSERT/DELETE/TRUNCATE/DDL/auth/audit/outbox/metadata access is granted to runtime.
