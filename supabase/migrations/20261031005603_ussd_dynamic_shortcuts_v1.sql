-- IzyTel USSD V1. LOCAL DELIVERY ONLY: not applied by this intervention.
-- Additive schema: no order, payment, capacity, proof or commission mutation.
-- No operator shortcut is seeded. All real codes require human SIM validation.

create table public.ussd_offer_families (
  id uuid primary key default gen_random_uuid(),
  network text not null check (network in ('orange','mtn','moov')),
  service text not null check (service in ('internetSubscription','callBundle','unitTransfer','sms','mixedBundle','other')),
  label text not null check (length(btrim(label)) between 1 and 100),
  created_by text not null, created_at timestamptz not null default now(),
  unique(network,service,label)
);
create table public.ussd_offer_bindings (
  offer_id text primary key references public.catalog_offers(id),
  family_id uuid references public.ussd_offer_families(id),
  offer_code text check (offer_code ~ '^[0-9]{1,20}$'),
  quantity integer check (quantity between 1 and 999999),
  version integer not null default 1 check (version > 0),
  updated_by text not null, updated_at timestamptz not null default now()
);
create table public.ussd_binding_versions (
  offer_id text not null references public.catalog_offers(id),
  version integer not null, snapshot jsonb not null,
  primary key(offer_id,version)
);
create table public.ussd_order_contexts (
  order_id text primary key references public.phase4_assignment_orders(order_id),
  offer_id text not null references public.catalog_offers(id),
  created_by text not null, created_at timestamptz not null default now()
);
create table public.ussd_execution_rules (
  id uuid primary key default gen_random_uuid(),
  network text not null check (network in ('orange','mtn','moov')),
  service text not null check (service in ('internetSubscription','callBundle','unitTransfer','sms','mixedBundle','other')),
  family_id uuid references public.ussd_offer_families(id),
  offer_id text references public.catalog_offers(id),
  actor_scope text not null check (actor_scope in ('agent','cabiniste','both')),
  ussd_template text not null check (length(ussd_template) between 1 and 512),
  priority integer not null default 0 check (priority between -100000 and 100000),
  status text not null default 'draft' check (status in ('draft','active','disabled')),
  version integer not null default 1 check (version > 0),
  effective_from timestamptz not null, effective_until timestamptz,
  internal_note text not null default '' check (length(internal_note) <= 1000),
  validation_sim_type text check (length(validation_sim_type) between 1 and 100),
  validated_by text, validated_at timestamptz,
  created_by text not null, updated_by text not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (effective_until is null or effective_until > effective_from),
  check (status <> 'active' or (validated_by is not null and validated_at is not null and validation_sim_type is not null))
);
create index ussd_rules_selection on public.ussd_execution_rules(network,service,status,offer_id,family_id,priority desc);
create table public.ussd_rule_versions (
  rule_id uuid not null references public.ussd_execution_rules(id),
  version integer not null, snapshot jsonb not null,
  primary key(rule_id,version)
);
create table public.ussd_execution_logs (
  id uuid primary key default gen_random_uuid(),
  order_id text not null references public.phase4_assignment_orders(order_id),
  rule_id uuid not null, rule_version integer not null,
  actor_uid text not null, actor_type text not null check (actor_type in ('agent','cabiniste')),
  network text not null, service text not null, zone_id text,
  offer_id text, binding_version integer,
  request_id text not null check (length(request_id) between 1 and 100),
  generated_at timestamptz not null default clock_timestamp(), dialer_opened_at timestamptz,
  launch_status text not null default 'prepared' check (launch_status in ('prepared','dialer_opened','failed')),
  error_code text check (error_code in ('dialer_unavailable','interrupted')),
  foreign key(rule_id,rule_version) references public.ussd_rule_versions(rule_id,version),
  unique(actor_uid,request_id)
);
create index ussd_logs_order on public.ussd_execution_logs(order_id,generated_at desc);
create index ussd_logs_scope on public.ussd_execution_logs(zone_id,generated_at desc);
create index ussd_logs_actor on public.ussd_execution_logs(actor_uid,generated_at desc);
create table public.ussd_reports (
  id uuid primary key default gen_random_uuid(),
  order_id text not null references public.phase4_assignment_orders(order_id),
  rule_id uuid, rule_version integer,
  actor_uid text not null, actor_type text not null check (actor_type in ('agent','cabiniste')),
  zone_id text, network text not null,
  reason text not null check (reason in ('incorrect_code','expired_code','wrong_offer','operator_menu_changed','other')),
  note text not null default '' check (length(note) <= 500),
  status text not null default 'open' check (status in ('open','in_progress','escalated','resolved')),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  updated_by text, review_note text not null default '' check (length(review_note) <= 500),
  foreign key(rule_id,rule_version) references public.ussd_rule_versions(rule_id,version),
  check ((rule_id is null) = (rule_version is null))
);
create index ussd_reports_scope on public.ussd_reports(zone_id,created_at desc);
create index ussd_reports_actor on public.ussd_reports(actor_uid,created_at desc);
create table public.ussd_report_events (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.ussd_reports(id),
  status text not null, note text not null,
  actor_uid text not null, occurred_at timestamptz not null default clock_timestamp()
);

