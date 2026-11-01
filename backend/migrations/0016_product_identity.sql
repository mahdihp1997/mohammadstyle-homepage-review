-- Production identity boundary. Original migrations stay immutable.
SET search_path=ms_b1_design,public;
CREATE TABLE product_runtime (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton), business_id uuid NOT NULL REFERENCES business(id),
 environment text NOT NULL CHECK(environment IN('test','staging','production')), public_origin text NOT NULL,
 session_seconds integer NOT NULL DEFAULT 3600 CHECK(session_seconds BETWEEN 900 AND 86400),
 idle_seconds integer NOT NULL DEFAULT 900 CHECK(idle_seconds BETWEEN 300 AND 3600 AND idle_seconds<=session_seconds),
 CHECK(environment='test' OR public_origin ~ '^https://'),created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE customer_contact (
 user_id uuid PRIMARY KEY REFERENCES app_user(id),mobile_lookup bytea NOT NULL UNIQUE CHECK(octet_length(mobile_lookup)=32),
 mobile_ciphertext text NOT NULL,mobile_last_four text NOT NULL CHECK(mobile_last_four ~ '^[0-9]{4}$'),
 verified_at timestamptz NOT NULL,identity_version integer NOT NULL DEFAULT 1 CHECK(identity_version>0),
 notifications_opt_in boolean NOT NULL DEFAULT false,updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE product_admin_credential (
 user_id uuid PRIMARY KEY REFERENCES app_user(id),username text NOT NULL UNIQUE CHECK(username ~ '^[a-z][a-z0-9_.-]{2,63}$'),
 password_verifier text NOT NULL CHECK(password_verifier ~ '^scrypt-v1\$[a-f0-9]{64}\$[a-f0-9]{128}$'),
 credential_version integer NOT NULL DEFAULT 1 CHECK(credential_version>0),totp_ciphertext text,
 totp_verified_at timestamptz,totp_last_counter bigint NOT NULL DEFAULT -1,
 setup_authorized_at timestamptz NOT NULL,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),CHECK(totp_verified_at IS NULL OR totp_ciphertext IS NOT NULL)
);
CREATE TABLE product_admin_invitation (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL REFERENCES business(id),
 mobile_lookup bytea NOT NULL CHECK(octet_length(mobile_lookup)=32),invitation_hash bytea NOT NULL UNIQUE CHECK(octet_length(invitation_hash)=32),
 role_id uuid NOT NULL,branch_id uuid,expires_at timestamptz NOT NULL,consumed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),created_by uuid REFERENCES app_user(id),
 FOREIGN KEY(business_id,role_id) REFERENCES role(business_id,id),FOREIGN KEY(business_id,branch_id) REFERENCES branch(business_id,id),
 CHECK(isfinite(expires_at) AND expires_at>created_at)
);
CREATE TABLE product_recovery_code (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid NOT NULL REFERENCES product_admin_credential(user_id),
 code_hash bytea NOT NULL UNIQUE CHECK(octet_length(code_hash)=32),used_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX product_recovery_owner ON product_recovery_code(user_id);
CREATE TABLE product_auth_challenge (
 id uuid PRIMARY KEY,business_id uuid NOT NULL REFERENCES business(id),
 kind text NOT NULL CHECK(kind IN('MOBILE_LOGIN','ADMIN_ACTIVATION','ADMIN_RECOVERY','ADMIN_LOGIN','MFA_ENROLLMENT','PASSWORD_RESET')),
 mobile_lookup bytea CHECK(mobile_lookup IS NULL OR octet_length(mobile_lookup)=32),
 user_id uuid REFERENCES app_user(id),phone_ciphertext text,last_four text CHECK(last_four IS NULL OR last_four ~ '^[0-9]{4}$'),
 otp_hash bytea CHECK(otp_hash IS NULL OR octet_length(otp_hash)=32),secret_ciphertext text,
 binding_hash bytea NOT NULL CHECK(octet_length(binding_hash)=32),peer_hash bytea NOT NULL CHECK(octet_length(peer_hash)=32),
 state text NOT NULL DEFAULT 'PENDING' CHECK(state IN('PENDING','VERIFIED','CONSUMED','CANCELLED','EXPIRED','LOCKED')),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 5),credential_version integer,
 invitation_id uuid REFERENCES product_admin_invitation(id),expires_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),consumed_at timestamptz,
 CHECK(isfinite(expires_at) AND expires_at>created_at)
);
CREATE INDEX product_challenge_identity ON product_auth_challenge(mobile_lookup,kind,created_at DESC);
CREATE INDEX product_challenge_expiry ON product_auth_challenge(expires_at) WHERE state='PENDING';
CREATE TABLE product_auth_throttle (
 bucket_hash bytea NOT NULL CHECK(octet_length(bucket_hash)=32),purpose text NOT NULL,
 window_start timestamptz NOT NULL,count integer NOT NULL CHECK(count>=0),PRIMARY KEY(bucket_hash,purpose)
);
ALTER TABLE role ADD COLUMN product_mfa_required boolean NOT NULL DEFAULT true;
ALTER TABLE auth_session ADD COLUMN product_environment text CHECK(product_environment IN('test','staging','production')),
 ADD COLUMN assurance text CHECK(assurance IN('OTP','PASSWORD','MFA')),
 ADD COLUMN credential_version integer CHECK(credential_version>0),ADD COLUMN authenticated_at timestamptz,
 ADD COLUMN mfa_at timestamptz,ADD COLUMN device_label text CHECK(length(device_label)<=160),ADD COLUMN revocation_reason text;
