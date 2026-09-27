-- BO-5 - durcissement final d'integrite financiere.
-- La base reste l'autorite pour les clotures et le rapprochement distingue le legacy pre-Phase 4.

create or replace function public.izytel_finance_snapshot()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare v_result jsonb;
begin
  if not private.is_izytel_finance_staff() then
    raise exception 'STAFF_REQUIRED' using errcode='42501';
  end if;
  select jsonb_build_object(
    'generated_at', now(),
    'wave_opening', (select to_jsonb(x) from (select * from public.finance_wave_settings where id=1) x),
    'wave_adjustments', coalesce((select jsonb_agg(to_jsonb(x) order by effective_at desc) from (select * from public.finance_wave_balance_adjustments order by effective_at desc limit 100) x), '[]'::jsonb),
    'credits', coalesce((select jsonb_agg(to_jsonb(x) order by updated_at desc) from (select * from public.finance_customer_credits order by updated_at desc limit 500) x), '[]'::jsonb),
    'credit_settlements', coalesce((select jsonb_agg(to_jsonb(x) order by paid_at desc) from (select * from public.finance_customer_credit_settlements order by paid_at desc limit 500) x), '[]'::jsonb),
    'expenses', coalesce((select jsonb_agg(to_jsonb(x) order by spent_at desc) from (select * from public.finance_expenses order by spent_at desc limit 500) x), '[]'::jsonb),
    'closings', coalesce((select jsonb_agg(to_jsonb(x) order by closed_at desc) from (select * from public.finance_daily_closings order by closed_at desc limit 120) x), '[]'::jsonb),
    'suppliers', coalesce((select jsonb_agg(to_jsonb(x) order by name) from (select * from public.finance_suppliers where coalesce(is_deleted,false)=false order by name) x), '[]'::jsonb),
    'supplier_accounts', coalesce((select jsonb_agg(to_jsonb(x) order by supplier_name) from (select * from public.phase5_supplier_accounts order by supplier_name) x), '[]'::jsonb),
    'supplier_recharges', coalesce((select jsonb_agg(to_jsonb(x) order by occurred_at desc) from (select * from public.phase5_agent_recharges order by occurred_at desc limit 500) x), '[]'::jsonb),
    'supplier_payments', coalesce((select jsonb_agg(to_jsonb(x) order by paid_at desc) from (select * from public.phase5_supplier_payments order by paid_at desc limit 500) x), '[]'::jsonb),
    'commission_accounts', coalesce((select jsonb_agg(to_jsonb(x) order by agent_name) from (select * from public.phase5_commission_accounts order by agent_name) x), '[]'::jsonb),
    'commissions', coalesce((select jsonb_agg(to_jsonb(x) order by earned_at desc) from (select * from public.phase5_commissions order by earned_at desc limit 500) x), '[]'::jsonb),
    'commission_payouts', coalesce((select jsonb_agg(to_jsonb(x) order by paid_at desc) from (select * from public.phase5_commission_payouts order by paid_at desc limit 500) x), '[]'::jsonb),
    'agent_capacities', coalesce((select jsonb_agg(to_jsonb(x) order by agent_name) from (select * from public.phase5_agent_capacities order by agent_name) x), '[]'::jsonb),
    'network_movements', coalesce((select jsonb_agg(to_jsonb(x) order by occurred_at desc) from (select * from public.phase5_network_movements order by occurred_at desc limit 600) x), '[]'::jsonb),
    'order_payments', coalesce((select jsonb_agg(to_jsonb(x) order by coalesce(confirmed_at,paid_at,updated_at) desc) from (select * from public.phase5_order_payments order by coalesce(confirmed_at,paid_at,updated_at) desc limit 700) x), '[]'::jsonb),
    'refunds', coalesce((select jsonb_agg(to_jsonb(x) order by updated_at desc) from (select * from public.refunds order by updated_at desc limit 500) x), '[]'::jsonb),
    'orders', coalesce((select jsonb_agg(to_jsonb(x) order by updated_at desc) from (
      select order_id,order_reference,network,amount,source,client_name,client_whatsapp_phone,beneficiary_phone,
             operation_type,offer_label,payment_status,payment_reference,payment_confirmed_at,paid_at,order_status,
             assigned_agent_id,assigned_agent_name,processing_started_at,completed_at,failure_reason,
             firebase_created_at,created_at,updated_at
      from public.phase4_assignment_orders order by updated_at desc limit 1000
    ) x), '[]'::jsonb),
    'success_finalizations', coalesce((select jsonb_agg(to_jsonb(x) order by financial_applied_at desc) from (select * from public.phase5_success_finalizations order by financial_applied_at desc limit 700) x), '[]'::jsonb),
    'ledger_events', coalesce((select jsonb_agg(to_jsonb(x) order by occurred_at desc) from (select * from public.phase5_ledger_events order by occurred_at desc limit 800) x), '[]'::jsonb),
    'audit_events', coalesce((select jsonb_agg(to_jsonb(x) order by created_at desc) from (select * from public.finance_audit_events order by created_at desc limit 300) x), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$function$;

create or replace function public.izytel_finance_create_closing(p_payload jsonb)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_finance_actor_name();
  v_key text := btrim(coalesce(p_payload->>'date_key',''));
  v_day date;
  v_today date := (now() at time zone 'Africa/Abidjan')::date;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_as_of timestamptz;
  v_actual bigint := coalesce((p_payload->>'wave_actual_balance')::bigint,0);
  v_note text := btrim(coalesce(p_payload->>'wave_difference_note',''));
  v_opening bigint;
  v_opening_at timestamptz;
  v_client_receipts bigint := 0;
  v_successful_orders_count integer := 0;
  v_successful_orders_amount bigint := 0;
  v_supplier_recharge_principal bigint := 0;
  v_supplier_recharge_bonus bigint := 0;
  v_supplier_recharge_received bigint := 0;
  v_supplier_payments bigint := 0;
  v_credits_created bigint := 0;
  v_credit_settlements bigint := 0;
  v_customer_receivables bigint := 0;
  v_expenses bigint := 0;
  v_refunds bigint := 0;
  v_commissions_earned bigint := 0;
  v_commissions_paid bigint := 0;
  v_orange_available bigint := 0;
  v_orange_committed bigint := 0;
  v_mtn_available bigint := 0;
  v_mtn_committed bigint := 0;
  v_moov_available bigint := 0;
  v_moov_committed bigint := 0;
  v_supplier_debt bigint := 0;
  v_commission_debt bigint := 0;
  v_wave_client bigint := 0;
  v_wave_credit bigint := 0;
  v_wave_supplier bigint := 0;
  v_wave_expenses bigint := 0;
  v_wave_refunds bigint := 0;
  v_wave_commissions bigint := 0;
  v_theoretical bigint := 0;
  v_profit_refunds bigint := 0;
  v_estimated_network_cost bigint := 0;
  v_estimated_profit bigint := 0;
  v_canonical jsonb;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
  end if;
  if v_key !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'INVALID_DATE_KEY'; end if;
  begin v_day := v_key::date; exception when others then raise exception 'INVALID_DATE_KEY'; end;
  if v_day <> v_today then raise exception 'CLOSING_DATE_MUST_BE_TODAY'; end if;

  v_day_start := v_day::timestamp at time zone 'Africa/Abidjan';
  v_day_end := (v_day + 1)::timestamp at time zone 'Africa/Abidjan';
  v_as_of := least(now(), v_day_end);

  select opening_balance,effective_at into v_opening,v_opening_at
  from public.finance_wave_settings where id=1 for share;
  if not found then raise exception 'WAVE_OPENING_REQUIRED'; end if;
  if v_opening_at >= v_as_of then raise exception 'WAVE_OPENING_AFTER_CLOSING_DATE'; end if;
  if v_actual < 0 then raise exception 'INVALID_WAVE_BALANCE'; end if;

  select coalesce(sum(o.amount),0)::bigint into v_client_receipts
  from public.phase4_assignment_orders o
  where o.payment_status='confirmed'
    and coalesce(o.payment_confirmed_at,o.paid_at) >= v_day_start
    and coalesce(o.payment_confirmed_at,o.paid_at) < v_day_end;

  select count(*)::integer,coalesce(sum(m.amount),0)::bigint
  into v_successful_orders_count,v_successful_orders_amount
  from public.phase5_network_movements m
  where m.direction='outgoing' and m.movement_type='orderSuccess'
    and m.occurred_at >= v_day_start and m.occurred_at < v_day_end;

  select coalesce(sum(r.principal_amount),0)::bigint,
         coalesce(sum(r.bonus_amount),0)::bigint,
         coalesce(sum(r.received_amount),0)::bigint
  into v_supplier_recharge_principal,v_supplier_recharge_bonus,v_supplier_recharge_received
  from public.phase5_agent_recharges r
  where r.occurred_at >= v_day_start and r.occurred_at < v_day_end;

  select coalesce(sum(p.amount),0)::bigint into v_supplier_payments
  from public.phase5_supplier_payments p where p.paid_at >= v_day_start and p.paid_at < v_day_end;
  select coalesce(sum(c.amount),0)::bigint into v_credits_created
  from public.finance_customer_credits c where c.created_at >= v_day_start and c.created_at < v_day_end;
  select coalesce(sum(s.amount),0)::bigint into v_credit_settlements
  from public.finance_customer_credit_settlements s where s.paid_at >= v_day_start and s.paid_at < v_day_end;
  select coalesce(sum(greatest(c.amount-c.paid_amount,0)),0)::bigint into v_customer_receivables
  from public.finance_customer_credits c;
  select coalesce(sum(e.amount),0)::bigint into v_expenses
  from public.finance_expenses e where e.spent_at >= v_day_start and e.spent_at < v_day_end;
  select coalesce(sum(r.amount),0)::bigint into v_refunds
  from public.refunds r where r.refunded_at >= v_day_start and r.refunded_at < v_day_end;
  select coalesce(sum(c.commission_amount),0)::bigint into v_commissions_earned
  from public.phase5_commissions c where c.earned_at >= v_day_start and c.earned_at < v_day_end;
  select coalesce(sum(p.amount),0)::bigint into v_commissions_paid
  from public.phase5_commission_payouts p where p.paid_at >= v_day_start and p.paid_at < v_day_end;

  select coalesce(sum(c.orange_capacity),0)::bigint,
         coalesce(sum(c.mtn_capacity),0)::bigint,
         coalesce(sum(c.moov_capacity),0)::bigint
  into v_orange_available,v_mtn_available,v_moov_available
  from public.phase5_agent_capacities c;

  select coalesce(sum(case when o.network='orange' then o.amount else 0 end),0)::bigint,
         coalesce(sum(case when o.network='mtn' then o.amount else 0 end),0)::bigint,
         coalesce(sum(case when o.network='moov' then o.amount else 0 end),0)::bigint
  into v_orange_committed,v_mtn_committed,v_moov_committed
  from public.phase4_assignment_orders o
  where nullif(btrim(coalesce(o.assigned_agent_id,'')),'') is not null
    and o.payment_status in ('confirmed','credit')
    and o.order_status in ('paidReady','inProgress','onHold');

  select coalesce(sum(greatest(a.total_owed-a.total_paid,0)),0)::bigint into v_supplier_debt
  from public.phase5_supplier_accounts a;
  select coalesce(sum(greatest(a.earned_total-a.paid_total,0)),0)::bigint into v_commission_debt
  from public.phase5_commission_accounts a;

  select coalesce(sum(o.amount),0)::bigint into v_wave_client
  from public.phase4_assignment_orders o
  where o.payment_status='confirmed'
    and coalesce(o.payment_confirmed_at,o.paid_at) >= v_opening_at
    and coalesce(o.payment_confirmed_at,o.paid_at) < v_as_of;
  select coalesce(sum(s.amount),0)::bigint into v_wave_credit
  from public.finance_customer_credit_settlements s
  where s.payment_channel='wave' and s.paid_at >= v_opening_at and s.paid_at < v_as_of;
  select coalesce(sum(p.amount),0)::bigint into v_wave_supplier
  from public.phase5_supplier_payments p
  where p.payment_channel='wave' and p.paid_at >= v_opening_at and p.paid_at < v_as_of;
  select coalesce(sum(e.amount),0)::bigint into v_wave_expenses
  from public.finance_expenses e
  where e.payment_channel='wave' and e.spent_at >= v_opening_at and e.spent_at < v_as_of;
  select coalesce(sum(r.amount),0)::bigint into v_wave_refunds
  from public.refunds r
  where coalesce(nullif(btrim(r.payment_channel),''),'wave')='wave'
    and r.refunded_at >= v_opening_at and r.refunded_at < v_as_of;
  select coalesce(sum(p.amount),0)::bigint into v_wave_commissions
  from public.phase5_commission_payouts p
  where coalesce(nullif(btrim(p.payment_channel),''),'wave')='wave'
    and p.paid_at >= v_opening_at and p.paid_at < v_as_of;

  v_theoretical := v_opening + v_wave_client + v_wave_credit
    - v_wave_supplier - v_wave_expenses - v_wave_refunds - v_wave_commissions;
  if v_theoretical < 0 then raise exception 'INVALID_WAVE_BALANCE'; end if;
  if v_actual <> v_theoretical and char_length(v_note) < 3 then
    raise exception 'WAVE_DIFFERENCE_NOTE_REQUIRED';
  end if;

  with ratios as (
    select r.network,
      case when sum(r.received_amount) <= 0 then 1::numeric
           else least(1::numeric,greatest(0::numeric,sum(r.principal_amount)::numeric/sum(r.received_amount)::numeric)) end ratio
    from public.phase5_agent_recharges r
    where r.network in ('orange','mtn','moov') group by r.network
  ), day_successes as (
    select m.network,m.amount from public.phase5_network_movements m
    where m.direction='outgoing' and m.movement_type='orderSuccess'
      and m.occurred_at >= v_day_start and m.occurred_at < v_day_end
  )
  select coalesce(sum(round(s.amount * coalesce(r.ratio,1::numeric))),0)::bigint
  into v_estimated_network_cost
  from day_successes s left join ratios r on r.network=s.network;

  select coalesce(sum(r.amount),0)::bigint into v_profit_refunds
  from public.refunds r
  where r.refunded_at >= v_day_start and r.refunded_at < v_day_end
    and exists(select 1 from public.phase5_network_movements m
               where m.order_id=r.order_id and m.movement_type='orderSuccess');

  v_estimated_profit := v_successful_orders_amount - v_estimated_network_cost
    - v_commissions_earned - v_expenses - v_profit_refunds;

  v_canonical := jsonb_build_object(
    'date_key',v_key,'client_receipts',v_client_receipts,
    'successful_orders_count',v_successful_orders_count,'successful_orders_amount',v_successful_orders_amount,
    'supplier_recharge_principal',v_supplier_recharge_principal,'supplier_recharge_bonus',v_supplier_recharge_bonus,
    'supplier_recharge_received',v_supplier_recharge_received,'supplier_payments',v_supplier_payments,
    'credits_created',v_credits_created,'credit_settlements',v_credit_settlements,
    'customer_receivables',v_customer_receivables,'expenses',v_expenses,'refunds',v_refunds,
    'commissions_earned',v_commissions_earned,'commissions_paid',v_commissions_paid,
    'orange_available',v_orange_available,'orange_committed',v_orange_committed,
    'mtn_available',v_mtn_available,'mtn_committed',v_mtn_committed,
    'moov_available',v_moov_available,'moov_committed',v_moov_committed,
    'supplier_debt',v_supplier_debt,'commission_debt',v_commission_debt,
    'wave_theoretical_balance',v_theoretical,'wave_actual_balance',v_actual,
    'wave_difference',v_actual-v_theoretical,'wave_difference_note',nullif(v_note,''),
    'estimated_profit',v_estimated_profit
  );

  insert into public.finance_daily_closings(
    date_key,client_receipts,successful_orders_count,successful_orders_amount,
    supplier_recharge_principal,supplier_recharge_bonus,supplier_recharge_received,supplier_payments,
    credits_created,credit_settlements,customer_receivables,expenses,refunds,
    commissions_earned,commissions_paid,orange_available,orange_committed,mtn_available,mtn_committed,
    moov_available,moov_committed,supplier_debt,commission_debt,wave_theoretical_balance,wave_actual_balance,
    wave_difference,wave_difference_note,estimated_profit,closed_at,closed_by_uid,closed_by_name
  ) values(
    v_key,v_client_receipts,v_successful_orders_count,v_successful_orders_amount,
    v_supplier_recharge_principal,v_supplier_recharge_bonus,v_supplier_recharge_received,v_supplier_payments,
    v_credits_created,v_credit_settlements,v_customer_receivables,v_expenses,v_refunds,
    v_commissions_earned,v_commissions_paid,v_orange_available,v_orange_committed,v_mtn_available,v_mtn_committed,
    v_moov_available,v_moov_committed,v_supplier_debt,v_commission_debt,v_theoretical,v_actual,
    v_actual-v_theoretical,nullif(v_note,''),v_estimated_profit,now(),v_uid,v_name
  );

  insert into public.finance_audit_events(event_kind,entity_type,entity_id,actor_uid,actor_name,payload)
  values('daily_closing_created','closing',v_key,v_uid,v_name,
    jsonb_build_object('canonical',v_canonical,'client_request',p_payload));
  return v_key;
exception when unique_violation then raise exception 'CLOSING_ALREADY_EXISTS';
end;
$function$;

revoke all on function public.izytel_finance_snapshot() from public;
revoke all on function public.izytel_finance_create_closing(jsonb) from public;
grant execute on function public.izytel_finance_snapshot() to anon, authenticated;
grant execute on function public.izytel_finance_create_closing(jsonb) to anon, authenticated;
