SET search_path=pg_catalog;
ALTER TABLE ms_b1_design.customer_contact ADD COLUMN test_only boolean NOT NULL DEFAULT false;
ALTER TABLE ms_b1_design.product_admin_credential ADD COLUMN test_only boolean NOT NULL DEFAULT false;
UPDATE ms_b1_design.customer_contact SET test_only=coalesce((SELECT environment='test' FROM ms_b1_design.product_runtime WHERE singleton),false);
UPDATE ms_b1_design.product_admin_credential SET test_only=coalesce((SELECT environment='test' FROM ms_b1_design.product_runtime WHERE singleton),false);
CREATE FUNCTION ms_b1_design.product_identity_provenance() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE mode text;BEGIN
 SELECT environment INTO mode FROM ms_b1_design.product_runtime WHERE singleton;
 IF mode IS NULL THEN PERFORM ms_b1_design.b3_fail('AUTH_UNCONFIGURED');END IF;
 NEW.test_only:=(mode='test');RETURN NEW;
END $$;
CREATE TRIGGER product_contact_source BEFORE INSERT ON ms_b1_design.customer_contact FOR EACH ROW EXECUTE FUNCTION ms_b1_design.product_identity_provenance();
CREATE TRIGGER product_admin_source BEFORE INSERT ON ms_b1_design.product_admin_credential FOR EACH ROW EXECUTE FUNCTION ms_b1_design.product_identity_provenance();
CREATE OR REPLACE FUNCTION ms_b1_design.product_runtime_view() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('environment',environment,'businessId',business_id,'origin',public_origin,'sessionSeconds',session_seconds,'idleSeconds',idle_seconds,
 'testIdentities',(SELECT count(*) FROM ms_b1_design.customer_contact WHERE test_only)+(SELECT count(*) FROM ms_b1_design.product_admin_credential WHERE test_only)+(SELECT count(*) FROM ms_b1_design.auth_identity WHERE provider='B4_ISOLATED_TEST'))
 FROM ms_b1_design.product_runtime WHERE singleton
$$;
REVOKE ALL ON FUNCTION ms_b1_design.product_identity_provenance() FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker;

CREATE OR REPLACE FUNCTION ms_b1_design.product_issue_session(u uuid,level text,h bytea,c bytea,device text) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE cfg ms_b1_design.product_runtime;v integer;sid uuid;BEGIN
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 PERFORM 1 FROM ms_b1_design.app_user WHERE id=u AND status='ACTIVE' AND archived_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('UNAUTHENTICATED','MS401');END IF;
 IF cfg.environment<>'test' AND(EXISTS(SELECT 1 FROM ms_b1_design.customer_contact WHERE user_id=u AND test_only) OR EXISTS(SELECT 1 FROM ms_b1_design.product_admin_credential WHERE user_id=u AND test_only)) THEN PERFORM ms_b1_design.b3_fail('TEST_IDENTITY_FORBIDDEN','MS401');END IF;
 -- Bound live session count under the same canonical user lock; never reuse a token.
 UPDATE ms_b1_design.auth_session SET revoked_at=clock_timestamp(),revocation_reason='SESSION_LIMIT',row_version=row_version+1
 WHERE id IN(SELECT id FROM ms_b1_design.auth_session WHERE user_id=u AND product_environment=cfg.environment AND revoked_at IS NULL AND expires_at>clock_timestamp() AND idle_expires_at>clock_timestamp() ORDER BY created_at DESC OFFSET 19);
 IF octet_length(h)<>32 OR octet_length(c)<>32 OR level NOT IN('OTP','PASSWORD','MFA') THEN PERFORM ms_b1_design.b3_fail('INVALID_SESSION_EVIDENCE');END IF;
 SELECT coalesce(a.credential_version,x.identity_version) INTO v FROM ms_b1_design.customer_contact x LEFT JOIN ms_b1_design.product_admin_credential a ON a.user_id=x.user_id WHERE x.user_id=u;
 IF v IS NULL THEN PERFORM ms_b1_design.b3_fail('VERIFIED_IDENTITY_REQUIRED','MS403');END IF;
 INSERT INTO ms_b1_design.auth_session(user_id,business_id,token_hash,csrf_hash,expires_at,idle_expires_at,product_environment,assurance,credential_version,authenticated_at,mfa_at,device_label,created_by)
 VALUES(u,cfg.business_id,h,c,clock_timestamp()+make_interval(secs=>cfg.session_seconds),clock_timestamp()+make_interval(secs=>cfg.idle_seconds),cfg.environment,level,v,clock_timestamp(),CASE WHEN level='MFA' THEN clock_timestamp() END,left(device,160),u) RETURNING id INTO sid;
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by)
 VALUES(cfg.business_id,u,'auth.session.created','session',sid,gen_random_uuid(),jsonb_build_object('assurance',level),u);
 RETURN jsonb_build_object('authenticated',true,'userId',u,'maxAge',cfg.session_seconds);
END $$;
