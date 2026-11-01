-- Forward integration of manual settlement. Applied files 0001–0043 are unchanged.
SET search_path=pg_catalog;
ALTER TABLE ms_b1_design.product_payment_configuration ADD COLUMN inherit_business boolean NOT NULL DEFAULT false CHECK(NOT inherit_business OR branch_id IS NOT NULL);
CREATE OR REPLACE FUNCTION ms_b1_design.manual_configuration(bid uuid,branchid uuid) RETURNS ms_b1_design.product_payment_configuration
 LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT c FROM ms_b1_design.product_payment_configuration c WHERE c.business_id=bid AND NOT c.inherit_business AND(c.branch_id=branchid OR c.branch_id IS NULL)
 ORDER BY c.branch_id IS NULL LIMIT 1
$$;
CREATE OR REPLACE FUNCTION ms_b1_design.manual_settings_read(h bytea,branchid uuid) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;c ms_b1_design.product_payment_configuration;effective ms_b1_design.product_payment_configuration;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);bid:=(a->>'businessId')::uuid;
 IF NOT ms_b1_design.b1b_can(a,'payment.settings.read',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF branchid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND b.id=branchid AND b.archived_at IS NULL) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 SELECT * INTO c FROM ms_b1_design.product_payment_configuration x WHERE x.business_id=bid AND x.branch_id IS NOT DISTINCT FROM branchid;
 effective:=ms_b1_design.manual_configuration(bid,branchid);
 RETURN jsonb_build_object('branchId',branchid,'version',coalesce(c.row_version,0)::text,'inherited',branchid IS NOT NULL AND(c.id IS NULL OR c.inherit_business),
 'onlineEnabled',coalesce(effective.online_enabled,false),'manualEnabled',coalesce(effective.manual_enabled,false),
 'defaultCardId',effective.default_card_id,'retentionDays',effective.receipt_retention_days,'maxSubmissions',coalesce(effective.max_receipt_submissions,3),
 'gatewayConfigured',EXISTS(SELECT 1 FROM ms_b1_design.product_runtime r WHERE r.singleton AND r.payment_provider<>'none'),
 'cards',coalesce((SELECT jsonb_agg(ms_b1_design.manual_card_document(x) ORDER BY x.priority,x.created_at,x.id)
 FROM ms_b1_design.product_bank_card x WHERE x.business_id=bid AND(branchid IS NULL OR x.scope_kind='BUSINESS' OR EXISTS(
 SELECT 1 FROM ms_b1_design.product_bank_card_branch s WHERE s.card_id=x.id AND s.business_id=bid AND s.branch_id=branchid))),'[]'::jsonb));
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.manual_settings_save(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;branchid uuid;c ms_b1_design.product_payment_configuration;card ms_b1_design.product_bank_card;result jsonb;BEGIN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['branchId','version','onlineEnabled','manualEnabled','defaultCardId','retentionDays','maxSubmissions','inherit']);
 branchid:=(d->>'branchId')::uuid;a:=ms_b1_design.manual_financial_actor(h,csrf,branchid,'payment.settings.manage');bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);
 result:=ms_b1_design.manual_replay(bid,uid,'settings.save',k,sig);IF result IS NOT NULL THEN RETURN result;END IF;
 IF branchid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.id=branchid AND b.business_id=bid AND b.archived_at IS NULL) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF jsonb_typeof(d->'onlineEnabled') IS DISTINCT FROM 'boolean' OR jsonb_typeof(d->'manualEnabled') IS DISTINCT FROM 'boolean' OR jsonb_typeof(d->'inherit') IS DISTINCT FROM 'boolean'
 OR(d->>'maxSubmissions') !~ '^\d{1,2}$' OR(d->>'maxSubmissions')::int NOT BETWEEN 1 AND 10 OR(d->>'version') !~ '^\d{1,19}$'
 OR(d->>'retentionDays' IS NOT NULL AND((d->>'retentionDays') !~ '^\d{1,5}$' OR(d->>'retentionDays')::int NOT BETWEEN 1 AND 36500)) THEN PERFORM ms_b1_design.b3_fail('INVALID_CONFIGURATION');END IF;
 SELECT * INTO c FROM ms_b1_design.product_payment_configuration x WHERE x.business_id=bid AND x.branch_id IS NOT DISTINCT FROM branchid FOR UPDATE;
 IF coalesce(c.row_version,0)::text IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF(d->>'inherit')::boolean THEN
 IF branchid IS NULL THEN PERFORM ms_b1_design.b3_fail('INVALID_CONFIGURATION');END IF;
 INSERT INTO ms_b1_design.product_payment_configuration(business_id,branch_id,inherit_business,updated_by)
 VALUES(bid,branchid,true,uid) ON CONFLICT(business_id,branch_id) DO UPDATE SET inherit_business=true,updated_by=uid,updated_at=clock_timestamp(),row_version=product_payment_configuration.row_version+1 RETURNING * INTO c;
 result:=jsonb_build_object('branchId',branchid,'version',c.row_version::text,'inherited',true);
 ELSE
 IF(d->>'onlineEnabled')::boolean AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_runtime r WHERE r.singleton AND r.payment_provider<>'none') THEN PERFORM ms_b1_design.b3_fail('PAYMENT_UNCONFIGURED','MS409');END IF;
 IF d->>'defaultCardId' IS NOT NULL THEN
 SELECT * INTO card FROM ms_b1_design.product_bank_card WHERE business_id=bid AND id=(d->>'defaultCardId')::uuid;
 IF card.id IS NULL OR NOT card.active OR card.archived_at IS NOT NULL OR(branchid IS NULL AND card.scope_kind<>'BUSINESS') OR(branchid IS NOT NULL AND NOT ms_b1_design.manual_card_eligible(card,branchid)) THEN PERFORM ms_b1_design.b3_fail('CARD_UNAVAILABLE','MS409');END IF;END IF;
 INSERT INTO ms_b1_design.product_payment_configuration(business_id,branch_id,online_enabled,manual_enabled,default_card_id,receipt_retention_days,max_receipt_submissions,updated_by,inherit_business)
 VALUES(bid,branchid,(d->>'onlineEnabled')::boolean,(d->>'manualEnabled')::boolean,(d->>'defaultCardId')::uuid,(d->>'retentionDays')::int,(d->>'maxSubmissions')::int,uid,false)
 ON CONFLICT(business_id,branch_id) DO UPDATE SET inherit_business=false,online_enabled=excluded.online_enabled,manual_enabled=excluded.manual_enabled,default_card_id=excluded.default_card_id,
 receipt_retention_days=excluded.receipt_retention_days,max_receipt_submissions=excluded.max_receipt_submissions,updated_by=uid,updated_at=clock_timestamp(),row_version=product_payment_configuration.row_version+1 RETURNING * INTO c;
 result:=jsonb_build_object('branchId',branchid,'version',c.row_version::text,'onlineEnabled',c.online_enabled,'manualEnabled',c.manual_enabled);
 END IF;
 PERFORM ms_b1_design.manual_event(bid,branchid,uid,'manual.settings.changed',coalesce(branchid,bid),result);
 RETURN ms_b1_design.manual_remember(bid,uid,'settings.save',k,sig,result);
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.manual_review_decide(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;p ms_b1_design.product_payment_intent;b ms_b1_design.booking;m ms_b1_design.product_manual_transfer;r ms_b1_design.product_manual_receipt;v ms_b1_design.product_manual_review;x ms_b1_design.product_manual_reconciliation;hold ms_b1_design.booking_hold;cfg ms_b1_design.product_runtime;result jsonb;outcome text;old_status text;actual bigint;decision_at timestamptz;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);
 PERFORM ms_b1_design.b3_keys(d,ARRAY['intentId','receiptId','version','decision','reason','amountRial','receivedAt','bankReferenceHash','evidenceCiphertext','attested']);
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=bid AND id=(d->>'intentId')::uuid AND provider='manual_card_transfer' FOR UPDATE;
 SELECT * INTO b FROM ms_b1_design.booking WHERE business_id=bid AND id=p.booking_id FOR UPDATE;
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
 PERFORM ms_b1_design.manual_event(bid,b.branch_id,uid,'manual.receipt.rejected',r.id,jsonb_build_object('bookingId',b.id,'intentId',p.id,'receiptId',r.id,'reason',CASE WHEN trim(d->>'reason') IN('تصویر رسید خوانا نیست','مبلغ با بیعانه مطابقت ندارد','واریز در گردش حساب یافت نشد','رسید به حساب مقصد مربوط نیست') THEN trim(d->>'reason') ELSE 'رسید نیاز به اصلاح و ارسال مجدد دارد' END));
 ELSE
 IF(d->'attested') IS DISTINCT FROM 'true'::jsonb OR(d->>'amountRial') !~ '^[1-9]\d{0,18}$' OR(d->>'amountRial')::numeric>9223372036854775807 OR(d->>'bankReferenceHash') !~ '^[a-f0-9]{64}$' OR length(d->>'evidenceCiphertext') NOT BETWEEN 50 AND 8000 OR d->>'receivedAt' IS NULL THEN PERFORM ms_b1_design.b3_fail('BANK_RECONCILIATION_REQUIRED');END IF;
 actual:=(d->>'amountRial')::bigint;
 IF NOT isfinite(ms_b1_design.b3_instant(d->>'receivedAt')) OR ms_b1_design.b3_instant(d->>'receivedAt')>clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('INVALID_BANK_TIME');END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.product_manual_reconciliation WHERE business_id=bid AND card_fingerprint=m.card_fingerprint AND bank_reference_hash=decode(d->>'bankReferenceHash','hex')) THEN PERFORM ms_b1_design.b3_fail('BANK_TRANSACTION_ALREADY_USED','MS409');END IF;
 -- Expiration is authoritative at review time, never the client-attested arrival time.
 PERFORM ms_b1_design.b4_expire_business(bid);SELECT * INTO STRICT b FROM ms_b1_design.booking WHERE id=b.id FOR UPDATE;
 SELECT * INTO hold FROM ms_b1_design.booking_hold WHERE business_id=bid AND revision_id=p.revision_id FOR UPDATE;
 decision_at:=clock_timestamp();
 outcome:=CASE WHEN actual<>p.amount_rial THEN 'AMOUNT_MISMATCH'
 WHEN p.expires_at<=decision_at OR hold.id IS NULL OR hold.expires_at<=decision_at OR hold.released_at IS NOT NULL THEN 'LATE_PAYMENT'
 WHEN b.status<>'PENDING_PAYMENT' OR b.active_revision_id<>p.revision_id THEN 'BOOKING_CLOSED'
 WHEN NOT EXISTS(SELECT 1 FROM ms_b1_design.resource_allocation z WHERE z.revision_id=p.revision_id AND z.released_at IS NULL) OR EXISTS(SELECT 1 FROM ms_b1_design.resource_allocation z WHERE z.revision_id=p.revision_id AND z.released_at IS NOT NULL) THEN 'ALLOCATION_REVIEW'
 ELSE 'CONFIRMED' END;
 INSERT INTO ms_b1_design.product_manual_review(business_id,intent_id,receipt_id,decision,reason,reviewed_by,reviewed_at) VALUES(bid,p.id,r.id,'BANK_RECONCILED',trim(d->>'reason'),uid,decision_at) RETURNING * INTO v;
 INSERT INTO ms_b1_design.product_manual_reconciliation(business_id,intent_id,review_id,card_fingerprint,bank_reference_hash,evidence_ciphertext,received_amount_rial,received_at,bank_statement_attested,outcome,reviewed_by,review_session_id,reviewed_at)
 VALUES(bid,p.id,v.id,m.card_fingerprint,decode(d->>'bankReferenceHash','hex'),d->>'evidenceCiphertext',actual,ms_b1_design.b3_instant(d->>'receivedAt'),true,outcome,uid,(a->>'sessionId')::uuid,decision_at) RETURNING * INTO x;
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 INSERT INTO ms_b1_design.product_payment_receipt(business_id,intent_id,provider,provider_reference,amount_rial,currency,evidence_hash,test_only,evidence_type,manual_reconciliation_id)
 VALUES(bid,p.id,'manual_card_transfer','manual_'||encode(x.bank_reference_hash,'hex'),actual,'IRR',sha256(convert_to(x.evidence_ciphertext,'UTF8')),cfg.environment='test','MANUAL_BANK_RECONCILED',x.id);
 UPDATE ms_b1_design.product_payment_intent SET state='VERIFIED',updated_at=clock_timestamp() WHERE id=p.id RETURNING * INTO p;
 IF outcome='CONFIRMED' THEN
 UPDATE ms_b1_design.booking SET status='CONFIRMED',row_version=row_version+1 WHERE id=b.id RETURNING * INTO b;
 UPDATE ms_b1_design.booking_hold SET released_at=clock_timestamp() WHERE id=hold.id;
 PERFORM ms_b1_design.b4_event(b,NULL,'PENDING_PAYMENT','b4.booking.payment.confirmed');
 ELSE
 INSERT INTO ms_b1_design.product_refund_case(business_id,booking_id,intent_id,reason,maximum_rial) VALUES(bid,b.id,p.id,CASE WHEN outcome='LATE_PAYMENT' THEN 'LATE_PAYMENT' ELSE 'RECONCILIATION' END,actual) ON CONFLICT DO NOTHING;
 END IF;
 PERFORM ms_b1_design.manual_event(bid,b.branch_id,uid,'manual.receipt.approved',r.id,jsonb_build_object('bookingId',b.id,'intentId',p.id,'receiptId',r.id,'evidenceType','MANUAL_BANK_RECONCILED','outcome',outcome,'amountRial',actual::text));
 END IF;
 UPDATE ms_b1_design.product_manual_transfer SET row_version=row_version+1 WHERE intent_id=p.id RETURNING * INTO m;
 result:=jsonb_build_object('id',v.id,'receiptId',r.id,'intentId',p.id,'version',m.row_version::text,'decision',v.decision,'outcome',outcome,'bookingStatus',b.status,'evidenceType',CASE WHEN v.decision='BANK_RECONCILED' THEN 'MANUAL_BANK_RECONCILED' END);
 RETURN ms_b1_design.manual_remember(bid,uid,'receipt.review',k,sig,result);
