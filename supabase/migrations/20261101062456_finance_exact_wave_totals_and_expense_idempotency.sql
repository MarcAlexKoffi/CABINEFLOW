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


-- Receipts are private, contain no client-editable balance and survive retries.
create table if not exists private.finance_operation_receipts (
  actor_uid text not null,
  operation_key text not null,
  request_payload jsonb not null,
  expense_id uuid not null references public.finance_expenses(id),
  created_at timestamptz not null default now(),
  primary key(actor_uid,operation_key)
);
alter table private.finance_operation_receipts enable row level security;
revoke all on private.finance_operation_receipts from public, anon, authenticated;

create or replace function public.izytel_finance_record_expense_once(
  p_category text,p_amount bigint,p_description text,p_channel text,
  p_reference text,p_operation_key text
) returns uuid
language plpgsql security definer set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_key text := btrim(coalesce(p_operation_key,''));
  v_payload jsonb := jsonb_build_object('category',p_category,'amount',p_amount,'description',btrim(p_description),'channel',p_channel,'reference',nullif(btrim(p_reference),''));
  v_receipt private.finance_operation_receipts;
  v_id uuid;
begin
  if not private.is_izytel_finance_admin() or nullif(v_uid,'') is null then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
  end if;
  if char_length(v_key)<8 or char_length(v_key)>160 then raise exception 'INVALID_OPERATION_KEY'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_uid || ':' || v_key,0));
  select * into v_receipt from private.finance_operation_receipts where actor_uid=v_uid and operation_key=v_key;
  if found then
    if v_receipt.request_payload <> v_payload then raise exception 'OPERATION_KEY_PAYLOAD_MISMATCH'; end if;
    return v_receipt.expense_id;
  end if;
  v_id := public.izytel_finance_record_expense(p_category,p_amount,p_description,p_channel,p_reference);
  insert into private.finance_operation_receipts(actor_uid,operation_key,request_payload,expense_id)
  values(v_uid,v_key,v_payload,v_id);
  return v_id;
end;
$function$;
revoke all on function public.izytel_finance_record_expense_once(text,bigint,text,text,text,text) from public;
grant execute on function public.izytel_finance_record_expense_once(text,bigint,text,text,text,text) to anon, authenticated;
-- All current clients use the receipt endpoint. Keep the original function for
-- its validation/audit logic, callable only by the privileged wrapper owner.
revoke all on function public.izytel_finance_record_expense(text,bigint,text,text,text) from public, anon, authenticated;

-- Global BO history is Admin-only. Manager finance uses territorial RPCs.
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

  return coalesce(v_result, '{}'::jsonb);
end;
$function$;

revoke all on function public.izytel_bo75_finance_period_history(text,timestamptz,timestamptz) from public;
grant execute on function public.izytel_bo75_finance_period_history(text,timestamptz,timestamptz) to anon, authenticated;
