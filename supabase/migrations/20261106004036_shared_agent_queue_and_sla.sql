-- IzyTel AFF-1 / SLA-1 / NOTIF-1. Additive, disabled until explicit activation.
-- No cron.schedule, production backfill, financial mutation or historical reallocation.
begin;

create table private.izytel_shared_queue_settings (
  singleton boolean primary key default true check(singleton),
  activated_at timestamptz,
  enabled boolean not null default false
);
insert into private.izytel_shared_queue_settings(singleton,enabled) values(true,false);
revoke all on private.izytel_shared_queue_settings from public,anon,authenticated;
alter table private.izytel_shared_queue_settings enable row level security;

alter table public.phase4_assignment_orders
  add column assignment_route text not null default 'legacy' check(assignment_route in ('legacy','shared')),
  add column assignment_version bigint not null default 0 check(assignment_version>=0),
  add column accepted_at timestamptz,
  add column available_at timestamptz;

create index phase4_shared_available_idx on public.phase4_assignment_orders(zone_id,available_at,order_id)
  where assignment_route='shared' and assignment_state='waiting' and assigned_agent_id is null;
create index phase4_acceptance_sla_idx on public.phase4_assignment_orders(accepted_at,order_id)
  where accepted_at is not null and assigned_agent_id is not null
    and order_status in ('paidReady','inProgress','onHold');

create table public.izytel_shared_queue_signals (
  zone_id text primary key references public.territory_zones(id) on delete cascade,
  revision bigint not null default 1,
  updated_at timestamptz not null default now()
);
create table public.izytel_order_delay_alerts (
  id uuid primary key default gen_random_uuid(),
  order_id text not null references public.phase4_assignment_orders(order_id) on delete restrict,
  assignment_version bigint not null,
  alert_type text not null default 'acceptance_delay' check(alert_type='acceptance_delay'),
  zone_id text not null,
  agent_id text not null,
  agent_name text not null,
  accepted_at timestamptz not null,
  created_at timestamptz not null default now(),
  state text not null default 'active' check(state in ('active','resolved','obsolete')),
  resolved_at timestamptz,
  unique(order_id,assignment_version,alert_type)
);
create index izytel_active_delay_zone_idx on public.izytel_order_delay_alerts(zone_id,created_at desc)
  where state='active';
alter table public.izytel_shared_queue_signals enable row level security;
alter table public.izytel_order_delay_alerts enable row level security;
revoke all on public.izytel_shared_queue_signals,public.izytel_order_delay_alerts from public,anon,authenticated;
grant select on public.izytel_shared_queue_signals,public.izytel_order_delay_alerts to anon,authenticated;

create function private.izytel_shared_agent_zone(p_zone text)
returns boolean language sql stable security definer set search_path=''
as $$
  select public.is_izytel_firebase_jwt() and exists(
    select 1 from public.phase5_agent_capacities a
    join public.territory_zones z on z.id=p_zone and z.is_active
    where a.agent_id=(select auth.jwt()->>'sub') and a.is_active and z.id=any(a.zone_ids)
  );
$$;
create function private.izytel_shared_staff_zone(p_zone text)
returns boolean language sql stable security definer set search_path=''
as $$
  select public.is_izytel_firebase_jwt() and (
    private.is_izytel_finance_admin() or
    (private.izytel_current_staff_role() in ('manager','supervisor') and
     private.izytel_wc5_manager_owns_zone(p_zone,(select auth.jwt()->>'sub')))
  );
$$;
revoke all on function private.izytel_shared_agent_zone(text),private.izytel_shared_staff_zone(text) from public;
grant execute on function private.izytel_shared_agent_zone(text),private.izytel_shared_staff_zone(text) to anon,authenticated;

create policy "shared signals own territory" on public.izytel_shared_queue_signals for select to anon,authenticated
using(private.izytel_shared_agent_zone(zone_id) or private.izytel_shared_staff_zone(zone_id));
create policy "delay alerts staff territory" on public.izytel_order_delay_alerts for select to anon,authenticated
using(private.izytel_shared_staff_zone(zone_id));

