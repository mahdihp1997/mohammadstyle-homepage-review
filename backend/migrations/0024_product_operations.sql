SET search_path=ms_b1_design,public;
CREATE TABLE product_booking_operation (
 booking_id uuid PRIMARY KEY,business_id uuid NOT NULL,state text NOT NULL CHECK(state IN('ARRIVED','IN_SERVICE','COMPLETED','NO_SHOW')),
 row_version bigint NOT NULL DEFAULT 1,updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),updated_by uuid NOT NULL REFERENCES app_user(id),
 FOREIGN KEY(business_id,booking_id) REFERENCES booking(business_id,id)
);
CREATE TABLE product_operation_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,booking_id uuid NOT NULL,from_state text,to_state text NOT NULL,
 actor_user_id uuid NOT NULL REFERENCES app_user(id),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(business_id,booking_id) REFERENCES booking(business_id,id)
);
CREATE INDEX product_operation_parent ON product_operation_history(business_id,booking_id,created_at,id);
CREATE TRIGGER product_operation_history_immutable BEFORE UPDATE OR DELETE ON product_operation_history FOR EACH ROW EXECUTE FUNCTION b3_freeze();
REVOKE ALL ON product_booking_operation,product_operation_history FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker;
SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.product_operation_guard() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF (NEW.status='CANCELLED' OR NEW.active_revision_id IS DISTINCT FROM OLD.active_revision_id) AND EXISTS(SELECT 1 FROM ms_b1_design.product_booking_operation WHERE booking_id=NEW.id) THEN PERFORM ms_b1_design.b3_fail('OPERATIONS_REVIEW_REQUIRED','MS409');END IF;RETURN NEW;END $$;
CREATE TRIGGER product_operation_guard BEFORE UPDATE ON ms_b1_design.booking FOR EACH ROW EXECUTE FUNCTION ms_b1_design.product_operation_guard();
CREATE FUNCTION ms_b1_design.product_public_catalog() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE bid uuid;BEGIN
 SELECT business_id INTO STRICT bid FROM ms_b1_design.product_runtime WHERE singleton;
 RETURN jsonb_build_object('source','SERVER','isolated',EXISTS(SELECT 1 FROM ms_b1_design.product_runtime WHERE singleton AND environment='test'),
 'branches',coalesce((SELECT jsonb_agg(jsonb_build_object('id',b.id,'name',b.display_name,'timeZone',b.time_zone,'configured',b.bookable,'version',b.row_version::text,'today',(clock_timestamp() AT TIME ZONE b.time_zone)::date::text,'horizonDays',coalesce((SELECT c.horizon_days FROM ms_b1_design.availability_configuration c WHERE c.business_id=bid AND c.branch_id=b.id AND c.enabled AND c.archived_at IS NULL),0)) ORDER BY b.code) FROM ms_b1_design.branch b WHERE b.business_id=bid AND b.active AND b.archived_at IS NULL),'[]'::jsonb),
 'offerings',coalesce((SELECT jsonb_agg(jsonb_build_object('id',o.id,'branchId',o.branch_id,'serviceId',o.service_id,'name',s.display_name,'priceRial',o.price_rial::text,'durationMinutes',o.duration_minutes::text,'version',o.row_version::text) ORDER BY s.code) FROM ms_b1_design.branch_service_offering o JOIN ms_b1_design.service s ON s.business_id=o.business_id AND s.id=o.service_id WHERE o.business_id=bid AND o.active AND o.archived_at IS NULL AND s.active AND s.archived_at IS NULL),'[]'::jsonb),
 'staff',coalesce((SELECT jsonb_agg(jsonb_build_object('id',s.id,'name',s.display_name,'offeringIds',coalesce((SELECT jsonb_agg(DISTINCT e.offering_id ORDER BY e.offering_id) FROM ms_b1_design.offering_staff_eligibility e WHERE e.business_id=bid AND e.staff_id=s.id AND e.active AND e.archived_at IS NULL),'[]'::jsonb)) ORDER BY s.id) FROM ms_b1_design.staff s WHERE s.business_id=bid AND s.active AND s.archived_at IS NULL),'[]'::jsonb));
