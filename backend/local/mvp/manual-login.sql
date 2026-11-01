-- Offline opt-in for the marked disposable local review DB ONLY.
-- Not part of the production/core migration chain; no new tables or identity seeds.
CREATE OR REPLACE FUNCTION ms_b1_design.mvp_local_issue_session(u uuid,b uuid,h bytea,c bytea,r uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE sid uuid;
BEGIN
 IF current_database()<>'ms_mvp_dev' OR
    shobj_description((SELECT oid FROM pg_database WHERE datname=current_database()),'pg_database') IS DISTINCT FROM 'mohammadstyle-mvp-disposable-v1'
 THEN RAISE EXCEPTION USING ERRCODE='MS403',MESSAGE='Local review only'; END IF;
 IF octet_length(h) IS DISTINCT FROM 32 OR octet_length(c) IS DISTINCT FROM 32 OR r IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='MS422',MESSAGE='Invalid session evidence'; END IF;
 -- The caller cannot create/verify identities or assign privileges.
 PERFORM 1 FROM ms_b1_design.app_user x WHERE x.id=u AND x.status='ACTIVE'
   AND x.archived_at IS NULL AND x.display_name LIKE 'B4 SYNTHETIC %' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='MS401',MESSAGE='Unauthenticated'; END IF;
 PERFORM 1 FROM ms_b1_design.business x WHERE x.id=b AND x.archived_at IS NULL
   AND x.slug LIKE 'b4-synthetic-%' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='MS401',MESSAGE='Unauthenticated'; END IF;
 PERFORM 1 FROM ms_b1_design.auth_identity x WHERE x.user_id=u
   AND x.provider='B4_ISOLATED_TEST' AND x.verified_at IS NOT NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='MS401',MESSAGE='Unauthenticated'; END IF;
 PERFORM 1 FROM ms_b1_design.user_role_assignment x JOIN ms_b1_design.role y
   ON y.id=x.role_id AND y.business_id=x.business_id
   WHERE x.user_id=u AND x.business_id=b AND x.branch_id IS NULL
   AND x.revoked_at IS NULL AND x.archived_at IS NULL AND y.archived_at IS NULL FOR SHARE OF x,y;
 IF NOT FOUND OR NOT ms_b1_design.b1b_can(jsonb_build_object('userId',u,'businessId',b),'branch.manage',NULL)
 THEN RAISE EXCEPTION USING ERRCODE='MS403',MESSAGE='Forbidden'; END IF;
 -- Serialize admissions for this existing identity without rotating other sessions.
 PERFORM pg_advisory_xact_lock(hashtextextended('local-review:'||u::text,0));
 IF (SELECT count(*) FROM ms_b1_design.auth_session WHERE user_id=u AND business_id=b
     AND created_by=u AND revoked_at IS NULL AND expires_at>clock_timestamp()
     AND idle_expires_at>clock_timestamp())>=20
 THEN RAISE EXCEPTION USING ERRCODE='MS429',MESSAGE='Session limit'; END IF;
 INSERT INTO ms_b1_design.auth_session(user_id,business_id,token_hash,csrf_hash,expires_at,idle_expires_at,created_by)
 VALUES(u,b,h,c,clock_timestamp()+interval '1 hour',clock_timestamp()+interval '15 minutes',u) RETURNING id INTO sid;
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by)
 VALUES(b,u,'local-review.session.created','session',sid,r,jsonb_build_object('environment','mvp-local'),u);
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.mvp_local_issue_session(uuid,uuid,bytea,bytea,uuid) FROM PUBLIC,ms_b1b_api,ms_b1a_runtime;
GRANT USAGE ON SCHEMA ms_b1_design TO ms_mvp_local_login;
GRANT EXECUTE ON FUNCTION ms_b1_design.mvp_local_issue_session(uuid,uuid,bytea,bytea,uuid) TO ms_mvp_local_login;
