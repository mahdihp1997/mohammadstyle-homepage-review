-- Typed order adapters reuse the same private receipt/reconciliation ledger.
-- Booking implementations keep their exact prior bodies, with revoked direct ACLs.
SET search_path=pg_catalog;
ALTER FUNCTION ms_b1_design.manual_receipt_access(bytea,uuid) RENAME TO booking_manual_receipt_access_v46;
REVOKE ALL ON FUNCTION ms_b1_design.booking_manual_receipt_access_v46(bytea,uuid) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
CREATE FUNCTION ms_b1_design.manual_receipt_access(h bytea,receiptid uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;r ms_b1_design.product_manual_receipt;p ms_b1_design.product_payment_intent;o ms_b1_design.shop_order;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);SELECT * INTO r FROM ms_b1_design.product_manual_receipt WHERE id=receiptid AND business_id=(a->>'businessId')::uuid;
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE id=r.intent_id;
 IF p.order_id IS NULL THEN RETURN ms_b1_design.booking_manual_receipt_access_v46(h,receiptid);END IF;
 SELECT * INTO o FROM ms_b1_design.shop_order WHERE id=p.order_id AND business_id=p.business_id;
 IF o.id IS NULL OR(o.customer_id<>(a->>'userId')::uuid AND NOT ms_b1_design.b1b_can(a,'payment.manual.read',o.branch_id)) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.product_receipt_retention WHERE receipt_id=r.id) THEN PERFORM ms_b1_design.b3_fail('RECEIPT_RETENTION_APPLIED','MS409');END IF;
 RETURN to_jsonb(r);
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.manual_receipt_access(bytea,uuid) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.manual_receipt_access(bytea,uuid) TO ms_b1b_api;
CREATE OR REPLACE FUNCTION ms_b1_design.manual_payments_read(h bytea,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;branchid uuid;fromdate date;todate date;term text;state text;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);bid:=(a->>'businessId')::uuid;PERFORM ms_b1_design.b3_keys(d,ARRAY['branchId','from','to','state','query','offset']);branchid:=(d->>'branchId')::uuid;
 IF branchid IS NOT NULL AND NOT ms_b1_design.b1b_can(a,'payment.manual.read',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF branchid IS NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND ms_b1_design.b1b_can(a,'payment.manual.read',b.id)) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF(d->>'from') IS NULL OR(d->>'from') !~ '^\d{4}-\d{2}-\d{2}$' OR(d->>'to') IS NULL OR(d->>'to') !~ '^\d{4}-\d{2}-\d{2}$' OR(d->>'offset') IS NULL OR(d->>'offset') !~ '^\d{1,5}$' OR(d->>'query') IS NULL OR length(d->>'query')>100 OR(d->>'offset')::int>10000 THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 fromdate:=(d->>'from')::date;todate:=(d->>'to')::date;term:=d->>'query';state:=d->>'state';
 IF fromdate>todate OR todate-fromdate>366 OR state IS NULL OR state NOT IN('','AWAITING_TRANSFER','UNDER_REVIEW','REJECTED','REVIEW_REQUIRED','VERIFIED') THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(x.document ORDER BY x.created_at DESC,x.id) FROM(
 SELECT p.id,p.created_at,ms_b1_design.product_payment_view(p)||jsonb_build_object('targetKind',CASE WHEN o.id IS NOT NULL THEN 'ORDER' ELSE 'BOOKING' END,'orderId',o.id,'orderNumber',o.number,'targetStatus',coalesce(o.status,b.status),'bookingStatus',b.status,'branchId',br.id,'branchName',br.display_name,
 'customer',jsonb_build_object('id',u.id,'name',u.display_name,'mobileLastFour',c.mobile_last_four)) document
 FROM ms_b1_design.product_payment_intent p LEFT JOIN ms_b1_design.booking b ON b.business_id=p.business_id AND b.id=p.booking_id LEFT JOIN ms_b1_design.shop_order o ON o.business_id=p.business_id AND o.id=p.order_id
 JOIN ms_b1_design.branch br ON br.id=coalesce(o.branch_id,b.branch_id) JOIN ms_b1_design.app_user u ON u.id=coalesce(o.customer_id,b.created_by) LEFT JOIN ms_b1_design.customer_contact c ON c.user_id=u.id
 WHERE p.business_id=bid AND p.provider='manual_card_transfer' AND(branchid IS NULL OR br.id=branchid) AND ms_b1_design.b1b_can(a,'payment.manual.read',br.id)
 AND(state='' OR p.state=state) AND(p.created_at AT TIME ZONE br.time_zone)::date BETWEEN fromdate AND todate
 AND(term='' OR coalesce(b.id,o.id)::text=term OR o.number=term OR p.id::text=term OR position(lower(term) IN lower(u.display_name))>0 OR c.mobile_last_four=term)
 ORDER BY p.created_at DESC,p.id LIMIT 25 OFFSET(d->>'offset')::int)x),'[]'::jsonb));
