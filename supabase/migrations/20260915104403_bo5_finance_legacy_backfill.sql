-- IzyTel BO-5 - reprise historique Firestore -> Supabase, lecture seule cote Firestore.
create table if not exists public.finance_migration_state (
  migration_key text primary key,
  imported_count integer not null default 0,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.finance_migration_state enable row level security;
revoke all on public.finance_migration_state from anon, authenticated;

create or replace function public.izytel_finance_backfill_needed()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select case
    when not private.is_izytel_finance_admin() then false
    else not exists(
      select 1 from public.finance_migration_state
      where migration_key='firestore_bo5' and completed_at is not null
    )
  end;
$function$;

create or replace function public.izytel_import_legacy_finance(p_kind text,p_legacy_id text,p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_finance_actor_name();
  v_credit_id text;
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
  if btrim(coalesce(p_legacy_id,''))='' then raise exception 'LEGACY_ID_REQUIRED'; end if;
  case p_kind
    when 'credit' then
      insert into public.finance_customer_credits(id,order_id,order_reference,client_name,client_whatsapp_phone,amount,paid_amount,status,note,created_at,created_by_uid,created_by_name,updated_at,settled_at,legacy_firestore_id)
      values(coalesce(nullif(p_payload->>'id',''),p_legacy_id),coalesce(nullif(p_payload->>'order_id',''),p_legacy_id),coalesce(nullif(p_payload->>'order_reference',''),'LEGACY-'||p_legacy_id),coalesce(nullif(p_payload->>'client_name',''),'Client'),coalesce(p_payload->>'client_whatsapp_phone',''),greatest(coalesce((p_payload->>'amount')::bigint,0),1),greatest(coalesce((p_payload->>'paid_amount')::bigint,0),0),case when p_payload->>'status' in('open','partial','settled') then p_payload->>'status' else 'open' end,nullif(p_payload->>'note',''),coalesce(nullif(p_payload->>'created_at','')::timestamptz,now()),coalesce(nullif(p_payload->>'created_by_uid',''),v_uid),coalesce(nullif(p_payload->>'created_by_name',''),v_name),coalesce(nullif(p_payload->>'updated_at','')::timestamptz,now()),nullif(p_payload->>'settled_at','')::timestamptz,p_legacy_id)
      on conflict do nothing;
    when 'credit_settlement' then
      v_credit_id:=coalesce(nullif(p_payload->>'credit_id',''),p_payload->>'order_id');
      if exists(select 1 from public.finance_customer_credits where id=v_credit_id) then
        insert into public.finance_customer_credit_settlements(legacy_firestore_id,credit_id,order_id,order_reference,client_name,amount,payment_channel,payment_reference,note,paid_at,created_by_uid,created_by_name)
        values(p_legacy_id,v_credit_id,coalesce(p_payload->>'order_id',''),coalesce(p_payload->>'order_reference',''),coalesce(nullif(p_payload->>'client_name',''),'Client'),greatest(coalesce((p_payload->>'amount')::bigint,0),1),case when p_payload->>'payment_channel' in('wave','cash','bank','other') then p_payload->>'payment_channel' else 'other' end,coalesce(nullif(p_payload->>'payment_reference',''),'LEGACY-'||p_legacy_id),nullif(p_payload->>'note',''),coalesce(nullif(p_payload->>'paid_at','')::timestamptz,now()),coalesce(nullif(p_payload->>'created_by_uid',''),v_uid),coalesce(nullif(p_payload->>'created_by_name',''),v_name))
        on conflict do nothing;
      end if;
    when 'expense' then
      insert into public.finance_expenses(legacy_firestore_id,category,amount,description,payment_channel,payment_reference,spent_at,created_by_uid,created_by_name)
      values(p_legacy_id,case when p_payload->>'category' in('transport','internet','electricity','maintenance','salary','communication','fees','marketing','office','other') then p_payload->>'category' else 'other' end,greatest(coalesce((p_payload->>'amount')::bigint,0),1),coalesce(nullif(p_payload->>'description',''),'Dépense historique'),case when p_payload->>'payment_channel' in('wave','cash','bank','other') then p_payload->>'payment_channel' else 'other' end,nullif(p_payload->>'payment_reference',''),coalesce(nullif(p_payload->>'spent_at','')::timestamptz,now()),coalesce(nullif(p_payload->>'created_by_uid',''),v_uid),coalesce(nullif(p_payload->>'created_by_name',''),v_name))
      on conflict do nothing;
    when 'wave_adjustment' then
      insert into public.finance_wave_balance_adjustments(legacy_firestore_id,previous_opening_balance,opening_balance,effective_at,note,created_by_uid,created_by_name)
      values(p_legacy_id,greatest(coalesce((p_payload->>'previous_opening_balance')::bigint,0),0),greatest(coalesce((p_payload->>'opening_balance')::bigint,0),0),coalesce(nullif(p_payload->>'effective_at','')::timestamptz,now()),nullif(p_payload->>'note',''),coalesce(nullif(p_payload->>'created_by_uid',''),v_uid),coalesce(nullif(p_payload->>'created_by_name',''),v_name))
      on conflict do nothing;
    when 'wave_setting' then
      insert into public.finance_wave_settings(id,opening_balance,effective_at,note,updated_at,updated_by_uid,updated_by_name)
      values(1,greatest(coalesce((p_payload->>'opening_balance')::bigint,0),0),coalesce(nullif(p_payload->>'effective_at','')::timestamptz,now()),nullif(p_payload->>'note',''),coalesce(nullif(p_payload->>'updated_at','')::timestamptz,now()),coalesce(nullif(p_payload->>'updated_by_uid',''),v_uid),coalesce(nullif(p_payload->>'updated_by_name',''),v_name))
      on conflict(id) do update set opening_balance=excluded.opening_balance,effective_at=excluded.effective_at,note=excluded.note,updated_at=excluded.updated_at,updated_by_uid=excluded.updated_by_uid,updated_by_name=excluded.updated_by_name
      where public.finance_wave_settings.updated_at<=excluded.updated_at;
    when 'closing' then
      insert into public.finance_daily_closings(date_key,client_receipts,successful_orders_count,successful_orders_amount,supplier_recharge_principal,supplier_recharge_bonus,supplier_recharge_received,supplier_payments,credits_created,credit_settlements,customer_receivables,expenses,refunds,commissions_earned,commissions_paid,orange_available,orange_committed,mtn_available,mtn_committed,moov_available,moov_committed,supplier_debt,commission_debt,wave_theoretical_balance,wave_actual_balance,wave_difference,wave_difference_note,estimated_profit,closed_at,closed_by_uid,closed_by_name,legacy_firestore_id)
      values(coalesce(nullif(p_payload->>'date_key',''),p_legacy_id),coalesce((p_payload->>'client_receipts')::bigint,0),coalesce((p_payload->>'successful_orders_count')::integer,0),coalesce((p_payload->>'successful_orders_amount')::bigint,0),coalesce((p_payload->>'supplier_recharge_principal')::bigint,0),coalesce((p_payload->>'supplier_recharge_bonus')::bigint,0),coalesce((p_payload->>'supplier_recharge_received')::bigint,0),coalesce((p_payload->>'supplier_payments')::bigint,0),coalesce((p_payload->>'credits_created')::bigint,0),coalesce((p_payload->>'credit_settlements')::bigint,0),coalesce((p_payload->>'customer_receivables')::bigint,0),coalesce((p_payload->>'expenses')::bigint,0),coalesce((p_payload->>'refunds')::bigint,0),coalesce((p_payload->>'commissions_earned')::bigint,0),coalesce((p_payload->>'commissions_paid')::bigint,0),coalesce((p_payload->>'orange_available')::bigint,0),coalesce((p_payload->>'orange_committed')::bigint,0),coalesce((p_payload->>'mtn_available')::bigint,0),coalesce((p_payload->>'mtn_committed')::bigint,0),coalesce((p_payload->>'moov_available')::bigint,0),coalesce((p_payload->>'moov_committed')::bigint,0),coalesce((p_payload->>'supplier_debt')::bigint,0),coalesce((p_payload->>'commission_debt')::bigint,0),coalesce((p_payload->>'wave_theoretical_balance')::bigint,0),coalesce((p_payload->>'wave_actual_balance')::bigint,0),coalesce((p_payload->>'wave_difference')::bigint,0),nullif(p_payload->>'wave_difference_note',''),coalesce((p_payload->>'estimated_profit')::bigint,0),coalesce(nullif(p_payload->>'closed_at','')::timestamptz,now()),coalesce(nullif(p_payload->>'closed_by_uid',''),v_uid),coalesce(nullif(p_payload->>'closed_by_name',''),v_name),p_legacy_id)
      on conflict do nothing;
    else raise exception 'INVALID_LEGACY_KIND';
  end case;
end;
$function$;

create or replace function public.izytel_finish_finance_backfill(p_imported_count integer)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
  insert into public.finance_migration_state(migration_key,imported_count,completed_at,updated_at)
  values('firestore_bo5',greatest(coalesce(p_imported_count,0),0),now(),now())
  on conflict(migration_key) do update set imported_count=excluded.imported_count,completed_at=excluded.completed_at,updated_at=now();
end;
$function$;

revoke all on function public.izytel_finance_backfill_needed() from public;
revoke all on function public.izytel_import_legacy_finance(text,text,jsonb) from public;
revoke all on function public.izytel_finish_finance_backfill(integer) from public;
grant execute on function public.izytel_finance_backfill_needed() to anon, authenticated;
grant execute on function public.izytel_import_legacy_finance(text,text,jsonb) to anon, authenticated;
grant execute on function public.izytel_finish_finance_backfill(integer) to anon, authenticated;
