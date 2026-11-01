-- Use the authoritative B4 expiry event; drafts without a capacity hold do not emit a hold-expired notice.
SET search_path=pg_catalog;
CREATE OR REPLACE FUNCTION ms_b1_design.product_collect() RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE e record;kind text;n integer:=0;cfg ms_b1_design.product_runtime;BEGIN
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 -- Events remain immutable and are consumed independently of the legacy publisher.
 FOR e IN SELECT x.* FROM ms_b1_design.outbox_event x WHERE x.business_id=cfg.business_id AND x.available_at<=clock_timestamp()
 AND x.event_type IN('auth.otp.requested','b4.booking.confirm','b4.booking.payment.confirmed','b4.booking.cancel','b4.booking.reschedule','product.payment.verified','product.payment.declined','manual.receipt.received','manual.receipt.approved','manual.receipt.rejected','b4.booking.expired')
 AND(x.event_type<>'b4.booking.expired' OR EXISTS(SELECT 1 FROM ms_b1_design.booking_hold h WHERE h.booking_id=x.aggregate_id AND h.business_id=x.business_id))
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_delivery d WHERE d.business_id=x.business_id AND d.kind='SMS' AND d.dedupe_key=x.id::text)
 ORDER BY x.available_at,x.id LIMIT 100 LOOP
 kind:=CASE e.event_type WHEN 'auth.otp.requested' THEN 'OTP' WHEN 'b4.booking.confirm' THEN 'CONFIRM' WHEN 'b4.booking.payment.confirmed' THEN 'CONFIRM' WHEN 'b4.booking.cancel' THEN 'CANCEL' WHEN 'b4.booking.reschedule' THEN 'RESCHEDULE' WHEN 'manual.receipt.received' THEN CASE WHEN e.payload->>'state'='REVIEW_REQUIRED' THEN 'REVIEW_REQUIRED' ELSE 'RECEIPT_RECEIVED' END WHEN 'manual.receipt.approved' THEN CASE WHEN e.payload->>'outcome'='CONFIRMED' THEN 'RECEIPT_APPROVED' ELSE 'REVIEW_REQUIRED' END WHEN 'manual.receipt.rejected' THEN 'RECEIPT_REJECTED' WHEN 'b4.booking.expired' THEN 'HOLD_EXPIRED' ELSE 'PAYMENT' END;
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

-- Offline migration-owner operator only. The application/worker cannot invoke
-- retention. Configured deadlines are immutable receipt snapshots; NULL retains.
CREATE FUNCTION ms_b1_design.manual_retention_eligible(receiptid uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT coalesce((SELECT r.retention_eligible_at IS NOT NULL AND r.retention_eligible_at<=clock_timestamp()
 AND EXISTS(SELECT 1 FROM ms_b1_design.product_manual_review v WHERE v.receipt_id=r.id)
 AND(b.status IN('CANCELLED','EXPIRED') OR EXISTS(SELECT 1 FROM ms_b1_design.product_booking_operation o WHERE o.booking_id=b.id AND o.state='COMPLETED'))
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_refund_case f WHERE f.intent_id=p.id AND f.state<>'VERIFIED')
 FROM ms_b1_design.product_manual_receipt r JOIN ms_b1_design.product_payment_intent p ON p.id=r.intent_id
 JOIN ms_b1_design.booking b ON b.id=p.booking_id AND b.business_id=p.business_id WHERE r.id=receiptid),false)
$$;
CREATE FUNCTION ms_b1_design.manual_retention_request(receiptid uuid,manifesthash text) RETURNS jsonb
 LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
 DECLARE r ms_b1_design.product_manual_receipt;t ms_b1_design.product_receipt_retention;BEGIN
 SELECT * INTO r FROM ms_b1_design.product_manual_receipt WHERE id=receiptid;
 IF r.id IS NULL OR manifesthash !~ '^[a-f0-9]{64}$' THEN PERFORM ms_b1_design.b3_fail('INVALID_RETENTION_REQUEST');END IF;
 PERFORM ms_b1_design.b4_lock(r.business_id);
 SELECT * INTO t FROM ms_b1_design.product_receipt_retention WHERE receipt_id=r.id FOR UPDATE;
 IF t.receipt_id IS NULL THEN
 IF NOT ms_b1_design.manual_retention_eligible(r.id) THEN PERFORM ms_b1_design.b3_fail('RETENTION_NOT_ELIGIBLE','MS409');END IF;
 INSERT INTO ms_b1_design.product_receipt_retention(receipt_id,business_id,backup_manifest_sha256) VALUES(r.id,r.business_id,manifesthash) RETURNING * INTO t;
 INSERT INTO ms_b1_design.audit_log(business_id,action,target_type,target_id,request_id,redacted_change)
 VALUES(r.business_id,'manual.receipt.retention.requested','manual_receipt',r.id,gen_random_uuid(),jsonb_build_object('backupManifestSha256',manifesthash));
 ELSIF t.backup_manifest_sha256<>manifesthash THEN PERFORM ms_b1_design.b3_fail('RETENTION_BACKUP_MISMATCH','MS409');END IF;
 RETURN to_jsonb(t)||jsonb_build_object('originalKey',r.original_key,'displayKey',r.display_key);
END $$;
CREATE FUNCTION ms_b1_design.manual_retention_finish(receiptid uuid,manifesthash text) RETURNS void
 LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE t ms_b1_design.product_receipt_retention;BEGIN
 SELECT * INTO t FROM ms_b1_design.product_receipt_retention WHERE receipt_id=receiptid FOR UPDATE;
 IF t.receipt_id IS NULL OR t.backup_manifest_sha256<>manifesthash THEN PERFORM ms_b1_design.b3_fail('RETENTION_BACKUP_MISMATCH','MS409');END IF;
 IF t.state='PURGED' THEN RETURN;END IF;
 UPDATE ms_b1_design.product_receipt_retention SET state='PURGED',purged_at=clock_timestamp() WHERE receipt_id=receiptid;
 INSERT INTO ms_b1_design.audit_log(business_id,action,target_type,target_id,request_id,redacted_change)
 VALUES(t.business_id,'manual.receipt.retention.purged','manual_receipt',receiptid,gen_random_uuid(),jsonb_build_object('backupManifestSha256',manifesthash));
END $$;
CREATE FUNCTION ms_b1_design.manual_retention_guard() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF TG_OP='DELETE' OR OLD.state<>'REQUESTED' OR NEW.state<>'PURGED' OR NEW.purged_at IS NULL
 OR(to_jsonb(NEW)-ARRAY['state','purged_at']) IS DISTINCT FROM(to_jsonb(OLD)-ARRAY['state','purged_at']) THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_RETENTION_EVIDENCE');END IF;RETURN NEW;
END $$;
CREATE TRIGGER manual_retention_evidence BEFORE UPDATE OR DELETE ON ms_b1_design.product_receipt_retention FOR EACH ROW EXECUTE FUNCTION ms_b1_design.manual_retention_guard();
REVOKE ALL ON FUNCTION ms_b1_design.manual_retention_eligible(uuid),ms_b1_design.manual_retention_request(uuid,text),ms_b1_design.manual_retention_finish(uuid,text),ms_b1_design.manual_retention_guard()
 FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
