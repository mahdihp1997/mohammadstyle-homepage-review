-- A cross-environment import must never wash a persisted test provenance flag.
CREATE OR REPLACE FUNCTION ms_b1_design.product_identity_provenance() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE mode text;BEGIN
 SELECT environment INTO mode FROM ms_b1_design.product_runtime WHERE singleton;
 IF mode IS NULL THEN PERFORM ms_b1_design.b3_fail('AUTH_UNCONFIGURED');END IF;
 IF TG_OP='UPDATE' AND OLD.test_only AND NEW.test_only IS DISTINCT FROM true THEN PERFORM ms_b1_design.b3_fail('TEST_PROVENANCE_IMMUTABLE');END IF;
 NEW.test_only:=coalesce(NEW.test_only,false) OR mode='test';
 IF mode<>'test' AND NEW.test_only THEN PERFORM ms_b1_design.b3_fail('TEST_IDENTITY_FORBIDDEN','MS403');END IF;RETURN NEW;
END $$;
CREATE TRIGGER product_contact_provenance_update BEFORE UPDATE OF test_only ON ms_b1_design.customer_contact FOR EACH ROW EXECUTE FUNCTION ms_b1_design.product_identity_provenance();
CREATE TRIGGER product_admin_provenance_update BEFORE UPDATE OF test_only ON ms_b1_design.product_admin_credential FOR EACH ROW EXECUTE FUNCTION ms_b1_design.product_identity_provenance();
