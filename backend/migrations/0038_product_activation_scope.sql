-- Distinguish the verified challenge record from an assignment SQL alias.
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
 INSERT INTO ms_b1_design.user_role_assignment(business_id,user_id,role_id) SELECT i.business_id,uid,r.id FROM ms_b1_design.role r WHERE r.business_id=i.business_id AND r.role_key='CUSTOMER' AND r.archived_at IS NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.user_role_assignment assigned WHERE assigned.business_id=i.business_id AND assigned.user_id=uid AND assigned.role_id=r.id AND assigned.revoked_at IS NULL AND assigned.archived_at IS NULL);
 UPDATE ms_b1_design.product_admin_invitation SET consumed_at=clock_timestamp() WHERE product_admin_invitation.id=i.id;
 UPDATE ms_b1_design.product_auth_challenge SET state='CONSUMED',consumed_at=clock_timestamp(),user_id=uid WHERE product_auth_challenge.id=x.id;
 INSERT INTO ms_b1_design.product_auth_challenge(id,business_id,kind,user_id,binding_hash,peer_hash,credential_version,expires_at)
 VALUES(next_id,i.business_id,'MFA_ENROLLMENT',uid,binding,x.peer_hash,1,clock_timestamp()+interval '5 minutes');
 RETURN jsonb_build_object('state','MFA_ENROLLMENT_REQUIRED','challengeId',next_id,'mfaOptional',EXISTS(SELECT 1 FROM ms_b1_design.role r WHERE r.id=i.role_id AND NOT r.product_mfa_required AND r.role_key<>'OWNER'));
END $$;