END $$;
CREATE FUNCTION ms_b1_design.shop_quote_context(h bytea,csrf bytea,quoteid uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;q ms_b1_design.shop_quote;c ms_b1_design.customer_contact;BEGIN
 a:=ms_b1_design.shop_customer_actor(h,csrf);SELECT * INTO q FROM ms_b1_design.shop_quote WHERE id=quoteid AND business_id=(a->>'businessId')::uuid AND customer_id=(a->>'userId')::uuid;
 IF q.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 SELECT * INTO STRICT c FROM ms_b1_design.customer_contact WHERE user_id=q.customer_id;
 RETURN jsonb_build_object('shippingMethod',q.document->>'shippingMethod','mobileCiphertext',c.mobile_ciphertext,'mobileLookup',encode(c.mobile_lookup,'hex'));
END $$;
CREATE FUNCTION ms_b1_design.shop_authorized_order_view(o ms_b1_design.shop_order,a jsonb) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT ms_b1_design.shop_order_view(o)||jsonb_build_object('payments',CASE WHEN o.customer_id=(a->>'userId')::uuid OR ms_b1_design.b1b_can(a,'payment.manual.read',o.branch_id) THEN ms_b1_design.shop_order_view(o)->'payments' ELSE '[]'::jsonb END,
 '_privateShipping',jsonb_build_object('businessId',o.business_id,'orderId',o.id,'ciphertext',o.shipping_ciphertext,'includePhone',o.customer_id=(a->>'userId')::uuid OR ms_b1_design.b1b_can(a,'customer.contact.read',o.branch_id)))
$$;
CREATE FUNCTION ms_b1_design.shop_payment_methods(h bytea,csrf bytea,orderid uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;o ms_b1_design.shop_order;p ms_b1_design.product_payment_intent;c ms_b1_design.product_payment_configuration;cards jsonb;online boolean;manual boolean;BEGIN
 a:=ms_b1_design.shop_customer_actor(h,csrf);PERFORM ms_b1_design.shop_expire((a->>'businessId')::uuid);
 SELECT * INTO o FROM ms_b1_design.shop_order WHERE id=orderid AND business_id=(a->>'businessId')::uuid AND customer_id=(a->>'userId')::uuid;
 IF o.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 c:=ms_b1_design.manual_configuration(o.business_id,o.branch_id);SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE order_id=o.id;
 online:=coalesce(c.online_enabled,false) AND EXISTS(SELECT 1 FROM ms_b1_design.product_runtime r WHERE r.singleton AND r.payment_provider<>'none');
 SELECT coalesce(jsonb_agg(ms_b1_design.manual_card_document(x,true) ORDER BY x.id IS DISTINCT FROM c.default_card_id,x.priority,x.id),'[]'::jsonb) INTO cards FROM ms_b1_design.product_bank_card x WHERE x.business_id=o.business_id AND ms_b1_design.manual_card_eligible(x,o.branch_id);
 manual:=coalesce(c.manual_enabled,false) AND jsonb_array_length(cards)>0;
 IF o.status<>'PENDING_PAYMENT' OR o.expires_at<=clock_timestamp() OR p.id IS NOT NULL THEN online:=false;manual:=false;cards:='[]';END IF;
 RETURN jsonb_build_object('orderId',o.id,'onlineEnabled',online,'manualEnabled',manual,'cards',CASE WHEN manual THEN cards ELSE '[]'::jsonb END,'mode',CASE WHEN online AND manual THEN 'BOTH' WHEN online THEN 'ONLINE_GATEWAY' WHEN manual THEN 'MANUAL_CARD_TRANSFER' ELSE 'NONE' END,'expiresAt',ms_b1_design.b3_iso(o.expires_at),'existingIntentId',p.id);
END $$;
CREATE FUNCTION ms_b1_design.shop_payment_start(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;o ms_b1_design.shop_order;p ms_b1_design.product_payment_intent;c ms_b1_design.product_bank_card;cfg ms_b1_design.product_payment_configuration;r ms_b1_design.product_runtime;result jsonb;BEGIN
 a:=ms_b1_design.shop_customer_actor(h,csrf);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);PERFORM ms_b1_design.shop_expire(bid);
 PERFORM ms_b1_design.b3_keys(d,ARRAY['orderId','version','method','cardId','callbackHash','callbackCiphertext']);
 SELECT * INTO o FROM ms_b1_design.shop_order WHERE id=(d->>'orderId')::uuid AND business_id=bid AND customer_id=uid FOR UPDATE;
 IF o.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 result:=ms_b1_design.manual_replay(bid,uid,'shop.payment.start',k,sig);IF result IS NOT NULL THEN RETURN result;END IF;
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE order_id=o.id FOR UPDATE;
 IF p.id IS NOT NULL THEN
 IF(p.provider='manual_card_transfer') IS DISTINCT FROM(d->>'method'='MANUAL_CARD_TRANSFER') OR(p.provider='manual_card_transfer' AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_manual_transfer m WHERE m.intent_id=p.id AND m.card_id=(d->>'cardId')::uuid)) THEN PERFORM ms_b1_design.b3_fail('PAYMENT_METHOD_LOCKED','MS409');END IF;
 RETURN ms_b1_design.manual_remember(bid,uid,'shop.payment.start',k,sig,jsonb_build_object('id',p.id));END IF;
 IF o.row_version::text IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF o.status<>'PENDING_PAYMENT' OR o.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('ORDER_EXPIRED','MS409');END IF;
 cfg:=ms_b1_design.manual_configuration(bid,o.branch_id);SELECT * INTO STRICT r FROM ms_b1_design.product_runtime WHERE singleton;
 IF d->>'method'='MANUAL_CARD_TRANSFER' THEN
 SELECT * INTO c FROM ms_b1_design.product_bank_card WHERE business_id=bid AND id=(d->>'cardId')::uuid FOR SHARE;
 IF cfg.manual_enabled IS DISTINCT FROM true OR c.id IS NULL OR NOT ms_b1_design.manual_card_eligible(c,o.branch_id) OR d->>'callbackHash' IS NOT NULL OR d->>'callbackCiphertext' IS NOT NULL THEN PERFORM ms_b1_design.b3_fail('CARD_UNAVAILABLE','MS409');END IF;
 INSERT INTO ms_b1_design.product_payment_intent(business_id,order_id,provider,amount_rial,state,expires_at,created_by) VALUES(bid,o.id,'manual_card_transfer',o.total_rial,'AWAITING_TRANSFER',o.expires_at,uid) RETURNING * INTO p;
 INSERT INTO ms_b1_design.product_manual_transfer(intent_id,business_id,card_id,card_version,destination_ciphertext,card_fingerprint,bank_name,last_four,max_submissions,retention_days) VALUES(p.id,bid,c.id,c.row_version,c.details_ciphertext,c.card_fingerprint,c.bank_name,c.last_four,cfg.max_receipt_submissions,cfg.receipt_retention_days);
 ELSIF d->>'method'='ONLINE_GATEWAY' THEN
 IF cfg.online_enabled IS DISTINCT FROM true OR r.payment_provider='none' THEN PERFORM ms_b1_design.b3_fail('PAYMENT_METHOD_UNAVAILABLE','MS409');END IF;
 IF d->>'cardId' IS NOT NULL OR(d->>'callbackHash') IS NULL OR(d->>'callbackHash') !~ '^[a-f0-9]{64}$' OR length(coalesce(d->>'callbackCiphertext','')) NOT BETWEEN 50 AND 500 THEN PERFORM ms_b1_design.b3_fail('INVALID_PAYMENT');END IF;
 INSERT INTO ms_b1_design.product_payment_intent(business_id,order_id,provider,amount_rial,callback_hash,callback_ciphertext,expires_at,created_by) VALUES(bid,o.id,r.payment_provider,o.total_rial,decode(d->>'callbackHash','hex'),d->>'callbackCiphertext',o.expires_at,uid) RETURNING * INTO p;
 PERFORM ms_b1_design.product_enqueue(bid,'PAYMENT_REQUEST',p.id::text,jsonb_build_object('intentId',p.id));
 ELSE PERFORM ms_b1_design.b3_fail('INVALID_PAYMENT');END IF;
 PERFORM ms_b1_design.shop_event(o,uid,'payment.requested',jsonb_build_object('orderId',o.id,'intentId',p.id,'method',d->>'method'));
 result:=jsonb_build_object('id',p.id);RETURN ms_b1_design.manual_remember(bid,uid,'shop.payment.start',k,sig,result);
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.shop_quote_context(bytea,bytea,uuid),ms_b1_design.shop_authorized_order_view(ms_b1_design.shop_order,jsonb),ms_b1_design.shop_payment_methods(bytea,bytea,uuid),ms_b1_design.shop_payment_start(bytea,bytea,uuid,bytea,jsonb) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.shop_quote_context(bytea,bytea,uuid),ms_b1_design.shop_payment_methods(bytea,bytea,uuid),ms_b1_design.shop_payment_start(bytea,bytea,uuid,bytea,jsonb) TO ms_b1b_api;
ALTER TABLE ms_b1_design.product_manual_reconciliation DROP CONSTRAINT product_manual_reconciliation_outcome_check;
ALTER TABLE ms_b1_design.product_manual_reconciliation ADD CONSTRAINT product_manual_reconciliation_outcome_check CHECK(outcome IN('CONFIRMED','LATE_PAYMENT','AMOUNT_MISMATCH','BOOKING_CLOSED','ORDER_CLOSED','ALLOCATION_REVIEW'));
ALTER FUNCTION ms_b1_design.manual_submission_context(bytea,bytea,uuid,uuid) RENAME TO booking_manual_submission_context_v46;
REVOKE ALL ON FUNCTION ms_b1_design.booking_manual_submission_context_v46(bytea,bytea,uuid,uuid) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
CREATE FUNCTION ms_b1_design.shop_manual_submission_context(h bytea,csrf bytea,intentid uuid,idem uuid DEFAULT NULL) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;p ms_b1_design.product_payment_intent;b ms_b1_design.shop_order;m ms_b1_design.product_manual_transfer;last_receipt ms_b1_design.product_manual_receipt;BEGIN
 a:=ms_b1_design.shop_customer_actor(h,csrf);SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=(a->>'businessId')::uuid AND id=intentid AND provider='manual_card_transfer';
 SELECT * INTO b FROM ms_b1_design.shop_order WHERE id=p.order_id AND business_id=p.business_id AND customer_id=(a->>'userId')::uuid;
 IF b.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 SELECT * INTO STRICT m FROM ms_b1_design.product_manual_transfer WHERE intent_id=p.id;
 IF idem IS NOT NULL AND EXISTS(SELECT 1 FROM ms_b1_design.product_manual_request q WHERE q.business_id=p.business_id AND q.actor_id=(a->>'userId')::uuid AND q.operation='receipt.submit' AND q.idempotency_key=idem AND q.response->>'intentId'=p.id::text) THEN RETURN jsonb_build_object('businessId',b.business_id,'userId',b.customer_id,'intentId',p.id,'version',m.row_version::text,'replayAvailable',true);END IF;
 IF p.state='VERIFIED' OR EXISTS(SELECT 1 FROM ms_b1_design.product_manual_reconciliation WHERE intent_id=p.id) THEN PERFORM ms_b1_design.b3_fail('MANUAL_PAYMENT_ALREADY_RECONCILED','MS409');END IF;
 SELECT * INTO last_receipt FROM ms_b1_design.product_manual_receipt WHERE intent_id=p.id ORDER BY submission DESC LIMIT 1;
 IF last_receipt.id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_manual_review WHERE receipt_id=last_receipt.id AND decision='REJECTED') THEN PERFORM ms_b1_design.b3_fail('RECEIPT_ALREADY_PENDING','MS409');END IF;
 IF coalesce(last_receipt.submission,0)>=m.max_submissions THEN PERFORM ms_b1_design.b3_fail('RECEIPT_SUBMISSION_LIMIT','MS409');END IF;
 RETURN jsonb_build_object('businessId',b.business_id,'userId',b.customer_id,'intentId',p.id,'version',m.row_version::text,'expiresAt',ms_b1_design.b3_iso(p.expires_at),'lateEvidenceOnly',p.expires_at<=clock_timestamp() OR b.status<>'PENDING_PAYMENT');
