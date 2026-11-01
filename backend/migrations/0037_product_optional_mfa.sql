-- Optional MFA requires an explicit non-OWNER role configuration; defaults remain required.
-- Verified admins also retain ordinary self-customer capability, separately from scoped management.
CREATE FUNCTION ms_b1_design.product_admin_grant(uid uuid,version integer,binding bytea,peer bytea,id uuid,h bytea,c bytea,device text,force_mfa boolean,recovery_hashes jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a ms_b1_design.product_admin_credential;cfg ms_b1_design.product_runtime;required boolean;entry text;issued boolean:=false;result jsonb;BEGIN
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 PERFORM 1 FROM ms_b1_design.app_user WHERE app_user.id=uid AND status IN('PENDING','ACTIVE') AND archived_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('code','INVALID_CREDENTIALS');END IF;
 SELECT * INTO a FROM ms_b1_design.product_admin_credential WHERE user_id=uid FOR UPDATE;
 IF a.user_id IS NULL OR a.credential_version<>version THEN RETURN jsonb_build_object('code','INVALID_CREDENTIALS');END IF;
 SELECT coalesce(bool_or(r.product_mfa_required OR r.role_key='OWNER'),true) INTO required FROM ms_b1_design.user_role_assignment x JOIN ms_b1_design.role r ON r.business_id=x.business_id AND r.id=x.role_id
 WHERE x.user_id=uid AND x.business_id=cfg.business_id AND x.revoked_at IS NULL AND x.archived_at IS NULL AND r.archived_at IS NULL AND r.role_key<>'CUSTOMER';
 IF force_mfa IS NULL THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 IF NOT required AND a.totp_verified_at IS NULL AND NOT force_mfa THEN
 UPDATE ms_b1_design.app_user SET status='ACTIVE',row_version=row_version+1,updated_at=clock_timestamp() WHERE app_user.id=uid AND status='PENDING';
 IF FOUND THEN INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES(cfg.business_id,uid,'auth.mfa.explicitly_optional','user',uid,gen_random_uuid(),jsonb_build_object('required',false),uid);END IF;
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.product_recovery_code WHERE user_id=uid AND used_at IS NULL) THEN
 IF jsonb_typeof(recovery_hashes) IS DISTINCT FROM 'array' OR jsonb_array_length(recovery_hashes)<>10 THEN PERFORM ms_b1_design.b3_fail('INVALID_RECOVERY_EVIDENCE');END IF;
 FOR entry IN SELECT jsonb_array_elements_text(recovery_hashes) LOOP IF entry !~ '^[a-f0-9]{64}$' THEN PERFORM ms_b1_design.b3_fail('INVALID_RECOVERY_EVIDENCE');END IF;INSERT INTO ms_b1_design.product_recovery_code(user_id,code_hash) VALUES(uid,decode(entry,'hex'));END LOOP;issued:=true;END IF;
 result:=ms_b1_design.product_issue_session(uid,'PASSWORD',h,c,device);RETURN result||jsonb_build_object('recoveryCodesIssued',issued);
 END IF;
 INSERT INTO ms_b1_design.product_auth_challenge(id,business_id,kind,user_id,binding_hash,peer_hash,credential_version,expires_at)
 VALUES(id,cfg.business_id,CASE WHEN a.totp_verified_at IS NULL THEN 'MFA_ENROLLMENT' ELSE 'ADMIN_LOGIN' END,uid,binding,peer,version,clock_timestamp()+interval '5 minutes');
 RETURN jsonb_build_object('state',CASE WHEN a.totp_verified_at IS NULL THEN 'MFA_ENROLLMENT_REQUIRED' ELSE 'MFA_REQUIRED' END,'challengeId',id,'totpCiphertext',CASE WHEN a.totp_verified_at IS NULL THEN a.totp_ciphertext END);
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.product_admin_finish(id uuid,binding bytea,counter bigint,h bytea,c bytea,device text,recovery_hashes jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE x ms_b1_design.product_auth_challenge;a ms_b1_design.product_admin_credential;entry text;BEGIN
 SELECT * INTO x FROM ms_b1_design.product_auth_challenge WHERE product_auth_challenge.id=$1 AND binding_hash=$2 FOR UPDATE;
 IF NOT FOUND OR x.kind NOT IN('ADMIN_LOGIN','MFA_ENROLLMENT') OR x.state<>'PENDING' OR x.expires_at<=clock_timestamp() OR x.attempts>=5 THEN RETURN jsonb_build_object('code','INVALID_MFA');END IF;
 PERFORM 1 FROM ms_b1_design.app_user WHERE app_user.id=x.user_id AND status IN('ACTIVE','PENDING') AND archived_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('code','INVALID_MFA');END IF;
 SELECT * INTO a FROM ms_b1_design.product_admin_credential WHERE user_id=x.user_id FOR UPDATE;
 IF a.credential_version<>x.credential_version OR counter IS NULL OR counter<=a.totp_last_counter THEN
 UPDATE ms_b1_design.product_auth_challenge SET attempts=attempts+1,state=CASE WHEN attempts+1>=5 THEN 'LOCKED' ELSE state END WHERE product_auth_challenge.id=x.id;
 RETURN jsonb_build_object('code','INVALID_MFA');END IF;
 IF abs(counter-floor(extract(epoch from clock_timestamp())/30)::bigint)>1 THEN RETURN jsonb_build_object('code','INVALID_MFA');END IF;
 IF x.kind='MFA_ENROLLMENT' THEN
 UPDATE ms_b1_design.product_recovery_code SET used_at=clock_timestamp() WHERE user_id=x.user_id AND used_at IS NULL;
 UPDATE ms_b1_design.auth_session SET revoked_at=clock_timestamp(),revocation_reason='MFA_ENROLLED',row_version=row_version+1 WHERE user_id=x.user_id AND revoked_at IS NULL;
 UPDATE ms_b1_design.product_admin_credential SET credential_version=credential_version+1 WHERE user_id=x.user_id;
 IF jsonb_typeof(recovery_hashes)<>'array' OR jsonb_array_length(recovery_hashes)<>10 THEN PERFORM ms_b1_design.b3_fail('INVALID_RECOVERY_EVIDENCE');END IF;
 FOR entry IN SELECT jsonb_array_elements_text(recovery_hashes) LOOP
 IF entry !~ '^[a-f0-9]{64}$' THEN PERFORM ms_b1_design.b3_fail('INVALID_RECOVERY_EVIDENCE');END IF;
 INSERT INTO ms_b1_design.product_recovery_code(user_id,code_hash) VALUES(x.user_id,decode(entry,'hex'));END LOOP;
 UPDATE ms_b1_design.app_user SET status='ACTIVE',row_version=row_version+1,updated_at=clock_timestamp() WHERE app_user.id=x.user_id;
 END IF;
 UPDATE ms_b1_design.product_admin_credential SET totp_verified_at=coalesce(totp_verified_at,clock_timestamp()),totp_last_counter=counter,updated_at=clock_timestamp() WHERE user_id=x.user_id;
 UPDATE ms_b1_design.product_auth_challenge SET state='CONSUMED',consumed_at=clock_timestamp() WHERE product_auth_challenge.id=x.id;
 RETURN ms_b1_design.product_issue_session(x.user_id,'MFA',h,c,device);
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.product_admin_activate(id uuid,binding bytea,username text,verifier text,totp_cipher text,next_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE x ms_b1_design.product_auth_challenge;i ms_b1_design.product_admin_invitation;uid uuid;BEGIN
 SELECT * INTO x FROM ms_b1_design.product_auth_challenge WHERE product_auth_challenge.id=$1 AND binding_hash=$2 FOR UPDATE;
 IF NOT FOUND OR x.kind<>'ADMIN_ACTIVATION' OR x.state<>'VERIFIED' OR x.expires_at<=clock_timestamp() THEN RETURN jsonb_build_object('code','INVALID_ACTIVATION');END IF;
 SELECT * INTO i FROM ms_b1_design.product_admin_invitation WHERE product_admin_invitation.id=x.invitation_id AND consumed_at IS NULL AND expires_at>clock_timestamp() FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('code','INVALID_ACTIVATION');END IF;
 SELECT user_id INTO uid FROM ms_b1_design.auth_identity WHERE provider='IRAN_MOBILE' AND subject_hash=x.mobile_lookup;
 IF uid IS NULL THEN
 INSERT INTO ms_b1_design.app_user(status) VALUES('PENDING') RETURNING app_user.id INTO uid;
 INSERT INTO ms_b1_design.auth_identity(user_id,provider,subject_hash,verified_at) VALUES(uid,'IRAN_MOBILE',x.mobile_lookup,clock_timestamp());
 INSERT INTO ms_b1_design.customer_contact(user_id,mobile_lookup,mobile_ciphertext,mobile_last_four,verified_at) VALUES(uid,x.mobile_lookup,x.phone_ciphertext,x.last_four,clock_timestamp());
 ELSE
 PERFORM 1 FROM ms_b1_design.app_user WHERE app_user.id=uid AND status IN('PENDING','ACTIVE') AND archived_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('code','ACCOUNT_UNAVAILABLE');END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.product_admin_credential WHERE user_id=uid) THEN RETURN jsonb_build_object('code','ADMIN_ALREADY_ACTIVATED');END IF;
 INSERT INTO ms_b1_design.product_admin_credential(user_id,username,password_verifier,totp_ciphertext,setup_authorized_at) VALUES(uid,username,verifier,totp_cipher,clock_timestamp());
 INSERT INTO ms_b1_design.user_role_assignment(business_id,user_id,role_id,branch_id,created_by) VALUES(i.business_id,uid,i.role_id,i.branch_id,i.created_by);
 INSERT INTO ms_b1_design.user_role_assignment(business_id,user_id,role_id) SELECT i.business_id,uid,r.id FROM ms_b1_design.role r WHERE r.business_id=i.business_id AND r.role_key='CUSTOMER' AND r.archived_at IS NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.user_role_assignment x WHERE x.business_id=i.business_id AND x.user_id=uid AND x.role_id=r.id AND x.revoked_at IS NULL AND x.archived_at IS NULL);
 UPDATE ms_b1_design.product_admin_invitation SET consumed_at=clock_timestamp() WHERE product_admin_invitation.id=i.id;
 UPDATE ms_b1_design.product_auth_challenge SET state='CONSUMED',consumed_at=clock_timestamp(),user_id=uid WHERE product_auth_challenge.id=x.id;
 INSERT INTO ms_b1_design.product_auth_challenge(id,business_id,kind,user_id,binding_hash,peer_hash,credential_version,expires_at)
 VALUES(next_id,i.business_id,'MFA_ENROLLMENT',uid,binding,x.peer_hash,1,clock_timestamp()+interval '5 minutes');
 RETURN jsonb_build_object('state','MFA_ENROLLMENT_REQUIRED','challengeId',next_id,'mfaOptional',EXISTS(SELECT 1 FROM ms_b1_design.role r WHERE r.id=i.role_id AND NOT r.product_mfa_required AND r.role_key<>'OWNER'));
