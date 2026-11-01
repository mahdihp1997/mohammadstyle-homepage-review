SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.shop_customer_actor(h bytea,csrf bytea) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE a jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);
 IF NOT ms_b1_design.b1b_can(a,'shop.customer',NULL) OR NOT EXISTS(SELECT 1 FROM ms_b1_design.customer_contact c WHERE c.user_id=(a->>'userId')::uuid AND c.business_id=(a->>'businessId')::uuid AND c.verified_at IS NOT NULL
 AND(NOT c.test_only OR EXISTS(SELECT 1 FROM ms_b1_design.product_runtime r WHERE r.singleton AND r.environment='test'))) THEN PERFORM ms_b1_design.b3_fail('VERIFIED_CUSTOMER_REQUIRED','MS403');END IF;RETURN a;
END $$;
CREATE FUNCTION ms_b1_design.shop_order_view(o ms_b1_design.shop_order) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('id',o.id,'number',o.number,'version',o.row_version::text,'status',o.status,'branchId',o.branch_id,'branchName',(SELECT b.display_name FROM ms_b1_design.branch b WHERE b.id=o.branch_id),'customerId',o.customer_id,
 'customerName',(SELECT u.display_name FROM ms_b1_design.app_user u WHERE u.id=o.customer_id),'totalRial',o.total_rial::text,'shippingMethod',o.shipping_method,'expiresAt',ms_b1_design.b3_iso(o.expires_at),'createdAt',ms_b1_design.b3_iso(o.created_at),'paidAt',ms_b1_design.b3_iso(o.paid_at),
 'fulfillmentState',o.fulfillment_state,'trackingReference',o.tracking_reference,'cancellationState',o.cancellation_state,
 '_privateShipping',jsonb_build_object('businessId',o.business_id,'orderId',o.id,'ciphertext',o.shipping_ciphertext),
 'quote',(SELECT q.document FROM ms_b1_design.shop_quote q WHERE q.id=o.quote_id),
 'payments',coalesce((SELECT jsonb_agg(ms_b1_design.product_payment_view(p)||jsonb_build_object('orderId',o.id)) FROM ms_b1_design.product_payment_intent p WHERE p.order_id=o.id),'[]'::jsonb),
 'history',coalesce((SELECT jsonb_agg(jsonb_build_object('kind',e.kind,'actorId',e.actor_id,'details',e.details,'at',ms_b1_design.b3_iso(e.created_at)) ORDER BY e.created_at,e.id) FROM ms_b1_design.shop_order_event e WHERE e.order_id=o.id),'[]'::jsonb))
