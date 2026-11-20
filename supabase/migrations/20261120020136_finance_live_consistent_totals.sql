-- Consistent, exact BO totals. History windows remain bounded for display only.
-- No existing balance, payment, capacity or closing is modified.
-- Private helpers inherit the caller's statement snapshot; no client grants.
create or replace function private.izytel_finance_period_totals(p_start timestamptz,p_end timestamptz)
returns jsonb language sql stable set search_path='' as $function$
  select jsonb_build_object(
    'client_receipts',(select coalesce(sum(amount),0) from public.phase4_assignment_orders where coalesce(payment_confirmed_at,paid_at) >= p_start and coalesce(payment_confirmed_at,paid_at) < p_end and payment_status='confirmed'),
    'successful_orders_amount',(select coalesce(sum(amount),0) from public.phase5_network_movements where occurred_at >= p_start and occurred_at < p_end and direction='outgoing' and movement_type='orderSuccess'),
    'successful_orders_count',(select count(*) from public.phase5_network_movements where occurred_at >= p_start and occurred_at < p_end and direction='outgoing' and movement_type='orderSuccess'),
    'credit_settlements',(select coalesce(sum(amount),0) from public.finance_customer_credit_settlements where paid_at >= p_start and paid_at < p_end),
    'supplier_payments',(select coalesce(sum(amount),0) from public.phase5_supplier_payments where paid_at >= p_start and paid_at < p_end),
    'expenses',(select coalesce(sum(amount),0) from public.finance_expenses where spent_at >= p_start and spent_at < p_end),
    'expenses_count',(select count(*) from public.finance_expenses where spent_at >= p_start and spent_at < p_end),
    'expenses_wave',(select coalesce(sum(amount),0) from public.finance_expenses where spent_at >= p_start and spent_at < p_end and payment_channel='wave'),
    'refunds',(select coalesce(sum(amount),0) from public.refunds where refunded_at >= p_start and refunded_at < p_end),
    'commissions_earned',(select coalesce(sum(commission_amount),0) from public.phase5_commissions where earned_at >= p_start and earned_at < p_end),
    'commissions_paid',(select coalesce(sum(amount),0) from public.phase5_commission_payouts where paid_at >= p_start and paid_at < p_end),
    'supplier_recharge_principal',(select coalesce(sum(principal_amount),0) from public.phase5_agent_recharges where occurred_at >= p_start and occurred_at < p_end),
    'supplier_recharge_bonus',(select coalesce(sum(bonus_amount),0) from public.phase5_agent_recharges where occurred_at >= p_start and occurred_at < p_end),
    'supplier_recharge_received',(select coalesce(sum(received_amount),0) from public.phase5_agent_recharges where occurred_at >= p_start and occurred_at < p_end),
    'supplier_recharges_count',(select count(*) from public.phase5_agent_recharges where occurred_at >= p_start and occurred_at < p_end),
    'credits_created',(select coalesce(sum(amount),0) from public.finance_customer_credits where created_at >= p_start and created_at < p_end),
    'network_movements_count',(select count(*) from public.phase5_network_movements where occurred_at >= p_start and occurred_at < p_end),
    'supplier_payments_count',(select count(*) from public.phase5_supplier_payments where paid_at >= p_start and paid_at < p_end),
    'commission_payouts_count',(select count(*) from public.phase5_commission_payouts where paid_at >= p_start and paid_at < p_end),
    'credit_settlements_count',(select count(*) from public.finance_customer_credit_settlements where paid_at >= p_start and paid_at < p_end),
    'refunds_count',(select count(*) from public.refunds where refunded_at >= p_start and refunded_at < p_end),
    'wave_adjustments_count',(select count(*) from public.finance_wave_balance_adjustments where effective_at >= p_start and effective_at < p_end)
,
    'credit_settlements_by_channel',(select coalesce(jsonb_object_agg(channel,total),'{}'::jsonb) from (select coalesce(payment_channel,'') channel,sum(amount) total from public.finance_customer_credit_settlements where paid_at >= p_start and paid_at < p_end group by payment_channel) x),
    'supplier_payments_by_channel',(select coalesce(jsonb_object_agg(channel,total),'{}'::jsonb) from (select coalesce(payment_channel,'') channel,sum(amount) total from public.phase5_supplier_payments where paid_at >= p_start and paid_at < p_end group by payment_channel) x),
    'commissions_paid_by_channel',(select coalesce(jsonb_object_agg(channel,total),'{}'::jsonb) from (select coalesce(payment_channel,'') channel,sum(amount) total from public.phase5_commission_payouts where paid_at >= p_start and paid_at < p_end group by payment_channel) x),
    'estimated_profit',(
      with ratios as (
        select network,case when sum(received_amount)<=0 then 1::numeric
          else least(1::numeric,greatest(0::numeric,sum(principal_amount)::numeric/sum(received_amount))) end ratio
        from public.phase5_agent_recharges group by network
      ), successes as (
        select m.amount,coalesce(r.ratio,1::numeric) ratio
        from public.phase5_network_movements m left join ratios r using(network)
        where m.direction='outgoing' and m.movement_type='orderSuccess'
          and m.occurred_at>=p_start and m.occurred_at<p_end
      )
      select coalesce(sum(amount-round(amount*ratio)),0)
        -(select coalesce(sum(commission_amount),0) from public.phase5_commissions where earned_at>=p_start and earned_at<p_end)
        -(select coalesce(sum(amount),0) from public.finance_expenses where spent_at>=p_start and spent_at<p_end)
        -(select coalesce(sum(r.amount),0) from public.refunds r where r.refunded_at>=p_start and r.refunded_at<p_end
          and exists(select 1 from public.phase5_network_movements m where m.order_id=r.order_id and m.movement_type='orderSuccess'))
      from successes
    )
  );
