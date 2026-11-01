-- Contact/identity are globally keyed by verified user; business authorization
-- comes from the validated session and exact shop.customer role assignment.
SET search_path=pg_catalog;
CREATE OR REPLACE FUNCTION ms_b1_design.shop_customer_actor(h bytea,csrf bytea) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE a jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);
 IF NOT ms_b1_design.b1b_can(a,'shop.customer',NULL) OR NOT EXISTS(SELECT 1 FROM ms_b1_design.customer_contact c WHERE c.user_id=(a->>'userId')::uuid AND c.verified_at IS NOT NULL
 AND(NOT c.test_only OR EXISTS(SELECT 1 FROM ms_b1_design.product_runtime r WHERE r.singleton AND r.environment='test'))) THEN PERFORM ms_b1_design.b3_fail('VERIFIED_CUSTOMER_REQUIRED','MS403');END IF;RETURN a;
END $$;