-- Do not expose unassigned full order records through the existing SELECT policy.
create function private.izytel_shared_available(p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid text:=(select auth.jwt()->>'sub'); v_enabled boolean; v_orders jsonb;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode='42501';
  end if;
  if not exists(select 1 from public.phase5_agent_capacities where agent_id=v_uid and is_active) then
    raise exception 'ACTIVE_AGENT_REQUIRED' using errcode='42501';
  end if;
  select enabled into v_enabled from private.izytel_shared_queue_settings where singleton;
  select coalesce(jsonb_agg(x.payload order by x.available_at,x.order_id),'[]'::jsonb) into v_orders
  from (
    select o.order_id,o.available_at,jsonb_build_object(
      'order_id',o.order_id,'order_reference',o.order_reference,'zone_id',o.zone_id,
      'network',o.network,'operation_type',o.operation_type,'offer_label',o.offer_label,
      'amount',o.amount,'available_at',o.available_at,
      'beneficiary_masked',case when length(regexp_replace(o.beneficiary_phone,'[^0-9]','','g'))>=4
        then '•• •• •• '||right(regexp_replace(o.beneficiary_phone,'[^0-9]','','g'),4) else '••••' end,
      'assignment_version',o.assignment_version,
      'can_accept',private.phase3_agent_is_eligible(v_uid,o.order_id)
    ) payload
    from public.phase4_assignment_orders o
    join public.phase5_agent_capacities a on a.agent_id=v_uid
    where v_enabled and private.izytel_shared_agent_zone(o.zone_id)
      and o.network=any(a.authorized_networks)
      and o.assignment_route='shared' and o.assignment_state='waiting'
      and o.assigned_agent_id is null and o.assigned_cabiniste_id is null
      and o.payment_status='confirmed' and o.order_status='paidReady' and not o.legacy_state_unresolved
    order by o.available_at,o.order_id limit greatest(1,least(coalesce(p_limit,100),100))
  ) x;
  return jsonb_build_object('enabled',v_enabled,'server_now',clock_timestamp(),'orders',v_orders);
end;
$$;
create function public.izytel_shared_available(p_limit integer default 100)
returns jsonb language sql set search_path='' as $$select private.izytel_shared_available(p_limit);$$;
revoke all on function private.izytel_shared_available(integer),public.izytel_shared_available(integer) from public;
grant execute on function private.izytel_shared_available(integer),public.izytel_shared_available(integer) to anon,authenticated;

-- New shared records use a dedicated guard. The historical guard and Cabiniste
-- code are preserved verbatim and still execute for all historical records.
create function private.izytel_shared_order_guard()
returns trigger language plpgsql security definer set search_path=''
as $$
declare
  v_uid text:=(select auth.jwt()->>'sub');
  v_staff boolean;
  v_allowed text[]:=array['assignment_state','assigned_agent_id','assigned_agent_name','assigned_by_uid',
    'assignment_mode','assigned_at','updated_at','order_status','processing_started_at','completed_at',
    'failure_reason','observation','last_hold_reason','last_held_at','last_resumed_at',
    'customer_confirmation_status','customer_confirmation_completed_at','last_refusal_reason',
    'last_refused_at','last_refused_agent_id','firebase_assignment_synced_at','firebase_handoff_at',
    'assignment_version','accepted_at','available_at'];
begin
  if old.assignment_route<>'shared' then
    if new.assignment_route is distinct from old.assignment_route then raise exception 'ROUTE_IMMUTABLE'; end if;
    return new;
  end if;
  v_staff:=coalesce(private.izytel_shared_staff_zone(old.zone_id),false);
  if new.zone_id is distinct from old.zone_id and not coalesce(private.is_izytel_finance_admin(),false) then raise exception 'MANAGER_ZONE_REQUIRED' using errcode='42501';end if;
  if new.assignment_route<>'shared' then raise exception 'ROUTE_IMMUTABLE'; end if;
  if not v_staff then
    if not public.is_izytel_firebase_jwt() or not private.izytel_shared_agent_zone(old.zone_id) then
      raise exception 'AGENT_ZONE_REQUIRED' using errcode='42501';
    end if;
    if (to_jsonb(new)-v_allowed) is distinct from (to_jsonb(old)-v_allowed) then
      raise exception 'ORDER_FIELDS_IMMUTABLE' using errcode='42501';
    end if;
    if old.assignment_state='waiting' and new.assignment_state='accepted' and
       old.assigned_agent_id is null and old.assigned_cabiniste_id is null and new.assigned_agent_id=v_uid then
      if old.payment_status<>'confirmed' or old.order_status<>'paidReady' or old.legacy_state_unresolved
         or not private.phase3_agent_is_eligible(v_uid,old.order_id) then
        raise exception 'AGENT_NOT_ELIGIBLE_CURRENT_STATE';
      end if;
    elsif old.assigned_agent_id=v_uid and new.assigned_agent_id=v_uid and old.assignment_state='assigned' and new.assignment_state='accepted' then
      if not private.phase3_agent_is_eligible(v_uid,old.order_id) then raise exception 'AGENT_NOT_ELIGIBLE_CURRENT_STATE'; end if;
      update public.phase4_assignment_history set status='accepted',accepted_at=clock_timestamp(),updated_at=clock_timestamp() where order_id=old.order_id and agent_id=v_uid and status='assigned';
    elsif old.assigned_agent_id=v_uid and old.assignment_state='assigned' and new.assignment_state='refused' then
      if char_length(btrim(coalesce(new.last_refusal_reason,''))) not between 3 and 500 then
        raise exception 'INVALID_REFUSAL_REASON';
      end if;
      update public.phase4_assignment_history set status='refused',refused_at=now(),
        refusal_reason=new.last_refusal_reason,updated_at=now()
        where order_id=old.order_id and agent_id=v_uid and status='assigned';
      new.assignment_state:='waiting';new.assigned_agent_id:=null;new.assigned_agent_name:=null;
      new.assignment_mode:=null;new.assigned_at:=null;new.last_refused_at:=now();new.last_refused_agent_id:=v_uid;
    elsif old.assigned_agent_id=v_uid and new.assigned_agent_id=v_uid and
          new.assignment_state=old.assignment_state and old.assignment_state in ('accepted','handed_off') then
      if not (
        (old.order_status='paidReady' and new.order_status='inProgress' and new.processing_started_at is not null)
        or (old.order_status='inProgress' and new.order_status='onHold'
            and char_length(btrim(coalesce(new.last_hold_reason,''))) between 3 and 300 and new.last_held_at is not null)
        or (old.order_status='onHold' and new.order_status='inProgress' and new.last_resumed_at is not null)
        or (old.order_status='inProgress' and new.order_status in ('completed','failed') and new.completed_at is not null)
      ) then raise exception 'INVALID_AGENT_ASSIGNMENT_TRANSITION'; end if;
      if new.assigned_agent_name is distinct from old.assigned_agent_name
         or new.assignment_mode is distinct from old.assignment_mode
         or new.assigned_at is distinct from old.assigned_at then raise exception 'ASSIGNMENT_IMMUTABLE'; end if;
    else
      raise exception 'ASSIGNMENT_OWNER_REQUIRED' using errcode='42501';
    end if;
  end if;

  if v_staff and new.assigned_agent_id is not null
     and (new.assigned_agent_id is distinct from old.assigned_agent_id
       or new.assigned_at is distinct from old.assigned_at) then
    if new.assignment_state<>'assigned' then raise exception 'MANUAL_ACCEPTANCE_REQUIRED';end if;
    perform 1 from public.phase5_agent_capacities where agent_id=new.assigned_agent_id for update;
    if not private.phase3_agent_is_eligible(new.assigned_agent_id,old.order_id) then
      raise exception 'AGENT_NOT_ELIGIBLE_CURRENT_STATE';
    end if;
  end if;

  -- A staff member outside this territory must not gain the historical broad UPDATE bypass.
  if private.is_izytel_phase4_staff() and not v_staff then raise exception 'MANAGER_ZONE_REQUIRED' using errcode='42501'; end if;
  -- Explicit Cabiniste assignment keeps its existing executor and processing guard.
  if new.assigned_cabiniste_id is not null then
    if not v_staff or old.assignment_state='accepted' then raise exception 'MANUAL_RESET_REQUIRED'; end if;
    new.assignment_route:='legacy';
  end if;
  return new;
end;
$$;
revoke all on function private.izytel_shared_order_guard() from public,anon,authenticated;

drop trigger trg_phase4_assignment_orders_guard on public.phase4_assignment_orders;
create trigger trg_phase4_assignment_orders_guard before update on public.phase4_assignment_orders
for each row when(old.assignment_route='legacy' and new.assignment_route='legacy')
execute function private.phase4_enforce_assignment_order_update();
create trigger aaa_izytel_shared_order_guard before update on public.phase4_assignment_orders
for each row execute function private.izytel_shared_order_guard();

create function private.izytel_acceptance_lifecycle()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_enabled boolean; v_changed boolean;
begin
  if tg_op='INSERT' then
    select enabled into v_enabled from private.izytel_shared_queue_settings where singleton;
    new.assignment_route:='legacy';new.assignment_version:=0;new.accepted_at:=null;new.available_at:=null;
    if v_enabled and new.payment_status='confirmed' and new.order_status='paidReady'
       and new.payment_confirmed_at is not null
       and new.payment_confirmed_at >= (select activated_at from private.izytel_shared_queue_settings where singleton)
       and new.assignment_state='waiting' and new.assigned_agent_id is null and new.assigned_cabiniste_id is null
       and not new.legacy_state_unresolved then
      new.assignment_route:='shared';new.available_at:=clock_timestamp();
    end if;
  else
    new.assignment_version:=old.assignment_version;new.accepted_at:=old.accepted_at;new.available_at:=old.available_at;
    v_changed:=new.assigned_agent_id is distinct from old.assigned_agent_id
      or new.assigned_cabiniste_id is distinct from old.assigned_cabiniste_id
      or new.assigned_at is distinct from old.assigned_at
      or (old.assignment_state in ('accepted','handed_off') and new.assignment_state not in ('accepted','handed_off'));
    if v_changed then new.assignment_version:=old.assignment_version+1;new.accepted_at:=null;end if;
    if new.assigned_agent_id is not null and new.assignment_state='accepted'
       and (old.assignment_state<>'accepted' or v_changed) then
      new.assignment_version:=greatest(1,new.assignment_version);new.accepted_at:=clock_timestamp();
    end if;
    if new.assignment_route='shared' and new.assignment_state='waiting'
       and old.assignment_state<>'waiting' then new.available_at:=clock_timestamp();end if;
  end if;
  new.updated_at:=clock_timestamp();
  return new;
end;
$$;
revoke all on function private.izytel_acceptance_lifecycle() from public,anon,authenticated;
create trigger zzz_izytel_acceptance_lifecycle before insert or update on public.phase4_assignment_orders
for each row execute function private.izytel_acceptance_lifecycle();

create function private.izytel_shared_claim(p_order_id text,p_expected_version bigint)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_uid text:=(select auth.jwt()->>'sub'); v_order public.phase4_assignment_orders; v_agent public.phase5_agent_capacities;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501';end if;
  if p_expected_version is null or p_expected_version<0 then raise exception 'INVALID_CLAIM_VERSION' using errcode='22023';end if;
  select * into v_order from public.phase4_assignment_orders where order_id=btrim(p_order_id) for update;
  if not found or not private.izytel_shared_agent_zone(v_order.zone_id) then
    raise exception 'ORDER_NOT_AVAILABLE' using errcode='42501';
  end if;
  -- Same cycle retry after a lost response: retain timestamp, version and history.
  if v_order.assigned_agent_id=v_uid and v_order.assignment_route='shared'
     and v_order.assignment_state in ('accepted','handed_off')
     and v_order.assignment_version=p_expected_version+1 then
    return jsonb_build_object('outcome','already_owned','order',to_jsonb(v_order),'server_now',clock_timestamp());
  end if;
  if v_order.assignment_route<>'shared' or v_order.assignment_state<>'waiting'
     or v_order.assigned_agent_id is not null or v_order.assigned_cabiniste_id is not null
     or v_order.assignment_version<>p_expected_version then raise exception 'ORDER_ALREADY_TAKEN';end if;
  if not (select enabled from private.izytel_shared_queue_settings where singleton) then raise exception 'QUEUE_DISABLED';end if;
  if v_order.payment_status<>'confirmed' or v_order.order_status<>'paidReady' or v_order.legacy_state_unresolved then
    raise exception 'ORDER_NOT_AVAILABLE';
  end if;
  -- The same capacity row serializes claims of DIFFERENT orders by the same Agent.
  select * into v_agent from public.phase5_agent_capacities where agent_id=v_uid for update;
  if not found or not private.phase3_agent_is_eligible(v_uid,v_order.order_id) then
    raise exception 'AGENT_NOT_ELIGIBLE_CURRENT_STATE';
  end if;
  update public.phase4_assignment_orders set
    assignment_state='accepted',assigned_agent_id=v_uid,assigned_agent_name=v_agent.agent_name,
    assigned_by_uid=v_uid,assignment_mode='automatic',assigned_at=clock_timestamp()
    where order_id=v_order.order_id returning * into v_order;
  -- Existing enum values retained; assignment_route identifies self-service unambiguously.
  insert into public.phase4_assignment_history(order_id,order_reference,agent_id,agent_name,mode,status,
    assigned_by_uid,assigned_at,accepted_at,network,amount)
  values(v_order.order_id,v_order.order_reference,v_uid,v_agent.agent_name,'automatic','accepted',
    v_uid,v_order.assigned_at,v_order.accepted_at,v_order.network,v_order.amount);
  return jsonb_build_object('outcome','claimed','order',to_jsonb(v_order),'server_now',clock_timestamp());
end;
$$;
create function public.izytel_shared_claim(p_order_id text,p_expected_version bigint)
returns jsonb language sql set search_path='' as $$select private.izytel_shared_claim(p_order_id,p_expected_version);$$;
revoke all on function private.izytel_shared_claim(text,bigint),public.izytel_shared_claim(text,bigint) from public;
grant execute on function private.izytel_shared_claim(text,bigint),public.izytel_shared_claim(text,bigint) to anon,authenticated;

create function private.izytel_shared_order_events()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_target record;v_published boolean;
begin
  update public.izytel_order_delay_alerts set
    state=case when new.assignment_version<>assignment_version or new.assigned_agent_id is distinct from agent_id
      or new.zone_id is distinct from zone_id then 'obsolete' else 'resolved' end,
    resolved_at=clock_timestamp()
  where order_id=new.order_id and state='active' and (
    new.assignment_version<>assignment_version or new.assigned_agent_id is distinct from agent_id
    or new.zone_id is distinct from zone_id
    or new.order_status not in ('paidReady','inProgress','onHold')
    or new.assignment_state not in ('accepted','handed_off'));
  if new.zone_id is not null then
    insert into public.izytel_shared_queue_signals(zone_id) values(new.zone_id)
    on conflict(zone_id) do update set revision=public.izytel_shared_queue_signals.revision+1,updated_at=clock_timestamp();
  end if;
  if tg_op='UPDATE' and old.zone_id is not null and old.zone_id is distinct from new.zone_id then
    insert into public.izytel_shared_queue_signals(zone_id) values(old.zone_id)
    on conflict(zone_id) do update set revision=public.izytel_shared_queue_signals.revision+1,updated_at=clock_timestamp();
  end if;
  v_published:=new.assignment_route='shared' and new.assignment_state='waiting'
    and new.assigned_agent_id is null and new.assigned_cabiniste_id is null;
  if tg_op='UPDATE' then
    v_published:=v_published and (old.assignment_state<>'waiting' or old.assignment_route<>'shared');
  end if;
  if v_published then
    for v_target in select a.agent_id from public.phase5_agent_capacities a
      where a.is_active and new.zone_id=any(a.zone_ids) and new.network=any(a.authorized_networks)
    loop
      perform private.enqueue_izytel_notification(v_target.agent_id,'order_available','Commande disponible',
        new.order_reference||' - '||upper(new.network)||' - '||new.amount::text||' F',
        jsonb_build_object('type','order_available','route','shared_queue','orderId',new.order_id,
          'orderReference',new.order_reference,'zoneId',new.zone_id),
        'available:'||new.order_id||':'||new.assignment_version||':'||v_target.agent_id);
    end loop;
  end if;
  return new;
end;
$$;
revoke all on function private.izytel_shared_order_events() from public,anon,authenticated;
create trigger zzz_izytel_shared_order_events after insert or update on public.phase4_assignment_orders
for each row execute function private.izytel_shared_order_events();


-- For a historical acceptance, reuse its real server history timestamp only.
-- No backfill, assignment mutation or invented timestamp is necessary.
create function private.izytel_acceptance_time(p_order public.phase4_assignment_orders)
returns timestamptz language sql stable security definer set search_path=''
as $$
  select coalesce(p_order.accepted_at,case when p_order.assignment_version=0
    and not p_order.legacy_state_unresolved and p_order.assignment_state in ('accepted','handed_off')
    then (select h.accepted_at from public.phase4_assignment_history h
      where h.order_id=p_order.order_id and h.agent_id=p_order.assigned_agent_id
        and h.assigned_at=p_order.assigned_at and h.accepted_at is not null
      order by h.accepted_at desc limit 1) end);
$$;
revoke all on function private.izytel_acceptance_time(public.phase4_assignment_orders) from public,anon,authenticated;
create index phase4_acceptance_history_lookup_idx on public.phase4_assignment_history(order_id,agent_id,assigned_at,accepted_at)
where accepted_at is not null;

create function private.izytel_detect_order_delays(p_limit integer default 200)
returns integer language plpgsql security definer set search_path=''
as $$
declare v_order public.phase4_assignment_orders;v_alert uuid;v_target record;v_count integer:=0;
begin
  for v_order in select o.* from public.phase4_assignment_orders o
    where o.assigned_agent_id is not null and private.izytel_acceptance_time(o) is not null and not o.legacy_state_unresolved
      and private.izytel_acceptance_time(o)<clock_timestamp()-interval '5 minutes'
      and o.assignment_state in ('accepted','handed_off')
      and o.order_status in ('paidReady','inProgress','onHold')
      and not exists(select 1 from public.izytel_order_delay_alerts a
        where a.order_id=o.order_id and a.assignment_version=o.assignment_version and a.alert_type='acceptance_delay')
    order by private.izytel_acceptance_time(o),o.order_id limit greatest(1,least(coalesce(p_limit,200),1000)) for update skip locked
  loop
    v_order.accepted_at:=private.izytel_acceptance_time(v_order);
    insert into public.izytel_order_delay_alerts(order_id,assignment_version,zone_id,agent_id,agent_name,accepted_at)
    values(v_order.order_id,v_order.assignment_version,v_order.zone_id,v_order.assigned_agent_id,
      v_order.assigned_agent_name,v_order.accepted_at)
    on conflict(order_id,assignment_version,alert_type) do nothing returning id into v_alert;
    if v_alert is not null then
      v_count:=v_count+1;
      -- No global Manager/Admin fallback: only active, effective zone owners.
      for v_target in select s.firebase_uid from public.territory_zones z
        join public.izytel_staff_access s on s.firebase_uid=z.manager_id
        where z.id=v_order.zone_id and z.is_active and s.is_active and s.role in ('manager','supervisor')
      loop
        perform private.enqueue_izytel_notification(v_target.firebase_uid,'order_acceptance_delay',
          'Prise en charge en retard',v_order.order_reference||' - '||v_order.assigned_agent_name||' - plus de 5 min',
          jsonb_build_object('type','order_acceptance_delay','route','order_supervision','orderId',v_order.order_id,
            'orderReference',v_order.order_reference,'zoneId',v_order.zone_id,
            'assignmentVersion',v_order.assignment_version,'acceptedAt',v_order.accepted_at,
            'orderStatus',v_order.order_status,'alertId',v_alert),
          'delay:'||v_order.order_id||':'||v_order.assignment_version||':'||v_target.firebase_uid);
      end loop;
      insert into public.izytel_shared_queue_signals(zone_id) values(v_order.zone_id)
      on conflict(zone_id) do update set revision=public.izytel_shared_queue_signals.revision+1,updated_at=clock_timestamp();
    end if;
  end loop;
  return v_count;
end;
$$;
revoke all on function private.izytel_detect_order_delays(integer) from public,anon,authenticated;
grant execute on function private.izytel_detect_order_delays(integer) to service_role;

create function private.izytel_order_supervision(p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_orders jsonb;v_alerts jsonb;
begin
  if not public.is_izytel_firebase_jwt() or not private.is_izytel_phase4_staff() then
    raise exception 'STAFF_REQUIRED' using errcode='42501';
  end if;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_orders from (
    select o.order_id,o.order_reference,o.zone_id,o.network,o.offer_label,o.amount,
      o.assigned_agent_id,o.assigned_agent_name,o.assignment_state,o.order_status,private.izytel_acceptance_time(o) as accepted_at,o.assignment_version,
      (private.izytel_acceptance_time(o)<clock_timestamp()-interval '5 minutes' and o.assignment_state in ('accepted','handed_off')
        and o.order_status in ('paidReady','inProgress','onHold')) is_overdue
    from public.phase4_assignment_orders o where private.izytel_shared_staff_zone(o.zone_id)
      and o.assigned_agent_id is not null and o.order_status in ('paidReady','inProgress','onHold','failed')
      and not o.legacy_state_unresolved
    order by private.izytel_acceptance_time(o) asc nulls last,o.order_id limit greatest(1,least(coalesce(p_limit,100),100))
  ) x;
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_alerts from (
    select a.*,o.order_reference,o.order_status from public.izytel_order_delay_alerts a
    join public.phase4_assignment_orders o on o.order_id=a.order_id
    where private.izytel_shared_staff_zone(a.zone_id)
    order by (a.state='active') desc,a.created_at desc,a.id limit 100
  ) x;
  return jsonb_build_object('server_now',clock_timestamp(),'orders',v_orders,'alerts',v_alerts);
end;
$$;
create function public.izytel_order_supervision(p_limit integer default 100)
returns jsonb language sql set search_path='' as $$select private.izytel_order_supervision(p_limit);$$;
revoke all on function private.izytel_order_supervision(integer),public.izytel_order_supervision(integer) from public;
grant execute on function private.izytel_order_supervision(integer),public.izytel_order_supervision(integer) to anon,authenticated;



drop policy if exists "phase4 scoped staff assigned agent or cabiniste reads orders" on public.phase4_assignment_orders;
create policy "phase4 scoped staff assigned agent or cabiniste reads orders" on public.phase4_assignment_orders
for select to anon,authenticated using(public.is_izytel_firebase_jwt() and (
  private.izytel_shared_staff_zone(zone_id)
  or (assigned_agent_id=(select auth.jwt()->>'sub')
      and (assignment_route='legacy' or private.izytel_shared_agent_zone(zone_id)))
  or exists(select 1 from public.partner_accounts p where p.id=assigned_cabiniste_id
    and p.firebase_uid=(select auth.jwt()->>'sub') and p.status='active')
));

-- Restrict assignment-history reads to the same territorial authority as order details.
drop policy if exists "phase4 staff or owner reads assignment history" on public.phase4_assignment_history;
create policy "phase4 staff or owner reads assignment history" on public.phase4_assignment_history
for select to anon,authenticated using(public.is_izytel_firebase_jwt() and (
  agent_id=(select auth.jwt()->>'sub') or exists(
    select 1 from public.phase4_assignment_orders o where o.order_id=phase4_assignment_history.order_id
      and private.izytel_shared_staff_zone(o.zone_id)
  )
));

-- Publication contains no customer data. Authorized users retain visibility of
-- the signal after another Agent takes an order; refetch removes stale rows.
do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    alter publication supabase_realtime add table public.izytel_shared_queue_signals;
  end if;
end;
$$;

-- WC14 - Round-robin automatique autoritatif cote Supabase.
--
-- Le client continue d'envoyer une liste classee, mais le serveur impose la
-- rotation sur la derniere affectation reelle afin qu'un lot de commandes ne
-- puisse plus etre attribue au premier agent avec un snapshot stale.
-- Un verrou transactionnel par zone serialise les affectations automatiques
-- concurrentes et garantit que la commande suivante voit l'affectation
-- precedente avant de choisir son agent.

create or replace function public.phase4_assign_ranked(
  p_order_id text,
  p_candidate_agent_ids text[],
  p_candidate_names jsonb,
  p_mode text default 'automatic'
)
returns public.phase4_assignment_orders
language plpgsql
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_order public.phase4_assignment_orders%rowtype;
  v_plan public.phase4_assignment_plans%rowtype;
  v_candidate text;
  v_name text;
  v_previous_agent text;
  v_previous_mode text;
begin
  if not private.is_izytel_phase4_staff() then
    raise exception 'STAFF_REQUIRED';
  end if;
  if p_mode not in ('automatic','manual') then
    raise exception 'INVALID_ASSIGNMENT_MODE';
  end if;

  select * into v_order
  from public.phase4_assignment_orders
  where order_id=p_order_id
  for update;
  if not found then raise exception 'ORDER_NOT_SYNCED'; end if;

  -- Une seule selection automatique a la fois par zone. Deux confirmations
  -- simultanees ne peuvent donc plus choisir toutes les deux le meme premier
  -- agent avant que l'historique de rotation soit mis a jour.
  if p_mode='automatic' then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'izytel:auto-assignment:' || coalesce(v_order.zone_id,''),
        0
      )
    );
  end if;

  if v_order.assignment_route='shared' and p_mode='automatic' then return v_order; end if;
  if v_order.order_status <> 'paidReady' then return v_order; end if;
  if v_order.assignment_state in ('accepted','handed_off','closed') then
    return v_order;
  end if;

  select * into v_plan
  from public.phase4_assignment_plans
  where order_id=p_order_id
  for update;
  if not found then
    insert into public.phase4_assignment_plans(order_id)
    values(p_order_id)
    returning * into v_plan;
  end if;

  update public.phase4_assignment_plans
  set candidate_agent_ids=coalesce(p_candidate_agent_ids,'{}'::text[]),
      candidate_names=coalesce(p_candidate_names,'{}'::jsonb),
      plan_mode=p_mode,
      updated_at=now()
  where order_id=p_order_id
  returning * into v_plan;

  if v_order.assignment_state='assigned'
     and v_order.assignment_mode=p_mode
     and v_order.assigned_agent_id=any(coalesce(v_plan.candidate_agent_ids,'{}'::text[]))
     and not(v_order.assigned_agent_id=any(coalesce(v_plan.refused_agent_ids,'{}'::text[])))
     and private.phase3_agent_is_eligible(v_order.assigned_agent_id,p_order_id) then
    return v_order;
  end if;

  v_previous_agent:=v_order.assigned_agent_id;
  v_previous_mode:=v_order.assignment_mode;

  select c.candidate_id into v_candidate
  from unnest(coalesce(v_plan.candidate_agent_ids,'{}'::text[]))
       with ordinality as c(candidate_id,ord)
  left join lateral (
    select max(h.assigned_at) as last_assigned_at
    from public.phase4_assignment_history h
    where h.agent_id=c.candidate_id
  ) usage on true
  where btrim(c.candidate_id)<>''
    and not(c.candidate_id=any(coalesce(v_plan.refused_agent_ids,'{}'::text[])))
    and private.phase3_agent_is_eligible(c.candidate_id,p_order_id)
  order by
    case when p_mode='automatic' then usage.last_assigned_at end asc nulls first,
    c.ord
  limit 1;

  if v_previous_agent is not null and (
    v_candidate is null
    or v_candidate is distinct from v_previous_agent
    or v_previous_mode is distinct from p_mode
  ) then
    update public.phase4_assignment_history h
    set status='reassigned',updated_at=now()
    where h.id=(
      select h2.id
      from public.phase4_assignment_history h2
      where h2.order_id=p_order_id
        and h2.agent_id=v_previous_agent
        and h2.status='assigned'
      order by h2.assigned_at desc
      limit 1
    );
  end if;

  if v_candidate is null then
    update public.phase4_assignment_orders
    set assignment_state=case
          when cardinality(v_plan.candidate_agent_ids)>0
           and cardinality(v_plan.refused_agent_ids)>0
          then 'manual_required'
          else 'waiting'
        end,
        assigned_agent_id=null,
        assigned_agent_name=null,
        assigned_by_uid=v_uid,
        assignment_mode=null,
        assigned_at=null,
        firebase_assignment_synced_at=null,
        firebase_handoff_at=null,
        updated_at=now()
    where order_id=p_order_id
    returning * into v_order;
    return v_order;
  end if;

  perform 1 from public.phase5_agent_capacities where agent_id=v_candidate for update;
  if not private.phase3_agent_is_eligible(v_candidate,p_order_id) then raise exception 'AGENT_NOT_ELIGIBLE_CURRENT_STATE'; end if;
  v_name:=nullif(btrim(coalesce(v_plan.candidate_names->>v_candidate,'')),'');
  if v_name is null then
    select nullif(btrim(c.agent_name),'') into v_name
    from public.phase5_agent_capacities c
    where c.agent_id=v_candidate;
  end if;
  if v_name is null or char_length(v_name)<2 then v_name:='Agent'; end if;

  update public.phase4_assignment_orders
  set assignment_state='assigned',
      assigned_agent_id=v_candidate,
      assigned_agent_name=v_name,
      assigned_by_uid=v_uid,
      assignment_mode=p_mode,
      assigned_at=now(),
      firebase_assignment_synced_at=null,
      firebase_handoff_at=null,
      legacy_state_unresolved=false,
      updated_at=now()
  where order_id=p_order_id
  returning * into v_order;

  insert into public.phase4_assignment_history(
    order_id,order_reference,agent_id,agent_name,mode,status,
    assigned_by_uid,assigned_at
  ) values(
    v_order.order_id,v_order.order_reference,v_candidate,v_name,
    p_mode,'assigned',v_uid,v_order.assigned_at
  );
  return v_order;
