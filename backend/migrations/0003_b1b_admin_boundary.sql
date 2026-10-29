-- B1B forward migration. No identity seeds and no change to B1A runtime grants.
-- API receives EXECUTE only. All object names are schema-qualified; no dynamic SQL.
SET search_path = pg_catalog;
ALTER TABLE ms_b1_design.auth_session
  ADD COLUMN business_id uuid REFERENCES ms_b1_design.business(id) ON DELETE RESTRICT,
  ADD COLUMN csrf_hash bytea,
  ADD COLUMN idle_expires_at timestamptz,
  ADD CONSTRAINT b1b_csrf_length CHECK (csrf_hash IS NULL OR octet_length(csrf_hash)=32),
  ADD CONSTRAINT b1b_idle_expiry CHECK (idle_expires_at IS NULL OR
    (isfinite(idle_expires_at) AND idle_expires_at > created_at AND idle_expires_at <= expires_at));

-- Private helpers execute only inside reviewed definer entry points.
CREATE FUNCTION ms_b1_design.b1b_actor(h bytea, csrf bytea DEFAULT NULL, mutation boolean DEFAULT false)
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

CREATE FUNCTION ms_b1_design.b1b_can(a jsonb, permission_key text, target_branch uuid)
RETURNS boolean LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT EXISTS(SELECT 1 FROM ms_b1_design.user_role_assignment x
 JOIN ms_b1_design.role r ON r.business_id=x.business_id AND r.id=x.role_id
 JOIN ms_b1_design.role_permission rp ON rp.business_id=r.business_id AND rp.role_id=r.id
 JOIN ms_b1_design.permission p ON p.id=rp.permission_id
 WHERE x.user_id=(a->>'userId')::uuid AND x.business_id=(a->>'businessId')::uuid
 AND x.revoked_at IS NULL AND x.archived_at IS NULL AND r.archived_at IS NULL
 AND rp.archived_at IS NULL AND p.archived_at IS NULL AND p.permission_key=$2
 AND (x.branch_id IS NULL OR ($3 IS NOT NULL AND x.branch_id=$3 AND EXISTS
   (SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=x.business_id AND b.id=x.branch_id AND b.archived_at IS NULL))))
$$;

CREATE FUNCTION ms_b1_design.b1b_session(h bytea)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;
BEGIN
 a:=ms_b1_design.b1b_actor(h);
 RETURN (a-'sessionId')||jsonb_build_object('authenticated',true,'assignments',coalesce((SELECT jsonb_agg(jsonb_build_object(
   'role',r.role_key,'branchId',x.branch_id,'permission',p.permission_key) ORDER BY r.role_key,p.permission_key,x.branch_id)
   FROM ms_b1_design.user_role_assignment x JOIN ms_b1_design.role r ON r.business_id=x.business_id AND r.id=x.role_id
   JOIN ms_b1_design.role_permission rp ON rp.business_id=r.business_id AND rp.role_id=r.id
   JOIN ms_b1_design.permission p ON p.id=rp.permission_id WHERE x.user_id=(a->>'userId')::uuid
   AND x.business_id=(a->>'businessId')::uuid AND x.revoked_at IS NULL AND x.archived_at IS NULL
   AND r.archived_at IS NULL AND rp.archived_at IS NULL AND p.archived_at IS NULL),'[]'::jsonb));
END $$;

