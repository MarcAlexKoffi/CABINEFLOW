-- BO-7.5B1a - pagination serveur des centres Clients et Signalements.
-- Migration deja appliquee en production Supabase. Ne pas la rejouer manuellement.

create or replace function public.izytel_bo75b1_support_page(
  p_start timestamptz default null,
  p_end timestamptz default null,
  p_scope text default 'all',
  p_query text default null,
  p_offset integer default 0,
  p_limit integer default 25
) returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_scope text := lower(btrim(coalesce(p_scope, 'all')));
  v_query text := nullif(lower(btrim(coalesce(p_query, ''))), '');
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_limit integer := greatest(1, least(coalesce(p_limit, 25), 100));
  v_result jsonb;
begin
  if not public.is_izytel_firebase_jwt() or not private.is_izytel_finance_staff() then
    raise exception 'STAFF_REQUIRED';
  end if;

  with period_rows as (
    select s.*
    from public.support_requests s
    where (p_start is null or s.created_at >= p_start)
      and (p_end is null or s.created_at <= p_end)
  ),
  filtered as (
    select s.*
    from period_rows s
    where (
      v_scope = 'all'
      or (v_scope = 'new' and s.status = 'new')
      or (v_scope = 'in_progress' and s.status = 'inProgress')
      or (v_scope = 'resolved' and s.status in ('resolved', 'closed'))
    )
    and (
      v_query is null
      or lower(coalesce(s.order_reference, '')) like '%' || v_query || '%'
      or lower(coalesce(s.type, '')) like '%' || v_query || '%'
      or lower(coalesce(s.description, '')) like '%' || v_query || '%'
      or lower(coalesce(s.status, '')) like '%' || v_query || '%'
      or lower(coalesce(s.assigned_to_name, '')) like '%' || v_query || '%'
      or lower(coalesce(s.resolved_by_name, '')) like '%' || v_query || '%'
    )
  ),
  paged as (
    select s.*
    from filtered s
    order by s.updated_at desc, s.id desc
    offset v_offset limit v_limit
  )
  select jsonb_build_object(
    'total', (select count(*) from filtered),
    'summary', jsonb_build_object(
      'all', (select count(*) from period_rows),
      'new', (select count(*) from period_rows where status = 'new'),
      'in_progress', (select count(*) from period_rows where status = 'inProgress'),
      'resolved', (select count(*) from period_rows where status in ('resolved', 'closed'))
    ),
    'items', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'request', to_jsonb(p),
          'refund', (
            select to_jsonb(r)
            from public.refunds r
            where r.support_request_id = p.id or r.order_id = p.order_id
            order by case when r.support_request_id = p.id then 0 else 1 end,
                     r.requested_at desc
            limit 1
          )
        )
        order by p.updated_at desc, p.id desc
      )
      from paged p
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$function$;

create or replace function public.izytel_bo75b1_refunds_page(
  p_start timestamptz default null,
  p_end timestamptz default null,
  p_scope text default 'all',
  p_query text default null,
  p_offset integer default 0,
  p_limit integer default 25
) returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_scope text := lower(btrim(coalesce(p_scope, 'all')));
  v_query text := nullif(lower(btrim(coalesce(p_query, ''))), '');
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_limit integer := greatest(1, least(coalesce(p_limit, 25), 100));
  v_result jsonb;
begin
  if not public.is_izytel_firebase_jwt() or not private.is_izytel_finance_staff() then
    raise exception 'STAFF_REQUIRED';
  end if;

  with period_rows as (
    select r.*
    from public.refunds r
    where (p_start is null or r.requested_at >= p_start)
      and (p_end is null or r.requested_at <= p_end)
  ),
  filtered as (
    select r.*
    from period_rows r
    where (
      v_scope = 'all'
      or (v_scope = 'pending' and r.status = 'pendingApproval')
      or (v_scope = 'approved' and r.status = 'approved')
      or (v_scope = 'refunded' and r.status = 'refunded')
      or (v_scope = 'reconciled' and r.status = 'reconciled')
      or (v_scope = 'rejected' and r.status = 'rejected')
    )
    and (
      v_query is null
      or lower(coalesce(r.order_reference, '')) like '%' || v_query || '%'
      or lower(coalesce(r.client_name, '')) like '%' || v_query || '%'
      or lower(coalesce(r.client_whatsapp_phone, '')) like '%' || v_query || '%'
      or lower(coalesce(r.reason, '')) like '%' || v_query || '%'
      or lower(coalesce(r.status, '')) like '%' || v_query || '%'
      or lower(coalesce(r.refund_reference, '')) like '%' || v_query || '%'
    )
  ),
  paged as (
    select r.*
    from filtered r
    order by r.updated_at desc, r.order_id desc
    offset v_offset limit v_limit
  )
  select jsonb_build_object(
    'total', (select count(*) from filtered),
    'summary', jsonb_build_object(
      'pending', (select count(*) from period_rows where status = 'pendingApproval'),
      'approved', (select count(*) from period_rows where status = 'approved'),
      'completed', (select count(*) from period_rows where status in ('refunded', 'reconciled')),
      'exposure', coalesce((select sum(amount) from period_rows where status in ('pendingApproval', 'approved')), 0)
    ),
    'items', coalesce((select jsonb_agg(to_jsonb(p) order by p.updated_at desc, p.order_id desc) from paged p), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$function$;

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

revoke all on function public.izytel_bo75b1_support_page(timestamptz,timestamptz,text,text,integer,integer) from public;
revoke all on function public.izytel_bo75b1_refunds_page(timestamptz,timestamptz,text,text,integer,integer) from public;
revoke all on function public.izytel_bo75b1_agent_issues_page(timestamptz,timestamptz,text,text,text,text,integer,integer) from public;
grant execute on function public.izytel_bo75b1_support_page(timestamptz,timestamptz,text,text,integer,integer) to anon, authenticated;
grant execute on function public.izytel_bo75b1_refunds_page(timestamptz,timestamptz,text,text,integer,integer) to anon, authenticated;
grant execute on function public.izytel_bo75b1_agent_issues_page(timestamptz,timestamptz,text,text,text,text,integer,integer) to anon, authenticated;