end;
$function$;

-- Keep historical reconciliation RPCs callable for older clients, while shared
-- orders remain canonical in Supabase. Explicit Manager reset/assignment RPCs
-- are separate and retain their existing permissions.
CREATE OR REPLACE FUNCTION public.phase4_reconcile_acceptance(p_order_id text, p_firebase_handoff_confirmed boolean)
 RETURNS phase4_assignment_orders
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_row public.phase4_assignment_orders;
  v_history_id uuid;
begin
  if not private.is_izytel_phase4_staff() then
    raise exception 'STAFF_REQUIRED';
  end if;

  select * into v_row
  from public.phase4_assignment_orders
  where order_id = p_order_id
  for update;
  if not found then raise exception 'ORDER_NOT_SYNCED'; end if;

  if v_row.assignment_route = 'shared' then return v_row; end if;

  if v_row.assignment_state <> 'accepted' then
    return v_row;
  end if;

  select h.id into v_history_id
  from public.phase4_assignment_history h
  where h.order_id = p_order_id
    and h.agent_id = v_row.assigned_agent_id
    and h.status = 'accepted'
  order by h.assigned_at desc
  limit 1;

  if p_firebase_handoff_confirmed then
    update public.phase4_assignment_orders
    set assignment_state = 'handed_off',
        firebase_assignment_synced_at = coalesce(firebase_assignment_synced_at, now()),
        firebase_handoff_at = coalesce(firebase_handoff_at, now()),
        updated_at = now()
    where order_id = p_order_id
    returning * into v_row;

    if v_history_id is not null then
      update public.phase4_assignment_history
      set status = 'handed_off', handed_off_at = coalesce(handed_off_at, now()),
          updated_at = now()
      where id = v_history_id;
    end if;
  else
    update public.phase4_assignment_orders
    set assignment_state = 'assigned',
        firebase_assignment_synced_at = null,
        firebase_handoff_at = null,
        updated_at = now()
    where order_id = p_order_id
    returning * into v_row;

    if v_history_id is not null then
      update public.phase4_assignment_history
      set status = 'assigned', accepted_at = null, handed_off_at = null,
          updated_at = now()
      where id = v_history_id;
    end if;
  end if;

  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.phase4_import_legacy_refusals(p_order_id text, p_refused_agent_ids text[], p_manual_required boolean DEFAULT false)
 RETURNS phase4_assignment_orders
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_row public.phase4_assignment_orders;
  v_existing text[];
  v_merged text[];