END $$;
CREATE OR REPLACE FUNCTION ms_b1_design.product_account(h bytea) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h);
 RETURN(SELECT jsonb_build_object('id',u.id,'displayName',u.display_name,'mobileLastFour',c.mobile_last_four,'verifiedAt',ms_b1_design.b3_iso(c.verified_at),'notificationsOptIn',c.notifications_opt_in,
 'administrator',EXISTS(SELECT 1 FROM ms_b1_design.product_admin_credential p WHERE p.user_id=u.id),'currentAssurance',s.assurance,'mfaEnrolled',EXISTS(SELECT 1 FROM ms_b1_design.product_admin_credential p WHERE p.user_id=u.id AND p.totp_verified_at IS NOT NULL))
 FROM ms_b1_design.app_user u JOIN ms_b1_design.customer_contact c ON c.user_id=u.id JOIN ms_b1_design.auth_session s ON s.token_hash=h WHERE u.id=(a->>'userId')::uuid);
END $$;

REVOKE EXECUTE ON FUNCTION ms_b1_design.product_admin_grant(uuid,integer,bytea,bytea,uuid,bytea,bytea,text) FROM ms_product_auth;
REVOKE ALL ON FUNCTION ms_b1_design.product_admin_grant(uuid,integer,bytea,bytea,uuid,bytea,bytea,text,boolean,jsonb) FROM PUBLIC,ms_b1b_api,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_admin_grant(uuid,integer,bytea,bytea,uuid,bytea,bytea,text,boolean,jsonb) TO ms_product_auth;
