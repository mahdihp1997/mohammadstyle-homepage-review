-- Additive integration boundary. No business data, publication grants, sessions or configuration seeds.
SET search_path=pg_catalog;
ALTER TABLE ms_b1_design.booking_status_history ADD COLUMN operator_reason text CHECK(operator_reason IS NULL OR length(btrim(operator_reason)) BETWEEN 1 AND 200);
CREATE TABLE ms_b1_design.media_asset(
 id uuid PRIMARY KEY,business_id uuid NOT NULL REFERENCES ms_b1_design.business(id),branch_id uuid,
 kind text NOT NULL CHECK(kind IN('IMAGE','VIDEO')),original_name text NOT NULL CHECK(length(original_name) BETWEEN 1 AND 240),
 original_key text NOT NULL UNIQUE CHECK(original_key ~ '^[a-f0-9-]{36}/[a-f0-9-]{36}/[a-f0-9]{64}/original[.](bin|mp4|webm|mov)$'),
 source_hash text NOT NULL CHECK(source_hash ~ '^[a-f0-9]{64}$'),source_bytes bigint NOT NULL CHECK(source_bytes BETWEEN 1 AND 33554432),
 title text NOT NULL DEFAULT '' CHECK(length(title)<=200),alt_text text NOT NULL DEFAULT '' CHECK(length(alt_text)<=500),
 state text NOT NULL DEFAULT 'READY' CHECK(state IN('READY','PUBLISHED','ARCHIVED')),row_version bigint NOT NULL DEFAULT 1 CHECK(row_version>0),
 created_by uuid NOT NULL REFERENCES ms_b1_design.app_user(id),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,id),FOREIGN KEY(business_id,branch_id) REFERENCES ms_b1_design.branch(business_id,id));
CREATE TABLE ms_b1_design.media_variant(
 business_id uuid NOT NULL,asset_id uuid NOT NULL,name text NOT NULL CHECK(name IN('THUMB','DISPLAY','VIDEO')),
 storage_key text NOT NULL UNIQUE CHECK(storage_key ~ '^[a-f0-9-]{36}/[a-f0-9-]{36}/[a-f0-9]{64}/(thumb[.]webp|display[.]webp|video[.]mp4)$'),
 mime text NOT NULL CHECK(mime IN('image/webp','video/mp4')),bytes bigint NOT NULL CHECK(bytes BETWEEN 1 AND 67108864),
 sha256 text NOT NULL CHECK(sha256 ~ '^[a-f0-9]{64}$'),width integer NOT NULL CHECK(width BETWEEN 1 AND 1920),height integer NOT NULL CHECK(height BETWEEN 1 AND 1920),
 duration_ms integer CHECK(duration_ms BETWEEN 1 AND 120000),PRIMARY KEY(business_id,asset_id,name),FOREIGN KEY(business_id,asset_id) REFERENCES ms_b1_design.media_asset(business_id,id),
 CHECK((name='VIDEO' AND mime='video/mp4' AND duration_ms IS NOT NULL) OR(name<>'VIDEO' AND mime='image/webp' AND duration_ms IS NULL)));
CREATE TABLE ms_b1_design.media_category(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL REFERENCES ms_b1_design.business(id),
 name text NOT NULL CHECK(length(btrim(name)) BETWEEN 1 AND 100),slug text NOT NULL CHECK(slug ~ '^[a-z0-9][a-z0-9-]{0,63}$'),
 active boolean NOT NULL DEFAULT true,row_version bigint NOT NULL DEFAULT 1 CHECK(row_version>0),created_by uuid NOT NULL REFERENCES ms_b1_design.app_user(id),
 UNIQUE(business_id,id),UNIQUE(business_id,slug));
CREATE TABLE ms_b1_design.media_asset_category(
 business_id uuid NOT NULL,asset_id uuid NOT NULL,category_id uuid NOT NULL,PRIMARY KEY(business_id,asset_id,category_id),
 FOREIGN KEY(business_id,asset_id) REFERENCES ms_b1_design.media_asset(business_id,id),FOREIGN KEY(business_id,category_id) REFERENCES ms_b1_design.media_category(business_id,id));
CREATE INDEX media_category_assets_fk ON ms_b1_design.media_asset_category(business_id,category_id,asset_id);
CREATE TABLE ms_b1_design.media_rights_event(
 seq bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,business_id uuid NOT NULL,asset_id uuid NOT NULL,
 action text NOT NULL CHECK(action IN('GRANT','REVOKE')),scope text NOT NULL CHECK(scope='PUBLIC_WEBSITE'),
 evidence_reference text NOT NULL CHECK(length(btrim(evidence_reference)) BETWEEN 1 AND 2000),
 confirmed boolean NOT NULL CHECK(confirmed),valid_until timestamptz CHECK(valid_until IS NULL OR isfinite(valid_until)),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),created_by uuid NOT NULL REFERENCES ms_b1_design.app_user(id),
 FOREIGN KEY(business_id,asset_id) REFERENCES ms_b1_design.media_asset(business_id,id),CHECK(valid_until IS NULL OR valid_until>created_at));
CREATE INDEX media_rights_current ON ms_b1_design.media_rights_event(business_id,asset_id,seq DESC);
CREATE INDEX media_published_page ON ms_b1_design.media_asset(business_id,state,created_at DESC,id);
CREATE INDEX media_branch_fk ON ms_b1_design.media_asset(business_id,branch_id);

