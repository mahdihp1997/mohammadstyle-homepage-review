-- A browser may recover a lost checkout response without resending an address
-- or creating another order. The permanent request record is actor-scoped.
SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.shop_checkout_status(h bytea,csrf bytea,k uuid,cancel_attempt boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;r jsonb;BEGIN
 a:=ms_b1_design.shop_customer_actor(h,csrf);
 IF k IS NULL OR cancel_attempt IS NULL THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 PERFORM ms_b1_design.b4_lock((a->>'businessId')::uuid);
 SELECT q.response INTO r FROM ms_b1_design.product_manual_request q WHERE q.business_id=(a->>'businessId')::uuid AND q.actor_id=(a->>'userId')::uuid AND q.operation='shop.checkout' AND q.idempotency_key=k;
 IF r IS NULL AND cancel_attempt THEN
 -- A tombstone fences a delayed original HTTP request. Its semantic signature
 -- cannot match a checkout, so a later original request fails instead of creating
 -- a second order after the browser has deliberately restarted.
 INSERT INTO ms_b1_design.product_manual_request(business_id,actor_id,operation,idempotency_key,signature,response)
 VALUES((a->>'businessId')::uuid,(a->>'userId')::uuid,'shop.checkout',k,sha256(convert_to('checkout-aborted:'||k::text,'UTF8')),jsonb_build_object('aborted',true));
 r:=jsonb_build_object('aborted',true);
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES((a->>'businessId')::uuid,(a->>'userId')::uuid,'shop.checkout.aborted','checkout_attempt',k,gen_random_uuid(),'{}',(a->>'userId')::uuid);
 END IF;
 RETURN jsonb_build_object('order',CASE WHEN r ? 'id' THEN r END,'aborted',coalesce((r->>'aborted')::boolean,false));
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.shop_checkout_status(bytea,bytea,uuid,boolean) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.shop_checkout_status(bytea,bytea,uuid,boolean) TO ms_b1b_api;
