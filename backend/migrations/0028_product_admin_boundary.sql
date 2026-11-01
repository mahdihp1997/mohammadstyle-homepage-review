-- Actor is a compact identity; session projection provides explicit scoped permission assignments.
CREATE OR REPLACE FUNCTION ms_b1_design.product_admin_read(h bytea,kind text,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;bid uuid;branchid uuid;uid uuid;term text;BEGIN
 a:=ms_b1_design.b1b_session(h);bid:=(a->>'businessId')::uuid;
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
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT z.id,z.kind,z.state,z.attempts,z.last_code,z.provider_receipt,ms_b1_design.b3_iso(z.updated_at) "updatedAt" FROM ms_b1_design.product_delivery z WHERE z.business_id=bid ORDER BY z.updated_at DESC,z.id LIMIT 50 OFFSET(d->>'offset')::int)x),'[]'::jsonb),
 'templates',coalesce((SELECT jsonb_agg(to_jsonb(x)) FROM(SELECT DISTINCT ON(z.kind) z.kind,z.version,z.body,z.enabled FROM ms_b1_design.product_notification_template z WHERE z.business_id=bid ORDER BY z.kind,z.version DESC)x),'[]'::jsonb));
 ELSIF kind='settings' THEN
 IF NOT ms_b1_design.b1b_can(a,'operations.manage',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 RETURN coalesce((SELECT jsonb_build_object('branchId',branch_id,'reminderMinutes',reminder_minutes,'noShowGraceMinutes',no_show_grace_minutes,'version',row_version::text) FROM ms_b1_design.product_operational_settings WHERE business_id=bid AND branch_id=branchid),jsonb_build_object('branchId',branchid,'reminderMinutes',NULL,'noShowGraceMinutes',NULL,'version','0'));
 ELSE PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;RETURN NULL;
END $$;

ALTER TABLE ms_b1_design.product_refund_case ADD CONSTRAINT product_requested_refund_amount CHECK(state NOT IN('REQUESTED','UNKNOWN','VERIFIED') OR requested_rial IS NOT NULL);
CREATE UNIQUE INDEX product_refund_provider_receipt ON ms_b1_design.product_refund_case(provider_reference) WHERE provider_reference IS NOT NULL;
