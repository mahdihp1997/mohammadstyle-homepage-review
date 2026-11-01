-- Owner-requested specialised blog. Draft edits never silently replace the
-- published edition. No seeded articles, testimonials, credentials or claims.
SET search_path=ms_b1_design,public;
CREATE TABLE product_article (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL REFERENCES business(id),
 slug text NOT NULL CHECK(slug ~ '^[a-z0-9][a-z0-9-]{2,99}$'),draft_document jsonb NOT NULL,
 published_version bigint,published boolean NOT NULL DEFAULT false,archived_at timestamptz,
 row_version bigint NOT NULL DEFAULT 1 CHECK(row_version>0),created_by uuid NOT NULL REFERENCES app_user(id),updated_by uuid NOT NULL REFERENCES app_user(id),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(business_id,id),UNIQUE(business_id,slug),CHECK(NOT published OR(published_version IS NOT NULL AND archived_at IS NULL)),CHECK(jsonb_typeof(draft_document)='object')
);
CREATE TABLE product_article_edition (
 business_id uuid NOT NULL,article_id uuid NOT NULL,version bigint NOT NULL,document jsonb NOT NULL,
 published_by uuid NOT NULL REFERENCES app_user(id),published_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(business_id,article_id,version),FOREIGN KEY(business_id,article_id) REFERENCES product_article(business_id,id)
);
ALTER TABLE product_article ADD FOREIGN KEY(business_id,id,published_version) REFERENCES product_article_edition(business_id,article_id,version);
CREATE TRIGGER product_article_edition_immutable BEFORE UPDATE OR DELETE ON product_article_edition FOR EACH ROW EXECUTE FUNCTION b3_freeze();
REVOKE ALL ON product_article,product_article_edition FROM PUBLIC,ms_b1b_api,ms_product_auth,ms_product_worker,ms_b1a_runtime;
INSERT INTO permission(permission_key,description) VALUES('content.read','Read editorial drafts'),('content.manage','Manage and publish editorial articles') ON CONFLICT(permission_key) DO NOTHING;
INSERT INTO role_permission(business_id,role_id,permission_id) SELECT r.business_id,r.id,p.id FROM role r CROSS JOIN permission p WHERE r.role_key='OWNER' AND p.permission_key IN('content.read','content.manage') ON CONFLICT DO NOTHING;
SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.product_content_document(d jsonb) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['title','summary','body','authorName','category','coverId']);
 IF jsonb_typeof(d->'title') IS DISTINCT FROM 'string' OR length(trim(d->>'title')) NOT BETWEEN 1 AND 160
 OR jsonb_typeof(d->'summary') IS DISTINCT FROM 'string' OR length(d->>'summary')>500
 OR jsonb_typeof(d->'body') IS DISTINCT FROM 'string' OR length(d->>'body') NOT BETWEEN 1 AND 6000
 OR jsonb_typeof(d->'authorName') IS DISTINCT FROM 'string' OR length(trim(d->>'authorName')) NOT BETWEEN 1 AND 100
 OR jsonb_typeof(d->'category') IS DISTINCT FROM 'string' OR length(d->>'category')>80 THEN PERFORM ms_b1_design.b3_fail('INVALID_ARTICLE');END IF;
 IF d->>'coverId' IS NOT NULL THEN PERFORM(d->>'coverId')::uuid;END IF;RETURN d;
END $$;
CREATE FUNCTION ms_b1_design.product_content_read(h bytea,entity uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;bid uuid;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);bid:=(a->>'businessId')::uuid;
 IF NOT ms_b1_design.b1b_can(a,'content.read',NULL) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(jsonb_build_object('id',x.id,'slug',x.slug,'version',x.row_version::text,'draft',x.draft_document,'published',x.published,'publishedVersion',x.published_version::text,'archivedAt',ms_b1_design.b3_iso(x.archived_at),'updatedAt',ms_b1_design.b3_iso(x.updated_at)) ORDER BY x.updated_at DESC) FROM ms_b1_design.product_article x WHERE x.business_id=bid AND(entity IS NULL OR x.id=entity)),'[]'::jsonb));
