-- Exact territorial total and bounded keyset pages, without exposing recipients.
create or replace function private.izytel_shared_available_page(
  p_limit integer default 100,
  p_after_available_at timestamptz default null,
  p_after_order_id text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_enabled boolean;
  v_limit integer := greatest(1,least(coalesce(p_limit,100),100));
  v_total bigint;
  v_orders jsonb;
  v_more boolean;
  v_last jsonb;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode='42501';
  end if;
  if not exists(select 1 from public.phase5_agent_capacities where agent_id=v_uid and is_active) then
    raise exception 'ACTIVE_AGENT_REQUIRED' using errcode='42501';
  end if;
  if (p_after_available_at is null) <> (p_after_order_id is null) then
    raise exception 'INVALID_QUEUE_CURSOR' using errcode='22023';
  end if;
  select enabled into v_enabled from private.izytel_shared_queue_settings where singleton;
  with eligible as materialized (
    select o.* from public.phase4_assignment_orders o
    join public.phase5_agent_capacities a on a.agent_id=v_uid
    where v_enabled and private.izytel_shared_agent_zone(o.zone_id)
      and o.network=any(a.authorized_networks)
      and o.assignment_route='shared' and o.assignment_state='waiting'
      and o.assigned_agent_id is null and o.assigned_cabiniste_id is null
      and o.payment_status='confirmed' and o.order_status='paidReady' and not o.legacy_state_unresolved
  ), page as materialized (
    select * from eligible o
    where p_after_available_at is null or (o.available_at,o.order_id) > (p_after_available_at,p_after_order_id)
    order by o.available_at,o.order_id limit v_limit+1
  ), payloads as (
    select o.available_at,o.order_id,jsonb_build_object(
      'order_id',o.order_id,'order_reference',o.order_reference,'zone_id',o.zone_id,
      'network',o.network,'operation_type',o.operation_type,'offer_label',o.offer_label,
      'amount',o.amount,'available_at',o.available_at,
      'beneficiary_masked',case when length(regexp_replace(o.beneficiary_phone,'[^0-9]','','g'))>=4
        then '•• •• •• '||right(regexp_replace(o.beneficiary_phone,'[^0-9]','','g'),4) else '••••' end,
      'assignment_version',o.assignment_version,
      'can_accept',private.phase3_agent_is_eligible(v_uid,o.order_id)
    ) payload from page o order by o.available_at,o.order_id limit v_limit
  ) select (select count(*) from eligible),
    coalesce((select jsonb_agg(payload order by available_at,order_id) from payloads),'[]'::jsonb),
    (select count(*)>v_limit from page) into v_total,v_orders,v_more;
  v_last := v_orders->(jsonb_array_length(v_orders)-1);
  return jsonb_build_object('enabled',v_enabled,'server_now',clock_timestamp(),
    'orders',v_orders,'total_count',v_total,'next_cursor',case when v_more then
      jsonb_build_object('available_at',v_last->'available_at','order_id',v_last->'order_id') else null end);
end $$;

create or replace function public.izytel_shared_available_page(
  p_limit integer default 100,
  p_after_available_at timestamptz default null,
  p_after_order_id text default null
) returns jsonb language sql set search_path='' as $$
  select private.izytel_shared_available_page(p_limit,p_after_available_at,p_after_order_id);
$$;

-- Older builds retain their original bounded first page.
create or replace function private.izytel_shared_available(p_limit integer default 100)
returns jsonb language sql security definer set search_path='' as $$
  select private.izytel_shared_available_page(p_limit,null,null);
$$;

revoke all on function private.izytel_shared_available_page(integer,timestamptz,text),
  public.izytel_shared_available_page(integer,timestamptz,text) from public;
grant execute on function private.izytel_shared_available_page(integer,timestamptz,text),
  public.izytel_shared_available_page(integer,timestamptz,text) to anon,authenticated;
notify pgrst,'reload schema';