END $$;
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
 AND((p.provider<>'manual_card_transfer' AND r.evidence_type='PROVIDER_VERIFIED') OR(p.provider='manual_card_transfer' AND r.evidence_type='MANUAL_BANK_RECONCILED' AND EXISTS(
 SELECT 1 FROM ms_b1_design.product_manual_reconciliation x JOIN ms_b1_design.product_manual_review v ON v.id=x.review_id
 JOIN ms_b1_design.booking_hold h ON h.business_id=p.business_id AND h.revision_id=p.revision_id
 WHERE x.id=r.manual_reconciliation_id AND x.intent_id=p.id AND x.business_id=p.business_id AND x.outcome='CONFIRMED'
 AND x.bank_statement_attested AND v.decision='BANK_RECONCILED' AND x.reviewed_at=v.reviewed_at AND x.reviewed_at<h.expires_at
 AND x.reviewed_at<p.expires_at AND h.released_at IS NULL AND x.received_amount_rial=r.amount_rial
 AND EXISTS(SELECT 1 FROM ms_b1_design.resource_allocation z WHERE z.revision_id=p.revision_id AND z.released_at IS NULL)
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.resource_allocation z WHERE z.revision_id=p.revision_id AND z.released_at IS NOT NULL))))
 AND(NOT r.test_only OR EXISTS(SELECT 1 FROM ms_b1_design.product_runtime WHERE singleton AND environment='test'))))) THEN PERFORM ms_b1_design.b3_fail('INVALID_BOOKING_STATE','MS409');END IF;
 IF NEW.status IN('HELD','PENDING_PAYMENT') AND(NEW.status IS DISTINCT FROM OLD.status OR NEW.active_revision_id IS DISTINCT FROM OLD.active_revision_id)
 AND EXISTS(SELECT 1 FROM ms_b1_design.product_runtime r WHERE r.singleton AND r.business_id=NEW.business_id)
 AND EXISTS(SELECT 1 FROM ms_b1_design.booking_revision v JOIN ms_b1_design.pricing_quote q ON q.business_id=v.business_id AND q.id=v.quote_id
 WHERE v.id=NEW.active_revision_id AND v.business_id=NEW.business_id AND(q.content_document->>'depositRial')::bigint>0)
 AND NOT ms_b1_design.manual_method_available(NEW.business_id,NEW.branch_id) THEN PERFORM ms_b1_design.b3_fail('PAYMENT_UNCONFIGURED','MS409');END IF;
 ELSE
 IF (to_jsonb(NEW)-ARRAY['released_at','busy_period']) IS DISTINCT FROM(to_jsonb(OLD)-ARRAY['released_at','busy_period']) OR OLD.released_at IS NOT NULL OR NEW.released_at IS NULL THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_BOOKING_EVIDENCE');END IF;
 END IF;RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.product_payment_start(h bytea,csrf bytea,bookingid uuid,version text,callbackhash bytea,callbackcipher text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;b ms_b1_design.booking;p ms_b1_design.product_payment_intent;q ms_b1_design.pricing_quote;hold ms_b1_design.booking_hold;cfg ms_b1_design.product_runtime;BEGIN
 a:=ms_b1_design.b4_actor(h,csrf);SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;PERFORM ms_b1_design.b4_lock(cfg.business_id);
 SELECT * INTO b FROM ms_b1_design.booking WHERE id=bookingid AND business_id=(a->>'businessId')::uuid AND created_by=(a->>'userId')::uuid FOR UPDATE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=b.business_id AND revision_id=b.active_revision_id FOR UPDATE;
 IF FOUND THEN IF p.provider='manual_card_transfer' THEN PERFORM ms_b1_design.b3_fail('PAYMENT_METHOD_LOCKED','MS409');END IF;RETURN ms_b1_design.product_payment_view(p);END IF;
 IF (ms_b1_design.manual_configuration(b.business_id,b.branch_id)).online_enabled IS DISTINCT FROM true THEN PERFORM ms_b1_design.b3_fail('PAYMENT_METHOD_UNAVAILABLE','MS409');END IF;
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
 IF d->>'kind'='OTP' OR jsonb_typeof(d->'enabled')<>'boolean' OR regexp_replace(d->>'body','\{(booking|status|date|reason)\}','','g') ~ '[{}]' THEN PERFORM ms_b1_design.b3_fail('INVALID_TEMPLATE');END IF;
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
ALTER TABLE ms_b1_design.product_notification_template ADD CONSTRAINT product_notification_template_kind_check CHECK(kind IN('OTP','CONFIRM','PAYMENT','REMINDER','CANCEL','RESCHEDULE','RECEIPT_RECEIVED','RECEIPT_APPROVED','RECEIPT_REJECTED','REVIEW_REQUIRED','HOLD_EXPIRED'));
CREATE OR REPLACE FUNCTION ms_b1_design.product_collect() RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE e record;kind text;n integer:=0;cfg ms_b1_design.product_runtime;BEGIN
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 -- Events remain immutable and are consumed independently of the legacy publisher.
 FOR e IN SELECT x.* FROM ms_b1_design.outbox_event x WHERE x.business_id=cfg.business_id AND x.available_at<=clock_timestamp()
 AND x.event_type IN('auth.otp.requested','b4.booking.confirm','b4.booking.payment.confirmed','b4.booking.cancel','b4.booking.reschedule','product.payment.verified','product.payment.declined','manual.receipt.received','manual.receipt.approved','manual.receipt.rejected','b4.booking.hold.expired')
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_delivery d WHERE d.business_id=x.business_id AND d.kind='SMS' AND d.dedupe_key=x.id::text)
 ORDER BY x.available_at,x.id LIMIT 100 LOOP
 kind:=CASE e.event_type WHEN 'auth.otp.requested' THEN 'OTP' WHEN 'b4.booking.confirm' THEN 'CONFIRM' WHEN 'b4.booking.payment.confirmed' THEN 'CONFIRM' WHEN 'b4.booking.cancel' THEN 'CANCEL' WHEN 'b4.booking.reschedule' THEN 'RESCHEDULE' WHEN 'manual.receipt.received' THEN CASE WHEN e.payload->>'state'='REVIEW_REQUIRED' THEN 'REVIEW_REQUIRED' ELSE 'RECEIPT_RECEIVED' END WHEN 'manual.receipt.approved' THEN CASE WHEN e.payload->>'outcome'='CONFIRMED' THEN 'RECEIPT_APPROVED' ELSE 'REVIEW_REQUIRED' END WHEN 'manual.receipt.rejected' THEN 'RECEIPT_REJECTED' WHEN 'b4.booking.hold.expired' THEN 'HOLD_EXPIRED' ELSE 'PAYMENT' END;
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
CREATE OR REPLACE FUNCTION ms_b1_design.product_sms_context(id uuid,t uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE j ms_b1_design.product_delivery;e ms_b1_design.outbox_event;c ms_b1_design.product_auth_challenge;b ms_b1_design.booking;phone ms_b1_design.customer_contact;template ms_b1_design.product_notification_template;k text;bookingid uuid;revisionid uuid;snapshot jsonb;BEGIN
 SELECT * INTO j FROM ms_b1_design.product_delivery WHERE product_delivery.id=product_sms_context.id AND lease_token=t AND lease_until>clock_timestamp() AND state='LEASED' AND kind='SMS';
 IF NOT FOUND THEN RETURN jsonb_build_object('code','LEASE_LOST');END IF;
 k:=j.payload->>'kind';
 IF k='OTP' THEN
 SELECT * INTO e FROM ms_b1_design.outbox_event WHERE outbox_event.id=(j.payload->>'eventId')::uuid;
 SELECT * INTO c FROM ms_b1_design.product_auth_challenge WHERE product_auth_challenge.id=(e.payload->>'challengeId')::uuid;
 IF c.state<>'PENDING' OR c.expires_at<=clock_timestamp() OR c.secret_ciphertext IS NULL OR(c.kind='ADMIN_ACTIVATION' AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_admin_invitation i WHERE i.id=c.invitation_id AND i.consumed_at IS NULL AND i.expires_at>clock_timestamp())) OR(c.kind='ADMIN_RECOVERY' AND c.user_id IS NULL) THEN RETURN jsonb_build_object('code','STALE');END IF;
 RETURN jsonb_build_object('kind','OTP','challengeId',c.id,'ciphertext',c.secret_ciphertext);
 END IF;
 IF j.payload ? 'eventId' THEN
 SELECT * INTO e FROM ms_b1_design.outbox_event WHERE outbox_event.id=(j.payload->>'eventId')::uuid;
 bookingid:=CASE WHEN e.aggregate_type='booking' THEN e.aggregate_id ELSE(e.payload->>'bookingId')::uuid END;
 ELSE bookingid:=(j.payload->>'bookingId')::uuid;revisionid:=(j.payload->>'revisionId')::uuid;END IF;
 SELECT * INTO b FROM ms_b1_design.booking WHERE booking.id=bookingid AND business_id=j.business_id;
 IF (k='REMINDER' AND EXISTS(SELECT 1 FROM ms_b1_design.product_booking_operation o WHERE o.booking_id=b.id)) OR b.id IS NULL OR(k IN('CONFIRM','REMINDER','RESCHEDULE') AND b.status<>'CONFIRMED') OR(k='CANCEL' AND b.status<>'CANCELLED') OR(revisionid IS NOT NULL AND b.active_revision_id<>revisionid) OR(e.aggregate_type='booking' AND e.aggregate_version<>b.row_version) THEN RETURN jsonb_build_object('code','STALE');END IF;
 SELECT * INTO phone FROM ms_b1_design.customer_contact WHERE user_id=b.created_by AND notifications_opt_in;
 IF NOT FOUND THEN RETURN jsonb_build_object('code','OPTED_OUT');END IF;
 IF j.render_snapshot IS NOT NULL THEN RETURN j.render_snapshot;END IF;
 SELECT * INTO template FROM ms_b1_design.product_notification_template WHERE business_id=j.business_id AND kind=k ORDER BY version DESC LIMIT 1;
 IF template.business_id IS NULL OR NOT template.enabled THEN RETURN jsonb_build_object('code','TEMPLATE_UNCONFIGURED');END IF;
 snapshot:=jsonb_build_object('kind',k,'mobileCiphertext',phone.mobile_ciphertext,'mobileLookup',encode(phone.mobile_lookup,'hex'),'templateVersion',template.version,'body',template.body,
 'variables',jsonb_build_object('booking',b.id::text,'status',b.status,'reason',CASE WHEN k='RECEIPT_REJECTED' THEN coalesce(e.payload->>'reason','رسید نیاز به بررسی دارد') WHEN k='REVIEW_REQUIRED' THEN 'مهلت رزرو یا مبلغ پرداخت نیاز به بررسی دارد' WHEN k='HOLD_EXPIRED' THEN 'مهلت نگهداری نوبت پایان یافت' ELSE '' END,'date',coalesce((SELECT to_char(min(starts_at) AT TIME ZONE br.time_zone,'YYYY-MM-DD HH24:MI') FROM ms_b1_design.booking_service_segment s JOIN ms_b1_design.branch br ON br.id=b.branch_id WHERE s.revision_id=b.active_revision_id GROUP BY br.time_zone),'')));
 UPDATE ms_b1_design.product_delivery SET render_snapshot=snapshot WHERE product_delivery.id=j.id AND lease_token=t;RETURN snapshot;
END $$;