END $$;
CREATE FUNCTION ms_b1_design.manual_submission_context(h bytea,csrf bytea,intentid uuid,idem uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;is_order boolean;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);
 SELECT p.order_id IS NOT NULL INTO is_order FROM ms_b1_design.product_payment_intent p WHERE p.id=intentid AND p.business_id=(a->>'businessId')::uuid;
 IF is_order THEN RETURN ms_b1_design.shop_manual_submission_context(h,csrf,intentid,idem);END IF;
 RETURN ms_b1_design.booking_manual_submission_context_v46(h,csrf,intentid,idem);END $$;
REVOKE ALL ON FUNCTION ms_b1_design.manual_submission_context(bytea,bytea,uuid,uuid),ms_b1_design.shop_manual_submission_context(bytea,bytea,uuid,uuid) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.manual_submission_context(bytea,bytea,uuid,uuid) TO ms_b1b_api;
ALTER FUNCTION ms_b1_design.manual_receipt_submit(bytea,bytea,uuid,bytea,jsonb) RENAME TO booking_manual_receipt_submit_v46;
REVOKE ALL ON FUNCTION ms_b1_design.booking_manual_receipt_submit_v46(bytea,bytea,uuid,bytea,jsonb) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
CREATE FUNCTION ms_b1_design.shop_manual_receipt_submit(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;p ms_b1_design.product_payment_intent;b ms_b1_design.shop_order;m ms_b1_design.product_manual_transfer;r ms_b1_design.product_manual_receipt;result jsonb;n integer;BEGIN
 a:=ms_b1_design.shop_customer_actor(h,csrf);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','intentId','version','referenceCiphertext','originalKey','originalHash','originalObjectHash','originalObjectBytes','displayKey','displayHash','displayObjectHash','displayObjectBytes','mime','sourceBytes','width','height']);
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=bid AND id=(d->>'intentId')::uuid AND provider='manual_card_transfer' FOR UPDATE;
 SELECT * INTO b FROM ms_b1_design.shop_order WHERE business_id=bid AND id=p.order_id AND customer_id=uid;
 IF b.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 result:=ms_b1_design.manual_replay(bid,uid,'receipt.submit',k,sig);IF result IS NOT NULL THEN RETURN result;END IF;
 PERFORM ms_b1_design.manual_submission_context(h,csrf,p.id);
 SELECT * INTO STRICT m FROM ms_b1_design.product_manual_transfer WHERE intent_id=p.id FOR UPDATE;
 IF m.row_version::text IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 SELECT coalesce(max(submission),0)+1 INTO n FROM ms_b1_design.product_manual_receipt WHERE intent_id=p.id;
 IF(d->>'originalKey') IS DISTINCT FROM 'receipts/'||bid::text||'/'||(d->>'id')||'/original.aes' OR(d->>'displayKey') IS DISTINCT FROM 'receipts/'||bid::text||'/'||(d->>'id')||'/display.aes'
 OR(d->>'originalHash') !~ '^[a-f0-9]{64}$' OR(d->>'displayHash') !~ '^[a-f0-9]{64}$' OR(d->>'originalObjectHash') !~ '^[a-f0-9]{64}$' OR(d->>'displayObjectHash') !~ '^[a-f0-9]{64}$'
 OR(d->>'sourceBytes')::int NOT BETWEEN 1 AND 5242880 OR(d->>'width')::int NOT BETWEEN 1 AND 12000 OR(d->>'height')::int NOT BETWEEN 1 AND 12000 OR(d->>'width')::bigint*(d->>'height')::bigint>25000000 THEN PERFORM ms_b1_design.b3_fail('INVALID_RECEIPT');END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.product_manual_receipt WHERE business_id=bid AND original_sha256=decode(d->>'originalHash','hex')) THEN PERFORM ms_b1_design.b3_fail('DUPLICATE_RECEIPT','MS409');END IF;
 INSERT INTO ms_b1_design.product_manual_receipt(id,business_id,intent_id,submission,submitted_by,sender_reference_ciphertext,original_key,original_sha256,original_object_sha256,original_object_bytes,display_key,display_sha256,display_object_sha256,display_object_bytes,mime,source_bytes,width,height,retention_eligible_at)
 VALUES((d->>'id')::uuid,bid,p.id,n,uid,d->>'referenceCiphertext',d->>'originalKey',decode(d->>'originalHash','hex'),d->>'originalObjectHash',(d->>'originalObjectBytes')::bigint,d->>'displayKey',decode(d->>'displayHash','hex'),d->>'displayObjectHash',(d->>'displayObjectBytes')::bigint,d->>'mime',(d->>'sourceBytes')::int,(d->>'width')::int,(d->>'height')::int,CASE WHEN m.retention_days IS NOT NULL THEN clock_timestamp()+make_interval(days=>m.retention_days) END) RETURNING * INTO r;
 UPDATE ms_b1_design.product_manual_transfer SET row_version=row_version+1 WHERE intent_id=p.id RETURNING * INTO m;
 UPDATE ms_b1_design.product_payment_intent SET state=CASE WHEN p.expires_at<=clock_timestamp() OR b.status<>'PENDING_PAYMENT' THEN 'REVIEW_REQUIRED' ELSE 'UNDER_REVIEW' END,updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;
 result:=jsonb_build_object('id',r.id,'intentId',p.id,'submission',n,'version',m.row_version::text,'state',p.state,'paymentVerified',false,'holdExtended',false);
 PERFORM ms_b1_design.manual_event(bid,b.branch_id,uid,'manual.receipt.received',r.id,jsonb_build_object('orderId',b.id,'intentId',p.id,'receiptId',r.id,'state',p.state));
 RETURN ms_b1_design.manual_remember(bid,uid,'receipt.submit',k,sig,result);
END $$;
CREATE FUNCTION ms_b1_design.manual_receipt_submit(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;is_order boolean;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);
 SELECT p.order_id IS NOT NULL INTO is_order FROM ms_b1_design.product_payment_intent p WHERE p.id=(d->>'intentId')::uuid AND p.business_id=(a->>'businessId')::uuid;
 IF is_order THEN RETURN ms_b1_design.shop_manual_receipt_submit(h,csrf,k,sig,d);END IF;
 RETURN ms_b1_design.booking_manual_receipt_submit_v46(h,csrf,k,sig,d);END $$;
REVOKE ALL ON FUNCTION ms_b1_design.manual_receipt_submit(bytea,bytea,uuid,bytea,jsonb),ms_b1_design.shop_manual_receipt_submit(bytea,bytea,uuid,bytea,jsonb) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.manual_receipt_submit(bytea,bytea,uuid,bytea,jsonb) TO ms_b1b_api;
ALTER FUNCTION ms_b1_design.manual_review_context(bytea,bytea,uuid,uuid) RENAME TO booking_manual_review_context_v46;
REVOKE ALL ON FUNCTION ms_b1_design.booking_manual_review_context_v46(bytea,bytea,uuid,uuid) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
CREATE FUNCTION ms_b1_design.shop_manual_review_context(h bytea,csrf bytea,intentid uuid,receiptid uuid) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;p ms_b1_design.product_payment_intent;b ms_b1_design.shop_order;m ms_b1_design.product_manual_transfer;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=(a->>'businessId')::uuid AND id=intentid AND provider='manual_card_transfer';SELECT * INTO b FROM ms_b1_design.shop_order WHERE business_id=p.business_id AND id=p.order_id;
 IF b.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;PERFORM ms_b1_design.manual_financial_actor(h,csrf,b.branch_id,'payment.manual.review');
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.product_manual_receipt WHERE business_id=p.business_id AND intent_id=p.id AND id=receiptid) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 SELECT * INTO STRICT m FROM ms_b1_design.product_manual_transfer WHERE intent_id=p.id;
 RETURN jsonb_build_object('businessId',b.business_id,'intentId',p.id,'version',m.row_version::text,'cardFingerprint',encode(m.card_fingerprint,'hex'));
