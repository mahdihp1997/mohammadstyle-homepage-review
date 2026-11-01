-- Callback is a capability to request provider verification, never settlement.
-- Return to the correct typed account history without exposing customer/order
-- identifiers or accepting a visitor-supplied redirect URL.
SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.product_payment_callback_route(intentid uuid,statehash bytea,authority text) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE accepted boolean;route text;BEGIN
 accepted:=ms_b1_design.product_payment_callback(intentid,statehash,authority);
 IF accepted IS NOT TRUE THEN RETURN jsonb_build_object('accepted',false);END IF;
 SELECT CASE WHEN p.order_id IS NOT NULL THEN '/account/orders?payment=checking' ELSE '/account?payment=checking' END INTO route
 FROM ms_b1_design.product_payment_intent p WHERE p.id=intentid AND p.callback_hash=statehash;
 RETURN jsonb_build_object('accepted',route IS NOT NULL,'returnPath',route);
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.product_payment_callback_route(uuid,bytea,text) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_payment_callback_route(uuid,bytea,text) TO ms_b1b_api;
