-- SQL three-valued logic must fail closed for absent prior operational state.
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
 IF d->>'kind'='OTP' OR jsonb_typeof(d->'enabled')<>'boolean' OR regexp_replace(d->>'body','\{(booking|status|date)\}','','g') ~ '[{}]' THEN PERFORM ms_b1_design.b3_fail('INVALID_TEMPLATE');END IF;
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
CREATE OR REPLACE FUNCTION ms_b1_design.product_payment_start(h bytea,csrf bytea,bookingid uuid,version text,callbackhash bytea,callbackcipher text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;b ms_b1_design.booking;p ms_b1_design.product_payment_intent;q ms_b1_design.pricing_quote;hold ms_b1_design.booking_hold;cfg ms_b1_design.product_runtime;BEGIN
 a:=ms_b1_design.b4_actor(h,csrf);SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;PERFORM ms_b1_design.b4_lock(cfg.business_id);
 SELECT * INTO b FROM ms_b1_design.booking WHERE id=bookingid AND business_id=(a->>'businessId')::uuid AND created_by=(a->>'userId')::uuid FOR UPDATE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=b.business_id AND revision_id=b.active_revision_id FOR UPDATE;
 IF FOUND THEN RETURN ms_b1_design.product_payment_view(p);END IF;
 IF b.row_version::text IS DISTINCT FROM version THEN PERFORM ms_b1_design.b3_fail('STALE_BOOKING','MS412');END IF;
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
CREATE OR REPLACE FUNCTION ms_b1_design.product_payment_callback(intentid uuid,callbackhash bytea,p_authority text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE p ms_b1_design.product_payment_intent;BEGIN
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE id=intentid;
 IF NOT FOUND OR p.callback_hash IS DISTINCT FROM callbackhash OR p.authority IS DISTINCT FROM p_authority THEN RETURN false;END IF;
 IF p.state='VERIFIED' THEN RETURN true;END IF;
 PERFORM ms_b1_design.product_enqueue(p.business_id,'PAYMENT_VERIFY',p.id::text,jsonb_build_object('intentId',p.id));
 UPDATE ms_b1_design.product_delivery SET state='READY',available_at=clock_timestamp(),last_code='CALLBACK_RECEIVED' WHERE kind='PAYMENT_VERIFY' AND dedupe_key=p.id::text AND business_id=p.business_id AND state NOT IN('LEASED','DISPATCHED');RETURN true;
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.product_payment_result(jobid uuid,t uuid,result jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
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
CREATE OR REPLACE FUNCTION ms_b1_design.product_claim(replay_safe_sms boolean) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE j ms_b1_design.product_delivery;t uuid:=gen_random_uuid();BEGIN
 -- A crash before dispatch is retryable. An ambiguous non-idempotent SMS must be reconciled.
 UPDATE ms_b1_design.product_delivery SET state=CASE WHEN state='DISPATCHED' AND kind='SMS' AND NOT replay_safe_sms THEN 'UNKNOWN' WHEN attempts>=12 THEN 'DEAD' ELSE 'READY' END,lease_token=NULL,lease_until=NULL,last_code='LEASE_EXPIRED',updated_at=clock_timestamp()
 WHERE state IN('LEASED','DISPATCHED') AND lease_until<clock_timestamp();
 SELECT * INTO j FROM ms_b1_design.product_delivery WHERE state='READY' AND attempts<12 AND available_at<=clock_timestamp() ORDER BY available_at,id LIMIT 1 FOR UPDATE SKIP LOCKED;
 IF NOT FOUND THEN RETURN NULL;END IF;
 UPDATE ms_b1_design.product_delivery SET state='LEASED',attempts=attempts+1,lease_token=t,lease_until=clock_timestamp()+interval '90 seconds',updated_at=clock_timestamp() WHERE id=j.id RETURNING * INTO j;
 RETURN jsonb_build_object('id',j.id,'token',t,'kind',j.kind,'payload',j.payload,'attempt',j.attempts,'businessId',j.business_id);
END $$;

