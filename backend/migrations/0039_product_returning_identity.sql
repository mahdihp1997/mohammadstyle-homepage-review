-- The challenge UUID parameter must not shadow the returning account primary key.
CREATE OR REPLACE FUNCTION ms_b1_design.product_auth_verify(id uuid,binding bytea,provided_hash bytea,session_hash bytea,csrf_hash bytea,device text,next_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE x ms_b1_design.product_auth_challenge;cfg ms_b1_design.product_runtime;uid uuid;rid uuid;cred ms_b1_design.product_admin_credential;BEGIN
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 SELECT * INTO x FROM ms_b1_design.product_auth_challenge WHERE product_auth_challenge.id=$1 AND binding_hash=$2 FOR UPDATE;
 IF NOT FOUND OR x.kind NOT IN('MOBILE_LOGIN','ADMIN_ACTIVATION','ADMIN_RECOVERY') OR x.state<>'PENDING' THEN RETURN jsonb_build_object('code','INVALID_OTP');END IF;
 IF x.expires_at<=clock_timestamp() THEN UPDATE ms_b1_design.product_auth_challenge SET state='EXPIRED',otp_hash=NULL,secret_ciphertext=NULL WHERE product_auth_challenge.id=x.id;RETURN jsonb_build_object('code','OTP_EXPIRED');END IF;
 IF x.attempts>=5 THEN RETURN jsonb_build_object('code','OTP_LOCKED');END IF;
 IF x.otp_hash IS DISTINCT FROM provided_hash THEN
 UPDATE ms_b1_design.product_auth_challenge SET attempts=attempts+1,state=CASE WHEN attempts+1>=5 THEN 'LOCKED' ELSE state END WHERE product_auth_challenge.id=x.id;
 RETURN jsonb_build_object('code','INVALID_OTP');END IF;
 UPDATE ms_b1_design.product_auth_challenge SET state='VERIFIED',otp_hash=NULL,secret_ciphertext=NULL WHERE product_auth_challenge.id=x.id;
 IF x.kind='ADMIN_ACTIVATION' THEN
 IF x.invitation_id IS NULL THEN RETURN jsonb_build_object('code','INVALID_OTP');END IF;
 RETURN jsonb_build_object('state','ACTIVATION_READY','challengeId',x.id);END IF;
 SELECT i.user_id INTO uid FROM ms_b1_design.auth_identity i WHERE i.provider='IRAN_MOBILE' AND i.subject_hash=x.mobile_lookup AND i.verified_at IS NOT NULL;
 IF x.kind='ADMIN_RECOVERY' THEN
 IF uid IS NULL OR NOT EXISTS(SELECT 1 FROM ms_b1_design.product_admin_credential WHERE user_id=uid) THEN RETURN jsonb_build_object('code','INVALID_OTP');END IF;
 UPDATE ms_b1_design.product_auth_challenge SET user_id=uid WHERE product_auth_challenge.id=x.id;
 RETURN jsonb_build_object('state','RECOVERY_READY','challengeId',x.id);END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('mobile:'||encode(x.mobile_lookup,'hex'),0));
 SELECT i.user_id INTO uid FROM ms_b1_design.auth_identity i WHERE i.provider='IRAN_MOBILE' AND i.subject_hash=x.mobile_lookup;
 SELECT r.id INTO rid FROM ms_b1_design.role r WHERE r.business_id=cfg.business_id AND r.role_key='CUSTOMER' AND r.archived_at IS NULL;
 IF rid IS NULL THEN PERFORM ms_b1_design.b3_fail('AUTH_UNCONFIGURED');END IF;
 IF uid IS NULL THEN
 INSERT INTO ms_b1_design.app_user(status) VALUES('ACTIVE') RETURNING app_user.id INTO uid;
 INSERT INTO ms_b1_design.auth_identity(user_id,provider,subject_hash,verified_at) VALUES(uid,'IRAN_MOBILE',x.mobile_lookup,clock_timestamp());
 INSERT INTO ms_b1_design.customer_contact(user_id,mobile_lookup,mobile_ciphertext,mobile_last_four,verified_at) VALUES(uid,x.mobile_lookup,x.phone_ciphertext,x.last_four,clock_timestamp());
 ELSE
 PERFORM 1 FROM ms_b1_design.app_user WHERE app_user.id=uid AND status='ACTIVE' AND archived_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('code','ACCOUNT_UNAVAILABLE');END IF;
 END IF;
 INSERT INTO ms_b1_design.user_role_assignment(business_id,user_id,role_id) SELECT cfg.business_id,uid,rid WHERE NOT EXISTS(SELECT 1 FROM ms_b1_design.user_role_assignment WHERE business_id=cfg.business_id AND user_id=uid AND role_id=rid AND revoked_at IS NULL AND archived_at IS NULL);
 UPDATE ms_b1_design.product_auth_challenge SET state='CONSUMED',consumed_at=clock_timestamp(),user_id=uid WHERE product_auth_challenge.id=x.id;
 SELECT * INTO cred FROM ms_b1_design.product_admin_credential WHERE user_id=uid;
 IF cred.user_id IS NOT NULL THEN RETURN jsonb_build_object('code','USE_ADMIN_LOGIN');END IF;
 RETURN ms_b1_design.product_issue_session(uid,'OTP',session_hash,csrf_hash,device);
END $$;

