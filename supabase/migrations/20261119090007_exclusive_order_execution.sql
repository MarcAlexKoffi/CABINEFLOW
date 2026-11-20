-- Exclusive execution rollout. Recorded remotely as 20261119090007.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';

-- Save exact pre-migration definitions/ACLs for a data-preserving rollback.
create table private.izytel_execution_schema_backup(object_key text primary key,definition text not null,acl jsonb);
alter table private.izytel_execution_schema_backup enable row level security;
revoke all on private.izytel_execution_schema_backup from public,anon,authenticated;
insert into private.izytel_execution_schema_backup
select p.oid::regprocedure::text,pg_get_functiondef(p.oid),
  (select jsonb_agg(jsonb_build_object('grantee',case when a.grantee=0 then 'PUBLIC' else pg_get_userbyid(a.grantee) end,
    'grantable',a.is_grantable)) from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where a.privilege_type='EXECUTE')
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where (n.nspname='private' and p.proname in ('izytel_shared_claim','izytel_shared_order_guard','izytel_acceptance_lifecycle',
  'izytel_shared_order_events','izytel_detect_order_delays','izytel_order_supervision',
  'phase3_agent_processing_action','ussd_resolve','ussd_prepare','ussd_record_result','phase5_finalize_order_success'))
  or (n.nspname='public' and p.proname='izytel_notification_recipient_authorized');
insert into private.izytel_execution_schema_backup(object_key,definition)
select 'order_select_policy',format('create policy %I on public.phase4_assignment_orders for select to anon,authenticated using (%s)',policyname,qual)
from pg_policies where schemaname='public' and tablename='phase4_assignment_orders'
  and policyname='phase4 scoped staff assigned agent or cabiniste reads orders';

create table private.izytel_order_executions (
  order_id text not null references public.phase4_assignment_orders(order_id),
  assignment_version bigint not null,
  agent_id text not null,
  request_id text not null check(length(request_id)=64),
  auth_time text not null,
  state text not null default 'authorized'
    check(state in ('authorized','uncertain','verified_not_executed','completed','revoked')),
  authorized_at timestamptz not null default clock_timestamp(),
  verified_by text,
  verified_at timestamptz,
  verification_reason text,
  primary key(order_id,assignment_version)
);
alter table private.izytel_order_executions enable row level security;
revoke all on private.izytel_order_executions from public,anon,authenticated;

create table public.izytel_order_requeues (
  id uuid primary key default gen_random_uuid(),
  order_id text not null references public.phase4_assignment_orders(order_id),
  old_assignment_version bigint not null,
  previous_agent_id text,
  actor_uid text not null,
  request_id text not null,
  reason text not null,
  previous_order jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  unique(actor_uid,request_id)
);
alter table public.izytel_order_requeues enable row level security;
revoke all on public.izytel_order_requeues from public,anon,authenticated;
grant select on public.izytel_order_requeues to anon,authenticated;
create policy "territorial requeue history" on public.izytel_order_requeues
for select to anon,authenticated using(exists(select 1 from public.phase4_assignment_orders o
  where o.order_id=izytel_order_requeues.order_id and private.izytel_shared_staff_zone(o.zone_id)));

create function private.izytel_assert_execution(p_order_id text) returns void
language plpgsql security definer set search_path='' as $$
declare o public.phase4_assignment_orders; e private.izytel_order_executions;
  k text:=nullif(current_setting('request.headers',true),'')::jsonb->>'x-izytel-execution-key';