begin
  if not private.is_izytel_phase4_staff() then raise exception 'STAFF_REQUIRED'; end if;

  -- Canonical shared orders must not be mutated by obsolete Firebase workers.
  select * into v_row from public.phase4_assignment_orders
  where order_id=p_order_id for update;
  if not found then raise exception 'ORDER_NOT_SYNCED'; end if;
  if v_row.assignment_route='shared' then return v_row; end if;

  select refused_agent_ids into v_existing
  from public.phase4_assignment_plans
  where order_id=p_order_id
  for update;
  if not found then raise exception 'ASSIGNMENT_PLAN_MISSING'; end if;

  select coalesce(array_agg(distinct x), '{}'::text[]) into v_merged
  from unnest(coalesce(v_existing,'{}'::text[]) || coalesce(p_refused_agent_ids,'{}'::text[])) as x
  where btrim(x) <> '';

  update public.phase4_assignment_plans
  set refused_agent_ids=v_merged, updated_at=now()
  where order_id=p_order_id;

  if p_manual_required then
    update public.phase4_assignment_orders
    set assignment_state='manual_required',
        assigned_agent_id=null,
        assigned_agent_name=null,
        assignment_mode=null,
        assigned_at=null,
        firebase_assignment_synced_at=null,
        firebase_handoff_at=null,
        updated_at=now()
    where order_id=p_order_id
      and assignment_state not in ('accepted','handed_off','closed')
    returning * into v_row;
  else
    select * into v_row from public.phase4_assignment_orders where order_id=p_order_id;
  end if;

  if v_row.order_id is null then raise exception 'ORDER_NOT_SYNCED'; end if;
  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.phase4_close_order(p_order_id text)
 RETURNS phase4_assignment_orders
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_row public.phase4_assignment_orders;
  v_previous_agent text;