END $$;
CREATE FUNCTION ms_b1_design.manual_review_context(h bytea,csrf bytea,intentid uuid,receiptid uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;is_order boolean;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);
 SELECT p.order_id IS NOT NULL INTO is_order FROM ms_b1_design.product_payment_intent p WHERE p.id=intentid AND p.business_id=(a->>'businessId')::uuid;
 IF is_order THEN RETURN ms_b1_design.shop_manual_review_context(h,csrf,intentid,receiptid);END IF;
 RETURN ms_b1_design.booking_manual_review_context_v46(h,csrf,intentid,receiptid);END $$;
REVOKE ALL ON FUNCTION ms_b1_design.manual_review_context(bytea,bytea,uuid,uuid),ms_b1_design.shop_manual_review_context(bytea,bytea,uuid,uuid) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.manual_review_context(bytea,bytea,uuid,uuid) TO ms_b1b_api;
ALTER FUNCTION ms_b1_design.manual_review_decide(bytea,bytea,uuid,bytea,jsonb) RENAME TO booking_manual_review_decide_v46;
REVOKE ALL ON FUNCTION ms_b1_design.booking_manual_review_decide_v46(bytea,bytea,uuid,bytea,jsonb) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
CREATE FUNCTION ms_b1_design.shop_manual_review_decide(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;p ms_b1_design.product_payment_intent;b ms_b1_design.shop_order;m ms_b1_design.product_manual_transfer;r ms_b1_design.product_manual_receipt;v ms_b1_design.product_manual_review;x ms_b1_design.product_manual_reconciliation;hold ms_b1_design.booking_hold;cfg ms_b1_design.product_runtime;result jsonb;outcome text;old_status text;actual bigint;decision_at timestamptz;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);
 PERFORM ms_b1_design.b3_keys(d,ARRAY['intentId','receiptId','version','decision','reason','amountRial','receivedAt','bankReferenceHash','evidenceCiphertext','attested']);
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=bid AND id=(d->>'intentId')::uuid AND provider='manual_card_transfer' FOR UPDATE;
 SELECT * INTO b FROM ms_b1_design.shop_order WHERE business_id=bid AND id=p.order_id FOR UPDATE;
 IF b.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 PERFORM ms_b1_design.manual_financial_actor(h,csrf,b.branch_id,'payment.manual.review');
 result:=ms_b1_design.manual_replay(bid,uid,'receipt.review',k,sig);IF result IS NOT NULL THEN RETURN result;END IF;
 SELECT * INTO STRICT m FROM ms_b1_design.product_manual_transfer WHERE intent_id=p.id FOR UPDATE;
 SELECT * INTO r FROM ms_b1_design.product_manual_receipt WHERE business_id=bid AND intent_id=p.id AND id=(d->>'receiptId')::uuid FOR UPDATE;
 IF r.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF m.row_version::text IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF p.state='VERIFIED' OR EXISTS(SELECT 1 FROM ms_b1_design.product_manual_review WHERE receipt_id=r.id) OR r.submission<>(SELECT max(submission) FROM ms_b1_design.product_manual_receipt WHERE intent_id=p.id)
 OR EXISTS(SELECT 1 FROM ms_b1_design.product_receipt_retention WHERE receipt_id=r.id) THEN PERFORM ms_b1_design.b3_fail('RECEIPT_ALREADY_REVIEWED','MS409');END IF;
 IF(d->>'decision') NOT IN('APPROVE','REJECT') OR(d->>'reason') IS NULL OR length(d->>'reason')>300 THEN PERFORM ms_b1_design.b3_fail('INVALID_REVIEW');END IF;
 IF d->>'decision'='REJECT' THEN
 IF length(trim(d->>'reason'))<3 OR d->>'amountRial' IS NOT NULL OR d->>'receivedAt' IS NOT NULL OR d->>'bankReferenceHash' IS NOT NULL OR d->>'evidenceCiphertext' IS NOT NULL THEN PERFORM ms_b1_design.b3_fail('INVALID_REVIEW');END IF;
 INSERT INTO ms_b1_design.product_manual_review(business_id,intent_id,receipt_id,decision,reason,reviewed_by) VALUES(bid,p.id,r.id,'REJECTED',trim(d->>'reason'),uid) RETURNING * INTO v;
 UPDATE ms_b1_design.product_payment_intent SET state=CASE WHEN expires_at<=clock_timestamp() OR b.status<>'PENDING_PAYMENT' THEN 'REVIEW_REQUIRED' ELSE 'REJECTED' END,updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;
 outcome:='REJECTED';
 PERFORM ms_b1_design.manual_event(bid,b.branch_id,uid,'manual.receipt.rejected',r.id,jsonb_build_object('orderId',b.id,'intentId',p.id,'receiptId',r.id,'reason',CASE WHEN trim(d->>'reason') IN('تصویر رسید خوانا نیست','مبلغ با بیعانه مطابقت ندارد','واریز در گردش حساب یافت نشد','رسید به حساب مقصد مربوط نیست') THEN trim(d->>'reason') ELSE 'رسید نیاز به اصلاح و ارسال مجدد دارد' END));
 ELSE
 IF(d->'attested') IS DISTINCT FROM 'true'::jsonb OR(d->>'amountRial') !~ '^[1-9]\d{0,18}$' OR(d->>'amountRial')::numeric>9223372036854775807 OR(d->>'bankReferenceHash') !~ '^[a-f0-9]{64}$' OR length(d->>'evidenceCiphertext') NOT BETWEEN 50 AND 8000 OR d->>'receivedAt' IS NULL THEN PERFORM ms_b1_design.b3_fail('BANK_RECONCILIATION_REQUIRED');END IF;
 actual:=(d->>'amountRial')::bigint;
 IF NOT isfinite(ms_b1_design.b3_instant(d->>'receivedAt')) OR ms_b1_design.b3_instant(d->>'receivedAt')>clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('INVALID_BANK_TIME');END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.product_manual_reconciliation WHERE business_id=bid AND card_fingerprint=m.card_fingerprint AND bank_reference_hash=decode(d->>'bankReferenceHash','hex')) THEN PERFORM ms_b1_design.b3_fail('BANK_TRANSACTION_ALREADY_USED','MS409');END IF;
 -- Linearization is after acquiring the canonical lock, never bank arrival time.
 decision_at:=clock_timestamp();outcome:=ms_b1_design.shop_settlement_outcome(p.id,actual,decision_at);
 SELECT * INTO STRICT b FROM ms_b1_design.shop_order WHERE id=p.order_id FOR UPDATE;
 INSERT INTO ms_b1_design.product_manual_review(business_id,intent_id,receipt_id,decision,reason,reviewed_by,reviewed_at) VALUES(bid,p.id,r.id,'BANK_RECONCILED',trim(d->>'reason'),uid,decision_at) RETURNING * INTO v;
 INSERT INTO ms_b1_design.product_manual_reconciliation(business_id,intent_id,review_id,card_fingerprint,bank_reference_hash,evidence_ciphertext,received_amount_rial,received_at,bank_statement_attested,outcome,reviewed_by,review_session_id,reviewed_at)
 VALUES(bid,p.id,v.id,m.card_fingerprint,decode(d->>'bankReferenceHash','hex'),d->>'evidenceCiphertext',actual,ms_b1_design.b3_instant(d->>'receivedAt'),true,outcome,uid,(a->>'sessionId')::uuid,decision_at) RETURNING * INTO x;
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 INSERT INTO ms_b1_design.product_payment_receipt(business_id,intent_id,provider,provider_reference,amount_rial,currency,evidence_hash,test_only,evidence_type,manual_reconciliation_id)
 VALUES(bid,p.id,'manual_card_transfer','manual_'||encode(x.bank_reference_hash,'hex'),actual,'IRR',sha256(convert_to(x.evidence_ciphertext,'UTF8')),cfg.environment='test','MANUAL_BANK_RECONCILED',x.id);
 UPDATE ms_b1_design.product_payment_intent SET state='VERIFIED',updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;
 IF outcome='CONFIRMED' THEN
 PERFORM ms_b1_design.shop_commit_paid(p.id,decision_at,uid);SELECT * INTO STRICT b FROM ms_b1_design.shop_order WHERE id=p.order_id;
 ELSE
 INSERT INTO ms_b1_design.product_refund_case(business_id,order_id,intent_id,reason,maximum_rial) VALUES(bid,b.id,p.id,CASE WHEN outcome='LATE_PAYMENT' THEN 'LATE_PAYMENT' ELSE 'RECONCILIATION' END,actual) ON CONFLICT DO NOTHING;
 END IF;
 PERFORM ms_b1_design.manual_event(bid,b.branch_id,uid,'manual.receipt.approved',r.id,jsonb_build_object('orderId',b.id,'intentId',p.id,'receiptId',r.id,'evidenceType','MANUAL_BANK_RECONCILED','outcome',outcome,'amountRial',actual::text));
 END IF;
 UPDATE ms_b1_design.product_manual_transfer SET row_version=row_version+1 WHERE intent_id=p.id RETURNING * INTO m;
 result:=jsonb_build_object('id',v.id,'receiptId',r.id,'intentId',p.id,'version',m.row_version::text,'decision',v.decision,'outcome',outcome,'orderStatus',b.status,'evidenceType',CASE WHEN v.decision='BANK_RECONCILED' THEN 'MANUAL_BANK_RECONCILED' END);
 RETURN ms_b1_design.manual_remember(bid,uid,'receipt.review',k,sig,result);
