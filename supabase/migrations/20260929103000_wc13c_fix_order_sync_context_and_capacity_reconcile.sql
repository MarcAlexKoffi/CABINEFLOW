-- IzyTel WC13C
-- 1) phase3_sync_order doit pouvoir lire customer_order_contexts, table RPC-only.
-- 2) le rapprochement des capacites doit ecrire une valeur admise par la contrainte.

create or replace function public.phase3_sync_order(
  p_order_id text,
  p_order_reference text,
  p_network text,
  p_amount integer,
  p_firebase_created_at timestamptz,
  p_paid_at timestamptz,
  p_source text,
  p_client_name text,
  p_client_whatsapp_phone text,
  p_beneficiary_phone text,
  p_operation_type text,
  p_offer_label text,
  p_original_whatsapp_message text,
  p_internal_notes text,
  p_payment_status text,
  p_payment_payer_name text,
  p_payment_reference text,
  p_payment_confirmed_at timestamptz,
  p_customer_auth_uid text default null
)
returns public.phase4_assignment_orders
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_row public.phase4_assignment_orders;
  v_zone_id text;
  v_uid text := (select auth.jwt()->>'sub');
  v_role text;
begin
  if not private.is_izytel_phase4_staff() then
    raise exception 'STAFF_REQUIRED' using errcode = '42501';
  end if;

  if btrim(coalesce(p_order_id,''))=''
     or btrim(coalesce(p_order_reference,''))='' then
    raise exception 'INVALID_ORDER';
  end if;
  if p_network not in ('orange','mtn','moov') or p_amount<=0 then
    raise exception 'INVALID_ORDER';
  end if;
  if p_source not in ('customerWeb','operatorApp') then
    raise exception 'INVALID_SOURCE';
  end if;
  if p_operation_type not in (
    'internetSubscription','unitTransfer','callBundle','mixedBundle','other'
  ) then
    raise exception 'INVALID_OPERATION_TYPE';
  end if;
  if p_payment_status not in ('confirmed','credit') then
    raise exception 'INVALID_PAYMENT_STATUS';
  end if;

  select c.zone_id into v_zone_id
  from public.customer_order_contexts c
  where c.order_id=btrim(p_order_id)
    and upper(c.order_reference)=upper(btrim(p_order_reference))
  order by c.updated_at desc
  limit 1;

  v_zone_id := coalesce(v_zone_id, private.izytel_wc5_fallback_zone_id());

  select private.izytel_current_staff_role() into v_role;
  if v_role in ('manager','supervisor')
     and not private.izytel_wc5_manager_owns_zone(v_zone_id, v_uid) then
    raise exception 'MANAGER_ZONE_REQUIRED' using errcode = '42501';
  end if;

  insert into public.phase4_assignment_orders(
    order_id,order_reference,network,amount,firebase_created_at,paid_at,
    source,customer_auth_uid,client_name,client_whatsapp_phone,beneficiary_phone,
    operation_type,offer_label,original_whatsapp_message,internal_notes,
    payment_status,payment_payer_name,payment_reference,payment_confirmed_at,
    zone_id,assignment_state,order_status,legacy_state_unresolved
  ) values (
    btrim(p_order_id),btrim(p_order_reference),p_network,p_amount,
    p_firebase_created_at,p_paid_at,p_source,
    nullif(btrim(coalesce(p_customer_auth_uid,'')),''),
    coalesce(nullif(btrim(p_client_name),''),'Client'),'',
    btrim(coalesce(p_beneficiary_phone,'')),p_operation_type,
    coalesce(nullif(btrim(p_offer_label),''),'Offre non renseignee'),
    null,nullif(btrim(coalesce(p_internal_notes,'')),''),
    p_payment_status,nullif(btrim(coalesce(p_payment_payer_name,'')),''),
    nullif(btrim(coalesce(p_payment_reference,'')),''),
    p_payment_confirmed_at,v_zone_id,'waiting','paidReady',false
  )
  on conflict(order_id) do update set
    order_reference=excluded.order_reference,
    network=excluded.network,
    amount=excluded.amount,
    firebase_created_at=excluded.firebase_created_at,
    paid_at=excluded.paid_at,
    source=excluded.source,
    customer_auth_uid=coalesce(
      public.phase4_assignment_orders.customer_auth_uid,
      excluded.customer_auth_uid
    ),
    client_name=excluded.client_name,
    client_whatsapp_phone='',
    beneficiary_phone=excluded.beneficiary_phone,
    operation_type=excluded.operation_type,
    offer_label=excluded.offer_label,
    original_whatsapp_message=null,
    internal_notes=excluded.internal_notes,
    payment_status=excluded.payment_status,
    payment_payer_name=excluded.payment_payer_name,
    payment_reference=excluded.payment_reference,
    payment_confirmed_at=excluded.payment_confirmed_at,
    zone_id=excluded.zone_id,
    legacy_state_unresolved=public.phase4_assignment_orders.legacy_state_unresolved,
    updated_at=now()
  returning * into v_row;

  insert into public.phase4_assignment_plans(order_id)
  values(v_row.order_id)
  on conflict(order_id) do nothing;

  return v_row;
end;
$function$;

revoke all on function public.phase3_sync_order(
  text,text,text,integer,timestamptz,timestamptz,text,text,text,text,text,text,
  text,text,text,text,text,timestamptz,text
) from public;
grant execute on function public.phase3_sync_order(
  text,text,text,integer,timestamptz,timestamptz,text,text,text,text,text,text,
  text,text,text,text,text,timestamptz,text
) to anon, authenticated;

create or replace function private.phase5_reconcile_capacity_snapshot(p_row jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_agent_id text := btrim(coalesce(p_row->>'agent_id',''));
  v_agent_name text := btrim(coalesce(p_row->>'agent_name','Agent'));
  v_orange bigint := coalesce((p_row->>'orange_capacity')::bigint,0);
  v_mtn bigint := coalesce((p_row->>'mtn_capacity')::bigint,0);
  v_moov bigint := coalesce((p_row->>'moov_capacity')::bigint,0);
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
  end if;
  if v_agent_id='' or v_orange not between 0 and 100000000
     or v_mtn not between 0 and 100000000
     or v_moov not between 0 and 100000000 then
    raise exception 'INVALID_CAPACITY_SNAPSHOT';
  end if;

  insert into public.phase5_agent_capacities(
    agent_id,agent_name,orange_capacity,mtn_capacity,moov_capacity,
    initialized_from,legacy_seeded_at,created_at,updated_at
  ) values (
    v_agent_id,v_agent_name,v_orange,v_mtn,v_moov,
    'legacy_firestore',now(),now(),now()
  )
  on conflict(agent_id) do update set
    agent_name=excluded.agent_name,
    orange_capacity=excluded.orange_capacity,
    mtn_capacity=excluded.mtn_capacity,
    moov_capacity=excluded.moov_capacity,
    initialized_from='legacy_firestore',
    legacy_seeded_at=coalesce(public.phase5_agent_capacities.legacy_seeded_at,now()),
    updated_at=now();
end;
$function$;
