-- Complements BO-7.5B1a issue search with Agent name/code before pagination.
-- Migration deja appliquee en production Supabase. Ne pas la rejouer manuellement.

create or replace function public.izytel_bo75b1_agent_issues_page(
  p_start timestamptz default null,
  p_end timestamptz default null,
  p_scope text default 'all',
  p_network text default null,
  p_query text default null,
  p_sort text default 'recent',
  p_offset integer default 0,
  p_limit integer default 25
) returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_role text := private.izytel_current_staff_role();
  v_scope text := lower(btrim(coalesce(p_scope, 'all')));
  v_network text := nullif(lower(btrim(coalesce(p_network, ''))), '');
  v_query text := nullif(lower(btrim(coalesce(p_query, ''))), '');
  v_sort text := lower(btrim(coalesce(p_sort, 'recent')));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_limit integer := greatest(1, least(coalesce(p_limit, 25), 100));
  v_result jsonb;
begin
  if v_uid is null or not public.is_izytel_firebase_jwt() or v_role not in ('admin', 'manager', 'supervisor') then
    raise exception 'STAFF_REQUIRED';
  end if;

  with period_rows as (
    select i.*
    from public.agent_issues i
    where private.izytel_issue_agent_in_scope(i.agent_id)
      and (p_start is null or i.created_at >= p_start)
      and (p_end is null or i.created_at <= p_end)
  ),
  filtered as (
    select i.*
    from period_rows i
    where (v_scope = 'all' or lower(i.status) = v_scope)
      and (
        v_network is null
        or (v_network = '__none__' and nullif(btrim(coalesce(i.network, '')), '') is null)
        or lower(coalesce(i.network, '')) = v_network
      )
      and (
        v_query is null
        or lower(coalesce(i.agent_id, '')) like '%' || v_query || '%'
        or lower(coalesce(i.type, '')) like '%' || v_query || '%'
        or lower(coalesce(i.description, '')) like '%' || v_query || '%'
        or lower(coalesce(i.network, '')) like '%' || v_query || '%'
        or lower(coalesce(i.status, '')) like '%' || v_query || '%'
        or lower(coalesce(i.resolved_by, '')) like '%' || v_query || '%'
        or lower(coalesce(i.resolution_note, '')) like '%' || v_query || '%'
        or exists (
          select 1 from public.phase5_agent_capacities c
          where c.agent_id = i.agent_id
            and lower(coalesce(c.agent_name, '') || ' ' || coalesce(c.agent_code, '')) like '%' || v_query || '%'
        )
        or exists (
          select 1
          from public.agent_issue_events e
          where e.issue_id = i.id
            and lower(coalesce(e.actor_name, '') || ' ' || coalesce(e.note, '')) like '%' || v_query || '%'
        )
      )
  ),
  paged as (
    select i.*
    from filtered i
    order by
      case when v_sort = 'oldest' then i.created_at end asc,
      case when v_sort = 'updated' then coalesce(i.updated_at, i.created_at) end desc,
      case when v_sort not in ('oldest', 'updated') then i.created_at end desc,
      i.id desc
    offset v_offset limit v_limit
  )
  select jsonb_build_object(
    'generated_at', now(),
    'caller_role', v_role,
    'scope', jsonb_build_object('type', case when v_role = 'admin' then 'admin_global' else 'manager_territory' end),
    'total', (select count(*) from filtered),
    'summary', jsonb_build_object(
      'all', (select count(*) from period_rows),
      'open', (select count(*) from period_rows where status = 'open'),
      'in_progress', (select count(*) from period_rows where status = 'in_progress'),
      'resolved', (select count(*) from period_rows where status = 'resolved'),
      'cancelled', (select count(*) from period_rows where status = 'cancelled')
    ),
    'items', coalesce((
      select jsonb_agg(
        to_jsonb(p) || jsonb_build_object(
          'events', coalesce((
            select jsonb_agg(to_jsonb(e) order by e.occurred_at asc, e.id asc)
            from public.agent_issue_events e
            where e.issue_id = p.id
          ), '[]'::jsonb)
        )
        order by
          case when v_sort = 'oldest' then p.created_at end asc,
          case when v_sort = 'updated' then coalesce(p.updated_at, p.created_at) end desc,
          case when v_sort not in ('oldest', 'updated') then p.created_at end desc,
          p.id desc
      )
      from paged p
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$function$;
