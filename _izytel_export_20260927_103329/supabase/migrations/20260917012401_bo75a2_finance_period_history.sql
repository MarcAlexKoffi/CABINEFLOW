-- BO-7.5A2 - historique financier périodique.
-- Le RPC permet au calendrier Web de retrouver des écritures anciennes au-delà
-- des fenêtres limitées du snapshot financier courant. La pagination complète
-- sera traitée en BO-7.5B.

create or replace function public.izytel_bo75_finance_period_history(
  p_module text,
  p_start timestamptz,
  p_end timestamptz
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_module text := lower(btrim(coalesce(p_module, '')));
  v_result jsonb;
begin
  if not private.is_izytel_finance_staff() then
    raise exception 'STAFF_REQUIRED' using errcode='42501';
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

  return coalesce(v_result, '{}'::jsonb);
end;
$function$;

revoke all on function public.izytel_bo75_finance_period_history(text,timestamptz,timestamptz) from public;
grant execute on function public.izytel_bo75_finance_period_history(text,timestamptz,timestamptz) to anon, authenticated;