begin
  if not private.is_izytel_phase4_staff() then raise exception 'STAFF_REQUIRED'; end if;
  -- Canonical shared orders must not be mutated by obsolete Firebase workers.
  select * into v_row from public.phase4_assignment_orders
  where order_id=p_order_id for update;
  if not found then raise exception 'ORDER_NOT_SYNCED'; end if;
  if v_row.assignment_route='shared' then return v_row; end if;

  select assigned_agent_id into v_previous_agent
  from public.phase4_assignment_orders where order_id=p_order_id for update;
  if not found then raise exception 'ORDER_NOT_SYNCED'; end if;

  if v_previous_agent is not null then
    update public.phase4_assignment_history h
    set status='closed', updated_at=now()
    where h.id=(
      select h2.id from public.phase4_assignment_history h2
      where h2.order_id=p_order_id and h2.agent_id=v_previous_agent
        and h2.status in ('assigned','accepted')
      order by h2.assigned_at desc limit 1
    );
  end if;

  update public.phase4_assignment_orders
  set assignment_state='closed',
      assigned_agent_id=null,
      assigned_agent_name=null,
      assignment_mode=null,
      assigned_at=null,
      firebase_assignment_synced_at=null,
      firebase_handoff_at=null,
      updated_at=now()
  where order_id=p_order_id
  returning * into v_row;
  return v_row;
