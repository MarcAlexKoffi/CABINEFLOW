-- Delete login identities while preserving immutable business references.
-- No existing account or historical row is deleted by applying this migration.
alter table public.partner_accounts add column account_deleted_at timestamptz;
alter table public.partner_accounts add constraint partner_deleted_access_denied check (
  account_deleted_at is null or (status='suspended' and availability='unavailable'));


create or replace function public.izytel_user_admin_begin(p_actor text,p_uid text,p_request_id text,p_command jsonb,p_before jsonb)
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
  if p_command->>'action'='delete' then
    if p_command->>'confirmUid' is distinct from p_uid then raise exception 'INVALID_CONFIRMATION'; end if;
    if exists(select 1 from public.izytel_staff_access where firebase_uid=p_uid and role='admin' and is_active)
      and (select count(*) from public.izytel_staff_access where role='admin' and is_active)<2 then raise exception 'LAST_ADMIN'; end if;
    perform 1 from public.phase5_agent_capacities where agent_id=p_uid for update;
    perform 1 from public.partner_accounts where firebase_uid=p_uid or
      (coalesce(firebase_uid,'')='' and 'partner:'||id::text=p_uid) for update;
    if exists(select 1 from public.phase4_assignment_orders o where
      (o.assigned_agent_id=p_uid or o.assigned_cabiniste_id in (select id from public.partner_accounts where firebase_uid=p_uid or
        (coalesce(firebase_uid,'')='' and 'partner:'||id::text=p_uid)))
      and o.assignment_state in ('assigned','accepted','handed_off')
      and o.order_status not in ('completed','failed','cancelled','refunded','refundPending')) then raise exception 'ACTIVE_ORDERS'; end if;
    if exists(select 1 from public.territory_zones where manager_id=p_uid and is_active) then raise exception 'DELETE_ZONE_ASSIGNED'; end if;
    p_before:=coalesce(p_before,'{}'::jsonb)||jsonb_build_object('business',jsonb_build_object(
      'agent',(select to_jsonb(a) from public.phase5_agent_capacities a where agent_id=p_uid),
      'partner',(select to_jsonb(p) from public.partner_accounts p where firebase_uid=p_uid or
        (coalesce(firebase_uid,'')='' and 'partner:'||id::text=p_uid)),
      'manager',(select to_jsonb(m) from public.manager_profiles m where firebase_uid=p_uid),
      'staff',(select to_jsonb(s) from public.izytel_staff_access s where firebase_uid=p_uid)));
  elsif exists(select 1 from public.izytel_user_admin_operations where target_uid=p_uid and command->>'action'='delete') then
    raise exception 'ACCOUNT_DELETED';
  end if;
  if p_command->>'action' not in ('create','update','reset_password','delete') then raise exception 'INVALID_ACTION'; end if;
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
  if p_command->>'action'='delete' then
    perform public.izytel_user_admin_deny(p_request_id);
    update public.partner_accounts set status='suspended',availability='unavailable',active_networks='{}',updated_at=now()
      where coalesce(firebase_uid,'')='' and 'partner:'||id::text=p_uid;
  end if;
  return jsonb_build_object('request_id',p_request_id,'status','pending','fresh',true);
end; $$;

create or replace function private.izytel_guard_managed_account_access()
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
  if tg_op<>'DELETE' and exists(select 1 from public.izytel_user_admin_operations
    where target_uid=v_uid and command->>'action'='delete') and (
      tg_op='INSERT' or coalesce((to_jsonb(new)->>'is_active')::boolean,false) or to_jsonb(new)->>'status'='active') then
    raise exception 'ACCOUNT_DELETED';
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

create function public.izytel_user_admin_delete_access(p_request_id text)
returns boolean language plpgsql security definer set search_path='' as $$
declare o public.izytel_user_admin_operations;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'SERVICE_REQUIRED'; end if;
  select * into strict o from public.izytel_user_admin_operations where request_id=p_request_id for update;
  if o.command->>'action'<>'delete' or o.command->>'confirmUid' is distinct from o.target_uid then raise exception 'INVALID_OPERATION'; end if;
  if o.status='completed' then return true; end if;
  if o.status<>'pending' then raise exception 'OPERATION_REQUIRES_REPAIR'; end if;
  perform public.izytel_user_admin_deny(p_request_id);
  update public.partner_accounts set account_deleted_at=coalesce(account_deleted_at,clock_timestamp()),
    status='suspended',availability='unavailable',active_networks='{}',updated_at=now()
    where firebase_uid=o.target_uid or (coalesce(firebase_uid,'')='' and 'partner:'||id::text=o.target_uid);
  return true;
end; $$;
revoke all on function public.izytel_user_admin_delete_access(text) from public,anon,authenticated;
grant execute on function public.izytel_user_admin_delete_access(text) to service_role;
