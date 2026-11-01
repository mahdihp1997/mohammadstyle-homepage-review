-- Qualify SQL/PLpgSQL names explicitly; the existing migration history stays intact.
CREATE OR REPLACE FUNCTION ms_b1_design.product_enqueue(bid uuid,kind text,key text,payload jsonb,at_time timestamptz DEFAULT clock_timestamp()) RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE result uuid;BEGIN
 INSERT INTO ms_b1_design.product_delivery(business_id,kind,dedupe_key,payload,available_at) VALUES(bid,product_enqueue.kind,key,product_enqueue.payload,at_time) ON CONFLICT DO NOTHING RETURNING id INTO result;RETURN result;
END $$;
