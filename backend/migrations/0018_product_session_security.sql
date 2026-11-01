-- Preserve the original actor OID so every existing entry point receives the security extension.
CREATE FUNCTION ms_b1_design.product_legacy_actor(h bytea, csrf bytea DEFAULT NULL, mutation boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE s ms_b1_design.auth_session; u ms_b1_design.app_user; user_id uuid;
BEGIN
  SELECT x.user_id INTO user_id FROM ms_b1_design.auth_session x WHERE token_hash=h;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='MS401', MESSAGE='Unauthenticated'; END IF;
  -- Same user -> session lock order as offline rotation; avoid fixation/revocation deadlocks.
  SELECT * INTO u FROM ms_b1_design.app_user WHERE id=user_id FOR SHARE;
  SELECT * INTO s FROM ms_b1_design.auth_session WHERE token_hash=h FOR UPDATE;
  IF NOT FOUND OR s.business_id IS NULL OR s.revoked_at IS NOT NULL OR s.expires_at<=clock_timestamp()
    OR s.idle_expires_at IS NULL OR s.idle_expires_at<=clock_timestamp() THEN
    RAISE EXCEPTION USING ERRCODE='MS401', MESSAGE='Unauthenticated';
  END IF;
  PERFORM 1 FROM ms_b1_design.business WHERE id=s.business_id AND archived_at IS NULL FOR SHARE;
  IF NOT FOUND OR u.status IS DISTINCT FROM 'ACTIVE' OR u.archived_at IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE='MS401', MESSAGE='Unauthenticated';
  END IF;
  IF mutation AND (csrf IS NULL OR s.csrf_hash IS DISTINCT FROM csrf) THEN
    RAISE EXCEPTION USING ERRCODE='MS403', MESSAGE='Forbidden';
  END IF;
  -- Lock active membership/role/permission evidence until transaction end.
  PERFORM 1 FROM ms_b1_design.user_role_assignment a JOIN ms_b1_design.role r
    ON r.business_id=a.business_id AND r.id=a.role_id
    WHERE a.business_id=s.business_id AND a.user_id=s.user_id AND a.revoked_at IS NULL
    AND a.archived_at IS NULL AND r.archived_at IS NULL FOR SHARE OF a,r;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='MS403', MESSAGE='Forbidden'; END IF;
  PERFORM 1 FROM ms_b1_design.role_permission rp JOIN ms_b1_design.permission p ON p.id=rp.permission_id
    WHERE rp.business_id=s.business_id AND rp.archived_at IS NULL AND p.archived_at IS NULL FOR SHARE OF rp,p;
  UPDATE ms_b1_design.auth_session SET last_seen_at=clock_timestamp(),
    idle_expires_at=least(expires_at,clock_timestamp()+interval '15 minutes'),updated_at=clock_timestamp()
    WHERE id=s.id;
  RETURN jsonb_build_object('userId',s.user_id,'businessId',s.business_id,'sessionId',s.id);
END $$;

CREATE OR REPLACE FUNCTION ms_b1_design.b1b_actor(h bytea,csrf bytea DEFAULT NULL,mutation boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE a jsonb;s ms_b1_design.auth_session;cfg ms_b1_design.product_runtime;v integer;admin boolean;required boolean;BEGIN
 a:=ms_b1_design.product_legacy_actor(h,csrf,mutation);
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 SELECT * INTO s FROM ms_b1_design.auth_session WHERE token_hash=h;
 IF s.product_environment IS DISTINCT FROM cfg.environment OR s.assurance IS NULL THEN PERFORM ms_b1_design.b3_fail('UNAUTHENTICATED','MS401');END IF;
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
REVOKE ALL ON FUNCTION ms_b1_design.product_legacy_actor(bytea,bytea,boolean),ms_b1_design.b1b_actor(bytea,bytea,boolean) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;

CREATE FUNCTION ms_b1_design.product_sessions(h bytea,c bytea,operation text,target uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;uid uuid;bid uuid;sid uuid;n integer;BEGIN
 IF operation NOT IN('list','revoke','revoke_others','revoke_all') THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 a:=ms_b1_design.b1b_actor(h,c,operation<>'list');uid:=(a->>'userId')::uuid;bid:=(a->>'businessId')::uuid;sid:=(a->>'sessionId')::uuid;
 IF operation='list' THEN
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(jsonb_build_object('id',s.id,'current',s.id=sid,'device',s.device_label,'authenticatedAt',ms_b1_design.b3_iso(s.authenticated_at),'expiresAt',ms_b1_design.b3_iso(s.expires_at),'lastSeenAt',ms_b1_design.b3_iso(s.last_seen_at)) ORDER BY s.created_at DESC)
 FROM ms_b1_design.auth_session s WHERE s.user_id=uid AND s.business_id=bid AND s.revoked_at IS NULL AND s.expires_at>clock_timestamp() AND s.idle_expires_at>clock_timestamp()),'[]'::jsonb));END IF;
 IF operation='revoke' AND NOT EXISTS(SELECT 1 FROM ms_b1_design.auth_session WHERE id=target AND user_id=uid AND business_id=bid) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 UPDATE ms_b1_design.auth_session SET revoked_at=clock_timestamp(),revocation_reason='USER_REVOKED',row_version=row_version+1
 WHERE user_id=uid AND business_id=bid AND revoked_at IS NULL AND(operation='revoke_all' OR(operation='revoke_others' AND id<>sid) OR(operation='revoke' AND id=target));
 GET DIAGNOSTICS n=ROW_COUNT;
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by)
 VALUES(bid,uid,'auth.sessions.revoked','user',uid,gen_random_uuid(),jsonb_build_object('count',n,'operation',operation),uid);
 RETURN jsonb_build_object('revoked',n,'currentRevoked',operation='revoke_all' OR(operation='revoke' AND target=sid));
