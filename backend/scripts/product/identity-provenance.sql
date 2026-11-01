SET search_path=pg_catalog;
ALTER TABLE ms_b1_design.customer_contact ADD COLUMN test_only boolean NOT NULL DEFAULT false;
ALTER TABLE ms_b1_design.product_admin_credential ADD COLUMN test_only boolean NOT NULL DEFAULT false;
UPDATE ms_b1_design.customer_contact SET test_only=coalesce((SELECT environment='test' FROM ms_b1_design.product_runtime WHERE singleton),false);
UPDATE ms_b1_design.product_admin_credential SET test_only=coalesce((SELECT environment='test' FROM ms_b1_design.product_runtime WHERE singleton),false);
CREATE FUNCTION ms_b1_design.product_identity_provenance() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE mode text;BEGIN
 SELECT environment INTO mode FROM ms_b1_design.product_runtime WHERE singleton;
 IF mode IS NULL THEN PERFORM ms_b1_design.b3_fail('AUTH_UNCONFIGURED');END IF;
 NEW.test_only:=(mode='test');RETURN NEW;
END $$;
CREATE TRIGGER product_contact_source BEFORE INSERT ON ms_b1_design.customer_contact FOR EACH ROW EXECUTE FUNCTION ms_b1_design.product_identity_provenance();
CREATE TRIGGER product_admin_source BEFORE INSERT ON ms_b1_design.product_admin_credential FOR EACH ROW EXECUTE FUNCTION ms_b1_design.product_identity_provenance();
CREATE OR REPLACE FUNCTION ms_b1_design.product_runtime_view() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('environment',environment,'businessId',business_id,'origin',public_origin,'sessionSeconds',session_seconds,'idleSeconds',idle_seconds,
 'testIdentities',(SELECT count(*) FROM ms_b1_design.customer_contact WHERE test_only)+(SELECT count(*) FROM ms_b1_design.product_admin_credential WHERE test_only)+(SELECT count(*) FROM ms_b1_design.auth_identity WHERE provider='B4_ISOLATED_TEST'))
 FROM ms_b1_design.product_runtime WHERE singleton
$$;
REVOKE ALL ON FUNCTION ms_b1_design.product_identity_provenance() FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker;
