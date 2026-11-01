SET search_path=ms_b1_design,public;
CREATE TABLE product_delivery (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL REFERENCES business(id),
 kind text NOT NULL CHECK(kind IN('PAYMENT_REQUEST','PAYMENT_VERIFY','REFUND','SMS')),dedupe_key text NOT NULL,
 payload jsonb NOT NULL, state text NOT NULL DEFAULT 'READY' CHECK(state IN('READY','LEASED','DISPATCHED','DELIVERED','BLOCKED','UNKNOWN','DEAD','CANCELLED')),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 12),available_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 lease_token uuid,lease_until timestamptz,provider_receipt text,last_code text,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,kind,dedupe_key),CHECK(jsonb_typeof(payload)='object')
);
CREATE INDEX product_delivery_ready ON product_delivery(available_at,id) WHERE state='READY';
CREATE INDEX product_delivery_lease ON product_delivery(lease_until,id) WHERE state IN('LEASED','DISPATCHED');
CREATE TABLE product_notification_template (
 business_id uuid NOT NULL REFERENCES business(id),kind text NOT NULL CHECK(kind IN('OTP','CONFIRM','PAYMENT','REMINDER','CANCEL','RESCHEDULE')),
 version integer NOT NULL CHECK(version>0),body text NOT NULL CHECK(length(body) BETWEEN 1 AND 600),
 enabled boolean NOT NULL DEFAULT false,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),created_by uuid REFERENCES app_user(id),
 PRIMARY KEY(business_id,kind,version)
);
CREATE TRIGGER product_template_immutable BEFORE UPDATE OR DELETE ON product_notification_template FOR EACH ROW EXECUTE FUNCTION b3_freeze();
CREATE TABLE product_operational_settings (
 business_id uuid NOT NULL,branch_id uuid NOT NULL,reminder_minutes integer CHECK(reminder_minutes BETWEEN 5 AND 10080),
 no_show_grace_minutes integer CHECK(no_show_grace_minutes BETWEEN 0 AND 1440),row_version bigint NOT NULL DEFAULT 1,
 PRIMARY KEY(business_id,branch_id),FOREIGN KEY(business_id,branch_id) REFERENCES branch(business_id,id)
);
REVOKE ALL ON product_delivery,product_notification_template,product_operational_settings FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker;
SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.product_enqueue(bid uuid,kind text,key text,payload jsonb,at_time timestamptz DEFAULT clock_timestamp()) RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE result uuid;BEGIN
 INSERT INTO ms_b1_design.product_delivery(business_id,kind,dedupe_key,payload,available_at) VALUES(bid,kind,key,payload,at_time) ON CONFLICT(business_id,kind,dedupe_key) DO NOTHING RETURNING id INTO result;RETURN result;
END $$;
CREATE FUNCTION ms_b1_design.product_collect() RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
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
 WHERE b.business_id=cfg.business_id AND b.status='CONFIRMED' AND c.reminder_minutes IS NOT NULL
 GROUP BY b.business_id,b.id,b.active_revision_id,c.reminder_minutes HAVING min(s.starts_at)>clock_timestamp() AND min(s.starts_at)-make_interval(mins=>c.reminder_minutes)<=clock_timestamp() LOOP
 PERFORM ms_b1_design.product_enqueue(e.business_id,'SMS','reminder:'||e.active_revision_id::text,jsonb_build_object('kind','REMINDER','bookingId',e.id,'revisionId',e.active_revision_id));END LOOP;
 RETURN n;
END $$;
CREATE FUNCTION ms_b1_design.product_claim(replay_safe_sms boolean) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE j ms_b1_design.product_delivery;t uuid:=gen_random_uuid();BEGIN
 -- A crash before dispatch is retryable. An ambiguous non-idempotent SMS must be reconciled.
 UPDATE ms_b1_design.product_delivery SET state=CASE WHEN state='DISPATCHED' AND kind='SMS' AND NOT replay_safe_sms THEN 'UNKNOWN' ELSE 'READY' END,lease_token=NULL,lease_until=NULL,last_code='LEASE_EXPIRED',updated_at=clock_timestamp()
 WHERE state IN('LEASED','DISPATCHED') AND lease_until<clock_timestamp();
 SELECT * INTO j FROM ms_b1_design.product_delivery WHERE state='READY' AND attempts<12 AND available_at<=clock_timestamp() ORDER BY available_at,id LIMIT 1 FOR UPDATE SKIP LOCKED;
 IF NOT FOUND THEN RETURN NULL;END IF;
 UPDATE ms_b1_design.product_delivery SET state='LEASED',attempts=attempts+1,lease_token=t,lease_until=clock_timestamp()+interval '90 seconds',updated_at=clock_timestamp() WHERE id=j.id RETURNING * INTO j;
 RETURN jsonb_build_object('id',j.id,'token',t,'kind',j.kind,'payload',j.payload,'attempt',j.attempts,'businessId',j.business_id);