-- RPC-only tables: RLS plus no client table grants. In particular, immutable
-- version/event history cannot be updated or truncated by a client SQL role.
do $rls$
declare t text;
begin
  foreach t in array array['ussd_offer_families','ussd_offer_bindings','ussd_binding_versions',
    'ussd_order_contexts','ussd_execution_rules','ussd_rule_versions',
    'ussd_execution_logs','ussd_reports','ussd_report_events'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on table public.%I from public,anon,authenticated',t);
  end loop;
end $rls$;

create function private.ussd_uid() returns text language plpgsql stable set search_path='' as $$
declare v text := nullif((select auth.jwt()->>'sub'),'');
begin
  if v is null or not coalesce(public.is_izytel_firebase_jwt(),false) then
    raise exception 'USSD_AUTH_REQUIRED' using errcode='42501';
  end if;
  return v;
end $$;
create function private.ussd_admin() returns text language plpgsql stable security definer set search_path='' as $$
declare v text := private.ussd_uid();
begin
  if not coalesce(private.is_izytel_finance_admin(),false) then
    raise exception 'USSD_ADMIN_REQUIRED' using errcode='42501';
  end if;
  return v;
end $$;
create function private.ussd_staff() returns text language plpgsql stable security definer set search_path='' as $$
declare v text := private.ussd_uid();
begin
  if coalesce(private.izytel_current_staff_role(),'') not in ('admin','manager','supervisor') then
    raise exception 'USSD_STAFF_REQUIRED' using errcode='42501';
  end if;
  return v;
end $$;
create function private.ussd_zone(p_zone text) returns boolean language sql stable security definer set search_path='' as $$
  select coalesce(public.is_izytel_firebase_jwt(),false) and (
    coalesce(private.is_izytel_finance_admin(),false) or
    (coalesce(private.izytel_current_staff_role(),'') in ('manager','supervisor') and
      coalesce(private.izytel_wc5_manager_owns_zone(p_zone,(select auth.jwt()->>'sub')),false)));
$$;
create function private.ussd_service(p_operation text) returns text language sql immutable set search_path='' as $$
  select p_operation;
$$;
create function private.ussd_actor(p_order public.phase4_assignment_orders) returns text
language plpgsql stable security definer set search_path='' as $$
declare v_uid text := private.ussd_uid();
begin
  if coalesce(private.izytel_current_staff_role(),'') in ('admin','manager','supervisor','operator') then
    raise exception 'USSD_ASSIGNED_ACTOR_REQUIRED' using errcode='42501';
  end if;
  if p_order.assigned_cabiniste_id is null and p_order.assigned_agent_id = v_uid and exists(select 1 from public.phase5_agent_capacities a
    where a.agent_id=v_uid and a.is_active=true and p_order.network=any(a.authorized_networks)) then return 'agent'; end if;
  if exists(select 1 from public.partner_accounts p where p.id=p_order.assigned_cabiniste_id
    and p_order.assigned_agent_id is null and p.firebase_uid=v_uid and p.status='active'
    and p_order.network=any(p.authorized_networks)) then return 'cabiniste'; end if;
  raise exception 'USSD_ASSIGNED_ACTOR_REQUIRED' using errcode='42501';
end $$;
create function private.ussd_phone(p_input text) returns text language plpgsql immutable set search_path='' as $$
declare v text;
begin
  if p_input is null or length(p_input)>80 or p_input !~ '^[+0-9 -]+$' then raise exception 'invalid_beneficiary'; end if;
  v := regexp_replace(p_input,'[ -]','','g');
  if v like '+225%' then v:=substr(v,5);
  elsif v like '00225%' then v:=substr(v,6);
  elsif v like '225%' then v:=substr(v,4); end if;
  if v !~ '^(01|05|07)[0-9]{8}$' then raise exception 'invalid_beneficiary'; end if;
  return v;
end $$;
create function private.ussd_template(p_template text) returns text[] language plpgsql immutable set search_path='' as $$
declare v text; m text[]; names text[] := '{}';
begin
  if p_template is null or length(p_template) not between 1 and 512 then raise exception 'invalid_template'; end if;
  for m in select regexp_matches(p_template,'\{\{([a-z_]+)\}\}','g') loop
    if m[1] not in ('msisdn_local','amount','offer_code','quantity') then raise exception 'unknown_variable'; end if;
    names := array_append(names,m[1]);
  end loop;
  v := regexp_replace(p_template,'\{\{([a-z_]+)\}\}','1','g');
  if length(v)>182 or v !~ '^\*{1,2}[0-9]+(\*[0-9]+)*#$' then raise exception 'invalid_template'; end if;
  return names;
end $$;
create function private.ussd_generate(p_template text,p_beneficiary text,p_amount bigint,p_offer_code text,p_quantity integer)
returns text language plpgsql immutable set search_path='' as $$
declare names text[] := private.ussd_template(p_template); v text := p_template;
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
  if length(v)>182 or v !~ '^\*{1,2}[0-9]+(\*[0-9]+)*#$' then raise exception 'invalid_template'; end if;
  return v;
end $$;

create function private.ussd_rule_visible(r public.ussd_execution_rules) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce(private.is_izytel_finance_admin(),false) or exists (
    select 1 from public.phase4_assignment_orders o
    left join public.ussd_order_contexts ctx on ctx.order_id=o.order_id
    left join public.ussd_offer_bindings b on b.offer_id=ctx.offer_id
    where private.ussd_zone(o.zone_id) and o.network=r.network and private.ussd_service(o.operation_type)=r.service
      and (r.offer_id is null or r.offer_id=ctx.offer_id)
      and (r.family_id is null or r.family_id=b.family_id));
$$;

create function private.ussd_configuration() returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform private.ussd_staff();
  return jsonb_build_object('rules',coalesce((select jsonb_agg(to_jsonb(r) order by r.updated_at desc)
    from public.ussd_execution_rules r where private.ussd_rule_visible(r)),'[]'::jsonb),
    'families',coalesce((select jsonb_agg(to_jsonb(f) order by f.label) from public.ussd_offer_families f),'[]'::jsonb),
    'offers',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'network',c.network,'service',private.ussd_service(c.operation_type),
      'title',c.title,'binding',to_jsonb(b)) order by c.display_order,c.id)
      from public.catalog_offers c left join public.ussd_offer_bindings b on b.offer_id=c.id
      where c.deleted_at is null),'[]'::jsonb));
