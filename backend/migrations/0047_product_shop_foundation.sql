-- Owner-requested optional store. Defaults OFF. Products are separate from the
-- six approved salon services. No products, prices, stock or policies are seeded.
SET search_path=ms_b1_design,public;
CREATE TABLE shop_configuration_version (
 business_id uuid NOT NULL REFERENCES business(id),version bigint NOT NULL CHECK(version>0),document jsonb NOT NULL,
 created_by uuid NOT NULL REFERENCES app_user(id),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),PRIMARY KEY(business_id,version)
);
CREATE TABLE shop_configuration (
 business_id uuid PRIMARY KEY REFERENCES business(id),version bigint NOT NULL,
 FOREIGN KEY(business_id,version) REFERENCES shop_configuration_version(business_id,version)
);
CREATE TABLE shop_product (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL REFERENCES business(id),sku text NOT NULL CHECK(length(sku) BETWEEN 1 AND 80),
 slug text NOT NULL CHECK(slug ~ '^[a-z0-9][a-z0-9-]{2,99}$'),name text NOT NULL CHECK(length(name) BETWEEN 1 AND 160),description text NOT NULL CHECK(length(description)<=6000),category text NOT NULL CHECK(length(category)<=100),
 price_rial bigint CHECK(price_rial>0),stock_on_hand integer NOT NULL DEFAULT 0 CHECK(stock_on_hand>=0),cover_id uuid,
 active boolean NOT NULL DEFAULT false,published boolean NOT NULL DEFAULT false,first_published_at timestamptz,archived_at timestamptz,
 row_version bigint NOT NULL DEFAULT 1 CHECK(row_version>0),catalog_version bigint NOT NULL DEFAULT 1 CHECK(catalog_version>0),
 created_by uuid NOT NULL REFERENCES app_user(id),updated_by uuid NOT NULL REFERENCES app_user(id),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,id),UNIQUE(business_id,sku),UNIQUE(business_id,slug),FOREIGN KEY(business_id,cover_id) REFERENCES media_asset(business_id,id),
 CHECK(NOT published OR(price_rial IS NOT NULL AND archived_at IS NULL))
);
CREATE TABLE shop_quote (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL REFERENCES business(id),customer_id uuid NOT NULL REFERENCES app_user(id),
 configuration_version bigint NOT NULL,document jsonb NOT NULL,content_hash bytea NOT NULL CHECK(octet_length(content_hash)=32),
 expires_at timestamptz NOT NULL CHECK(isfinite(expires_at)),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,id),FOREIGN KEY(business_id,configuration_version) REFERENCES shop_configuration_version(business_id,version)
);
CREATE TABLE shop_order (
 id uuid PRIMARY KEY,business_id uuid NOT NULL REFERENCES business(id),branch_id uuid NOT NULL,customer_id uuid NOT NULL REFERENCES app_user(id),quote_id uuid NOT NULL UNIQUE,
 number text NOT NULL UNIQUE,status text NOT NULL CHECK(status IN('PENDING_PAYMENT','PAID','EXPIRED','CANCELLED','REFUND_REVIEW')),
 total_rial bigint NOT NULL CHECK(total_rial>0),shipping_method text NOT NULL CHECK(shipping_method IN('PICKUP','DELIVERY')),shipping_ciphertext text NOT NULL CHECK(length(shipping_ciphertext) BETWEEN 50 AND 8000),
 expires_at timestamptz NOT NULL CHECK(isfinite(expires_at)),row_version bigint NOT NULL DEFAULT 1 CHECK(row_version>0),
 fulfillment_state text NOT NULL DEFAULT 'PLANNED' CHECK(fulfillment_state IN('PLANNED','PACKED','SHIPPED','DELIVERED','PICKUP_READY','COLLECTED')),
 tracking_reference text CHECK(length(tracking_reference)<=160),cancellation_requested_at timestamptz,cancellation_state text CHECK(cancellation_state IN('REQUESTED','DECLINED','ACCEPTED')),paid_at timestamptz,
 CHECK((paid_at IS NOT NULL)=(status IN('PAID','REFUND_REVIEW'))),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,id),FOREIGN KEY(business_id,branch_id) REFERENCES branch(business_id,id),FOREIGN KEY(business_id,quote_id) REFERENCES shop_quote(business_id,id)
);
CREATE TABLE shop_order_item (
 business_id uuid NOT NULL,order_id uuid NOT NULL,product_id uuid NOT NULL,quantity integer NOT NULL CHECK(quantity BETWEEN 1 AND 99),unit_rial bigint NOT NULL CHECK(unit_rial>0),snapshot jsonb NOT NULL,
 PRIMARY KEY(business_id,order_id,product_id),FOREIGN KEY(business_id,order_id) REFERENCES shop_order(business_id,id),FOREIGN KEY(business_id,product_id) REFERENCES shop_product(business_id,id)
);
CREATE TABLE shop_stock_hold (
 business_id uuid NOT NULL,order_id uuid NOT NULL,product_id uuid NOT NULL,quantity integer NOT NULL CHECK(quantity BETWEEN 1 AND 99),expires_at timestamptz NOT NULL,released_at timestamptz,
 PRIMARY KEY(business_id,order_id,product_id),FOREIGN KEY(business_id,order_id,product_id) REFERENCES shop_order_item(business_id,order_id,product_id)
);
CREATE INDEX shop_stock_pending ON shop_stock_hold(business_id,product_id,expires_at) WHERE released_at IS NULL;
CREATE INDEX shop_customer_orders ON shop_order(business_id,customer_id,created_at DESC,id);
CREATE INDEX shop_branch_orders ON shop_order(business_id,branch_id,created_at DESC,id);
CREATE TABLE shop_stock_movement (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,product_id uuid NOT NULL,order_id uuid,
 delta integer NOT NULL CHECK(delta<>0),resulting_stock integer NOT NULL CHECK(resulting_stock>=0),kind text NOT NULL CHECK(kind IN('ADJUSTMENT','SALE','RETURN')),
 reason text NOT NULL CHECK(length(reason) BETWEEN 3 AND 300),actor_id uuid REFERENCES app_user(id),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(business_id,product_id) REFERENCES shop_product(business_id,id),FOREIGN KEY(business_id,order_id) REFERENCES shop_order(business_id,id),UNIQUE(order_id,product_id,kind)
);
CREATE TABLE shop_order_event (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,order_id uuid NOT NULL,kind text NOT NULL,actor_id uuid REFERENCES app_user(id),details jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(business_id,order_id) REFERENCES shop_order(business_id,id)
);
CREATE TRIGGER shop_config_immutable BEFORE UPDATE OR DELETE ON shop_configuration_version FOR EACH ROW EXECUTE FUNCTION b3_freeze();
CREATE TRIGGER shop_quote_immutable BEFORE UPDATE OR DELETE ON shop_quote FOR EACH ROW EXECUTE FUNCTION b3_freeze();
CREATE TRIGGER shop_order_item_immutable BEFORE UPDATE OR DELETE ON shop_order_item FOR EACH ROW EXECUTE FUNCTION b3_freeze();
CREATE TRIGGER shop_stock_movement_immutable BEFORE UPDATE OR DELETE ON shop_stock_movement FOR EACH ROW EXECUTE FUNCTION b3_freeze();
CREATE TRIGGER shop_order_event_immutable BEFORE UPDATE OR DELETE ON shop_order_event FOR EACH ROW EXECUTE FUNCTION b3_freeze();
-- One common financial intent/receipt/refund ledger, with mutually exclusive
-- BOOKING and ORDER targets. Never construct a fake salon booking for a product.
ALTER TABLE product_payment_intent ALTER COLUMN booking_id DROP NOT NULL;
ALTER TABLE product_payment_intent ALTER COLUMN revision_id DROP NOT NULL;
ALTER TABLE product_payment_intent ADD COLUMN order_id uuid;
ALTER TABLE product_payment_intent ADD FOREIGN KEY(business_id,order_id) REFERENCES shop_order(business_id,id);
ALTER TABLE product_payment_intent ADD UNIQUE(business_id,order_id);
ALTER TABLE product_payment_intent ADD UNIQUE(business_id,id,order_id);
ALTER TABLE product_payment_intent ADD CONSTRAINT payment_target_exclusive CHECK((order_id IS NULL AND booking_id IS NOT NULL AND revision_id IS NOT NULL) OR(order_id IS NOT NULL AND booking_id IS NULL AND revision_id IS NULL));
ALTER TABLE product_refund_case ALTER COLUMN booking_id DROP NOT NULL;
ALTER TABLE product_refund_case ADD COLUMN order_id uuid;
ALTER TABLE product_refund_case ADD FOREIGN KEY(business_id,order_id) REFERENCES shop_order(business_id,id);
ALTER TABLE product_refund_case ADD FOREIGN KEY(business_id,intent_id,order_id) REFERENCES product_payment_intent(business_id,id,order_id);
ALTER TABLE product_refund_case ADD CONSTRAINT refund_target_exclusive CHECK((booking_id IS NULL)<>(order_id IS NULL));
REVOKE ALL ON shop_configuration_version,shop_configuration,shop_product,shop_quote,shop_order,shop_order_item,shop_stock_hold,shop_stock_movement,shop_order_event FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
INSERT INTO permission(permission_key,description) VALUES('shop.customer','Create and read own product orders'),('shop.catalog.read','Read product drafts and inventory'),('shop.catalog.manage','Manage product catalog and inventory'),('shop.configure','Configure and enable the optional store'),('shop.orders.read','Read scoped product orders'),('shop.orders.manage','Manage scoped fulfillment') ON CONFLICT(permission_key) DO NOTHING;
INSERT INTO role_permission(business_id,role_id,permission_id) SELECT r.business_id,r.id,p.id FROM role r CROSS JOIN permission p WHERE
 (r.role_key='OWNER' AND p.permission_key LIKE 'shop.%') OR(r.role_key='CUSTOMER' AND p.permission_key='shop.customer') OR(r.role_key='BRANCH_MANAGER' AND p.permission_key IN('shop.orders.read','shop.orders.manage')) ON CONFLICT DO NOTHING;
SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.shop_config(bid uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT coalesce((SELECT v.document||jsonb_build_object('version',c.version::text) FROM ms_b1_design.shop_configuration c JOIN ms_b1_design.shop_configuration_version v ON v.business_id=c.business_id AND v.version=c.version WHERE c.business_id=bid),jsonb_build_object('version','0','enabled',false,'branchId',NULL,'paymentMode',NULL,'holdSeconds',NULL,'pickupEnabled',false,'deliveryEnabled',false,'deliveryFeeRial',NULL,'termsText','','returnsText','','shippingText','','finalPricesConfirmed',false))
$$;
CREATE FUNCTION ms_b1_design.shop_available(p ms_b1_design.shop_product) RETURNS integer LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT greatest(0,p.stock_on_hand-coalesce((SELECT sum(h.quantity) FROM ms_b1_design.shop_stock_hold h WHERE h.business_id=p.business_id AND h.product_id=p.id AND h.released_at IS NULL AND h.expires_at>clock_timestamp()),0))::integer
$$;
CREATE FUNCTION ms_b1_design.shop_cover(bid uuid,assetid uuid) RETURNS uuid LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT m.id FROM ms_b1_design.media_asset m WHERE m.business_id=bid AND m.id=assetid AND m.kind='IMAGE' AND m.state='PUBLISHED' AND ms_b1_design.mvp_rights_current(bid,m.id)
$$;
CREATE FUNCTION ms_b1_design.shop_product_view(p ms_b1_design.shop_product,private_view boolean) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('id',p.id,'sku',p.sku,'slug',p.slug,'name',p.name,'description',p.description,'category',p.category,'priceRial',p.price_rial::text,'availableQuantity',ms_b1_design.shop_available(p),'coverId',ms_b1_design.shop_cover(p.business_id,p.cover_id))||CASE WHEN private_view THEN jsonb_build_object('version',p.row_version::text,'catalogVersion',p.catalog_version::text,'stockOnHand',p.stock_on_hand,'active',p.active,'published',p.published,'archivedAt',ms_b1_design.b3_iso(p.archived_at),'draftCoverId',p.cover_id) ELSE '{}'::jsonb END
$$;
CREATE FUNCTION ms_b1_design.shop_event(o ms_b1_design.shop_order,uid uuid,k text,d jsonb) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 INSERT INTO ms_b1_design.shop_order_event(business_id,order_id,kind,actor_id,details) VALUES(o.business_id,o.id,k,uid,d);
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,branch_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES(o.business_id,uid,o.branch_id,'shop.'||k,'shop_order',o.id,gen_random_uuid(),d,uid);
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at,created_by) VALUES(o.business_id,'shop_order',o.id,o.row_version,'shop.'||k,1,d||jsonb_build_object('orderId',o.id),clock_timestamp(),uid);
END $$;
CREATE FUNCTION ms_b1_design.shop_expire(bid uuid) RETURNS integer LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE o ms_b1_design.shop_order;n integer:=0;BEGIN
 PERFORM ms_b1_design.b4_lock(bid);
 FOR o IN SELECT * FROM ms_b1_design.shop_order x WHERE x.business_id=bid AND x.status='PENDING_PAYMENT' AND x.expires_at<=clock_timestamp() ORDER BY x.id LIMIT 100 FOR UPDATE LOOP
 UPDATE ms_b1_design.shop_stock_hold SET released_at=clock_timestamp() WHERE order_id=o.id AND released_at IS NULL;
 UPDATE ms_b1_design.shop_order SET status='EXPIRED',row_version=row_version+1,updated_at=clock_timestamp() WHERE id=o.id RETURNING * INTO o;
 PERFORM ms_b1_design.shop_event(o,NULL,'expired',jsonb_build_object('status','EXPIRED'));n:=n+1;END LOOP;RETURN n;
