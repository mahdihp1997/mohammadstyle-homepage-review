SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.product_auth_request(id uuid,kind text,lookup bytea,phone text,last_four text,code_hash bytea,ciphertext text,binding bytea,peer bytea,invitation bytea DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE cfg ms_b1_design.product_runtime;inv ms_b1_design.product_admin_invitation;BEGIN
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 IF kind NOT IN('MOBILE_LOGIN','ADMIN_ACTIVATION','ADMIN_RECOVERY') OR octet_length(lookup)<>32 OR octet_length(code_hash)<>32 OR octet_length(binding)<>32 OR octet_length(peer)<>32 OR last_four !~ '^[0-9]{4}$' THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 IF NOT ms_b1_design.product_throttle(peer,'otp.peer',20,900) OR NOT ms_b1_design.product_throttle(lookup,'otp.phone',3,900) THEN RETURN jsonb_build_object('code','RATE_LIMITED');END IF;
 IF EXISTS(SELECT 1 FROM ms_b1_design.product_auth_challenge x WHERE x.mobile_lookup=lookup AND x.created_at>clock_timestamp()-interval '60 seconds') THEN RETURN jsonb_build_object('code','RATE_LIMITED');END IF;
 IF kind='ADMIN_ACTIVATION' THEN SELECT * INTO inv FROM ms_b1_design.product_admin_invitation x WHERE x.invitation_hash=invitation AND x.mobile_lookup=lookup AND x.business_id=cfg.business_id AND x.consumed_at IS NULL AND x.expires_at>clock_timestamp();END IF;
 UPDATE ms_b1_design.product_auth_challenge x SET state='CANCELLED',otp_hash=NULL,secret_ciphertext=NULL WHERE x.mobile_lookup=lookup AND x.state='PENDING' AND x.kind IN('MOBILE_LOGIN','ADMIN_ACTIVATION','ADMIN_RECOVERY');
 INSERT INTO ms_b1_design.product_auth_challenge(id,business_id,kind,mobile_lookup,phone_ciphertext,last_four,otp_hash,secret_ciphertext,binding_hash,peer_hash,expires_at,invitation_id)
 VALUES(id,cfg.business_id,kind,lookup,phone,last_four,code_hash,ciphertext,binding,peer,clock_timestamp()+interval '5 minutes',inv.id);
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at)
 VALUES(cfg.business_id,'auth.challenge',id,1,'auth.otp.requested',1,jsonb_build_object('challengeId',id),clock_timestamp());
 RETURN jsonb_build_object('challengeId',id,'expiresIn',300,'delivery','QUEUED');
END $$;
CREATE FUNCTION ms_b1_design.product_auth_context(id uuid,binding bytea) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('id',x.id,'kind',x.kind,'lookup',encode(x.mobile_lookup,'hex'),'userId',x.user_id,'credentialVersion',x.credential_version,
 'totpCiphertext',a.totp_ciphertext,'totpVerified',a.totp_verified_at IS NOT NULL,'lastCounter',a.totp_last_counter::text)
 FROM ms_b1_design.product_auth_challenge x LEFT JOIN ms_b1_design.product_admin_credential a ON a.user_id=x.user_id
 WHERE x.id=$1 AND x.binding_hash=$2 AND x.state IN('PENDING','VERIFIED') AND x.attempts<5 AND x.expires_at>clock_timestamp()
$$;
CREATE FUNCTION ms_b1_design.product_auth_verify(id uuid,binding bytea,provided_hash bytea,session_hash bytea,csrf_hash bytea,device text,next_id uuid)
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
 PERFORM 1 FROM ms_b1_design.app_user WHERE id=uid AND status='ACTIVE' AND archived_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('code','ACCOUNT_UNAVAILABLE');END IF;
 END IF;
 INSERT INTO ms_b1_design.user_role_assignment(business_id,user_id,role_id) SELECT cfg.business_id,uid,rid WHERE NOT EXISTS(SELECT 1 FROM ms_b1_design.user_role_assignment WHERE business_id=cfg.business_id AND user_id=uid AND role_id=rid AND revoked_at IS NULL AND archived_at IS NULL);
 UPDATE ms_b1_design.product_auth_challenge SET state='CONSUMED',consumed_at=clock_timestamp(),user_id=uid WHERE product_auth_challenge.id=x.id;
 SELECT * INTO cred FROM ms_b1_design.product_admin_credential WHERE user_id=uid;
 IF cred.user_id IS NOT NULL THEN
 IF cred.totp_verified_at IS NULL THEN RETURN jsonb_build_object('code','USE_ADMIN_LOGIN');END IF;
 INSERT INTO ms_b1_design.product_auth_challenge(id,business_id,kind,user_id,binding_hash,peer_hash,credential_version,expires_at)
 VALUES(next_id,cfg.business_id,'ADMIN_LOGIN',uid,binding,x.peer_hash,cred.credential_version,clock_timestamp()+interval '5 minutes');
 RETURN jsonb_build_object('state','MFA_REQUIRED','challengeId',next_id);END IF;
 RETURN ms_b1_design.product_issue_session(uid,'OTP',session_hash,csrf_hash,device);