begin
  select * into o from public.phase4_assignment_orders where order_id=p_order_id;
  if o.assigned_agent_id is null and o.assigned_cabiniste_id is not null then return;end if;
  if not public.is_izytel_firebase_jwt() or o.assigned_agent_id is distinct from (auth.jwt()->>'sub')
     or not coalesce(private.izytel_shared_agent_zone(o.zone_id),false)
     or not exists(select 1 from public.phase5_agent_capacities c where c.agent_id=o.assigned_agent_id
       and c.is_active and o.network=any(c.authorized_networks)) then
    raise exception 'EXECUTION_OWNER_REQUIRED' using errcode='42501';end if;
  select * into e from private.izytel_order_executions
    where order_id=o.order_id and assignment_version=o.assignment_version;
  if not found or e.agent_id<>o.assigned_agent_id or e.request_id is distinct from k
    or e.auth_time is distinct from (auth.jwt()->>'auth_time')
    or e.state not in ('authorized','uncertain','completed') then
    raise exception 'EXECUTION_SESSION_REQUIRED' using errcode='42501';end if;
  if clock_timestamp()<e.authorized_at+interval '5 seconds'
    and coalesce(current_setting('izytel.begin_execution',true),'')<>'authorized' then
    raise exception 'EXECUTION_PREPARING' using errcode='42501';end if;
end $$;
revoke all on function private.izytel_assert_execution(text) from public,anon,authenticated;

create function private.izytel_execution_visible(p_order_id text) returns boolean
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.izytel_assert_execution(p_order_id);
  return true;
exception when insufficient_privilege then return false;
end $$;
revoke all on function private.izytel_execution_visible(text) from public;
grant execute on function private.izytel_execution_visible(text) to anon,authenticated;

create function private.izytel_order_for_reader(o public.phase4_assignment_orders) returns jsonb
language sql stable security definer set search_path='' as $$
  select case when private.izytel_shared_staff_zone(o.zone_id)
    or private.izytel_execution_visible(o.order_id) or o.order_status='completed' then to_jsonb(o)
  else to_jsonb(o)||jsonb_build_object('beneficiary_phone','••••','client_whatsapp_phone','',
    'original_whatsapp_message',null,'internal_notes',null) end;
