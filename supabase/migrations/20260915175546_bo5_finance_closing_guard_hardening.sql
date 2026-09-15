-- BO-5 - durcissement serveur des clotures financieres.
-- Le back-office valide deja ces regles, mais elles restent obligatoires au
-- niveau Supabase afin qu'un client contourne ne puisse pas enregistrer une
-- cloture sans point de depart Wave ou sans justification d'ecart.
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
  v_theoretical bigint := coalesce((p_payload->>'wave_theoretical_balance')::bigint,0);
  v_actual bigint := coalesce((p_payload->>'wave_actual_balance')::bigint,0);
  v_note text := btrim(coalesce(p_payload->>'wave_difference_note',''));
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
  end if;
  if v_key !~ '^\d{4}-\d{2}-\d{2}$' then
    raise exception 'INVALID_DATE_KEY';
  end if;
  if not exists(select 1 from public.finance_wave_settings where id=1) then
    raise exception 'WAVE_OPENING_REQUIRED';
  end if;
  if v_actual < 0 or v_theoretical < 0 then
    raise exception 'INVALID_WAVE_BALANCE';
  end if;
  if v_actual <> v_theoretical and char_length(v_note) < 3 then
    raise exception 'WAVE_DIFFERENCE_NOTE_REQUIRED';
  end if;

  insert into public.finance_daily_closings(
    date_key,client_receipts,successful_orders_count,successful_orders_amount,
    supplier_recharge_principal,supplier_recharge_bonus,supplier_recharge_received,supplier_payments,
    credits_created,credit_settlements,customer_receivables,expenses,refunds,
    commissions_earned,commissions_paid,orange_available,orange_committed,mtn_available,mtn_committed,
    moov_available,moov_committed,supplier_debt,commission_debt,wave_theoretical_balance,wave_actual_balance,
    wave_difference,wave_difference_note,estimated_profit,closed_at,closed_by_uid,closed_by_name
  ) values(
    v_key,
    coalesce((p_payload->>'client_receipts')::bigint,0),
    coalesce((p_payload->>'successful_orders_count')::integer,0),
    coalesce((p_payload->>'successful_orders_amount')::bigint,0),
    coalesce((p_payload->>'supplier_recharge_principal')::bigint,0),
    coalesce((p_payload->>'supplier_recharge_bonus')::bigint,0),
    coalesce((p_payload->>'supplier_recharge_received')::bigint,0),
    coalesce((p_payload->>'supplier_payments')::bigint,0),
    coalesce((p_payload->>'credits_created')::bigint,0),
    coalesce((p_payload->>'credit_settlements')::bigint,0),
    coalesce((p_payload->>'customer_receivables')::bigint,0),
    coalesce((p_payload->>'expenses')::bigint,0),
    coalesce((p_payload->>'refunds')::bigint,0),
    coalesce((p_payload->>'commissions_earned')::bigint,0),
    coalesce((p_payload->>'commissions_paid')::bigint,0),
    coalesce((p_payload->>'orange_available')::bigint,0),
    coalesce((p_payload->>'orange_committed')::bigint,0),
    coalesce((p_payload->>'mtn_available')::bigint,0),
    coalesce((p_payload->>'mtn_committed')::bigint,0),
    coalesce((p_payload->>'moov_available')::bigint,0),
    coalesce((p_payload->>'moov_committed')::bigint,0),
    coalesce((p_payload->>'supplier_debt')::bigint,0),
    coalesce((p_payload->>'commission_debt')::bigint,0),
    v_theoretical,
    v_actual,
    v_actual-v_theoretical,
    nullif(v_note,''),
    coalesce((p_payload->>'estimated_profit')::bigint,0),
    now(),v_uid,v_name
  );

  insert into public.finance_audit_events(
    event_kind,entity_type,entity_id,actor_uid,actor_name,payload
  ) values(
    'daily_closing_created','closing',v_key,v_uid,v_name,p_payload
  );
  return v_key;
exception
  when unique_violation then
    raise exception 'CLOSING_ALREADY_EXISTS';
end;
$function$;

revoke all on function public.izytel_finance_create_closing(jsonb) from public;
grant execute on function public.izytel_finance_create_closing(jsonb) to anon, authenticated;
