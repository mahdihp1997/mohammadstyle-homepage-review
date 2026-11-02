-- Both customer permissions are ownership-scoped server APIs. Every other
-- permission retains the existing admin credential/MFA policy; owner MFA and
-- fresh financial step-up are unchanged. No production login bypass.
SET search_path=pg_catalog;
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
 SELECT coalesce(bool_or(p.permission_key NOT IN('booking.customer','shop.customer')),false),coalesce(bool_or(r.product_mfa_required OR r.role_key='OWNER') FILTER(WHERE p.permission_key NOT IN('booking.customer','shop.customer')),false)
 INTO admin,required FROM ms_b1_design.user_role_assignment x JOIN ms_b1_design.role r ON r.business_id=x.business_id AND r.id=x.role_id
 JOIN ms_b1_design.role_permission rp ON rp.business_id=r.business_id AND rp.role_id=r.id JOIN ms_b1_design.permission p ON p.id=rp.permission_id
 WHERE x.user_id=s.user_id AND x.business_id=s.business_id AND x.revoked_at IS NULL AND x.archived_at IS NULL AND r.archived_at IS NULL AND rp.archived_at IS NULL AND p.archived_at IS NULL;
 IF admin AND(NOT EXISTS(SELECT 1 FROM ms_b1_design.product_admin_credential c WHERE c.user_id=s.user_id)
 OR s.assurance NOT IN('PASSWORD','MFA') OR(required AND(s.assurance<>'MFA' OR s.mfa_at IS NULL))) THEN PERFORM ms_b1_design.b3_fail('MFA_REQUIRED','MS403');END IF;
 UPDATE ms_b1_design.auth_session SET idle_expires_at=least(expires_at,clock_timestamp()+make_interval(secs=>cfg.idle_seconds)) WHERE id=s.id;
 RETURN a;
END $$;
