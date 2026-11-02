SET search_path=pg_catalog;
CREATE FUNCTION ms_b1_design.manual_card_document(c ms_b1_design.product_bank_card,full_number boolean DEFAULT false) RETURNS jsonb
 LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('id',c.id,'bankName',c.bank_name,'lastFour',c.last_four,'scopeKind',c.scope_kind,
 'branchIds',coalesce((SELECT jsonb_agg(s.branch_id ORDER BY s.branch_id) FROM ms_b1_design.product_bank_card_branch s WHERE s.business_id=c.business_id AND s.card_id=c.id),'[]'::jsonb),
 'priority',c.priority,'active',c.active,'archivedAt',ms_b1_design.b3_iso(c.archived_at),'version',c.row_version::text,
 '_privateCard',jsonb_build_object('ciphertext',c.details_ciphertext,'businessId',c.business_id,'cardId',c.id,'version',c.row_version::text,'fullNumber',full_number))
$$;
CREATE FUNCTION ms_b1_design.manual_card_manageable(a jsonb,c ms_b1_design.product_bank_card) RETURNS boolean
 LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT ms_b1_design.b1b_can(a,'payment.settings.manage',NULL) OR(c.scope_kind='BRANCHES'
 AND EXISTS(SELECT 1 FROM ms_b1_design.product_bank_card_branch s WHERE s.card_id=c.id AND s.business_id=c.business_id)
 AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_bank_card_branch s WHERE s.card_id=c.id AND s.business_id=c.business_id AND NOT ms_b1_design.b1b_can(a,'payment.settings.manage',s.branch_id)))
$$;
CREATE FUNCTION ms_b1_design.manual_settings_read(h bytea,branchid uuid) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;c ms_b1_design.product_payment_configuration;effective ms_b1_design.product_payment_configuration;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);bid:=(a->>'businessId')::uuid;
 IF NOT ms_b1_design.b1b_can(a,'payment.settings.read',branchid) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 IF branchid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND b.id=branchid AND b.archived_at IS NULL) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 SELECT * INTO c FROM ms_b1_design.product_payment_configuration x WHERE x.business_id=bid AND x.branch_id IS NOT DISTINCT FROM branchid;
 effective:=ms_b1_design.manual_configuration(bid,branchid);
 RETURN jsonb_build_object('branchId',branchid,'version',coalesce(c.row_version,0)::text,'inherited',c.id IS NULL AND effective.id IS NOT NULL,
 'onlineEnabled',coalesce(effective.online_enabled,false),'manualEnabled',coalesce(effective.manual_enabled,false),
 'defaultCardId',effective.default_card_id,'retentionDays',effective.receipt_retention_days,'maxSubmissions',coalesce(effective.max_receipt_submissions,3),
 'gatewayConfigured',EXISTS(SELECT 1 FROM ms_b1_design.product_runtime r WHERE r.singleton AND r.payment_provider<>'none'),
 'cards',coalesce((SELECT jsonb_agg(ms_b1_design.manual_card_document(x) ORDER BY x.priority,x.created_at,x.id)
 FROM ms_b1_design.product_bank_card x WHERE x.business_id=bid AND(branchid IS NULL OR x.scope_kind='BUSINESS' OR EXISTS(
 SELECT 1 FROM ms_b1_design.product_bank_card_branch s WHERE s.card_id=x.id AND s.business_id=bid AND s.branch_id=branchid))),'[]'::jsonb));
END $$;