CREATE FUNCTION ms_b1_design.mvp_immutable() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$ BEGIN RAISE EXCEPTION USING ERRCODE='MS409',MESSAGE='IMMUTABLE_MEDIA_EVIDENCE';END $$;
CREATE TRIGGER media_rights_immutable BEFORE UPDATE OR DELETE ON ms_b1_design.media_rights_event FOR EACH ROW EXECUTE FUNCTION ms_b1_design.mvp_immutable();
CREATE TRIGGER media_variant_immutable BEFORE UPDATE OR DELETE ON ms_b1_design.media_variant FOR EACH ROW EXECUTE FUNCTION ms_b1_design.mvp_immutable();
CREATE FUNCTION ms_b1_design.mvp_asset_guard() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF TG_OP='DELETE' OR(to_jsonb(NEW)-ARRAY['title','alt_text','state','row_version','updated_at']) IS DISTINCT FROM(to_jsonb(OLD)-ARRAY['title','alt_text','state','row_version','updated_at']) THEN RAISE EXCEPTION USING ERRCODE='MS409',MESSAGE='IMMUTABLE_MEDIA_EVIDENCE';END IF;RETURN NEW;END $$;
CREATE TRIGGER media_asset_original_immutable BEFORE UPDATE OR DELETE ON ms_b1_design.media_asset FOR EACH ROW EXECUTE FUNCTION ms_b1_design.mvp_asset_guard();
CREATE FUNCTION ms_b1_design.mvp_actor(h bytea,c bytea,writing boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ DECLARE a jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h,c,writing);
 IF writing AND NOT EXISTS(SELECT 1 FROM ms_b1_design.auth_identity WHERE user_id=(a->>'userId')::uuid AND verified_at IS NOT NULL) THEN PERFORM ms_b1_design.b3_fail('VERIFIED_IDENTITY_REQUIRED','MS403');END IF;RETURN a;END $$;
CREATE FUNCTION ms_b1_design.mvp_media_allowed(a jsonb,branch uuid,perm text) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF NOT ms_b1_design.b1b_can(a,perm,branch) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF branch IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch br WHERE br.business_id=(a->>'businessId')::uuid AND br.id=branch AND br.archived_at IS NULL) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;END $$;
CREATE FUNCTION ms_b1_design.mvp_rights_current(bid uuid,asset uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT coalesce((SELECT action='GRANT' AND(valid_until IS NULL OR valid_until>clock_timestamp()) FROM ms_b1_design.media_rights_event WHERE business_id=bid AND asset_id=asset ORDER BY seq DESC LIMIT 1),false) $$;
CREATE FUNCTION ms_b1_design.mvp_media_authorize(h bytea,c bytea,branch uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;BEGIN a:=ms_b1_design.mvp_actor(h,c,true);PERFORM ms_b1_design.mvp_media_allowed(a,branch,'media.manage');RETURN a- 'sessionId';END $$;
CREATE FUNCTION ms_b1_design.mvp_media_view(m ms_b1_design.media_asset,private_view boolean) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('id',m.id,'kind',m.kind,'title',m.title,'altText',m.alt_text,'categories',coalesce((SELECT jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'slug',c.slug) ORDER BY c.name) FROM ms_b1_design.media_asset_category x JOIN ms_b1_design.media_category c ON c.business_id=x.business_id AND c.id=x.category_id WHERE x.business_id=m.business_id AND x.asset_id=m.id AND c.active),'[]'),
 'variants',coalesce((SELECT jsonb_agg(jsonb_build_object('name',v.name,'mime',v.mime,'width',v.width,'height',v.height,'bytes',v.bytes::text,'durationMs',v.duration_ms) ORDER BY v.name) FROM ms_b1_design.media_variant v WHERE v.business_id=m.business_id AND v.asset_id=m.id),'[]')) ||
 CASE WHEN private_view THEN jsonb_build_object('branchId',m.branch_id,'version',m.row_version::text,'state',m.state,'originalName',m.original_name,'sourceBytes',m.source_bytes::text,'rightsConfirmed',ms_b1_design.mvp_rights_current(m.business_id,m.id),'rightsEvents',coalesce((SELECT jsonb_agg(jsonb_build_object('action',r.action,'scope',r.scope,'evidenceReference',r.evidence_reference,'validUntil',ms_b1_design.b3_iso(r.valid_until),'at',ms_b1_design.b3_iso(r.created_at)) ORDER BY r.seq DESC) FROM ms_b1_design.media_rights_event r WHERE r.business_id=m.business_id AND r.asset_id=m.id),'[]')) ELSE '{}'::jsonb END $$;
CREATE FUNCTION ms_b1_design.mvp_event(bid uuid,uid uuid,branch uuid,action text,target uuid,version bigint,requestid uuid) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,branch_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES(bid,uid,branch,action,'mvp',target,requestid,jsonb_build_object('version',version::text),uid);
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at,created_by) VALUES(bid,'mvp',target,version,action,1,jsonb_build_object('id',target,'version',version::text),clock_timestamp(),uid);END $$;

