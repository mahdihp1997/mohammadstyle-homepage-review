SET search_path=ms_b1_design,public;
CREATE TABLE product_worker_health (singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),last_success_at timestamptz NOT NULL,processed integer NOT NULL CHECK(processed BETWEEN 0 AND 100));
REVOKE ALL ON product_worker_health FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker;
SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.product_worker_runtime() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('businessId',business_id,'environment',environment,'origin',public_origin,'payment',payment_provider,'sms',sms_provider,
 'marker',shobj_description((SELECT oid FROM pg_database WHERE datname=current_database()),'pg_database')) FROM ms_b1_design.product_runtime WHERE singleton $$;
CREATE FUNCTION ms_b1_design.product_worker_heartbeat(n integer) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 INSERT INTO ms_b1_design.product_worker_health(singleton,last_success_at,processed) VALUES(true,clock_timestamp(),n) ON CONFLICT(singleton) DO UPDATE SET last_success_at=excluded.last_success_at,processed=excluded.processed $$;
REVOKE ALL ON FUNCTION ms_b1_design.product_worker_runtime(),ms_b1_design.product_worker_heartbeat(integer) FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_worker_runtime() TO ms_product_worker,ms_b1b_api;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_worker_heartbeat(integer) TO ms_product_worker;
