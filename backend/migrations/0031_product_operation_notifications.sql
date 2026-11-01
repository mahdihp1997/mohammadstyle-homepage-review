-- A customer already in salon operations does not receive future reminders or a misleading cancellation preview.
CREATE OR REPLACE FUNCTION ms_b1_design.product_collect() RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE e record;kind text;n integer:=0;cfg ms_b1_design.product_runtime;BEGIN
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 -- Events remain immutable and are consumed independently of the legacy publisher.
 FOR e IN SELECT x.* FROM ms_b1_design.outbox_event x WHERE x.business_id=cfg.business_id AND x.available_at<=clock_timestamp()
 AND x.event_type IN('auth.otp.requested','b4.booking.confirm','b4.booking.payment.confirmed','b4.booking.cancel','b4.booking.reschedule','product.payment.verified','product.payment.declined')
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_delivery d WHERE d.business_id=x.business_id AND d.kind='SMS' AND d.dedupe_key=x.id::text)
 ORDER BY x.available_at,x.id LIMIT 100 LOOP
 kind:=CASE e.event_type WHEN 'auth.otp.requested' THEN 'OTP' WHEN 'b4.booking.confirm' THEN 'CONFIRM' WHEN 'b4.booking.payment.confirmed' THEN 'CONFIRM' WHEN 'b4.booking.cancel' THEN 'CANCEL' WHEN 'b4.booking.reschedule' THEN 'RESCHEDULE' ELSE 'PAYMENT' END;
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
 'variables',jsonb_build_object('booking',b.id::text,'status',b.status,'date',coalesce((SELECT to_char(min(starts_at) AT TIME ZONE br.time_zone,'YYYY-MM-DD HH24:MI') FROM ms_b1_design.booking_service_segment s JOIN ms_b1_design.branch br ON br.id=b.branch_id WHERE s.revision_id=b.active_revision_id),'')));
 UPDATE ms_b1_design.product_delivery SET render_snapshot=snapshot WHERE product_delivery.id=j.id AND lease_token=t;RETURN snapshot;
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.b4_cancellation(b ms_b1_design.booking,at_time timestamptz) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 DECLARE q ms_b1_design.pricing_quote;t jsonb;deadline timestamptz;allowed boolean;paid numeric:=0;base numeric:=0;rate integer:=0;refund numeric:=0;mins numeric;BEGIN
 IF b.plan_committed THEN SELECT x.* INTO q FROM ms_b1_design.pricing_quote x JOIN ms_b1_design.booking_revision v ON v.business_id=x.business_id AND v.quote_id=x.id WHERE v.business_id=b.business_id AND v.id=b.active_revision_id;
 t:=q.terms_document->'terms';deadline:=ms_b1_design.b3_instant(q.content_document->>'startsAt')-make_interval(mins=>(t->>'cancellationDeadlineMinutes')::integer);
 SELECT coalesce(sum(r.amount_rial),0) INTO paid FROM ms_b1_design.product_payment_receipt r JOIN ms_b1_design.product_payment_intent p ON p.id=r.intent_id WHERE p.business_id=b.business_id AND p.booking_id=b.id;
 base:=CASE WHEN t->>'refundBase'='DEPOSIT_PAID' THEN least(paid,(q.content_document->>'depositRial')::numeric) ELSE paid END;
 rate:=(t->>'outsideRefundBps')::int;mins:=floor(extract(epoch FROM ms_b1_design.b3_instant(q.content_document->>'startsAt')-at_time)/60);
 IF mins>=0 THEN SELECT(value->>'refundBps')::int INTO rate FROM jsonb_array_elements(t->'refundWindows') WHERE(value->>'thresholdMinutes')::int<=mins ORDER BY(value->>'thresholdMinutes')::int DESC LIMIT 1;rate:=coalesce(rate,(t->>'outsideRefundBps')::int);END IF;
 refund:=least(base,floor((base*rate+50000)/100000)*10);END IF;
 allowed:=b.status IN('DRAFT','HELD','PENDING_PAYMENT','CONFIRMED') AND(deadline IS NULL OR at_time<=deadline) AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_booking_operation o WHERE o.booking_id=b.id);
 RETURN jsonb_build_object('bookingId',b.id,'version',b.row_version::text,'evaluatedAt',ms_b1_design.b3_iso(at_time),'cancellationAllowed',allowed,'deadline',ms_b1_design.b3_iso(deadline),'paidRial',paid::text,'refundPreviewRial',refund::text,'moneyExecuted',false,'terms',q.terms_document);
END $$;