END $$;
CREATE FUNCTION ms_b1_design.manual_review_decide(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;is_order boolean;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);
 SELECT p.order_id IS NOT NULL INTO is_order FROM ms_b1_design.product_payment_intent p WHERE p.id=(d->>'intentId')::uuid AND p.business_id=(a->>'businessId')::uuid;
 IF is_order THEN RETURN ms_b1_design.shop_manual_review_decide(h,csrf,k,sig,d);END IF;
 RETURN ms_b1_design.booking_manual_review_decide_v46(h,csrf,k,sig,d);END $$;
REVOKE ALL ON FUNCTION ms_b1_design.manual_review_decide(bytea,bytea,uuid,bytea,jsonb),ms_b1_design.shop_manual_review_decide(bytea,bytea,uuid,bytea,jsonb) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.manual_review_decide(bytea,bytea,uuid,bytea,jsonb) TO ms_b1b_api;

CREATE OR REPLACE FUNCTION ms_b1_design.shop_orders_read(h bytea,csrf bytea,mode text,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;branchid uuid;entity uuid;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;PERFORM ms_b1_design.b3_keys(d,ARRAY['id','branchId','state','offset']);
 IF mode IS NULL OR mode NOT IN('customer','admin') OR(d->>'offset') IS NULL OR(d->>'offset') !~ '^\d{1,5}$' OR(d->>'offset')::int>10000 OR(d->>'state') IS NULL OR(d->>'state') NOT IN('','PENDING_PAYMENT','PAID','EXPIRED','CANCELLED','REFUND_REVIEW') THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 branchid:=(d->>'branchId')::uuid;entity:=(d->>'id')::uuid;
 IF mode='customer' THEN PERFORM ms_b1_design.shop_customer_actor(h,csrf);
 ELSIF branchid IS NOT NULL AND NOT ms_b1_design.b1b_can(a,'shop.orders.read',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');
 ELSIF branchid IS NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND ms_b1_design.b1b_can(a,'shop.orders.read',b.id)) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 PERFORM ms_b1_design.shop_expire(bid);
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(ms_b1_design.shop_authorized_order_view(o,a) ORDER BY o.created_at DESC,o.id) FROM(SELECT z.* FROM ms_b1_design.shop_order z WHERE z.business_id=bid AND(entity IS NULL OR z.id=entity) AND(branchid IS NULL OR z.branch_id=branchid) AND(d->>'state'='' OR z.status=d->>'state') AND((mode='customer' AND z.customer_id=(a->>'userId')::uuid) OR(mode='admin' AND ms_b1_design.b1b_can(a,'shop.orders.read',z.branch_id))) ORDER BY z.created_at DESC,z.id LIMIT 25 OFFSET(d->>'offset')::int)o),'[]'::jsonb),'limit',25,'offset',(d->>'offset')::int);
END $$;