CREATE FUNCTION ms_b1_design.manual_settings_save(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;branchid uuid;c ms_b1_design.product_payment_configuration;card ms_b1_design.product_bank_card;result jsonb;BEGIN
 PERFORM ms_b1_design.b3_keys(d,ARRAY['branchId','version','onlineEnabled','manualEnabled','defaultCardId','retentionDays','maxSubmissions','inherit']);
 branchid:=(d->>'branchId')::uuid;a:=ms_b1_design.manual_financial_actor(h,csrf,branchid,'payment.settings.manage');bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);
 result:=ms_b1_design.manual_replay(bid,uid,'settings.save',k,sig);IF result IS NOT NULL THEN RETURN result;END IF;
 IF branchid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.id=branchid AND b.business_id=bid AND b.archived_at IS NULL) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 IF jsonb_typeof(d->'onlineEnabled') IS DISTINCT FROM 'boolean' OR jsonb_typeof(d->'manualEnabled') IS DISTINCT FROM 'boolean' OR jsonb_typeof(d->'inherit') IS DISTINCT FROM 'boolean'
 OR(d->>'maxSubmissions') !~ '^\d{1,2}$' OR(d->>'maxSubmissions')::int NOT BETWEEN 1 AND 10 OR(d->>'version') !~ '^\d{1,19}$'
 OR(d->>'retentionDays' IS NOT NULL AND((d->>'retentionDays') !~ '^\d{1,5}$' OR(d->>'retentionDays')::int NOT BETWEEN 1 AND 36500)) THEN PERFORM ms_b1_design.b3_fail('INVALID_CONFIGURATION');END IF;
 SELECT * INTO c FROM ms_b1_design.product_payment_configuration x WHERE x.business_id=bid AND x.branch_id IS NOT DISTINCT FROM branchid FOR UPDATE;
 IF coalesce(c.row_version,0)::text IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF(d->>'inherit')::boolean THEN
 IF branchid IS NULL THEN PERFORM ms_b1_design.b3_fail('INVALID_CONFIGURATION');END IF;
 DELETE FROM ms_b1_design.product_payment_configuration WHERE id=c.id;
 result:=jsonb_build_object('branchId',branchid,'version','0','inherited',true);
 ELSE
 IF(d->>'onlineEnabled')::boolean AND NOT EXISTS(SELECT 1 FROM ms_b1_design.product_runtime r WHERE r.singleton AND r.payment_provider<>'none') THEN PERFORM ms_b1_design.b3_fail('PAYMENT_UNCONFIGURED','MS409');END IF;
 IF d->>'defaultCardId' IS NOT NULL THEN
 SELECT * INTO card FROM ms_b1_design.product_bank_card WHERE business_id=bid AND id=(d->>'defaultCardId')::uuid;
 IF card.id IS NULL OR NOT card.active OR card.archived_at IS NOT NULL OR(branchid IS NULL AND card.scope_kind<>'BUSINESS') OR(branchid IS NOT NULL AND NOT ms_b1_design.manual_card_eligible(card,branchid)) THEN PERFORM ms_b1_design.b3_fail('CARD_UNAVAILABLE','MS409');END IF;END IF;
 INSERT INTO ms_b1_design.product_payment_configuration(business_id,branch_id,online_enabled,manual_enabled,default_card_id,receipt_retention_days,max_receipt_submissions,updated_by)
 VALUES(bid,branchid,(d->>'onlineEnabled')::boolean,(d->>'manualEnabled')::boolean,(d->>'defaultCardId')::uuid,(d->>'retentionDays')::int,(d->>'maxSubmissions')::int,uid)
 ON CONFLICT(business_id,branch_id) DO UPDATE SET online_enabled=excluded.online_enabled,manual_enabled=excluded.manual_enabled,default_card_id=excluded.default_card_id,
 receipt_retention_days=excluded.receipt_retention_days,max_receipt_submissions=excluded.max_receipt_submissions,updated_by=uid,updated_at=clock_timestamp(),row_version=product_payment_configuration.row_version+1 RETURNING * INTO c;
 result:=jsonb_build_object('branchId',branchid,'version',c.row_version::text,'onlineEnabled',c.online_enabled,'manualEnabled',c.manual_enabled);
 END IF;
 PERFORM ms_b1_design.manual_event(bid,branchid,uid,'manual.settings.changed',coalesce(branchid,bid),result);
 RETURN ms_b1_design.manual_remember(bid,uid,'settings.save',k,sig,result);
END $$;

CREATE FUNCTION ms_b1_design.manual_card_context(h bytea,cardid uuid) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$ DECLARE a jsonb;c ms_b1_design.product_bank_card;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);SELECT * INTO c FROM ms_b1_design.product_bank_card WHERE business_id=(a->>'businessId')::uuid AND id=cardid;
 IF c.id IS NULL OR NOT ms_b1_design.manual_card_manageable(a,c) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 RETURN ms_b1_design.manual_card_document(c,true);
END $$;

