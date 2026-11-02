SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.manual_transfer_document(p ms_b1_design.product_payment_intent) RETURNS jsonb
 LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('version',m.row_version::text,'maxSubmissions',m.max_submissions,
 'destination',jsonb_build_object('id',m.card_id,'bankName',m.bank_name,'lastFour',m.last_four,
 '_privateCard',jsonb_build_object('ciphertext',m.destination_ciphertext,'businessId',m.business_id,'cardId',m.card_id,'version',m.card_version::text,'fullNumber',true)),
 'cardCurrentlyActive',EXISTS(SELECT 1 FROM ms_b1_design.product_bank_card c WHERE c.business_id=m.business_id AND c.id=m.card_id AND c.active AND c.archived_at IS NULL),
 'receipts',coalesce((SELECT jsonb_agg(jsonb_build_object('id',r.id,'submission',r.submission,'submittedAt',ms_b1_design.b3_iso(r.created_at),
 'imageAvailable',NOT EXISTS(SELECT 1 FROM ms_b1_design.product_receipt_retention t WHERE t.receipt_id=r.id),
 'imageUrl','/api/product/manual/receipts/'||r.id::text||'/image',
 '_privateReference',CASE WHEN r.sender_reference_ciphertext IS NOT NULL THEN jsonb_build_object('ciphertext',r.sender_reference_ciphertext,'businessId',r.business_id,'receiptId',r.id) END,
 'status',CASE WHEN v.decision='REJECTED' THEN 'REJECTED' WHEN v.decision='BANK_RECONCILED' THEN 'MANUAL_BANK_RECONCILED' ELSE 'PENDING_REVIEW' END,
 'review',CASE WHEN v.id IS NOT NULL THEN jsonb_build_object('decision',v.decision,'reason',v.reason,'reviewerId',v.reviewed_by,'at',ms_b1_design.b3_iso(v.reviewed_at)) END
 ) ORDER BY r.submission) FROM ms_b1_design.product_manual_receipt r LEFT JOIN ms_b1_design.product_manual_review v ON v.receipt_id=r.id WHERE r.business_id=m.business_id AND r.intent_id=m.intent_id),'[]'::jsonb),
 'reconciliation',(SELECT jsonb_build_object('source','MANUAL_BANK_RECONCILED','receivedAmountRial',x.received_amount_rial::text,'receivedAt',ms_b1_design.b3_iso(x.received_at),'outcome',x.outcome,'reviewerId',x.reviewed_by,
 '_privateBankEvidence',jsonb_build_object('ciphertext',x.evidence_ciphertext,'businessId',x.business_id,'intentId',x.intent_id)) FROM ms_b1_design.product_manual_reconciliation x WHERE x.intent_id=m.intent_id))
 FROM ms_b1_design.product_manual_transfer m WHERE m.intent_id=p.id
$$;
CREATE OR REPLACE FUNCTION ms_b1_design.product_payment_view(p ms_b1_design.product_payment_intent) RETURNS jsonb
 LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('id',p.id,'bookingId',p.booking_id,'revisionId',p.revision_id,'state',p.state,'amountRial',p.amount_rial::text,'currency',p.currency,
 'method',CASE WHEN p.provider='manual_card_transfer' THEN 'MANUAL_CARD_TRANSFER' ELSE 'ONLINE_GATEWAY' END,
 'evidenceType',(SELECT evidence_type FROM ms_b1_design.product_payment_receipt WHERE intent_id=p.id),
 'receivedAmountRial',(SELECT amount_rial::text FROM ms_b1_design.product_payment_receipt WHERE intent_id=p.id),
 'hostedUrl',CASE WHEN p.state='REDIRECT_READY' AND p.expires_at>clock_timestamp() THEN p.hosted_url ELSE NULL END,'expiresAt',ms_b1_design.b3_iso(p.expires_at),
 'reference',(SELECT provider_reference FROM ms_b1_design.product_payment_receipt WHERE intent_id=p.id),
 'manual',CASE WHEN p.provider='manual_card_transfer' THEN ms_b1_design.manual_transfer_document(p) END,
 'refunds',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'state',state,'reason',reason,'maximumRial',maximum_rial::text,'requestedRial',requested_rial::text)) FROM ms_b1_design.product_refund_case WHERE intent_id=p.id),'[]'::jsonb))
$$;

