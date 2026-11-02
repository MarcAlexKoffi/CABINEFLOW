-- CLI-created local migration. Never applied remotely during implementation.
create table public.izytel_user_admin_operations (
  request_id text primary key,
  actor_uid text not null,
  target_uid text not null,
  command jsonb not null,
  before_state jsonb,
  status text not null default 'pending' check(status in ('pending','completed','failed')),
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- A failed saga blocks subsequent mutations until an operator repairs and audits
-- it. This deliberately favours integrity over availability; no timed unlock.
create unique index izytel_user_admin_single_mutation
  on public.izytel_user_admin_operations ((true)) where status in ('pending','failed');
create index izytel_user_admin_operations_target on public.izytel_user_admin_operations(target_uid);
alter table public.izytel_user_admin_operations enable row level security;
revoke all on public.izytel_user_admin_operations from public,anon,authenticated;
grant all on public.izytel_user_admin_operations to service_role;

create table public.izytel_user_admin_audit_events (
  id bigint generated always as identity primary key,
  request_id text not null,
  actor_uid text not null,
  target_uid text not null,
  action text not null,
  before_state jsonb,
  after_state jsonb,
  status text not null,
  error_code text,
  created_at timestamptz not null default now()
);
create index izytel_user_admin_audit_target on public.izytel_user_admin_audit_events(target_uid,id desc);
alter table public.izytel_user_admin_audit_events enable row level security;
revoke all on public.izytel_user_admin_audit_events from public,anon,authenticated,service_role;
grant select on public.izytel_user_admin_audit_events to service_role;
create function private.izytel_capture_user_admin_audit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.izytel_user_admin_audit_events(request_id,actor_uid,target_uid,action,before_state,after_state,status,error_code)
    values(new.request_id,new.actor_uid,new.target_uid,new.command->>'action',new.before_state,new.command,new.status,new.error_code);
  return new;
end; $$;
revoke all on function private.izytel_capture_user_admin_audit() from public,anon,authenticated,service_role;
create trigger izytel_user_admin_audit_capture after insert or update on public.izytel_user_admin_operations
  for each row execute function private.izytel_capture_user_admin_audit();

create function public.izytel_user_admin_authorize(p_actor text)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'SERVICE_REQUIRED'; end if;
  if not exists(select 1 from public.izytel_staff_access where firebase_uid=p_actor and role='admin' and is_active) then raise exception 'ADMIN_REQUIRED'; end if;
  return true;
end; $$;

create function public.izytel_user_admin_history(p_actor text,p_uid text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  perform public.izytel_user_admin_authorize(p_actor);
  return coalesce((select jsonb_agg(to_jsonb(e)) from (
    select * from (
      select id::text,request_id,actor_uid,target_uid,action,
        before_state,after_state,status,error_code,created_at
      from public.izytel_user_admin_audit_events where target_uid=p_uid
      union all
      -- Territory administration remains a legitimate existing Admin workflow;
      -- include its immutable journal instead of hiding its authorization edits.
      select id::text,null::text,actor_uid,p_uid,'territory_'||action,
        before_state,after_state,'completed'::text,null::text,created_at
      from public.territory_audit_events
      where (entity_type='manager' and entity_id=p_uid)
        or (entity_type='zone' and (
          before_state->>'manager_id'=p_uid or after_state->>'manager_id'=p_uid
        ))
    ) all_events order by created_at desc,id desc limit 100
  ) e),'[]'::jsonb);
end; $$;

create function public.izytel_user_admin_begin(p_actor text,p_uid text,p_request_id text,p_command jsonb,p_before jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_existing public.izytel_user_admin_operations; v_role text:=p_command->>'role'; v_active boolean:=coalesce((p_command->>'isActive')::boolean,false);
begin
  perform public.izytel_user_admin_authorize(p_actor);
  perform pg_advisory_xact_lock(731904611);
  select * into v_existing from public.izytel_user_admin_operations where request_id=p_request_id;
  if found then
    if v_existing.actor_uid<>p_actor or v_existing.target_uid<>p_uid or v_existing.command<>p_command then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    return jsonb_build_object('request_id',p_request_id,'status',v_existing.status,'fresh',false);
  end if;
  if exists(select 1 from public.izytel_user_admin_operations where status in ('pending','failed')) then raise exception 'ADMIN_OPERATION_PENDING'; end if;
  if p_uid=p_actor then raise exception 'SELF_ADMIN_OPERATION_FORBIDDEN'; end if;
  if p_command->>'action'='delete' then raise exception 'REFERENCES_NOT_VERIFIED'; end if;
  if p_command->>'action' not in ('create','update','reset_password') then raise exception 'INVALID_ACTION'; end if;
  if p_command->>'action' in ('create','update') then
    if v_role not in ('admin','manager','agent','cabiniste') then raise exception 'INVALID_ROLE'; end if;
    if exists(select 1 from jsonb_array_elements_text(p_command->'zoneIds') z(id) where not exists(select 1 from public.territory_zones t where t.id=z.id and t.is_active)) then raise exception 'INVALID_ZONE'; end if;
    if v_role='manager' and exists(select 1 from public.territory_zones where id in(select jsonb_array_elements_text(p_command->'zoneIds')) and manager_id is not null and manager_id<>p_uid) then raise exception 'ZONE_OCCUPIED'; end if;
    if exists(select 1 from public.izytel_staff_access where firebase_uid=p_uid and role='admin' and is_active) and (v_role<>'admin' or not v_active) then
      if (select count(*) from public.izytel_staff_access where role='admin' and is_active)<2 then raise exception 'LAST_ADMIN'; end if;
    end if;
    if p_command->>'action'='create' and (
      exists(select 1 from public.izytel_staff_access where firebase_uid=p_uid) or
      exists(select 1 from public.phase5_agent_capacities where agent_id=p_uid) or
      exists(select 1 from public.partner_accounts where firebase_uid=p_uid)
    ) then raise exception 'ACCOUNT_CONFLICT'; end if;
  end if;
  insert into public.izytel_user_admin_operations(request_id,actor_uid,target_uid,command,before_state)
    values(p_request_id,p_actor,p_uid,p_command,p_before);
  return jsonb_build_object('request_id',p_request_id,'status','pending','fresh',true);
end; $$;

-- Independent denial transaction: no provisioning/zone reassignment can roll
-- this back during compensation after a failed business validation.
create function public.izytel_user_admin_deny(p_request_id text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_uid text;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'SERVICE_REQUIRED'; end if;
  select target_uid into strict v_uid from public.izytel_user_admin_operations where request_id=p_request_id for update;
  update public.izytel_staff_access set is_active=false,updated_at=now() where firebase_uid=v_uid;
  update public.phase5_agent_capacities set is_active=false,availability='unavailable',active_networks='{}',updated_at=now() where agent_id=v_uid;
  update public.partner_accounts set status='suspended',availability='unavailable',active_networks='{}',updated_at=now() where firebase_uid=v_uid;
  update public.manager_profiles set is_active=false,is_available=false,updated_at=now() where firebase_uid=v_uid;
  update public.izytel_notification_devices set is_active=false,updated_at=now() where firebase_uid=v_uid;
  return true;
end; $$;

create function public.izytel_user_admin_apply(p_request_id text,p_active boolean)
returns boolean language plpgsql security definer set search_path = '' as $$
declare o public.izytel_user_admin_operations; c jsonb; v_role text; v_zones text[]; v_networks text[];
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'SERVICE_REQUIRED'; end if;
  select * into strict o from public.izytel_user_admin_operations where request_id=p_request_id for update;
  if o.command->>'action' not in ('create','update') then raise exception 'INVALID_ACTION'; end if;
  c:=o.command; v_role:=c->>'role';
  v_zones:=array(select jsonb_array_elements_text(c->'zoneIds'));
  v_networks:=array(select jsonb_array_elements_text(c->'authorizedNetworks'));
  -- Deny every previous population without destroying financial balances/history.
  update public.izytel_staff_access set is_active=false,updated_at=now() where firebase_uid=o.target_uid;
  update public.phase5_agent_capacities set is_active=false,availability='unavailable',active_networks='{}',updated_at=now() where agent_id=o.target_uid;
  update public.partner_accounts set status='suspended',availability='unavailable',active_networks='{}',updated_at=now() where firebase_uid=o.target_uid;
  update public.manager_profiles set is_active=false,is_available=false,updated_at=now() where firebase_uid=o.target_uid;
  update public.izytel_notification_devices set is_active=false,updated_at=now() where firebase_uid=o.target_uid;
  if p_active and not coalesce((c->>'isActive')::boolean,false) then raise exception 'INVALID_STATUS'; end if;
  if v_role in ('admin','manager') then
    insert into public.izytel_staff_access(firebase_uid,role,is_active,display_name)
      values(o.target_uid,v_role,p_active,c->>'name') on conflict(firebase_uid) do update
      set role=excluded.role,is_active=excluded.is_active,display_name=excluded.display_name,updated_at=now();
  end if;
  if v_role='manager' then
    insert into public.manager_profiles(firebase_uid,display_name,email,phone_number,is_active,is_available)
      values(o.target_uid,c->>'name',c->>'email',c->>'phoneNumber',p_active,false)
      on conflict(firebase_uid) do update set display_name=excluded.display_name,email=excluded.email,phone_number=excluded.phone_number,is_active=excluded.is_active,updated_at=now();
    update public.territory_zones set manager_id=null,updated_at=now() where manager_id=o.target_uid and not(id=any(v_zones));
    update public.territory_zones set manager_id=o.target_uid,updated_at=now() where id=any(v_zones) and (manager_id is null or manager_id=o.target_uid);
    if exists(select 1 from public.territory_zones where id=any(v_zones) and manager_id is distinct from o.target_uid) then raise exception 'ZONE_OCCUPIED'; end if;
  elsif v_role='agent' then
    insert into public.phase5_agent_capacities(agent_id,agent_name,is_active,availability,zone_ids,authorized_networks,active_networks,initialized_from)
      values(o.target_uid,c->>'name',p_active,'unavailable',v_zones,v_networks,'{}','supabase')
      on conflict(agent_id) do update set agent_name=excluded.agent_name,is_active=excluded.is_active,zone_ids=excluded.zone_ids,authorized_networks=excluded.authorized_networks,updated_at=now();
  elsif v_role='cabiniste' then
    insert into public.partner_accounts(firebase_uid,display_name,phone_number,status,availability,zone_ids,authorized_networks,created_by_uid)
      values(o.target_uid,c->>'name',c->>'phoneNumber',case when p_active then 'active' else 'suspended' end,'unavailable',v_zones,v_networks,o.actor_uid)
      on conflict(firebase_uid) do update set display_name=excluded.display_name,phone_number=excluded.phone_number,status=excluded.status,zone_ids=excluded.zone_ids,authorized_networks=excluded.authorized_networks,updated_at=now();
  end if;
  if v_role in ('admin','manager','agent') then
    insert into public.staff_profiles(firebase_uid,role,first_name,email,phone_number)
      values(o.target_uid,v_role,c->>'name',c->>'email',c->>'phoneNumber') on conflict(firebase_uid)
      do update set role=excluded.role,email=excluded.email,phone_number=excluded.phone_number,updated_at=now();
  end if;
  return true;
end; $$;

create function public.izytel_user_admin_finish(p_request_id text,p_error text)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'SERVICE_REQUIRED'; end if;
  update public.izytel_user_admin_operations set status=case when p_error is null then 'completed' else 'failed' end,error_code=p_error,updated_at=now() where request_id=p_request_id;
  if not found then raise exception 'INVALID_OPERATION'; end if;
  return true;
end; $$;

revoke all on function public.izytel_user_admin_authorize(text) from public,anon,authenticated;
revoke all on function public.izytel_user_admin_history(text,text) from public,anon,authenticated;
revoke all on function public.izytel_user_admin_begin(text,text,text,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.izytel_user_admin_apply(text,boolean) from public,anon,authenticated;
revoke all on function public.izytel_user_admin_deny(text) from public,anon,authenticated;
revoke all on function public.izytel_user_admin_finish(text,text) from public,anon,authenticated;
grant execute on function public.izytel_user_admin_authorize(text) to service_role;
grant execute on function public.izytel_user_admin_history(text,text) to service_role;
grant execute on function public.izytel_user_admin_begin(text,text,text,jsonb,jsonb) to service_role;
grant execute on function public.izytel_user_admin_apply(text,boolean) to service_role;
grant execute on function public.izytel_user_admin_deny(text) to service_role;
grant execute on function public.izytel_user_admin_finish(text,text) to service_role;

-- Accounts processed by the new administration path cannot silently return to
-- legacy direct mutations. Untouched historical accounts retain compatibility.
create function private.izytel_guard_managed_account_access()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_uid text;
begin
  if coalesce(auth.jwt()->>'role','')='service_role' then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_table_name='izytel_staff_access' and tg_op in ('UPDATE','DELETE')
    and to_jsonb(old)->>'role'='admin' and coalesce((to_jsonb(old)->>'is_active')::boolean,false)
    and (tg_op='DELETE' or to_jsonb(new)->>'role' is distinct from 'admin'
      or not coalesce((to_jsonb(new)->>'is_active')::boolean,false)) then
    if to_jsonb(old)->>'firebase_uid'=auth.jwt()->>'sub' then raise exception 'SELF_ADMIN_OPERATION_FORBIDDEN'; end if;
    if (select count(*) from public.izytel_staff_access where role='admin' and is_active)<2 then raise exception 'LAST_ADMIN'; end if;
  end if;
  -- An unrelated legacy row must never be renamed onto a managed identity.
  -- No existing profile operation requires changing the immutable Auth UID.
  if tg_op='UPDATE' and (
    to_jsonb(new)->'firebase_uid' is distinct from to_jsonb(old)->'firebase_uid'
    or to_jsonb(new)->'agent_id' is distinct from to_jsonb(old)->'agent_id'
  ) then raise exception 'MANAGED_ACCOUNT_SERVER_REQUIRED'; end if;
  if tg_op='INSERT' then
    v_uid:=case when tg_table_name='phase5_agent_capacities' then to_jsonb(new)->>'agent_id' else to_jsonb(new)->>'firebase_uid' end;
  else
    v_uid:=case when tg_table_name='phase5_agent_capacities' then to_jsonb(old)->>'agent_id' else to_jsonb(old)->>'firebase_uid' end;
  end if;
  if not exists(select 1 from public.izytel_user_admin_operations where target_uid=v_uid and command->>'action' in ('create','update')) then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_op in ('INSERT','DELETE') then raise exception 'MANAGED_ACCOUNT_SERVER_REQUIRED'; end if;
  if (to_jsonb(new)->'role' is distinct from to_jsonb(old)->'role')
    or (to_jsonb(new)->'is_active' is distinct from to_jsonb(old)->'is_active')
    or (to_jsonb(new)->'status' is distinct from to_jsonb(old)->'status')
    or (to_jsonb(new)->'zone_ids' is distinct from to_jsonb(old)->'zone_ids')
    or (to_jsonb(new)->'firebase_uid' is distinct from to_jsonb(old)->'firebase_uid')
    or (to_jsonb(new)->'agent_id' is distinct from to_jsonb(old)->'agent_id') then
    raise exception 'MANAGED_ACCOUNT_SERVER_REQUIRED';
  end if;
  return new;
end; $$;
revoke all on function private.izytel_guard_managed_account_access() from public,anon,authenticated;
create trigger izytel_staff_access_managed_guard before insert or update or delete on public.izytel_staff_access
  for each row execute function private.izytel_guard_managed_account_access();
create trigger izytel_agent_access_managed_guard before insert or update or delete on public.phase5_agent_capacities
  for each row execute function private.izytel_guard_managed_account_access();
create trigger izytel_partner_access_managed_guard before insert or update or delete on public.partner_accounts
  for each row execute function private.izytel_guard_managed_account_access();
create trigger izytel_manager_access_managed_guard before insert or update or delete on public.manager_profiles
  for each row execute function private.izytel_guard_managed_account_access();

-- Preserve authorized historical workflows while making their sensitive edits
-- visible in the same immutable account history, including Manager networks.
create function private.izytel_capture_legacy_account_access()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_uid text; v_actor text; v_request text; v_before jsonb; v_after jsonb;
begin
  if tg_op<>'INSERT' then v_before:=to_jsonb(old); end if;
  if tg_op<>'DELETE' then v_after:=to_jsonb(new); end if;
  if tg_op='UPDATE' and (
    v_before->'role' is not distinct from v_after->'role'
    and v_before->'is_active' is not distinct from v_after->'is_active'
    and v_before->'status' is not distinct from v_after->'status'
    and v_before->'zone_ids' is not distinct from v_after->'zone_ids'
    and v_before->'authorized_networks' is not distinct from v_after->'authorized_networks'
  ) then return new; end if;
  v_uid:=case when tg_table_name='phase5_agent_capacities'
    then coalesce(v_after->>'agent_id',v_before->>'agent_id')
    else coalesce(v_after->>'firebase_uid',v_before->>'firebase_uid') end;
  if v_uid is null then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if coalesce(auth.jwt()->>'role','')='service_role' then
    select actor_uid,request_id into v_actor,v_request
      from public.izytel_user_admin_operations where target_uid=v_uid and status in ('pending','failed')
      order by created_at desc limit 1;
  else v_actor:=nullif(auth.jwt()->>'sub',''); end if;
  insert into public.izytel_user_admin_audit_events(request_id,actor_uid,target_uid,action,before_state,after_state,status)
    values(coalesce(v_request,'legacy'),coalesce(v_actor,'system'),v_uid,
      'access_'||tg_table_name||'_'||lower(tg_op),v_before,v_after,'completed');
  if tg_op='DELETE' then return old; else return new; end if;
end; $$;
revoke all on function private.izytel_capture_legacy_account_access() from public,anon,authenticated,service_role;
create trigger izytel_staff_access_audit after insert or update or delete on public.izytel_staff_access
  for each row execute function private.izytel_capture_legacy_account_access();
create trigger izytel_agent_access_audit after insert or update or delete on public.phase5_agent_capacities
  for each row execute function private.izytel_capture_legacy_account_access();
create trigger izytel_partner_access_audit after insert or update or delete on public.partner_accounts
  for each row execute function private.izytel_capture_legacy_account_access();
create trigger izytel_manager_access_audit after insert or update or delete on public.manager_profiles
  for each row execute function private.izytel_capture_legacy_account_access();

-- A Firebase JWT already issued before deactivation can reach the old device
-- registration RPC. Dynamic SQL access, not token age, governs reactivation.
create function private.izytel_guard_managed_notification_device()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.is_active is distinct from true or coalesce(auth.jwt()->>'role','')='service_role' then return new; end if;
  if not exists(select 1 from public.izytel_user_admin_operations
    where target_uid=new.firebase_uid and command->>'action' in ('create','update')) then return new; end if;
  if exists(select 1 from public.izytel_staff_access where firebase_uid=new.firebase_uid and is_active
    and role in ('admin','manager','supervisor'))
    or exists(select 1 from public.phase5_agent_capacities where agent_id=new.firebase_uid and is_active)
    or exists(select 1 from public.partner_accounts where firebase_uid=new.firebase_uid and status='active') then return new; end if;
  raise exception 'ACCOUNT_INACTIVE' using errcode='42501';
end; $$;
revoke all on function private.izytel_guard_managed_notification_device() from public,anon,authenticated,service_role;
create trigger izytel_managed_notification_device_guard
  before insert or update on public.izytel_notification_devices
  for each row execute function private.izytel_guard_managed_notification_device();