END $$;
CREATE FUNCTION ms_b1_design.shop_public(bid uuid,mode text,slug_query text,page_offset integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE cfg jsonb;BEGIN
 IF mode IS NULL OR mode NOT IN('status','catalog','product') OR page_offset IS NULL OR page_offset NOT BETWEEN 0 AND 10000 OR length(slug_query)>100 THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 cfg:=ms_b1_design.shop_config(bid);
 IF(cfg->>'enabled')::boolean IS NOT TRUE THEN RETURN jsonb_build_object('enabled',false,'items','[]'::jsonb);END IF;
 IF mode='status' THEN RETURN jsonb_build_object('enabled',true);END IF;
 RETURN jsonb_build_object('enabled',true,'items',coalesce((SELECT jsonb_agg(ms_b1_design.shop_product_view(p,false) ORDER BY p.created_at DESC,p.id) FROM(SELECT x.* FROM ms_b1_design.shop_product x WHERE x.business_id=bid AND x.active AND x.published AND x.archived_at IS NULL AND(slug_query IS NULL OR x.slug=slug_query) ORDER BY x.created_at DESC,x.id LIMIT 24 OFFSET page_offset)p),'[]'::jsonb),'limit',24,'offset',page_offset,'pickupEnabled',cfg->'pickupEnabled','deliveryEnabled',cfg->'deliveryEnabled','deliveryFeeRial',cfg->'deliveryFeeRial','termsText',cfg->'termsText','returnsText',cfg->'returnsText','shippingText',cfg->'shippingText');
END $$;
CREATE FUNCTION ms_b1_design.shop_admin_read(h bytea,kind text,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;bid uuid;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);bid:=(a->>'businessId')::uuid;PERFORM ms_b1_design.b3_keys(d,ARRAY['offset']);
 IF(d->>'offset') IS NULL OR(d->>'offset') !~ '^\d{1,5}$' OR(d->>'offset')::int>10000 THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 IF kind='settings' THEN
 IF NOT ms_b1_design.b1b_can(a,'shop.configure',NULL) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;RETURN ms_b1_design.shop_config(bid);
 ELSIF kind='products' THEN
 IF NOT ms_b1_design.b1b_can(a,'shop.catalog.read',NULL) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(ms_b1_design.shop_product_view(p,true) ORDER BY p.created_at DESC,p.id) FROM(SELECT x.* FROM ms_b1_design.shop_product x WHERE x.business_id=bid ORDER BY x.created_at DESC,x.id LIMIT 24 OFFSET(d->>'offset')::int)p),'[]'::jsonb),'limit',24,'offset',(d->>'offset')::int);
 ELSE PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
