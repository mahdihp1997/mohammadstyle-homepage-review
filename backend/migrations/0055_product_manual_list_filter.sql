-- Avoid PL/pgSQL variable/column ambiguity in the shared review workspace.
SET search_path=pg_catalog;
CREATE OR REPLACE FUNCTION ms_b1_design.manual_payments_read(h bytea,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;branchid uuid;fromdate date;todate date;term text;filter_state text;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);bid:=(a->>'businessId')::uuid;PERFORM ms_b1_design.b3_keys(d,ARRAY['branchId','from','to','state','query','offset']);branchid:=(d->>'branchId')::uuid;
 IF branchid IS NOT NULL AND NOT ms_b1_design.b1b_can(a,'payment.manual.read',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF branchid IS NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND ms_b1_design.b1b_can(a,'payment.manual.read',b.id)) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF(d->>'from') IS NULL OR(d->>'from') !~ '^\d{4}-\d{2}-\d{2}$' OR(d->>'to') IS NULL OR(d->>'to') !~ '^\d{4}-\d{2}-\d{2}$' OR(d->>'offset') IS NULL OR(d->>'offset') !~ '^\d{1,5}$' OR(d->>'query') IS NULL OR length(d->>'query')>100 OR(d->>'offset')::int>10000 THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 fromdate:=(d->>'from')::date;todate:=(d->>'to')::date;term:=d->>'query';filter_state:=d->>'state';
 IF fromdate>todate OR todate-fromdate>366 OR filter_state IS NULL OR filter_state NOT IN('','AWAITING_TRANSFER','UNDER_REVIEW','REJECTED','REVIEW_REQUIRED','VERIFIED') THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(x.document ORDER BY x.created_at DESC,x.id) FROM(
 SELECT p.id,p.created_at,ms_b1_design.product_payment_view(p)||jsonb_build_object('targetKind',CASE WHEN o.id IS NOT NULL THEN 'ORDER' ELSE 'BOOKING' END,'orderId',o.id,'orderNumber',o.number,'targetStatus',coalesce(o.status,b.status),'bookingStatus',b.status,'branchId',br.id,'branchName',br.display_name,
 'customer',jsonb_build_object('id',u.id,'name',u.display_name,'mobileLastFour',c.mobile_last_four)) document
 FROM ms_b1_design.product_payment_intent p LEFT JOIN ms_b1_design.booking b ON b.business_id=p.business_id AND b.id=p.booking_id LEFT JOIN ms_b1_design.shop_order o ON o.business_id=p.business_id AND o.id=p.order_id
 JOIN ms_b1_design.branch br ON br.id=coalesce(o.branch_id,b.branch_id) JOIN ms_b1_design.app_user u ON u.id=coalesce(o.customer_id,b.created_by) LEFT JOIN ms_b1_design.customer_contact c ON c.user_id=u.id
 WHERE p.business_id=bid AND p.provider='manual_card_transfer' AND(branchid IS NULL OR br.id=branchid) AND ms_b1_design.b1b_can(a,'payment.manual.read',br.id)
 AND(filter_state='' OR p.state=filter_state) AND(p.created_at AT TIME ZONE br.time_zone)::date BETWEEN fromdate AND todate
 AND(term='' OR coalesce(b.id,o.id)::text=term OR o.number=term OR p.id::text=term OR position(lower(term) IN lower(u.display_name))>0 OR c.mobile_last_four=term)
 ORDER BY p.created_at DESC,p.id LIMIT 25 OFFSET(d->>'offset')::int)x),'[]'::jsonb));
END $$;
