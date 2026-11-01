-- LOCAL PREPARATION ONLY. Do not apply to production automatically.
-- Requires USSD V1 (local 20261031005603; remote history 20261031095414).
-- No order/payment/capacity/proof/commission writes and no active operator codes.

alter table public.ussd_execution_rules
  add column purpose text not null default 'order' check (purpose in ('order','balance')),
  add column seed_key text unique,
  alter column service drop not null,
  add constraint ussd_rule_purpose_context check (
    (purpose='order' and service is not null) or
    (purpose='balance' and service is null and family_id is null and offer_id is null));

-- Secret source of truth is private and never returned by configuration/history.
-- Only a trusted database administrator may provision a network/actor override.
create table private.ussd_secret_configuration (
  network text not null check (network in ('orange','mtn','moov')),
  actor_scope text not null check (actor_scope in ('agent','cabiniste','both')),
  secret_code text not null check (secret_code ~ '^[0-9]{1,20}$'),
  version bigint not null default 1 check (version>0),
  revision uuid not null default gen_random_uuid(),
  primary key(network,actor_scope)
);
alter table private.ussd_secret_configuration enable row level security;
revoke all on table private.ussd_secret_configuration from public,anon,authenticated;

create function private.ussd_default_secret() returns text
language sql immutable set search_path='' as $$ select '0000'::text; $$;

create function private.ussd_secret_revision() returns trigger
language plpgsql set search_path='' as $$
begin
  new.version:=old.version+1;
  new.revision:=gen_random_uuid();
  return new;
end $$;
create trigger ussd_secret_revision before update on private.ussd_secret_configuration
for each row execute function private.ussd_secret_revision();

create function private.ussd_secret_settings(p_network text,p_actor text) returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce((select jsonb_build_object('value',c.secret_code,
      'revision',c.revision::text)
    from private.ussd_secret_configuration c where c.network=p_network and c.actor_scope in (p_actor,'both')
    order by (c.actor_scope=p_actor) desc limit 1),
    jsonb_build_object('value',private.ussd_default_secret(),'revision','default-v1'));
$$;

-- Accent/case folding is local to known variable tokens. Operator punctuation
-- and numbers are preserved, including the leading # required by Orange.
create function private.ussd_variable_name(p_token text) returns text
language plpgsql immutable set search_path='' as $$
declare v text:=translate(lower(p_token),
  'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ','aaaaaaceeeeiiiinooooouuuuyy');
begin
  v:=regexp_replace(v,U&'[\0300-\036f]','','g');
  return case
    when v in ('msisdn_local','numero_du_destinataire','numero','beneficiaire') then 'msisdn_local'
    when v in ('amount','montant') then 'amount'
    when v in ('offer_code','code_offre','code offre') then 'offer_code'
    when v in ('quantity','quantite') then 'quantity'
    when v in ('secret_code','code_secret','code secret') then 'secret_code'
    else null end;
end $$;

create function private.ussd_normalize_template(p_template text) returns text
language plpgsql immutable set search_path='' as $$
declare v text:=''; token text:=''; canonical text; c text; i integer:=1; closing integer;
begin
  if p_template is null or length(p_template)>512 then return p_template; end if;
  while i<=length(p_template) loop
    if substr(p_template,i,2)='{{' then
      closing:=strpos(substr(p_template,i+2),'}}');
      if closing=0 then return v||substr(p_template,i); end if;
      token:=substr(p_template,i+2,closing-1);
      canonical:=private.ussd_variable_name(token);
      v:=v||'{{'||coalesce(canonical,token)||'}}';
      i:=i+closing+3;
    else
      c:=substr(p_template,i,1);
      if c in ('*','#','{','}') then v:=v||c; i:=i+1;
      else
        token:='';
        while i<=length(p_template) and substr(p_template,i,1) not in ('*','#','{','}') loop
          token:=token||substr(p_template,i,1); i:=i+1;
        end loop;
        canonical:=private.ussd_variable_name(token);
        v:=v||case when canonical is null then token else '{{'||canonical||'}}' end;
      end if;
    end if;
  end loop;
  return v;
end $$;