END $$;
CREATE FUNCTION ms_b1_design.product_delivery_state(id uuid,t uuid,p_state text,code text,receipt text DEFAULT NULL) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ BEGIN
 IF p_state NOT IN('DISPATCHED','DELIVERED','READY','BLOCKED','UNKNOWN','DEAD','CANCELLED') OR code !~ '^[A-Z0-9_]{1,64}$' OR length(coalesce(receipt,''))>160 THEN PERFORM ms_b1_design.b3_fail('INVALID_DELIVERY_STATE');END IF;
 UPDATE ms_b1_design.product_delivery j SET state=CASE WHEN p_state='READY' AND j.attempts>=12 THEN 'DEAD' ELSE p_state END,last_code=code,provider_receipt=receipt,
 available_at=CASE WHEN p_state='READY' THEN clock_timestamp()+make_interval(secs=>least(3600,5*(2^least(j.attempts,9))::int)) ELSE j.available_at END,
 lease_token=CASE WHEN p_state='DISPATCHED' THEN t ELSE NULL END,lease_until=CASE WHEN p_state='DISPATCHED' THEN j.lease_until ELSE NULL END,updated_at=clock_timestamp()
 WHERE j.id=product_delivery_state.id AND j.lease_token=t AND j.lease_until>clock_timestamp() AND j.state IN('LEASED','DISPATCHED');RETURN FOUND;
END $$;
CREATE FUNCTION ms_b1_design.product_sms_context(id uuid,t uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE j ms_b1_design.product_delivery;e ms_b1_design.outbox_event;c ms_b1_design.product_auth_challenge;b ms_b1_design.booking;phone ms_b1_design.customer_contact;template ms_b1_design.product_notification_template;k text;bookingid uuid;revisionid uuid;BEGIN
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
 IF b.id IS NULL OR(k IN('CONFIRM','REMINDER','RESCHEDULE') AND b.status<>'CONFIRMED') OR(k='CANCEL' AND b.status<>'CANCELLED') OR(revisionid IS NOT NULL AND b.active_revision_id<>revisionid) OR(e.aggregate_type='booking' AND e.aggregate_version<>b.row_version) THEN RETURN jsonb_build_object('code','STALE');END IF;
 SELECT * INTO phone FROM ms_b1_design.customer_contact WHERE user_id=b.created_by AND notifications_opt_in;
 IF NOT FOUND THEN RETURN jsonb_build_object('code','OPTED_OUT');END IF;
 SELECT * INTO template FROM ms_b1_design.product_notification_template WHERE business_id=j.business_id AND kind=k ORDER BY version DESC LIMIT 1;
 IF template.business_id IS NULL OR NOT template.enabled THEN RETURN jsonb_build_object('code','TEMPLATE_UNCONFIGURED');END IF;
 RETURN jsonb_build_object('kind',k,'mobileCiphertext',phone.mobile_ciphertext,'mobileLookup',encode(phone.mobile_lookup,'hex'),'templateVersion',template.version,'body',template.body,
 'variables',jsonb_build_object('booking',b.id::text,'status',b.status,'date',coalesce((SELECT to_char(min(starts_at) AT TIME ZONE br.time_zone,'YYYY-MM-DD HH24:MI') FROM ms_b1_design.booking_service_segment s JOIN ms_b1_design.branch br ON br.id=b.branch_id WHERE s.revision_id=b.active_revision_id),'')));
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.product_enqueue(uuid,text,text,jsonb,timestamptz),ms_b1_design.product_collect(),ms_b1_design.product_claim(boolean),ms_b1_design.product_delivery_state(uuid,uuid,text,text,text),ms_b1_design.product_sms_context(uuid,uuid) FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_collect(),ms_b1_design.product_claim(boolean),ms_b1_design.product_delivery_state(uuid,uuid,text,text,text),ms_b1_design.product_sms_context(uuid,uuid) TO ms_product_worker;