ALTER FUNCTION ms_b1_design.product_payment_result(uuid,uuid,jsonb) RENAME TO booking_product_payment_result_v46;
REVOKE ALL ON FUNCTION ms_b1_design.booking_product_payment_result_v46(uuid,uuid,jsonb) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
CREATE FUNCTION ms_b1_design.shop_product_payment_result(jobid uuid,t uuid,result jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE j ms_b1_design.product_delivery;p ms_b1_design.product_payment_intent;b ms_b1_design.booking;cfg ms_b1_design.product_runtime;hold ms_b1_design.booking_hold;old_status text;existing ms_b1_design.product_payment_receipt;decision_at timestamptz;outcome text;BEGIN
 SELECT * INTO j FROM ms_b1_design.product_delivery WHERE id=jobid;IF NOT FOUND THEN RETURN NULL;END IF;
 PERFORM ms_b1_design.b4_lock(j.business_id);
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE id=(j.payload->>'intentId')::uuid FOR UPDATE;
 SELECT * INTO j FROM ms_b1_design.product_delivery WHERE id=jobid AND lease_token=t AND lease_until>clock_timestamp() AND state='DISPATCHED' FOR UPDATE;
 IF NOT FOUND OR j.kind NOT IN('PAYMENT_REQUEST','PAYMENT_VERIFY') OR p.id IS NULL THEN RETURN NULL;END IF;
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 IF p.provider<>cfg.payment_provider OR(p.provider='mock' AND cfg.environment<>'test') THEN PERFORM ms_b1_design.b3_fail('PROVIDER_REALM_MISMATCH','MS403');END IF;
 IF p.state='VERIFIED' THEN PERFORM ms_b1_design.product_delivery_state(jobid,t,'DELIVERED','ALREADY_VERIFIED',NULL);RETURN ms_b1_design.product_payment_view(p);END IF;
 IF j.kind='PAYMENT_REQUEST' THEN
 IF result->>'status'='created' THEN
 IF result->>'authority' IS NULL OR result->>'hostedUrl' IS NULL OR result->>'authority' !~ '^[A-Za-z0-9_-]{8,160}$' OR length(result->>'hostedUrl')>500 OR result->>'hostedUrl' NOT LIKE 'http://127.0.0.1:%' THEN PERFORM ms_b1_design.b3_fail('INVALID_PROVIDER_RESPONSE');END IF;
 UPDATE ms_b1_design.product_payment_intent SET authority=result->>'authority',hosted_url=result->>'hostedUrl',state='REDIRECT_READY',updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;
 PERFORM ms_b1_design.product_enqueue(p.business_id,'PAYMENT_VERIFY',p.id::text,jsonb_build_object('intentId',p.id),clock_timestamp()+interval '45 seconds');
 PERFORM ms_b1_design.product_money_event(p,'product.payment.redirect.ready','{}');PERFORM ms_b1_design.product_delivery_state(jobid,t,'DELIVERED','REQUEST_CREATED',NULL);
 ELSIF result->>'status'='declined' THEN UPDATE ms_b1_design.product_payment_intent SET state='DECLINED',updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;PERFORM ms_b1_design.product_money_event(p,'product.payment.declined','{}');PERFORM ms_b1_design.product_delivery_state(jobid,t,'DELIVERED','PROVIDER_DECLINED',NULL);
 ELSIF result->>'status'='closed' THEN UPDATE ms_b1_design.product_payment_intent SET state='CLOSED',updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;PERFORM ms_b1_design.product_delivery_state(jobid,t,'CANCELLED','HOLD_EXPIRED',NULL);
 ELSE UPDATE ms_b1_design.product_payment_intent SET state='UNKNOWN',updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;PERFORM ms_b1_design.product_delivery_state(jobid,t,CASE WHEN result->>'retrySafe'='true' THEN 'READY' ELSE 'UNKNOWN' END,'REQUEST_AMBIGUOUS',NULL);END IF;
 ELSE
 IF result->>'status'='paid' THEN
 IF result->>'amountRial' IS DISTINCT FROM p.amount_rial::text OR result->>'currency' IS DISTINCT FROM 'IRR' OR result->>'authority' IS DISTINCT FROM p.authority OR result->>'reference' !~ '^[A-Za-z0-9_-]{8,160}$' OR result->>'evidenceHash' !~ '^[a-f0-9]{64}$' THEN
 UPDATE ms_b1_design.product_payment_intent SET state='UNKNOWN',updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;PERFORM ms_b1_design.product_money_event(p,'product.payment.verification.mismatch','{}');PERFORM ms_b1_design.product_delivery_state(jobid,t,'UNKNOWN','VERIFICATION_MISMATCH',NULL);RETURN ms_b1_design.product_payment_view(p);END IF;
 SELECT * INTO existing FROM ms_b1_design.product_payment_receipt WHERE provider=p.provider AND provider_reference=result->>'reference';
 IF FOUND AND existing.intent_id<>p.id THEN
 UPDATE ms_b1_design.product_payment_intent SET state='UNKNOWN',updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;PERFORM ms_b1_design.product_money_event(p,'product.payment.duplicate.reference','{}');PERFORM ms_b1_design.product_delivery_state(jobid,t,'UNKNOWN','DUPLICATE_REFERENCE',NULL);RETURN ms_b1_design.product_payment_view(p);END IF;
 INSERT INTO ms_b1_design.product_payment_receipt(business_id,intent_id,provider,provider_reference,amount_rial,currency,evidence_hash,test_only) VALUES(p.business_id,p.id,p.provider,result->>'reference',p.amount_rial,'IRR',decode(result->>'evidenceHash','hex'),cfg.environment='test') ON CONFLICT(intent_id) DO NOTHING;
 UPDATE ms_b1_design.product_payment_intent SET state='VERIFIED',updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;
 decision_at:=clock_timestamp();outcome:=ms_b1_design.shop_settlement_outcome(p.id,p.amount_rial,decision_at);
 IF outcome='CONFIRMED' THEN PERFORM ms_b1_design.shop_commit_paid(p.id,decision_at,NULL);
 ELSE INSERT INTO ms_b1_design.product_refund_case(business_id,order_id,intent_id,reason,maximum_rial) VALUES(p.business_id,p.order_id,p.id,CASE WHEN outcome='LATE_PAYMENT' THEN 'LATE_PAYMENT' ELSE 'RECONCILIATION' END,p.amount_rial) ON CONFLICT DO NOTHING;END IF;
 PERFORM ms_b1_design.product_money_event(p,'product.payment.verified',jsonb_build_object('amountRial',p.amount_rial::text,'reference',result->>'reference'));
 PERFORM ms_b1_design.product_delivery_state(jobid,t,'DELIVERED','INDEPENDENTLY_VERIFIED',result->>'reference');
 ELSIF result->>'status'='declined' THEN UPDATE ms_b1_design.product_payment_intent SET state='DECLINED',updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;PERFORM ms_b1_design.product_money_event(p,'product.payment.declined','{}');PERFORM ms_b1_design.product_delivery_state(jobid,t,'DELIVERED','PROVIDER_DECLINED',NULL);
 ELSE
 UPDATE ms_b1_design.product_payment_intent SET state=CASE WHEN j.attempts>=12 OR result->>'status'='unknown' THEN 'UNKNOWN' ELSE 'VERIFYING' END,updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;
 PERFORM ms_b1_design.product_delivery_state(jobid,t,'READY','VERIFICATION_PENDING',NULL);END IF;END IF;
 RETURN ms_b1_design.product_payment_view(p);
END $$;
CREATE FUNCTION ms_b1_design.product_payment_result(jobid uuid,t uuid,result jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE is_order boolean;BEGIN
 SELECT p.order_id IS NOT NULL INTO is_order FROM ms_b1_design.product_delivery j JOIN ms_b1_design.product_payment_intent p ON p.id=(j.payload->>'intentId')::uuid WHERE j.id=jobid;
 IF is_order THEN RETURN ms_b1_design.shop_product_payment_result(jobid,t,result);END IF;
 RETURN ms_b1_design.booking_product_payment_result_v46(jobid,t,result);END $$;
REVOKE ALL ON FUNCTION ms_b1_design.product_payment_result(uuid,uuid,jsonb),ms_b1_design.shop_product_payment_result(uuid,uuid,jsonb) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_payment_result(uuid,uuid,jsonb) TO ms_product_worker;
CREATE OR REPLACE FUNCTION ms_b1_design.product_payment_context(jobid uuid,t uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE j ms_b1_design.product_delivery;p ms_b1_design.product_payment_intent;cfg ms_b1_design.product_runtime;BEGIN
 SELECT * INTO j FROM ms_b1_design.product_delivery WHERE id=jobid AND lease_token=t AND lease_until>clock_timestamp() AND state='LEASED' AND kind IN('PAYMENT_REQUEST','PAYMENT_VERIFY');IF NOT FOUND THEN RETURN NULL;END IF;
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE id=(j.payload->>'intentId')::uuid;
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 IF p.id IS NULL OR p.provider<>cfg.payment_provider OR(p.provider='mock' AND cfg.environment<>'test') THEN PERFORM ms_b1_design.b3_fail('PROVIDER_REALM_MISMATCH','MS403');END IF;
 RETURN jsonb_build_object('id',p.id,'businessId',p.business_id,'bookingId',p.booking_id,'paymentTargetId',coalesce(p.booking_id,p.order_id),'provider',p.provider,'amountRial',p.amount_rial::text,'currency',p.currency,'state',p.state,'authority',p.authority,'callbackCiphertext',p.callback_ciphertext,'expiresAt',ms_b1_design.b3_iso(p.expires_at),'origin',cfg.public_origin);
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.product_money_event(p ms_b1_design.product_payment_intent,kind text,details jsonb) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF EXISTS(SELECT 1 FROM ms_b1_design.product_financial_event e WHERE e.intent_id=p.id AND e.event_type=kind AND e.evidence=details) THEN RETURN;END IF;
 INSERT INTO ms_b1_design.product_financial_event(business_id,intent_id,event_type,evidence) VALUES(p.business_id,p.id,kind,details);
 INSERT INTO ms_b1_design.audit_log(business_id,branch_id,action,target_type,target_id,request_id,redacted_change)
 SELECT p.business_id,coalesce((SELECT b.branch_id FROM ms_b1_design.booking b WHERE b.id=p.booking_id),(SELECT o.branch_id FROM ms_b1_design.shop_order o WHERE o.id=p.order_id)),kind,'payment_intent',p.id,gen_random_uuid(),details;
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at)
 VALUES(p.business_id,'payment.event',gen_random_uuid(),1,kind,1,jsonb_build_object('intentId',p.id,'bookingId',p.booking_id,'orderId',p.order_id,'state',p.state),clock_timestamp());
END $$;

CREATE OR REPLACE FUNCTION ms_b1_design.product_collect() RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE e record;kind text;n integer:=0;cfg ms_b1_design.product_runtime;BEGIN
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 -- Events remain immutable and are consumed independently of the legacy publisher.
 FOR e IN SELECT x.* FROM ms_b1_design.outbox_event x WHERE x.business_id=cfg.business_id AND x.available_at<=clock_timestamp()
 AND x.event_type IN('auth.otp.requested','b4.booking.confirm','b4.booking.payment.confirmed','b4.booking.cancel','b4.booking.reschedule','product.payment.verified','product.payment.declined','manual.receipt.received','manual.receipt.approved','manual.receipt.rejected','b4.booking.expired','shop.created','shop.paid','shop.expired','shop.cancel','shop.fulfill','shop.request-cancellation','shop.decline-cancellation','shop.accept-cancellation')
 AND(x.event_type<>'b4.booking.expired' OR EXISTS(SELECT 1 FROM ms_b1_design.booking_hold h WHERE h.booking_id=x.aggregate_id AND h.business_id=x.business_id))
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_delivery d WHERE d.business_id=x.business_id AND d.kind='SMS' AND d.dedupe_key=x.id::text)
 ORDER BY x.available_at,x.id LIMIT 100 LOOP
 kind:=CASE e.event_type WHEN 'auth.otp.requested' THEN 'OTP' WHEN 'b4.booking.confirm' THEN 'CONFIRM' WHEN 'b4.booking.payment.confirmed' THEN 'CONFIRM' WHEN 'b4.booking.cancel' THEN 'CANCEL' WHEN 'b4.booking.reschedule' THEN 'RESCHEDULE' WHEN 'manual.receipt.received' THEN CASE WHEN e.payload->>'state'='REVIEW_REQUIRED' THEN 'REVIEW_REQUIRED' ELSE 'RECEIPT_RECEIVED' END WHEN 'manual.receipt.approved' THEN CASE WHEN e.payload->>'outcome'='CONFIRMED' THEN 'RECEIPT_APPROVED' ELSE 'REVIEW_REQUIRED' END WHEN 'manual.receipt.rejected' THEN 'RECEIPT_REJECTED' WHEN 'b4.booking.expired' THEN 'HOLD_EXPIRED' ELSE 'PAYMENT' END;
 IF e.aggregate_type='shop_order' OR e.payload->>'orderId' IS NOT NULL THEN kind:=CASE e.event_type WHEN 'shop.created' THEN 'SHOP_ORDER_CREATED' WHEN 'shop.paid' THEN 'SHOP_ORDER_PAID' WHEN 'shop.expired' THEN 'SHOP_ORDER_EXPIRED' WHEN 'shop.cancel' THEN 'SHOP_ORDER_CANCELLED' WHEN 'shop.fulfill' THEN 'SHOP_ORDER_UPDATED' WHEN 'shop.request-cancellation' THEN 'SHOP_ORDER_UPDATED' WHEN 'shop.decline-cancellation' THEN 'SHOP_ORDER_UPDATED' WHEN 'shop.accept-cancellation' THEN 'SHOP_ORDER_UPDATED' ELSE 'SHOP_'||kind END;END IF;
 PERFORM ms_b1_design.product_enqueue(e.business_id,'SMS',e.id::text,jsonb_build_object('eventId',e.id,'kind',kind));n:=n+1;
 END LOOP;
 -- Reminder timing is explicitly configured per branch. NULL means disabled.
 FOR e IN SELECT b.business_id,b.id,b.active_revision_id,min(s.starts_at) starts_at,c.reminder_minutes
 FROM ms_b1_design.booking b JOIN ms_b1_design.product_operational_settings c ON c.business_id=b.business_id AND c.branch_id=b.branch_id
 JOIN ms_b1_design.booking_service_segment s ON s.business_id=b.business_id AND s.revision_id=b.active_revision_id
 WHERE b.business_id=cfg.business_id AND b.status='CONFIRMED' AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_booking_operation o WHERE o.booking_id=b.id) AND c.reminder_minutes IS NOT NULL
 GROUP BY b.business_id,b.id,b.active_revision_id,c.reminder_minutes HAVING min(s.starts_at)>clock_timestamp() AND min(s.starts_at)-make_interval(mins=>c.reminder_minutes)<=clock_timestamp() LOOP
 PERFORM ms_b1_design.product_enqueue(e.business_id,'SMS','reminder:'||e.active_revision_id::text,jsonb_build_object('kind','REMINDER','bookingId',e.id,'revisionId',e.active_revision_id));END LOOP;
 RETURN n;
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.product_admin_command(h bytea,csrf bytea,op text,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;b ms_b1_design.booking;previous ms_b1_design.product_booking_operation;r ms_b1_design.product_refund_case;p ms_b1_design.product_payment_intent;branchid uuid;grace integer;start_at timestamptz;version bigint;target uuid;result jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);
 IF op='operation' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['bookingId','version','state']);SELECT * INTO b FROM ms_b1_design.booking WHERE business_id=bid AND id=(d->>'bookingId')::uuid FOR UPDATE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;branchid:=b.branch_id;target:=b.id;
 IF NOT ms_b1_design.b1b_can(a,'operations.manage',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 SELECT * INTO previous FROM ms_b1_design.product_booking_operation WHERE booking_id=b.id FOR UPDATE;
 IF coalesce(previous.row_version,0)::text IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF b.status<>'CONFIRMED' OR ((previous.booking_id IS NULL AND d->>'state' IN('ARRIVED','NO_SHOW')) OR(previous.state='ARRIVED' AND d->>'state'='IN_SERVICE') OR(previous.state='IN_SERVICE' AND d->>'state'='COMPLETED')) IS NOT TRUE THEN PERFORM ms_b1_design.b3_fail('INVALID_OPERATION_TRANSITION','MS409');END IF;
 IF d->>'state'='NO_SHOW' THEN
 SELECT no_show_grace_minutes INTO grace FROM ms_b1_design.product_operational_settings WHERE business_id=bid AND branch_id=branchid;
 SELECT min(starts_at) INTO start_at FROM ms_b1_design.booking_service_segment WHERE revision_id=b.active_revision_id;
 IF grace IS NULL OR start_at+make_interval(mins=>grace)>clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('NO_SHOW_UNCONFIGURED_OR_EARLY','MS409');END IF;END IF;
 INSERT INTO ms_b1_design.product_booking_operation(booking_id,business_id,state,updated_by) VALUES(b.id,bid,d->>'state',uid) ON CONFLICT(booking_id) DO UPDATE SET state=excluded.state,row_version=product_booking_operation.row_version+1,updated_at=clock_timestamp(),updated_by=uid RETURNING row_version INTO version;
 INSERT INTO ms_b1_design.product_operation_history(business_id,booking_id,from_state,to_state,actor_user_id) VALUES(bid,b.id,coalesce(previous.state,'PLANNED'),d->>'state',uid);
 result:=jsonb_build_object('state',d->>'state','version',version::text);
 ELSIF op='refund.request' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['caseId','amountRial']);SELECT * INTO r FROM ms_b1_design.product_refund_case WHERE business_id=bid AND id=(d->>'caseId')::uuid FOR UPDATE;
 SELECT * INTO b FROM ms_b1_design.booking WHERE id=r.booking_id;branchid:=b.branch_id;target:=r.id;
 IF r.id IS NULL OR NOT ms_b1_design.b1b_can(a,'refund.review',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.product_payment_intent z WHERE z.id=r.intent_id AND z.provider='manual_card_transfer') THEN PERFORM ms_b1_design.b3_fail('MANUAL_REFUND_REVIEW_REQUIRED','MS409');END IF;
 IF r.state<>'REVIEW' OR(d->>'amountRial') !~ '^[1-9]\d{0,18}$' OR(d->>'amountRial')::numeric>r.maximum_rial THEN PERFORM ms_b1_design.b3_fail('INVALID_REFUND_REQUEST','MS409');END IF;
 -- Only one refund case per payment may execute, including late-payment review.
 IF EXISTS(SELECT 1 FROM ms_b1_design.product_refund_case WHERE intent_id=r.intent_id AND id<>r.id AND state IN('REQUESTED','UNKNOWN','VERIFIED')) THEN PERFORM ms_b1_design.b3_fail('REFUND_RECONCILIATION_REQUIRED','MS409');END IF;
 UPDATE ms_b1_design.product_refund_case SET requested_rial=(d->>'amountRial')::bigint,requested_by=uid,state='REQUESTED' WHERE id=r.id;
 PERFORM ms_b1_design.product_enqueue(bid,'REFUND',r.id::text,jsonb_build_object('caseId',r.id));result:=jsonb_build_object('id',r.id,'state','REQUESTED');
 ELSIF op='settings' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['branchId','version','reminderMinutes','noShowGraceMinutes']);branchid:=(d->>'branchId')::uuid;target:=branchid;
 IF NOT ms_b1_design.b1b_can(a,'booking.configure',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 SELECT row_version INTO version FROM ms_b1_design.product_operational_settings WHERE business_id=bid AND branch_id=branchid FOR UPDATE;
 IF coalesce(version,0)::text IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 INSERT INTO ms_b1_design.product_operational_settings(business_id,branch_id,reminder_minutes,no_show_grace_minutes) VALUES(bid,branchid,(d->>'reminderMinutes')::int,(d->>'noShowGraceMinutes')::int) ON CONFLICT(business_id,branch_id) DO UPDATE SET reminder_minutes=excluded.reminder_minutes,no_show_grace_minutes=excluded.no_show_grace_minutes,row_version=product_operational_settings.row_version+1 RETURNING row_version INTO version;
 result:=jsonb_build_object('version',version::text);
 ELSIF op='template' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['kind','version','body','enabled']);IF NOT ms_b1_design.b1b_can(a,'notification.manage',NULL) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF d->>'kind'='OTP' OR jsonb_typeof(d->'enabled')<>'boolean' OR regexp_replace(d->>'body','\{(booking|order|status|date|reason)\}','','g') ~ '[{}]' THEN PERFORM ms_b1_design.b3_fail('INVALID_TEMPLATE');END IF;
 SELECT coalesce(max(x.version),0) INTO version FROM ms_b1_design.product_notification_template x WHERE business_id=bid AND kind=d->>'kind';
 IF version::text IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 INSERT INTO ms_b1_design.product_notification_template(business_id,kind,version,body,enabled,created_by) VALUES(bid,d->>'kind',version+1,d->>'body',(d->>'enabled')::boolean,uid);target:=gen_random_uuid();result:=jsonb_build_object('version',(version+1)::text);
 ELSIF op='delivery.retry' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id']);IF NOT ms_b1_design.b1b_can(a,'notification.manage',NULL) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;target:=(d->>'id')::uuid;
 -- UNKNOWN could have been delivered: no blind resend or fabricated reconciliation.
 UPDATE ms_b1_design.product_delivery SET state='READY',available_at=clock_timestamp(),attempts=0,last_code='ADMIN_RETRY' WHERE business_id=bid AND id=target AND state IN('BLOCKED','DEAD') AND(kind<>'SMS' OR last_code NOT IN('TRANSPORT_AMBIGUOUS','AMBIGUOUS_RESPONSE','LEASE_EXPIRED'));
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('RECONCILIATION_REQUIRED','MS409');END IF;result:=jsonb_build_object('id',target,'state','READY');
 ELSE PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,branch_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES(bid,uid,branchid,'product.'||op,'product_operation',target,gen_random_uuid(),result,uid);RETURN result;