$$;
CREATE FUNCTION ms_b1_design.shop_quote_create(h bytea,csrf bytea,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
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
 doc:=jsonb_build_object('configurationVersion',cfg->>'version','branchId',cfg->>'branchId','items',items,'shippingMethod',d->>'shippingMethod','subtotalRial',subtotal::text,'shippingRial',fee::text,'totalRial',total::text,'currency','IRR','paymentMode',cfg->>'paymentMode','termsText',cfg->>'termsText','returnsText',cfg->>'returnsText','shippingText',cfg->>'shippingText');
 INSERT INTO ms_b1_design.shop_quote(business_id,customer_id,configuration_version,document,content_hash,expires_at) VALUES(bid,(a->>'userId')::uuid,(cfg->>'version')::bigint,doc,sha256(convert_to(doc::text,'UTF8')),clock_timestamp()+interval '3 minutes') RETURNING * INTO q;
 RETURN jsonb_build_object('id',q.id,'content',doc,'contentHash',encode(q.content_hash,'hex'),'expiresAt',ms_b1_design.b3_iso(q.expires_at));
END $$;
CREATE FUNCTION ms_b1_design.shop_checkout(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;cfg jsonb;q ms_b1_design.shop_quote;o ms_b1_design.shop_order;p ms_b1_design.shop_product;x jsonb;result jsonb;qty integer;BEGIN
 a:=ms_b1_design.shop_customer_actor(h,csrf);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);PERFORM ms_b1_design.shop_expire(bid);
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','quoteId','contentHash','accepted','shippingCiphertext']);
 result:=ms_b1_design.manual_replay(bid,uid,'shop.checkout',k,sig);IF result IS NOT NULL THEN RETURN result;END IF;
 cfg:=ms_b1_design.shop_config(bid);IF(cfg->>'enabled')::boolean IS NOT TRUE THEN PERFORM ms_b1_design.b3_fail('SHOP_DISABLED','MS409');END IF;
 IF d->'accepted' IS DISTINCT FROM 'true'::jsonb OR(d->>'contentHash') IS NULL OR(d->>'contentHash') !~ '^[a-f0-9]{64}$' OR(d->>'shippingCiphertext') IS NULL OR length(d->>'shippingCiphertext') NOT BETWEEN 50 AND 8000 THEN PERFORM ms_b1_design.b3_fail('ORDER_TERMS_REQUIRED');END IF;
 SELECT * INTO q FROM ms_b1_design.shop_quote z WHERE z.id=(d->>'quoteId')::uuid AND z.business_id=bid AND z.customer_id=uid FOR UPDATE;
 IF q.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF q.content_hash<>decode(d->>'contentHash','hex') OR q.expires_at<=clock_timestamp() OR q.configuration_version::text<>cfg->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_SHOP_QUOTE','MS409');END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.shop_order z WHERE z.quote_id=q.id) THEN PERFORM ms_b1_design.b3_fail('QUOTE_ALREADY_USED','MS409');END IF;
 IF NOT ms_b1_design.manual_method_available(bid,(cfg->>'branchId')::uuid) THEN PERFORM ms_b1_design.b3_fail('PAYMENT_UNCONFIGURED','MS409');END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(q.document->'items') ORDER BY value->>'productId' LOOP
 SELECT * INTO p FROM ms_b1_design.shop_product z WHERE z.id=(x->>'productId')::uuid AND z.business_id=bid FOR UPDATE;qty:=(x->>'quantity')::int;
 IF p.id IS NULL OR NOT p.active OR NOT p.published OR p.archived_at IS NOT NULL OR p.catalog_version::text<>x->>'catalogVersion' OR p.price_rial::text<>x->>'unitRial' THEN PERFORM ms_b1_design.b3_fail('STALE_SHOP_QUOTE','MS409');END IF;
 IF ms_b1_design.shop_available(p)<qty THEN PERFORM ms_b1_design.b3_fail('INSUFFICIENT_STOCK','MS409');END IF;
 END LOOP;
 INSERT INTO ms_b1_design.shop_order(id,business_id,branch_id,customer_id,quote_id,number,status,total_rial,shipping_method,shipping_ciphertext,expires_at)
 VALUES((d->>'id')::uuid,bid,(q.document->>'branchId')::uuid,uid,q.id,'MS-'||to_char(clock_timestamp() AT TIME ZONE 'Asia/Tehran','YYYYMMDD')||'-'||upper(right(replace(d->>'id','-',''),12)),'PENDING_PAYMENT',(q.document->>'totalRial')::bigint,q.document->>'shippingMethod',d->>'shippingCiphertext',clock_timestamp()+make_interval(secs=>(cfg->>'holdSeconds')::int)) RETURNING * INTO o;
 INSERT INTO ms_b1_design.shop_order_item(business_id,order_id,product_id,quantity,unit_rial,snapshot) SELECT bid,o.id,(z->>'productId')::uuid,(z->>'quantity')::int,(z->>'unitRial')::bigint,z FROM jsonb_array_elements(q.document->'items') z;
 INSERT INTO ms_b1_design.shop_stock_hold(business_id,order_id,product_id,quantity,expires_at) SELECT bid,o.id,product_id,quantity,o.expires_at FROM ms_b1_design.shop_order_item WHERE order_id=o.id;
 PERFORM ms_b1_design.shop_event(o,uid,'created',jsonb_build_object('status',o.status,'totalRial',o.total_rial::text,'quoteHash',encode(q.content_hash,'hex')));
 result:=jsonb_build_object('id',o.id,'number',o.number,'status',o.status,'version',o.row_version::text,'expiresAt',ms_b1_design.b3_iso(o.expires_at));
 RETURN ms_b1_design.manual_remember(bid,uid,'shop.checkout',k,sig,result);
END $$;
CREATE FUNCTION ms_b1_design.shop_orders_read(h bytea,csrf bytea,mode text,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;branchid uuid;entity uuid;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;PERFORM ms_b1_design.b3_keys(d,ARRAY['id','branchId','state','offset']);
 IF mode IS NULL OR mode NOT IN('customer','admin') OR(d->>'offset') IS NULL OR(d->>'offset') !~ '^\d{1,5}$' OR(d->>'offset')::int>10000 OR(d->>'state') IS NULL OR(d->>'state') NOT IN('','PENDING_PAYMENT','PAID','EXPIRED','CANCELLED','REFUND_REVIEW') THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 branchid:=(d->>'branchId')::uuid;entity:=(d->>'id')::uuid;
 IF mode='customer' THEN PERFORM ms_b1_design.shop_customer_actor(h,csrf);
 ELSIF branchid IS NOT NULL AND NOT ms_b1_design.b1b_can(a,'shop.orders.read',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');
 ELSIF branchid IS NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND ms_b1_design.b1b_can(a,'shop.orders.read',b.id)) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 PERFORM ms_b1_design.shop_expire(bid);
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(ms_b1_design.shop_order_view(o) ORDER BY o.created_at DESC,o.id) FROM(SELECT z.* FROM ms_b1_design.shop_order z WHERE z.business_id=bid AND(entity IS NULL OR z.id=entity) AND(branchid IS NULL OR z.branch_id=branchid) AND(d->>'state'='' OR z.status=d->>'state') AND((mode='customer' AND z.customer_id=(a->>'userId')::uuid) OR(mode='admin' AND ms_b1_design.b1b_can(a,'shop.orders.read',z.branch_id))) ORDER BY z.created_at DESC,z.id LIMIT 25 OFFSET(d->>'offset')::int)o),'[]'::jsonb),'limit',25,'offset',(d->>'offset')::int);
END $$;
CREATE FUNCTION ms_b1_design.shop_order_guard() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF TG_OP='DELETE' OR NEW.row_version<>OLD.row_version+1 OR(to_jsonb(NEW)-ARRAY['status','row_version','updated_at','fulfillment_state','tracking_reference','cancellation_requested_at','cancellation_state','paid_at']) IS DISTINCT FROM(to_jsonb(OLD)-ARRAY['status','row_version','updated_at','fulfillment_state','tracking_reference','cancellation_requested_at','cancellation_state','paid_at'])
 OR NOT((OLD.status='PENDING_PAYMENT' AND NEW.status IN('PAID','EXPIRED','CANCELLED')) OR(OLD.status='PAID' AND NEW.status IN('PAID','REFUND_REVIEW'))) THEN PERFORM ms_b1_design.b3_fail('INVALID_ORDER_TRANSITION','MS409');END IF;
 IF OLD.paid_at IS NOT NULL AND NEW.paid_at IS DISTINCT FROM OLD.paid_at THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_PAYMENT_TIME');END IF;
 IF OLD.status='PENDING_PAYMENT' AND NEW.status='PAID' THEN
 IF NEW.paid_at IS NULL OR NEW.paid_at>=OLD.expires_at OR NOT EXISTS(
 SELECT 1 FROM ms_b1_design.product_payment_intent p JOIN ms_b1_design.product_payment_receipt r ON r.intent_id=p.id AND r.business_id=p.business_id
 WHERE p.business_id=OLD.business_id AND p.order_id=OLD.id AND p.booking_id IS NULL AND p.state='VERIFIED' AND r.amount_rial=OLD.total_rial AND p.amount_rial=OLD.total_rial AND r.currency='IRR'
 AND(NOT r.test_only OR EXISTS(SELECT 1 FROM ms_b1_design.product_runtime t WHERE t.singleton AND t.environment='test'))
 AND((r.evidence_type='PROVIDER_VERIFIED' AND p.provider<>'manual_card_transfer') OR(r.evidence_type='MANUAL_BANK_RECONCILED' AND p.provider='manual_card_transfer' AND EXISTS(SELECT 1 FROM ms_b1_design.product_manual_reconciliation x JOIN ms_b1_design.product_manual_review v ON v.id=x.review_id WHERE x.id=r.manual_reconciliation_id AND x.intent_id=p.id AND x.outcome='CONFIRMED' AND x.bank_statement_attested AND x.received_amount_rial=OLD.total_rial AND x.reviewed_at=NEW.paid_at AND v.reviewed_at=x.reviewed_at AND v.decision='BANK_RECONCILED'))))
 OR NOT EXISTS(SELECT 1 FROM ms_b1_design.shop_order_item i WHERE i.order_id=OLD.id)
 OR EXISTS(SELECT 1 FROM ms_b1_design.shop_order_item i WHERE i.order_id=OLD.id AND NOT EXISTS(SELECT 1 FROM ms_b1_design.shop_stock_hold h WHERE h.order_id=i.order_id AND h.product_id=i.product_id AND h.quantity=i.quantity AND h.released_at IS NULL AND h.expires_at>NEW.paid_at))
 OR EXISTS(SELECT 1 FROM ms_b1_design.shop_order_item i WHERE i.order_id=OLD.id AND NOT EXISTS(SELECT 1 FROM ms_b1_design.shop_stock_movement m WHERE m.order_id=i.order_id AND m.product_id=i.product_id AND m.kind='SALE' AND m.delta=-i.quantity)) THEN PERFORM ms_b1_design.b3_fail('ORDER_PAYMENT_PROOF_REQUIRED','MS409');END IF;
 END IF;RETURN NEW;
