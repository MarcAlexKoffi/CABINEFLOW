-- CAT-IMPORT-01. Compatible extension; no historical order/financial values are rewritten.
-- Local candidate only: see docs/catalog_offers/IMPLEMENTATION.md before deployment.
alter table public.catalog_offers
  add column offer_code text,
  add column code_confirmed boolean not null default false,
  add column family_code text,
  add column catalog_status text,
  add column catalog_data jsonb,
  add column delivery_proof text,
  add column catalog_version bigint not null default 1;
-- A technical key is safe to expose as a provisional code. Never infer a match
-- from price/name/duration. An admin can explicitly bind this code once.
update public.catalog_offers set offer_code=id,
  catalog_status=case when is_active then 'ACTIF' else 'INACTIF' end;
alter table public.catalog_offers alter column offer_code set not null;
create unique index catalog_offers_code_unique on public.catalog_offers(offer_code);
alter table public.catalog_offers add constraint catalog_offer_status_valid
  check(catalog_status in ('BROUILLON','ACTIF','INACTIF'));

create table public.catalog_import_configuration (
  singleton boolean primary key default true check(singleton),
  verification_max_age_days integer check(verification_max_age_days between 1 and 366),
  version bigint not null default 1
);
insert into public.catalog_import_configuration(singleton) values(true);
create table public.catalog_import_families (
  network text not null check(network in ('ORANGE','MTN','MOOV')),
  code text not null check(code ~ '^[A-Z][A-Z0-9_]{0,39}$'),
  conditional boolean not null default false,
  enabled boolean not null default true,
  primary key(network,code)
);
insert into public.catalog_import_families(network,code,conditional) values
 ('ORANGE','INTERNET',false),('ORANGE','MIX',false),('ORANGE','MAXIT',true),('ORANGE','OZEN',true),
 ('MTN','INTERNET',false),('MTN','MIX',false),('MTN','CCHIC',true),('MTN','SOCIAL',true),
 ('MOOV','INTERNET',false),('MOOV','MIX',false),('MOOV','FOLIE',true),('MOOV','MAXI_DATA',true);
create table public.catalog_offer_imports (
  id uuid primary key,
  actor_uid text not null,
  file_name text not null,
  file_hash text not null,
  status text not null default 'preview' check(status in ('preview','running','completed','restored')),
  allow_partial boolean not null default false,
  total integer not null check(total between 1 and 5000),
  cursor integer not null default 0,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  confirmed_by text,
  completed_at timestamptz,
  restored_at timestamptz,
  restored_by text
);
create table public.catalog_offer_import_lines (
  import_id uuid not null references public.catalog_offer_imports(id),
  line_number integer not null,
  code text not null,
  kind text not null check(kind in ('create','update','deactivate','unchanged','error')),
  data jsonb not null,
  before_state jsonb,
  changes jsonb not null default '{}',
  errors jsonb not null default '[]',
  expected_version bigint,
  applied_version bigint,
  result text not null default 'pending' check(result in ('pending','applied','unchanged','excluded','conflict','restored')),
  result_error text,
  primary key(import_id,line_number)
);
create index catalog_offer_imports_created on public.catalog_offer_imports(created_at desc);
create table public.catalog_offer_import_metadata (
  offer_id text primary key references public.catalog_offers(id) deferrable initially deferred,
  data jsonb not null,
  delivery_proof text
);
alter table public.catalog_offer_import_metadata enable row level security;
alter table public.catalog_import_configuration enable row level security;
alter table public.catalog_import_families enable row level security;
alter table public.catalog_offer_imports enable row level security;
alter table public.catalog_offer_import_lines enable row level security;
revoke all on public.catalog_import_configuration,public.catalog_import_families,
  public.catalog_offer_imports,public.catalog_offer_import_lines,public.catalog_offer_import_metadata from public,anon,authenticated;

-- Internal comments and delivery evidence never enter the publicly readable
-- catalogue projection. Only the Admin RPC returns the complete document.
create function private.catalog_enrich(p_offer public.catalog_offers) returns public.catalog_offers
language plpgsql stable set search_path='' as $$
declare result public.catalog_offers:=p_offer; metadata public.catalog_offer_import_metadata;
begin
  select * into metadata from public.catalog_offer_import_metadata where offer_id=p_offer.id;
  if found then result.catalog_data:=metadata.data;result.delivery_proof:=metadata.delivery_proof; end if;
  return result;
end $$;

create function private.catalog_admin() returns text
language plpgsql stable security definer set search_path='' as $$
begin
  if not coalesce(private.is_izytel_finance_admin(),false) then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
  end if;
  return auth.jwt()->>'sub';
end $$;

create function public.izytel_catalog_offers_admin() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.catalog_admin();
  return coalesce((select jsonb_agg(to_jsonb(private.catalog_enrich(o)) order by display_order,id) from public.catalog_offers o where deleted_at is null),'[]');
end $$;

