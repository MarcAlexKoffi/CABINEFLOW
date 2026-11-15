-- Canonical mobile reads. Never grant direct client access to finance tables.
create or replace function public.izytel_finance_read_page(
  p_kind text, p_after text default null, p_limit integer default 250
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_table text;
  v_key text := 'id';
  v_result jsonb;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode = '42501';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 500 then
    raise exception 'INVALID_PAGE_SIZE' using errcode = '22023';
  end if;
  case p_kind
    when 'credits' then v_table := 'finance_customer_credits';
    when 'settlements' then v_table := 'finance_customer_credit_settlements';
    when 'expenses' then v_table := 'finance_expenses';
    when 'opening' then v_table := 'finance_wave_settings';
    when 'adjustments' then v_table := 'finance_wave_balance_adjustments';
    when 'closings' then v_table := 'finance_daily_closings'; v_key := 'date_key';
    when 'supplier_accounts' then v_table := 'phase5_supplier_accounts'; v_key := 'supplier_id';
    when 'supplier_recharges' then v_table := 'phase5_agent_recharges'; v_key := 'source_firestore_id';
    when 'supplier_payments' then v_table := 'phase5_supplier_payments';
    else raise exception 'INVALID_FINANCE_DATASET' using errcode = '22023';
  end case;
  -- Names originate exclusively from the closed case above; values stay bound.
  execute format(
    'select coalesce(jsonb_agg(to_jsonb(r) order by r.%1$I::text), ''[]''::jsonb)
     from (select * from public.%2$I where ($1 is null or %1$I::text > $1)
           order by %1$I::text limit $2) r', v_key, v_table
  ) into v_result using p_after, p_limit;
  return v_result;
end;
$$;
revoke all on function public.izytel_finance_read_page(text,text,integer) from public;
grant execute on function public.izytel_finance_read_page(text,text,integer) to anon, authenticated;