create or replace function private.ussd_template(p_template text) returns text[]
language plpgsql immutable set search_path='' as $$
declare v text; m text[]; names text[]:='{}'; t text:=private.ussd_normalize_template(p_template);
begin
  if t is null or length(t) not between 1 and 512 then raise exception 'invalid_template'; end if;
  for m in select regexp_matches(t,'\{\{([^{}]+)\}\}','g') loop
    if m[1] not in ('msisdn_local','amount','offer_code','quantity','secret_code') then raise exception 'unknown_variable'; end if;
    names:=array_append(names,m[1]);
  end loop;
  v:=regexp_replace(t,'\{\{([^{}]+)\}\}','1','g');
  if length(v)>182 or v !~ '^(\*{1,2}|#)[0-9]+(\*[0-9]+)*#$' then raise exception 'invalid_template'; end if;
  return names;
end $$;

create function private.ussd_generate(p_template text,p_beneficiary text,p_amount bigint,p_offer_code text,p_quantity integer,p_secret_code text)
returns text language plpgsql immutable set search_path='' as $$
declare names text[]:=private.ussd_template(p_template); v text:=private.ussd_normalize_template(p_template);
  secret text:=coalesce(p_secret_code,private.ussd_default_secret());
begin
  if 'msisdn_local'=any(names) then v:=replace(v,'{{msisdn_local}}',private.ussd_phone(p_beneficiary)); end if;
  if 'amount'=any(names) then
    if p_amount is null or p_amount not between 1 and 100000000 then raise exception 'missing_amount'; end if;
    v:=replace(v,'{{amount}}',p_amount::text);
  end if;
  if 'offer_code'=any(names) then
    if p_offer_code is null or p_offer_code !~ '^[0-9]{1,20}$' then raise exception 'missing_offer_code'; end if;
    v:=replace(v,'{{offer_code}}',p_offer_code);
  end if;
  if 'quantity'=any(names) then
    if p_quantity is null or p_quantity not between 1 and 999999 then raise exception 'missing_quantity'; end if;
    v:=replace(v,'{{quantity}}',p_quantity::text);
  end if;
  if 'secret_code'=any(names) then
    if secret !~ '^[0-9]{1,20}$' then raise exception 'invalid_secret_code'; end if;
    v:=replace(v,'{{secret_code}}',secret);
  end if;
  if length(v)>182 or v !~ '^(\*{1,2}|#)[0-9]+(\*[0-9]+)*#$' then raise exception 'invalid_template'; end if;
  return v;
end $$;

-- Retain the existing internal five-argument API for legacy callers/tests.
create or replace function private.ussd_generate(p_template text,p_beneficiary text,p_amount bigint,p_offer_code text,p_quantity integer)
returns text language sql immutable set search_path='' as $$
  select private.ussd_generate(p_template,p_beneficiary,p_amount,p_offer_code,p_quantity,null);
$$;