END $$;
CREATE FUNCTION ms_b1_design.product_recover(id uuid,binding bytea,recovery_hash bytea,new_verifier text,new_totp text,next_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE x ms_b1_design.product_auth_challenge;a ms_b1_design.product_admin_credential;rc uuid;BEGIN
 SELECT * INTO x FROM ms_b1_design.product_auth_challenge WHERE product_auth_challenge.id=$1 AND binding_hash=$2 FOR UPDATE;
 IF NOT FOUND OR x.kind<>'ADMIN_RECOVERY' OR x.state<>'VERIFIED' OR x.expires_at<=clock_timestamp() OR x.attempts>=5 THEN RETURN jsonb_build_object('code','INVALID_RECOVERY');END IF;
 PERFORM 1 FROM ms_b1_design.app_user WHERE app_user.id=x.user_id AND status='ACTIVE' AND archived_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('code','INVALID_RECOVERY');END IF;
 SELECT * INTO a FROM ms_b1_design.product_admin_credential WHERE user_id=x.user_id FOR UPDATE;
 SELECT product_recovery_code.id INTO rc FROM ms_b1_design.product_recovery_code WHERE user_id=x.user_id AND code_hash=recovery_hash AND used_at IS NULL FOR UPDATE;
 IF rc IS NULL THEN
 UPDATE ms_b1_design.product_auth_challenge SET attempts=attempts+1,state=CASE WHEN attempts+1>=5 THEN 'LOCKED' ELSE state END WHERE product_auth_challenge.id=x.id;
 RETURN jsonb_build_object('code','INVALID_RECOVERY');END IF;
 UPDATE ms_b1_design.product_recovery_code SET used_at=clock_timestamp() WHERE user_id=x.user_id AND used_at IS NULL;
 UPDATE ms_b1_design.product_admin_credential SET password_verifier=new_verifier,credential_version=credential_version+1,totp_ciphertext=new_totp,totp_verified_at=NULL,totp_last_counter=-1,updated_at=clock_timestamp()
 WHERE user_id=x.user_id RETURNING * INTO a;
 UPDATE ms_b1_design.auth_session SET revoked_at=clock_timestamp(),revocation_reason='RECOVERY',row_version=row_version+1 WHERE user_id=x.user_id AND revoked_at IS NULL;
 UPDATE ms_b1_design.product_auth_challenge SET state='CONSUMED',consumed_at=clock_timestamp() WHERE product_auth_challenge.id=x.id;
 INSERT INTO ms_b1_design.product_auth_challenge(id,business_id,kind,user_id,binding_hash,peer_hash,credential_version,expires_at)
 VALUES(next_id,x.business_id,'MFA_ENROLLMENT',x.user_id,binding,x.peer_hash,a.credential_version,clock_timestamp()+interval '5 minutes');
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by)
 VALUES(x.business_id,x.user_id,'auth.admin.recovered','user',x.user_id,gen_random_uuid(),jsonb_build_object('sessionsRevoked',true),x.user_id);
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at,created_by)
 VALUES(x.business_id,'user.security',x.user_id,a.credential_version,'auth.admin.recovered',1,jsonb_build_object('userId',x.user_id),clock_timestamp(),x.user_id);
 RETURN jsonb_build_object('state','MFA_ENROLLMENT_REQUIRED','challengeId',next_id);
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.product_sessions(bytea,bytea,text,uuid),ms_b1_design.product_recover(uuid,bytea,bytea,text,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_sessions(bytea,bytea,text,uuid),ms_b1_design.product_recover(uuid,bytea,bytea,text,text,uuid) TO ms_product_auth;
