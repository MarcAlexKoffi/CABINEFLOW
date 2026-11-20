-- Restore the previous first-page reader. New clients require the paginated RPC.
begin;
CREATE OR REPLACE FUNCTION private.izytel_shared_available(p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$

drop function public.izytel_shared_available_page(integer,timestamptz,text);
drop function private.izytel_shared_available_page(integer,timestamptz,text);
notify pgrst,'reload schema';
commit;