CREATE INDEX product_live_sessions ON auth_session(user_id,business_id,expires_at) WHERE revoked_at IS NULL;

-- A SQL function returning a denial must COMMIT attempt counters, not raise/roll them back.
CREATE FUNCTION ms_b1_design.product_throttle(k bytea,p text,maximum integer,seconds integer) RETURNS boolean
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE n integer;BEGIN
 IF octet_length(k)<>32 OR maximum NOT BETWEEN 1 AND 1000 OR seconds NOT BETWEEN 1 AND 86400 THEN RETURN false;END IF;
 INSERT INTO ms_b1_design.product_auth_throttle(bucket_hash,purpose,window_start,count) VALUES(k,p,clock_timestamp(),1)
 ON CONFLICT(bucket_hash,purpose) DO UPDATE SET
 count=CASE WHEN product_auth_throttle.window_start+make_interval(secs=>seconds)<=clock_timestamp() THEN 1 ELSE product_auth_throttle.count+1 END,
 window_start=CASE WHEN product_auth_throttle.window_start+make_interval(secs=>seconds)<=clock_timestamp() THEN clock_timestamp() ELSE product_auth_throttle.window_start END
 RETURNING count INTO n;RETURN n<=maximum;
END $$;
CREATE FUNCTION ms_b1_design.product_runtime_view() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('environment',environment,'businessId',business_id,'origin',public_origin,'sessionSeconds',session_seconds,'idleSeconds',idle_seconds) FROM ms_b1_design.product_runtime WHERE singleton
$$;
CREATE FUNCTION ms_b1_design.product_issue_session(u uuid,level text,h bytea,c bytea,device text) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE cfg ms_b1_design.product_runtime;v integer;sid uuid;BEGIN
 SELECT * INTO STRICT cfg FROM ms_b1_design.product_runtime WHERE singleton;
 IF octet_length(h)<>32 OR octet_length(c)<>32 OR level NOT IN('OTP','PASSWORD','MFA') THEN PERFORM ms_b1_design.b3_fail('INVALID_SESSION_EVIDENCE');END IF;
 SELECT coalesce(a.credential_version,x.identity_version) INTO v FROM ms_b1_design.customer_contact x LEFT JOIN ms_b1_design.product_admin_credential a ON a.user_id=x.user_id WHERE x.user_id=u;
 IF v IS NULL THEN PERFORM ms_b1_design.b3_fail('VERIFIED_IDENTITY_REQUIRED','MS403');END IF;
 INSERT INTO ms_b1_design.auth_session(user_id,business_id,token_hash,csrf_hash,expires_at,idle_expires_at,product_environment,assurance,credential_version,authenticated_at,mfa_at,device_label,created_by)
 VALUES(u,cfg.business_id,h,c,clock_timestamp()+make_interval(secs=>cfg.session_seconds),clock_timestamp()+make_interval(secs=>cfg.idle_seconds),cfg.environment,level,v,clock_timestamp(),CASE WHEN level='MFA' THEN clock_timestamp() END,left(device,160),u) RETURNING id INTO sid;
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by)
 VALUES(cfg.business_id,u,'auth.session.created','session',sid,gen_random_uuid(),jsonb_build_object('assurance',level),u);
 RETURN jsonb_build_object('authenticated',true,'userId',u,'maxAge',cfg.session_seconds);
END $$;
REVOKE ALL ON product_runtime,customer_contact,product_admin_credential,product_admin_invitation,product_recovery_code,product_auth_challenge,product_auth_throttle FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
REVOKE ALL ON FUNCTION ms_b1_design.product_throttle(bytea,text,integer,integer),ms_b1_design.product_issue_session(uuid,text,bytea,bytea,text) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
REVOKE ALL ON FUNCTION ms_b1_design.product_runtime_view() FROM PUBLIC;
GRANT USAGE ON SCHEMA ms_b1_design TO ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_runtime_view() TO ms_b1b_api,ms_product_auth,ms_product_worker;