END $$;
CREATE TRIGGER shop_order_lifecycle BEFORE UPDATE OR DELETE ON ms_b1_design.shop_order FOR EACH ROW EXECUTE FUNCTION ms_b1_design.shop_order_guard();
CREATE FUNCTION ms_b1_design.shop_hold_guard() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF TG_OP='DELETE' OR OLD.released_at IS NOT NULL OR NEW.released_at IS NULL OR(to_jsonb(NEW)-'released_at') IS DISTINCT FROM(to_jsonb(OLD)-'released_at') THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_STOCK_HOLD');END IF;RETURN NEW;
END $$;
CREATE TRIGGER shop_hold_lifecycle BEFORE UPDATE OR DELETE ON ms_b1_design.shop_stock_hold FOR EACH ROW EXECUTE FUNCTION ms_b1_design.shop_hold_guard();
CREATE FUNCTION ms_b1_design.shop_settlement_outcome(intentid uuid,actual bigint,at_time timestamptz) RETURNS text LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
 DECLARE p ms_b1_design.product_payment_intent;o ms_b1_design.shop_order;x ms_b1_design.shop_product;BEGIN
 SELECT * INTO STRICT p FROM ms_b1_design.product_payment_intent WHERE id=intentid;
 PERFORM ms_b1_design.b4_lock(p.business_id);SELECT * INTO STRICT o FROM ms_b1_design.shop_order WHERE id=p.order_id FOR UPDATE;
 IF o.status='PENDING_PAYMENT' AND o.expires_at<=at_time THEN
 UPDATE ms_b1_design.shop_stock_hold SET released_at=clock_timestamp() WHERE order_id=o.id AND released_at IS NULL;
 UPDATE ms_b1_design.shop_order SET status='EXPIRED',row_version=row_version+1,updated_at=clock_timestamp() WHERE id=o.id RETURNING * INTO o;PERFORM ms_b1_design.shop_event(o,NULL,'expired',jsonb_build_object('status','EXPIRED'));
 END IF;
 IF actual<>p.amount_rial OR actual<>o.total_rial THEN RETURN 'AMOUNT_MISMATCH';END IF;
 IF o.expires_at<=at_time OR p.expires_at<=at_time THEN RETURN 'LATE_PAYMENT';END IF;
 IF o.status<>'PENDING_PAYMENT' THEN RETURN 'ORDER_CLOSED';END IF;
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.shop_order_item i WHERE i.order_id=o.id) OR EXISTS(SELECT 1 FROM ms_b1_design.shop_order_item i WHERE i.order_id=o.id AND NOT EXISTS(SELECT 1 FROM ms_b1_design.shop_stock_hold h WHERE h.order_id=o.id AND h.product_id=i.product_id AND h.quantity=i.quantity AND h.released_at IS NULL AND h.expires_at>at_time)) THEN RETURN 'ALLOCATION_REVIEW';END IF;
 FOR x IN SELECT z.* FROM ms_b1_design.shop_product z JOIN ms_b1_design.shop_order_item i ON i.product_id=z.id WHERE i.order_id=o.id ORDER BY z.id FOR UPDATE OF z LOOP
 IF x.stock_on_hand<(SELECT coalesce(sum(h.quantity),0) FROM ms_b1_design.shop_stock_hold h WHERE h.product_id=x.id AND h.released_at IS NULL AND h.expires_at>at_time) THEN RETURN 'ALLOCATION_REVIEW';END IF;END LOOP;
 RETURN 'CONFIRMED';