END $$;
CREATE FUNCTION ms_b1_design.product_admin_lookup(username text,peer bytea,subject bytea) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a ms_b1_design.product_admin_credential;BEGIN
 IF NOT ms_b1_design.product_throttle(peer,'admin.peer',30,900) OR NOT ms_b1_design.product_throttle(subject,'admin.subject',8,900) THEN RETURN jsonb_build_object('code','RATE_LIMITED');END IF;
 SELECT c.* INTO a FROM ms_b1_design.product_admin_credential c JOIN ms_b1_design.app_user u ON u.id=c.user_id
 JOIN ms_b1_design.customer_contact p ON p.user_id=u.id WHERE c.username=$1 AND u.status IN('PENDING','ACTIVE') AND u.archived_at IS NULL;
 IF NOT FOUND THEN RETURN NULL;END IF;
 RETURN jsonb_build_object('userId',a.user_id,'verifier',a.password_verifier,'version',a.credential_version);
END $$;
CREATE FUNCTION ms_b1_design.product_admin_grant(uid uuid,version integer,binding bytea,peer bytea,id uuid,h bytea,c bytea,device text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a ms_b1_design.product_admin_credential;cfg ms_b1_design.product_runtime;required boolean;BEGIN
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 PERFORM 1 FROM ms_b1_design.app_user WHERE app_user.id=uid AND status IN('PENDING','ACTIVE') AND archived_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('code','INVALID_CREDENTIALS');END IF;
 SELECT * INTO a FROM ms_b1_design.product_admin_credential WHERE user_id=uid FOR UPDATE;
 IF a.user_id IS NULL OR a.credential_version<>version THEN RETURN jsonb_build_object('code','INVALID_CREDENTIALS');END IF;
 SELECT coalesce(bool_or(r.product_mfa_required OR r.role_key='OWNER'),true) INTO required FROM ms_b1_design.user_role_assignment x JOIN ms_b1_design.role r ON r.business_id=x.business_id AND r.id=x.role_id
 WHERE x.user_id=uid AND x.business_id=cfg.business_id AND x.revoked_at IS NULL AND x.archived_at IS NULL AND r.archived_at IS NULL AND r.role_key<>'CUSTOMER';
 IF NOT required AND a.totp_verified_at IS NULL THEN RETURN ms_b1_design.product_issue_session(uid,'PASSWORD',h,c,device);END IF;
 INSERT INTO ms_b1_design.product_auth_challenge(id,business_id,kind,user_id,binding_hash,peer_hash,credential_version,expires_at)
 VALUES(id,cfg.business_id,CASE WHEN a.totp_verified_at IS NULL THEN 'MFA_ENROLLMENT' ELSE 'ADMIN_LOGIN' END,uid,binding,peer,version,clock_timestamp()+interval '5 minutes');
 RETURN jsonb_build_object('state',CASE WHEN a.totp_verified_at IS NULL THEN 'MFA_ENROLLMENT_REQUIRED' ELSE 'MFA_REQUIRED' END,'challengeId',id,'totpCiphertext',CASE WHEN a.totp_verified_at IS NULL THEN a.totp_ciphertext END);
END $$;
CREATE FUNCTION ms_b1_design.product_admin_finish(id uuid,binding bytea,counter bigint,h bytea,c bytea,device text,recovery_hashes jsonb) RETURNS jsonb
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
CREATE FUNCTION ms_b1_design.product_admin_activate(id uuid,binding bytea,username text,verifier text,totp_cipher text,next_id uuid) RETURNS jsonb
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
 UPDATE ms_b1_design.product_admin_invitation SET consumed_at=clock_timestamp() WHERE product_admin_invitation.id=i.id;
 UPDATE ms_b1_design.product_auth_challenge SET state='CONSUMED',consumed_at=clock_timestamp(),user_id=uid WHERE product_auth_challenge.id=x.id;
 INSERT INTO ms_b1_design.product_auth_challenge(id,business_id,kind,user_id,binding_hash,peer_hash,credential_version,expires_at)
 VALUES(next_id,i.business_id,'MFA_ENROLLMENT',uid,binding,x.peer_hash,1,clock_timestamp()+interval '5 minutes');
 RETURN jsonb_build_object('state','MFA_ENROLLMENT_REQUIRED','challengeId',next_id);
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.product_auth_request(uuid,text,bytea,text,text,bytea,text,bytea,bytea,bytea),ms_b1_design.product_auth_context(uuid,bytea),ms_b1_design.product_auth_verify(uuid,bytea,bytea,bytea,bytea,text,uuid),ms_b1_design.product_admin_lookup(text,bytea,bytea),ms_b1_design.product_admin_grant(uuid,integer,bytea,bytea,uuid,bytea,bytea,text),ms_b1_design.product_admin_finish(uuid,bytea,bigint,bytea,bytea,text,jsonb),ms_b1_design.product_admin_activate(uuid,bytea,text,text,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_auth_request(uuid,text,bytea,text,text,bytea,text,bytea,bytea,bytea),ms_b1_design.product_auth_context(uuid,bytea),ms_b1_design.product_auth_verify(uuid,bytea,bytea,bytea,bytea,text,uuid),ms_b1_design.product_admin_lookup(text,bytea,bytea),ms_b1_design.product_admin_grant(uuid,integer,bytea,bytea,uuid,bytea,bytea,text),ms_b1_design.product_admin_finish(uuid,bytea,bigint,bytea,bytea,text,jsonb),ms_b1_design.product_admin_activate(uuid,bytea,text,text,text,uuid) TO ms_product_auth;
