-- Complements BO-7.5B1a refund summary counts.
-- Migration deja appliquee en production Supabase. Ne pas la rejouer manuellement.

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
      'all', (select count(*) from period_rows),
      'pending', (select count(*) from period_rows where status = 'pendingApproval'),
      'approved', (select count(*) from period_rows where status = 'approved'),
      'refunded', (select count(*) from period_rows where status = 'refunded'),
      'reconciled', (select count(*) from period_rows where status = 'reconciled'),
      'rejected', (select count(*) from period_rows where status = 'rejected'),
      'completed', (select count(*) from period_rows where status in ('refunded', 'reconciled')),
      'exposure', coalesce((select sum(amount) from period_rows where status in ('pendingApproval', 'approved')), 0)
    ),
    'items', coalesce((select jsonb_agg(to_jsonb(p) order by p.updated_at desc, p.order_id desc) from paged p), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$function$;