$function$;
revoke all on function private.izytel_finance_period_totals(timestamptz,timestamptz) from public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.izytel_finance_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_result jsonb;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
  end if;
  select jsonb_build_object(
    'committed_capacities', (select coalesce(jsonb_object_agg(network,total),'{}'::jsonb) from (
      select lower(network) network,sum(amount) total from public.phase4_assignment_orders
      where payment_status in ('confirmed','credit') and order_status in ('paidReady','inProgress','onHold')
        and nullif(btrim(assigned_agent_id),'') is not null
      group by lower(network)
    ) committed),
    'wave_totals', jsonb_build_object(
      'client_payments', (select coalesce(sum(amount),0) from public.phase4_assignment_orders where payment_status='confirmed' and coalesce(payment_confirmed_at,paid_at) >= coalesce((select effective_at from public.finance_wave_settings where id=1), '-infinity'::timestamptz)),
      'credit_settlements', (select coalesce(sum(amount),0) from public.finance_customer_credit_settlements where payment_channel='wave' and paid_at >= coalesce((select effective_at from public.finance_wave_settings where id=1), '-infinity'::timestamptz)),
      'supplier_payments', (select coalesce(sum(amount),0) from public.phase5_supplier_payments where payment_channel='wave' and paid_at >= coalesce((select effective_at from public.finance_wave_settings where id=1), '-infinity'::timestamptz)),
      'expenses', (select coalesce(sum(amount),0) from public.finance_expenses where payment_channel='wave' and spent_at >= coalesce((select effective_at from public.finance_wave_settings where id=1), '-infinity'::timestamptz)),
      'refunds', (select coalesce(sum(amount),0) from public.refunds where coalesce(nullif(payment_channel,''),'wave')='wave' and refunded_at >= coalesce((select effective_at from public.finance_wave_settings where id=1), '-infinity'::timestamptz)),
      'cabiniste_payouts', (select coalesce(sum(amount),0) from public.compensation_payouts where actor_type='cabiniste' and currency='XOF' and lower(btrim(payment_channel))='wave' and paid_at >= coalesce((select effective_at from public.finance_wave_settings where id=1), '-infinity'::timestamptz)),
      'commission_payouts', (select coalesce(sum(amount),0) from public.phase5_commission_payouts where coalesce(nullif(payment_channel,''),'wave')='wave' and paid_at >= coalesce((select effective_at from public.finance_wave_settings where id=1), '-infinity'::timestamptz))
    ),
    'generated_at', now(),
    'revision',(select revision from public.finance_change_feed where id=1),
    'cabiniste_finance',private.izytel_admin_cabiniste_finance_snapshot(null),
    'day_totals',private.izytel_finance_period_totals(
      date_trunc('day',now() at time zone 'Africa/Abidjan') at time zone 'Africa/Abidjan',
      (date_trunc('day',now() at time zone 'Africa/Abidjan') + interval '1 day') at time zone 'Africa/Abidjan'
    ) || jsonb_build_object('date_key',to_char(now() at time zone 'Africa/Abidjan','YYYY-MM-DD')),
    'global_totals',jsonb_build_object(
      'customer_receivables',(select coalesce(sum(greatest(amount-paid_amount,0)),0) from public.finance_customer_credits),
      'credits_granted',(select coalesce(sum(amount),0) from public.finance_customer_credits),
      'credits_paid',(select coalesce(sum(paid_amount),0) from public.finance_customer_credits),
      'credits_count',(select count(*) from public.finance_customer_credits),
      'credits_open_count',(select count(*) from public.finance_customer_credits where status<>'settled'),
      'supplier_recharges_count',(select count(*) from public.phase5_agent_recharges),
      'network_movements_count',(select count(*) from public.phase5_network_movements),
      'ledger_events_count',(select count(*) from public.phase5_ledger_events),
      'order_payments_count',(select count(*) from public.phase5_order_payments),
      'refunds_count',(select count(*) from public.refunds)
    ),
    'reconciliation_totals',jsonb_build_object(
      'legacy_payments',(select count(*) from public.phase5_order_payments p where not exists(select 1 from public.phase4_assignment_orders o where o.order_id=p.order_id)
        and p.created_at < (select min(created_at) from public.phase4_assignment_orders)),
      'orphan_payments',(select count(*) from public.phase5_order_payments p where not exists(select 1 from public.phase4_assignment_orders o where o.order_id=p.order_id)
        and not coalesce(p.created_at < (select min(created_at) from public.phase4_assignment_orders),false)),
      'confirmed_without_ledger',(select count(*) from public.phase4_assignment_orders o where payment_status='confirmed' and not exists(select 1 from public.phase5_order_payments p where p.order_id=o.order_id)),
      'credit_mismatch',(select count(*) from public.finance_customer_credits c left join public.phase4_assignment_orders o using(order_id)
        where o.order_id is null or o.payment_status<>'credit' or o.amount<>c.amount or upper(o.order_reference)<>upper(c.order_reference)),
      'legacy_refunds',(select count(*) from public.refunds r where r.status in('refunded','reconciled') and nullif(r.legacy_firestore_id,'') is not null
        and not exists(select 1 from public.phase4_assignment_orders o where o.order_id=r.order_id)),
      'refund_mismatch',(select count(*) from public.refunds r left join public.phase4_assignment_orders o using(order_id)
        where r.status in('refunded','reconciled') and ((o.order_id is null and nullif(r.legacy_firestore_id,'') is null) or (o.order_id is not null and o.order_status<>'refunded'))),
      'closing_differences',(select count(*) from public.finance_daily_closings where wave_difference<>0),
      'unjustified_closing_differences',(select count(*) from public.finance_daily_closings where wave_difference<>0 and char_length(btrim(coalesce(wave_difference_note,'')))<3)
    ),
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
$function$
;

CREATE OR REPLACE FUNCTION public.izytel_bo75_finance_period_history(p_module text, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_module text := lower(btrim(coalesce(p_module, '')));
  v_result jsonb;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
  end if;
  if p_start is null or p_end is null or p_end < p_start then
    raise exception 'INVALID_PERIOD';
  end if;

  case v_module
    when 'wave_cash' then
      select jsonb_build_object(
        'wave_adjustments', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.effective_at desc)
          from (
            select * from public.finance_wave_balance_adjustments
            where effective_at >= p_start and effective_at <= p_end
            order by effective_at desc limit 2000
          ) x
        ), '[]'::jsonb)
      ) into v_result;

    when 'commissions' then
      select jsonb_build_object(
        'commission_payouts', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.paid_at desc)
          from (
            select * from public.phase5_commission_payouts
            where paid_at >= p_start and paid_at <= p_end
            order by paid_at desc limit 2000
          ) x
        ), '[]'::jsonb),
        'commissions', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.earned_at desc)
          from (
            select * from public.phase5_commissions
            where earned_at >= p_start and earned_at <= p_end
            order by earned_at desc limit 2000
          ) x
        ), '[]'::jsonb)
      ) into v_result;

    when 'suppliers' then
      select jsonb_build_object(
        'supplier_recharges', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.occurred_at desc)
          from (
            select * from public.phase5_agent_recharges
            where occurred_at >= p_start and occurred_at <= p_end
            order by occurred_at desc limit 2000
          ) x
        ), '[]'::jsonb),
        'supplier_payments', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.paid_at desc)
          from (
            select * from public.phase5_supplier_payments
            where paid_at >= p_start and paid_at <= p_end
            order by paid_at desc limit 2000
          ) x
        ), '[]'::jsonb)
      ) into v_result;

    when 'customer_credits' then
      select jsonb_build_object(
        'credits', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.updated_at desc)
          from (
            select * from public.finance_customer_credits
            where updated_at >= p_start and updated_at <= p_end
            order by updated_at desc limit 2000
          ) x
        ), '[]'::jsonb),
        'credit_settlements', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.paid_at desc)
          from (
            select * from public.finance_customer_credit_settlements
            where paid_at >= p_start and paid_at <= p_end
            order by paid_at desc limit 2000
          ) x
        ), '[]'::jsonb)
      ) into v_result;

    when 'expenses' then
      select jsonb_build_object(
        'expenses', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.spent_at desc)
          from (
            select * from public.finance_expenses
            where spent_at >= p_start and spent_at <= p_end
            order by spent_at desc limit 2000
          ) x
        ), '[]'::jsonb)
      ) into v_result;

    when 'reconciliations' then
      select jsonb_build_object(
        'closings', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.closed_at desc)
          from (
            select * from public.finance_daily_closings
            where closed_at >= p_start and closed_at <= p_end
            order by closed_at desc limit 2000
          ) x
        ), '[]'::jsonb)
      ) into v_result;

    when 'movements' then
      select jsonb_build_object(
        'network_movements', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.occurred_at desc)
          from (
            select * from public.phase5_network_movements
            where occurred_at >= p_start and occurred_at <= p_end
            order by occurred_at desc limit 2000
          ) x
        ), '[]'::jsonb),
        'supplier_payments', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.paid_at desc)
          from (
            select * from public.phase5_supplier_payments
            where paid_at >= p_start and paid_at <= p_end
            order by paid_at desc limit 2000
          ) x
        ), '[]'::jsonb),
        'commission_payouts', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.paid_at desc)
          from (
            select * from public.phase5_commission_payouts
            where paid_at >= p_start and paid_at <= p_end
            order by paid_at desc limit 2000
          ) x
        ), '[]'::jsonb),
        'credit_settlements', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.paid_at desc)
          from (
            select * from public.finance_customer_credit_settlements
            where paid_at >= p_start and paid_at <= p_end
            order by paid_at desc limit 2000
          ) x
        ), '[]'::jsonb),
        'expenses', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.spent_at desc)
          from (
            select * from public.finance_expenses
            where spent_at >= p_start and spent_at <= p_end
            order by spent_at desc limit 2000
          ) x
        ), '[]'::jsonb),
        'refunds', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.refunded_at desc)
          from (
            select * from public.refunds
            where refunded_at is not null
              and refunded_at >= p_start and refunded_at <= p_end
            order by refunded_at desc limit 2000
          ) x
        ), '[]'::jsonb),
        'wave_adjustments', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.effective_at desc)
          from (
            select * from public.finance_wave_balance_adjustments
            where effective_at >= p_start and effective_at <= p_end
            order by effective_at desc limit 2000
          ) x
        ), '[]'::jsonb)
      ) into v_result;

    when 'closings' then
      select jsonb_build_object(
        'closings', coalesce((
          select jsonb_agg(to_jsonb(x) order by x.closed_at desc)
          from (
            select * from public.finance_daily_closings
            where closed_at >= p_start and closed_at <= p_end
            order by closed_at desc limit 2000
          ) x
        ), '[]'::jsonb)
      ) into v_result;

    else
      raise exception 'UNSUPPORTED_FINANCE_PERIOD_MODULE';
  end case;

  return coalesce(v_result, '{}'::jsonb) || jsonb_build_object(
    'totals',private.izytel_finance_period_totals(p_start,p_end + interval '1 microsecond'));