CREATE FUNCTION ms_b1_design.manual_card_save(h bytea,csrf bytea,k uuid,sig bytea,d jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;bid uuid;uid uuid;c ms_b1_design.product_bank_card;cardid uuid;branches uuid[];branchid uuid;result jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h,csrf,true);bid:=(a->>'businessId')::uuid;uid:=(a->>'userId')::uuid;PERFORM ms_b1_design.b4_lock(bid);
 PERFORM ms_b1_design.b3_keys(d,ARRAY['id','version','bankName','ciphertext','fingerprint','lastFour','scopeKind','branchIds','priority','active','archive']);
 cardid:=(d->>'id')::uuid;
 IF jsonb_typeof(d->'branchIds') IS DISTINCT FROM 'array' OR jsonb_array_length(d->'branchIds')>100 THEN PERFORM ms_b1_design.b3_fail('INVALID_CONFIGURATION');END IF;
 SELECT coalesce(array_agg(value::uuid ORDER BY value::uuid),'{}') INTO branches FROM jsonb_array_elements_text(d->'branchIds');
 IF cardinality(branches)<>(SELECT count(DISTINCT x) FROM unnest(branches) x) OR(d->>'scopeKind') NOT IN('BUSINESS','BRANCHES')
 OR(d->>'scopeKind'='BUSINESS' AND cardinality(branches)<>0) OR(d->>'scopeKind'='BRANCHES' AND cardinality(branches)=0) THEN PERFORM ms_b1_design.b3_fail('INVALID_CONFIGURATION');END IF;
 IF d->>'scopeKind'='BUSINESS' THEN PERFORM ms_b1_design.manual_financial_actor(h,csrf,NULL,'payment.settings.manage');
 ELSE FOREACH branchid IN ARRAY branches LOOP
 PERFORM ms_b1_design.manual_financial_actor(h,csrf,branchid,'payment.settings.manage');
 IF NOT EXISTS(SELECT 1 FROM ms_b1_design.branch b WHERE b.business_id=bid AND b.id=branchid AND b.archived_at IS NULL) THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 END LOOP;END IF;
 SELECT * INTO c FROM ms_b1_design.product_bank_card WHERE business_id=bid AND id=cardid FOR UPDATE;
 IF c.id IS NOT NULL AND NOT ms_b1_design.manual_card_manageable(a,c) THEN PERFORM ms_b1_design.b3_fail('FORBIDDEN','MS403');END IF;
 result:=ms_b1_design.manual_replay(bid,uid,'card.save',k,sig);IF result IS NOT NULL THEN RETURN result;END IF;
 IF coalesce(c.row_version,0)::text IS DISTINCT FROM d->>'version' THEN PERFORM ms_b1_design.b3_fail('STALE_VERSION','MS412');END IF;
 IF c.archived_at IS NOT NULL THEN PERFORM ms_b1_design.b3_fail('CARD_ARCHIVED','MS409');END IF;
 IF cardid IS NULL OR(d->>'bankName') IS NULL OR length(trim(d->>'bankName')) NOT BETWEEN 1 AND 100
 OR(d->>'fingerprint') !~ '^[a-f0-9]{64}$' OR(d->>'lastFour') !~ '^\d{4}$'
 OR length(d->>'ciphertext') NOT BETWEEN 50 AND 4000 OR(d->>'priority') !~ '^\d{1,5}$' OR(d->>'priority')::int NOT BETWEEN 0 AND 10000
 OR jsonb_typeof(d->'active') IS DISTINCT FROM 'boolean' OR jsonb_typeof(d->'archive') IS DISTINCT FROM 'boolean' THEN PERFORM ms_b1_design.b3_fail('INVALID_CONFIGURATION');END IF;
 IF c.id IS NOT NULL AND(c.card_fingerprint<>decode(d->>'fingerprint','hex') OR c.last_four<>d->>'lastFour') THEN PERFORM ms_b1_design.b3_fail('CARD_NUMBER_IMMUTABLE','MS409');END IF;
 IF c.id IS NULL THEN
 IF(d->>'archive')::boolean THEN PERFORM ms_b1_design.b3_fail('INVALID_CONFIGURATION');END IF;
 INSERT INTO ms_b1_design.product_bank_card(id,business_id,bank_name,details_ciphertext,card_fingerprint,last_four,scope_kind,priority,active,created_by,updated_by)
 VALUES(cardid,bid,trim(d->>'bankName'),d->>'ciphertext',decode(d->>'fingerprint','hex'),d->>'lastFour',d->>'scopeKind',(d->>'priority')::int,(d->>'active')::boolean,uid,uid) RETURNING * INTO c;
 ELSE
 UPDATE ms_b1_design.product_bank_card SET bank_name=trim(d->>'bankName'),details_ciphertext=d->>'ciphertext',scope_kind=d->>'scopeKind',priority=(d->>'priority')::int,
 active=(d->>'active')::boolean AND NOT(d->>'archive')::boolean,archived_at=CASE WHEN(d->>'archive')::boolean THEN clock_timestamp() ELSE NULL END,
 row_version=row_version+1,updated_by=uid,updated_at=clock_timestamp() WHERE id=c.id RETURNING * INTO c;
 DELETE FROM ms_b1_design.product_bank_card_branch WHERE business_id=bid AND card_id=c.id;
 END IF;
 INSERT INTO ms_b1_design.product_bank_card_branch(business_id,card_id,branch_id) SELECT bid,c.id,x FROM unnest(branches) x;
 result:=jsonb_build_object('id',c.id,'version',c.row_version::text,'lastFour',c.last_four,'active',c.active,'archived',c.archived_at IS NOT NULL,'scopeKind',c.scope_kind,'branchIds',to_jsonb(branches));
 PERFORM ms_b1_design.manual_event(bid,NULL,uid,'manual.card.changed',c.id,result);
 RETURN ms_b1_design.manual_remember(bid,uid,'card.save',k,sig,result);
END $$;

