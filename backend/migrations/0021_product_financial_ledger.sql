-- Product financial evidence. No live merchant or commercial terms are seeded.
SET search_path=ms_b1_design,public;
ALTER TABLE product_runtime ADD COLUMN payment_provider text NOT NULL DEFAULT 'none' CHECK(payment_provider IN('none','mock'));
ALTER TABLE product_runtime ADD COLUMN sms_provider text NOT NULL DEFAULT 'none' CHECK(sms_provider IN('none','mock','kavenegar'));
CREATE TABLE product_payment_intent (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), business_id uuid NOT NULL, booking_id uuid NOT NULL, revision_id uuid NOT NULL,
 provider text NOT NULL CHECK(provider IN('mock')), amount_rial bigint NOT NULL CHECK(amount_rial>0), currency text NOT NULL DEFAULT 'IRR' CHECK(currency='IRR'),
 state text NOT NULL DEFAULT 'REQUESTED' CHECK(state IN('REQUESTED','REDIRECT_READY','VERIFYING','VERIFIED','DECLINED','UNKNOWN','CLOSED')),
 callback_hash bytea NOT NULL CHECK(octet_length(callback_hash)=32), callback_ciphertext text NOT NULL,
 authority text, hosted_url text, expires_at timestamptz NOT NULL, created_by uuid NOT NULL REFERENCES app_user(id),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(), updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,id), UNIQUE(provider,authority), UNIQUE(business_id,revision_id),
 FOREIGN KEY(business_id,revision_id,booking_id) REFERENCES booking_revision(business_id,id,booking_id),
 CHECK((authority IS NULL)=(hosted_url IS NULL)),CHECK(isfinite(expires_at))
);
-- Content integrity remains in the accepted quote; intent UUID is merchant idempotency.
CREATE TABLE product_payment_receipt (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,intent_id uuid NOT NULL UNIQUE,
 provider text NOT NULL,provider_reference text NOT NULL,amount_rial bigint NOT NULL CHECK(amount_rial>0),currency text NOT NULL CHECK(currency='IRR'),
 verified_at timestamptz NOT NULL DEFAULT clock_timestamp(), evidence_hash bytea NOT NULL CHECK(octet_length(evidence_hash)=32),test_only boolean NOT NULL,
 UNIQUE(provider,provider_reference),FOREIGN KEY(business_id,intent_id) REFERENCES product_payment_intent(business_id,id)
);
CREATE TABLE product_refund_case (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,booking_id uuid NOT NULL,intent_id uuid NOT NULL,
 reason text NOT NULL CHECK(reason IN('CANCELLATION','LATE_PAYMENT','RECONCILIATION')),
 maximum_rial bigint NOT NULL CHECK(maximum_rial>=0),requested_rial bigint CHECK(requested_rial>0 AND requested_rial<=maximum_rial),
 state text NOT NULL DEFAULT 'REVIEW' CHECK(state IN('REVIEW','REQUESTED','UNKNOWN','VERIFIED','DECLINED')),
 provider_reference text,requested_by uuid REFERENCES app_user(id),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 verified_at timestamptz,UNIQUE(intent_id,reason),FOREIGN KEY(business_id,intent_id) REFERENCES product_payment_intent(business_id,id),
 FOREIGN KEY(business_id,booking_id) REFERENCES booking(business_id,id),CHECK((state='VERIFIED')=(verified_at IS NOT NULL))
);
CREATE TABLE product_financial_event (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,intent_id uuid NOT NULL,event_type text NOT NULL,
 evidence jsonb NOT NULL DEFAULT '{}',created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(business_id,intent_id) REFERENCES product_payment_intent(business_id,id)
);
CREATE INDEX product_payment_booking ON product_payment_intent(business_id,booking_id,created_at);
CREATE INDEX product_refund_booking ON product_refund_case(business_id,booking_id);
CREATE INDEX product_financial_history ON product_financial_event(business_id,intent_id,created_at,id);
CREATE TRIGGER product_receipt_immutable BEFORE UPDATE OR DELETE ON product_payment_receipt FOR EACH ROW EXECUTE FUNCTION b3_freeze();
CREATE TRIGGER product_financial_event_immutable BEFORE UPDATE OR DELETE ON product_financial_event FOR EACH ROW EXECUTE FUNCTION b3_freeze();
REVOKE ALL ON product_payment_intent,product_payment_receipt,product_refund_case,product_financial_event FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker;
SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.product_money_event(p ms_b1_design.product_payment_intent,kind text,details jsonb) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 INSERT INTO ms_b1_design.product_financial_event(business_id,intent_id,event_type,evidence) VALUES(p.business_id,p.id,kind,details);
 INSERT INTO ms_b1_design.audit_log(business_id,branch_id,action,target_type,target_id,request_id,redacted_change)
 SELECT p.business_id,b.branch_id,kind,'payment_intent',p.id,gen_random_uuid(),details FROM ms_b1_design.booking b WHERE b.id=p.booking_id;
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at)
 VALUES(p.business_id,'payment.event',gen_random_uuid(),1,kind,1,jsonb_build_object('intentId',p.id,'bookingId',p.booking_id,'state',p.state),clock_timestamp());