END $$;
ALTER TABLE ms_b1_design.product_notification_template DROP CONSTRAINT product_notification_template_kind_check;
ALTER TABLE ms_b1_design.product_notification_template ADD CONSTRAINT product_notification_template_kind_check CHECK(kind IN('OTP','CONFIRM','PAYMENT','REMINDER','CANCEL','RESCHEDULE','RECEIPT_RECEIVED','RECEIPT_APPROVED','RECEIPT_REJECTED','REVIEW_REQUIRED','HOLD_EXPIRED','SHOP_ORDER_CREATED','SHOP_ORDER_PAID','SHOP_ORDER_EXPIRED','SHOP_ORDER_CANCELLED','SHOP_ORDER_UPDATED','SHOP_PAYMENT','SHOP_RECEIPT_RECEIVED','SHOP_RECEIPT_APPROVED','SHOP_RECEIPT_REJECTED','SHOP_REVIEW_REQUIRED'));
ALTER FUNCTION ms_b1_design.product_sms_context(uuid,uuid) RENAME TO booking_product_sms_context_v46;
REVOKE ALL ON FUNCTION ms_b1_design.booking_product_sms_context_v46(uuid,uuid) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
CREATE FUNCTION ms_b1_design.product_sms_context(id uuid,t uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE j ms_b1_design.product_delivery;e ms_b1_design.outbox_event;o ms_b1_design.shop_order;c ms_b1_design.customer_contact;template ms_b1_design.product_notification_template;k text;snapshot jsonb;BEGIN
 SELECT * INTO j FROM ms_b1_design.product_delivery x WHERE x.id=product_sms_context.id AND x.lease_token=t AND x.lease_until>clock_timestamp() AND x.state='LEASED' AND x.kind='SMS';
 IF NOT FOUND THEN RETURN jsonb_build_object('code','LEASE_LOST');END IF;
 k:=j.payload->>'kind';IF k NOT LIKE 'SHOP_%' THEN RETURN ms_b1_design.booking_product_sms_context_v46(id,t);END IF;
 SELECT * INTO e FROM ms_b1_design.outbox_event x WHERE x.id=(j.payload->>'eventId')::uuid;
 SELECT * INTO o FROM ms_b1_design.shop_order x WHERE x.id=(e.payload->>'orderId')::uuid AND x.business_id=j.business_id;
 IF o.id IS NULL OR(k='SHOP_ORDER_CREATED' AND o.status<>'PENDING_PAYMENT') OR(k='SHOP_ORDER_PAID' AND o.status<>'PAID') OR(k='SHOP_ORDER_EXPIRED' AND o.status<>'EXPIRED') OR(k='SHOP_ORDER_CANCELLED' AND o.status<>'CANCELLED') OR(k='SHOP_ORDER_UPDATED' AND e.aggregate_version<>o.row_version) THEN RETURN jsonb_build_object('code','STALE');END IF;
 SELECT * INTO c FROM ms_b1_design.customer_contact WHERE user_id=o.customer_id AND notifications_opt_in;
 IF NOT FOUND THEN RETURN jsonb_build_object('code','OPTED_OUT');END IF;
 IF j.render_snapshot IS NOT NULL THEN RETURN j.render_snapshot;END IF;
 SELECT * INTO template FROM ms_b1_design.product_notification_template x WHERE x.business_id=j.business_id AND x.kind=k ORDER BY x.version DESC LIMIT 1;
 IF template.business_id IS NULL OR NOT template.enabled THEN RETURN jsonb_build_object('code','TEMPLATE_UNCONFIGURED');END IF;
 snapshot:=jsonb_build_object('kind',k,'mobileCiphertext',c.mobile_ciphertext,'mobileLookup',encode(c.mobile_lookup,'hex'),'templateVersion',template.version,'body',template.body,'variables',jsonb_build_object('order',o.number,'status',o.status,'date',(SELECT to_char(o.created_at AT TIME ZONE b.time_zone,'YYYY-MM-DD HH24:MI') FROM ms_b1_design.branch b WHERE b.id=o.branch_id),'reason',CASE WHEN k='SHOP_RECEIPT_REJECTED' THEN coalesce(e.payload->>'reason','رسید نیاز به اصلاح دارد') WHEN k='SHOP_REVIEW_REQUIRED' THEN 'وجه دریافتی یا مهلت سفارش نیاز به بررسی دارد' ELSE '' END));
 UPDATE ms_b1_design.product_delivery SET render_snapshot=snapshot WHERE product_delivery.id=j.id AND lease_token=t;RETURN snapshot;
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.product_sms_context(uuid,uuid) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_sms_context(uuid,uuid) TO ms_product_worker;
CREATE OR REPLACE FUNCTION ms_b1_design.manual_retention_eligible(receiptid uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT coalesce((SELECT r.retention_eligible_at IS NOT NULL AND r.retention_eligible_at<=clock_timestamp()
 AND EXISTS(SELECT 1 FROM ms_b1_design.product_manual_review v WHERE v.receipt_id=r.id)
 AND((b.id IS NOT NULL AND(b.status IN('CANCELLED','EXPIRED') OR EXISTS(SELECT 1 FROM ms_b1_design.product_booking_operation o WHERE o.booking_id=b.id AND o.state='COMPLETED'))) OR(s.id IS NOT NULL AND(s.status IN('CANCELLED','EXPIRED') OR s.fulfillment_state IN('DELIVERED','COLLECTED'))))
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_refund_case f WHERE f.intent_id=p.id AND f.state<>'VERIFIED')
 FROM ms_b1_design.product_manual_receipt r JOIN ms_b1_design.product_payment_intent p ON p.id=r.intent_id
 LEFT JOIN ms_b1_design.booking b ON b.id=p.booking_id AND b.business_id=p.business_id LEFT JOIN ms_b1_design.shop_order s ON s.id=p.order_id AND s.business_id=p.business_id WHERE r.id=receiptid),false)
$$;