END $$;
CREATE FUNCTION ms_b1_design.product_content_command(h bytea,csrf bytea,k uuid,op text,d jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;r ms_b1_design.product_article;prior ms_b1_design.idempotency_record;signature bytea;route text;result jsonb;document jsonb;nextid uuid;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;
 IF NOT ms_b1_design.b1b_can(a,'content.manage',NULL) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF op IS NULL OR op NOT IN('save','publish','unpublish','archive') OR k IS NULL THEN PERFORM ms_b1_design.b3_fail('INVALID_ARTICLE');END IF;
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','version','slug','document']);
 PERFORM ms_b1_design.b4_lock(bid);route:='product:article:'||op;signature:=sha256(convert_to(d::text,'UTF8'));
 SELECT * INTO prior FROM ms_b1_design.idempotency_record WHERE business_id=bid AND actor_key=uid::text AND route_key=route AND idempotency_key=k::text FOR UPDATE;
 IF FOUND THEN IF prior.request_hash<>signature OR prior.expires_at<=clock_timestamp() THEN PERFORM ms_b1_design.b3_fail('IDEMPOTENCY_CONFLICT','MS409');END IF;RETURN prior.response_snapshot;END IF;
 IF(d->>'version') IS NULL OR(d->>'version') !~ '^\d{1,19}$' THEN PERFORM ms_b1_design.b3_fail('INVALID_ARTICLE');END IF;
 SELECT * INTO r FROM ms_b1_design.product_article WHERE business_id=bid AND id=(d->>'id')::uuid FOR UPDATE;
 IF coalesce(r.row_version,0)::text IS DISTINCT FROM d->>'version' OR(r.id IS NULL AND d->>'id' IS NOT NULL) THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF r.archived_at IS NOT NULL THEN PERFORM ms_b1_design.b3_fail('ARTICLE_ARCHIVED','MS409');END IF;
 IF op='save' THEN
 document:=ms_b1_design.product_content_document(d->'document');
 IF d->>'slug' IS NULL OR(d->>'slug') !~ '^[a-z0-9][a-z0-9-]{2,99}$' OR(r.published_version IS NOT NULL AND r.slug IS DISTINCT FROM d->>'slug') THEN PERFORM ms_b1_design.b3_fail('INVALID_ARTICLE_SLUG');END IF;
 IF document->>'coverId' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.media_asset m WHERE m.business_id=bid AND m.id=(document->>'coverId')::uuid AND m.kind='IMAGE' AND m.state<>'ARCHIVED') THEN PERFORM ms_b1_design.b3_fail('INVALID_ARTICLE_COVER');END IF;
 nextid:=coalesce(r.id,gen_random_uuid());
 INSERT INTO ms_b1_design.product_article(id,business_id,slug,draft_document,created_by,updated_by) VALUES(nextid,bid,d->>'slug',document,uid,uid)
 ON CONFLICT(id) DO UPDATE SET slug=excluded.slug,draft_document=excluded.draft_document,row_version=product_article.row_version+1,updated_by=uid,updated_at=clock_timestamp() RETURNING * INTO r;
 ELSE
 IF r.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF op='publish' THEN
 PERFORM ms_b1_design.product_content_document(r.draft_document);
 IF r.draft_document->>'coverId' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.media_asset m WHERE m.business_id=bid AND m.id=(r.draft_document->>'coverId')::uuid AND m.kind='IMAGE' AND m.state='PUBLISHED' AND ms_b1_design.mvp_rights_current(bid,m.id)) THEN PERFORM ms_b1_design.b3_fail('PUBLICATION_RIGHTS_REQUIRED','MS409');END IF;
 INSERT INTO ms_b1_design.product_article_edition(business_id,article_id,version,document,published_by) VALUES(bid,r.id,r.row_version+1,r.draft_document,uid);
 UPDATE ms_b1_design.product_article SET published=true,published_version=row_version+1,row_version=row_version+1,updated_by=uid,updated_at=clock_timestamp() WHERE id=r.id RETURNING * INTO r;
 ELSE UPDATE ms_b1_design.product_article SET published=false,archived_at=CASE WHEN op='archive' THEN clock_timestamp() ELSE NULL END,row_version=row_version+1,updated_by=uid,updated_at=clock_timestamp() WHERE id=r.id RETURNING * INTO r;END IF;
 END IF;
 result:=jsonb_build_object('id',r.id,'version',r.row_version::text,'published',r.published,'slug',r.slug);
 INSERT INTO ms_b1_design.audit_log(business_id,actor_user_id,action,target_type,target_id,request_id,redacted_change,created_by) VALUES(bid,uid,'content.'||op,'article',r.id,gen_random_uuid(),result,uid);
 INSERT INTO ms_b1_design.outbox_event(business_id,aggregate_type,aggregate_id,aggregate_version,event_type,schema_version,payload,available_at,created_by) VALUES(bid,'article',r.id,r.row_version,'content.'||op,1,result,clock_timestamp(),uid);
 INSERT INTO ms_b1_design.idempotency_record(business_id,actor_key,route_key,idempotency_key,request_hash,state,response_code,response_snapshot,expires_at,created_by) VALUES(bid,uid::text,route,k::text,signature,'COMPLETE',200,result,clock_timestamp()+interval '24 hours',uid);
 RETURN result;
END $$;
CREATE FUNCTION ms_b1_design.product_content_public(bid uuid,slug_query text,page_offset integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ BEGIN
 IF page_offset IS NULL OR page_offset NOT BETWEEN 0 AND 10000 OR length(slug_query)>100 THEN PERFORM ms_b1_design.b3_fail('INVALID_QUERY');END IF;
 RETURN jsonb_build_object('items',coalesce((SELECT jsonb_agg(t.document ORDER BY t.published_at DESC,t.id) FROM(
 SELECT a.id,e.published_at,(e.document-CASE WHEN slug_query IS NULL THEN ARRAY['body','coverId'] ELSE ARRAY['coverId'] END)||jsonb_build_object('id',a.id,'slug',a.slug,'publishedAt',ms_b1_design.b3_iso(e.published_at),'coverId',CASE WHEN EXISTS(SELECT 1 FROM ms_b1_design.media_asset m WHERE m.business_id=bid AND m.id=(e.document->>'coverId')::uuid AND m.kind='IMAGE' AND m.state='PUBLISHED' AND ms_b1_design.mvp_rights_current(bid,m.id)) THEN e.document->>'coverId' END) document
 FROM ms_b1_design.product_article a JOIN ms_b1_design.product_article_edition e ON e.business_id=a.business_id AND e.article_id=a.id AND e.version=a.published_version
 WHERE a.business_id=bid AND a.published AND a.archived_at IS NULL AND(slug_query IS NULL OR a.slug=slug_query) ORDER BY e.published_at DESC,a.id LIMIT 12 OFFSET page_offset)t),'[]'::jsonb),'limit',12,'offset',page_offset);
END $$;
REVOKE ALL ON FUNCTION ms_b1_design.product_content_document(jsonb),ms_b1_design.product_content_read(bytea,uuid),ms_b1_design.product_content_command(bytea,bytea,uuid,text,jsonb),ms_b1_design.product_content_public(uuid,text,integer) FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.product_content_read(bytea,uuid),ms_b1_design.product_content_command(bytea,bytea,uuid,text,jsonb),ms_b1_design.product_content_public(uuid,text,integer) TO ms_b1b_api;