CREATE FUNCTION ms_b1_design.manual_start(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;b ms_b1_design.booking;p ms_b1_design.product_payment_intent;c ms_b1_design.product_bank_card;cfg ms_b1_design.product_payment_configuration;hold ms_b1_design.booking_hold;q ms_b1_design.pricing_quote;result jsonb;BEGIN
 a:=ms_b1_design.b4_actor(h,csrf);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);
 PERFORM ms_b1_design.b3_keys(d,ARRAY['bookingId','version','cardId']);
 SELECT * INTO b FROM ms_b1_design.booking WHERE business_id=bid AND id=(d->>'bookingId')::uuid AND created_by=uid FOR UPDATE;
 IF b.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 result:=ms_b1_design.manual_replay(bid,uid,'manual.start',k,sig);IF result IS NOT NULL THEN RETURN result;END IF;
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=bid AND revision_id=b.active_revision_id FOR UPDATE;
 IF p.id IS NOT NULL THEN
 IF p.provider<>'manual_card_transfer' OR NOT EXISTS(SELECT 1 FROM ms_b1_design.product_manual_transfer m WHERE m.intent_id=p.id AND m.card_id=(d->>'cardId')::uuid) THEN PERFORM ms_b1_design.b3_fail('PAYMENT_METHOD_LOCKED','MS409');END IF;
 result:=jsonb_build_object('id',p.id,'state',p.state,'method','MANUAL_CARD_TRANSFER');RETURN ms_b1_design.manual_remember(bid,uid,'manual.start',k,sig,result);END IF;
 IF b.row_version::text IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_BOOKING','MS412');END IF;
 SELECT * INTO hold FROM ms_b1_design.booking_hold WHERE business_id=bid AND revision_id=b.active_revision_id;
 IF b.status<>'PENDING_PAYMENT' OR hold.id IS NULL OR hold.released_at IS NOT NULL OR hold.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('HOLD_EXPIRED','MS409');END IF;
 cfg:=ms_b1_design.manual_configuration(bid,b.branch_id);
 SELECT * INTO c FROM ms_b1_design.product_bank_card WHERE business_id=bid AND id=(d->>'cardId')::uuid FOR SHARE;
 IF cfg.manual_enabled IS DISTINCT FROM true OR c.id IS NULL OR NOT ms_b1_design.manual_card_eligible(c,b.branch_id) THEN PERFORM ms_b1_design.b3_fail('CARD_UNAVAILABLE','MS409');END IF;
 SELECT x.* INTO STRICT q FROM ms_b1_design.pricing_quote x JOIN ms_b1_design.booking_policy_acceptance x2 ON x2.business_id=x.business_id AND x2.quote_id=x.id AND x2.quote_hash=x.content_hash WHERE x2.revision_id=b.active_revision_id;
 IF(q.content_document->>'depositRial')::bigint<=0 THEN PERFORM ms_b1_design.b3_fail('INVALID_PAYMENT');END IF;
 INSERT INTO ms_b1_design.product_payment_intent(business_id,booking_id,revision_id,provider,amount_rial,state,expires_at,created_by)
 VALUES(bid,b.id,b.active_revision_id,'manual_card_transfer',(q.content_document->>'depositRial')::bigint,'AWAITING_TRANSFER',hold.expires_at,uid) RETURNING * INTO p;
 INSERT INTO ms_b1_design.product_manual_transfer(intent_id,business_id,card_id,card_version,destination_ciphertext,card_fingerprint,bank_name,last_four,max_submissions,retention_days)
 VALUES(p.id,bid,c.id,c.row_version,c.details_ciphertext,c.card_fingerprint,c.bank_name,c.last_four,cfg.max_receipt_submissions,cfg.receipt_retention_days);
 result:=jsonb_build_object('id',p.id,'state',p.state,'method','MANUAL_CARD_TRANSFER');
 PERFORM ms_b1_design.manual_event(bid,b.branch_id,uid,'manual.intent.created',p.id,jsonb_build_object('bookingId',b.id,'intentId',p.id,'amountRial',p.amount_rial::text));
 RETURN ms_b1_design.manual_remember(bid,uid,'manual.start',k,sig,result);
END $$;

