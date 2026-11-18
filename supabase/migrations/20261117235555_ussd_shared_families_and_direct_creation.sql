-- Shared commercial families (Folie, Maxit, C'Chic, night passes, etc.).
-- New administrator-created rules become active atomically after validation.
-- Existing drafts and SIM validations are preserved; no telecom action occurs.
alter table public.ussd_offer_families drop constraint ussd_offer_families_service_check;
alter table public.ussd_offer_families add constraint ussd_offer_families_service_check
  check (service in ('all','internetSubscription','callBundle','unitTransfer','sms','mixedBundle','other'));
alter table public.ussd_execution_rules drop constraint ussd_execution_rules_service_check;
alter table public.ussd_execution_rules add constraint ussd_execution_rules_service_check
  check (service in ('all','internetSubscription','callBundle','unitTransfer','sms','mixedBundle','other'));
alter table public.ussd_execution_rules add column validation_method text not null default 'sim'
  check (validation_method in ('sim','creation'));
-- Creation validation is an administrative validation, never a claimed SIM test.
do $constraint$
declare c record;
begin
  for c in select conname from pg_constraint
    where conrelid='public.ussd_execution_rules'::regclass and contype='c'
    and pg_get_constraintdef(oid) like '%validated_by%'
  loop
    execute format('alter table public.ussd_execution_rules drop constraint %I',c.conname);
  end loop;
end $constraint$;
alter table public.ussd_execution_rules add constraint ussd_active_validation check (
  status <> 'active' or (validated_by is not null and validated_at is not null
    and (validation_method='creation' or validation_sim_type is not null)));


create function private.ussd_validate_rule(r public.ussd_execution_rules) returns void
language plpgsql security definer set search_path='' as $$
declare vars text[];
begin
  perform private.ussd_admin();
    vars:=private.ussd_template(r.ussd_template);
    if r.service='sms' and not exists(select 1 from public.catalog_offers c where c.operation_type='sms' and c.deleted_at is null) then raise exception 'unsupported_order_service'; end if;
    if r.family_id is not null and not exists(select 1 from public.ussd_offer_families f
      where f.id=r.family_id and f.network=r.network and (f.service='all' or r.service='all' or f.service=r.service)) then raise exception 'invalid_association'; end if;
    if r.offer_id is not null and not exists(select 1 from public.catalog_offers c
      left join public.ussd_offer_bindings b on b.offer_id=c.id where c.id=r.offer_id and c.deleted_at is null
      and c.network=r.network and (r.service='all' or private.ussd_service(c.operation_type)=r.service) and (r.family_id is null or b.family_id=r.family_id)) then raise exception 'invalid_association'; end if;

    if r.effective_until is not null and r.effective_until<=clock_timestamp() then raise exception 'expired_rule'; end if;
    if ('offer_code'=any(vars) or 'quantity'=any(vars)) then
      if r.offer_id is null and r.family_id is null then raise exception 'missing_offer_context'; end if;
      if not exists(select 1 from public.catalog_offers c left join public.ussd_offer_bindings b on b.offer_id=c.id
        where c.deleted_at is null and c.network=r.network and (r.service='all' or private.ussd_service(c.operation_type)=r.service)
        and (r.offer_id is null or c.id=r.offer_id) and (r.family_id is null or b.family_id=r.family_id)) then raise exception 'missing_offer_context'; end if;
      if exists(select 1 from public.catalog_offers c left join public.ussd_offer_bindings b on b.offer_id=c.id
        where c.deleted_at is null and c.network=r.network and (r.service='all' or private.ussd_service(c.operation_type)=r.service)
        and (r.offer_id is null or c.id=r.offer_id) and (r.family_id is null or b.family_id=r.family_id)
        and (('offer_code'=any(vars) and b.offer_code is null) or ('quantity'=any(vars) and b.quantity is null))) then raise exception 'missing_offer_context'; end if;
    end if;
    if exists(select 1 from public.ussd_execution_rules x where x.id<>r.id and x.status='active'
      and x.network=r.network and x.purpose=r.purpose and (x.service is not distinct from r.service or x.service='all' or r.service='all') and x.priority=r.priority
      and (x.actor_scope=r.actor_scope or x.actor_scope='both' or r.actor_scope='both')
      and ((r.offer_id is not null and x.offer_id=r.offer_id) or
        (r.offer_id is null and x.offer_id is null and r.family_id is not distinct from x.family_id))
      and tstzrange(x.effective_from,x.effective_until,'[)') && tstzrange(r.effective_from,r.effective_until,'[)')) then raise exception 'ambiguous_rule'; end if;
end $$;

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
    where f.id=r.family_id and f.network=r.network and (f.service='all' or r.service='all' or f.service=r.service)) then raise exception 'invalid_association'; end if;
  if r.offer_id is not null and not exists(select 1 from public.catalog_offers c
    left join public.ussd_offer_bindings b on b.offer_id=c.id where c.id=r.offer_id and c.deleted_at is null
    and c.network=r.network and (r.service='all' or private.ussd_service(c.operation_type)=r.service) and (r.family_id is null or b.family_id=r.family_id)) then raise exception 'invalid_association'; end if;
  if p_rule_id is null then
    perform private.ussd_validate_rule(r);
    update public.ussd_execution_rules set status='active',validation_method='creation',
      validated_by=v_uid,validated_at=clock_timestamp(),validation_sim_type=null
      where id=r.id returning * into r;
  end if;
  insert into public.ussd_rule_versions values(r.id,r.version,to_jsonb(r));
  return r.id;