END $$;
CREATE FUNCTION ms_b1_design.shop_commit_paid(intentid uuid,at_time timestamptz,uid uuid) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
 DECLARE p ms_b1_design.product_payment_intent;o ms_b1_design.shop_order;i ms_b1_design.shop_order_item;stock integer;BEGIN
 SELECT * INTO STRICT p FROM ms_b1_design.product_payment_intent WHERE id=intentid;
 IF ms_b1_design.shop_settlement_outcome(p.id,p.amount_rial,at_time)<>'CONFIRMED' THEN PERFORM ms_b1_design.b3_fail('ORDER_ALLOCATION_REVIEW','MS409');END IF;
 SELECT * INTO STRICT o FROM ms_b1_design.shop_order WHERE id=p.order_id FOR UPDATE;
 FOR i IN SELECT * FROM ms_b1_design.shop_order_item x WHERE x.order_id=o.id ORDER BY x.product_id LOOP
 UPDATE ms_b1_design.shop_product SET stock_on_hand=stock_on_hand-i.quantity,row_version=row_version+1,updated_at=clock_timestamp() WHERE id=i.product_id RETURNING stock_on_hand INTO stock;
 INSERT INTO ms_b1_design.shop_stock_movement(business_id,product_id,order_id,delta,resulting_stock,kind,reason,actor_id) VALUES(o.business_id,i.product_id,o.id,-i.quantity,stock,'SALE','Paid order settlement',uid);
 END LOOP;
 UPDATE ms_b1_design.shop_order SET status='PAID',paid_at=at_time,row_version=row_version+1,updated_at=clock_timestamp() WHERE id=o.id RETURNING * INTO o;
 UPDATE ms_b1_design.shop_stock_hold SET released_at=clock_timestamp() WHERE order_id=o.id AND released_at IS NULL;
 PERFORM ms_b1_design.shop_event(o,uid,'paid',jsonb_build_object('status','PAID','totalRial',o.total_rial::text,'intentId',p.id));
