-- Additive manual settlement evidence. Historical migrations/hashes stay immutable.
SET search_path=ms_b1_design,public;

CREATE TABLE product_bank_card (
 id uuid PRIMARY KEY, business_id uuid NOT NULL REFERENCES business(id),
 bank_name text NOT NULL CHECK(length(bank_name) BETWEEN 1 AND 100),
 details_ciphertext text NOT NULL CHECK(length(details_ciphertext) BETWEEN 50 AND 4000),
 card_fingerprint bytea NOT NULL CHECK(octet_length(card_fingerprint)=32),
 last_four text NOT NULL CHECK(last_four ~ '^\d{4}$'),
 scope_kind text NOT NULL CHECK(scope_kind IN('BUSINESS','BRANCHES')),
 priority integer NOT NULL DEFAULT 100 CHECK(priority BETWEEN 0 AND 10000),
 active boolean NOT NULL DEFAULT true, archived_at timestamptz,
 row_version bigint NOT NULL DEFAULT 1 CHECK(row_version>0),
 created_by uuid NOT NULL REFERENCES app_user(id), updated_by uuid NOT NULL REFERENCES app_user(id),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,id)
);
CREATE UNIQUE INDEX product_card_current_identity ON product_bank_card(business_id,card_fingerprint) WHERE archived_at IS NULL;
CREATE TABLE product_bank_card_branch (
 business_id uuid NOT NULL,card_id uuid NOT NULL,branch_id uuid NOT NULL,
 PRIMARY KEY(business_id,card_id,branch_id),
 FOREIGN KEY(business_id,card_id) REFERENCES product_bank_card(business_id,id),
 FOREIGN KEY(business_id,branch_id) REFERENCES branch(business_id,id)
);
CREATE INDEX product_card_branch_selection ON product_bank_card_branch(business_id,branch_id,card_id);

CREATE TABLE product_payment_configuration (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL REFERENCES business(id),branch_id uuid,
 online_enabled boolean NOT NULL DEFAULT false,manual_enabled boolean NOT NULL DEFAULT false,
 default_card_id uuid,receipt_retention_days integer CHECK(receipt_retention_days BETWEEN 1 AND 36500),
 max_receipt_submissions integer NOT NULL DEFAULT 3 CHECK(max_receipt_submissions BETWEEN 1 AND 10),
 row_version bigint NOT NULL DEFAULT 1 CHECK(row_version>0),updated_by uuid NOT NULL REFERENCES app_user(id),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE NULLS NOT DISTINCT(business_id,branch_id),
 FOREIGN KEY(business_id,branch_id) REFERENCES branch(business_id,id),
 FOREIGN KEY(business_id,default_card_id) REFERENCES product_bank_card(business_id,id)
);

ALTER TABLE product_payment_intent DROP CONSTRAINT product_payment_intent_provider_check;
ALTER TABLE product_payment_intent ADD CONSTRAINT product_payment_intent_provider_check CHECK(provider IN('mock','manual_card_transfer'));
ALTER TABLE product_payment_intent DROP CONSTRAINT product_payment_intent_state_check;
ALTER TABLE product_payment_intent ADD CONSTRAINT product_payment_intent_state_check CHECK(state IN('REQUESTED','REDIRECT_READY','VERIFYING','VERIFIED','DECLINED','UNKNOWN','CLOSED','AWAITING_TRANSFER','UNDER_REVIEW','REJECTED','REVIEW_REQUIRED'));
ALTER TABLE product_payment_intent ALTER COLUMN callback_hash DROP NOT NULL;
ALTER TABLE product_payment_intent ALTER COLUMN callback_ciphertext DROP NOT NULL;
ALTER TABLE product_payment_intent ADD CONSTRAINT product_payment_callback_method CHECK(
 (provider='manual_card_transfer' AND callback_hash IS NULL AND callback_ciphertext IS NULL AND authority IS NULL AND hosted_url IS NULL)
 OR(provider<>'manual_card_transfer' AND callback_hash IS NOT NULL AND callback_ciphertext IS NOT NULL));