END $$;
CREATE FUNCTION ms_b1_design.product_payment_view(p ms_b1_design.product_payment_intent) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('id',p.id,'bookingId',p.booking_id,'revisionId',p.revision_id,'state',p.state,'amountRial',p.amount_rial::text,'currency',p.currency,
 'hostedUrl',CASE WHEN p.state='REDIRECT_READY' AND p.expires_at>clock_timestamp() THEN p.hosted_url ELSE NULL END,'expiresAt',ms_b1_design.b3_iso(p.expires_at),
 'reference',(SELECT provider_reference FROM ms_b1_design.product_payment_receipt WHERE intent_id=p.id),
 'refunds',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'state',state,'reason',reason,'maximumRial',maximum_rial::text,'requestedRial',requested_rial::text)) FROM ms_b1_design.product_refund_case WHERE intent_id=p.id),'[]'::jsonb)) $$;
-- A new confirmation edge requires durable independent-verification evidence, not a SET-able flag.
CREATE OR REPLACE FUNCTION ms_b1_design.b4_lifecycle_guard() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF TG_OP='DELETE' THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_BOOKING_EVIDENCE');END IF;
 IF TG_TABLE_NAME='booking' THEN
 IF (to_jsonb(NEW)-ARRAY['status','active_revision_id','draft_expires_at','row_version','plan_committed']) IS DISTINCT FROM(to_jsonb(OLD)-ARRAY['status','active_revision_id','draft_expires_at','row_version','plan_committed']) OR NEW.row_version<>OLD.row_version+1 OR(OLD.plan_committed AND NOT NEW.plan_committed)
 OR NOT((OLD.status='DRAFT' AND NEW.status IN('HELD','CANCELLED','EXPIRED')) OR(OLD.status='HELD' AND NEW.status IN('HELD','CONFIRMED','PENDING_PAYMENT','CANCELLED','EXPIRED')) OR(OLD.status='PENDING_PAYMENT' AND NEW.status IN('PENDING_PAYMENT','CANCELLED','EXPIRED')) OR(OLD.status='CONFIRMED' AND NEW.status IN('CONFIRMED','CANCELLED'))
 OR(OLD.status='PENDING_PAYMENT' AND NEW.status='CONFIRMED' AND NEW.active_revision_id=OLD.active_revision_id AND EXISTS(
 SELECT 1 FROM ms_b1_design.product_payment_intent p JOIN ms_b1_design.product_payment_receipt r ON r.intent_id=p.id
 JOIN ms_b1_design.booking_policy_acceptance a ON a.business_id=p.business_id AND a.revision_id=p.revision_id
 JOIN ms_b1_design.pricing_quote q ON q.business_id=a.business_id AND q.id=a.quote_id AND q.content_hash=a.quote_hash
 WHERE p.business_id=NEW.business_id AND p.booking_id=NEW.id AND p.revision_id=NEW.active_revision_id AND p.state='VERIFIED' AND r.amount_rial=p.amount_rial
 AND p.amount_rial=(q.content_document->>'depositRial')::bigint AND r.currency='IRR'
 AND(NOT r.test_only OR EXISTS(SELECT 1 FROM ms_b1_design.product_runtime WHERE singleton AND environment='test'))))) THEN PERFORM ms_b1_design.b3_fail('INVALID_BOOKING_STATE','MS409');END IF;
 ELSE
 IF (to_jsonb(NEW)-ARRAY['released_at','busy_period']) IS DISTINCT FROM(to_jsonb(OLD)-ARRAY['released_at','busy_period']) OR OLD.released_at IS NOT NULL OR NEW.released_at IS NULL THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_BOOKING_EVIDENCE');END IF;
 END IF;RETURN NEW;