end;
$function$
;

CREATE OR REPLACE FUNCTION public.izytel_finance_create_closing(p_payload jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  if v_key !~ '^\d{4}-\d{2}-\d{2}$' then
    raise exception 'INVALID_DATE_KEY';
  end if;

  begin
    v_day := v_key::date;
  exception when others then
    raise exception 'INVALID_DATE_KEY';
  end;

  if v_day <> v_today then
    raise exception 'CLOSING_DATE_MUST_BE_TODAY';
  end if;

  v_day_start := v_day::timestamp at time zone 'Africa/Abidjan';
  v_day_end := (v_day + 1)::timestamp at time zone 'Africa/Abidjan';
  v_as_of := least(now(), v_day_end);

  select opening_balance,effective_at
    into v_opening,v_opening_at
  from public.finance_wave_settings
  where id=1
  for share;
  if not found then
    raise exception 'WAVE_OPENING_REQUIRED';
  end if;
  if v_opening_at >= v_as_of then
    raise exception 'WAVE_OPENING_AFTER_CLOSING_DATE';
  end if;
  if v_actual < 0 then
    raise exception 'INVALID_WAVE_BALANCE';
  end if;

  select coalesce(sum(o.amount),0)::bigint
    into v_client_receipts
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
  from public.phase5_supplier_payments p
  where p.paid_at >= v_day_start and p.paid_at < v_day_end;

  select coalesce(sum(c.amount),0)::bigint into v_credits_created
  from public.finance_customer_credits c
  where c.created_at >= v_day_start and c.created_at < v_day_end;

  select coalesce(sum(s.amount),0)::bigint into v_credit_settlements
  from public.finance_customer_credit_settlements s
  where s.paid_at >= v_day_start and s.paid_at < v_day_end;

  select coalesce(sum(greatest(c.amount-c.paid_amount,0)),0)::bigint into v_customer_receivables
  from public.finance_customer_credits c;

  select coalesce(sum(e.amount),0)::bigint into v_expenses
  from public.finance_expenses e
  where e.spent_at >= v_day_start and e.spent_at < v_day_end;

  select coalesce(sum(r.amount),0)::bigint into v_refunds
  from public.refunds r
  where r.refunded_at >= v_day_start and r.refunded_at < v_day_end;

  select coalesce(sum(c.commission_amount),0)::bigint into v_commissions_earned
  from public.phase5_commissions c
  where c.earned_at >= v_day_start and c.earned_at < v_day_end;

  select coalesce(sum(p.amount),0)::bigint into v_commissions_paid
  from public.phase5_commission_payouts p
  where p.paid_at >= v_day_start and p.paid_at < v_day_end;

  select coalesce(sum(c.orange_capacity),0)::bigint,
         coalesce(sum(c.mtn_capacity),0)::bigint,
         coalesce(sum(c.moov_capacity),0)::bigint
    into v_orange_available,v_mtn_available,v_moov_available
  from public.phase5_agent_capacities c;

  select
    coalesce(sum(case when o.network='orange' then o.amount else 0 end),0)::bigint,
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
    - v_wave_supplier - v_wave_expenses - v_wave_refunds - v_wave_commissions
    - (select coalesce(sum(amount),0) from public.compensation_payouts
       where actor_type='cabiniste' and currency='XOF' and lower(btrim(payment_channel))='wave'
         and paid_at>=v_opening_at and paid_at<v_as_of);

  if v_theoretical < 0 then
    raise exception 'INVALID_WAVE_BALANCE';
  end if;
  if v_actual <> v_theoretical and char_length(v_note) < 3 then
    raise exception 'WAVE_DIFFERENCE_NOTE_REQUIRED';
  end if;

  with ratios as (
    select r.network,
      case when sum(r.received_amount) <= 0 then 1::numeric
           else least(1::numeric,greatest(0::numeric,sum(r.principal_amount)::numeric/sum(r.received_amount)::numeric)) end as ratio
    from public.phase5_agent_recharges r
    where r.network in ('orange','mtn','moov')
    group by r.network
  ), day_successes as (
    select m.network,m.amount
    from public.phase5_network_movements m
    where m.direction='outgoing' and m.movement_type='orderSuccess'
      and m.occurred_at >= v_day_start and m.occurred_at < v_day_end
  )
  select coalesce(sum(round(s.amount * coalesce(r.ratio,1::numeric))),0)::bigint
    into v_estimated_network_cost
  from day_successes s left join ratios r on r.network=s.network;

  select coalesce(sum(r.amount),0)::bigint into v_profit_refunds
  from public.refunds r
  where r.refunded_at >= v_day_start and r.refunded_at < v_day_end
    and exists(
      select 1 from public.phase5_network_movements m
      where m.order_id=r.order_id and m.movement_type='orderSuccess'
    );

  v_estimated_profit := v_successful_orders_amount - v_estimated_network_cost
    - v_commissions_earned - v_expenses - v_profit_refunds;

  v_canonical := jsonb_build_object(
    'date_key',v_key,
    'client_receipts',v_client_receipts,
    'successful_orders_count',v_successful_orders_count,
    'successful_orders_amount',v_successful_orders_amount,
    'supplier_recharge_principal',v_supplier_recharge_principal,
    'supplier_recharge_bonus',v_supplier_recharge_bonus,
    'supplier_recharge_received',v_supplier_recharge_received,
    'supplier_payments',v_supplier_payments,
    'credits_created',v_credits_created,
    'credit_settlements',v_credit_settlements,
    'customer_receivables',v_customer_receivables,
    'expenses',v_expenses,
    'refunds',v_refunds,
    'commissions_earned',v_commissions_earned,
    'commissions_paid',v_commissions_paid,
    'orange_available',v_orange_available,
    'orange_committed',v_orange_committed,
    'mtn_available',v_mtn_available,
    'mtn_committed',v_mtn_committed,
    'moov_available',v_moov_available,
    'moov_committed',v_moov_committed,
    'supplier_debt',v_supplier_debt,
    'commission_debt',v_commission_debt,
    'wave_theoretical_balance',v_theoretical,
    'wave_actual_balance',v_actual,
    'wave_difference',v_actual-v_theoretical,
    'wave_difference_note',nullif(v_note,''),
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
  values(
    'daily_closing_created','closing',v_key,v_uid,v_name,
    jsonb_build_object('canonical',v_canonical,'client_request',p_payload)
  );
  return v_key;
exception
  when unique_violation then
    raise exception 'CLOSING_ALREADY_EXISTS';
end;
$function$
;

-- A legacy application must never reset a live stock to an old Firestore balance.
CREATE OR REPLACE FUNCTION private.phase5_reconcile_capacity_snapshot(p_row jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      on conflict(agent_id) do nothing; -- Supabase is authoritative after initialization.
    end;
    $function$
;

-- Partner identity/status changes also affect the same financial snapshot.
create trigger bo5_touch_partner_accounts after insert or update or delete on public.partner_accounts
for each statement execute function private.izytel_finance_phase5_touch();
notify pgrst,'reload schema';
