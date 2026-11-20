-- Freeze closing totals from the same canonical statement snapshot used by BO.
-- No existing closing or financial data is modified.
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
  v_theoretical bigint := 0;
  v_estimated_profit bigint := 0;
  v_canonical jsonb;
  v_snapshot jsonb;
  v_day_totals jsonb;
  v_wave_totals jsonb;
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

  -- Read every closing figure through one STABLE statement snapshot. Separate
  -- READ COMMITTED queries can otherwise observe different concurrent payments.
  select public.izytel_finance_snapshot() into v_snapshot;
  v_day_totals := v_snapshot->'day_totals';
  v_wave_totals := v_snapshot->'wave_totals';
  v_client_receipts := coalesce((v_day_totals->>'client_receipts')::bigint,0);
  v_successful_orders_count := coalesce((v_day_totals->>'successful_orders_count')::bigint,0);
  v_successful_orders_amount := coalesce((v_day_totals->>'successful_orders_amount')::bigint,0);
  v_supplier_recharge_principal := coalesce((v_day_totals->>'supplier_recharge_principal')::bigint,0);
  v_supplier_recharge_bonus := coalesce((v_day_totals->>'supplier_recharge_bonus')::bigint,0);
  v_supplier_recharge_received := coalesce((v_day_totals->>'supplier_recharge_received')::bigint,0);
  v_supplier_payments := coalesce((v_day_totals->>'supplier_payments')::bigint,0);
  v_credits_created := coalesce((v_day_totals->>'credits_created')::bigint,0);
  v_credit_settlements := coalesce((v_day_totals->>'credit_settlements')::bigint,0);
  v_expenses := coalesce((v_day_totals->>'expenses')::bigint,0);
  v_refunds := coalesce((v_day_totals->>'refunds')::bigint,0);
  v_commissions_earned := coalesce((v_day_totals->>'commissions_earned')::bigint,0);
  v_commissions_paid := coalesce((v_day_totals->>'commissions_paid')::bigint,0);
  v_estimated_profit := coalesce((v_day_totals->>'estimated_profit')::bigint,0);
  v_customer_receivables := coalesce((v_snapshot#>>'{global_totals,customer_receivables}')::bigint,0);
  select coalesce(sum(orange_capacity),0),coalesce(sum(mtn_capacity),0),coalesce(sum(moov_capacity),0)
    into v_orange_available,v_mtn_available,v_moov_available
    from pg_catalog.jsonb_to_recordset(v_snapshot->'agent_capacities')
      as c(orange_capacity bigint,mtn_capacity bigint,moov_capacity bigint);
  v_orange_committed := coalesce((v_snapshot#>>'{committed_capacities,orange}')::bigint,0);
  v_mtn_committed := coalesce((v_snapshot#>>'{committed_capacities,mtn}')::bigint,0);
  v_moov_committed := coalesce((v_snapshot#>>'{committed_capacities,moov}')::bigint,0);
  select coalesce(sum(greatest(total_owed-total_paid,0)),0) into v_supplier_debt
    from pg_catalog.jsonb_to_recordset(v_snapshot->'supplier_accounts') as a(total_owed bigint,total_paid bigint);
  select coalesce(sum(greatest(earned_total-paid_total,0)),0) into v_commission_debt
    from pg_catalog.jsonb_to_recordset(v_snapshot->'commission_accounts') as a(earned_total bigint,paid_total bigint);
  v_theoretical := v_opening
    +coalesce((v_wave_totals->>'client_payments')::bigint,0)
    +coalesce((v_wave_totals->>'credit_settlements')::bigint,0)
    -coalesce((v_wave_totals->>'supplier_payments')::bigint,0)
    -coalesce((v_wave_totals->>'expenses')::bigint,0)
    -coalesce((v_wave_totals->>'refunds')::bigint,0)
    -coalesce((v_wave_totals->>'commission_payouts')::bigint,0)
    -coalesce((v_wave_totals->>'cabiniste_payouts')::bigint,0);
  if v_theoretical < 0 then raise exception 'INVALID_WAVE_BALANCE'; end if;
  if v_actual <> v_theoretical and char_length(v_note)<3 then
    raise exception 'WAVE_DIFFERENCE_NOTE_REQUIRED';
  end if;

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
