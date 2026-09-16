-- BO-7.1 iteration 2 — série temporelle pour la datavisualisation.
-- Additif : ne remplace pas izytel_bo6_control_snapshot() déjà validé.
-- Admin : périmètre global. Manager/supervisor : uniquement ses Agents zonés.

create or replace function public.izytel_bo7_daily_trend(p_days integer default 30)
returns table(
  date date,
  orders bigint,
  completed bigint,
  failed bigint,
  completed_amount bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_role text := private.izytel_current_staff_role();
  v_is_admin boolean := false;
  v_days integer := greatest(1, least(coalesce(p_days, 30), 30));
  v_agent_ids text[] := array[]::text[];
begin
  if v_uid is null
     or not public.is_izytel_firebase_jwt()
     or v_role not in ('admin', 'manager', 'supervisor') then
    raise exception 'STAFF_REQUIRED';
  end if;

  v_is_admin := v_role = 'admin';

  if not v_is_admin then
    select coalesce(array_agg(distinct capacity.agent_id), array[]::text[])
      into v_agent_ids
    from public.phase5_agent_capacities capacity
    where exists (
      select 1
      from public.territory_zones zone
      where zone.manager_id = v_uid
        and zone.is_active = true
        and zone.id = any(coalesce(capacity.zone_ids, array[]::text[]))
    );
  end if;

  return query
  with days as (
    select generate_series(
      (now() at time zone 'Africa/Abidjan')::date - (v_days - 1),
      (now() at time zone 'Africa/Abidjan')::date,
      interval '1 day'
    )::date as day
  ),
  scoped_orders as (
    select o.*
    from public.phase4_assignment_orders o
    where v_is_admin or o.assigned_agent_id = any(v_agent_ids)
  ),
  created as (
    select
      (coalesce(o.firebase_created_at, o.created_at) at time zone 'Africa/Abidjan')::date as day,
      count(*)::bigint as value
    from scoped_orders o
    where coalesce(o.firebase_created_at, o.created_at) >=
      ((now() at time zone 'Africa/Abidjan')::date - (v_days - 1))::timestamp at time zone 'Africa/Abidjan'
    group by 1
  ),
  finished as (
    select
      (o.completed_at at time zone 'Africa/Abidjan')::date as day,
      count(*)::bigint as value,
      coalesce(sum(o.amount), 0)::bigint as amount
    from scoped_orders o
    where o.order_status = 'completed'
      and o.completed_at is not null
      and o.completed_at >=
        ((now() at time zone 'Africa/Abidjan')::date - (v_days - 1))::timestamp at time zone 'Africa/Abidjan'
    group by 1
  ),
  failures as (
    select
      (o.updated_at at time zone 'Africa/Abidjan')::date as day,
      count(*)::bigint as value
    from scoped_orders o
    where o.order_status = 'failed'
      and o.updated_at >=
        ((now() at time zone 'Africa/Abidjan')::date - (v_days - 1))::timestamp at time zone 'Africa/Abidjan'
    group by 1
  )
  select
    days.day as date,
    coalesce(created.value, 0)::bigint as orders,
    coalesce(finished.value, 0)::bigint as completed,
    coalesce(failures.value, 0)::bigint as failed,
    coalesce(finished.amount, 0)::bigint as completed_amount
  from days
  left join created on created.day = days.day
  left join finished on finished.day = days.day
  left join failures on failures.day = days.day
  order by days.day;
end;
$$;

revoke all on function public.izytel_bo7_daily_trend(integer) from public;
grant execute on function public.izytel_bo7_daily_trend(integer) to anon, authenticated;

comment on function public.izytel_bo7_daily_trend(integer) is
  'BO-7.1 daily operational trend (max 30 days). Admin global; Manager/supervisor territorial scope. No sensitive finance data.';