END $$;
CREATE FUNCTION ms_b1_design.shop_order_command(h bytea,csrf bytea,k uuid,sig bytea,op text,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;o ms_b1_design.shop_order;p ms_b1_design.product_payment_intent;i ms_b1_design.shop_order_item;stock integer;result jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);PERFORM ms_b1_design.shop_expire(bid);
 IF op IS NULL OR op NOT IN('cancel','request-cancellation','fulfill','decline-cancellation','accept-cancellation') THEN PERFORM ms_b1_design.b3_fail('INVALID_ORDER_COMMAND');END IF;
 SELECT * INTO o FROM ms_b1_design.shop_order z WHERE z.business_id=bid AND z.id=(d->>'id')::uuid FOR UPDATE;
 IF o.id IS NULL OR(o.customer_id<>uid AND NOT ms_b1_design.b1b_can(a,'shop.orders.manage',o.branch_id)) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF op IN('fulfill','decline-cancellation','accept-cancellation') AND NOT ms_b1_design.b1b_can(a,'shop.orders.manage',o.branch_id) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 result:=ms_b1_design.manual_replay(bid,uid,'shop.order.'||op,k,sig);IF result IS NOT NULL THEN RETURN result;END IF;
 IF o.row_version::text IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF op='cancel' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','version']);IF o.status<>'PENDING_PAYMENT' THEN PERFORM ms_b1_design.b3_fail('ORDER_CANCELLATION_REVIEW','MS409');END IF;
 UPDATE ms_b1_design.shop_stock_hold SET released_at=clock_timestamp() WHERE order_id=o.id AND released_at IS NULL;
 UPDATE ms_b1_design.shop_order SET status='CANCELLED',row_version=row_version+1,updated_at=clock_timestamp() WHERE id=o.id RETURNING * INTO o;
 ELSIF op='request-cancellation' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','version','reason']);IF o.customer_id<>uid OR o.status<>'PAID' OR o.cancellation_state IS NOT NULL OR length(trim(coalesce(d->>'reason',''))) NOT BETWEEN 3 AND 300 THEN PERFORM ms_b1_design.b3_fail('INVALID_ORDER_COMMAND');END IF;
 UPDATE ms_b1_design.shop_order SET cancellation_state='REQUESTED',cancellation_requested_at=clock_timestamp(),row_version=row_version+1,updated_at=clock_timestamp() WHERE id=o.id RETURNING * INTO o;
 ELSIF op='fulfill' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','version','state','trackingReference']);
 IF o.status<>'PAID' OR o.cancellation_state='REQUESTED' OR((o.fulfillment_state='PLANNED' AND d->>'state'='PACKED') OR(o.shipping_method='DELIVERY' AND o.fulfillment_state='PACKED' AND d->>'state'='SHIPPED') OR(o.shipping_method='DELIVERY' AND o.fulfillment_state='SHIPPED' AND d->>'state'='DELIVERED') OR(o.shipping_method='PICKUP' AND o.fulfillment_state='PACKED' AND d->>'state'='PICKUP_READY') OR(o.shipping_method='PICKUP' AND o.fulfillment_state='PICKUP_READY' AND d->>'state'='COLLECTED')) IS NOT TRUE THEN PERFORM ms_b1_design.b3_fail('INVALID_FULFILLMENT_TRANSITION','MS409');END IF;
 IF d->>'state'='SHIPPED' AND length(trim(coalesce(d->>'trackingReference',''))) NOT BETWEEN 3 AND 160 THEN PERFORM ms_b1_design.b3_fail('TRACKING_REQUIRED');END IF;
 UPDATE ms_b1_design.shop_order SET fulfillment_state=d->>'state',tracking_reference=CASE WHEN d->>'state'='SHIPPED' THEN trim(d->>'trackingReference') ELSE tracking_reference END,row_version=row_version+1,updated_at=clock_timestamp() WHERE id=o.id RETURNING * INTO o;
 ELSIF op='decline-cancellation' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','version','reason']);IF o.status<>'PAID' OR o.cancellation_state IS DISTINCT FROM 'REQUESTED' OR length(trim(coalesce(d->>'reason',''))) NOT BETWEEN 3 AND 300 THEN PERFORM ms_b1_design.b3_fail('INVALID_ORDER_COMMAND');END IF;
 UPDATE ms_b1_design.shop_order SET cancellation_state='DECLINED',row_version=row_version+1,updated_at=clock_timestamp() WHERE id=o.id RETURNING * INTO o;
 ELSE
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','version','reason','goodsReconciled','restock']);PERFORM ms_b1_design.manual_financial_actor(h,csrf,o.branch_id,'payment.manual.review');
 IF o.status<>'PAID' OR o.cancellation_state IS DISTINCT FROM 'REQUESTED' OR d->'goodsReconciled' IS DISTINCT FROM 'true'::jsonb OR jsonb_typeof(d->'restock') IS DISTINCT FROM 'boolean' OR length(trim(coalesce(d->>'reason',''))) NOT BETWEEN 3 AND 300 THEN PERFORM ms_b1_design.b3_fail('ORDER_CANCELLATION_REVIEW','MS409');END IF;
 IF(d->>'restock')::boolean THEN FOR i IN SELECT * FROM ms_b1_design.shop_order_item x WHERE x.order_id=o.id ORDER BY x.product_id LOOP
 UPDATE ms_b1_design.shop_product SET stock_on_hand=stock_on_hand+i.quantity,row_version=row_version+1,updated_at=clock_timestamp() WHERE id=i.product_id RETURNING stock_on_hand INTO stock;
 INSERT INTO ms_b1_design.shop_stock_movement(business_id,product_id,order_id,delta,resulting_stock,kind,reason,actor_id) VALUES(bid,i.product_id,o.id,i.quantity,stock,'RETURN',trim(d->>'reason'),uid);END LOOP;END IF;
 SELECT * INTO STRICT p FROM ms_b1_design.product_payment_intent WHERE order_id=o.id AND state='VERIFIED';
 INSERT INTO ms_b1_design.product_refund_case(business_id,order_id,intent_id,reason,maximum_rial) SELECT bid,o.id,p.id,'CANCELLATION',r.amount_rial FROM ms_b1_design.product_payment_receipt r WHERE r.intent_id=p.id ON CONFLICT DO NOTHING;
 UPDATE ms_b1_design.shop_order SET status='REFUND_REVIEW',cancellation_state='ACCEPTED',row_version=row_version+1,updated_at=clock_timestamp() WHERE id=o.id RETURNING * INTO o;
 END IF;
 PERFORM ms_b1_design.shop_event(o,uid,op,jsonb_build_object('status',o.status,'fulfillmentState',o.fulfillment_state,'reason',d->>'reason','restock',d->'restock'));
 result:=jsonb_build_object('id',o.id,'status',o.status,'version',o.row_version::text,'fulfillmentState',o.fulfillment_state,'moneyExecuted',false);
 RETURN ms_b1_design.manual_remember(bid,uid,'shop.order.'||op,k,sig,result);
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.shop_customer_actor(bytea,bytea),ms_b1_design.shop_order_view(ms_b1_design.shop_order),ms_b1_design.shop_quote_create(bytea,bytea,jsonb),ms_b1_design.shop_checkout(bytea,bytea,uuid,bytea,jsonb),ms_b1_design.shop_orders_read(bytea,bytea,text,jsonb),ms_b1_design.shop_order_guard(),ms_b1_design.shop_hold_guard(),ms_b1_design.shop_settlement_outcome(uuid,bigint,timestamptz),ms_b1_design.shop_commit_paid(uuid,timestamptz,uuid),ms_b1_design.shop_order_command(bytea,bytea,uuid,bytea,text,jsonb) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.shop_quote_create(bytea,bytea,jsonb),ms_b1_design.shop_checkout(bytea,bytea,uuid,bytea,jsonb),ms_b1_design.shop_orders_read(bytea,bytea,text,jsonb),ms_b1_design.shop_order_command(bytea,bytea,uuid,bytea,text,jsonb) TO ms_b1b_api;