$$;
revoke all on function private.izytel_order_for_reader(public.phase4_assignment_orders) from public,anon,authenticated;
create function private.izytel_read_orders(p_order_id text default null,p_agent_id text default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
  if not public.is_izytel_firebase_jwt() then raise exception 'AUTH_REQUIRED' using errcode='42501';end if;
  return (select coalesce(jsonb_agg(private.izytel_order_for_reader(o)),'[]'::jsonb)
    from public.phase4_assignment_orders o where (p_order_id is null or o.order_id=p_order_id)
      and (p_agent_id is null or o.assigned_agent_id=p_agent_id)
      and (private.izytel_shared_staff_zone(o.zone_id)
        or (o.assigned_agent_id=auth.jwt()->>'sub' and private.izytel_shared_agent_zone(o.zone_id))));
end $$;
create function public.izytel_read_orders(p_order_id text default null,p_agent_id text default null) returns jsonb
language sql set search_path='' as $$select private.izytel_read_orders(p_order_id,p_agent_id);$$;
revoke all on function private.izytel_read_orders(text,text),public.izytel_read_orders(text,text) from public;
grant execute on function private.izytel_read_orders(text,text),public.izytel_read_orders(text,text) to anon,authenticated;
drop policy "phase4 scoped staff assigned agent or cabiniste reads orders" on public.phase4_assignment_orders;
create policy "phase4 scoped staff assigned agent or cabiniste reads orders" on public.phase4_assignment_orders
for select to anon,authenticated using(public.is_izytel_firebase_jwt() and (
  private.izytel_shared_staff_zone(zone_id)
  or (assigned_agent_id=auth.jwt()->>'sub' and private.izytel_shared_agent_zone(zone_id)
    and (order_status='completed' or private.izytel_execution_visible(order_id)))
  or exists(select 1 from public.partner_accounts p where p.id=assigned_cabiniste_id
    and p.firebase_uid=auth.jwt()->>'sub' and p.status='active')));

alter function private.izytel_shared_claim(text,bigint) rename to izytel_shared_claim_before_execution;
revoke all on function private.izytel_shared_claim_before_execution(text,bigint) from public,anon,authenticated;
create function private.izytel_shared_claim(p_order_id text,p_expected_version bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r jsonb;o public.phase4_assignment_orders;
begin
  r:=private.izytel_shared_claim_before_execution(p_order_id,p_expected_version);
  select * into o from public.phase4_assignment_orders where order_id=btrim(p_order_id);
  return r||jsonb_build_object('order',private.izytel_order_for_reader(o));
end $$;
revoke all on function private.izytel_shared_claim(text,bigint) from public;
grant execute on function private.izytel_shared_claim(text,bigint) to anon,authenticated;

-- This guard also covers legacy acceptance, direct UPDATEs and older RPCs.
create function private.izytel_exclusive_order_guard() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.assigned_agent_id is not null and new.assignment_state in ('accepted','handed_off')
     and new.order_status in ('paidReady','inProgress','onHold') and
     (old.assigned_agent_id is distinct from new.assigned_agent_id
       or old.assignment_state not in ('accepted','handed_off')) then
    perform 1 from public.phase5_agent_capacities where agent_id=new.assigned_agent_id for update;
    if exists(select 1 from public.phase4_assignment_orders o
      where o.order_id<>new.order_id and o.assigned_agent_id=new.assigned_agent_id
        and ((o.assignment_state in ('accepted','handed_off') and o.order_status in ('paidReady','inProgress','onHold'))
          or exists(select 1 from private.izytel_order_executions e where e.order_id=o.order_id
            and e.assignment_version=o.assignment_version and e.state='uncertain'))) then
      raise exception 'AGENT_ACTIVE_ORDER_EXISTS';end if;
  end if;
  if old.assigned_agent_id is not null and
    (new.assigned_agent_id is distinct from old.assigned_agent_id
      or new.assignment_state not in ('accepted','handed_off') and old.assignment_state in ('accepted','handed_off')) then
    if exists(select 1 from private.izytel_order_executions e where e.order_id=old.order_id
      and e.assignment_version=old.assignment_version and e.state='uncertain')
      or (old.processing_started_at is not null and old.order_status<>'completed'
        and not exists(select 1 from private.izytel_order_executions e where e.order_id=old.order_id
          and e.assignment_version=old.assignment_version and e.state='verified_not_executed')) then
      raise exception 'EXECUTION_REQUIRES_MANAGER_VERIFICATION';end if;
  end if;
  if old.assigned_agent_id is not null and new.order_status is distinct from old.order_status
     and (new.order_status in ('inProgress','onHold','completed','failed'))
     and coalesce(current_setting('izytel.requeue',true),'')<>'authorized' then
    perform private.izytel_assert_execution(old.order_id);
  end if;
  return new;
end $$;
revoke all on function private.izytel_exclusive_order_guard() from public,anon,authenticated;
create trigger aab_izytel_exclusive_order_guard before update on public.phase4_assignment_orders
for each row execute function private.izytel_exclusive_order_guard();

create function private.izytel_execution_lifecycle() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  update private.izytel_order_executions set state=case
    when new.assignment_version<>assignment_version or new.assigned_agent_id is distinct from agent_id then 'revoked'
    when new.order_status='completed' then 'completed' else state end
  where order_id=new.order_id and state not in ('completed','revoked');
  return new;
end $$;
revoke all on function private.izytel_execution_lifecycle() from public,anon,authenticated;
create trigger zzzz_izytel_execution_lifecycle after update on public.phase4_assignment_orders
for each row execute function private.izytel_execution_lifecycle();

-- Retain the existing business implementations, but revoke their direct use.
alter function private.phase3_agent_processing_action(text,text,text,text) rename to phase3_agent_processing_action_before_execution;
revoke all on function private.phase3_agent_processing_action_before_execution(text,text,text,text) from public,anon,authenticated;
create function private.phase3_agent_processing_action(p_order_id text,p_action text,p_reason text default null,p_observation text default null)
returns public.phase4_assignment_orders language plpgsql security definer set search_path='' as $$
begin
  perform private.izytel_assert_execution(btrim(p_order_id));
  return private.phase3_agent_processing_action_before_execution(p_order_id,p_action,p_reason,p_observation);
end $$;
revoke all on function private.phase3_agent_processing_action(text,text,text,text) from public;
grant execute on function private.phase3_agent_processing_action(text,text,text,text) to anon,authenticated;

create function private.izytel_begin_order_execution(p_order_id text,p_expected_version bigint,p_request_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.phase4_assignment_orders; e private.izytel_order_executions;
  u text:=auth.jwt()->>'sub'; t text:=auth.jwt()->>'auth_time';
begin
  if not public.is_izytel_firebase_jwt() or u is null or t is null then
    raise exception 'AUTH_REQUIRED' using errcode='42501';end if;
  if p_request_id !~ '^[0-9a-f]{64}$' or p_request_id is null then raise exception 'INVALID_EXECUTION_KEY';end if;
  select * into o from public.phase4_assignment_orders where order_id=btrim(p_order_id) for update;
  if not found or o.assigned_agent_id is distinct from u
    or not coalesce(private.izytel_shared_agent_zone(o.zone_id),false)
    or o.assignment_state not in ('accepted','handed_off') then
    raise exception 'EXECUTION_OWNER_REQUIRED' using errcode='42501';end if;
  if o.order_status not in ('paidReady','inProgress','onHold')
    or (o.payment_status<>'confirmed' and not (o.assignment_route='legacy' and o.payment_status='credit'))
    or o.legacy_state_unresolved then raise exception 'ORDER_NOT_PROCESSABLE';end if;
  if o.assignment_version is distinct from p_expected_version then raise exception 'EXECUTION_VERSION_EXPIRED';end if;
  select * into e from private.izytel_order_executions
    where order_id=o.order_id and assignment_version=o.assignment_version;
  if found then
    perform set_config('izytel.begin_execution','authorized',true);
    perform private.izytel_assert_execution(o.order_id);
  else
  -- Existing in-progress orders need Manager verification rather than a fresh lease.
  if o.order_status<>'paidReady' or o.processing_started_at is not null then
    raise exception 'EXECUTION_REQUIRES_MANAGER_VERIFICATION';end if;
  perform 1 from public.phase5_agent_capacities where agent_id=u for update;
  if exists(select 1 from private.izytel_order_executions x where x.agent_id=u
    and x.order_id<>o.order_id and x.state in ('authorized','uncertain')) then
    raise exception 'AGENT_ACTIVE_ORDER_EXISTS';end if;
  if not private.phase3_agent_is_eligible(u,o.order_id) then raise exception 'AGENT_NOT_ELIGIBLE_CURRENT_STATE';end if;
  insert into private.izytel_order_executions(order_id,assignment_version,agent_id,request_id,auth_time)
    values(o.order_id,o.assignment_version,u,p_request_id,t) returning * into e;
  perform set_config('izytel.begin_execution','authorized',true);
  perform private.izytel_assert_execution(o.order_id);
  o:=private.phase3_agent_processing_action(o.order_id,'start',null,null);
  end if;
  perform set_config('izytel.begin_execution','',true);
  return jsonb_build_object('ready',clock_timestamp()>=e.authorized_at+interval '5 seconds',
    'retry_after_ms',greatest(0,ceil(extract(epoch from (e.authorized_at+interval '5 seconds'-clock_timestamp()))*1000)),
    'order',private.izytel_order_for_reader(o));
end $$;
create function public.izytel_begin_order_execution(p_order_id text,p_expected_version bigint,p_request_id text)
returns jsonb language sql set search_path='' as $$select private.izytel_begin_order_execution(p_order_id,p_expected_version,p_request_id);$$;
revoke all on function private.izytel_begin_order_execution(text,bigint,text),public.izytel_begin_order_execution(text,bigint,text) from public;
grant execute on function private.izytel_begin_order_execution(text,bigint,text),public.izytel_begin_order_execution(text,bigint,text) to anon,authenticated;

-- Apply session checks to both USSD preview and launch, and to financial closure.
alter function private.ussd_resolve(text) rename to ussd_resolve_before_execution;
revoke all on function private.ussd_resolve_before_execution(text) from public,anon,authenticated;
create function private.ussd_resolve(p_order_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  perform private.izytel_assert_execution(p_order_id);
  return private.ussd_resolve_before_execution(p_order_id);
end $$;
alter function private.ussd_prepare(text,uuid,integer,jsonb,text) rename to ussd_prepare_before_execution;
revoke all on function private.ussd_prepare_before_execution(text,uuid,integer,jsonb,text) from public,anon,authenticated;
create function private.ussd_prepare(p_order_id text,p_rule_id uuid,p_version integer,p_context jsonb,p_request_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.phase4_assignment_orders; result jsonb;
begin
  -- Same lock order as the original USSD configuration path.
  perform pg_advisory_xact_lock(9261031);
  select * into o from public.phase4_assignment_orders where order_id=p_order_id for update;
  perform private.izytel_assert_execution(p_order_id);
  if o.assigned_agent_id is not null and exists(select 1 from private.izytel_order_executions
    where order_id=p_order_id and assignment_version=o.assignment_version and state='uncertain') then
    return jsonb_build_object('status','unavailable','reason','execution_uncertain');end if;
  result:=private.ussd_prepare_before_execution(p_order_id,p_rule_id,p_version,p_context,p_request_id);
  if result->>'status'='available' then
    update private.izytel_order_executions set state='uncertain'
      where order_id=p_order_id and assignment_version=o.assignment_version;
  end if;
  return result;
end $$;
alter function private.ussd_record_result(uuid,text,text) rename to ussd_record_result_before_execution;
revoke all on function private.ussd_record_result_before_execution(uuid,text,text) from public,anon,authenticated;
create function private.ussd_record_result(p_attempt_id uuid,p_status text,p_error_code text) returns void
language plpgsql security definer set search_path='' as $$
declare oid text;
begin
  select order_id into oid from public.ussd_execution_logs where id=p_attempt_id;
  perform private.izytel_assert_execution(oid);
  perform private.ussd_record_result_before_execution(p_attempt_id,p_status,p_error_code);
end $$;
alter function private.phase5_finalize_order_success(text,text,timestamptz) rename to phase5_finalize_order_success_before_execution;
revoke all on function private.phase5_finalize_order_success_before_execution(text,text,timestamptz) from public,anon,authenticated;
create function private.phase5_finalize_order_success(p_order_id text,p_agent_name text,p_processing_started_at timestamptz default null)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform private.izytel_assert_execution(btrim(p_order_id));
  return private.phase5_finalize_order_success_before_execution(p_order_id,p_agent_name,p_processing_started_at);
end $$;
revoke all on function private.ussd_resolve(text),private.ussd_prepare(text,uuid,integer,jsonb,text),
  private.ussd_record_result(uuid,text,text),private.phase5_finalize_order_success(text,text,timestamptz) from public;
grant execute on function private.ussd_resolve(text),private.ussd_prepare(text,uuid,integer,jsonb,text),
  private.ussd_record_result(uuid,text,text),private.phase5_finalize_order_success(text,text,timestamptz) to anon,authenticated;

create function private.izytel_verify_order_not_executed(p_order_id text,p_reason text,p_expected_version bigint) returns void
language plpgsql security definer set search_path='' as $$
declare o public.phase4_assignment_orders;
begin
  select * into o from public.phase4_assignment_orders where order_id=btrim(p_order_id) for update;
  if not found or not coalesce(private.izytel_shared_staff_zone(o.zone_id),false) then
    raise exception 'MANAGER_ZONE_REQUIRED' using errcode='42501';end if;
  if length(btrim(coalesce(p_reason,''))) not between 10 and 500 then raise exception 'VERIFICATION_REASON_REQUIRED';end if;
  if o.assignment_version is distinct from p_expected_version then raise exception 'ASSIGNMENT_VERSION_EXPIRED';end if;
  if o.order_status in ('completed','awaitingCustomerConfirmation','refundPending','refunded','cancelled')
    or o.assigned_agent_id is null then raise exception 'ORDER_NOT_REQUEUEABLE';end if;
  insert into private.izytel_order_executions(order_id,assignment_version,agent_id,request_id,auth_time,state,
    verified_by,verified_at,verification_reason)
  values(o.order_id,o.assignment_version,o.assigned_agent_id,repeat('0',64),'legacy','verified_not_executed',
    auth.jwt()->>'sub',clock_timestamp(),btrim(p_reason))
  on conflict(order_id,assignment_version) do update set state='verified_not_executed',
    verified_by=excluded.verified_by,verified_at=excluded.verified_at,verification_reason=excluded.verification_reason;
end $$;

-- Permit conversion of a historical assignment only inside the checked requeue RPC.
do $$declare d text;begin
  d:=pg_get_functiondef('private.izytel_shared_order_guard()'::regprocedure);
  if position('if new.assignment_route is distinct from old.assignment_route then' in d)=0 then
    raise exception 'UNEXPECTED_SHARED_GUARD_DEFINITION';end if;
  d:=replace(d,'if new.assignment_route is distinct from old.assignment_route then',
    'if new.assignment_route is distinct from old.assignment_route and not (coalesce(current_setting(''izytel.requeue'',true),'''')=''authorized'' and private.izytel_shared_staff_zone(old.zone_id)) then');
  execute d;
end $$;

create function private.izytel_return_order_to_queue(p_order_id text,p_reason text,p_request_id text)
returns public.phase4_assignment_orders language plpgsql security definer set search_path='' as $$
declare o public.phase4_assignment_orders; r public.izytel_order_requeues;
begin
  select * into o from public.phase4_assignment_orders where order_id=btrim(p_order_id) for update;
  if not found or not coalesce(private.izytel_shared_staff_zone(o.zone_id),false) then
    raise exception 'MANAGER_ZONE_REQUIRED' using errcode='42501';end if;
  if p_request_id is null or length(p_request_id)<>64 or length(btrim(coalesce(p_reason,''))) not between 3 and 500 then
    raise exception 'REQUEUE_REASON_REQUIRED';end if;
  select * into r from public.izytel_order_requeues where actor_uid=auth.jwt()->>'sub' and request_id=p_request_id;
  if found then
    if r.order_id<>o.order_id then raise exception 'IDEMPOTENCY_CONFLICT';end if;
    return o;
  end if;
  if o.order_status not in ('paidReady','inProgress','onHold','failed') or o.payment_status<>'confirmed'
    or o.assigned_cabiniste_id is not null or o.legacy_state_unresolved
    or exists(select 1 from public.phase5_success_finalizations where order_id=o.order_id) then
    raise exception 'ORDER_NOT_REQUEUEABLE';end if;
  if not (select enabled from private.izytel_shared_queue_settings where singleton) then raise exception 'QUEUE_DISABLED';end if;
  if o.assignment_route='shared' and o.assignment_state='waiting' and o.assigned_agent_id is null then return o;end if;
  if exists(select 1 from private.izytel_order_executions e where e.order_id=o.order_id
    and e.assignment_version=o.assignment_version and e.state='uncertain')
    or ((o.processing_started_at is not null or o.order_status in ('inProgress','onHold','failed'))
      and not exists(select 1 from private.izytel_order_executions e where e.order_id=o.order_id
        and e.assignment_version=o.assignment_version and e.state='verified_not_executed'))
    or exists(select 1 from public.ussd_execution_logs l where l.order_id=o.order_id
      and l.generated_at>=coalesce(o.assigned_at,'-infinity'::timestamptz)
      and l.launch_status in ('prepared','dialer_opened')
      and not exists(select 1 from private.izytel_order_executions e where e.order_id=o.order_id
        and e.assignment_version=o.assignment_version and e.state='verified_not_executed')) then
    raise exception 'EXECUTION_REQUIRES_MANAGER_VERIFICATION';end if;
  insert into public.izytel_order_requeues(order_id,old_assignment_version,previous_agent_id,actor_uid,request_id,reason,previous_order)
    values(o.order_id,o.assignment_version,o.assigned_agent_id,auth.jwt()->>'sub',p_request_id,btrim(p_reason),to_jsonb(o));
  update public.phase4_assignment_history set status='reassigned',updated_at=clock_timestamp()
    where order_id=o.order_id and status in ('assigned','accepted','handed_off');
  update public.phase4_assignment_plans set candidate_agent_ids='{}',candidate_names='{}',refused_agent_ids='{}',
    plan_mode='manual',updated_at=clock_timestamp() where order_id=o.order_id;
  perform set_config('izytel.requeue','authorized',true);
  update public.phase4_assignment_orders set assignment_route='shared',assignment_state='waiting',
    assigned_agent_id=null,assigned_agent_name=null,assigned_by_uid=auth.jwt()->>'sub',assignment_mode=null,
    assigned_at=null,order_status='paidReady',processing_started_at=null,completed_at=null,
    failure_reason=null,observation=null,last_hold_reason=null,last_held_at=null,last_resumed_at=null,
    firebase_assignment_synced_at=null,firebase_handoff_at=null,last_refusal_reason=null,
    last_refused_at=null,last_refused_agent_id=null
    where order_id=o.order_id returning * into o;
  perform set_config('izytel.requeue','',true);
  return o;
end $$;
create function public.izytel_return_order_to_queue(p_order_id text,p_reason text,p_request_id text)
returns public.phase4_assignment_orders language sql set search_path='' as $$select private.izytel_return_order_to_queue(p_order_id,p_reason,p_request_id);$$;
create function public.izytel_verify_order_not_executed(p_order_id text,p_reason text,p_expected_version bigint) returns void
language sql set search_path='' as $$select private.izytel_verify_order_not_executed(p_order_id,p_reason,p_expected_version);$$;
revoke all on function private.izytel_return_order_to_queue(text,text,text),private.izytel_verify_order_not_executed(text,text,bigint),
  public.izytel_return_order_to_queue(text,text,text),public.izytel_verify_order_not_executed(text,text,bigint) from public;
grant execute on function private.izytel_return_order_to_queue(text,text,text),private.izytel_verify_order_not_executed(text,text,bigint),
  public.izytel_return_order_to_queue(text,text,text),public.izytel_verify_order_not_executed(text,text,bigint) to anon,authenticated;

do $$declare d text;begin
  d:=pg_get_functiondef('private.izytel_acceptance_lifecycle()'::regprocedure);
  if position('if v_changed then' in d)=0 then raise exception 'UNEXPECTED_ACCEPTANCE_LIFECYCLE';end if;
  d:=replace(d,'if v_changed then',
    'if v_changed or coalesce(current_setting(''izytel.requeue'',true),'''')=''authorized'' then');
  d:=replace(d,'and old.assignment_state<>''waiting'' then',
    'and (old.assignment_state<>''waiting'' or old.assignment_route<>''shared'') then');
  execute d;
end $$;

-- A failed order with an unknown telecom result remains active for SLA and
-- single-order admission until verified or finalized. Existing cron/outbox stay authoritative.
do $$declare f regprocedure;d text;begin
  foreach f in array array['private.izytel_detect_order_delays(integer)'::regprocedure,
    'private.izytel_order_supervision(integer)'::regprocedure,
    'public.izytel_notification_recipient_authorized(uuid)'::regprocedure] loop
    d:=pg_get_functiondef(f);
    d:=replace(d,'o.order_status in (''paidReady'',''inProgress'',''onHold'')',
      '(o.order_status in (''paidReady'',''inProgress'',''onHold'') or exists(select 1 from private.izytel_order_executions e where e.order_id=o.order_id and e.assignment_version=o.assignment_version and e.state=''uncertain''))');
    execute d;
  end loop;
  d:=pg_get_functiondef('private.izytel_shared_order_events()'::regprocedure);
  d:=replace(d,'new.order_status not in (''paidReady'',''inProgress'',''onHold'')',
    '(new.order_status=''completed'' or (new.order_status not in (''paidReady'',''inProgress'',''onHold'') and not exists(select 1 from private.izytel_order_executions e where e.order_id=new.order_id and e.assignment_version=new.assignment_version and e.state=''uncertain'')))');
  execute d;
end $$;
commit;