CREATE FUNCTION ms_b1_design.mvp_read(h bytea,kind text,branch uuid,entity uuid,page_offset integer,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;bid uuid;m ms_b1_design.media_asset;b ms_b1_design.booking;result jsonb;zone text;BEGIN
 a:=ms_b1_design.mvp_actor(h,NULL);bid:=(a->>'businessId')::uuid;
 IF page_offset IS NULL OR page_offset NOT BETWEEN 0 AND 10000 OR d IS NULL OR jsonb_typeof(d)<>'object' THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 IF kind IN('media','categories') THEN
 PERFORM ms_b1_design.mvp_media_allowed(a,branch,'media.manage');
 IF kind='media' THEN SELECT coalesce(jsonb_agg(ms_b1_design.mvp_media_view(x,true) ORDER BY x.created_at DESC,x.id),'[]') INTO result FROM(SELECT * FROM ms_b1_design.media_asset WHERE business_id=bid AND branch_id IS NOT DISTINCT FROM branch ORDER BY created_at DESC,id LIMIT 25 OFFSET page_offset) x;
 ELSE SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'slug',slug,'active',active,'version',row_version::text) ORDER BY name),'[]') INTO result FROM(SELECT * FROM ms_b1_design.media_category WHERE business_id=bid ORDER BY name,id LIMIT 100 OFFSET page_offset) x;END IF;
 RETURN jsonb_build_object('items',result,'limit',CASE WHEN kind='media' THEN 25 ELSE 100 END,'offset',page_offset);
 ELSIF kind='upload-receipt' THEN
 PERFORM ms_b1_design.mvp_media_allowed(a,branch,'media.manage');PERFORM ms_b1_design.b3_keys(d,ARRAY['key','hash']);
 SELECT response_snapshot INTO result FROM ms_b1_design.idempotency_record WHERE business_id=bid AND actor_key=a->>'userId' AND route_key='mvp:upload:'||coalesce(branch::text,'global') AND idempotency_key=d->>'key' AND expires_at>clock_timestamp() AND request_hash=decode(d->>'hash','hex');RETURN result;
 ELSIF kind IN('reservations','reservation') THEN
 PERFORM ms_b1_design.mvp_media_allowed(a,branch,'booking.read');
 PERFORM ms_b1_design.b4_expire_business(bid);
 IF kind='reservation' THEN SELECT * INTO b FROM ms_b1_design.booking WHERE business_id=bid AND branch_id=branch AND id=entity;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 RETURN ms_b1_design.b4_view(b)||jsonb_build_object('customerName',(SELECT display_name FROM ms_b1_design.app_user WHERE id=b.created_by),'cancellation',ms_b1_design.b4_cancellation(b,clock_timestamp()),'events',coalesce((SELECT jsonb_agg(jsonb_build_object('from',from_status,'to',to_status,'event',event_type,'reason',operator_reason,'at',ms_b1_design.b3_iso(created_at)) ORDER BY created_at,id) FROM ms_b1_design.booking_status_history WHERE business_id=bid AND booking_id=b.id),'[]'));
 END IF;
 SELECT coalesce(jsonb_agg(ms_b1_design.b4_view(x)||jsonb_build_object('customerName',(SELECT display_name FROM ms_b1_design.app_user WHERE id=x.created_by)) ORDER BY x.created_at DESC,x.id),'[]') INTO result FROM(SELECT * FROM ms_b1_design.booking WHERE business_id=bid AND branch_id=branch ORDER BY created_at DESC,id LIMIT 25 OFFSET page_offset) x;
 RETURN jsonb_build_object('items',result,'limit',25,'offset',page_offset);
 ELSIF kind='identities' THEN
 PERFORM ms_b1_design.mvp_media_allowed(a,NULL,'staff.link');
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(jsonb_build_object('id',x.id,'name',x.display_name)) FROM(SELECT DISTINCT u.id,u.display_name FROM ms_b1_design.app_user u JOIN ms_b1_design.auth_identity i ON i.user_id=u.id JOIN ms_b1_design.user_role_assignment r ON r.user_id=u.id WHERE r.business_id=bid AND r.revoked_at IS NULL AND r.archived_at IS NULL AND i.verified_at IS NOT NULL AND u.status='ACTIVE' AND u.archived_at IS NULL ORDER BY u.id LIMIT 100 OFFSET page_offset) x),'[]'));
 ELSIF kind='policy-headers' THEN
 PERFORM ms_b1_design.mvp_media_allowed(a,branch,'policy.read');
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(jsonb_build_object('id',x.id,'name',x.name,'code',x.code,'branchId',x.branch_id) ORDER BY x.code) FROM(SELECT p.* FROM ms_b1_design.booking_policy p WHERE p.business_id=bid AND(p.branch_id=branch OR p.branch_id IS NULL AND ms_b1_design.b1b_can(a,'policy.read',NULL)) ORDER BY p.code LIMIT 100 OFFSET page_offset) x),'[]'));
 ELSIF kind='instant' THEN
 PERFORM ms_b1_design.mvp_media_allowed(a,branch,'branch.read');PERFORM ms_b1_design.b3_keys(d,ARRAY['local']);SELECT br.time_zone INTO zone FROM ms_b1_design.branch br WHERE br.business_id=bid AND br.id=branch;
 IF d->>'local' !~ '^20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$' THEN PERFORM ms_b1_design.b3_fail('INVALID_LOCAL_TIME');END IF;
 RETURN jsonb_build_object('instant',ms_b1_design.b3_iso(ms_b1_design.b2b_local_instant((d->>'local')::timestamp,zone,'reject')),'timeZone',zone);
 ELSE PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;RETURN NULL;
END $$;