end;
$function$;

-- Re-check new territorial events at dispatch time, including after a retry.
-- A role/zone change or an obsolete acceptance must not disclose an old payload.
create function public.izytel_notification_recipient_authorized(p_outbox_id uuid)
returns boolean language plpgsql security definer set search_path=''
as $$
declare v_type text;v_uid text;v_data jsonb;
begin
  select event_type,recipient_uid,data into v_type,v_uid,v_data
  from public.izytel_notification_outbox where id=p_outbox_id;
  if not found then return false;end if;
  if v_type='order_available' then
    return exists(select 1 from public.phase4_assignment_orders o
      join public.phase5_agent_capacities a on a.agent_id=v_uid and a.is_active
      join public.territory_zones z on z.id=o.zone_id and z.is_active
      where o.order_id=v_data->>'orderId' and o.zone_id=v_data->>'zoneId'
        and o.zone_id=any(a.zone_ids) and o.network=any(a.authorized_networks)
        and o.assignment_route='shared' and o.assignment_state='waiting'
        and o.assigned_agent_id is null and o.assigned_cabiniste_id is null
        and (select enabled from private.izytel_shared_queue_settings where singleton));
  elsif v_type='order_acceptance_delay' then
    return exists(select 1 from public.izytel_order_delay_alerts a
      join public.phase4_assignment_orders o on o.order_id=a.order_id
      join public.territory_zones z on z.id=a.zone_id and z.is_active
      join public.izytel_staff_access s on s.firebase_uid=z.manager_id and s.is_active
      where a.id::text=v_data->>'alertId' and a.state='active'
        and a.order_id=v_data->>'orderId' and a.zone_id=v_data->>'zoneId'
        and o.zone_id=a.zone_id and o.assignment_version=a.assignment_version
        and s.firebase_uid=v_uid and s.role in ('manager','supervisor'));
  end if;
  return true;
