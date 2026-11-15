-- One-off operator recovery explicitly authorized on 2026-11-06.
-- Run only after shared_queue_activate.sql, or in the same transaction.
-- Full table lock prevents clients observing the temporary trigger suspension.
-- Only these business references may change; all other order fields stay intact.
begin;
set local lock_timeout='5s';
set local statement_timeout='20s';
lock table public.phase4_assignment_orders in access exclusive mode;

do $publication$
declare
  v_refs text[] := array['CF-20261106-UCTYKO','CF-20261106-MEEBSO','CF-20261106-J4WWAB'];
  v_count integer;
  v_before jsonb;
  v_after jsonb;
  v_history_before jsonb;
  v_history_after jsonb;
begin
  if not coalesce((select enabled from private.izytel_shared_queue_settings where singleton),false) then
    raise exception 'SHARED_QUEUE_MUST_BE_ENABLED';
  end if;
  if (select count(distinct order_reference) from public.phase4_assignment_orders
      where order_reference=any(v_refs))<>3
     or (select count(*) from public.phase4_assignment_orders where order_reference=any(v_refs))<>3 then
    raise exception 'EXACTLY_THREE_EXPECTED_ORDERS_REQUIRED';
  end if;
  -- Safe retry after a successful commit, including a later legitimate acceptance.
  if not exists(select 1 from public.phase4_assignment_orders
      where order_reference=any(v_refs) and assignment_route<>'shared') then
    return;
  end if;
  if exists(select 1 from public.phase4_assignment_orders
    where order_reference=any(v_refs) and (
      assignment_route<>'legacy' or assignment_state<>'waiting'
      or order_status<>'paidReady' or payment_status<>'confirmed'
      or payment_confirmed_at is null or zone_id is null
      or assigned_agent_id is not null or assigned_cabiniste_id is not null
      or accepted_at is not null or assignment_version<>0 or legacy_state_unresolved
    )) then raise exception 'ORDER_STATE_CHANGED_RECHECK_BEFORE_PUBLICATION'; end if;
  if exists(select 1 from public.phase4_assignment_history h
    join public.phase4_assignment_orders o using(order_id)
    where o.order_reference=any(v_refs) and h.status in ('assigned','accepted','handed_off')) then
    raise exception 'EXISTING_ASSIGNMENT_HISTORY_REQUIRES_REVIEW';
  end if;
  if (select count(*) from pg_trigger
      where tgrelid='public.phase4_assignment_orders'::regclass
        and tgname in ('aaa_izytel_shared_order_guard','zzz_izytel_acceptance_lifecycle')
        and tgenabled='O')<>2 then
    raise exception 'EXPECTED_ENABLED_GUARDS_REQUIRED';
  end if;
  select jsonb_agg(to_jsonb(o)-array['assignment_route','available_at','updated_at'] order by o.order_reference)
    into v_before from public.phase4_assignment_orders o where order_reference=any(v_refs);
  select coalesce(jsonb_agg(to_jsonb(h) order by to_jsonb(h)::text),'[]'::jsonb)
    into v_history_before from public.phase4_assignment_history h
    join public.phase4_assignment_orders o using(order_id) where o.order_reference=any(v_refs);

  -- Route is intentionally immutable to normal callers. Suspend only these two
  -- guards inside the exclusive transaction; all other business/outbox hooks run.
  alter table public.phase4_assignment_orders disable trigger aaa_izytel_shared_order_guard;
  alter table public.phase4_assignment_orders disable trigger zzz_izytel_acceptance_lifecycle;
  update public.phase4_assignment_orders
    set assignment_route='shared',available_at=clock_timestamp(),updated_at=clock_timestamp()
    where order_reference=any(v_refs);
  get diagnostics v_count=row_count;
  alter table public.phase4_assignment_orders enable trigger zzz_izytel_acceptance_lifecycle;
  alter table public.phase4_assignment_orders enable trigger aaa_izytel_shared_order_guard;
  if v_count<>3 then raise exception 'PUBLICATION_COUNT_MISMATCH'; end if;

  select jsonb_agg(to_jsonb(o)-array['assignment_route','available_at','updated_at'] order by o.order_reference)
    into v_after from public.phase4_assignment_orders o where order_reference=any(v_refs);
  select coalesce(jsonb_agg(to_jsonb(h) order by to_jsonb(h)::text),'[]'::jsonb)
    into v_history_after from public.phase4_assignment_history h
    join public.phase4_assignment_orders o using(order_id) where o.order_reference=any(v_refs);
  if v_before is distinct from v_after or v_history_before is distinct from v_history_after then
    raise exception 'BUSINESS_DATA_OR_HISTORY_CHANGED_ROLLING_BACK';
  end if;
end;
$publication$;
commit;