-- Safe projections: monetary amounts and versions remain lossless decimal strings.
CREATE FUNCTION ms_b1_design.b1b_view(kind text, value jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
 result:=jsonb_build_object('id',value->'id','version',value->>'row_version');
 IF kind='business' THEN RETURN result||jsonb_build_object('brandName',value->'brand_name','legalName',value->'legal_name','currency',value->'currency_code'); END IF;
 IF kind IN ('branch','service') THEN
  result:=result||jsonb_build_object('code',value->'code','displayName',value->'display_name','active',value->'active');
  IF kind='service' THEN RETURN result||jsonb_build_object('description',value->'description'); END IF;
  RETURN result||jsonb_build_object('address',value->'address','timeZone',value->'time_zone','bookable',value->'bookable','configurationVersion',value->>'configuration_version');
 END IF;
 RETURN result||jsonb_build_object('branchId',value->'branch_id','serviceId',value->'service_id','active',value->'active',
  'price',CASE WHEN value->>'price_rial' IS NULL THEN NULL ELSE jsonb_build_object('amountRial',value->>'price_rial','currency','IRR','unitVersion','IRR_RIAL_V1') END,
  'durationMinutes',value->'duration_minutes','bufferBeforeMinutes',value->'buffer_before_minutes','bufferAfterMinutes',value->'buffer_after_minutes',
  'configurationVersion',value->>'configuration_version','resourcesConfirmed',value->'resources_confirmed','eligibleStaffIds','[]'::jsonb,
  'resourceRequirements',coalesce((SELECT jsonb_agg(jsonb_build_object('kind',r.resource_kind,'quantity',r.quantity) ORDER BY r.resource_kind)
   FROM ms_b1_design.offering_resource_requirement r WHERE r.business_id=(value->>'business_id')::uuid
   AND r.offering_id=(value->>'id')::uuid AND r.archived_at IS NULL),'[]'::jsonb));
END $$;

CREATE FUNCTION ms_b1_design.b1b_read(h bytea, kind text, target_branch uuid, page_size integer, page_offset integer, sort_order text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb; bid uuid; permission_key text; items jsonb;
BEGIN
 a:=ms_b1_design.b1b_actor(h);bid:=(a->>'businessId')::uuid;
 IF kind NOT IN ('business','branch','service','offering') OR kind IS NULL OR page_size NOT BETWEEN 1 AND 100
 OR page_offset NOT BETWEEN 0 AND 10000 OR sort_order NOT IN ('asc','desc') OR page_size IS NULL OR page_offset IS NULL OR sort_order IS NULL THEN
 RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Invalid query'; END IF;
 permission_key:=CASE kind WHEN 'business' THEN 'business.read' WHEN 'branch' THEN 'branch.read' WHEN 'service' THEN 'catalog.read' ELSE 'offering.read' END;
 IF kind='offering' THEN
  IF NOT ms_b1_design.b1b_can(a,permission_key,target_branch) THEN RAISE EXCEPTION USING ERRCODE='MS403', MESSAGE='Forbidden'; END IF;
  IF NOT EXISTS(SELECT 1 FROM ms_b1_design.branch WHERE business_id=bid AND id=target_branch AND archived_at IS NULL) THEN
   RAISE EXCEPTION USING ERRCODE='MS404', MESSAGE='Not found'; END IF;
 ELSIF NOT ms_b1_design.b1b_can(a,permission_key,NULL) AND NOT(kind='branch' AND EXISTS(
   SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND b.archived_at IS NULL AND ms_b1_design.b1b_can(a,permission_key,b.id))) THEN
  RAISE EXCEPTION USING ERRCODE='MS403', MESSAGE='Forbidden';
 END IF;
 PERFORM set_config('ms.business_id',bid::text,true);
 SELECT coalesce(jsonb_agg(v ORDER BY ord),'[]'::jsonb) INTO items FROM (
  SELECT ms_b1_design.b1b_view(kind,value) v,row_number() OVER(ORDER BY
    CASE WHEN sort_order='asc' THEN value->>'code' END ASC,
    CASE WHEN sort_order='desc' THEN value->>'code' END DESC,value->>'id') ord FROM (
    SELECT to_jsonb(b) value FROM ms_b1_design.business b WHERE kind='business' AND b.id=bid AND b.archived_at IS NULL
    UNION ALL SELECT to_jsonb(b) FROM ms_b1_design.branch b WHERE kind='branch' AND b.business_id=bid AND b.archived_at IS NULL AND ms_b1_design.b1b_can(a,permission_key,b.id)
    UNION ALL SELECT to_jsonb(s) FROM ms_b1_design.service s WHERE kind='service' AND s.business_id=bid AND s.archived_at IS NULL
    UNION ALL SELECT to_jsonb(o) FROM ms_b1_design.branch_service_offering o WHERE kind='offering' AND o.business_id=bid AND o.branch_id=target_branch AND o.archived_at IS NULL
  ) all_rows ORDER BY ord LIMIT page_size OFFSET page_offset
 ) projected;
 RETURN jsonb_build_object('items',items,'limit',page_size,'offset',page_offset);
END $$;

CREATE FUNCTION ms_b1_design.b1b_validate(kind text, d jsonb)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE allowed text[]; k text; n text;
BEGIN
 IF jsonb_typeof(d) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Invalid DTO'; END IF;
 allowed:=CASE kind WHEN 'branch' THEN ARRAY['code','displayName','address','timeZone','active','bookable']
 WHEN 'service' THEN ARRAY['code','displayName','description','active']
 WHEN 'offering' THEN ARRAY['serviceId','active','price','durationMinutes','bufferBeforeMinutes','bufferAfterMinutes','eligibleStaffIds','resourcesConfirmed','resourceRequirements']
 WHEN 'session' THEN ARRAY[]::text[] ELSE NULL END;
 IF allowed IS NULL OR NOT(d ?& allowed) OR EXISTS(SELECT 1 FROM jsonb_object_keys(d) x WHERE NOT(x=ANY(allowed))) THEN
 RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Unknown or missing field'; END IF;
 IF kind='session' THEN RETURN; END IF;
 IF jsonb_typeof(d->'active')<>'boolean' THEN RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Invalid active'; END IF;
 IF kind IN ('branch','service') THEN
  IF jsonb_typeof(d->'code')<>'string' OR (d->>'code') !~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'
   OR jsonb_typeof(d->'displayName')<>'string' OR length(btrim(d->>'displayName')) NOT BETWEEN 1 AND 200 THEN
   RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Invalid code or name'; END IF;
  k:=CASE kind WHEN 'branch' THEN 'address' ELSE 'description' END;
  IF jsonb_typeof(d->k) NOT IN ('null','string') OR length(d->>k)>(CASE kind WHEN 'branch' THEN 1000 ELSE 2000 END) THEN
   RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Invalid text'; END IF;
 END IF;
 IF kind='branch' AND (d->'bookable' IS DISTINCT FROM 'false'::jsonb OR jsonb_typeof(d->'timeZone')<>'string' OR NOT EXISTS
  (SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=d->>'timeZone' AND name !~ '^(posix|right)/' AND (name='UTC' OR position('/' IN name)>0))) THEN
  RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Branch not bookable in B1B or invalid IANA timezone'; END IF;
 IF kind='offering' THEN
  IF d->'active' IS DISTINCT FROM 'false'::jsonb OR d->'resourcesConfirmed' IS DISTINCT FROM 'false'::jsonb
   OR d->'eligibleStaffIds' IS DISTINCT FROM '[]'::jsonb OR d->'resourceRequirements' IS DISTINCT FROM '[]'::jsonb
   OR jsonb_typeof(d->'serviceId')<>'string' OR (d->>'serviceId') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
   RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Inactive unverified offering required'; END IF;
  FOREACH k IN ARRAY ARRAY['durationMinutes','bufferBeforeMinutes','bufferAfterMinutes'] LOOP
   n:=d->>k;
   IF jsonb_typeof(d->k)<>'null' AND (jsonb_typeof(d->k)<>'number' OR n !~ '^(0|[1-9][0-9]{0,9})$' OR n::numeric>2147483647 OR (k='durationMinutes' AND n::numeric=0)) THEN
    RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Invalid duration or buffer'; END IF;
  END LOOP;
  IF d->'price'<>'null'::jsonb THEN
   IF jsonb_typeof(d->'price')<>'object' OR NOT(d->'price' ?& ARRAY['amountRial','currency','unitVersion'])
   OR (SELECT count(*) FROM jsonb_object_keys(d->'price'))<>3 OR d->'price'->>'currency'<>'IRR' OR d->'price'->>'unitVersion'<>'IRR_RIAL_V1'
   OR jsonb_typeof(d->'price'->'amountRial')<>'string' OR (d->'price'->>'amountRial') !~ '^(0|[1-9][0-9]*0)$'
   OR length(d->'price'->>'amountRial')>19 OR (d->'price'->>'amountRial')::numeric>9223372036854775807 THEN
    RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Invalid money'; END IF;
  END IF;
 END IF;
END $$;

CREATE FUNCTION ms_b1_design.b1b_command(h bytea, csrf bytea, kind text, entity_id uuid, target_branch uuid,
 expected_version bigint, idem_key text, request_id uuid, d jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb; bid uuid; uid uuid; creating boolean; permission_key text; route text; digest bytea;
 prior ms_b1_design.idempotency_record; saved jsonb; result jsonb; target uuid; version bigint; status_code integer;
BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;
 PERFORM ms_b1_design.b1b_validate(kind,d);
 creating:=entity_id IS NULL;
 IF idem_key IS NULL OR idem_key !~ '^[A-Za-z0-9_-]{16,128}$' OR request_id IS NULL OR
 (NOT creating AND kind<>'session' AND (expected_version IS NULL OR expected_version<1)) THEN
 RAISE EXCEPTION USING ERRCODE='MS412', MESSAGE='Command precondition required'; END IF;
 IF kind='branch' THEN
  IF creating AND target_branch IS NOT NULL OR NOT creating AND target_branch IS DISTINCT FROM entity_id THEN
   RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Invalid branch target'; END IF;
  permission_key:='branch.manage';
 ELSIF kind='service' THEN
  IF target_branch IS NOT NULL THEN RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Invalid service target'; END IF;
  permission_key:='catalog.manage';
 ELSIF kind='offering' THEN
  IF target_branch IS NULL THEN RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Branch required'; END IF;
  permission_key:='offering.manage';
 ELSIF kind='session' THEN
  IF entity_id IS NOT NULL OR target_branch IS NOT NULL THEN RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Invalid session target'; END IF;
 ELSE RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Invalid command'; END IF;
 IF kind<>'session' AND NOT ms_b1_design.b1b_can(a,permission_key,target_branch) THEN
  RAISE EXCEPTION USING ERRCODE='MS403', MESSAGE='Forbidden'; END IF;
 -- Recheck authorization before replay, then serialize durable identity by actor+route+key.
 route:=kind||':'||coalesce(entity_id::text,'create')||':'||coalesce(target_branch::text,'business');
 digest:=sha256(convert_to(jsonb_build_object('body',d,'ifMatch',expected_version)::text,'UTF8'));
 PERFORM pg_advisory_xact_lock(hashtextextended(bid::text||uid::text||route||idem_key,0));
 SELECT * INTO prior FROM ms_b1_design.idempotency_record WHERE business_id=bid AND actor_key=uid::text AND route_key=route AND idempotency_key=idem_key FOR UPDATE;
 IF FOUND THEN
  IF prior.request_hash<>digest OR prior.state<>'COMPLETE' OR prior.expires_at<=clock_timestamp() THEN
   RAISE EXCEPTION USING ERRCODE='MS409', MESSAGE='Idempotency conflict'; END IF;
  RETURN prior.response_snapshot;
 END IF;
 PERFORM set_config('ms.business_id',bid::text,true);
 IF kind='offering' THEN
  PERFORM 1 FROM ms_b1_design.branch WHERE business_id=bid AND id=target_branch AND archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='MS404', MESSAGE='Not found'; END IF;
  PERFORM 1 FROM ms_b1_design.service WHERE business_id=bid AND id=(d->>'serviceId')::uuid AND archived_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='MS404', MESSAGE='Not found'; END IF;
 END IF;
 IF NOT creating AND kind<>'session' THEN
  IF kind='branch' THEN SELECT to_jsonb(b) INTO saved FROM ms_b1_design.branch b WHERE business_id=bid AND id=entity_id AND archived_at IS NULL FOR UPDATE;
  ELSIF kind='service' THEN SELECT to_jsonb(s) INTO saved FROM ms_b1_design.service s WHERE business_id=bid AND id=entity_id AND archived_at IS NULL FOR UPDATE;
  ELSE SELECT to_jsonb(o) INTO saved FROM ms_b1_design.branch_service_offering o WHERE business_id=bid AND id=entity_id AND branch_id=target_branch AND archived_at IS NULL FOR UPDATE; END IF;
  IF saved IS NULL THEN RAISE EXCEPTION USING ERRCODE='MS404', MESSAGE='Not found'; END IF;
  IF (saved->>'row_version')::bigint<>expected_version THEN RAISE EXCEPTION USING ERRCODE='MS412', MESSAGE='Stale version'; END IF;
  IF kind='offering' AND ((saved->>'resources_confirmed')::boolean OR EXISTS(SELECT 1 FROM ms_b1_design.offering_resource_requirement
    WHERE business_id=bid AND offering_id=entity_id AND archived_at IS NULL)) THEN
   RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Existing workforce/resource configuration requires later reviewed command'; END IF;
  IF kind IN ('branch','service') AND saved->>'code'<>d->>'code' OR kind='offering' AND saved->>'service_id'<>d->>'serviceId' THEN
   RAISE EXCEPTION USING ERRCODE='MS422', MESSAGE='Stable identity cannot change'; END IF;
 END IF;
 target:=coalesce(entity_id,gen_random_uuid());version:=CASE WHEN creating THEN 1 ELSE expected_version+1 END;status_code:=CASE WHEN creating THEN 201 ELSE 200 END;
 IF kind='branch' THEN
  IF creating THEN INSERT INTO ms_b1_design.branch(id,business_id,code,display_name,address,time_zone,active,created_by)
   VALUES(target,bid,d->>'code',d->>'displayName',d->>'address',d->>'timeZone',(d->>'active')::boolean,uid);
  ELSE UPDATE ms_b1_design.branch SET display_name=d->>'displayName',address=d->>'address',time_zone=d->>'timeZone',active=(d->>'active')::boolean,
   row_version=version,configuration_version=configuration_version+1,updated_at=clock_timestamp() WHERE id=target AND business_id=bid; END IF;
  SELECT ms_b1_design.b1b_view(kind,to_jsonb(b)) INTO result FROM ms_b1_design.branch b WHERE id=target AND business_id=bid;
 ELSIF kind='service' THEN
  IF creating THEN INSERT INTO ms_b1_design.service(id,business_id,code,display_name,description,active,created_by)
   VALUES(target,bid,d->>'code',d->>'displayName',d->>'description',(d->>'active')::boolean,uid);
  ELSE UPDATE ms_b1_design.service SET display_name=d->>'displayName',description=d->>'description',active=(d->>'active')::boolean,row_version=version,updated_at=clock_timestamp() WHERE id=target AND business_id=bid; END IF;
  SELECT ms_b1_design.b1b_view(kind,to_jsonb(s)) INTO result FROM ms_b1_design.service s WHERE id=target AND business_id=bid;
 ELSIF kind='offering' THEN
  IF creating THEN INSERT INTO ms_b1_design.branch_service_offering(id,business_id,branch_id,service_id,price_rial,duration_minutes,buffer_before_minutes,buffer_after_minutes,created_by)
   VALUES(target,bid,target_branch,(d->>'serviceId')::uuid,(d->'price'->>'amountRial')::bigint,(d->>'durationMinutes')::integer,(d->>'bufferBeforeMinutes')::integer,(d->>'bufferAfterMinutes')::integer,uid);
  ELSE UPDATE ms_b1_design.branch_service_offering SET price_rial=(d->'price'->>'amountRial')::bigint,duration_minutes=(d->>'durationMinutes')::integer,
   buffer_before_minutes=(d->>'bufferBeforeMinutes')::integer,buffer_after_minutes=(d->>'bufferAfterMinutes')::integer,row_version=version,configuration_version=configuration_version+1,updated_at=clock_timestamp() WHERE id=target AND business_id=bid; END IF;
  SELECT ms_b1_design.b1b_view(kind,to_jsonb(o)) INTO result FROM ms_b1_design.branch_service_offering o WHERE id=target AND business_id=bid;
 ELSE
  target:=(a->>'sessionId')::uuid;version:=1;status_code:=200;
  UPDATE ms_b1_design.auth_session SET revoked_at=clock_timestamp(),row_version=row_version+1,updated_at=clock_timestamp() WHERE id=target RETURNING row_version INTO version;
  result:=jsonb_build_object('revoked',true);
 END IF;
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,branch_id,action,target_type,target_id,request_id,redacted_change,created_by)
 VALUES(bid,uid,target_branch,kind||(CASE WHEN kind='session' THEN '.revoked' WHEN creating THEN '.created' ELSE '.updated' END),kind,target,request_id,
   jsonb_build_object('version',version::text,'fields',(SELECT jsonb_agg(x ORDER BY x) FROM jsonb_object_keys(d) x)),uid);
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at,created_by)
 VALUES(bid,kind,target,version,'admin.'||kind||'.changed',1,jsonb_build_object('id',target,'version',version::text),clock_timestamp(),uid);
 result:=jsonb_build_object('status',status_code,'body',result);
 INSERT INTO ms_b1_design.idempotency_record(business_id,actor_key,route_key,idempotency_key,request_hash,state,response_code,response_snapshot,expires_at,created_by)
 VALUES(bid,uid::text,route,idem_key,digest,'COMPLETE',status_code,result,clock_timestamp()+interval '24 hours',uid);
 RETURN result;
END $$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA ms_b1_design FROM PUBLIC;
GRANT USAGE ON SCHEMA ms_b1_design TO ms_b1b_api;
GRANT EXECUTE ON FUNCTION ms_b1_design.b1b_session(bytea),
 ms_b1_design.b1b_read(bytea,text,uuid,integer,integer,text),
 ms_b1_design.b1b_command(bytea,bytea,text,uuid,uuid,bigint,text,uuid,jsonb) TO ms_b1b_api;
-- Existing B1A role remains read/version-only; new API role has no table grants,
-- no schema CREATE, no role memberships and no access to private helpers.