-- Ingest accepts only server-validated immutable derivative descriptors; it is never an HTTP DTO.
CREATE FUNCTION ms_b1_design.mvp_media_ingest(h bytea,c bytea,branch uuid,idem text,source_digest text,requestid uuid,assets jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;bid uuid;uid uuid;x jsonb;v jsonb;target uuid;prior ms_b1_design.idempotency_record;result jsonb;ids uuid[]:='{}';route text;BEGIN
 a:=ms_b1_design.mvp_actor(h,c,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.mvp_media_allowed(a,branch,'media.manage');
 IF idem IS NULL OR idem !~ '^[A-Za-z0-9_-]{16,128}$' OR source_digest !~ '^[a-f0-9]{64}$' OR jsonb_typeof(assets)<>'array' OR jsonb_array_length(assets) NOT BETWEEN 1 AND 20 THEN PERFORM ms_b1_design.b3_fail('INVALID_UPLOAD');END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('mvp:'||bid::text,0));route:='mvp:upload:'||coalesce(branch::text,'global');
 SELECT * INTO prior FROM ms_b1_design.idempotency_record WHERE business_id=bid AND actor_key=uid::text AND route_key=route AND idempotency_key=idem FOR UPDATE;
 IF FOUND THEN IF prior.request_hash<>decode(source_digest,'hex') OR prior.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('IDEMPOTENCY_CONFLICT','MS409');END IF;RETURN prior.response_snapshot;END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(assets) LOOP
 PERFORM ms_b1_design.b3_keys(x,ARRAY['id','kind','originalName','originalKey','sourceHash','sourceBytes','variants']);target:=(x->>'id')::uuid;
 IF x->>'originalKey' NOT LIKE bid::text||'/'||target::text||'/'||(x->>'sourceHash')||'/%' THEN PERFORM ms_b1_design.b3_fail('INVALID_STORAGE_KEY');END IF;
 INSERT INTO ms_b1_design.media_asset(id,business_id,branch_id,kind,original_name,original_key,source_hash,source_bytes,created_by) VALUES(target,bid,branch,x->>'kind',x->>'originalName',x->>'originalKey',x->>'sourceHash',(x->>'sourceBytes')::bigint,uid);
 IF jsonb_array_length(x->'variants')<>(CASE WHEN x->>'kind'='VIDEO' THEN 3 ELSE 2 END) THEN PERFORM ms_b1_design.b3_fail('INCOMPLETE_VARIANTS');END IF;
 FOR v IN SELECT value FROM jsonb_array_elements(x->'variants') LOOP
 PERFORM ms_b1_design.b3_keys(v,ARRAY['name','key','mime','bytes','sha256','width','height','durationMs']);
 IF v->>'key' NOT LIKE bid::text||'/'||target::text||'/'||(x->>'sourceHash')||'/%' THEN PERFORM ms_b1_design.b3_fail('INVALID_STORAGE_KEY');END IF;
 INSERT INTO ms_b1_design.media_variant(business_id,asset_id,name,storage_key,mime,bytes,sha256,width,height,duration_ms) VALUES(bid,target,v->>'name',v->>'key',v->>'mime',(v->>'bytes')::bigint,v->>'sha256',(v->>'width')::int,(v->>'height')::int,(v->>'durationMs')::int);
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.media_variant WHERE business_id=bid AND asset_id=target AND name='THUMB') OR NOT EXISTS(SELECT 1 FROM ms_b1_design.media_variant WHERE business_id=bid AND asset_id=target AND name='DISPLAY') OR(x->>'kind'='VIDEO' AND NOT EXISTS(SELECT 1 FROM ms_b1_design.media_variant WHERE business_id=bid AND asset_id=target AND name='VIDEO')) THEN PERFORM ms_b1_design.b3_fail('INCOMPLETE_VARIANTS');END IF;
 PERFORM ms_b1_design.mvp_event(bid,uid,branch,'mvp.media.ingested',target,1,requestid);ids:=array_append(ids,target);END LOOP;
 SELECT jsonb_build_object('items',jsonb_agg(ms_b1_design.mvp_media_view(m,true) ORDER BY m.id)) INTO result FROM ms_b1_design.media_asset m WHERE m.business_id=bid AND m.id=ANY(ids);
 INSERT INTO ms_b1_design.idempotency_record(business_id,actor_key,route_key,idempotency_key,request_hash,state,response_code,response_snapshot,expires_at,created_by) VALUES(bid,uid::text,route,idem,decode(source_digest,'hex'),'COMPLETE',200,result,clock_timestamp()+interval '24 hours',uid);RETURN result;
END $$;