create function public.izytel_catalog_configuration() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.catalog_admin();
  return jsonb_build_object('settings',(select to_jsonb(c) from public.catalog_import_configuration c),
    'families',(select jsonb_agg(to_jsonb(f) order by network,code) from public.catalog_import_families f),
    'maxFileBytes',5242880,'maxRows',5000,'batchSize',50);
end $$;
create function public.izytel_catalog_save_configuration(p_version bigint,p_days integer,p_families jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare f jsonb; old_configuration jsonb;
begin
  perform private.catalog_admin();
  old_configuration:=public.izytel_catalog_configuration();
  if p_days is not null and p_days not between 1 and 366 then raise exception 'CATALOG_POLICY_INVALID'; end if;
  if jsonb_typeof(p_families) is distinct from 'array' or jsonb_array_length(p_families)>100 then raise exception 'CATALOG_FAMILIES_INVALID'; end if;
  update public.catalog_import_configuration set verification_max_age_days=p_days,version=version+1 where version=p_version;
  if not found then raise exception 'CATALOG_VERSION_CONFLICT'; end if;
  for f in select value from jsonb_array_elements(p_families) loop
    insert into public.catalog_import_families(network,code,conditional,enabled)
      values(f->>'network',f->>'code',(f->>'conditional')::boolean,(f->>'enabled')::boolean)
      on conflict(network,code) do update set conditional=excluded.conditional,enabled=excluded.enabled;
  end loop;
  insert into public.catalog_offer_audit_events(offer_id,action,before_state,after_state,actor_uid,actor_name,actor_role)
    values('__catalog_configuration__','configuration_updated',old_configuration,public.izytel_catalog_configuration(),auth.jwt()->>'sub',private.izytel_staff_display_name(),'admin');
  return public.izytel_catalog_configuration();
end $$;

-- Canonical comparison preserves data units. Empty fields explicitly clear
-- optional data; DESACTIVER never clears the commercial attributes.
create function private.catalog_normalize(p_row jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare r jsonb:='{}'; k text; v text;
begin
  if jsonb_typeof(p_row) is distinct from 'object' then raise exception 'CATALOG_ROW_INVALID'; end if;
  foreach k in array array['action','code_offre','operateur','famille','type_forfait','nom_affiche','prix_fcfa','volume_data','unite_data','minutes_appels','nombre_sms','duree_valeur','duree_unite','statut','mis_en_avant','ordre_affichage','activable_pour_tiers','canal_activation','reference_operateur','verifie_le','source_url','commentaire'] loop
    v:=btrim(coalesce(p_row->>k,''));
    if length(v)>2000 then raise exception 'CATALOG_FIELD_TOO_LONG'; end if;
    if k in ('action','operateur','famille','type_forfait','unite_data','duree_unite','statut','mis_en_avant','activable_pour_tiers','canal_activation') then v:=upper(v); end if;
    if k in ('prix_fcfa','volume_data','minutes_appels','nombre_sms','duree_valeur','ordre_affichage') and v ~ '^[0-9]+([.,][0-9]+)?$' and length(v)<30 then
      v:=trim_scale(replace(v,',','.')::numeric)::text;
    end if;
    r:=r||jsonb_build_object(k,v);
  end loop;
  return r;
end $$;

create function private.catalog_validate(p_data jsonb,p_existing public.catalog_offers) returns jsonb
language plpgsql stable set search_path='' as $$
declare errors jsonb:='[]'; k text; value text; days integer; verified date;
begin
  if coalesce(p_data->>'code_offre','') !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$' then errors:=errors||jsonb_build_array('code_offre obligatoire : lettres, chiffres, point, tiret, souligné ; 120 caractères maximum.'); end if;
  if p_data->>'action' not in ('UPSERT','DESACTIVER') then errors:=errors||jsonb_build_array('Action attendue : UPSERT ou DESACTIVER.'); end if;
  if p_existing.id is not null and p_data->>'operateur'<>'' and lower(p_data->>'operateur')<>p_existing.network then errors:=errors||jsonb_build_array('Collision de code entre opérateurs.'); end if;
  if p_existing.deleted_at is not null then errors:=errors||jsonb_build_array('Offre archivée : restauration administrative nécessaire avant modification.'); end if;
  if p_data->>'action'='DESACTIVER' then
    if p_existing.id is null then errors:=errors||jsonb_build_array('Code inconnu : aucune offre à désactiver.'); end if;
    return errors;
  end if;
  if not exists(select 1 from public.catalog_import_families where network=p_data->>'operateur' and code=p_data->>'famille' and enabled) then errors:=errors||jsonb_build_array('Famille ou opérateur non reconnu / incompatible.'); end if;
  if p_data->>'type_forfait' not in ('INTERNET','MIXTE','APPELS','SOCIAL') then errors:=errors||jsonb_build_array('type_forfait invalide.'); end if;
  if length(p_data->>'nom_affiche') not between 2 and 120 then errors:=errors||jsonb_build_array('nom_affiche : 2 à 120 caractères.'); end if;
  if p_data->>'statut' not in ('BROUILLON','ACTIF','INACTIF') then errors:=errors||jsonb_build_array('statut invalide.'); end if;
  if p_data->>'mis_en_avant' not in ('OUI','NON') or p_data->>'activable_pour_tiers' not in ('OUI','NON','A_VERIFIER') or p_data->>'canal_activation' not in ('MANUEL','USSD','API','APP_OPERATEUR','A_VERIFIER') then errors:=errors||jsonb_build_array('Valeur de vérification / activation non reconnue.'); end if;
  foreach k in array array['prix_fcfa','volume_data','minutes_appels','nombre_sms','duree_valeur','ordre_affichage'] loop
    value:=p_data->>k;
    if value='' and k in ('volume_data','minutes_appels','nombre_sms') then continue; end if;
    if value !~ '^[0-9]+(\.[0-9]+)?$' or length(value)>20 then errors:=errors||jsonb_build_array(k||' : nombre invalide.');
    elsif value::numeric>100000000 or (k in ('prix_fcfa','volume_data','duree_valeur') and value::numeric<=0) or (k<>'volume_data' and value::numeric<>trunc(value::numeric)) then errors:=errors||jsonb_build_array(k||' : quantité / précision invalide.'); end if;
  end loop;
  if p_data->>'duree_unite' not in ('JOUR','HEURE','MOIS') then errors:=errors||jsonb_build_array('duree_unite invalide.'); end if;
  if p_data->>'unite_data' not in ('','MO','GO') or ((p_data->>'volume_data'='')<>(p_data->>'unite_data'='')) then errors:=errors||jsonb_build_array('Volume et unité MO/GO à renseigner ensemble.'); end if;
  if p_data->>'verifie_le'<>'' then
    begin
      verified:=(p_data->>'verifie_le')::date;
      if p_data->>'verifie_le' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' or verified>current_date then raise exception 'invalid date'; end if;
    exception when others then errors:=errors||jsonb_build_array('verifie_le : date AAAA-MM-JJ valide et non future attendue.'); verified:=null; end;
  end if;
  if p_data->>'statut'='ACTIF' then
    select verification_max_age_days into days from public.catalog_import_configuration;
    if days is null then errors:=errors||jsonb_build_array('Configurer le délai de vérification avant publication.');
    elsif verified is null or verified<current_date-days then errors:=errors||jsonb_build_array('Vérification absente ou trop ancienne.'); end if;
    if p_data->>'activable_pour_tiers'<>'OUI' or p_data->>'canal_activation'='A_VERIFIER' then errors:=errors||jsonb_build_array('Activation pour un tiers et canal réel à confirmer.'); end if;
    if exists(select 1 from public.catalog_import_families where network=p_data->>'operateur' and code=p_data->>'famille' and conditional)
      and nullif(btrim(p_existing.delivery_proof),'') is null then errors:=errors||jsonb_build_array('Offre conditionnelle : confirmer la livraison depuis la fiche avant publication.'); end if;
  end if;
  return errors;
end $$;

create function private.catalog_version_guard() returns trigger
language plpgsql set search_path='' as $$
declare errs jsonb; metadata public.catalog_offer_import_metadata;
begin
  new.offer_code:=coalesce(nullif(btrim(new.offer_code),''),new.id);
  if tg_op='UPDATE' then
    new.catalog_version:=old.catalog_version+1;
    if old.code_confirmed and new.offer_code<>old.offer_code then raise exception 'CATALOG_CODE_IMMUTABLE'; end if;
    if not old.is_active and new.is_active and new.catalog_data is null and coalesce(current_setting('izytel.catalog_restore',true),'')<>'true' then raise exception 'CATALOG_VERIFICATION_REQUIRED'; end if;
  elsif new.is_active and new.catalog_data is null and new.source_kind<>'legacy_firestore' then
    raise exception 'CATALOG_VERIFICATION_REQUIRED';
  end if;
  if new.deleted_at is not null then new.is_active:=false; end if;
  new.catalog_status:=case when new.is_active then 'ACTIF' when new.catalog_status='BROUILLON' then 'BROUILLON' else 'INACTIF' end;
  if new.catalog_data is not null then
    select * into metadata from public.catalog_offer_import_metadata where offer_id=new.id;
    new.catalog_data:=coalesce(metadata.data,'{}')||new.catalog_data;
    if new.delivery_proof='CONFIRMED' then new.delivery_proof:=metadata.delivery_proof; end if;
    -- Keep single-offer legacy RPCs in sync with the canonical import fields.
    new.catalog_data:=new.catalog_data||jsonb_build_object('nom_affiche',new.title,'prix_fcfa',new.selling_price::text,
      'statut',new.catalog_status,'ordre_affichage',new.display_order::text,'code_offre',new.offer_code);
    if new.is_active then
      errs:=private.catalog_validate(new.catalog_data,new);
      if jsonb_array_length(errs)>0 then raise exception 'CATALOG_PUBLICATION_BLOCKED: %',errs; end if;
    end if;
    insert into public.catalog_offer_import_metadata(offer_id,data,delivery_proof) values(new.id,new.catalog_data,new.delivery_proof)
      on conflict(offer_id) do update set data=excluded.data,delivery_proof=excluded.delivery_proof;
    new.catalog_data:=new.catalog_data-'commentaire'-'source_url'-'reference_operateur';
    new.delivery_proof:=case when nullif(btrim(new.delivery_proof),'') is not null then 'CONFIRMED' end;
  elsif tg_op='UPDATE' then
    delete from public.catalog_offer_import_metadata where offer_id=new.id;
  end if;
  return new;
end $$;
create trigger catalog_offer_import_version before insert or update on public.catalog_offers
  for each row execute function private.catalog_version_guard();

create function private.catalog_write(p_data jsonb,p_existing public.catalog_offers) returns public.catalog_offers
language plpgsql set search_path='' as $$
declare saved public.catalog_offers; v_service text; operation text; v_validity text; v_details text[]:='{}';
begin
  v_service:=case when p_data->>'type_forfait' in ('APPELS','MIXTE') then 'calls' else 'internetSubscription' end;
  operation:=case p_data->>'type_forfait' when 'MIXTE' then 'mixedBundle' when 'APPELS' then 'callBundle' else 'internetSubscription' end;
  v_validity:=(p_data->>'duree_valeur')||' '||case p_data->>'duree_unite'
    when 'JOUR' then case when (p_data->>'duree_valeur')::numeric>1 then 'jours' else 'jour' end
    when 'HEURE' then case when (p_data->>'duree_valeur')::numeric>1 then 'heures' else 'heure' end else 'mois' end;
  if p_data->>'volume_data'<>'' then v_details:=array_append(v_details,(p_data->>'volume_data')||' '||(p_data->>'unite_data')); end if;
  if p_data->>'minutes_appels'<>'' then v_details:=array_append(v_details,(p_data->>'minutes_appels')||' min'); end if;
  if p_data->>'nombre_sms'<>'' then v_details:=array_append(v_details,(p_data->>'nombre_sms')||' SMS'); end if;
  v_details:=array_append(v_details,'Validité '||v_validity);
  if p_existing.id is null then
    insert into public.catalog_offers(network,service,operation_type,title,catalog_label,selling_price,details,category,is_active,display_order,
      offer_code,code_confirmed,family_code,catalog_status,catalog_data,validity,volume,minutes,sms,badge_label,created_by_uid,updated_by_uid,delivery_proof)
    values(lower(p_data->>'operateur'),v_service,operation,p_data->>'nom_affiche',p_data->>'nom_affiche',(p_data->>'prix_fcfa')::bigint,v_details,
      case when operation='mixedBundle' then 'mixed' when v_service='calls' then 'calls' else 'internet' end,p_data->>'statut'='ACTIF',(p_data->>'ordre_affichage')::integer,
      p_data->>'code_offre',true,p_data->>'famille',p_data->>'statut',p_data,v_validity,
      nullif(p_data->>'volume_data','')||' '||(p_data->>'unite_data'),nullif(p_data->>'minutes_appels',''),nullif(p_data->>'nombre_sms',''),
      case when p_data->>'mis_en_avant'='OUI' then 'Mis en avant' end,auth.jwt()->>'sub',auth.jwt()->>'sub',p_existing.delivery_proof) returning * into saved;
  else
    update public.catalog_offers set network=lower(p_data->>'operateur'),service=v_service,operation_type=operation,
      title=p_data->>'nom_affiche',catalog_label=p_data->>'nom_affiche',selling_price=(p_data->>'prix_fcfa')::bigint,details=v_details,
      category=case when operation='mixedBundle' then 'mixed' when v_service='calls' then 'calls' else 'internet' end,
      is_active=p_data->>'statut'='ACTIF',display_order=(p_data->>'ordre_affichage')::integer,
      code_confirmed=true,family_code=p_data->>'famille',catalog_status=p_data->>'statut',catalog_data=p_data,validity=v_validity,
      volume=nullif(p_data->>'volume_data','')||' '||(p_data->>'unite_data'),minutes=nullif(p_data->>'minutes_appels',''),sms=nullif(p_data->>'nombre_sms',''),
      badge_label=case when p_data->>'mis_en_avant'='OUI' then 'Mis en avant' end,updated_by_uid=auth.jwt()->>'sub',updated_at=now()
    where id=p_existing.id returning * into saved;
  end if;
  return private.catalog_enrich(saved);
end $$;

create function public.izytel_catalog_import_prepare(p_id uuid,p_name text,p_hash text,p_rows jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor text:=private.catalog_admin(); job public.catalog_offer_imports; row jsonb; data jsonb; before public.catalog_offers;
  errors jsonb; changes jsonb; kind text; code text; line integer; n integer; key text; duplicates text[];
begin
  if p_id is null or length(p_name) not between 1 and 160 or p_hash !~ '^[a-f0-9]{64}$' or jsonb_typeof(p_rows) is distinct from 'array' then raise exception 'CATALOG_IMPORT_INVALID'; end if;
  n:=jsonb_array_length(p_rows);
  if n not between 1 and 5000 or octet_length(p_rows::text)>10485760 then raise exception 'CATALOG_IMPORT_TOO_LARGE'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
  select * into job from public.catalog_offer_imports where id=p_id;
  if found then
    if job.actor_uid<>actor or job.file_hash<>p_hash then raise exception 'CATALOG_IDEMPOTENCY_CONFLICT'; end if;
    return p_id;
  end if;
  select array_agg(c) into duplicates from (select btrim(value->>'code_offre') c from jsonb_array_elements(p_rows) group by 1 having count(*)>1) d;
  insert into public.catalog_offer_imports(id,actor_uid,file_name,file_hash,total) values(p_id,actor,left(p_name,160),p_hash,n);
  for row in select value from jsonb_array_elements(p_rows) loop
    data:=private.catalog_normalize(row);code:=data->>'code_offre';line:=(row->>'_row')::integer;
    if line not between 2 and 100000 then raise exception 'CATALOG_LINE_INVALID'; end if;
    select * into before from public.catalog_offers where offer_code=code;
    before:=private.catalog_enrich(before);
    errors:=private.catalog_validate(data,before);changes:='{}';
    if code=any(duplicates) then
      errors:=errors||jsonb_build_array('Code répété aux lignes '||(select string_agg(value->>'_row',', ' order by (value->>'_row')::integer) from jsonb_array_elements(p_rows) where btrim(value->>'code_offre')=code)||'. Toutes les occurrences sont bloquées.');
    end if;
    if data->>'action'='DESACTIVER' then
      kind:=case when not before.is_active and before.catalog_status='INACTIF' then 'unchanged' else 'deactivate' end;
      if kind='deactivate' then changes:=jsonb_build_object('statut',jsonb_build_object('before',before.catalog_status,'after','INACTIF')); end if;
    elsif before.id is null then kind:='create';
    else
      for key in select jsonb_object_keys(data-'action'-'code_offre') loop
        if data->key is distinct from before.catalog_data->key then changes:=changes||jsonb_build_object(key,jsonb_build_object('before',before.catalog_data->key,'after',data->key)); end if;
      end loop;
      kind:=case when changes='{}' then 'unchanged' else 'update' end;
    end if;
    if jsonb_array_length(errors)>0 then kind:='error'; end if;
    insert into public.catalog_offer_import_lines(import_id,line_number,code,kind,data,before_state,changes,errors,expected_version)
      values(p_id,line,code,kind,data,case when before.id is not null then to_jsonb(before) end,changes,errors,before.catalog_version);
  end loop;
  return p_id;
end $$;

create function public.izytel_catalog_import_get(p_id uuid,p_offset integer default 0,p_filter text default 'all') returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare job public.catalog_offer_imports; summary jsonb;
begin
  perform private.catalog_admin();
  select * into job from public.catalog_offer_imports where id=p_id;
  if not found then raise exception 'CATALOG_IMPORT_NOT_FOUND'; end if;
  select jsonb_build_object('create',count(*) filter(where kind='create'),'update',count(*) filter(where kind='update'),
    'deactivate',count(*) filter(where kind='deactivate'),'unchanged',count(*) filter(where kind='unchanged'),'error',count(*) filter(where kind='error'),
    'applied',count(*) filter(where result in ('applied','restored')),'conflict',count(*) filter(where result='conflict')) into summary
    from public.catalog_offer_import_lines where import_id=p_id;
  return jsonb_build_object('job',to_jsonb(job),'summary',summary,
    'filteredTotal',(select count(*) from public.catalog_offer_import_lines where import_id=p_id and (p_filter='all' or kind=p_filter or result=p_filter)),
    'lines',coalesce((select jsonb_agg(to_jsonb(l) order by line_number) from
      (select * from public.catalog_offer_import_lines where import_id=p_id and (p_filter='all' or kind=p_filter or result=p_filter)
        order by line_number limit 20 offset greatest(0,least(p_offset,5000))) l),'[]'));
end $$;
create function public.izytel_catalog_import_history(p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.catalog_admin();
  return coalesce((select jsonb_agg(to_jsonb(j) order by created_at desc) from
    (select * from public.catalog_offer_imports order by created_at desc limit 20 offset greatest(0,least(p_offset,10000))) j),'[]');
end $$;
create function public.izytel_catalog_import_confirm(p_id uuid,p_allow_partial boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare job public.catalog_offer_imports;
begin
  perform private.catalog_admin();select * into job from public.catalog_offer_imports where id=p_id for update;
  if not found then raise exception 'CATALOG_IMPORT_NOT_FOUND'; end if;
  if job.status='preview' then
    if not coalesce(p_allow_partial,false) and exists(select 1 from public.catalog_offer_import_lines where import_id=p_id and kind='error') then raise exception 'CATALOG_ERRORS_REQUIRE_CONFIRMATION'; end if;
    update public.catalog_offer_imports set status='running',allow_partial=p_allow_partial,confirmed_at=now(),confirmed_by=auth.jwt()->>'sub' where id=p_id;
  elsif job.status='restored' then raise exception 'CATALOG_IMPORT_ALREADY_RESTORED'; end if;
  return public.izytel_catalog_import_get(p_id);
end $$;
create function public.izytel_catalog_import_apply(p_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare job public.catalog_offer_imports; l public.catalog_offer_import_lines; before public.catalog_offers; saved public.catalog_offers; errors jsonb; processed integer:=0;
begin
  perform private.catalog_admin();select * into job from public.catalog_offer_imports where id=p_id for update;
  if not found then raise exception 'CATALOG_IMPORT_NOT_FOUND'; end if;
  if job.status='completed' then return public.izytel_catalog_import_get(p_id); end if;
  if job.status<>'running' then raise exception 'CATALOG_CONFIRMATION_REQUIRED'; end if;
  for l in select * from public.catalog_offer_import_lines where import_id=p_id and result='pending' order by line_number limit 50 for update loop
    processed:=processed+1;
    if l.kind in ('error','unchanged') then
      update public.catalog_offer_import_lines set result=case when kind='error' then 'excluded' else 'unchanged' end where import_id=p_id and line_number=l.line_number;continue;
    end if;
    -- Serialize a code across imports, then recheck the current version.
    perform pg_advisory_xact_lock(hashtextextended(l.code,1));
    select * into before from public.catalog_offers where offer_code=l.code for update;
    before:=private.catalog_enrich(before);
    if before.catalog_version is distinct from l.expected_version then
      update public.catalog_offer_import_lines set result='conflict',result_error='Version modifiée depuis l’aperçu. Aucun écrasement.' where import_id=p_id and line_number=l.line_number;continue;
    end if;
    errors:=private.catalog_validate(l.data,before);
    if jsonb_array_length(errors)>0 then
      update public.catalog_offer_import_lines set result='conflict',result_error=errors::text where import_id=p_id and line_number=l.line_number;continue;
    end if;
    begin
      if l.kind='deactivate' then
        update public.catalog_offers set is_active=false,catalog_status='INACTIF',updated_at=now(),updated_by_uid=auth.jwt()->>'sub' where id=before.id returning * into saved;
      else saved:=private.catalog_write(l.data,before); end if;
      saved:=private.catalog_enrich(saved);
      insert into public.catalog_offer_audit_events(offer_id,action,before_state,after_state,actor_uid,actor_name,actor_role)
        values(saved.id,'import:'||p_id,case when before.id is not null then to_jsonb(before) end,to_jsonb(saved),auth.jwt()->>'sub',private.izytel_staff_display_name(),'admin');
      update public.catalog_offer_import_lines set result='applied',applied_version=saved.catalog_version where import_id=p_id and line_number=l.line_number;
    exception when unique_violation then
      update public.catalog_offer_import_lines set result='conflict',result_error='Code créé simultanément. Aucun écrasement.' where import_id=p_id and line_number=l.line_number;
    end;
  end loop;
  update public.catalog_offer_imports set cursor=cursor+processed where id=p_id;
  if not exists(select 1 from public.catalog_offer_import_lines where import_id=p_id and result='pending') then
    update public.catalog_offer_imports set status='completed',completed_at=now() where id=p_id;
  end if;
  return public.izytel_catalog_import_get(p_id);
end $$;

create function public.izytel_catalog_import_restore(p_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare job public.catalog_offer_imports; l public.catalog_offer_import_lines; current public.catalog_offers; old public.catalog_offers; saved public.catalog_offers;
begin
  perform private.catalog_admin();select * into job from public.catalog_offer_imports where id=p_id for update;
  if not found then raise exception 'CATALOG_IMPORT_NOT_FOUND'; end if;
  if job.status='restored' then return public.izytel_catalog_import_get(p_id); end if;
  if job.status<>'completed' then raise exception 'CATALOG_IMPORT_NOT_COMPLETED'; end if;
  -- Lock and validate the whole restoration before changing any offer.
  perform set_config('izytel.catalog_restore','true',true);
  for l in select * from public.catalog_offer_import_lines where import_id=p_id and result='applied' order by code loop
    perform pg_advisory_xact_lock(hashtextextended(l.code,1));
    select * into current from public.catalog_offers where offer_code=l.code for update;
    if current.catalog_version is distinct from l.applied_version then raise exception 'CATALOG_RESTORE_CONFLICT: %',l.code; end if;
  end loop;
  for l in select * from public.catalog_offer_import_lines where import_id=p_id and result='applied' order by code loop
    select * into current from public.catalog_offers where offer_code=l.code;
    current:=private.catalog_enrich(current);
    if l.before_state is null then
      update public.catalog_offers set is_active=false,catalog_status='INACTIF',updated_at=now(),updated_by_uid=auth.jwt()->>'sub' where id=current.id returning * into saved;
    else
      old:=jsonb_populate_record(null::public.catalog_offers,l.before_state);
      update public.catalog_offers set network=old.network,service=old.service,operation_type=old.operation_type,title=old.title,catalog_label=old.catalog_label,
        selling_price=old.selling_price,details=old.details,category=old.category,is_active=old.is_active,display_order=old.display_order,
        description=old.description,badge_label=old.badge_label,validity=old.validity,volume=old.volume,minutes=old.minutes,sms=old.sms,eligibility=old.eligibility,
        family_code=old.family_code,catalog_status=old.catalog_status,catalog_data=old.catalog_data,delivery_proof=old.delivery_proof,
        updated_at=now(),updated_by_uid=auth.jwt()->>'sub' where id=current.id returning * into saved;
    end if;
    saved:=private.catalog_enrich(saved);
    insert into public.catalog_offer_audit_events(offer_id,action,before_state,after_state,actor_uid,actor_name,actor_role)
      values(saved.id,'restore:'||p_id,to_jsonb(current),to_jsonb(saved),auth.jwt()->>'sub',private.izytel_staff_display_name(),'admin');
    update public.catalog_offer_import_lines set result='restored' where import_id=p_id and line_number=l.line_number;
  end loop;
  update public.catalog_offer_imports set status='restored',restored_at=now(),restored_by=auth.jwt()->>'sub' where id=p_id;
  perform set_config('izytel.catalog_restore','false',true);
  return public.izytel_catalog_import_get(p_id);
end $$;

create function public.izytel_catalog_offer_update_legacy(p_offer_id text,p_version bigint,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare offer public.catalog_offers;
begin
  perform private.catalog_admin();
  select * into offer from public.catalog_offers where id=p_offer_id for update;
  if offer.id is null or offer.catalog_version is distinct from p_version then raise exception 'CATALOG_VERSION_CONFLICT'; end if;
  if offer.catalog_data is not null then raise exception 'CATALOG_STRUCTURED_EDIT_REQUIRED'; end if;
  return to_jsonb(public.izytel_update_catalog_offer(p_offer_id,p_payload));
end $$;

create function public.izytel_catalog_offer_history(p_offer_id text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.catalog_admin();
  return coalesce((select jsonb_agg(to_jsonb(e) order by created_at desc) from
    (select * from public.catalog_offer_audit_events where offer_id=p_offer_id order by created_at desc limit 100) e),'[]');
end $$;

create function public.izytel_catalog_bulk_prepare(p_id uuid,p_changes jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor text:=private.catalog_admin(); item jsonb; offer public.catalog_offers; rows jsonb:='[]'; data jsonb;
  operation text:=p_changes->>'operation'; v_value text:=p_changes->>'value'; line integer:=1; hash text; job public.catalog_offer_imports;
begin
  if operation not in ('deactivate','activate','family','priority') or jsonb_typeof(p_changes->'items') is distinct from 'array'
    or jsonb_array_length(p_changes->'items') not between 1 and 500 then raise exception 'CATALOG_BULK_INVALID'; end if;
  hash:=md5(p_changes::text)||md5(reverse(p_changes::text));
  select * into job from public.catalog_offer_imports where id=p_id;
  if found then
    if job.actor_uid<>actor or job.file_hash<>hash then raise exception 'CATALOG_IDEMPOTENCY_CONFLICT'; end if;
    return p_id;
  end if;
  if exists(select 1 from jsonb_array_elements(p_changes->'items') e group by e.value->>'id' having count(*)>1) then raise exception 'CATALOG_BULK_DUPLICATE'; end if;
  for item in select e.value from jsonb_array_elements(p_changes->'items') e order by e.value->>'id' loop
    select * into offer from public.catalog_offers where id=item->>'id' and deleted_at is null for update;
    offer:=private.catalog_enrich(offer);
    if offer.id is null or offer.catalog_version is distinct from (item->>'version')::bigint then raise exception 'CATALOG_VERSION_CONFLICT'; end if;
    line:=line+1;
    data:=coalesce(offer.catalog_data,'{}')||jsonb_build_object('_row',line,'code_offre',offer.offer_code,'action','UPSERT');
    if operation='deactivate' then data:=jsonb_build_object('_row',line,'code_offre',offer.offer_code,'action','DESACTIVER');
    elsif operation='activate' then data:=data||jsonb_build_object('statut','ACTIF');
    elsif operation='family' then data:=data||jsonb_build_object('famille',upper(v_value));
    else data:=data||jsonb_build_object('ordre_affichage',v_value); end if;
    rows:=rows||jsonb_build_array(data);
  end loop;
  return public.izytel_catalog_import_prepare(p_id,'Modification groupée : '||operation,hash,rows);
end $$;

-- Freeze only new canonical order snapshots. Never reconstruct old quantities
-- or fees from today's catalogue. Preserve every commercial field actually
-- present on the order; absent fee data is not invented or set to zero.
create function private.catalog_order_snapshot() returns trigger
language plpgsql security definer set search_path='' as $$
declare r jsonb:=to_jsonb(new); offer public.catalog_offers; registry jsonb;
begin
  if tg_op='UPDATE' then
    if new.catalog_snapshot is distinct from old.catalog_snapshot then raise exception 'CATALOG_ORDER_SNAPSHOT_IMMUTABLE'; end if;
    return new;
  end if;
  if new.catalog_snapshot is not null then raise exception 'CATALOG_ORDER_SNAPSHOT_SERVER_ONLY'; end if;
  if tg_table_name='phase4_assignment_orders' and to_regclass('public.customer_order_recovery_registry') is not null then
    execute 'select to_jsonb(o) from public.customer_order_recovery_registry o where order_id=$1' into registry using r->>'order_id';
    if registry is not null then
      if registry->'catalog_snapshot' is not null and registry->'catalog_snapshot'<>'null'::jsonb then
        new.catalog_snapshot:=registry->'catalog_snapshot';return new;
      end if;
      new.catalog_snapshot:=jsonb_build_object('historical_without_catalog_snapshot',true,'offer_id',registry->>'offer_id',
        'offer_label',registry->>'offer_label','amount',registry->'amount','order_fields',registry-'catalog_snapshot','captured_at',now());
      return new;
    end if;
  end if;
  select * into offer from public.catalog_offers where id=r->>'offer_id';
  new.catalog_snapshot:=jsonb_build_object('offer_id',offer.id,'offer_code',offer.offer_code,
    'offer_label',r->>'offer_label','amount',r->'amount','volume',offer.volume,'minutes',offer.minutes,'sms',offer.sms,
    'catalog_data',offer.catalog_data,'catalog_version',offer.catalog_version,'order_fields',r-'catalog_snapshot','captured_at',now());
  return new;
end $$;
do $$ declare target text; begin
  foreach target in array array['customer_order_recovery_registry','phase4_assignment_orders'] loop
    if to_regclass('public.'||target) is not null then
      execute format('alter table public.%I add column catalog_snapshot jsonb',target);
      execute format('create trigger catalog_order_snapshot before insert or update on public.%I for each row execute function private.catalog_order_snapshot()',target);
    end if;
  end loop;
end $$;

-- Structured editor + explicit mapping of an existing technical ID. The caller
-- supplies the observed version. Existing legacy create/update RPCs remain intact.
create function public.izytel_catalog_offer_save(p_offer_id text,p_version bigint,p_data jsonb,p_delivery_proof text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare old public.catalog_offers; original public.catalog_offers; saved public.catalog_offers; data jsonb; errors jsonb;
begin
  perform private.catalog_admin();data:=private.catalog_normalize(p_data||jsonb_build_object('action','UPSERT'));
  if length(p_delivery_proof)>2000 then raise exception 'CATALOG_FIELD_TOO_LONG'; end if;
  perform pg_advisory_xact_lock(hashtextextended(data->>'code_offre',1));
  if p_offer_id is not null then
    select * into old from public.catalog_offers where id=p_offer_id for update;
    old:=private.catalog_enrich(old);
    original:=old;
    if old.id is null then raise exception 'CATALOG_OFFER_NOT_FOUND'; end if;
    if old.catalog_version is distinct from p_version then raise exception 'CATALOG_VERSION_CONFLICT'; end if;
    if old.code_confirmed and old.offer_code<>data->>'code_offre' then raise exception 'CATALOG_CODE_IMMUTABLE'; end if;
    if lower(data->>'operateur')<>old.network then raise exception 'CATALOG_NETWORK_IMMUTABLE'; end if;
    if old.offer_code<>data->>'code_offre' then update public.catalog_offers set offer_code=data->>'code_offre',code_confirmed=true where id=old.id returning * into old; end if;
    if old.delivery_proof is distinct from nullif(btrim(p_delivery_proof),'') then
      update public.catalog_offers set delivery_proof=nullif(btrim(p_delivery_proof),'') where id=old.id returning * into old;
    end if;
  else old.delivery_proof:=nullif(btrim(p_delivery_proof),''); end if;
  errors:=private.catalog_validate(data,old);
  if jsonb_array_length(errors)>0 then raise exception 'CATALOG_VALIDATION: %',errors; end if;
  saved:=private.catalog_write(data,old);
  insert into public.catalog_offer_audit_events(offer_id,action,before_state,after_state,actor_uid,actor_name,actor_role)
    values(saved.id,'structured_edit',case when original.id is not null then to_jsonb(original) end,to_jsonb(saved),auth.jwt()->>'sub',private.izytel_staff_display_name(),'admin');
  return to_jsonb(saved);
end $$;

-- Explicit grants on the bounded RPC surface only; no direct table access.
do $$ declare f record; begin
  for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='public' and p.proname like 'izytel_catalog_%') or (n.nspname='private' and p.proname in ('catalog_admin','catalog_normalize','catalog_validate','catalog_version_guard','catalog_write','catalog_order_snapshot','catalog_enrich')) loop
    execute format('revoke all on function %s from public,anon,authenticated',f.signature);
    if split_part(f.signature::text,'.',1)<>'private' then execute format('grant execute on function %s to anon,authenticated',f.signature); end if;
  end loop;
end $$;
