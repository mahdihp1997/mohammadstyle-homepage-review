-- Explicit owner-defined delivery areas. No assumed nationwide shipping.
SET search_path=pg_catalog;
CREATE OR REPLACE FUNCTION ms_b1_design.shop_config(bid uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 WITH original(cfg) AS(SELECT coalesce((SELECT v.document||jsonb_build_object('version',c.version::text) FROM ms_b1_design.shop_configuration c JOIN ms_b1_design.shop_configuration_version v ON v.business_id=c.business_id AND v.version=c.version WHERE c.business_id=bid),jsonb_build_object('version','0','enabled',false,'branchId',NULL,'paymentMode',NULL,'holdSeconds',NULL,'pickupEnabled',false,'deliveryEnabled',false,'deliveryFeeRial',NULL,'termsText','','returnsText','','shippingText','','finalPricesConfirmed',false)))
 SELECT cfg||jsonb_build_object('deliveryProvinces',coalesce(cfg->'deliveryProvinces','[]'::jsonb),'enabled',coalesce((cfg->>'enabled')::boolean,false) AND((cfg->>'deliveryEnabled')::boolean IS NOT TRUE OR CASE WHEN jsonb_typeof(cfg->'deliveryProvinces')='array' THEN jsonb_array_length(cfg->'deliveryProvinces')>0 ELSE false END)) FROM original
$$;
CREATE OR REPLACE FUNCTION ms_b1_design.shop_config_save(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;cfg jsonb;v bigint;result jsonb;BEGIN
 a:=ms_b1_design.manual_financial_actor(h,csrf,NULL,'shop.configure');bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);
 PERFORM ms_b1_design.b3_keys(d,ARRAY['version','enabled','branchId','paymentMode','holdSeconds','pickupEnabled','deliveryEnabled','deliveryFeeRial','termsText','returnsText','shippingText','finalPricesConfirmed','deliveryProvinces']);
 result:=ms_b1_design.manual_replay(bid,uid,'shop.config',k,sig);IF result IS NOT NULL THEN RETURN result;END IF;
 cfg:=ms_b1_design.shop_config(bid);IF cfg->>'version' IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF jsonb_typeof(d->'enabled') IS DISTINCT FROM 'boolean' OR jsonb_typeof(d->'pickupEnabled') IS DISTINCT FROM 'boolean' OR jsonb_typeof(d->'deliveryEnabled') IS DISTINCT FROM 'boolean' OR jsonb_typeof(d->'finalPricesConfirmed') IS DISTINCT FROM 'boolean'
 OR jsonb_typeof(d->'termsText') IS DISTINCT FROM 'string' OR jsonb_typeof(d->'returnsText') IS DISTINCT FROM 'string' OR jsonb_typeof(d->'shippingText') IS DISTINCT FROM 'string' OR length(d->>'termsText')>4000 OR length(d->>'returnsText')>4000 OR length(d->>'shippingText')>4000 THEN PERFORM ms_b1_design.b3_fail('INVALID_SHOP_CONFIGURATION');END IF;
 IF jsonb_typeof(d->'deliveryProvinces') IS DISTINCT FROM 'array' OR jsonb_array_length(d->'deliveryProvinces')>100 OR EXISTS(SELECT 1 FROM jsonb_array_elements(d->'deliveryProvinces') z WHERE jsonb_typeof(z) IS DISTINCT FROM 'string' OR length(trim(z#>>'{}')) NOT BETWEEN 1 AND 80) OR jsonb_array_length(d->'deliveryProvinces')<>(SELECT count(DISTINCT trim(z)) FROM jsonb_array_elements_text(d->'deliveryProvinces') z) THEN PERFORM ms_b1_design.b3_fail('INVALID_DELIVERY_AREAS');END IF;
 IF d->>'branchId' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND b.id=(d->>'branchId')::uuid AND b.active AND b.archived_at IS NULL) THEN PERFORM ms_b1_design.b3_fail('INVALID_SCOPE');END IF;
 IF d->>'paymentMode' IS NOT NULL AND d->>'paymentMode'<>'FULL_PREPAYMENT' THEN PERFORM ms_b1_design.b3_fail('INVALID_SHOP_CONFIGURATION');END IF;
 IF d->>'holdSeconds' IS NOT NULL AND((d->>'holdSeconds') !~ '^\d{2,4}$' OR(d->>'holdSeconds')::int NOT BETWEEN 30 AND 3600) THEN PERFORM ms_b1_design.b3_fail('INVALID_SHOP_CONFIGURATION');END IF;
 IF d->>'deliveryFeeRial' IS NOT NULL AND((d->>'deliveryFeeRial') !~ '^(0|[1-9]\d{0,18})$' OR(d->>'deliveryFeeRial')::numeric>9223372036854775807) THEN PERFORM ms_b1_design.b3_fail('INVALID_SHOP_CONFIGURATION');END IF;
 IF(d->>'enabled')::boolean AND(d->>'branchId' IS NULL OR d->>'paymentMode' IS DISTINCT FROM 'FULL_PREPAYMENT' OR d->>'holdSeconds' IS NULL OR NOT((d->>'pickupEnabled')::boolean OR(d->>'deliveryEnabled')::boolean)
 OR((d->>'deliveryEnabled')::boolean AND(d->>'deliveryFeeRial' IS NULL OR jsonb_array_length(d->'deliveryProvinces')=0)) OR length(trim(d->>'termsText'))=0 OR length(trim(d->>'returnsText'))=0 OR length(trim(d->>'shippingText'))=0 OR NOT(d->>'finalPricesConfirmed')::boolean
 OR NOT ms_b1_design.manual_method_available(bid,(d->>'branchId')::uuid)) THEN PERFORM ms_b1_design.b3_fail('SHOP_CONFIGURATION_INCOMPLETE','MS409');END IF;
 v:=(cfg->>'version')::bigint+1;
 INSERT INTO ms_b1_design.shop_configuration_version(business_id,version,document,created_by) VALUES(bid,v,d-'version',uid);
 INSERT INTO ms_b1_design.shop_configuration(business_id,version) VALUES(bid,v) ON CONFLICT(business_id) DO UPDATE SET version=excluded.version;
 result:=jsonb_build_object('version',v::text,'enabled',d->'enabled');
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES(bid,uid,'shop.configuration','shop',bid,gen_random_uuid(),result,uid);
 RETURN ms_b1_design.manual_remember(bid,uid,'shop.config',k,sig,result);
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.shop_quote_create(h bytea,csrf bytea,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;cfg jsonb;x jsonb;p ms_b1_design.shop_product;items jsonb:='[]';subtotal numeric:=0;fee numeric;total numeric;quantity integer;doc jsonb;q ms_b1_design.shop_quote;BEGIN
 a:=ms_b1_design.shop_customer_actor(h,csrf);bid:=(a->>'businessId')::uuid;PERFORM ms_b1_design.b3_keys(d,ARRAY['items','shippingMethod']);
 cfg:=ms_b1_design.shop_config(bid);IF(cfg->>'enabled')::boolean IS NOT TRUE THEN PERFORM ms_b1_design.b3_fail('SHOP_DISABLED','MS409');END IF;
 IF jsonb_typeof(d->'items') IS DISTINCT FROM 'array' OR jsonb_array_length(d->'items') NOT BETWEEN 1 AND 20 OR(d->>'shippingMethod') IS NULL OR(d->>'shippingMethod') NOT IN('PICKUP','DELIVERY') THEN PERFORM ms_b1_design.b3_fail('INVALID_CART');END IF;
 IF(d->>'shippingMethod'='PICKUP' AND(cfg->>'pickupEnabled')::boolean IS NOT TRUE) OR(d->>'shippingMethod'='DELIVERY' AND(cfg->>'deliveryEnabled')::boolean IS NOT TRUE) THEN PERFORM ms_b1_design.b3_fail('SHIPPING_UNAVAILABLE','MS409');END IF;
 IF jsonb_array_length(d->'items')<>(SELECT count(DISTINCT z->>'productId') FROM jsonb_array_elements(d->'items') z) THEN PERFORM ms_b1_design.b3_fail('INVALID_CART');END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(d->'items') ORDER BY value->>'productId' LOOP
 PERFORM ms_b1_design.b3_keys(x,ARRAY['productId','quantity']);
 IF(x->>'quantity') IS NULL OR(x->>'quantity') !~ '^[1-9]\d?$' THEN PERFORM ms_b1_design.b3_fail('INVALID_CART');END IF;quantity:=(x->>'quantity')::int;
 SELECT * INTO p FROM ms_b1_design.shop_product z WHERE z.business_id=bid AND z.id=(x->>'productId')::uuid AND z.active AND z.published AND z.archived_at IS NULL;
 IF p.id IS NULL OR p.price_rial IS NULL THEN PERFORM ms_b1_design.b3_fail('PRODUCT_UNAVAILABLE','MS409');END IF;
 IF ms_b1_design.shop_available(p)<quantity THEN PERFORM ms_b1_design.b3_fail('INSUFFICIENT_STOCK','MS409');END IF;
 items:=items||jsonb_build_array(jsonb_build_object('productId',p.id,'sku',p.sku,'name',p.name,'catalogVersion',p.catalog_version::text,'quantity',quantity,'unitRial',p.price_rial::text,'lineRial',(p.price_rial::numeric*quantity)::text));subtotal:=subtotal+p.price_rial::numeric*quantity;
 END LOOP;
 fee:=CASE WHEN d->>'shippingMethod'='DELIVERY' THEN(cfg->>'deliveryFeeRial')::numeric ELSE 0 END;total:=subtotal+fee;
 IF total IS NULL OR total<=0 OR total>9223372036854775807 THEN PERFORM ms_b1_design.b3_fail('INVALID_ORDER_TOTAL');END IF;
 doc:=jsonb_build_object('configurationVersion',cfg->>'version','branchId',cfg->>'branchId','items',items,'shippingMethod',d->>'shippingMethod','subtotalRial',subtotal::text,'shippingRial',fee::text,'totalRial',total::text,'currency','IRR','paymentMode',cfg->>'paymentMode','deliveryProvinces',cfg->'deliveryProvinces','termsText',cfg->>'termsText','returnsText',cfg->>'returnsText','shippingText',cfg->>'shippingText');
 INSERT INTO ms_b1_design.shop_quote(business_id,customer_id,configuration_version,document,content_hash,expires_at) VALUES(bid,(a->>'userId')::uuid,(cfg->>'version')::bigint,doc,sha256(convert_to(doc::text,'UTF8')),clock_timestamp()+interval '3 minutes') RETURNING * INTO q;
 RETURN jsonb_build_object('id',q.id,'content',doc,'contentHash',encode(q.content_hash,'hex'),'expiresAt',ms_b1_design.b3_iso(q.expires_at));
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.shop_quote_context(h bytea,csrf bytea,quoteid uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;q ms_b1_design.shop_quote;c ms_b1_design.customer_contact;BEGIN
 a:=ms_b1_design.shop_customer_actor(h,csrf);SELECT * INTO q FROM ms_b1_design.shop_quote WHERE id=quoteid AND business_id=(a->>'businessId')::uuid AND customer_id=(a->>'userId')::uuid;
 IF q.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 SELECT * INTO STRICT c FROM ms_b1_design.customer_contact WHERE user_id=q.customer_id;
 RETURN jsonb_build_object('shippingMethod',q.document->>'shippingMethod','deliveryProvinces',q.document->'deliveryProvinces','mobileCiphertext',c.mobile_ciphertext,'mobileLookup',encode(c.mobile_lookup,'hex'));
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.shop_public(bid uuid,mode text,slug_query text,page_offset integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE cfg jsonb;BEGIN
 IF mode IS NULL OR mode NOT IN('status','catalog','product') OR page_offset IS NULL OR page_offset NOT BETWEEN 0 AND 10000 OR length(slug_query)>100 THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 cfg:=ms_b1_design.shop_config(bid);
 IF(cfg->>'enabled')::boolean IS NOT TRUE THEN RETURN jsonb_build_object('enabled',false,'items','[]'::jsonb);END IF;
 IF mode='status' THEN RETURN jsonb_build_object('enabled',true);END IF;
 RETURN jsonb_build_object('enabled',true,'items',coalesce((SELECT jsonb_agg(ms_b1_design.shop_product_view(p,false) ORDER BY p.created_at DESC,p.id) FROM(SELECT x.* FROM ms_b1_design.shop_product x WHERE x.business_id=bid AND x.active AND x.published AND x.archived_at IS NULL AND(slug_query IS NULL OR x.slug=slug_query) ORDER BY x.created_at DESC,x.id LIMIT 24 OFFSET page_offset)p),'[]'::jsonb),'limit',24,'offset',page_offset,'deliveryProvinces',cfg->'deliveryProvinces','pickupEnabled',cfg->'pickupEnabled','deliveryEnabled',cfg->'deliveryEnabled','deliveryFeeRial',cfg->'deliveryFeeRial','termsText',cfg->'termsText','returnsText',cfg->'returnsText','shippingText',cfg->'shippingText');
END $$;