END $$;
CREATE FUNCTION ms_b1_design.shop_config_save(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;cfg jsonb;v bigint;result jsonb;BEGIN
 a:=ms_b1_design.manual_financial_actor(h,csrf,NULL,'shop.configure');bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);
 PERFORM ms_b1_design.b3_keys(d,ARRAY['version','enabled','branchId','paymentMode','holdSeconds','pickupEnabled','deliveryEnabled','deliveryFeeRial','termsText','returnsText','shippingText','finalPricesConfirmed']);
 result:=ms_b1_design.manual_replay(bid,uid,'shop.config',k,sig);IF result IS NOT NULL THEN RETURN result;END IF;
 cfg:=ms_b1_design.shop_config(bid);IF cfg->>'version' IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF jsonb_typeof(d->'enabled') IS DISTINCT FROM 'boolean' OR jsonb_typeof(d->'pickupEnabled') IS DISTINCT FROM 'boolean' OR jsonb_typeof(d->'deliveryEnabled') IS DISTINCT FROM 'boolean' OR jsonb_typeof(d->'finalPricesConfirmed') IS DISTINCT FROM 'boolean'
 OR jsonb_typeof(d->'termsText') IS DISTINCT FROM 'string' OR jsonb_typeof(d->'returnsText') IS DISTINCT FROM 'string' OR jsonb_typeof(d->'shippingText') IS DISTINCT FROM 'string' OR length(d->>'termsText')>4000 OR length(d->>'returnsText')>4000 OR length(d->>'shippingText')>4000 THEN PERFORM ms_b1_design.b3_fail('INVALID_SHOP_CONFIGURATION');END IF;
 IF d->>'branchId' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND b.id=(d->>'branchId')::uuid AND b.active AND b.archived_at IS NULL) THEN PERFORM ms_b1_design.b3_fail('INVALID_SCOPE');END IF;
 IF d->>'paymentMode' IS NOT NULL AND d->>'paymentMode'<>'FULL_PREPAYMENT' THEN PERFORM ms_b1_design.b3_fail('INVALID_SHOP_CONFIGURATION');END IF;
 IF d->>'holdSeconds' IS NOT NULL AND((d->>'holdSeconds') !~ '^\d{2,4}$' OR(d->>'holdSeconds')::int NOT BETWEEN 30 AND 3600) THEN PERFORM ms_b1_design.b3_fail('INVALID_SHOP_CONFIGURATION');END IF;
 IF d->>'deliveryFeeRial' IS NOT NULL AND((d->>'deliveryFeeRial') !~ '^(0|[1-9]\d{0,18})$' OR(d->>'deliveryFeeRial')::numeric>9223372036854775807) THEN PERFORM ms_b1_design.b3_fail('INVALID_SHOP_CONFIGURATION');END IF;
 IF(d->>'enabled')::boolean AND(d->>'branchId' IS NULL OR d->>'paymentMode' IS DISTINCT FROM 'FULL_PREPAYMENT' OR d->>'holdSeconds' IS NULL OR NOT((d->>'pickupEnabled')::boolean OR(d->>'deliveryEnabled')::boolean)
 OR((d->>'deliveryEnabled')::boolean AND d->>'deliveryFeeRial' IS NULL) OR length(trim(d->>'termsText'))=0 OR length(trim(d->>'returnsText'))=0 OR length(trim(d->>'shippingText'))=0 OR NOT(d->>'finalPricesConfirmed')::boolean
 OR NOT ms_b1_design.manual_method_available(bid,(d->>'branchId')::uuid)) THEN PERFORM ms_b1_design.b3_fail('SHOP_CONFIGURATION_INCOMPLETE','MS409');END IF;
 v:=(cfg->>'version')::bigint+1;
 INSERT INTO ms_b1_design.shop_configuration_version(business_id,version,document,created_by) VALUES(bid,v,d-'version',uid);
 INSERT INTO ms_b1_design.shop_configuration(business_id,version) VALUES(bid,v) ON CONFLICT(business_id) DO UPDATE SET version=excluded.version;
 result:=jsonb_build_object('version',v::text,'enabled',d->'enabled');
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES(bid,uid,'shop.configuration','shop',bid,gen_random_uuid(),result,uid);
 RETURN ms_b1_design.manual_remember(bid,uid,'shop.config',k,sig,result);