CREATE TABLE product_manual_transfer (
 intent_id uuid PRIMARY KEY,business_id uuid NOT NULL,card_id uuid NOT NULL,card_version bigint NOT NULL,
 destination_ciphertext text NOT NULL,card_fingerprint bytea NOT NULL CHECK(octet_length(card_fingerprint)=32),
 bank_name text NOT NULL,last_four text NOT NULL CHECK(last_four ~ '^\d{4}$'),
 max_submissions integer NOT NULL CHECK(max_submissions BETWEEN 1 AND 10),
 retention_days integer CHECK(retention_days BETWEEN 1 AND 36500),
 row_version bigint NOT NULL DEFAULT 1 CHECK(row_version>0),
 UNIQUE(business_id,intent_id),
 FOREIGN KEY(business_id,intent_id) REFERENCES product_payment_intent(business_id,id),
 FOREIGN KEY(business_id,card_id) REFERENCES product_bank_card(business_id,id)
);
CREATE TABLE product_manual_receipt (
 id uuid PRIMARY KEY,business_id uuid NOT NULL,intent_id uuid NOT NULL,submission integer NOT NULL CHECK(submission BETWEEN 1 AND 10),
 submitted_by uuid NOT NULL REFERENCES app_user(id),sender_reference_ciphertext text,
 original_key text NOT NULL UNIQUE,original_sha256 bytea NOT NULL CHECK(octet_length(original_sha256)=32),
 original_object_sha256 text NOT NULL CHECK(original_object_sha256 ~ '^[a-f0-9]{64}$'),original_object_bytes bigint NOT NULL CHECK(original_object_bytes>0),
 display_key text NOT NULL UNIQUE,display_sha256 bytea NOT NULL CHECK(octet_length(display_sha256)=32),
 display_object_sha256 text NOT NULL CHECK(display_object_sha256 ~ '^[a-f0-9]{64}$'),display_object_bytes bigint NOT NULL CHECK(display_object_bytes>0),
 mime text NOT NULL CHECK(mime IN('image/jpeg','image/png','image/webp')),
 source_bytes integer NOT NULL CHECK(source_bytes BETWEEN 1 AND 5242880),
 width integer NOT NULL CHECK(width BETWEEN 1 AND 12000),height integer NOT NULL CHECK(height BETWEEN 1 AND 12000),
 retention_eligible_at timestamptz,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,id),UNIQUE(business_id,id,intent_id),UNIQUE(intent_id,submission),UNIQUE(business_id,original_sha256),
 FOREIGN KEY(business_id,intent_id) REFERENCES product_manual_transfer(business_id,intent_id)
);
CREATE TABLE product_manual_review (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,intent_id uuid NOT NULL,receipt_id uuid NOT NULL UNIQUE,
 decision text NOT NULL CHECK(decision IN('REJECTED','BANK_RECONCILED')),
 reason text NOT NULL CHECK(length(reason)<=300),reviewed_by uuid NOT NULL REFERENCES app_user(id),
 reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(decision<>'REJECTED' OR length(trim(reason))>=3),
 UNIQUE(business_id,id,intent_id),
 FOREIGN KEY(business_id,receipt_id,intent_id) REFERENCES product_manual_receipt(business_id,id,intent_id)
);
CREATE TABLE product_manual_reconciliation (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL,intent_id uuid NOT NULL UNIQUE,review_id uuid NOT NULL UNIQUE,
 card_fingerprint bytea NOT NULL CHECK(octet_length(card_fingerprint)=32),bank_reference_hash bytea NOT NULL CHECK(octet_length(bank_reference_hash)=32),
 evidence_ciphertext text NOT NULL CHECK(length(evidence_ciphertext) BETWEEN 50 AND 8000),
 received_amount_rial bigint NOT NULL CHECK(received_amount_rial>0),received_at timestamptz NOT NULL CHECK(isfinite(received_at)),
 bank_statement_attested boolean NOT NULL CHECK(bank_statement_attested),
 evidence_type text NOT NULL DEFAULT 'MANUAL_BANK_RECONCILED' CHECK(evidence_type='MANUAL_BANK_RECONCILED'),
 outcome text NOT NULL CHECK(outcome IN('CONFIRMED','LATE_PAYMENT','AMOUNT_MISMATCH','BOOKING_CLOSED','ALLOCATION_REVIEW')),
 reviewed_by uuid NOT NULL REFERENCES app_user(id),review_session_id uuid NOT NULL REFERENCES auth_session(id),
 reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,intent_id,id),UNIQUE(business_id,card_fingerprint,bank_reference_hash),
 FOREIGN KEY(business_id,intent_id) REFERENCES product_manual_transfer(business_id,intent_id),
 FOREIGN KEY(business_id,review_id,intent_id) REFERENCES product_manual_review(business_id,id,intent_id)
);
ALTER TABLE product_payment_receipt ADD COLUMN evidence_type text NOT NULL DEFAULT 'PROVIDER_VERIFIED' CHECK(evidence_type IN('PROVIDER_VERIFIED','MANUAL_BANK_RECONCILED'));
ALTER TABLE product_payment_receipt ADD COLUMN manual_reconciliation_id uuid;
ALTER TABLE product_payment_receipt ADD CONSTRAINT product_receipt_source CHECK(
 (evidence_type='PROVIDER_VERIFIED' AND provider<>'manual_card_transfer' AND manual_reconciliation_id IS NULL)
 OR(evidence_type='MANUAL_BANK_RECONCILED' AND provider='manual_card_transfer' AND manual_reconciliation_id IS NOT NULL));