END $$;
-- Exact paid amount and frozen B3 refund terms. The published B3 rounding contract is preserved.
CREATE OR REPLACE FUNCTION ms_b1_design.b4_cancellation(b ms_b1_design.booking,at_time timestamptz) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 DECLARE q ms_b1_design.pricing_quote;t jsonb;deadline timestamptz;allowed boolean;paid numeric:=0;base numeric:=0;rate integer:=0;refund numeric:=0;mins numeric;BEGIN
 IF b.plan_committed THEN SELECT x.* INTO q FROM ms_b1_design.pricing_quote x JOIN ms_b1_design.booking_revision v ON v.business_id=x.business_id AND v.quote_id=x.id WHERE v.business_id=b.business_id AND v.id=b.active_revision_id;
 t:=q.terms_document->'terms';deadline:=ms_b1_design.b3_instant(q.content_document->>'startsAt')-make_interval(mins=>(t->>'cancellationDeadlineMinutes')::integer);
 SELECT coalesce(sum(r.amount_rial),0) INTO paid FROM ms_b1_design.product_payment_receipt r JOIN ms_b1_design.product_payment_intent p ON p.id=r.intent_id WHERE p.business_id=b.business_id AND p.booking_id=b.id;
 base:=CASE WHEN t->>'refundBase'='DEPOSIT_PAID' THEN least(paid,(q.content_document->>'depositRial')::numeric) ELSE paid END;
 rate:=(t->>'outsideRefundBps')::int;mins:=floor(extract(epoch FROM ms_b1_design.b3_instant(q.content_document->>'startsAt')-at_time)/60);
 IF mins>=0 THEN SELECT(value->>'refundBps')::int INTO rate FROM jsonb_array_elements(t->'refundWindows') WHERE(value->>'thresholdMinutes')::int<=mins ORDER BY(value->>'thresholdMinutes')::int DESC LIMIT 1;rate:=coalesce(rate,(t->>'outsideRefundBps')::int);END IF;
 refund:=least(base,floor((base*rate+50000)/100000)*10);END IF;
 allowed:=b.status IN('DRAFT','HELD','PENDING_PAYMENT','CONFIRMED') AND(deadline IS NULL OR at_time<=deadline);
 RETURN jsonb_build_object('bookingId',b.id,'version',b.row_version::text,'evaluatedAt',ms_b1_design.b3_iso(at_time),'cancellationAllowed',allowed,'deadline',ms_b1_design.b3_iso(deadline),'paidRial',paid::text,'refundPreviewRial',refund::text,'moneyExecuted',false,'terms',q.terms_document);
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.product_money_event(ms_b1_design.product_payment_intent,text,jsonb),ms_b1_design.product_payment_view(ms_b1_design.product_payment_intent) FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker;
