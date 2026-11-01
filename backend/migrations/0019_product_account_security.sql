SET search_path=pg_catalog;
CREATE OR REPLACE FUNCTION ms_b1_design.product_auth_context(id uuid,binding bytea) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('id',x.id,'kind',x.kind,'lookup',encode(x.mobile_lookup,'hex'),'userId',x.user_id,'credentialVersion',x.credential_version,
 'username',a.username,'totpCiphertext',a.totp_ciphertext,'totpVerified',a.totp_verified_at IS NOT NULL,'lastCounter',a.totp_last_counter::text)
 FROM ms_b1_design.product_auth_challenge x LEFT JOIN ms_b1_design.product_admin_credential a ON a.user_id=x.user_id
 WHERE x.id=$1 AND x.binding_hash=$2 AND x.state IN('PENDING','VERIFIED') AND x.attempts<5 AND x.expires_at>clock_timestamp()
$$;
CREATE FUNCTION ms_b1_design.product_account(h bytea) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h);
 RETURN(SELECT jsonb_build_object('id',u.id,'displayName',u.display_name,'mobileLastFour',c.mobile_last_four,'verifiedAt',ms_b1_design.b3_iso(c.verified_at),'notificationsOptIn',c.notifications_opt_in,
 'administrator',EXISTS(SELECT 1 FROM ms_b1_design.product_admin_credential p WHERE p.user_id=u.id),'currentAssurance',s.assurance)
 FROM ms_b1_design.app_user u JOIN ms_b1_design.customer_contact c ON c.user_id=u.id JOIN ms_b1_design.auth_session s ON s.token_hash=h WHERE u.id=(a->>'userId')::uuid);
END $$;
CREATE FUNCTION ms_b1_design.product_account_update(h bytea,c bytea,display_name text,opt_in boolean) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h,c,true);
 IF display_name IS NOT NULL AND(length(display_name)>100 OR display_name ~ '[\x00-\x08\x0B\x0C\x0E-\x1F]') THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 UPDATE ms_b1_design.app_user SET display_name=nullif(btrim($3),''),row_version=row_version+1,updated_at=clock_timestamp() WHERE id=(a->>'userId')::uuid;
 UPDATE ms_b1_design.customer_contact SET notifications_opt_in=opt_in,updated_at=clock_timestamp() WHERE user_id=(a->>'userId')::uuid;
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by)
 VALUES((a->>'businessId')::uuid,(a->>'userId')::uuid,'account.profile.updated','user',(a->>'userId')::uuid,gen_random_uuid(),jsonb_build_object('notificationsOptIn',opt_in),(a->>'userId')::uuid);
 RETURN ms_b1_design.product_account(h);
END $$;
CREATE FUNCTION ms_b1_design.product_owner_mfa_guard() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
BEGIN IF NEW.role_key='OWNER' AND NOT NEW.product_mfa_required THEN PERFORM ms_b1_design.b3_fail('OWNER_MFA_REQUIRED','MS403');END IF;RETURN NEW;END $$;
CREATE TRIGGER product_owner_mfa BEFORE INSERT OR UPDATE ON ms_b1_design.role FOR EACH ROW EXECUTE FUNCTION ms_b1_design.product_owner_mfa_guard();
REVOKE ALL ON FUNCTION ms_b1_design.product_account(bytea),ms_b1_design.product_account_update(bytea,bytea,text,boolean),ms_b1_design.product_owner_mfa_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_account(bytea),ms_b1_design.product_account_update(bytea,bytea,text,boolean) TO ms_b1b_api;