CREATE FUNCTION ms_b1_design.manual_submission_context(h bytea,csrf bytea,intentid uuid,idem uuid DEFAULT NULL) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;p ms_b1_design.product_payment_intent;b ms_b1_design.booking;m ms_b1_design.product_manual_transfer;last_receipt ms_b1_design.product_manual_receipt;BEGIN
 a:=ms_b1_design.b4_actor(h,csrf);SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=(a->>'businessId')::uuid AND id=intentid AND provider='manual_card_transfer';
 SELECT * INTO b FROM ms_b1_design.booking WHERE id=p.booking_id AND business_id=p.business_id AND created_by=(a->>'userId')::uuid;
 IF b.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 SELECT * INTO STRICT m FROM ms_b1_design.product_manual_transfer WHERE intent_id=p.id;
 IF idem IS NOT NULL AND EXISTS(SELECT 1 FROM ms_b1_design.product_manual_request q WHERE q.business_id=p.business_id AND q.actor_id=(a->>'userId')::uuid AND q.operation='receipt.submit' AND q.idempotency_key=idem AND q.response->>'intentId'=p.id::text) THEN RETURN jsonb_build_object('businessId',b.business_id,'userId',b.created_by,'intentId',p.id,'version',m.row_version::text,'replayAvailable',true);END IF;
 IF p.state='VERIFIED' OR EXISTS(SELECT 1 FROM ms_b1_design.product_manual_reconciliation WHERE intent_id=p.id) THEN PERFORM ms_b1_design.b3_fail('MANUAL_PAYMENT_ALREADY_RECONCILED','MS409');END IF;
 SELECT * INTO last_receipt FROM ms_b1_design.product_manual_receipt WHERE intent_id=p.id ORDER BY submission DESC LIMIT 1;
 IF last_receipt.id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_manual_review WHERE receipt_id=last_receipt.id AND decision='REJECTED') THEN PERFORM ms_b1_design.b3_fail('RECEIPT_ALREADY_PENDING','MS409');END IF;
 IF coalesce(last_receipt.submission,0)>=m.max_submissions THEN PERFORM ms_b1_design.b3_fail('RECEIPT_SUBMISSION_LIMIT','MS409');END IF;
 RETURN jsonb_build_object('businessId',b.business_id,'userId',b.created_by,'intentId',p.id,'version',m.row_version::text,'expiresAt',ms_b1_design.b3_iso(p.expires_at),'lateEvidenceOnly',p.expires_at<=clock_timestamp() OR b.status<>'PENDING_PAYMENT');
END $$;

CREATE FUNCTION ms_b1_design.manual_receipt_submit(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;p ms_b1_design.product_payment_intent;b ms_b1_design.booking;m ms_b1_design.product_manual_transfer;r ms_b1_design.product_manual_receipt;result jsonb;n integer;BEGIN
 a:=ms_b1_design.b4_actor(h,csrf);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','intentId','version','referenceCiphertext','originalKey','originalHash','originalObjectHash','originalObjectBytes','displayKey','displayHash','displayObjectHash','displayObjectBytes','mime','sourceBytes','width','height']);
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=bid AND id=(d->>'intentId')::uuid AND provider='manual_card_transfer' FOR UPDATE;
 SELECT * INTO b FROM ms_b1_design.booking WHERE business_id=bid AND id=p.booking_id AND created_by=uid;
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
 PERFORM ms_b1_design.manual_event(bid,b.branch_id,uid,'manual.receipt.received',r.id,jsonb_build_object('bookingId',b.id,'intentId',p.id,'receiptId',r.id,'state',p.state));
 RETURN ms_b1_design.manual_remember(bid,uid,'receipt.submit',k,sig,result);
END $$;

CREATE FUNCTION ms_b1_design.manual_review_context(h bytea,csrf bytea,intentid uuid,receiptid uuid) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;p ms_b1_design.product_payment_intent;b ms_b1_design.booking;m ms_b1_design.product_manual_transfer;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=(a->>'businessId')::uuid AND id=intentid AND provider='manual_card_transfer';SELECT * INTO b FROM ms_b1_design.booking WHERE business_id=p.business_id AND id=p.booking_id;
 IF b.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;PERFORM ms_b1_design.manual_financial_actor(h,csrf,b.branch_id,'payment.manual.review');
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.product_manual_receipt WHERE business_id=p.business_id AND intent_id=p.id AND id=receiptid) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 SELECT * INTO STRICT m FROM ms_b1_design.product_manual_transfer WHERE intent_id=p.id;
 RETURN jsonb_build_object('businessId',b.business_id,'intentId',p.id,'version',m.row_version::text,'cardFingerprint',encode(m.card_fingerprint,'hex'));
END $$;

