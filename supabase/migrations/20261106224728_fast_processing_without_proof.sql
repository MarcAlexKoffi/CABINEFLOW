-- Fast processing: remove only the photo prerequisite; preserve ownership, state, capacity and finance.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
CREATE OR REPLACE FUNCTION private.phase5_finalize_order_success(p_order_id text, p_agent_name text, p_processing_started_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_order public.phase4_assignment_orders;
  v_capacity public.phase5_agent_capacities;
  v_existing public.phase5_success_finalizations;
  v_before bigint;
  v_after bigint;
  v_commission constant bigint := 10;
  v_agent_name text;
  v_now timestamptz := now();
  v_manager_id text;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode='42501';
  end if;

  select * into v_existing
  from public.phase5_success_finalizations
  where order_id=btrim(p_order_id);

  if found then
    if v_existing.agent_id<>v_uid then
      raise exception 'FINALIZATION_OWNER_MISMATCH' using errcode='42501';
    end if;
    return to_jsonb(v_existing)||jsonb_build_object('idempotent',true);
  end if;

  select * into v_order
  from public.phase4_assignment_orders
  where order_id=btrim(p_order_id)
  for update;

  if not found then
    raise exception 'PHASE4_ORDER_NOT_FOUND';
  end if;

  select * into v_existing
  from public.phase5_success_finalizations
  where order_id=v_order.order_id;

  if found then
    if v_existing.agent_id<>v_uid then
      raise exception 'FINALIZATION_OWNER_MISMATCH' using errcode='42501';
    end if;
    return to_jsonb(v_existing)||jsonb_build_object('idempotent',true);
  end if;

  if v_order.assignment_state not in ('accepted','handed_off') then
    raise exception 'ORDER_NOT_ACCEPTED';
  end if;
  if v_order.assigned_agent_id is distinct from v_uid then
    raise exception 'ORDER_NOT_ASSIGNED_TO_AGENT' using errcode='42501';
  end if;
  if v_order.order_status<>'inProgress' then
    raise exception 'ORDER_NOT_IN_PROGRESS';
  end if;
  if v_order.legacy_state_unresolved then
    raise exception 'LEGACY_STATUS_REQUIRES_RECONCILIATION';
  end if;
  -- Completion is explicitly confirmed by the assigned executor; no photo required.

  select * into v_capacity
  from public.phase5_agent_capacities
  where agent_id=v_uid
  for update;

  if not found then
    raise exception 'CAPACITY_NOT_INITIALIZED';
  end if;

  v_before:=case v_order.network
    when 'orange' then v_capacity.orange_capacity
    when 'mtn' then v_capacity.mtn_capacity
    else v_capacity.moov_capacity
  end;

  if v_before<v_order.amount then
    raise exception 'INSUFFICIENT_CAPACITY';
  end if;

  v_after:=v_before-v_order.amount;
  v_agent_name:=coalesce(
    nullif(btrim(v_order.assigned_agent_name),''),
    nullif(btrim(p_agent_name),''),
    v_capacity.agent_name
  );

  update public.phase5_agent_capacities
  set agent_name=v_agent_name,
      orange_capacity=case when v_order.network='orange' then v_after else orange_capacity end,
      mtn_capacity=case when v_order.network='mtn' then v_after else mtn_capacity end,
      moov_capacity=case when v_order.network='moov' then v_after else moov_capacity end,
      initialized_from='supabase',
      updated_at=v_now
  where agent_id=v_uid;

  insert into public.phase5_network_movements(
    source_key,network,direction,movement_type,amount,capacity_before,capacity_after,
    agent_id,agent_name,order_id,order_reference,created_by_uid,created_by_name,created_by_role,occurred_at
  ) values(
    'order:'||v_order.order_id,
    v_order.network,
    'outgoing',
    'orderSuccess',
    v_order.amount,
    v_before,
    v_after,
    v_uid,
    v_agent_name,
    v_order.order_id,
    v_order.order_reference,
    v_uid,
    v_agent_name,
    'agent',
    v_now
  ) on conflict(source_key) do nothing;

  insert into public.phase5_commissions(
    order_id,order_reference,agent_id,agent_name,network,order_amount,commission_amount,
    policy_id,policy_type,rate,processing_started_at,earned_at,updated_at
  ) values(
    v_order.order_id,
    v_order.order_reference,
    v_uid,
    v_agent_name,
    v_order.network,
    v_order.amount,
    v_commission,
    'fixed-10-v1',
    'fixedPerSuccessfulTransaction',
    v_commission,
    coalesce(p_processing_started_at,v_order.processing_started_at),
    v_now,
    v_now
  ) on conflict(order_id) do nothing;

  insert into public.phase5_commission_accounts(
    agent_id,agent_name,earned_total,paid_total,earned_transactions,
    last_commission_order_id,created_at,updated_at
  ) values(
    v_uid,v_agent_name,v_commission,0,1,v_order.order_id,v_now,v_now
  )
  on conflict(agent_id) do update
  set agent_name=excluded.agent_name,
      earned_total=public.phase5_commission_accounts.earned_total+v_commission,
      earned_transactions=public.phase5_commission_accounts.earned_transactions+1,
      last_commission_order_id=v_order.order_id,
      updated_at=v_now;

  insert into public.phase5_success_finalizations(
    order_id,order_reference,agent_id,agent_name,network,order_amount,
    capacity_before,capacity_after,commission_amount,financial_applied_at,created_at,updated_at
  ) values(
    v_order.order_id,
    v_order.order_reference,
    v_uid,
    v_agent_name,
    v_order.network,
    v_order.amount,
    v_before,
    v_after,
    v_commission,
    v_now,
    v_now,
    v_now
  );

  insert into public.phase5_ledger_events(
    source_collection,source_id,event_kind,agent_id,agent_name,
    order_id,order_reference,network,amount,occurred_at,payload
  ) values
  (
    'phase5_network_movements',
    'order:'||v_order.order_id,
    'capacity_movement',
    v_uid,
    v_agent_name,
    v_order.order_id,
    v_order.order_reference,
    v_order.network,
    v_order.amount,
    v_now,
    jsonb_build_object(
      'direction','outgoing',
      'type','orderSuccess',
      'capacityBefore',v_before,
      'capacityAfter',v_after
    )
  ),
  (
    'phase5_commissions',
    v_order.order_id,
    'commission_earned',
    v_uid,
    v_agent_name,
    v_order.order_id,
    v_order.order_reference,
    v_order.network,
    v_commission,
    v_now,
    jsonb_build_object(
      'policyId','fixed-10-v1',
      'orderAmount',v_order.amount
    )
  )
  on conflict do nothing;

  update public.phase4_assignment_orders
  set order_status='completed',
      completed_at=v_now,
      failure_reason=null,
      observation=null,
      customer_confirmation_status='pending',
      legacy_state_unresolved=false,
      updated_at=v_now
  where order_id=v_order.order_id;

  begin
    v_manager_id := private.izytel_resolve_manager_for_zone_ids(v_capacity.zone_ids);

    perform private.izytel_record_order_economics_observation(
      v_order.order_id,
      'izytel',
      'agent',
      v_uid,
      null,
      v_manager_id
    );
  exception when others then
    raise warning '[IzyTel Economics][observation] order=% error=%',
      v_order.order_id,
      sqlerrm;
  end;

  select * into v_existing
  from public.phase5_success_finalizations
  where order_id=v_order.order_id;

  return to_jsonb(v_existing)||jsonb_build_object('idempotent',false);
end;
$function$;

CREATE OR REPLACE FUNCTION private.phase5_finalize_partner_order_success_internal(p_order_id text, p_processing_started_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid text := nullif(
    btrim(coalesce((select auth.jwt()->>'sub'),'')),
    ''
  );
  v_partner public.partner_accounts;
  v_order public.phase4_assignment_orders;
  v_capacity public.partner_capacities;
  v_existing public.partner_success_finalizations;
  v_economics public.order_economics;
  v_before bigint;
  v_after bigint;
  v_now timestamptz := now();
  v_manager_id text;
begin
  if not public.is_izytel_firebase_jwt()
     or v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode='42501';
  end if;

  select * into v_partner
  from public.partner_accounts
  where firebase_uid=v_uid
    and status='active'
  limit 1;

  if not found then
    raise exception 'ACTIVE_PARTNER_REQUIRED' using errcode='42501';
  end if;

  select * into v_existing
  from public.partner_success_finalizations
  where order_id=btrim(p_order_id);

  if found then
    if v_existing.partner_id<>v_partner.id then
      raise exception 'FINALIZATION_OWNER_MISMATCH'
        using errcode='42501';
    end if;

    select * into v_economics
    from public.order_economics
    where order_id=v_existing.order_id;

    return to_jsonb(v_existing)
      || jsonb_build_object(
        'idempotent',true,
        'economics',to_jsonb(v_economics)
      );
  end if;

  select * into v_order
  from public.phase4_assignment_orders
  where order_id=btrim(p_order_id)
  for update;

  if not found then
    raise exception 'PHASE4_ORDER_NOT_FOUND';
  end if;

  if v_order.assigned_cabiniste_id
     is distinct from v_partner.id then
    raise exception 'ORDER_NOT_ASSIGNED_TO_CABINISTE'
      using errcode='42501';
  end if;

  if v_order.assignment_state not in ('accepted','handed_off') then
    raise exception 'ORDER_NOT_ACCEPTED';
  end if;

  if v_order.order_status<>'inProgress' then
    raise exception 'ORDER_NOT_IN_PROGRESS';
  end if;

  if v_order.legacy_state_unresolved then
    raise exception 'LEGACY_STATUS_REQUIRES_RECONCILIATION';
  end if;

  -- Completion is explicitly confirmed by the assigned executor; no photo required.

  select * into v_capacity
  from public.partner_capacities
  where partner_id=v_partner.id
  for update;

  if not found then
    raise exception 'CAPACITY_NOT_INITIALIZED';
  end if;

  v_before := case v_order.network
    when 'orange' then v_capacity.orange_capacity
    when 'mtn' then v_capacity.mtn_capacity
    else v_capacity.moov_capacity
  end;

  if v_before<v_order.amount then
    raise exception 'INSUFFICIENT_CAPACITY';
  end if;

  v_after := v_before-v_order.amount;

  update public.partner_capacities
  set orange_capacity=case
        when v_order.network='orange' then v_after
        else orange_capacity
      end,
      mtn_capacity=case
        when v_order.network='mtn' then v_after
        else mtn_capacity
      end,
      moov_capacity=case
        when v_order.network='moov' then v_after
        else moov_capacity
      end
  where partner_id=v_partner.id;

  insert into public.partner_capacity_movements(
    source_key,partner_id,partner_name,
    network,direction,movement_type,
    amount,capacity_before,capacity_after,
    order_id,order_reference,
    created_by_uid,occurred_at
  ) values(
    'order:'||v_order.order_id,
    v_partner.id,
    v_partner.display_name,
    v_order.network,
    'outgoing',
    'orderSuccess',
    v_order.amount,
    v_before,
    v_after,
    v_order.order_id,
    v_order.order_reference,
    v_uid,
    v_now
  )
  on conflict(source_key) do nothing;

  update public.phase4_assignment_orders
  set order_status='completed',
      completed_at=v_now,
      failure_reason=null,
      observation=null,
      customer_confirmation_status='pending',
      legacy_state_unresolved=false,
      updated_at=v_now
  where order_id=v_order.order_id;

  v_manager_id := private.izytel_resolve_manager_for_zone_ids(v_partner.zone_ids);

  perform private.izytel_record_order_economics_observation(
    v_order.order_id,
    'izytel',
    'cabiniste',
    v_partner.id::text,
    null,
    v_manager_id
  );

  select * into v_economics
  from public.order_economics
  where order_id=v_order.order_id;

  if not found then
    raise exception 'ORDER_ECONOMICS_NOT_CREATED';
  end if;

  insert into public.partner_success_finalizations(
    order_id,order_reference,partner_id,partner_name,
    network,order_amount,
    capacity_before,capacity_after,
    telecom_margin_amount,
    cabiniste_margin_amount,
    izytel_margin_amount,
    customer_fee_amount,
    cabiniste_settlement_amount,
    izytel_gross_gain,
    financial_applied_at
  ) values(
    v_order.order_id,
    v_order.order_reference,
    v_partner.id,
    v_partner.display_name,
    v_order.network,
    v_order.amount,
    v_before,
    v_after,
    v_economics.telecom_margin_amount,
    v_economics.cabiniste_margin_amount,
    v_economics.izytel_margin_amount,
    v_economics.customer_fee_amount,
    v_economics.cabiniste_settlement_amount,
    v_economics.izytel_gross_gain,
    v_now
  )
  returning * into v_existing;

  select * into v_economics
  from public.order_economics
  where order_id=v_order.order_id;

  update public.phase4_partner_assignment_history
  set status='completed',
      completed_at=v_now
  where id=(
    select h.id
    from public.phase4_partner_assignment_history h
    where h.order_id=v_order.order_id
      and h.partner_id=v_partner.id
      and h.status in ('accepted','in_progress','on_hold')
    order by h.assigned_at desc
    limit 1
  );

  return to_jsonb(v_existing)
    || jsonb_build_object(
      'idempotent',false,
      'economics',to_jsonb(v_economics),
      'processingStartedAt',
      coalesce(p_processing_started_at,v_order.processing_started_at)
    );
end;
$function$;

do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(
    select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='izytel_order_delay_alerts'
  ) then
    alter publication supabase_realtime add table public.izytel_order_delay_alerts;
  end if;
end;
$$;
NOTIFY pgrst, 'reload schema';
commit;