CREATE FUNCTION ms_b1_design.mvp_command(h bytea,c bytea,op text,branch uuid,entity uuid,expected bigint,idem text,requestid uuid,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE a jsonb;bid uuid;uid uuid;perm text;prior ms_b1_design.idempotency_record;rh bytea;route text;target uuid;m ms_b1_design.media_asset;category ms_b1_design.media_category;o ms_b1_design.branch_service_offering;b ms_b1_design.booking;old_status text;result jsonb;ids uuid[];BEGIN
 a:=ms_b1_design.mvp_actor(h,c,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;
 IF op IS NULL OR op NOT IN('branch.save','service.save','offering.create','category.save','media.edit','media.rights','media.publish','media.unpublish','media.archive','offering.configure','offering.requirements','booking.cancel') OR expected IS NULL OR expected<0 OR idem IS NULL OR idem !~ '^[A-Za-z0-9_-]{16,128}$' OR requestid IS NULL THEN PERFORM ms_b1_design.b3_fail('INVALID_HEADERS');END IF;
 perm:=CASE WHEN op='branch.save' THEN 'branch.manage' WHEN op='service.save' THEN 'catalog.manage' WHEN op='booking.cancel' THEN 'booking.manage' WHEN op LIKE 'offering.%' THEN 'offering.manage' WHEN op='media.rights' THEN 'media.rights.manage' WHEN op='media.publish' THEN 'media.publish' ELSE 'media.manage' END;
 PERFORM ms_b1_design.mvp_media_allowed(a,branch,perm);
 IF op LIKE 'offering.%' OR op IN('booking.cancel','branch.save','service.save') THEN PERFORM ms_b1_design.b4_lock(bid);END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('mvp:'||bid::text,0));route:='mvp:'||op||':'||coalesce(branch::text,'global')||':'||coalesce(entity::text,'new');rh:=sha256(convert_to(jsonb_build_object('version',expected::text,'data',d)::text,'UTF8'));
 SELECT * INTO prior FROM ms_b1_design.idempotency_record WHERE business_id=bid AND actor_key=uid::text AND route_key=route AND idempotency_key=idem FOR UPDATE;
 IF FOUND THEN IF prior.request_hash<>rh OR prior.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('IDEMPOTENCY_CONFLICT','MS409');END IF;RETURN prior.response_snapshot;END IF;
 target:=coalesce(entity,gen_random_uuid());
 IF op LIKE 'media.%' THEN
 SELECT * INTO m FROM ms_b1_design.media_asset WHERE business_id=bid AND id=entity AND branch_id IS NOT DISTINCT FROM branch FOR UPDATE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF m.row_version<>expected THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF m.state='ARCHIVED' THEN PERFORM ms_b1_design.b3_fail('MEDIA_ARCHIVED','MS409');END IF;
 IF op='media.edit' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['title','altText','categoryIds']);
 IF jsonb_typeof(d->'title')<>'string' OR jsonb_typeof(d->'altText')<>'string' OR jsonb_typeof(d->'categoryIds')<>'array' OR jsonb_array_length(d->'categoryIds')>20 THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 SELECT coalesce(array_agg(value::uuid),'{}') INTO ids FROM jsonb_array_elements_text(d->'categoryIds');
 IF cardinality(ids)<>(SELECT count(DISTINCT x) FROM unnest(ids) x) OR EXISTS(SELECT 1 FROM unnest(ids) x WHERE NOT EXISTS(SELECT 1 FROM ms_b1_design.media_category WHERE business_id=bid AND id=x AND active)) THEN PERFORM ms_b1_design.b3_fail('INVALID_CATEGORY');END IF;
 IF m.state='PUBLISHED' AND(btrim(d->>'title')='' OR btrim(d->>'altText')='') THEN PERFORM ms_b1_design.b3_fail('MEDIA_TEXT_REQUIRED');END IF;
 UPDATE ms_b1_design.media_asset SET title=d->>'title',alt_text=d->>'altText',state='READY' WHERE id=m.id;
 DELETE FROM ms_b1_design.media_asset_category WHERE business_id=bid AND asset_id=m.id;
 INSERT INTO ms_b1_design.media_asset_category SELECT bid,m.id,x FROM unnest(ids) x;
 ELSIF op='media.rights' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['action','confirmed','scope','evidenceReference','validUntil']);
 IF d->'confirmed' IS DISTINCT FROM 'true'::jsonb OR jsonb_typeof(d->'evidenceReference')<>'string' OR d->>'action' NOT IN('GRANT','REVOKE') OR d->>'scope'<>'PUBLIC_WEBSITE' THEN PERFORM ms_b1_design.b3_fail('EXPLICIT_RIGHTS_REQUIRED');END IF;
 INSERT INTO ms_b1_design.media_rights_event(business_id,asset_id,action,scope,evidence_reference,confirmed,valid_until,created_by) VALUES(bid,m.id,d->>'action','PUBLIC_WEBSITE',d->>'evidenceReference',true,(d->>'validUntil')::timestamptz,uid);
 UPDATE ms_b1_design.media_asset SET state='READY' WHERE id=m.id;
 ELSE
 PERFORM ms_b1_design.b3_keys(d,ARRAY[]::text[]);
 IF op='media.publish' THEN
 IF NOT ms_b1_design.mvp_rights_current(bid,m.id) THEN PERFORM ms_b1_design.b3_fail('PUBLICATION_RIGHTS_REQUIRED','MS409');END IF;
 IF btrim(m.title)='' OR btrim(m.alt_text)='' THEN PERFORM ms_b1_design.b3_fail('MEDIA_TEXT_REQUIRED');END IF;
 END IF;
 UPDATE ms_b1_design.media_asset SET state=CASE op WHEN 'media.publish' THEN 'PUBLISHED' WHEN 'media.archive' THEN 'ARCHIVED' ELSE 'READY' END WHERE id=m.id;
 END IF;
 UPDATE ms_b1_design.media_asset SET row_version=row_version+1,updated_at=clock_timestamp() WHERE id=m.id RETURNING * INTO m;result:=ms_b1_design.mvp_media_view(m,true);
 ELSIF op='category.save' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['name','slug','active']);
 IF branch IS NOT NULL OR jsonb_typeof(d->'name')<>'string' OR jsonb_typeof(d->'slug')<>'string' OR jsonb_typeof(d->'active')<>'boolean' THEN PERFORM ms_b1_design.b3_fail('INVALID_FIELDS');END IF;
 IF entity IS NULL THEN IF expected<>0 THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;INSERT INTO ms_b1_design.media_category(id,business_id,name,slug,active,created_by) VALUES(target,bid,d->>'name',d->>'slug',(d->>'active')::boolean,uid) RETURNING * INTO category;
 ELSE SELECT * INTO category FROM ms_b1_design.media_category WHERE business_id=bid AND id=entity FOR UPDATE;IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;IF category.row_version<>expected THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 UPDATE ms_b1_design.media_category SET name=d->>'name',slug=d->>'slug',active=(d->>'active')::boolean,row_version=row_version+1 WHERE id=entity RETURNING * INTO category;END IF;
 result:=jsonb_build_object('id',category.id,'name',category.name,'slug',category.slug,'active',category.active,'version',category.row_version::text);
 ELSIF op IN('branch.save','service.save','offering.create') THEN
 IF op='branch.save' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['code','displayName','address','timeZone','active']);PERFORM ms_b1_design.b1b_validate('branch',d||jsonb_build_object('bookable',false));
 IF entity IS NULL THEN
 IF branch IS NOT NULL OR expected<>0 THEN PERFORM ms_b1_design.b3_fail('INVALID_SCOPE');END IF;
 result:=(ms_b1_design.b2b_legacy_command(h,c,'branch',NULL,NULL,NULL,idem,requestid,d||jsonb_build_object('bookable',false)))->'body';
 ELSE
 IF branch IS DISTINCT FROM entity THEN PERFORM ms_b1_design.b3_fail('INVALID_SCOPE');END IF;
 SELECT ms_b1_design.b1b_view('branch',to_jsonb(x)) INTO result FROM ms_b1_design.branch x WHERE business_id=bid AND id=entity AND archived_at IS NULL FOR UPDATE;
 IF result IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;IF result->>'version'<>expected::text THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF result->>'timeZone' IS DISTINCT FROM d->>'timeZone' AND(EXISTS(SELECT 1 FROM ms_b1_design.staff_shift WHERE business_id=bid AND branch_id=branch) OR EXISTS(SELECT 1 FROM ms_b1_design.branch_working_hours WHERE business_id=bid AND branch_id=branch) OR EXISTS(SELECT 1 FROM ms_b1_design.staff_schedule_rule WHERE business_id=bid AND branch_id=branch) OR EXISTS(SELECT 1 FROM ms_b1_design.booking WHERE business_id=bid AND branch_id=branch)) THEN PERFORM ms_b1_design.b3_fail('TIMEZONE_RECONCILIATION_REQUIRED','MS409');END IF;
 UPDATE ms_b1_design.branch SET code=d->>'code',display_name=d->>'displayName',address=d->>'address',time_zone=d->>'timeZone',active=(d->>'active')::boolean,row_version=row_version+1,configuration_version=configuration_version+1 WHERE id=entity;
 IF NOT(d->>'active')::boolean THEN UPDATE ms_b1_design.branch SET bookable=false,row_version=row_version+1,configuration_version=configuration_version+1 WHERE id=entity;END IF;
 SELECT ms_b1_design.b1b_view('branch',to_jsonb(x)) INTO result FROM ms_b1_design.branch x WHERE id=entity;
 END IF;
 ELSIF op='service.save' THEN
 IF branch IS NOT NULL THEN PERFORM ms_b1_design.b3_fail('INVALID_SCOPE');END IF;PERFORM ms_b1_design.b1b_validate('service',d);
 IF entity IS NULL THEN IF expected<>0 THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;result:=(ms_b1_design.b2b_legacy_command(h,c,'service',NULL,NULL,NULL,idem,requestid,d))->'body';
 ELSE
 SELECT ms_b1_design.b1b_view('service',to_jsonb(x)) INTO result FROM ms_b1_design.service x WHERE business_id=bid AND id=entity AND archived_at IS NULL FOR UPDATE;
 IF result IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;IF result->>'version'<>expected::text THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF NOT(d->>'active')::boolean AND EXISTS(SELECT 1 FROM ms_b1_design.staff_shift s JOIN ms_b1_design.staff_service_eligibility q ON q.business_id=s.business_id AND q.staff_id=s.staff_id WHERE s.business_id=bid AND q.service_id=entity AND s.published AND s.archived_at IS NULL AND s.ends_at>clock_timestamp()) THEN PERFORM ms_b1_design.b3_fail('PUBLISHED_SHIFT_REVIEW_REQUIRED','MS409');END IF;
 UPDATE ms_b1_design.service SET code=d->>'code',display_name=d->>'displayName',description=d->>'description',active=(d->>'active')::boolean,row_version=row_version+1 WHERE id=entity;
 SELECT ms_b1_design.b1b_view('service',to_jsonb(x)) INTO result FROM ms_b1_design.service x WHERE id=entity;END IF;
 ELSE
 PERFORM ms_b1_design.b3_keys(d,ARRAY['serviceId']);IF entity IS NOT NULL OR branch IS NULL OR expected<>0 THEN PERFORM ms_b1_design.b3_fail('INVALID_SCOPE');END IF;
 result:=(ms_b1_design.b2b_legacy_command(h,c,'offering',NULL,branch,NULL,idem,requestid,jsonb_build_object('serviceId',d->>'serviceId','active',false,'price',NULL,'durationMinutes',NULL,'bufferBeforeMinutes',NULL,'bufferAfterMinutes',NULL,'eligibleStaffIds','[]'::jsonb,'resourcesConfirmed',false,'resourceRequirements','[]'::jsonb)))->'body';
 END IF;
 target:=(result->>'id')::uuid;
 ELSIF op LIKE 'offering.%' THEN
 SELECT * INTO o FROM ms_b1_design.branch_service_offering WHERE business_id=bid AND branch_id=branch AND id=entity AND archived_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;IF o.row_version<>expected THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF op='offering.configure' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['priceRial','durationMinutes','bufferBeforeMinutes','bufferAfterMinutes']);
 IF jsonb_typeof(d->'priceRial')<>'string' OR d->>'priceRial' !~ '^(0|[1-9][0-9]*0)$' OR length(d->>'priceRial')>19 OR(d->>'priceRial')::numeric>9223372036854775807 THEN PERFORM ms_b1_design.b3_fail('INVALID_MONEY');END IF;
 IF EXISTS(SELECT 1 FROM unnest(ARRAY['durationMinutes','bufferBeforeMinutes','bufferAfterMinutes']) k WHERE jsonb_typeof(d->k)<>'number' OR d->>k !~ '^[0-9]+$' OR(d->>k)::numeric>1440) OR(d->>'durationMinutes')::int<1 THEN PERFORM ms_b1_design.b3_fail('INVALID_DURATION');END IF;
 IF (o.duration_minutes,o.buffer_before_minutes,o.buffer_after_minutes) IS DISTINCT FROM((d->>'durationMinutes')::int,(d->>'bufferBeforeMinutes')::int,(d->>'bufferAfterMinutes')::int) AND EXISTS(SELECT 1 FROM ms_b1_design.resource_allocation WHERE business_id=bid AND released_at IS NULL AND busy_ends_at>clock_timestamp()) THEN PERFORM ms_b1_design.b3_fail('LIVE_RESERVATIONS_REQUIRE_REVIEW','MS409');END IF;
 UPDATE ms_b1_design.branch_service_offering SET price_rial=(d->>'priceRial')::bigint,duration_minutes=(d->>'durationMinutes')::int,buffer_before_minutes=(d->>'bufferBeforeMinutes')::int,buffer_after_minutes=(d->>'bufferAfterMinutes')::int,row_version=row_version+1,configuration_version=configuration_version+1 WHERE id=o.id;
 ELSE
 PERFORM ms_b1_design.b3_keys(d,ARRAY['kind','quantity','confirmed']);
 IF d->>'kind' NOT IN('CHAIR','ROOM','DEVICE') OR d->'confirmed' IS DISTINCT FROM 'true'::jsonb OR jsonb_typeof(d->'quantity')<>'number' OR d->>'quantity' !~ '^[1-9][0-9]?$' OR(d->>'quantity')::int>16 THEN PERFORM ms_b1_design.b3_fail('INVALID_RESOURCE_REQUIREMENT');END IF;
 INSERT INTO ms_b1_design.offering_resource_requirement(business_id,branch_id,offering_id,service_id,resource_kind,quantity,created_by) VALUES(bid,branch,o.id,o.service_id,d->>'kind',(d->>'quantity')::int,uid)
 ON CONFLICT(business_id,offering_id,resource_kind) DO UPDATE SET quantity=excluded.quantity,row_version=offering_resource_requirement.row_version+1;
 UPDATE ms_b1_design.branch_service_offering SET resources_confirmed=true,row_version=row_version+1,configuration_version=configuration_version+1 WHERE id=o.id;
 END IF;
 SELECT ms_b1_design.b1b_view('offering',to_jsonb(x)) INTO result FROM ms_b1_design.branch_service_offering x WHERE id=o.id;
 ELSIF op='booking.cancel' THEN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['reason','confirmed']);IF jsonb_typeof(d->'reason')<>'string' OR length(btrim(d->>'reason')) NOT BETWEEN 1 AND 200 OR d->'confirmed' IS DISTINCT FROM 'true'::jsonb THEN PERFORM ms_b1_design.b3_fail('EXPLICIT_CONFIRMATION_REQUIRED');END IF;
 SELECT * INTO b FROM ms_b1_design.booking WHERE business_id=bid AND branch_id=branch AND id=entity FOR UPDATE;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;IF b.row_version<>expected THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF NOT(ms_b1_design.b4_cancellation(b,clock_timestamp())->>'cancellationAllowed')::boolean THEN PERFORM ms_b1_design.b3_fail('CANCELLATION_REQUIRES_REVIEW');END IF;
 old_status:=b.status;UPDATE ms_b1_design.resource_allocation SET released_at=clock_timestamp() WHERE business_id=bid AND revision_id=b.active_revision_id AND released_at IS NULL;
 UPDATE ms_b1_design.booking_hold SET released_at=clock_timestamp() WHERE business_id=bid AND revision_id=b.active_revision_id AND released_at IS NULL;
 UPDATE ms_b1_design.booking SET status='CANCELLED',row_version=row_version+1 WHERE id=b.id RETURNING * INTO b;
 INSERT INTO ms_b1_design.booking_status_history(business_id,booking_id,revision_id,actor_user_id,from_status,to_status,event_type,operator_reason) VALUES(bid,b.id,b.active_revision_id,uid,old_status,b.status,'mvp.booking.admin_cancel',d->>'reason');result:=ms_b1_design.b4_view(b);
 END IF;
 PERFORM ms_b1_design.mvp_event(bid,uid,branch,'mvp.'||op,target,(result->>'version')::bigint,requestid);
 INSERT INTO ms_b1_design.idempotency_record(business_id,actor_key,route_key,idempotency_key,request_hash,state,response_code,response_snapshot,expires_at,created_by) VALUES(bid,uid::text,route,idem,rh,'COMPLETE',200,result,clock_timestamp()+interval '24 hours',uid);RETURN result;