create or replace function private.ussd_save_rule(p_rule_id uuid,p_expected_version integer,p_payload jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_admin(); r public.ussd_execution_rules; v_id uuid := coalesce(p_rule_id,gen_random_uuid());
begin
  perform pg_advisory_xact_lock(9261031);
  if jsonb_typeof(p_payload)<>'object' or exists(select 1 from jsonb_object_keys(p_payload) k
    where k not in ('purpose','network','service','family_id','offer_id','actor_scope','ussd_template','priority','effective_from','effective_until','internal_note')) then raise exception 'invalid_payload'; end if;
  perform private.ussd_template(p_payload->>'ussd_template');
  p_payload:=jsonb_set(p_payload,'{ussd_template}',to_jsonb(private.ussd_normalize_template(p_payload->>'ussd_template')));
  if coalesce(p_payload->>'purpose','order')='balance' and exists(
    select 1 from unnest(private.ussd_template(p_payload->>'ussd_template')) n where n<>'secret_code') then
    raise exception 'invalid_balance_template';
  end if;
  if p_rule_id is not null then
    select * into strict r from public.ussd_execution_rules where id=p_rule_id for update;
    if p_expected_version is distinct from r.version then raise exception 'rule_changed'; end if;
  end if;
  insert into public.ussd_execution_rules(id,purpose,network,service,family_id,offer_id,actor_scope,ussd_template,priority,
    effective_from,effective_until,internal_note,created_by,updated_by)
  values(v_id,coalesce(p_payload->>'purpose','order'),p_payload->>'network',p_payload->>'service',nullif(p_payload->>'family_id','')::uuid,
    nullif(p_payload->>'offer_id',''),p_payload->>'actor_scope',p_payload->>'ussd_template',
    coalesce((p_payload->>'priority')::integer,0),(p_payload->>'effective_from')::timestamptz,
    nullif(p_payload->>'effective_until','')::timestamptz,coalesce(p_payload->>'internal_note',''),v_uid,v_uid)
  on conflict(id) do update set purpose=excluded.purpose,network=excluded.network,service=excluded.service,family_id=excluded.family_id,
    offer_id=excluded.offer_id,actor_scope=excluded.actor_scope,ussd_template=excluded.ussd_template,
    priority=excluded.priority,effective_from=excluded.effective_from,effective_until=excluded.effective_until,
    internal_note=excluded.internal_note,status='draft',version=public.ussd_execution_rules.version+1,
    validation_sim_type=null,validated_at=null,validated_by=null,updated_by=v_uid,updated_at=clock_timestamp()
  returning * into r;
  if r.family_id is not null and not exists(select 1 from public.ussd_offer_families f
    where f.id=r.family_id and f.network=r.network and f.service=r.service) then raise exception 'invalid_association'; end if;
  if r.offer_id is not null and not exists(select 1 from public.catalog_offers c
    left join public.ussd_offer_bindings b on b.offer_id=c.id where c.id=r.offer_id and c.deleted_at is null
    and c.network=r.network and private.ussd_service(c.operation_type)=r.service and (r.family_id is null or b.family_id=r.family_id)) then raise exception 'invalid_association'; end if;
  insert into public.ussd_rule_versions values(r.id,r.version,to_jsonb(r));
  return r.id;
end $$;

create or replace function private.ussd_set_status(p_rule_id uuid,p_expected_version integer,p_status text,p_sim_type text) returns void
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_admin(); r public.ussd_execution_rules; vars text[];
begin
  perform pg_advisory_xact_lock(9261031);
  select * into strict r from public.ussd_execution_rules where id=p_rule_id for update;
  if p_expected_version is distinct from r.version then raise exception 'rule_changed'; end if;
  if p_status is null or p_status not in ('active','disabled') then raise exception 'invalid_status'; end if;
  if p_status='active' then
    vars:=private.ussd_template(r.ussd_template);
    if r.service='sms' and not exists(select 1 from public.catalog_offers c where c.operation_type='sms' and c.deleted_at is null) then raise exception 'unsupported_order_service'; end if;
    if r.family_id is not null and not exists(select 1 from public.ussd_offer_families f
      where f.id=r.family_id and f.network=r.network and f.service=r.service) then raise exception 'invalid_association'; end if;
    if r.family_id is not null and not exists(select 1 from public.catalog_offers c
      join public.ussd_offer_bindings b on b.offer_id=c.id where b.family_id=r.family_id
      and c.deleted_at is null and c.network=r.network and c.operation_type=r.service) then
      raise exception 'missing_offer_context';
    end if;
    if r.offer_id is not null and not exists(select 1 from public.catalog_offers c
      left join public.ussd_offer_bindings b on b.offer_id=c.id where c.id=r.offer_id and c.deleted_at is null
      and c.network=r.network and private.ussd_service(c.operation_type)=r.service and (r.family_id is null or b.family_id=r.family_id)) then raise exception 'invalid_association'; end if;
    if length(btrim(coalesce(p_sim_type,''))) not between 1 and 100
      or p_sim_type ~ '[0-9]([[:space:].()+-]*[0-9]){7,}' then raise exception 'sim_validation_required'; end if;
    if r.effective_until is not null and r.effective_until<=clock_timestamp() then raise exception 'expired_rule'; end if;
    if ('offer_code'=any(vars) or 'quantity'=any(vars)) then
      if r.offer_id is null and r.family_id is null then raise exception 'missing_offer_context'; end if;
      if not exists(select 1 from public.catalog_offers c left join public.ussd_offer_bindings b on b.offer_id=c.id
        where c.deleted_at is null and c.network=r.network and private.ussd_service(c.operation_type)=r.service
        and (r.offer_id is null or c.id=r.offer_id) and (r.family_id is null or b.family_id=r.family_id)) then raise exception 'missing_offer_context'; end if;
      if exists(select 1 from public.catalog_offers c left join public.ussd_offer_bindings b on b.offer_id=c.id
        where c.deleted_at is null and c.network=r.network and private.ussd_service(c.operation_type)=r.service
        and (r.offer_id is null or c.id=r.offer_id) and (r.family_id is null or b.family_id=r.family_id)
        and (('offer_code'=any(vars) and b.offer_code is null) or ('quantity'=any(vars) and b.quantity is null))) then raise exception 'missing_offer_context'; end if;
    end if;
    if exists(select 1 from public.ussd_execution_rules x where x.id<>r.id and x.status='active'
      and x.network=r.network and x.purpose=r.purpose and x.service is not distinct from r.service and x.priority=r.priority
      and (x.actor_scope=r.actor_scope or x.actor_scope='both' or r.actor_scope='both')
      and ((r.offer_id is not null and x.offer_id=r.offer_id) or
        (r.offer_id is null and x.offer_id is null and r.family_id is not distinct from x.family_id))
      and tstzrange(x.effective_from,x.effective_until,'[)') && tstzrange(r.effective_from,r.effective_until,'[)')) then raise exception 'ambiguous_rule'; end if;
  end if;
  update public.ussd_execution_rules set status=p_status,version=version+1,
    validation_sim_type=case when p_status='active' then btrim(p_sim_type) else validation_sim_type end,
    validated_by=case when p_status='active' then v_uid else validated_by end,
    validated_at=case when p_status='active' then clock_timestamp() else validated_at end,
    updated_by=v_uid,updated_at=clock_timestamp() where id=r.id returning * into r;
  insert into public.ussd_rule_versions values(r.id,r.version,to_jsonb(r));
end $$;

create or replace function private.ussd_resolve(p_order_id text) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.phase4_assignment_orders; r public.ussd_execution_rules; r2 public.ussd_execution_rules;
  b public.ussd_offer_bindings; v_actor text; v_offer text; v_service text; v_code text; v_phone text;
  v_network text; v_context jsonb; v_secret jsonb;
begin
  perform private.ussd_uid();
  select * into strict o from public.phase4_assignment_orders where order_id=p_order_id;
  v_actor:=private.ussd_actor(o);
  if o.order_status<>'inProgress' or o.assignment_state<>'accepted' or o.payment_status not in ('confirmed','credit') then
    return jsonb_build_object('status','unavailable','reason','order_not_processable'); end if;
  -- Only the staff-synchronized identity is trusted. A customer recovery record
  -- is not a substitute for the canonical operational offer association.
  select ctx.offer_id into v_offer from public.phase4_assignment_orders a
    left join public.ussd_order_contexts ctx on ctx.order_id=a.order_id where a.order_id=o.order_id;
  -- Stale or inconsistent offer metadata is never used for an exact/family rule.
  if v_offer is not null and not exists(select 1 from public.catalog_offers c
    where c.id=v_offer and c.network=o.network and c.operation_type=o.operation_type and c.deleted_at is null) then v_offer:=null; end if;
  select * into b from public.ussd_offer_bindings where offer_id=v_offer;
  v_service:=private.ussd_service(o.operation_type);
  select * into r from public.ussd_execution_rules x where x.purpose='order' and x.status='active' and x.network=o.network and x.service=v_service
    and x.actor_scope in (v_actor,'both') and x.effective_from<=clock_timestamp()
    and (x.effective_until is null or x.effective_until>clock_timestamp())
    and (x.offer_id is null or x.offer_id=v_offer) and (x.family_id is null or x.family_id=b.family_id)
    order by case when x.offer_id is not null then 3 when x.family_id is not null then 2 else 1 end desc,x.priority desc limit 1;
  if r.id is null then return jsonb_build_object('status','unavailable','reason','no_rule'); end if;
  select * into r2 from public.ussd_execution_rules x where x.id<>r.id and x.purpose='order' and x.status='active' and x.network=r.network
    and x.service=r.service and x.actor_scope in (v_actor,'both') and x.priority=r.priority
    and x.effective_from<=clock_timestamp() and (x.effective_until is null or x.effective_until>clock_timestamp())
    and (x.offer_id is null or x.offer_id=v_offer) and (x.family_id is null or x.family_id=b.family_id)
    and (case when x.offer_id is not null then 3 when x.family_id is not null then 2 else 1 end)=
      (case when r.offer_id is not null then 3 when r.family_id is not null then 2 else 1 end) limit 1;
  if r2.id is not null then return jsonb_build_object('status','unavailable','reason','ambiguous_rule'); end if;
  if 'secret_code'=any(private.ussd_template(r.ussd_template)) then
    v_secret:=private.ussd_secret_settings(o.network,v_actor);
  end if;
  begin v_code:=private.ussd_generate(r.ussd_template,o.beneficiary_phone,o.amount,b.offer_code,b.quantity,v_secret->>'value');
  exception when raise_exception then return jsonb_build_object('status','unavailable','reason',sqlerrm); end;
  begin v_phone:=private.ussd_phone(o.beneficiary_phone); exception when raise_exception then v_phone:=null; end;
  v_network:=case left(v_phone,2) when '07' then 'orange' when '05' then 'mtn' when '01' then 'moov' end;
  v_context:=jsonb_build_object('network',o.network,'service',v_service,'offer_id',v_offer,
    'offer_label',o.offer_label,'beneficiary',o.beneficiary_phone,'amount',o.amount,
    'binding_version',b.version,'quantity',b.quantity,'offer_code',b.offer_code,
    'secret_revision',v_secret->'revision');
  -- Internal notes and author identifiers do not leave the server for actors.
  return jsonb_build_object('status','available','reason','', 'rule',to_jsonb(r)-'internal_note'-'created_by'-'updated_by',
    'code',v_code,'context',v_context,'network_mismatch',coalesce(v_network<>o.network,false));
end $$;

-- BEGIN IDEMPOTENT USSD DRAFT SEED
-- Controlled new family records. Labels are used only to reuse these seed
-- records; real order selection always uses family_id + stable offer IDs.
do $seed$
declare folie uuid; chic uuid; r public.ussd_execution_rules; binding public.ussd_offer_bindings;
begin
  perform pg_advisory_xact_lock(9261031);
  insert into public.ussd_offer_families(id,network,service,label,created_by) values
    ('71000000-0000-4000-8000-000000000001','moov','callBundle','Folie','ussd-seed-v2'),
    ('71000000-0000-4000-8000-000000000002','mtn','mixedBundle','Chic','ussd-seed-v2')
  on conflict do nothing;
  -- Prefer controlled identities even after an administrator renames a family.
  -- Never reuse a record from a different network/service if an ID is occupied.
  select id into strict folie from public.ussd_offer_families where network='moov' and service='callBundle'
    and (id='71000000-0000-4000-8000-000000000001' or label='Folie')
    order by (id='71000000-0000-4000-8000-000000000001') desc limit 1;
  select id into strict chic from public.ussd_offer_families where network='mtn' and service='mixedBundle'
    and (id='71000000-0000-4000-8000-000000000002' or label='Chic')
    order by (id='71000000-0000-4000-8000-000000000002') desc limit 1;

  -- Mapping explicitly reviewed against catalogue metadata on 2026-10-31.
  -- Preserve all existing administrator bindings, including unrelated families.
  for binding in
    insert into public.ussd_offer_bindings(offer_id,family_id,updated_by)
    select c.id,folie,'ussd-seed-v2' from public.catalog_offers c
      where c.id in ('moov-calls-500','moov-calls-1000','moov-calls-1500','moov-calls-2500','moov-calls-5000')
      and c.network='moov' and c.operation_type='callBundle' and c.deleted_at is null
    on conflict(offer_id) do nothing returning *
  loop
    insert into public.ussd_binding_versions values(binding.offer_id,binding.version,to_jsonb(binding))
    on conflict(offer_id,version) do nothing;
  end loop;
  -- MTN catalogue currently contains Free Plus, not an identified Chic offer.
  -- Chic deliberately has NO automatic offer binding. Admin mapping is required
  -- before activation; do not infer a family from the displayed title.

  for r in
    insert into public.ussd_execution_rules(id,seed_key,purpose,network,service,family_id,
      actor_scope,ussd_template,priority,status,effective_from,internal_note,created_by,updated_by)
    select x.id::uuid,x.seed_key,x.purpose,x.network,x.service,x.family_id,
      'both',x.template,0,'draft','2026-10-31T00:00:00Z'::timestamptz,
      x.note||' Syntaxe fournie, à prévisualiser puis valider sur SIM avant activation.','ussd-seed-v2','ussd-seed-v2'
    from (values
      ('72000000-0000-4000-8000-000000000001','moov-pass-appel-v1','order','moov','callBundle',null::uuid,'*412*1#','MOOV — Pass Appel.'),
      ('72000000-0000-4000-8000-000000000002','moov-internet-normal-v1','order','moov','internetSubscription',null::uuid,'*412*2*{{msisdn_local}}#','MOOV — Pass Internet normal.'),
      ('72000000-0000-4000-8000-000000000003','moov-folie-v1','order','moov','callBundle',folie,'*412*4*{{msisdn_local}}#','MOOV — Pass Folie, famille contrôlée.'),
      ('72000000-0000-4000-8000-000000000004','moov-balance-v1','balance','moov',null,null::uuid,'*414*{{secret_code}}#','MOOV — Consultation du solde. Utilitaire séparé, jamais sélectionné pour une commande.'),
      ('72000000-0000-4000-8000-000000000005','moov-unit-transfer-v1','order','moov','unitTransfer',null::uuid,'*410*{{msisdn_local}}*{{amount}}*{{secret_code}}#','MOOV — Transfert d’unité.'),
      ('72000000-0000-4000-8000-000000000006','orange-internet-v1','order','orange','internetSubscription',null::uuid,'#154*1*{{msisdn_local}}#','ORANGE — Pass Internet.'),
      ('72000000-0000-4000-8000-000000000007','orange-call-bundle-v1','order','orange','callBundle',null::uuid,'#154*1*{{msisdn_local}}#','ORANGE — Appels, opération callBundle réelle.'),
      ('72000000-0000-4000-8000-000000000008','orange-mixed-bundle-v1','order','orange','mixedBundle',null::uuid,'#154*1*{{msisdn_local}}#','ORANGE — Appels, opération mixedBundle réelle.'),
      ('72000000-0000-4000-8000-000000000009','mtn-pass-appel-v1','order','mtn','mixedBundle',null::uuid,'*133*6*2*{{msisdn_local}}#','MTN — Pass Appel, catalogue actuel mixedBundle.'),
      ('72000000-0000-4000-8000-000000000010','mtn-pass-internet-v1','order','mtn','internetSubscription',null::uuid,'*133*6*3*{{msisdn_local}}#','MTN — Pass Internet.'),
      ('72000000-0000-4000-8000-000000000011','mtn-chic-v1','order','mtn','mixedBundle',chic,'*133*6*8*{{msisdn_local}}#','MTN — Pass Chic. Association explicite des offres requise ; aucun mapping automatique vers Free Plus.'),
      ('72000000-0000-4000-8000-000000000012','mtn-unit-transfer-v1','order','mtn','unitTransfer',null::uuid,'*133*5*{{msisdn_local}}*{{amount}}#','MTN — Transfert d’unité.')
    ) x(id,seed_key,purpose,network,service,family_id,template,note)
    on conflict(seed_key) do nothing returning *
  loop
    insert into public.ussd_rule_versions values(r.id,r.version,to_jsonb(r))
    on conflict(rule_id,version) do nothing;
  end loop;
end $seed$;
-- END IDEMPOTENT USSD DRAFT SEED

-- New helpers remain internal; do not change existing RPC/role grants.
revoke all on function private.ussd_default_secret() from public,anon,authenticated;
revoke all on function private.ussd_secret_revision() from public,anon,authenticated;
revoke all on function private.ussd_secret_settings(text,text) from public,anon,authenticated;
revoke all on function private.ussd_variable_name(text) from public,anon,authenticated;
revoke all on function private.ussd_normalize_template(text) from public,anon,authenticated;
revoke all on function private.ussd_generate(text,text,bigint,text,integer,text) from public,anon,authenticated;