CREATE FUNCTION ms_b1_design.manual_review_decide(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;p ms_b1_design.product_payment_intent;b ms_b1_design.booking;m ms_b1_design.product_manual_transfer;r ms_b1_design.product_manual_receipt;v ms_b1_design.product_manual_review;x ms_b1_design.product_manual_reconciliation;hold ms_b1_design.booking_hold;cfg ms_b1_design.product_runtime;result jsonb;outcome text;old_status text;actual bigint;BEGIN
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
 PERFORM ms_b1_design.manual_event(bid,b.branch_id,uid,'manual.receipt.rejected',r.id,jsonb_build_object('bookingId',b.id,'intentId',p.id,'receiptId',r.id,'reason',regexp_replace(trim(d->>'reason'),'[0-9۰-۹٠-٩]{4,}','***','g')));
 ELSE
 IF(d->'attested') IS DISTINCT FROM 'true'::jsonb OR(d->>'amountRial') !~ '^[1-9]\d{0,18}$' OR(d->>'amountRial')::numeric>9223372036854775807 OR(d->>'bankReferenceHash') !~ '^[a-f0-9]{64}$' OR length(d->>'evidenceCiphertext') NOT BETWEEN 50 AND 8000 OR d->>'receivedAt' IS NULL THEN PERFORM ms_b1_design.b3_fail('BANK_RECONCILIATION_REQUIRED');END IF;
 actual:=(d->>'amountRial')::bigint;
 IF NOT isfinite(ms_b1_design.b3_instant(d->>'receivedAt')) OR ms_b1_design.b3_instant(d->>'receivedAt')>clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('INVALID_BANK_TIME');END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.product_manual_reconciliation WHERE business_id=bid AND card_fingerprint=m.card_fingerprint AND bank_reference_hash=decode(d->>'bankReferenceHash','hex')) THEN PERFORM ms_b1_design.b3_fail('BANK_TRANSACTION_ALREADY_USED','MS409');END IF;
 -- Expiration is authoritative at review time, never the client-attested arrival time.
 PERFORM ms_b1_design.b4_expire_business(bid);SELECT * INTO STRICT b FROM ms_b1_design.booking WHERE id=b.id FOR UPDATE;
 SELECT * INTO hold FROM ms_b1_design.booking_hold WHERE business_id=bid AND revision_id=p.revision_id FOR UPDATE;
 outcome:=CASE WHEN actual<>p.amount_rial THEN 'AMOUNT_MISMATCH'
 WHEN p.expires_at<=clock_timestamp() OR hold.id IS NULL OR hold.expires_at<=clock_timestamp() OR hold.released_at IS NOT NULL THEN 'LATE_PAYMENT'
 WHEN b.status<>'PENDING_PAYMENT' OR b.active_revision_id<>p.revision_id THEN 'BOOKING_CLOSED'
 WHEN NOT EXISTS(SELECT 1 FROM ms_b1_design.resource_allocation z WHERE z.revision_id=p.revision_id AND z.released_at IS NULL) OR EXISTS(SELECT 1 FROM ms_b1_design.resource_allocation z WHERE z.revision_id=p.revision_id AND z.released_at IS NOT NULL) THEN 'ALLOCATION_REVIEW'
 ELSE 'CONFIRMED' END;
 INSERT INTO ms_b1_design.product_manual_review(business_id,intent_id,receipt_id,decision,reason,reviewed_by) VALUES(bid,p.id,r.id,'BANK_RECONCILED',trim(d->>'reason'),uid) RETURNING * INTO v;
 INSERT INTO ms_b1_design.product_manual_reconciliation(business_id,intent_id,review_id,card_fingerprint,bank_reference_hash,evidence_ciphertext,received_amount_rial,received_at,bank_statement_attested,outcome,reviewed_by,review_session_id)
 VALUES(bid,p.id,v.id,m.card_fingerprint,decode(d->>'bankReferenceHash','hex'),d->>'evidenceCiphertext',actual,ms_b1_design.b3_instant(d->>'receivedAt'),true,outcome,uid,(a->>'sessionId')::uuid) RETURNING * INTO x;
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

CREATE FUNCTION ms_b1_design.manual_receipt_access(h bytea,receiptid uuid) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;r ms_b1_design.product_manual_receipt;b ms_b1_design.booking;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);SELECT * INTO r FROM ms_b1_design.product_manual_receipt WHERE business_id=(a->>'businessId')::uuid AND id=receiptid;
 SELECT x.* INTO b FROM ms_b1_design.booking x JOIN ms_b1_design.product_payment_intent p ON p.booking_id=x.id AND p.business_id=x.business_id WHERE p.id=r.intent_id;
 IF b.id IS NULL OR(b.created_by<>(a->>'userId')::uuid AND NOT ms_b1_design.b1b_can(a,'payment.manual.read',b.branch_id)) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.product_receipt_retention WHERE receipt_id=r.id) THEN PERFORM ms_b1_design.b3_fail('RECEIPT_RETENTION_APPLIED','MS409');END IF;
 RETURN to_jsonb(r);
