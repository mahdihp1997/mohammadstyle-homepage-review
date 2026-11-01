-- Restore parameter qualification after the private Booking SMS helper rename.
-- Runtime permissions and the public dispatcher stay unchanged.
SET search_path=pg_catalog;
CREATE OR REPLACE FUNCTION ms_b1_design.booking_product_sms_context_v46(id uuid, t uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
 DECLARE j ms_b1_design.product_delivery;e ms_b1_design.outbox_event;c ms_b1_design.product_auth_challenge;b ms_b1_design.booking;phone ms_b1_design.customer_contact;template ms_b1_design.product_notification_template;k text;bookingid uuid;revisionid uuid;snapshot jsonb;BEGIN
 SELECT * INTO j FROM ms_b1_design.product_delivery WHERE product_delivery.id=booking_product_sms_context_v46.id AND lease_token=t AND lease_until>clock_timestamp() AND state='LEASED' AND kind='SMS';
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
END $function$