END $$;
CREATE FUNCTION ms_b1_design.shop_product_command(h bytea,csrf bytea,k uuid,sig bytea,op text,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;p ms_b1_design.shop_product;result jsonb;delta integer;held bigint;target uuid;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;
 IF NOT ms_b1_design.b1b_can(a,'shop.catalog.manage',NULL) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF op IS NULL OR op NOT IN('save','stock','archive') THEN PERFORM ms_b1_design.b3_fail('INVALID_SHOP_PRODUCT');END IF;
 PERFORM ms_b1_design.b4_lock(bid);PERFORM ms_b1_design.shop_expire(bid);
 result:=ms_b1_design.manual_replay(bid,uid,'shop.product.'||op,k,sig);IF result IS NOT NULL THEN RETURN result;END IF;
 IF(d->>'version') IS NULL OR(d->>'version') !~ '^\d{1,19}$' THEN PERFORM ms_b1_design.b3_fail('INVALID_SHOP_PRODUCT');END IF;
 SELECT * INTO p FROM ms_b1_design.shop_product x WHERE x.business_id=bid AND x.id=(d->>'id')::uuid FOR UPDATE;
 IF coalesce(p.row_version,0)::text IS DISTINCT FROM d->>'version' OR(p.id IS NULL AND d->>'id' IS NOT NULL) THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF p.archived_at IS NOT NULL THEN PERFORM ms_b1_design.b3_fail('PRODUCT_ARCHIVED','MS409');END IF;
 IF op='save' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','version','sku','slug','name','description','category','priceRial','active','published','coverId']);
 IF jsonb_typeof(d->'sku') IS DISTINCT FROM 'string' OR length(trim(d->>'sku')) NOT BETWEEN 1 AND 80 OR(d->>'slug') IS NULL OR(d->>'slug') !~ '^[a-z0-9][a-z0-9-]{2,99}$'
 OR jsonb_typeof(d->'name') IS DISTINCT FROM 'string' OR length(trim(d->>'name')) NOT BETWEEN 1 AND 160 OR jsonb_typeof(d->'description') IS DISTINCT FROM 'string' OR length(d->>'description')>6000 OR jsonb_typeof(d->'category') IS DISTINCT FROM 'string' OR length(d->>'category')>100
 OR jsonb_typeof(d->'active') IS DISTINCT FROM 'boolean' OR jsonb_typeof(d->'published') IS DISTINCT FROM 'boolean' OR(d->>'priceRial' IS NOT NULL AND((d->>'priceRial') !~ '^[1-9]\d{0,18}$' OR(d->>'priceRial')::numeric>9223372036854775807)) THEN PERFORM ms_b1_design.b3_fail('INVALID_SHOP_PRODUCT');END IF;
 IF(d->>'published')::boolean AND(d->>'priceRial' IS NULL OR(d->>'coverId' IS NOT NULL AND ms_b1_design.shop_cover(bid,(d->>'coverId')::uuid) IS NULL)) THEN PERFORM ms_b1_design.b3_fail('PRODUCT_PUBLICATION_INCOMPLETE','MS409');END IF;
 IF d->>'coverId' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.media_asset m WHERE m.business_id=bid AND m.id=(d->>'coverId')::uuid AND m.kind='IMAGE' AND m.state<>'ARCHIVED') THEN PERFORM ms_b1_design.b3_fail('INVALID_PRODUCT_COVER');END IF;
 IF p.first_published_at IS NOT NULL AND p.slug IS DISTINCT FROM d->>'slug' THEN PERFORM ms_b1_design.b3_fail('PRODUCT_SLUG_IMMUTABLE','MS409');END IF;
 target:=coalesce(p.id,gen_random_uuid());
 INSERT INTO ms_b1_design.shop_product(id,business_id,sku,slug,name,description,category,price_rial,cover_id,active,published,first_published_at,created_by,updated_by)
 VALUES(target,bid,trim(d->>'sku'),d->>'slug',trim(d->>'name'),d->>'description',d->>'category',(d->>'priceRial')::bigint,(d->>'coverId')::uuid,(d->>'active')::boolean,(d->>'published')::boolean,CASE WHEN(d->>'published')::boolean THEN clock_timestamp() END,uid,uid)
 ON CONFLICT(id) DO UPDATE SET sku=excluded.sku,slug=excluded.slug,name=excluded.name,description=excluded.description,category=excluded.category,price_rial=excluded.price_rial,cover_id=excluded.cover_id,active=excluded.active,published=excluded.published,first_published_at=coalesce(shop_product.first_published_at,excluded.first_published_at),row_version=shop_product.row_version+1,catalog_version=shop_product.catalog_version+1,updated_by=uid,updated_at=clock_timestamp() RETURNING * INTO p;
 ELSIF op='stock' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','version','delta','reason']);
 IF p.id IS NULL OR(d->>'delta') IS NULL OR(d->>'delta') !~ '^-?[1-9]\d{0,8}$' OR(d->>'reason') IS NULL OR length(trim(d->>'reason')) NOT BETWEEN 3 AND 300 THEN PERFORM ms_b1_design.b3_fail('INVALID_STOCK_ADJUSTMENT');END IF;
 delta:=(d->>'delta')::int;
 SELECT coalesce(sum(quantity),0) INTO held FROM ms_b1_design.shop_stock_hold x WHERE x.product_id=p.id AND x.released_at IS NULL AND x.expires_at>clock_timestamp();
 IF p.stock_on_hand::bigint+delta<held OR p.stock_on_hand::bigint+delta>2147483647 THEN PERFORM ms_b1_design.b3_fail('STOCK_RESERVED_OR_INVALID','MS409');END IF;
 UPDATE ms_b1_design.shop_product SET stock_on_hand=stock_on_hand+delta,row_version=row_version+1,updated_by=uid,updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;
 INSERT INTO ms_b1_design.shop_stock_movement(business_id,product_id,delta,resulting_stock,kind,reason,actor_id) VALUES(bid,p.id,delta,p.stock_on_hand,'ADJUSTMENT',trim(d->>'reason'),uid);
 ELSE
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','version']);IF p.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 UPDATE ms_b1_design.shop_product SET active=false,published=false,archived_at=clock_timestamp(),row_version=row_version+1,catalog_version=catalog_version+1,updated_by=uid,updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;
 END IF;
 result:=ms_b1_design.shop_product_view(p,true);
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES(bid,uid,'shop.product.'||op,'shop_product',p.id,gen_random_uuid(),jsonb_build_object('version',p.row_version::text),uid);
 RETURN ms_b1_design.manual_remember(bid,uid,'shop.product.'||op,k,sig,result);
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.shop_config(uuid),ms_b1_design.shop_available(ms_b1_design.shop_product),ms_b1_design.shop_cover(uuid,uuid),ms_b1_design.shop_product_view(ms_b1_design.shop_product,boolean),ms_b1_design.shop_event(ms_b1_design.shop_order,uuid,text,jsonb),ms_b1_design.shop_expire(uuid),ms_b1_design.shop_public(uuid,text,text,integer),ms_b1_design.shop_admin_read(bytea,text,jsonb),ms_b1_design.shop_config_save(bytea,bytea,uuid,bytea,jsonb),ms_b1_design.shop_product_command(bytea,bytea,uuid,bytea,text,jsonb) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.shop_public(uuid,text,text,integer),ms_b1_design.shop_admin_read(bytea,text,jsonb),ms_b1_design.shop_config_save(bytea,bytea,uuid,bytea,jsonb),ms_b1_design.shop_product_command(bytea,bytea,uuid,bytea,text,jsonb) TO ms_b1b_api;
