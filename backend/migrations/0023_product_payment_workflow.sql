SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.product_payment_start(h bytea,csrf bytea,bookingid uuid,version text,callbackhash bytea,callbackcipher text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;b ms_b1_design.booking;p ms_b1_design.product_payment_intent;q ms_b1_design.pricing_quote;hold ms_b1_design.booking_hold;cfg ms_b1_design.product_runtime;BEGIN
 a:=ms_b1_design.b4_actor(h,csrf);SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;PERFORM ms_b1_design.b4_lock(cfg.business_id);
 SELECT * INTO b FROM ms_b1_design.booking WHERE id=bookingid AND business_id=(a->>'businessId')::uuid AND created_by=(a->>'userId')::uuid FOR UPDATE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=b.business_id AND revision_id=b.active_revision_id FOR UPDATE;
 IF FOUND THEN RETURN ms_b1_design.product_payment_view(p);END IF;
 IF b.row_version::text<>version THEN PERFORM ms_b1_design.b3_fail('STALE_BOOKING','MS412');END IF;
 IF cfg.payment_provider='none' THEN PERFORM ms_b1_design.b3_fail('PAYMENT_UNCONFIGURED','MS409');END IF;
 IF b.status<>'PENDING_PAYMENT' THEN PERFORM ms_b1_design.b3_fail('INVALID_BOOKING_STATE','MS409');END IF;
 SELECT * INTO STRICT hold FROM ms_b1_design.booking_hold WHERE revision_id=b.active_revision_id;
 IF hold.released_at IS NOT NULL OR hold.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('HOLD_EXPIRED','MS409');END IF;
 SELECT x.* INTO STRICT q FROM ms_b1_design.pricing_quote x JOIN ms_b1_design.booking_policy_acceptance c ON c.business_id=x.business_id AND c.quote_id=x.id AND c.quote_hash=x.content_hash WHERE c.revision_id=b.active_revision_id;
 IF (q.content_document->>'depositRial')::bigint<=0 OR octet_length(callbackhash)<>32 OR length(callbackcipher) NOT BETWEEN 50 AND 500 THEN PERFORM ms_b1_design.b3_fail('INVALID_PAYMENT');END IF;
 INSERT INTO ms_b1_design.product_payment_intent(business_id,booking_id,revision_id,provider,amount_rial,callback_hash,callback_ciphertext,expires_at,created_by)
 VALUES(b.business_id,b.id,b.active_revision_id,cfg.payment_provider,(q.content_document->>'depositRial')::bigint,callbackhash,callbackcipher,hold.expires_at,b.created_by) RETURNING * INTO p;
 PERFORM ms_b1_design.product_enqueue(b.business_id,'PAYMENT_REQUEST',p.id::text,jsonb_build_object('intentId',p.id));
 PERFORM ms_b1_design.product_money_event(p,'product.payment.requested',jsonb_build_object('amountRial',p.amount_rial::text,'currency','IRR'));
 RETURN ms_b1_design.product_payment_view(p);
END $$;
CREATE FUNCTION ms_b1_design.product_payment_read(h bytea,bookingid uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;b ms_b1_design.booking;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);SELECT * INTO b FROM ms_b1_design.booking WHERE id=bookingid AND business_id=(a->>'businessId')::uuid;
 IF NOT FOUND OR(b.created_by<>(a->>'userId')::uuid AND NOT ms_b1_design.b1b_can(a,'payment.read',b.branch_id)) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 RETURN jsonb_build_object('bookingId',b.id,'bookingStatus',b.status,'items',coalesce((SELECT jsonb_agg(ms_b1_design.product_payment_view(p) ORDER BY p.created_at DESC) FROM ms_b1_design.product_payment_intent p WHERE p.business_id=b.business_id AND p.booking_id=b.id),'[]'::jsonb),
 'events',coalesce((SELECT jsonb_agg(jsonb_build_object('event',e.event_type,'at',ms_b1_design.b3_iso(e.created_at),'evidence',e.evidence) ORDER BY e.created_at,e.id) FROM ms_b1_design.product_financial_event e JOIN ms_b1_design.product_payment_intent p ON p.id=e.intent_id WHERE p.booking_id=b.id),'[]'::jsonb));
END $$;
-- Public callback can only wake verification for an ALREADY server-bound authority.
CREATE FUNCTION ms_b1_design.product_payment_callback(intentid uuid,callbackhash bytea,p_authority text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE p ms_b1_design.product_payment_intent;BEGIN
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE id=intentid;
 IF NOT FOUND OR p.callback_hash<>callbackhash OR p.authority IS DISTINCT FROM p_authority THEN RETURN false;END IF;
 IF p.state='VERIFIED' THEN RETURN true;END IF;
 PERFORM ms_b1_design.product_enqueue(p.business_id,'PAYMENT_VERIFY',p.id::text,jsonb_build_object('intentId',p.id));
 UPDATE ms_b1_design.product_delivery SET state='READY',available_at=clock_timestamp(),last_code='CALLBACK_RECEIVED' WHERE kind='PAYMENT_VERIFY' AND dedupe_key=p.id::text AND business_id=p.business_id AND state NOT IN('LEASED','DISPATCHED');RETURN true;
END $$;
CREATE FUNCTION ms_b1_design.product_payment_context(jobid uuid,t uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE j ms_b1_design.product_delivery;p ms_b1_design.product_payment_intent;cfg ms_b1_design.product_runtime;BEGIN
 SELECT * INTO j FROM ms_b1_design.product_delivery WHERE id=jobid AND lease_token=t AND lease_until>clock_timestamp() AND state='LEASED' AND kind IN('PAYMENT_REQUEST','PAYMENT_VERIFY');IF NOT FOUND THEN RETURN NULL;END IF;
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE id=(j.payload->>'intentId')::uuid;
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 IF p.id IS NULL OR p.provider<>cfg.payment_provider OR(p.provider='mock' AND cfg.environment<>'test') THEN PERFORM ms_b1_design.b3_fail('PROVIDER_REALM_MISMATCH','MS403');END IF;
 RETURN jsonb_build_object('id',p.id,'businessId',p.business_id,'bookingId',p.booking_id,'provider',p.provider,'amountRial',p.amount_rial::text,'currency',p.currency,'state',p.state,'authority',p.authority,'callbackCiphertext',p.callback_ciphertext,'expiresAt',ms_b1_design.b3_iso(p.expires_at),'origin',cfg.public_origin);
END $$;
CREATE FUNCTION ms_b1_design.product_payment_result(jobid uuid,t uuid,result jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE j ms_b1_design.product_delivery;p ms_b1_design.product_payment_intent;b ms_b1_design.booking;cfg ms_b1_design.product_runtime;hold ms_b1_design.booking_hold;old_status text;existing ms_b1_design.product_payment_receipt;BEGIN
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
 IF result->>'authority' !~ '^[A-Za-z0-9_-]{8,160}$' OR length(result->>'hostedUrl')>500 OR result->>'hostedUrl' NOT LIKE 'http://127.0.0.1:%' THEN PERFORM ms_b1_design.b3_fail('INVALID_PROVIDER_RESPONSE');END IF;
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
 SELECT * INTO b FROM ms_b1_design.booking WHERE id=p.booking_id FOR UPDATE;SELECT * INTO hold FROM ms_b1_design.booking_hold WHERE revision_id=p.revision_id;
 IF b.status='PENDING_PAYMENT' AND b.active_revision_id=p.revision_id AND hold.released_at IS NULL AND hold.expires_at>clock_timestamp() THEN
 UPDATE ms_b1_design.booking SET status='CONFIRMED',row_version=row_version+1 WHERE id=b.id RETURNING * INTO b;
 UPDATE ms_b1_design.booking_hold SET released_at=clock_timestamp() WHERE id=hold.id;PERFORM ms_b1_design.b4_event(b,NULL,'PENDING_PAYMENT','b4.booking.payment.confirmed');
 ELSE
 IF b.status IN('HELD','PENDING_PAYMENT') AND b.active_revision_id=p.revision_id THEN
 old_status:=b.status;UPDATE ms_b1_design.resource_allocation SET released_at=clock_timestamp() WHERE revision_id=p.revision_id AND released_at IS NULL;
 UPDATE ms_b1_design.booking_hold SET released_at=clock_timestamp() WHERE revision_id=p.revision_id AND released_at IS NULL;
 UPDATE ms_b1_design.booking SET status='EXPIRED',row_version=row_version+1 WHERE id=b.id RETURNING * INTO b;PERFORM ms_b1_design.b4_event(b,NULL,old_status,'b4.booking.expired');END IF;
 INSERT INTO ms_b1_design.product_refund_case(business_id,booking_id,intent_id,reason,maximum_rial) VALUES(p.business_id,p.booking_id,p.id,'LATE_PAYMENT',p.amount_rial) ON CONFLICT DO NOTHING;END IF;
 PERFORM ms_b1_design.product_money_event(p,'product.payment.verified',jsonb_build_object('amountRial',p.amount_rial::text,'reference',result->>'reference'));
 PERFORM ms_b1_design.product_delivery_state(jobid,t,'DELIVERED','INDEPENDENTLY_VERIFIED',result->>'reference');
 ELSIF result->>'status'='declined' THEN UPDATE ms_b1_design.product_payment_intent SET state='DECLINED',updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;PERFORM ms_b1_design.product_money_event(p,'product.payment.declined','{}');PERFORM ms_b1_design.product_delivery_state(jobid,t,'DELIVERED','PROVIDER_DECLINED',NULL);
 ELSE
 UPDATE ms_b1_design.product_payment_intent SET state=CASE WHEN j.attempts>=12 OR result->>'status'='unknown' THEN 'UNKNOWN' ELSE 'VERIFYING' END,updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;
 PERFORM ms_b1_design.product_delivery_state(jobid,t,'READY','VERIFICATION_PENDING',NULL);END IF;END IF;
 RETURN ms_b1_design.product_payment_view(p);
END $$;
CREATE FUNCTION ms_b1_design.product_cancel_refund() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE preview jsonb;p record;remaining bigint;BEGIN
 IF NEW.status='CANCELLED' AND OLD.status<>'CANCELLED' THEN
 preview:=ms_b1_design.b4_cancellation(OLD,clock_timestamp());remaining:=(preview->>'refundPreviewRial')::bigint;
 FOR p IN SELECT x.id,r.amount_rial FROM ms_b1_design.product_payment_intent x JOIN ms_b1_design.product_payment_receipt r ON r.intent_id=x.id WHERE x.booking_id=NEW.id ORDER BY x.created_at,x.id LOOP
 INSERT INTO ms_b1_design.product_refund_case(business_id,booking_id,intent_id,reason,maximum_rial) VALUES(NEW.business_id,NEW.id,p.id,'CANCELLATION',least(remaining,p.amount_rial)) ON CONFLICT DO NOTHING;remaining:=greatest(remaining-p.amount_rial,0);END LOOP;END IF;RETURN NEW;
END $$;
CREATE TRIGGER product_cancel_refund AFTER UPDATE OF status ON ms_b1_design.booking FOR EACH ROW EXECUTE FUNCTION ms_b1_design.product_cancel_refund();
CREATE FUNCTION ms_b1_design.product_tick() RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE bid uuid;BEGIN SELECT business_id INTO STRICT bid FROM ms_b1_design.product_runtime WHERE singleton;RETURN ms_b1_design.b4_expire_business(bid);END $$;
REVOKE ALL ON FUNCTION ms_b1_design.product_payment_start(bytea,bytea,uuid,text,bytea,text),ms_b1_design.product_payment_read(bytea,uuid),ms_b1_design.product_payment_callback(uuid,bytea,text),ms_b1_design.product_payment_context(uuid,uuid),ms_b1_design.product_payment_result(uuid,uuid,jsonb),ms_b1_design.product_cancel_refund(),ms_b1_design.product_tick() FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_payment_start(bytea,bytea,uuid,text,bytea,text),ms_b1_design.product_payment_read(bytea,uuid),ms_b1_design.product_payment_callback(uuid,bytea,text) TO ms_b1b_api;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_payment_context(uuid,uuid),ms_b1_design.product_payment_result(uuid,uuid,jsonb),ms_b1_design.product_tick() TO ms_product_worker;