end;
$$;
revoke all on function public.izytel_notification_recipient_authorized(uuid) from public,anon,authenticated;
grant execute on function public.izytel_notification_recipient_authorized(uuid) to service_role;

-- Preserve canonical shared order data against Firestore replay and concurrent upserts.
CREATE OR REPLACE FUNCTION public.phase3_sync_order(p_order_id text, p_order_reference text, p_network text, p_amount integer, p_firebase_created_at timestamp with time zone, p_paid_at timestamp with time zone, p_source text, p_client_name text, p_client_whatsapp_phone text, p_beneficiary_phone text, p_operation_type text, p_offer_label text, p_original_whatsapp_message text, p_internal_notes text, p_payment_status text, p_payment_payer_name text, p_payment_reference text, p_payment_confirmed_at timestamp with time zone, p_customer_auth_uid text DEFAULT NULL::text)
 RETURNS phase4_assignment_orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
    declare
      v_row public.phase4_assignment_orders;
      v_zone_id text;
      v_uid text := (select auth.jwt()->>'sub');
      v_role text;
    begin
      if not private.is_izytel_phase4_staff() then
        raise exception 'STAFF_REQUIRED' using errcode = '42501';
      end if;

      -- Shared publication makes Supabase canonical; preserve data on replay.
      select * into v_row from public.phase4_assignment_orders
      where order_id=btrim(p_order_id) for update;
      if found and v_row.assignment_route='shared' then
        if not coalesce(private.izytel_shared_staff_zone(v_row.zone_id),false) then
          raise exception 'MANAGER_ZONE_REQUIRED' using errcode='42501';
        end if;
        return v_row;
      end if;

      if btrim(coalesce(p_order_id,''))=''
         or btrim(coalesce(p_order_reference,''))='' then
        raise exception 'INVALID_ORDER';
      end if;
      if p_network not in ('orange','mtn','moov') or p_amount<=0 then
        raise exception 'INVALID_ORDER';
      end if;
      if p_source not in ('customerWeb','operatorApp') then
        raise exception 'INVALID_SOURCE';
      end if;
      if p_operation_type not in (
        'internetSubscription','unitTransfer','callBundle','mixedBundle','other'
      ) then
        raise exception 'INVALID_OPERATION_TYPE';
      end if;
      if p_payment_status not in ('confirmed','credit') then
        raise exception 'INVALID_PAYMENT_STATUS';
      end if;

      select c.zone_id into v_zone_id
      from public.customer_order_contexts c
      where c.order_id=btrim(p_order_id)
        and upper(c.order_reference)=upper(btrim(p_order_reference))
      order by c.updated_at desc
      limit 1;

      v_zone_id := coalesce(v_zone_id, private.izytel_wc5_fallback_zone_id());

      select private.izytel_current_staff_role() into v_role;
      if v_role in ('manager','supervisor')
         and not private.izytel_wc5_manager_owns_zone(v_zone_id, v_uid) then
        raise exception 'MANAGER_ZONE_REQUIRED' using errcode = '42501';
      end if;

      insert into public.phase4_assignment_orders(
        order_id,order_reference,network,amount,firebase_created_at,paid_at,
        source,customer_auth_uid,client_name,client_whatsapp_phone,beneficiary_phone,
        operation_type,offer_label,original_whatsapp_message,internal_notes,
        payment_status,payment_payer_name,payment_reference,payment_confirmed_at,
        zone_id,assignment_state,order_status,legacy_state_unresolved
      ) values (
        btrim(p_order_id),btrim(p_order_reference),p_network,p_amount,
        p_firebase_created_at,p_paid_at,p_source,
        nullif(btrim(coalesce(p_customer_auth_uid,'')),''),
        coalesce(nullif(btrim(p_client_name),''),'Client'),'',
        btrim(coalesce(p_beneficiary_phone,'')),p_operation_type,
        coalesce(nullif(btrim(p_offer_label),''),'Offre non renseignee'),
        null,nullif(btrim(coalesce(p_internal_notes,'')),''),
        p_payment_status,nullif(btrim(coalesce(p_payment_payer_name,'')),''),
        nullif(btrim(coalesce(p_payment_reference,'')),''),
        p_payment_confirmed_at,v_zone_id,'waiting','paidReady',false
      )
      on conflict(order_id) do update set
        order_reference=excluded.order_reference,
        network=excluded.network,
        amount=excluded.amount,
        firebase_created_at=excluded.firebase_created_at,
        paid_at=excluded.paid_at,
        source=excluded.source,
        customer_auth_uid=coalesce(
          public.phase4_assignment_orders.customer_auth_uid,
          excluded.customer_auth_uid
        ),
        client_name=excluded.client_name,
        client_whatsapp_phone='',
        beneficiary_phone=excluded.beneficiary_phone,
        operation_type=excluded.operation_type,
        offer_label=excluded.offer_label,
        original_whatsapp_message=null,
        internal_notes=excluded.internal_notes,
        payment_status=excluded.payment_status,
        payment_payer_name=excluded.payment_payer_name,
        payment_reference=excluded.payment_reference,
        payment_confirmed_at=excluded.payment_confirmed_at,
        zone_id=excluded.zone_id,
        legacy_state_unresolved=
          public.phase4_assignment_orders.legacy_state_unresolved,
        updated_at=now()
      where public.phase4_assignment_orders.assignment_route<>'shared'
      returning * into v_row;

      -- A concurrent synchronization may have published the shared row.
      if not found then
        select * into v_row from public.phase4_assignment_orders
        where order_id=btrim(p_order_id) for update;
        if not coalesce(private.izytel_shared_staff_zone(v_row.zone_id),false) then
          raise exception 'MANAGER_ZONE_REQUIRED' using errcode='42501';
        end if;
      end if;

      insert into public.phase4_assignment_plans(order_id)
      values(v_row.order_id)
      on conflict(order_id) do nothing;

      return v_row;
    end;
    $function$;

NOTIFY pgrst, 'reload schema';
commit;