end $$;

create function private.ussd_save_family(p_network text,p_service text,p_label text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_admin(); v_id uuid;
begin
  insert into public.ussd_offer_families(network,service,label,created_by)
  values(p_network,p_service,btrim(p_label),v_uid) returning id into v_id;
  return v_id;
end $$;

create function private.ussd_save_binding(p_offer_id text,p_family_id uuid,p_offer_code text,p_quantity integer) returns void
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_admin(); c public.catalog_offers; b public.ussd_offer_bindings;
begin
  perform pg_advisory_xact_lock(9261031);
  select * into strict c from public.catalog_offers where id=p_offer_id and deleted_at is null;
  if p_family_id is not null and not exists(select 1 from public.ussd_offer_families f
    where f.id=p_family_id and f.network=c.network and f.service=private.ussd_service(c.operation_type)) then raise exception 'invalid_association'; end if;
  select * into b from public.ussd_offer_bindings where offer_id=p_offer_id;
  if exists(select 1 from public.ussd_execution_rules r where r.status='active' and r.network=c.network
    and r.service=private.ussd_service(c.operation_type) and (r.offer_id=p_offer_id or r.family_id in (b.family_id,p_family_id))) then
    raise exception 'active_binding_in_use';
  end if;
  insert into public.ussd_offer_bindings(offer_id,family_id,offer_code,quantity,updated_by)
  values(p_offer_id,p_family_id,nullif(p_offer_code,''),p_quantity,v_uid)
  on conflict(offer_id) do update set family_id=excluded.family_id,offer_code=excluded.offer_code,
    quantity=excluded.quantity,version=public.ussd_offer_bindings.version+1,updated_by=v_uid,updated_at=clock_timestamp()
  returning * into b;
  insert into public.ussd_binding_versions values(b.offer_id,b.version,to_jsonb(b));
end $$;

create function private.ussd_save_rule(p_rule_id uuid,p_expected_version integer,p_payload jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_admin(); r public.ussd_execution_rules; v_id uuid := coalesce(p_rule_id,gen_random_uuid());
begin
  perform pg_advisory_xact_lock(9261031);
  if jsonb_typeof(p_payload)<>'object' or exists(select 1 from jsonb_object_keys(p_payload) k
    where k not in ('network','service','family_id','offer_id','actor_scope','ussd_template','priority','effective_from','effective_until','internal_note')) then raise exception 'invalid_payload'; end if;
  perform private.ussd_template(p_payload->>'ussd_template');
  if p_rule_id is not null then
    select * into strict r from public.ussd_execution_rules where id=p_rule_id for update;
    if p_expected_version is distinct from r.version then raise exception 'rule_changed'; end if;
  end if;
  insert into public.ussd_execution_rules(id,network,service,family_id,offer_id,actor_scope,ussd_template,priority,
    effective_from,effective_until,internal_note,created_by,updated_by)
  values(v_id,p_payload->>'network',p_payload->>'service',nullif(p_payload->>'family_id','')::uuid,
    nullif(p_payload->>'offer_id',''),p_payload->>'actor_scope',p_payload->>'ussd_template',
    coalesce((p_payload->>'priority')::integer,0),(p_payload->>'effective_from')::timestamptz,
    nullif(p_payload->>'effective_until','')::timestamptz,coalesce(p_payload->>'internal_note',''),v_uid,v_uid)
  on conflict(id) do update set network=excluded.network,service=excluded.service,family_id=excluded.family_id,
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

create function private.ussd_set_status(p_rule_id uuid,p_expected_version integer,p_status text,p_sim_type text) returns void
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
      and x.network=r.network and x.service=r.service and x.priority=r.priority
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

create function private.ussd_register_order_context(p_order_id text,p_offer_id text) returns void
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_staff(); o public.phase4_assignment_orders;
begin
  select * into strict o from public.phase4_assignment_orders where order_id=p_order_id for share;
  if not private.ussd_zone(o.zone_id) then raise exception 'USSD_ZONE_REQUIRED' using errcode='42501'; end if;
  if not exists(select 1 from public.catalog_offers c where c.id=p_offer_id and c.deleted_at is null
    and c.network=o.network and c.operation_type=o.operation_type) then raise exception 'invalid_association'; end if;
  -- Never overwrite a registered identity or derive it by matching labels.
  insert into public.ussd_order_contexts(order_id,offer_id,created_by) values(p_order_id,p_offer_id,v_uid)
  on conflict(order_id) do nothing;
  if exists(select 1 from public.ussd_order_contexts c where c.order_id=p_order_id and c.offer_id<>p_offer_id) then raise exception 'order_context_changed'; end if;
end $$;

create function private.ussd_resolve(p_order_id text) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.phase4_assignment_orders; r public.ussd_execution_rules; r2 public.ussd_execution_rules;
  b public.ussd_offer_bindings; v_actor text; v_offer text; v_service text; v_code text; v_phone text;
  v_network text; v_context jsonb;
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
  select * into r from public.ussd_execution_rules x where x.status='active' and x.network=o.network and x.service=v_service
    and x.actor_scope in (v_actor,'both') and x.effective_from<=clock_timestamp()
    and (x.effective_until is null or x.effective_until>clock_timestamp())
    and (x.offer_id is null or x.offer_id=v_offer) and (x.family_id is null or x.family_id=b.family_id)
    order by case when x.offer_id is not null then 3 when x.family_id is not null then 2 else 1 end desc,x.priority desc limit 1;
  if r.id is null then return jsonb_build_object('status','unavailable','reason','no_rule'); end if;
  select * into r2 from public.ussd_execution_rules x where x.id<>r.id and x.status='active' and x.network=r.network
    and x.service=r.service and x.actor_scope in (v_actor,'both') and x.priority=r.priority
    and x.effective_from<=clock_timestamp() and (x.effective_until is null or x.effective_until>clock_timestamp())
    and (x.offer_id is null or x.offer_id=v_offer) and (x.family_id is null or x.family_id=b.family_id)
    and (case when x.offer_id is not null then 3 when x.family_id is not null then 2 else 1 end)=
      (case when r.offer_id is not null then 3 when r.family_id is not null then 2 else 1 end) limit 1;
  if r2.id is not null then return jsonb_build_object('status','unavailable','reason','ambiguous_rule'); end if;
  begin v_code:=private.ussd_generate(r.ussd_template,o.beneficiary_phone,o.amount,b.offer_code,b.quantity);
  exception when raise_exception then return jsonb_build_object('status','unavailable','reason',sqlerrm); end;
  begin v_phone:=private.ussd_phone(o.beneficiary_phone); exception when raise_exception then v_phone:=null; end;
  v_network:=case left(v_phone,2) when '07' then 'orange' when '05' then 'mtn' when '01' then 'moov' end;
  v_context:=jsonb_build_object('network',o.network,'service',v_service,'offer_id',v_offer,
    'offer_label',o.offer_label,'beneficiary',o.beneficiary_phone,'amount',o.amount,
    'binding_version',b.version,'quantity',b.quantity,'offer_code',b.offer_code);
  -- Internal notes and author identifiers do not leave the server for actors.
  return jsonb_build_object('status','available','reason','', 'rule',to_jsonb(r)-'internal_note'-'created_by'-'updated_by',
    'code',v_code,'context',v_context,'network_mismatch',coalesce(v_network<>o.network,false));
end $$;

create function private.ussd_prepare(p_order_id text,p_rule_id uuid,p_version integer,p_context jsonb,p_request_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_uid(); o public.phase4_assignment_orders; v jsonb; v_log public.ussd_execution_logs; v_deadline timestamptz;
begin
  -- Serialize activation/disable/binding edits against preparing a launch.
  perform pg_advisory_xact_lock(9261031);
  select * into strict o from public.phase4_assignment_orders where order_id=p_order_id for share;
  v:=private.ussd_resolve(p_order_id);
  if v->>'status'<>'available' then return v; end if;
  if (v->'rule'->>'id')::uuid is distinct from p_rule_id or (v->'rule'->>'version')::integer is distinct from p_version
    or (v->'context') is distinct from p_context then
    return jsonb_build_object('status','unavailable','reason','rule_changed'); end if;
  if exists(select 1 from public.ussd_execution_logs where actor_uid=v_uid and request_id=p_request_id) then
    return jsonb_build_object('status','unavailable','reason','duplicate_attempt'); end if;
  if (select count(*) from public.ussd_execution_logs where actor_uid=v_uid and generated_at>clock_timestamp()-interval '1 minute')>=10 then
    raise exception 'USSD_RATE_LIMIT'; end if;
  insert into public.ussd_execution_logs(order_id,rule_id,rule_version,actor_uid,actor_type,network,service,zone_id,
    offer_id,binding_version,request_id)
  values(p_order_id,p_rule_id,p_version,v_uid,private.ussd_actor(o),o.network,v->'context'->>'service',o.zone_id,
    v->'context'->>'offer_id',(v->'context'->>'binding_version')::integer,p_request_id) returning * into v_log;
  v_deadline:=least(clock_timestamp()+interval '10 seconds',coalesce((v->'rule'->>'effective_until')::timestamptz,'infinity'::timestamptz));
  return v || jsonb_build_object('attempt_id',v_log.id,'valid_for_ms',
    greatest(0,floor(extract(epoch from (v_deadline-clock_timestamp()))*1000)::integer));
end $$;

create function private.ussd_record_result(p_attempt_id uuid,p_status text,p_error_code text) returns void
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_uid(); l public.ussd_execution_logs;
begin
  if p_status is null or p_status not in ('dialer_opened','failed') or (p_error_code is not null and p_error_code not in ('dialer_unavailable','interrupted')) then raise exception 'invalid_status'; end if;
  select * into strict l from public.ussd_execution_logs where id=p_attempt_id and actor_uid=v_uid for update;
  if l.launch_status=p_status then return; end if;
  if l.launch_status<>'prepared' then raise exception 'attempt_already_recorded'; end if;
  update public.ussd_execution_logs set launch_status=p_status,error_code=p_error_code,
    dialer_opened_at=case when p_status='dialer_opened' then clock_timestamp() end where id=l.id;
end $$;

create function private.ussd_report(p_order_id text,p_rule_id uuid,p_version integer,p_reason text,p_note text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_uid(); o public.phase4_assignment_orders; v_actor text; v_id uuid; v_offer text; v_family uuid;
begin
  select * into strict o from public.phase4_assignment_orders where order_id=p_order_id;
  v_actor:=private.ussd_actor(o);
  select ctx.offer_id,b.family_id into v_offer,v_family from public.ussd_order_contexts ctx
    left join public.ussd_offer_bindings b on b.offer_id=ctx.offer_id where ctx.order_id=p_order_id;
  if (select count(*) from public.ussd_reports where actor_uid=v_uid and created_at>clock_timestamp()-interval '1 minute')>=5 then raise exception 'USSD_RATE_LIMIT'; end if;
  if coalesce(p_note,'') ~ '[0-9]([[:space:].()+-]*[0-9]){7,}' or regexp_replace(coalesce(p_note,''),'[[:space:]]','','g') ~ '\*[0-9*]+#' then raise exception 'sensitive_report_content'; end if;
  if p_rule_id is not null and not exists(select 1 from public.ussd_rule_versions rv
    where rv.rule_id=p_rule_id and rv.version=p_version and rv.snapshot->>'network'=o.network
    and rv.snapshot->>'service'=private.ussd_service(o.operation_type)
    and rv.snapshot->>'actor_scope' in (v_actor,'both') and (
      exists(select 1 from public.ussd_execution_logs l where l.order_id=p_order_id and l.actor_uid=v_uid
        and l.rule_id=p_rule_id and l.rule_version=p_version)
      or ((rv.snapshot->>'offer_id' is null or rv.snapshot->>'offer_id'=v_offer)
        and (rv.snapshot->>'family_id' is null or rv.snapshot->>'family_id'=v_family::text))
    )) then raise exception 'invalid_association'; end if;
  insert into public.ussd_reports(order_id,rule_id,rule_version,actor_uid,actor_type,zone_id,network,reason,note)
    values(p_order_id,p_rule_id,p_version,v_uid,v_actor,o.zone_id,o.network,p_reason,coalesce(p_note,'')) returning id into v_id;
  insert into public.ussd_report_events(report_id,status,note,actor_uid) values(v_id,'open','',v_uid);
  return v_id;
end $$;

create function private.ussd_review_report(p_report_id uuid,p_status text,p_note text) returns void
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_staff(); r public.ussd_reports;
begin
  select * into strict r from public.ussd_reports where id=p_report_id for update;
  if not private.ussd_zone(r.zone_id) then raise exception 'USSD_ZONE_REQUIRED' using errcode='42501'; end if;
  if p_status is null or p_status not in ('in_progress','escalated','resolved') or length(coalesce(p_note,''))>500 then raise exception 'invalid_status'; end if;
  if coalesce(p_note,'') ~ '[0-9]([[:space:].()+-]*[0-9]){7,}' or regexp_replace(coalesce(p_note,''),'[[:space:]]','','g') ~ '\*[0-9*]+#' then raise exception 'sensitive_report_content'; end if;
  update public.ussd_reports set status=p_status,review_note=coalesce(p_note,''),updated_by=v_uid,updated_at=clock_timestamp() where id=r.id;
  insert into public.ussd_report_events(report_id,status,note,actor_uid) values(r.id,p_status,coalesce(p_note,''),v_uid);
end $$;

create function private.ussd_history(p_rule_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.ussd_execution_rules;
begin
  perform private.ussd_admin();
  select * into strict r from public.ussd_execution_rules where id=p_rule_id;
  if not private.ussd_rule_visible(r) then raise exception 'USSD_ZONE_REQUIRED' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(snapshot order by version desc) from public.ussd_rule_versions where rule_id=p_rule_id),'[]'::jsonb);
end $$;
create function private.ussd_binding_history(p_offer_id text) returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform private.ussd_admin();
  return coalesce((select jsonb_agg(snapshot order by version desc) from public.ussd_binding_versions where offer_id=p_offer_id),'[]'::jsonb);
end $$;
create function private.ussd_logs(p_offset integer) returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform private.ussd_staff();
  if p_offset is null or p_offset not between 0 and 100000 then raise exception 'invalid_offset'; end if;
  return coalesce((select jsonb_agg(to_jsonb(t) order by generated_at desc) from (
    select l.* from public.ussd_execution_logs l where private.ussd_zone(l.zone_id)
    order by l.generated_at desc,l.id limit 50 offset p_offset) t),'[]'::jsonb);
end $$;
create function private.ussd_reports(p_offset integer) returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform private.ussd_staff();
  if p_offset is null or p_offset not between 0 and 100000 then raise exception 'invalid_offset'; end if;
  return coalesce((select jsonb_agg(to_jsonb(t) order by created_at desc) from (
    select r.*,coalesce((select jsonb_agg(to_jsonb(e) order by e.occurred_at)
      from public.ussd_report_events e where e.report_id=r.id),'[]'::jsonb) as events
    from public.ussd_reports r where private.ussd_zone(r.zone_id)
    order by r.created_at desc,r.id limit 50 offset p_offset) t),'[]'::jsonb);
end $$;

-- Public API wrappers remain SECURITY INVOKER. Private implementation owns its
-- authorization checks and never accepts an actor UID/role from the client.
create function public.izytel_ussd_configuration() returns jsonb language sql set search_path='' as $$ select private.ussd_configuration(); $$;
create function public.izytel_ussd_save_family(p_network text,p_service text,p_label text) returns uuid language sql set search_path='' as $$ select private.ussd_save_family(p_network,p_service,p_label); $$;
create function public.izytel_ussd_save_binding(p_offer_id text,p_family_id uuid,p_offer_code text,p_quantity integer) returns void language sql set search_path='' as $$ select private.ussd_save_binding(p_offer_id,p_family_id,p_offer_code,p_quantity); $$;
create function public.izytel_ussd_save_rule(p_rule_id uuid,p_expected_version integer,p_payload jsonb) returns uuid language sql set search_path='' as $$ select private.ussd_save_rule(p_rule_id,p_expected_version,p_payload); $$;
create function public.izytel_ussd_set_status(p_rule_id uuid,p_expected_version integer,p_status text,p_sim_type text) returns void language sql set search_path='' as $$ select private.ussd_set_status(p_rule_id,p_expected_version,p_status,p_sim_type); $$;
create function public.izytel_ussd_register_order_context(p_order_id text,p_offer_id text) returns void language sql set search_path='' as $$ select private.ussd_register_order_context(p_order_id,p_offer_id); $$;
create function public.izytel_ussd_resolve(p_order_id text) returns jsonb language sql set search_path='' as $$ select private.ussd_resolve(p_order_id); $$;
create function public.izytel_ussd_prepare(p_order_id text,p_rule_id uuid,p_version integer,p_context jsonb,p_request_id text) returns jsonb language sql set search_path='' as $$ select private.ussd_prepare(p_order_id,p_rule_id,p_version,p_context,p_request_id); $$;
create function public.izytel_ussd_record_result(p_attempt_id uuid,p_status text,p_error_code text) returns void language sql set search_path='' as $$ select private.ussd_record_result(p_attempt_id,p_status,p_error_code); $$;
create function public.izytel_ussd_report(p_order_id text,p_rule_id uuid,p_version integer,p_reason text,p_note text) returns uuid language sql set search_path='' as $$ select private.ussd_report(p_order_id,p_rule_id,p_version,p_reason,p_note); $$;
create function public.izytel_ussd_review_report(p_report_id uuid,p_status text,p_note text) returns void language sql set search_path='' as $$ select private.ussd_review_report(p_report_id,p_status,p_note); $$;
create function public.izytel_ussd_history(p_rule_id uuid) returns jsonb language sql set search_path='' as $$ select private.ussd_history(p_rule_id); $$;
create function public.izytel_ussd_binding_history(p_offer_id text) returns jsonb language sql set search_path='' as $$ select private.ussd_binding_history(p_offer_id); $$;
create function public.izytel_ussd_logs(p_offset integer default 0) returns jsonb language sql set search_path='' as $$ select private.ussd_logs(p_offset); $$;
create function public.izytel_ussd_reports(p_offset integer default 0) returns jsonb language sql set search_path='' as $$ select private.ussd_reports(p_offset); $$;

do $permissions$
declare r record;
begin
  for r in select p.oid::regprocedure as signature,n.nspname,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='private' and p.proname like 'ussd\_%' escape '\') or
      (n.nspname='public' and p.proname like 'izytel\_ussd\_%' escape '\') loop
    execute format('revoke all on function %s from public,anon,authenticated',r.signature);
    if r.nspname='public' or r.proname in ('ussd_configuration','ussd_save_family','ussd_save_binding','ussd_save_rule',
      'ussd_set_status','ussd_register_order_context','ussd_resolve','ussd_prepare','ussd_record_result',
      'ussd_report','ussd_review_report','ussd_history','ussd_binding_history','ussd_logs','ussd_reports') then
      execute format('grant execute on function %s to anon,authenticated',r.signature);
    end if;
  end loop;
end $permissions$;
grant usage on schema private to anon,authenticated;
-- Firebase JWTs without a custom SQL-role claim may run as anon. Every granted
-- entry point verifies the existing Firebase project JWT helper and live roles.