END $$;
CREATE FUNCTION ms_b1_design.product_admin_read(h bytea,kind text,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;bid uuid;branchid uuid;uid uuid;term text;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);bid:=(a->>'businessId')::uuid;
 PERFORM ms_b1_design.b3_keys(d,ARRAY['branchId','customerId','query','offset']);branchid:=(d->>'branchId')::uuid;uid:=(d->>'customerId')::uuid;term:=d->>'query';
 IF length(term)>100 OR(d->>'offset') !~ '^\d{1,5}$' OR(d->>'offset')::int>10000 THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 IF kind IN('bookings','customers') THEN
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(a->'assignments') x WHERE x->>'permission'=CASE WHEN kind='customers' THEN 'customer.read' ELSE 'booking.read' END) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(x.document ORDER BY x.created_at DESC,x.id) FROM(
 SELECT b.created_at,b.id,ms_b1_design.b4_view(b)||jsonb_build_object('customer',jsonb_build_object('id',u.id,'name',u.display_name,'mobileLastFour',c.mobile_last_four,'verifiedAt',ms_b1_design.b3_iso(c.verified_at)),
 'operation',coalesce((SELECT jsonb_build_object('state',o.state,'version',o.row_version::text,'at',ms_b1_design.b3_iso(o.updated_at)) FROM ms_b1_design.product_booking_operation o WHERE o.booking_id=b.id),jsonb_build_object('state','PLANNED','version','0')),
 'payments',CASE WHEN ms_b1_design.b1b_can(a,'payment.read',b.branch_id) THEN coalesce((SELECT jsonb_agg(ms_b1_design.product_payment_view(p)) FROM ms_b1_design.product_payment_intent p WHERE p.booking_id=b.id),'[]'::jsonb) ELSE '[]'::jsonb END,
 'history',coalesce((SELECT jsonb_agg(jsonb_build_object('event',e.event_type,'from',e.from_status,'to',e.to_status,'at',ms_b1_design.b3_iso(e.created_at)) ORDER BY e.created_at,e.id) FROM ms_b1_design.booking_status_history e WHERE e.booking_id=b.id),'[]'::jsonb)) document
 FROM ms_b1_design.booking b JOIN ms_b1_design.app_user u ON u.id=b.created_by LEFT JOIN ms_b1_design.customer_contact c ON c.user_id=u.id
 WHERE b.business_id=bid AND(branchid IS NULL OR b.branch_id=branchid) AND(uid IS NULL OR b.created_by=uid) AND ms_b1_design.b1b_can(a,CASE WHEN kind='customers' THEN 'customer.read' ELSE 'booking.read' END,b.branch_id)
 AND(term='' OR position(lower(term) IN lower(u.display_name))>0 OR b.id::text=term OR c.mobile_last_four=term OR b.status=upper(term)) ORDER BY b.created_at DESC,b.id LIMIT 25 OFFSET(d->>'offset')::int) x),'[]'::jsonb));
 ELSIF kind='notifications' THEN
 IF NOT ms_b1_design.b1b_can(a,'notification.read',NULL) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT id,kind,state,attempts,last_code,provider_receipt,ms_b1_design.b3_iso(updated_at) "updatedAt" FROM ms_b1_design.product_delivery WHERE business_id=bid ORDER BY updated_at DESC,id LIMIT 50 OFFSET(d->>'offset')::int)x),'[]'::jsonb),
 'templates',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT DISTINCT ON(kind) kind,version,body,enabled FROM ms_b1_design.product_notification_template WHERE business_id=bid ORDER BY kind,version DESC)x),'[]'::jsonb));
 ELSIF kind='settings' THEN
 IF NOT ms_b1_design.b1b_can(a,'operations.manage',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 RETURN coalesce((SELECT jsonb_build_object('branchId',branch_id,'reminderMinutes',reminder_minutes,'noShowGraceMinutes',no_show_grace_minutes,'version',row_version::text) FROM ms_b1_design.product_operational_settings WHERE business_id=bid AND branch_id=branchid),jsonb_build_object('branchId',branchid,'reminderMinutes',NULL,'noShowGraceMinutes',NULL,'version','0'));
 ELSE PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;RETURN NULL;
END $$;
CREATE FUNCTION ms_b1_design.product_admin_command(h bytea,csrf bytea,op text,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
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
 IF NOT ms_b1_design.b1b_can(a,'operations.manage',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
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
CREATE FUNCTION ms_b1_design.product_refund_context(jobid uuid,t uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE j ms_b1_design.product_delivery;r ms_b1_design.product_refund_case;p ms_b1_design.product_payment_intent;BEGIN
 SELECT * INTO j FROM ms_b1_design.product_delivery WHERE id=jobid AND lease_token=t AND lease_until>clock_timestamp() AND state='LEASED' AND kind='REFUND';IF NOT FOUND THEN RETURN NULL;END IF;
 SELECT * INTO r FROM ms_b1_design.product_refund_case WHERE id=(j.payload->>'caseId')::uuid;SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE id=r.intent_id;
 IF r.state NOT IN('REQUESTED','UNKNOWN') THEN RETURN NULL;END IF;RETURN jsonb_build_object('id',r.id,'provider',p.provider,'authority',p.authority,'amountRial',r.requested_rial::text);
END $$;
CREATE FUNCTION ms_b1_design.product_refund_result(jobid uuid,t uuid,p_state text,reference text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE j ms_b1_design.product_delivery;r ms_b1_design.product_refund_case;p ms_b1_design.product_payment_intent;BEGIN
 SELECT * INTO j FROM ms_b1_design.product_delivery WHERE id=jobid;IF NOT FOUND THEN RETURN false;END IF;PERFORM ms_b1_design.b4_lock(j.business_id);
 SELECT * INTO j FROM ms_b1_design.product_delivery WHERE id=jobid AND lease_token=t AND lease_until>clock_timestamp() AND state='DISPATCHED' AND kind='REFUND' FOR UPDATE;IF NOT FOUND THEN RETURN false;END IF;
 SELECT * INTO r FROM ms_b1_design.product_refund_case WHERE id=(j.payload->>'caseId')::uuid FOR UPDATE;SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE id=r.intent_id;
 IF r.state='VERIFIED' THEN RETURN true;END IF;
 IF p_state='verified' AND reference ~ '^mock_refund_[a-f0-9]{32}$' AND p.provider='mock' AND EXISTS(SELECT 1 FROM ms_b1_design.product_runtime WHERE singleton AND environment='test') THEN
 UPDATE ms_b1_design.product_refund_case SET state='VERIFIED',provider_reference=reference,verified_at=clock_timestamp() WHERE id=r.id;PERFORM ms_b1_design.product_delivery_state(jobid,t,'DELIVERED','REFUND_VERIFIED',reference);
 ELSE UPDATE ms_b1_design.product_refund_case SET state=CASE WHEN p_state='declined' THEN 'DECLINED' ELSE 'UNKNOWN' END WHERE id=r.id;PERFORM ms_b1_design.product_delivery_state(jobid,t,CASE WHEN p_state='unsupported' THEN 'BLOCKED' WHEN p_state='declined' THEN 'DELIVERED' ELSE 'UNKNOWN' END,'REFUND_REVIEW_REQUIRED',NULL);END IF;
 PERFORM ms_b1_design.product_money_event(p,'product.refund.'||CASE WHEN p_state='verified' THEN 'verified' ELSE 'review' END,jsonb_build_object('caseId',r.id,'amountRial',r.requested_rial::text));RETURN true;
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.product_operation_guard(),ms_b1_design.product_public_catalog(),ms_b1_design.product_admin_read(bytea,text,jsonb),ms_b1_design.product_admin_command(bytea,bytea,text,jsonb),ms_b1_design.product_refund_context(uuid,uuid),ms_b1_design.product_refund_result(uuid,uuid,text,text) FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_public_catalog(),ms_b1_design.product_admin_read(bytea,text,jsonb),ms_b1_design.product_admin_command(bytea,bytea,text,jsonb) TO ms_b1b_api;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_refund_context(uuid,uuid),ms_b1_design.product_refund_result(uuid,uuid,text,text) TO ms_product_worker;