END $$;

-- Only safe derivative descriptors cross the DB boundary; original objects are never public.
CREATE FUNCTION ms_b1_design.mvp_media_delivery(h bytea,bid uuid,asset uuid,variant text,public_view boolean) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;m ms_b1_design.media_asset;v ms_b1_design.media_variant;BEGIN
 IF variant NOT IN('THUMB','DISPLAY','VIDEO') OR variant IS NULL OR public_view IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF NOT public_view THEN a:=ms_b1_design.mvp_actor(h,NULL);bid:=(a->>'businessId')::uuid;END IF;
 SELECT * INTO m FROM ms_b1_design.media_asset WHERE business_id=bid AND id=asset;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF public_view THEN IF m.state<>'PUBLISHED' OR NOT ms_b1_design.mvp_rights_current(bid,m.id) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 ELSE PERFORM ms_b1_design.mvp_media_allowed(a,m.branch_id,'media.manage');END IF;
 SELECT * INTO v FROM ms_b1_design.media_variant WHERE business_id=bid AND asset_id=asset AND name=variant;
 IF NOT FOUND THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;RETURN jsonb_build_object('key',v.storage_key,'mime',v.mime,'bytes',v.bytes::text,'sha256',v.sha256);
END $$;
CREATE FUNCTION ms_b1_design.mvp_public_gallery(bid uuid,category text,page_offset integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE result jsonb;BEGIN
 IF page_offset IS NULL OR page_offset NOT BETWEEN 0 AND 10000 OR(category IS NOT NULL AND category !~ '^[a-z0-9][a-z0-9-]{0,63}$') THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 SELECT coalesce(jsonb_agg(ms_b1_design.mvp_media_view(x,false) ORDER BY x.created_at DESC,x.id),'[]') INTO result FROM(SELECT m.* FROM ms_b1_design.media_asset m WHERE m.business_id=bid AND m.state='PUBLISHED' AND ms_b1_design.mvp_rights_current(bid,m.id) AND(category IS NULL OR EXISTS(SELECT 1 FROM ms_b1_design.media_asset_category x JOIN ms_b1_design.media_category c ON c.business_id=x.business_id AND c.id=x.category_id WHERE x.business_id=bid AND x.asset_id=m.id AND c.active AND c.slug=category)) ORDER BY m.created_at DESC,m.id LIMIT 24 OFFSET page_offset) x;
 RETURN jsonb_build_object('items',result,'limit',24,'offset',page_offset,'categories',coalesce((SELECT jsonb_agg(jsonb_build_object('id',c.id,'name',c.name,'slug',c.slug) ORDER BY c.name) FROM ms_b1_design.media_category c WHERE c.business_id=bid AND c.active AND EXISTS(SELECT 1 FROM ms_b1_design.media_asset_category x JOIN ms_b1_design.media_asset m ON m.business_id=x.business_id AND m.id=x.asset_id WHERE x.business_id=bid AND x.category_id=c.id AND m.state='PUBLISHED' AND ms_b1_design.mvp_rights_current(bid,m.id))),'[]'));
END $$;
REVOKE ALL ON ms_b1_design.media_asset,ms_b1_design.media_variant,ms_b1_design.media_category,ms_b1_design.media_asset_category,ms_b1_design.media_rights_event FROM PUBLIC,ms_b1a_runtime,ms_b1b_api;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA ms_b1_design FROM PUBLIC;
REVOKE ALL ON FUNCTION ms_b1_design.mvp_immutable(),ms_b1_design.mvp_actor(bytea,bytea,boolean),ms_b1_design.mvp_media_allowed(jsonb,uuid,text),ms_b1_design.mvp_rights_current(uuid,uuid),ms_b1_design.mvp_media_view(ms_b1_design.media_asset,boolean),ms_b1_design.mvp_event(uuid,uuid,uuid,text,uuid,bigint,uuid) FROM ms_b1a_runtime,ms_b1b_api;
REVOKE ALL ON FUNCTION ms_b1_design.mvp_asset_guard() FROM ms_b1a_runtime,ms_b1b_api;
GRANT EXECUTE ON FUNCTION ms_b1_design.mvp_read(bytea,text,uuid,uuid,integer,jsonb),ms_b1_design.mvp_command(bytea,bytea,text,uuid,uuid,bigint,text,uuid,jsonb),ms_b1_design.mvp_media_ingest(bytea,bytea,uuid,text,text,uuid,jsonb),ms_b1_design.mvp_media_delivery(bytea,uuid,uuid,text,boolean),ms_b1_design.mvp_public_gallery(uuid,text,integer) TO ms_b1b_api;
GRANT EXECUTE ON FUNCTION ms_b1_design.mvp_media_authorize(bytea,bytea,uuid) TO ms_b1b_api;
