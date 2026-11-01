-- Scoped configuration, semantic financial dedupe, explicit realm and readiness.
SET search_path=pg_catalog;
CREATE OR REPLACE FUNCTION ms_b1_design.product_admin_command(h bytea,csrf bytea,op text,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;b ms_b1_design.booking;previous ms_b1_design.product_booking_operation;r ms_b1_design.product_refund_case;p ms_b1_design.product_payment_intent;branchid uuid;grace integer;start_at timestamptz;version bigint;target uuid;result jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);
 IF op='operation' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['bookingId','version','state']);SELECT * INTO b FROM ms_b1_design.booking WHERE business_id=bid AND id=(d->>'bookingId')::uuid FOR UPDATE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;branchid:=b.branch_id;target:=b.id;
 IF NOT ms_b1_design.b1b_can(a,'operations.manage',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 SELECT * INTO previous FROM ms_b1_design.product_booking_operation WHERE booking_id=b.id FOR UPDATE;
 IF coalesce(previous.row_version,0)::text IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF b.status<>'CONFIRMED' OR NOT((previous.booking_id IS NULL AND d->>'state' IN('ARRIVED','NO_SHOW')) OR(previous.state='ARRIVED' AND d->>'state'='IN_SERVICE') OR(previous.state='IN_SERVICE' AND d->>'state'='COMPLETED')) THEN PERFORM ms_b1_design.b3_fail('INVALID_OPERATION_TRANSITION','MS409');END IF;
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
CREATE OR REPLACE FUNCTION ms_b1_design.product_money_event(p ms_b1_design.product_payment_intent,kind text,details jsonb) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF EXISTS(SELECT 1 FROM ms_b1_design.product_financial_event e WHERE e.intent_id=p.id AND e.event_type=kind AND e.evidence=details) THEN RETURN;END IF;
 INSERT INTO ms_b1_design.product_financial_event(business_id,intent_id,event_type,evidence) VALUES(p.business_id,p.id,kind,details);
 INSERT INTO ms_b1_design.audit_log(business_id,branch_id,action,target_type,target_id,request_id,redacted_change)
 SELECT p.business_id,b.branch_id,kind,'payment_intent',p.id,gen_random_uuid(),details FROM ms_b1_design.booking b WHERE b.id=p.booking_id;
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at)
 VALUES(p.business_id,'payment.event',gen_random_uuid(),1,kind,1,jsonb_build_object('intentId',p.id,'bookingId',p.booking_id,'state',p.state),clock_timestamp());
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.b1b_actor(h bytea,csrf bytea DEFAULT NULL,mutation boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE a jsonb;s ms_b1_design.auth_session;cfg ms_b1_design.product_runtime;v integer;admin boolean;required boolean;BEGIN
 a:=ms_b1_design.product_legacy_actor(h,csrf,mutation);
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 SELECT * INTO s FROM ms_b1_design.auth_session WHERE token_hash=h;
 IF s.business_id IS DISTINCT FROM cfg.business_id OR s.product_environment IS DISTINCT FROM cfg.environment OR s.assurance IS NULL THEN PERFORM ms_b1_design.b3_fail('UNAUTHENTICATED','MS401');END IF;
 SELECT coalesce(c.credential_version,p.identity_version) INTO v FROM ms_b1_design.customer_contact p
 LEFT JOIN ms_b1_design.product_admin_credential c ON c.user_id=p.user_id
 WHERE p.user_id=s.user_id AND EXISTS(SELECT 1 FROM ms_b1_design.auth_identity i WHERE i.user_id=p.user_id AND i.provider='IRAN_MOBILE' AND i.subject_hash=p.mobile_lookup AND i.verified_at IS NOT NULL);
 IF v IS NULL OR v IS DISTINCT FROM s.credential_version THEN PERFORM ms_b1_design.b3_fail('UNAUTHENTICATED','MS401');END IF;
 SELECT coalesce(bool_or(p.permission_key<>'booking.customer'),false),coalesce(bool_or(r.product_mfa_required OR r.role_key='OWNER') FILTER(WHERE p.permission_key<>'booking.customer'),false)
 INTO admin,required FROM ms_b1_design.user_role_assignment x JOIN ms_b1_design.role r ON r.business_id=x.business_id AND r.id=x.role_id
 JOIN ms_b1_design.role_permission rp ON rp.business_id=r.business_id AND rp.role_id=r.id JOIN ms_b1_design.permission p ON p.id=rp.permission_id
 WHERE x.user_id=s.user_id AND x.business_id=s.business_id AND x.revoked_at IS NULL AND x.archived_at IS NULL AND r.archived_at IS NULL AND rp.archived_at IS NULL AND p.archived_at IS NULL;
 IF admin AND(NOT EXISTS(SELECT 1 FROM ms_b1_design.product_admin_credential c WHERE c.user_id=s.user_id)
 OR s.assurance NOT IN('PASSWORD','MFA') OR(required AND(s.assurance<>'MFA' OR s.mfa_at IS NULL))) THEN PERFORM ms_b1_design.b3_fail('MFA_REQUIRED','MS403');END IF;
 UPDATE ms_b1_design.auth_session SET idle_expires_at=least(expires_at,clock_timestamp()+make_interval(secs=>cfg.idle_seconds)) WHERE id=s.id;
 RETURN a;
END $$;

CREATE OR REPLACE FUNCTION ms_b1_design.product_worker_runtime() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('businessId',business_id,'environment',environment,'origin',public_origin,'payment',payment_provider,'sms',sms_provider,
 'marker',shobj_description((SELECT oid FROM pg_database WHERE datname=current_database()),'pg_database'),'postgres',current_setting('server_version_num')::int,
 'schemaHead',(SELECT id FROM ms_b1_meta.schema_migration ORDER BY id DESC LIMIT 1),'schemaChecksum',(SELECT checksum FROM ms_b1_meta.schema_migration ORDER BY id DESC LIMIT 1),
 'testData',(SELECT count(*) FROM ms_b1_design.customer_contact WHERE test_only)+(SELECT count(*) FROM ms_b1_design.product_admin_credential WHERE test_only)+(SELECT count(*) FROM ms_b1_design.product_payment_receipt WHERE test_only)+(SELECT count(*) FROM ms_b1_design.auth_identity WHERE provider='B4_ISOLATED_TEST'),
 'workerLastSuccess',(SELECT ms_b1_design.b3_iso(last_success_at) FROM ms_b1_design.product_worker_health WHERE singleton)) FROM ms_b1_design.product_runtime WHERE singleton $$;
CREATE FUNCTION ms_b1_design.product_customer_contact(h bytea,c bytea,userid uuid,branchid uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h,c,true);
 IF NOT ms_b1_design.b1b_can(a,'customer.contact.read',branchid) OR NOT EXISTS(SELECT 1 FROM ms_b1_design.booking b WHERE b.business_id=(a->>'businessId')::uuid AND b.branch_id=branchid AND b.created_by=userid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,branch_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES((a->>'businessId')::uuid,(a->>'userId')::uuid,branchid,'customer.contact.viewed','user',userid,gen_random_uuid(),'{}',(a->>'userId')::uuid);
 RETURN(SELECT jsonb_build_object('ciphertext',mobile_ciphertext,'lookup',encode(mobile_lookup,'hex')) FROM ms_b1_design.customer_contact WHERE user_id=userid);
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.product_customer_contact(bytea,bytea,uuid,uuid) FROM PUBLIC,ms_product_worker,ms_product_auth;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_customer_contact(bytea,bytea,uuid,uuid) TO ms_b1b_api;