END $$;

CREATE FUNCTION ms_b1_design.manual_payments_read(h bytea,d jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;bid uuid;branchid uuid;fromdate date;todate date;term text;state text;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);bid:=(a->>'businessId')::uuid;PERFORM ms_b1_design.b3_keys(d,ARRAY['branchId','from','to','state','query','offset']);branchid:=(d->>'branchId')::uuid;
 IF branchid IS NOT NULL AND NOT ms_b1_design.b1b_can(a,'payment.manual.read',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF branchid IS NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND ms_b1_design.b1b_can(a,'payment.manual.read',b.id)) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF(d->>'from') !~ '^\d{4}-\d{2}-\d{2}$' OR(d->>'to') !~ '^\d{4}-\d{2}-\d{2}$' OR(d->>'offset') !~ '^\d{1,5}$' OR length(d->>'query')>100 OR(d->>'offset')::int>10000 THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 fromdate:=(d->>'from')::date;todate:=(d->>'to')::date;term:=d->>'query';state:=d->>'state';
 IF fromdate>todate OR todate-fromdate>366 OR state NOT IN('','AWAITING_TRANSFER','UNDER_REVIEW','REJECTED','REVIEW_REQUIRED','VERIFIED') THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(x.document ORDER BY x.created_at DESC,x.id) FROM(
 SELECT p.id,p.created_at,ms_b1_design.product_payment_view(p)||jsonb_build_object('bookingStatus',b.status,'bookingVersion',b.row_version::text,'branchId',b.branch_id,'branchName',br.display_name,
 'customer',jsonb_build_object('id',u.id,'name',u.display_name,'mobileLastFour',c.mobile_last_four)) document
 FROM ms_b1_design.product_payment_intent p JOIN ms_b1_design.booking b ON b.business_id=p.business_id AND b.id=p.booking_id JOIN ms_b1_design.branch br ON br.id=b.branch_id JOIN ms_b1_design.app_user u ON u.id=b.created_by LEFT JOIN ms_b1_design.customer_contact c ON c.user_id=u.id
 WHERE p.business_id=bid AND p.provider='manual_card_transfer' AND(branchid IS NULL OR b.branch_id=branchid) AND ms_b1_design.b1b_can(a,'payment.manual.read',b.branch_id)
 AND(state='' OR p.state=state) AND(p.created_at AT TIME ZONE br.time_zone)::date BETWEEN fromdate AND todate
 AND(term='' OR b.id::text=term OR p.id::text=term OR position(lower(term) IN lower(u.display_name))>0 OR c.mobile_last_four=term)
 ORDER BY p.created_at DESC,p.id LIMIT 25 OFFSET(d->>'offset')::int)x),'[]'::jsonb));
END $$;

REVOKE ALL ON FUNCTION ms_b1_design.manual_transfer_document(ms_b1_design.product_payment_intent) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
REVOKE ALL ON FUNCTION ms_b1_design.manual_start(bytea,bytea,uuid,bytea,jsonb),ms_b1_design.manual_submission_context(bytea,bytea,uuid,uuid),
 ms_b1_design.manual_receipt_submit(bytea,bytea,uuid,bytea,jsonb),ms_b1_design.manual_review_context(bytea,bytea,uuid,uuid),ms_b1_design.manual_review_decide(bytea,bytea,uuid,bytea,jsonb),
 ms_b1_design.manual_receipt_access(bytea,uuid),ms_b1_design.manual_payments_read(bytea,jsonb) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.manual_start(bytea,bytea,uuid,bytea,jsonb),ms_b1_design.manual_submission_context(bytea,bytea,uuid,uuid),
 ms_b1_design.manual_receipt_submit(bytea,bytea,uuid,bytea,jsonb),ms_b1_design.manual_review_context(bytea,bytea,uuid,uuid),ms_b1_design.manual_review_decide(bytea,bytea,uuid,bytea,jsonb),
 ms_b1_design.manual_receipt_access(bytea,uuid),ms_b1_design.manual_payments_read(bytea,jsonb) TO ms_b1b_api;