CREATE FUNCTION ms_b1_design.manual_methods(h bytea,bookingid uuid) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
 DECLARE a jsonb;b ms_b1_design.booking;c ms_b1_design.product_payment_configuration;hold ms_b1_design.booking_hold;p ms_b1_design.product_payment_intent;online boolean;manual boolean;cards jsonb;BEGIN
 a:=ms_b1_design.b1b_actor(h,NULL,false);SELECT * INTO b FROM ms_b1_design.booking WHERE business_id=(a->>'businessId')::uuid AND id=bookingid AND created_by=(a->>'userId')::uuid;
 IF b.id IS NULL THEN PERFORM ms_b1_design.b3_fail('NOT_FOUND','MS404');END IF;
 c:=ms_b1_design.manual_configuration(b.business_id,b.branch_id);SELECT * INTO hold FROM ms_b1_design.booking_hold WHERE revision_id=b.active_revision_id;
 SELECT * INTO p FROM ms_b1_design.product_payment_intent WHERE business_id=b.business_id AND revision_id=b.active_revision_id;
 online:=coalesce(c.online_enabled,false) AND EXISTS(SELECT 1 FROM ms_b1_design.product_runtime r WHERE r.singleton AND r.payment_provider<>'none');
 SELECT coalesce(jsonb_agg(ms_b1_design.manual_card_document(x,true) ORDER BY x.id IS DISTINCT FROM c.default_card_id,x.priority,x.id),'[]'::jsonb)
 INTO cards FROM ms_b1_design.product_bank_card x WHERE x.business_id=b.business_id AND ms_b1_design.manual_card_eligible(x,b.branch_id);
 manual:=coalesce(c.manual_enabled,false) AND jsonb_array_length(cards)>0;
 IF b.status<>'PENDING_PAYMENT' OR hold.id IS NULL OR hold.released_at IS NOT NULL OR hold.expires_at<=clock_timestamp() OR p.id IS NOT NULL THEN online:=false;manual:=false;cards:='[]';END IF;
 RETURN jsonb_build_object('bookingId',b.id,'branchId',b.branch_id,'onlineEnabled',online,'manualEnabled',manual,'cards',CASE WHEN manual THEN cards ELSE '[]'::jsonb END,
 'mode',CASE WHEN online AND manual THEN 'BOTH' WHEN online THEN 'ONLINE_GATEWAY' WHEN manual THEN 'MANUAL_CARD_TRANSFER' ELSE 'NONE' END,
 'expiresAt',ms_b1_design.b3_iso(hold.expires_at),'existingIntentId',p.id,'existingMethod',CASE WHEN p.provider='manual_card_transfer' THEN 'MANUAL_CARD_TRANSFER' WHEN p.id IS NOT NULL THEN 'ONLINE_GATEWAY' END);
END $$;

CREATE FUNCTION ms_b1_design.manual_card_guard() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$ BEGIN
 IF TG_OP='DELETE' OR NEW.id<>OLD.id OR NEW.business_id<>OLD.business_id OR NEW.card_fingerprint<>OLD.card_fingerprint OR NEW.last_four<>OLD.last_four
 OR NEW.created_by<>OLD.created_by OR NEW.created_at<>OLD.created_at OR NEW.row_version<>OLD.row_version+1 OR OLD.archived_at IS NOT NULL THEN PERFORM ms_b1_design.b3_fail('IMMUTABLE_CARD_IDENTITY');END IF;RETURN NEW;
END $$;
CREATE TRIGGER manual_card_identity BEFORE UPDATE OR DELETE ON ms_b1_design.product_bank_card FOR EACH ROW EXECUTE FUNCTION ms_b1_design.manual_card_guard();
REVOKE ALL ON FUNCTION ms_b1_design.manual_card_document(ms_b1_design.product_bank_card,boolean),ms_b1_design.manual_card_manageable(jsonb,ms_b1_design.product_bank_card),ms_b1_design.manual_card_guard()
 FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
REVOKE ALL ON FUNCTION ms_b1_design.manual_settings_read(bytea,uuid),ms_b1_design.manual_settings_save(bytea,bytea,uuid,bytea,jsonb),
 ms_b1_design.manual_card_context(bytea,uuid),ms_b1_design.manual_card_save(bytea,bytea,uuid,bytea,jsonb),ms_b1_design.manual_methods(bytea,uuid)
 FROM PUBLIC,ms_b1a_runtime,ms_b1b_api,ms_product_auth,ms_product_worker;
GRANT EXECUTE ON FUNCTION ms_b1_design.manual_settings_read(bytea,uuid),ms_b1_design.manual_settings_save(bytea,bytea,uuid,bytea,jsonb),
 ms_b1_design.manual_card_context(bytea,uuid),ms_b1_design.manual_card_save(bytea,bytea,uuid,bytea,jsonb),ms_b1_design.manual_methods(bytea,uuid) TO ms_b1b_api;