ALTER TABLE product_payment_receipt ADD FOREIGN KEY(business_id,intent_id,manual_reconciliation_id) REFERENCES product_manual_reconciliation(business_id,intent_id,id);

CREATE TABLE product_manual_request (
 business_id uuid NOT NULL,actor_id uuid NOT NULL REFERENCES app_user(id),operation text NOT NULL,idempotency_key uuid NOT NULL,
 signature bytea NOT NULL CHECK(octet_length(signature)=32),response jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),PRIMARY KEY(business_id,actor_id,operation,idempotency_key)
);
CREATE TABLE product_receipt_retention (
 receipt_id uuid PRIMARY KEY,business_id uuid NOT NULL,state text NOT NULL DEFAULT 'REQUESTED' CHECK(state IN('REQUESTED','PURGED')),
 backup_manifest_sha256 text NOT NULL CHECK(backup_manifest_sha256 ~ '^[a-f0-9]{64}$'),
 requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),purged_at timestamptz,
 CHECK((state='PURGED')=(purged_at IS NOT NULL)),
 FOREIGN KEY(business_id,receipt_id) REFERENCES product_manual_receipt(business_id,id)
);

CREATE TRIGGER product_manual_receipt_immutable BEFORE UPDATE OR DELETE ON product_manual_receipt FOR EACH ROW EXECUTE FUNCTION b3_freeze();
CREATE TRIGGER product_manual_review_immutable BEFORE UPDATE OR DELETE ON product_manual_review FOR EACH ROW EXECUTE FUNCTION b3_freeze();
CREATE TRIGGER product_manual_reconciliation_immutable BEFORE UPDATE OR DELETE ON product_manual_reconciliation FOR EACH ROW EXECUTE FUNCTION b3_freeze();
CREATE TRIGGER product_manual_request_immutable BEFORE UPDATE OR DELETE ON product_manual_request FOR EACH ROW EXECUTE FUNCTION b3_freeze();

INSERT INTO permission(permission_key,description) VALUES
 ('payment.settings.read','Read authorized payment configuration and masked bank cards'),
 ('payment.settings.manage','Manage authorized payment methods and destination cards with MFA'),
 ('payment.manual.read','Read scoped manual payments and private receipt evidence'),
 ('payment.manual.review','Independently reconcile bank money with MFA') ON CONFLICT(permission_key) DO NOTHING;
INSERT INTO role_permission(business_id,role_id,permission_id)
 SELECT r.business_id,r.id,p.id FROM role r CROSS JOIN permission p WHERE r.role_key IN('OWNER','BRANCH_MANAGER')
 AND p.permission_key IN('payment.settings.read','payment.settings.manage','payment.manual.read','payment.manual.review') ON CONFLICT DO NOTHING;

REVOKE ALL ON product_bank_card,product_bank_card_branch,product_payment_configuration,product_manual_transfer,product_manual_receipt,
 product_manual_review,product_manual_reconciliation,product_manual_request,product_receipt_retention
 FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;

SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.manual_card_eligible(c ms_b1_design.product_bank_card,branchid uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT c.active AND c.archived_at IS NULL AND(c.scope_kind='BUSINESS' OR EXISTS(
 SELECT 1 FROM ms_b1_design.product_bank_card_branch s WHERE s.business_id=c.business_id AND s.card_id=c.id AND s.branch_id=branchid))
$$;
CREATE FUNCTION ms_b1_design.manual_configuration(bid uuid,branchid uuid) RETURNS ms_b1_design.product_payment_configuration
 LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT c FROM ms_b1_design.product_payment_configuration c WHERE c.business_id=bid AND(c.branch_id=branchid OR c.branch_id IS NULL)
 ORDER BY c.branch_id IS NULL LIMIT 1
$$;
CREATE FUNCTION ms_b1_design.manual_method_available(bid uuid,branchid uuid) RETURNS boolean
 LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT coalesce((c.online_enabled AND EXISTS(SELECT 1 FROM ms_b1_design.product_runtime r WHERE r.singleton AND r.payment_provider<>'none'))
 OR(c.manual_enabled AND EXISTS(SELECT 1 FROM ms_b1_design.product_bank_card k WHERE k.business_id=bid AND ms_b1_design.manual_card_eligible(k,branchid))),false)
 FROM(SELECT ms_b1_design.manual_configuration(bid,branchid) c) q
 CROSS JOIN LATERAL(SELECT(q.c).*) c
$$;
CREATE FUNCTION ms_b1_design.manual_financial_actor(h bytea,csrf bytea,branchid uuid,p text) RETURNS jsonb
 LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE a jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);
 IF NOT ms_b1_design.b1b_can(a,p,branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.auth_session s WHERE s.token_hash=h AND s.user_id=(a->>'userId')::uuid
 AND s.assurance='MFA' AND s.mfa_at>clock_timestamp()-interval '15 minutes') THEN PERFORM ms_b1_design.b3_fail('FINANCIAL_MFA_REQUIRED','MS403');END IF;
 RETURN a;
END $$;
CREATE FUNCTION ms_b1_design.manual_event(bid uuid,branchid uuid,uid uuid,kind text,target uuid,details jsonb) RETURNS void
 LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 INSERT INTO ms_b1_design.audit_log(business_id,branch_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by)
 VALUES(bid,branchid,uid,kind,'manual_payment',target,gen_random_uuid(),details,uid);
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at)
 VALUES(bid,'manual.payment.event',gen_random_uuid(),1,kind,1,details,clock_timestamp());
END $$;
CREATE FUNCTION ms_b1_design.manual_replay(bid uuid,uid uuid,op text,k uuid,sig bytea) RETURNS jsonb
 LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE r ms_b1_design.product_manual_request;BEGIN
 IF k IS NULL OR octet_length(sig) IS DISTINCT FROM 32 THEN PERFORM ms_b1_design.b3_fail('INVALID_IDEMPOTENCY_KEY');END IF;
 SELECT * INTO r FROM ms_b1_design.product_manual_request WHERE business_id=bid AND actor_id=uid AND operation=op AND idempotency_key=k;
 IF FOUND THEN IF r.signature<>sig THEN PERFORM ms_b1_design.b3_fail('IDEMPOTENCY_MISMATCH','MS409');END IF;RETURN r.response;END IF;RETURN NULL;
END $$;
CREATE FUNCTION ms_b1_design.manual_remember(bid uuid,uid uuid,op text,k uuid,sig bytea,result jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 INSERT INTO ms_b1_design.product_manual_request(business_id,actor_id,operation,idempotency_key,signature,response) VALUES(bid,uid,op,k,sig,result);RETURN result;
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.manual_card_eligible(ms_b1_design.product_bank_card,uuid),ms_b1_design.manual_configuration(uuid,uuid),
 ms_b1_design.manual_method_available(uuid,uuid),ms_b1_design.manual_financial_actor(bytea,bytea,uuid,text),ms_b1_design.manual_event(uuid,uuid,uuid,text,uuid,jsonb),
 ms_b1_design.manual_replay(uuid,uuid,text,uuid,bytea),ms_b1_design.manual_remember(uuid,uuid,text,uuid,bytea,jsonb)
 FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