end $$;

create or replace function private.ussd_set_status(p_rule_id uuid,p_expected_version integer,p_status text,p_sim_type text) returns void
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_admin(); r public.ussd_execution_rules;
begin
  perform pg_advisory_xact_lock(9261031);
  select * into strict r from public.ussd_execution_rules where id=p_rule_id for update;
  if p_expected_version is distinct from r.version then raise exception 'rule_changed'; end if;
  if p_status is null or p_status not in ('active','disabled') then raise exception 'invalid_status'; end if;
  if p_status='active' then
    perform private.ussd_validate_rule(r);
    if length(btrim(coalesce(p_sim_type,''))) not between 1 and 100
      or p_sim_type ~ '[0-9]([[:space:].()+-]*[0-9]){7,}' then raise exception 'sim_validation_required'; end if;
  end if;
  update public.ussd_execution_rules set status=p_status,version=version+1,
    validation_method=case when p_status='active' then 'sim' else validation_method end,
    validation_sim_type=case when p_status='active' then btrim(p_sim_type) else validation_sim_type end,
    validated_by=case when p_status='active' then v_uid else validated_by end,
    validated_at=case when p_status='active' then clock_timestamp() else validated_at end,
    updated_by=v_uid,updated_at=clock_timestamp() where id=r.id returning * into r;
  insert into public.ussd_rule_versions values(r.id,r.version,to_jsonb(r));
end $$;

create or replace function private.ussd_save_binding(p_offer_id text,p_family_id uuid,p_offer_code text,p_quantity integer) returns void
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_admin(); c public.catalog_offers; b public.ussd_offer_bindings; v_next integer;
begin
  perform pg_advisory_xact_lock(9261031);
  select * into strict c from public.catalog_offers where id=p_offer_id and deleted_at is null;
  if p_family_id is not null and not exists(select 1 from public.ussd_offer_families f
    where f.id=p_family_id and f.deleted_at is null and f.network=c.network and (f.service='all' or f.service=private.ussd_service(c.operation_type))) then raise exception 'invalid_association'; end if;
  select * into b from public.ussd_offer_bindings where offer_id=p_offer_id;
  if exists(select 1 from public.ussd_execution_rules r where r.status='active' and r.network=c.network
    and (r.service='all' or r.service=private.ussd_service(c.operation_type)) and (r.offer_id=p_offer_id or r.family_id=b.family_id)) then
    raise exception 'active_binding_in_use';
  end if;
  -- Offers may join a configured family after the syntax has been created.
  -- Existing contexts stay protected, and every required variable must exist.
  if exists(select 1 from public.ussd_execution_rules r
    where r.status='active' and r.network=c.network and r.family_id=p_family_id
      and (r.service='all' or r.service=private.ussd_service(c.operation_type))
      and (r.offer_id is null or r.offer_id=p_offer_id)
      and (('offer_code'=any(private.ussd_template(r.ussd_template)) and nullif(p_offer_code,'') is null)
        or ('quantity'=any(private.ussd_template(r.ussd_template)) and p_quantity is null))) then
    raise exception 'missing_offer_context';
  end if;
  select coalesce(max(version),0)+1 into v_next from public.ussd_binding_versions where offer_id=p_offer_id;
  insert into public.ussd_offer_bindings(offer_id,family_id,offer_code,quantity,version,updated_by)
  values(p_offer_id,p_family_id,nullif(p_offer_code,''),p_quantity,v_next,v_uid)
  on conflict(offer_id) do update set family_id=excluded.family_id,offer_code=excluded.offer_code,
    quantity=excluded.quantity,version=excluded.version,updated_by=v_uid,updated_at=clock_timestamp()
  returning * into b;
  insert into public.ussd_binding_versions values(b.offer_id,b.version,to_jsonb(b));
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
  select * into r from public.ussd_execution_rules x where x.purpose='order' and x.status='active' and x.network=o.network and (x.service='all' or x.service=v_service)
    and x.actor_scope in (v_actor,'both') and x.effective_from<=clock_timestamp()
    and (x.effective_until is null or x.effective_until>clock_timestamp())
    and (x.offer_id is null or x.offer_id=v_offer) and (x.family_id is null or x.family_id=b.family_id)
    order by case when x.offer_id is not null then 3 when x.family_id is not null then 2 else 1 end desc,x.priority desc limit 1;
  if r.id is null then return jsonb_build_object('status','unavailable','reason','no_rule'); end if;
  select * into r2 from public.ussd_execution_rules x where x.id<>r.id and x.purpose='order' and x.status='active' and x.network=r.network
    and (x.service='all' or x.service=v_service) and x.actor_scope in (v_actor,'both') and x.priority=r.priority
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

revoke all on function private.ussd_validate_rule(public.ussd_execution_rules) from public,anon,authenticated;

create or replace function private.ussd_rule_visible(r public.ussd_execution_rules) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce(private.is_izytel_finance_admin(),false) or exists (
    select 1 from public.phase4_assignment_orders o
    left join public.ussd_order_contexts ctx on ctx.order_id=o.order_id
    left join public.ussd_offer_bindings b on b.offer_id=ctx.offer_id
    where private.ussd_zone(o.zone_id) and o.network=r.network
      and (r.service='all' or private.ussd_service(o.operation_type)=r.service)
      and (r.offer_id is null or r.offer_id=ctx.offer_id)
      and (r.family_id is null or r.family_id=b.family_id));
$$;
