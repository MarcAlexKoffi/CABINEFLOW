-- BO-6 — Controle & Pilotage
-- Snapshot lecture seule partage entre Web BO et mobile Manager.
-- Admin : perimetre global + audit sensible.
-- Manager / supervisor : seulement ses zones et les agents rattaches.

create or replace function public.izytel_bo6_control_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_role text := private.izytel_current_staff_role();
  v_admin boolean := false;
  v_today date := (now() at time zone 'Africa/Abidjan')::date;
  v_agent_ids text[] := array[]::text[];
  v_zone_count integer := 0;
  v_activity jsonb := '[]'::jsonb;
  v_audit jsonb := '[]'::jsonb;
  v_stats jsonb := '{}'::jsonb;
  v_networks jsonb := '[]'::jsonb;
  v_agents jsonb := '[]'::jsonb;
  v_admin_finance jsonb := '{}'::jsonb;
begin
  if v_uid is null or not public.is_izytel_firebase_jwt()
     or v_role not in ('admin', 'manager', 'supervisor') then
    raise exception 'STAFF_REQUIRED';
  end if;

  v_admin := v_role = 'admin';

  if not v_admin then
    select count(*)::integer into v_zone_count
    from public.territory_zones z
    where z.manager_id = v_uid and z.is_active = true;

    select coalesce(array_agg(distinct c.agent_id), array[]::text[])
      into v_agent_ids
    from public.phase5_agent_capacities c
    where exists (
      select 1 from public.territory_zones z
      where z.manager_id = v_uid and z.is_active = true
        and z.id = any(coalesce(c.zone_ids, array[]::text[]))
    );
  end if;

  with scoped_orders as (
    select o.* from public.phase4_assignment_orders o
    where v_admin or o.assigned_agent_id = any(v_agent_ids)
  ), events as (
    select 'order-created-' || o.order_id as id,
           coalesce(o.firebase_created_at, o.created_at) as occurred_at,
           'orders'::text as domain, 'order_created'::text as event_kind,
           'Commande creee'::text as title, o.order_reference as reference,
           null::text as actor_uid, null::text as actor_name, 'info'::text as severity,
           jsonb_build_object('network',o.network,'amount',o.amount,'status',o.order_status,'agent_id',o.assigned_agent_id,'agent_name',o.assigned_agent_name) as details
    from scoped_orders o
    union all
    select 'order-assigned-' || o.order_id, o.assigned_at, 'assignments','order_assigned','Commande affectee',o.order_reference,
           o.assigned_by_uid,null::text,'info',jsonb_build_object('agent_id',o.assigned_agent_id,'agent_name',o.assigned_agent_name,'mode',o.assignment_mode)
    from scoped_orders o where o.assigned_at is not null
    union all
    select 'order-completed-' || o.order_id, o.completed_at, 'orders','order_completed','Commande terminee',o.order_reference,
           o.assigned_agent_id,o.assigned_agent_name,'success',jsonb_build_object('network',o.network,'amount',o.amount)
    from scoped_orders o where o.completed_at is not null and o.order_status='completed'
    union all
    select 'order-failed-' || o.order_id, o.updated_at, 'orders','order_failed','Commande echouee',o.order_reference,
           o.assigned_agent_id,o.assigned_agent_name,'error',jsonb_build_object('network',o.network,'amount',o.amount,'failure_reason',o.failure_reason)
    from scoped_orders o where o.order_status='failed'
    union all
    select 'support-created-' || s.id, s.created_at, 'support','support_created','Demande client creee',coalesce(nullif(s.order_reference,''),s.id),
           null::text,null::text,'warning',jsonb_build_object('type',s.type,'status',s.status)
    from public.support_requests s
    where v_admin or s.assigned_to=v_uid or exists(select 1 from scoped_orders o where o.order_id=s.order_id)
    union all
    select 'issue-created-' || i.id::text, i.created_at, 'agents','agent_issue_created','Signalement agent cree',i.id::text,
           i.agent_id,null::text,'warning',jsonb_build_object('type',i.type,'network',i.network,'status',i.status)
    from public.agent_issues i where v_admin or i.agent_id=any(v_agent_ids)
  ), limited as (
    select * from events where occurred_at is not null order by occurred_at desc limit 500
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',id,'occurred_at',occurred_at,'domain',domain,'event_kind',event_kind,'title',title,
    'reference',reference,'actor_uid',actor_uid,'actor_name',actor_name,'severity',severity,'details',details
  ) order by occurred_at desc),'[]'::jsonb) into v_activity from limited;

  if v_admin then
    with events as (
      select 'finance-'||id::text as id, created_at as occurred_at, 'finance'::text as domain,
             event_kind as action, entity_type, entity_id, actor_uid, actor_name,
             jsonb_build_object('payload',payload) as details
      from public.finance_audit_events
      union all
      select 'catalog-'||id::text,created_at,'catalog',action,'offer',offer_id,actor_uid,actor_name,
             jsonb_build_object('actor_role',actor_role,'before_state',before_state,'after_state',after_state)
      from public.catalog_offer_audit_events
      union all
      select 'territory-'||id::text,created_at,'territory',action,entity_type,entity_id,actor_uid,actor_name,
             jsonb_build_object('actor_role',actor_role,'before_state',before_state,'after_state',after_state)
      from public.territory_audit_events
      union all
      select 'staff-'||id::text,created_at,'staff',action,'staff_profile',firebase_uid,actor_uid,null::text,
             jsonb_build_object('actor_role',actor_role,'note',note)
      from public.staff_profile_audit_events
    ), limited as (select * from events order by occurred_at desc limit 500)
    select coalesce(jsonb_agg(jsonb_build_object(
      'id',id,'occurred_at',occurred_at,'domain',domain,'action',action,'entity_type',entity_type,
      'entity_id',entity_id,'actor_uid',actor_uid,'actor_name',actor_name,'details',details
    ) order by occurred_at desc),'[]'::jsonb) into v_audit from limited;
  end if;

  with o as (
    select * from public.phase4_assignment_orders
    where v_admin or assigned_agent_id=any(v_agent_ids)
  )
  select jsonb_build_object(
    'today_orders',count(*) filter(where (coalesce(firebase_created_at,created_at) at time zone 'Africa/Abidjan')::date=v_today),
    'today_completed',count(*) filter(where order_status='completed' and completed_at is not null and (completed_at at time zone 'Africa/Abidjan')::date=v_today),
    'today_failed',count(*) filter(where order_status='failed' and (updated_at at time zone 'Africa/Abidjan')::date=v_today),
    'active_orders',count(*) filter(where order_status in ('paidReady','inProgress','onHold','awaitingCustomerConfirmation','refundPending')),
    'orders_7d',count(*) filter(where coalesce(firebase_created_at,created_at)>=now()-interval '7 days'),
    'completed_7d',count(*) filter(where order_status='completed' and completed_at>=now()-interval '7 days'),
    'failed_7d',count(*) filter(where order_status='failed' and updated_at>=now()-interval '7 days'),
    'orders_30d',count(*) filter(where coalesce(firebase_created_at,created_at)>=now()-interval '30 days'),
    'completed_30d',count(*) filter(where order_status='completed' and completed_at>=now()-interval '30 days'),
    'failed_30d',count(*) filter(where order_status='failed' and updated_at>=now()-interval '30 days'),
    'avg_processing_minutes_30d',coalesce(round(avg(extract(epoch from(completed_at-processing_started_at))/60.0)
      filter(where order_status='completed' and completed_at>=now()-interval '30 days' and processing_started_at is not null and completed_at>=processing_started_at),1),0),
    'manager_zones',case when v_admin then null else v_zone_count end,
    'manager_agents',case when v_admin then null else cardinality(v_agent_ids) end,
    'support_open',(select count(*) from public.support_requests s where s.status in ('new','newRequest','inProgress','in_progress') and
      (v_admin or s.assigned_to=v_uid or exists(select 1 from o x where x.order_id=s.order_id))),
    'agent_issues_open',(select count(*) from public.agent_issues i where i.status in ('open','in_progress') and (v_admin or i.agent_id=any(v_agent_ids)))
  ) into v_stats from o;

  with o as (
    select * from public.phase4_assignment_orders
    where (v_admin or assigned_agent_id=any(v_agent_ids)) and coalesce(firebase_created_at,created_at)>=now()-interval '30 days'
  ), g as (
    select coalesce(nullif(btrim(network),''),'unknown') network, count(*)::integer orders,
      count(*) filter(where order_status='completed')::integer completed,
      count(*) filter(where order_status='failed')::integer failed,
      coalesce(sum(amount) filter(where order_status='completed'),0)::bigint completed_amount
    from o group by 1 order by 1
  ) select coalesce(jsonb_agg(to_jsonb(g)),'[]'::jsonb) into v_networks from g;

  with o as (
    select * from public.phase4_assignment_orders
    where (v_admin or assigned_agent_id=any(v_agent_ids)) and coalesce(firebase_created_at,created_at)>=now()-interval '30 days'
      and nullif(btrim(coalesce(assigned_agent_id,'')),'') is not null
  ), g as (
    select assigned_agent_id agent_id, coalesce(nullif(btrim(assigned_agent_name),''),assigned_agent_id) agent_name,
      count(*)::integer orders, count(*) filter(where order_status='completed')::integer completed,
      count(*) filter(where order_status='failed')::integer failed,
      coalesce(sum(amount) filter(where order_status='completed'),0)::bigint completed_amount,
      coalesce(round(avg(extract(epoch from(completed_at-processing_started_at))/60.0)
        filter(where order_status='completed' and processing_started_at is not null and completed_at is not null and completed_at>=processing_started_at),1),0) avg_processing_minutes
    from o group by assigned_agent_id,coalesce(nullif(btrim(assigned_agent_name),''),assigned_agent_id)
    order by completed desc,orders desc,agent_name limit 100
  ) select coalesce(jsonb_agg(to_jsonb(g)),'[]'::jsonb) into v_agents from g;

  if v_admin then
    select jsonb_build_object(
      'refund_amount_30d',coalesce(sum(amount) filter(where refunded_at>=now()-interval '30 days'),0),
      'customer_receivables',coalesce((select sum(greatest(amount-paid_amount,0)) from public.finance_customer_credits),0),
      'supplier_debt',coalesce((select sum(greatest(total_owed-total_paid,0)) from public.phase5_supplier_accounts),0),
      'commission_debt',coalesce((select sum(greatest(earned_total-paid_total,0)) from public.phase5_commission_accounts),0)
    ) into v_admin_finance from public.refunds;
  end if;

  return jsonb_build_object(
    'generated_at',now(),'caller_role',v_role,
    'scope',jsonb_build_object('type',case when v_admin then 'global' else 'manager_territory' end,'agent_ids',case when v_admin then '[]'::jsonb else to_jsonb(v_agent_ids) end,'zone_count',case when v_admin then null else v_zone_count end),
    'activity',v_activity,'audit',v_audit,'audit_allowed',v_admin,'statistics',v_stats,
    'network_breakdown',v_networks,'agent_performance',v_agents,'admin_finance',v_admin_finance
  );
end;
$$;

revoke all on function public.izytel_bo6_control_snapshot() from public;
grant execute on function public.izytel_bo6_control_snapshot() to anon, authenticated;

comment on function public.izytel_bo6_control_snapshot() is
  'BO-6 read-only control/pilotage snapshot. Admin global + audit; Manager/supervisor territorial operational scope.';
