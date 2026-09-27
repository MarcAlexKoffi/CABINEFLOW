-- IzyTel BO-5 - socle financier canonique du Back-office.
-- Supabase est la source d'ecriture. Firestore reste uniquement une source de reprise historique.

alter table public.finance_suppliers add column if not exists is_deleted boolean not null default false;

create table if not exists public.finance_customer_credits (
  id text primary key,
  order_id text not null unique,
  order_reference text not null,
  client_name text not null,
  client_whatsapp_phone text not null default '',
  amount bigint not null check (amount > 0),
  paid_amount bigint not null default 0 check (paid_amount >= 0 and paid_amount <= amount),
  status text not null default 'open' check (status in ('open','partial','settled')),
  note text,
  created_at timestamptz not null default now(),
  created_by_uid text not null,
  created_by_name text not null,
  updated_at timestamptz not null default now(),
  settled_at timestamptz,
  last_settlement_id uuid,
  legacy_firestore_id text unique
);

create table if not exists public.finance_customer_credit_settlements (
  id uuid primary key default gen_random_uuid(),
  legacy_firestore_id text unique,
  credit_id text not null references public.finance_customer_credits(id) on delete restrict,
  order_id text not null,
  order_reference text not null,
  client_name text not null,
  amount bigint not null check (amount > 0),
  payment_channel text not null check (payment_channel in ('wave','cash','bank','other')),
  payment_reference text not null,
  note text,
  paid_at timestamptz not null default now(),
  created_by_uid text not null,
  created_by_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.finance_expenses (
  id uuid primary key default gen_random_uuid(),
  legacy_firestore_id text unique,
  category text not null check (category in ('transport','internet','electricity','maintenance','salary','communication','fees','marketing','office','other')),
  amount bigint not null check (amount > 0),
  description text not null,
  payment_channel text not null check (payment_channel in ('wave','cash','bank','other')),
  payment_reference text,
  spent_at timestamptz not null default now(),
  created_by_uid text not null,
  created_by_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.finance_wave_settings (
  id smallint primary key default 1 check (id = 1),
  opening_balance bigint not null default 0 check (opening_balance >= 0),
  effective_at timestamptz not null default now(),
  note text,
  last_adjustment_id uuid,
  updated_at timestamptz not null default now(),
  updated_by_uid text not null,
  updated_by_name text not null
);

create table if not exists public.finance_wave_balance_adjustments (
  id uuid primary key default gen_random_uuid(),
  legacy_firestore_id text unique,
  previous_opening_balance bigint not null check (previous_opening_balance >= 0),
  opening_balance bigint not null check (opening_balance >= 0),
  effective_at timestamptz not null default now(),
  note text,
  created_by_uid text not null,
  created_by_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.finance_daily_closings (
  date_key text primary key,
  client_receipts bigint not null default 0,
  successful_orders_count integer not null default 0,
  successful_orders_amount bigint not null default 0,
  supplier_recharge_principal bigint not null default 0,
  supplier_recharge_bonus bigint not null default 0,
  supplier_recharge_received bigint not null default 0,
  supplier_payments bigint not null default 0,
  credits_created bigint not null default 0,
  credit_settlements bigint not null default 0,
  customer_receivables bigint not null default 0,
  expenses bigint not null default 0,
  refunds bigint not null default 0,
  commissions_earned bigint not null default 0,
  commissions_paid bigint not null default 0,
  orange_available bigint not null default 0,
  orange_committed bigint not null default 0,
  mtn_available bigint not null default 0,
  mtn_committed bigint not null default 0,
  moov_available bigint not null default 0,
  moov_committed bigint not null default 0,
  supplier_debt bigint not null default 0,
  commission_debt bigint not null default 0,
  wave_theoretical_balance bigint not null default 0,
  wave_actual_balance bigint not null default 0,
  wave_difference bigint not null default 0,
  wave_difference_note text,
  estimated_profit bigint not null default 0,
  closed_at timestamptz not null default now(),
  closed_by_uid text not null,
  closed_by_name text not null,
  legacy_firestore_id text unique
);

create table if not exists public.finance_audit_events (
  id uuid primary key default gen_random_uuid(),
  event_kind text not null,
  entity_type text not null,
  entity_id text,
  actor_uid text not null,
  actor_name text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists finance_customer_credits_status_idx on public.finance_customer_credits(status, updated_at desc);
create index if not exists finance_customer_credits_reference_idx on public.finance_customer_credits(order_reference);
create index if not exists finance_credit_settlements_credit_idx on public.finance_customer_credit_settlements(credit_id, paid_at desc);
create index if not exists finance_expenses_spent_idx on public.finance_expenses(spent_at desc);
create index if not exists finance_wave_adjustments_effective_idx on public.finance_wave_balance_adjustments(effective_at desc);
create index if not exists finance_daily_closings_closed_idx on public.finance_daily_closings(closed_at desc);
create index if not exists finance_audit_created_idx on public.finance_audit_events(created_at desc);

alter table public.finance_customer_credits enable row level security;
alter table public.finance_customer_credit_settlements enable row level security;
alter table public.finance_expenses enable row level security;
alter table public.finance_wave_settings enable row level security;
alter table public.finance_wave_balance_adjustments enable row level security;
alter table public.finance_daily_closings enable row level security;
alter table public.finance_audit_events enable row level security;

-- Les tables sensibles ne sont pas exposees directement aux clients.
revoke all on public.finance_customer_credits from anon, authenticated;
revoke all on public.finance_customer_credit_settlements from anon, authenticated;
revoke all on public.finance_expenses from anon, authenticated;
revoke all on public.finance_wave_settings from anon, authenticated;
revoke all on public.finance_wave_balance_adjustments from anon, authenticated;
revoke all on public.finance_daily_closings from anon, authenticated;
revoke all on public.finance_audit_events from anon, authenticated;

create or replace function private.izytel_finance_actor_name()
returns text
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(
    nullif(btrim(concat_ws(' ', sp.first_name, sp.last_name)), ''),
    nullif(btrim(sa.display_name), ''),
    'Administration'
  )
  from (select (select auth.jwt()->>'sub') uid) u
  left join public.staff_profiles sp on sp.firebase_uid=u.uid
  left join public.izytel_staff_access sa on sa.firebase_uid=u.uid
  limit 1;
$function$;

create or replace function public.izytel_finance_snapshot()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare v_result jsonb;
begin
  if not private.is_izytel_phase4_staff() then
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
    'orders', coalesce((select jsonb_agg(to_jsonb(x) order by updated_at desc) from (select order_id,order_reference,network,amount,source,client_name,client_whatsapp_phone,beneficiary_phone,operation_type,offer_label,payment_status,payment_reference,payment_confirmed_at,paid_at,order_status,assigned_agent_id,assigned_agent_name,processing_started_at,completed_at,failure_reason,updated_at from public.phase4_assignment_orders order by updated_at desc limit 1000) x), '[]'::jsonb),
    'success_finalizations', coalesce((select jsonb_agg(to_jsonb(x) order by financial_applied_at desc) from (select * from public.phase5_success_finalizations order by financial_applied_at desc limit 700) x), '[]'::jsonb),
    'ledger_events', coalesce((select jsonb_agg(to_jsonb(x) order by occurred_at desc) from (select * from public.phase5_ledger_events order by occurred_at desc limit 800) x), '[]'::jsonb),
    'audit_events', coalesce((select jsonb_agg(to_jsonb(x) order by created_at desc) from (select * from public.finance_audit_events order by created_at desc limit 300) x), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$function$;

create or replace function public.izytel_finance_set_wave_opening(p_amount bigint, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_finance_actor_name();
  v_prev bigint := 0;
  v_id uuid := gen_random_uuid();
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
  if p_amount < 0 then raise exception 'INVALID_WAVE_BALANCE'; end if;
  select opening_balance into v_prev from public.finance_wave_settings where id=1 for update;
  v_prev := coalesce(v_prev,0);
  insert into public.finance_wave_balance_adjustments(id,previous_opening_balance,opening_balance,effective_at,note,created_by_uid,created_by_name)
  values(v_id,v_prev,p_amount,now(),nullif(btrim(coalesce(p_note,'')),''),v_uid,v_name);
  insert into public.finance_wave_settings(id,opening_balance,effective_at,note,last_adjustment_id,updated_at,updated_by_uid,updated_by_name)
  values(1,p_amount,now(),nullif(btrim(coalesce(p_note,'')),''),v_id,now(),v_uid,v_name)
  on conflict(id) do update set opening_balance=excluded.opening_balance,effective_at=excluded.effective_at,note=excluded.note,last_adjustment_id=excluded.last_adjustment_id,updated_at=now(),updated_by_uid=v_uid,updated_by_name=v_name;
  insert into public.finance_audit_events(event_kind,entity_type,entity_id,actor_uid,actor_name,payload)
  values('wave_opening_set','wave','1',v_uid,v_name,jsonb_build_object('previous',v_prev,'amount',p_amount,'note',p_note));
end;
$function$;

create or replace function public.izytel_finance_settle_credit(p_credit_id text,p_amount bigint,p_channel text,p_reference text,p_note text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_finance_actor_name();
  v_credit public.finance_customer_credits;
  v_id uuid := gen_random_uuid();
  v_ref text := upper(btrim(coalesce(p_reference,'')));
  v_next bigint;
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
  if p_amount<=0 then raise exception 'INVALID_AMOUNT'; end if;
  if p_channel not in('wave','cash','bank','other') then raise exception 'INVALID_CHANNEL'; end if;
  if char_length(v_ref)<3 then raise exception 'INVALID_REFERENCE'; end if;
  select * into v_credit from public.finance_customer_credits where id=btrim(p_credit_id) for update;
  if not found then raise exception 'CREDIT_NOT_FOUND'; end if;
  if v_credit.status='settled' or v_credit.paid_amount>=v_credit.amount then raise exception 'CREDIT_ALREADY_SETTLED'; end if;
  if p_amount>v_credit.amount-v_credit.paid_amount then raise exception 'PAYMENT_EXCEEDS_BALANCE'; end if;
  if exists(select 1 from public.finance_customer_credit_settlements where upper(payment_reference)=v_ref) then raise exception 'DUPLICATE_REFERENCE'; end if;
  insert into public.finance_customer_credit_settlements(id,credit_id,order_id,order_reference,client_name,amount,payment_channel,payment_reference,note,paid_at,created_by_uid,created_by_name)
  values(v_id,v_credit.id,v_credit.order_id,v_credit.order_reference,v_credit.client_name,p_amount,p_channel,v_ref,nullif(btrim(coalesce(p_note,'')),''),now(),v_uid,v_name);
  v_next:=v_credit.paid_amount+p_amount;
  update public.finance_customer_credits set paid_amount=v_next,status=case when v_next=amount then 'settled' else 'partial' end,settled_at=case when v_next=amount then now() else null end,last_settlement_id=v_id,updated_at=now() where id=v_credit.id;
  insert into public.finance_audit_events(event_kind,entity_type,entity_id,actor_uid,actor_name,payload)
  values('credit_settled','customer_credit',v_credit.id,v_uid,v_name,jsonb_build_object('settlement_id',v_id,'amount',p_amount,'channel',p_channel));
  return v_id;
end;
$function$;

create or replace function public.izytel_finance_record_expense(p_category text,p_amount bigint,p_description text,p_channel text,p_reference text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_finance_actor_name();
  v_id uuid := gen_random_uuid();
  v_ref text := nullif(btrim(coalesce(p_reference,'')),'');
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
  if p_category not in('transport','internet','electricity','maintenance','salary','communication','fees','marketing','office','other') then raise exception 'INVALID_EXPENSE_CATEGORY'; end if;
  if p_amount<=0 then raise exception 'INVALID_AMOUNT'; end if;
  if char_length(btrim(coalesce(p_description,'')))<3 then raise exception 'INVALID_DESCRIPTION'; end if;
  if p_channel not in('wave','cash','bank','other') then raise exception 'INVALID_CHANNEL'; end if;
  if p_channel='wave' and(v_ref is null or char_length(v_ref)<3) then raise exception 'WAVE_REFERENCE_REQUIRED'; end if;
  insert into public.finance_expenses(id,category,amount,description,payment_channel,payment_reference,spent_at,created_by_uid,created_by_name)
  values(v_id,p_category,p_amount,btrim(p_description),p_channel,v_ref,now(),v_uid,v_name);
  insert into public.finance_audit_events(event_kind,entity_type,entity_id,actor_uid,actor_name,payload)
  values('expense_recorded','expense',v_id::text,v_uid,v_name,jsonb_build_object('amount',p_amount,'category',p_category,'channel',p_channel));
  return v_id;
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
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
  if v_key !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'INVALID_DATE_KEY'; end if;
  if coalesce((p_payload->>'wave_actual_balance')::bigint,0) <> coalesce((p_payload->>'wave_theoretical_balance')::bigint,0)
     and char_length(btrim(coalesce(p_payload->>'wave_difference_note',''))) < 3 then
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
    v_key,coalesce((p_payload->>'client_receipts')::bigint,0),coalesce((p_payload->>'successful_orders_count')::integer,0),coalesce((p_payload->>'successful_orders_amount')::bigint,0),
    coalesce((p_payload->>'supplier_recharge_principal')::bigint,0),coalesce((p_payload->>'supplier_recharge_bonus')::bigint,0),coalesce((p_payload->>'supplier_recharge_received')::bigint,0),coalesce((p_payload->>'supplier_payments')::bigint,0),
    coalesce((p_payload->>'credits_created')::bigint,0),coalesce((p_payload->>'credit_settlements')::bigint,0),coalesce((p_payload->>'customer_receivables')::bigint,0),coalesce((p_payload->>'expenses')::bigint,0),coalesce((p_payload->>'refunds')::bigint,0),
    coalesce((p_payload->>'commissions_earned')::bigint,0),coalesce((p_payload->>'commissions_paid')::bigint,0),coalesce((p_payload->>'orange_available')::bigint,0),coalesce((p_payload->>'orange_committed')::bigint,0),coalesce((p_payload->>'mtn_available')::bigint,0),coalesce((p_payload->>'mtn_committed')::bigint,0),
    coalesce((p_payload->>'moov_available')::bigint,0),coalesce((p_payload->>'moov_committed')::bigint,0),coalesce((p_payload->>'supplier_debt')::bigint,0),coalesce((p_payload->>'commission_debt')::bigint,0),
    coalesce((p_payload->>'wave_theoretical_balance')::bigint,0),coalesce((p_payload->>'wave_actual_balance')::bigint,0),
    coalesce((p_payload->>'wave_actual_balance')::bigint,0)-coalesce((p_payload->>'wave_theoretical_balance')::bigint,0),
    nullif(btrim(coalesce(p_payload->>'wave_difference_note','')),''),coalesce((p_payload->>'estimated_profit')::bigint,0),now(),v_uid,v_name
  );
  insert into public.finance_audit_events(event_kind,entity_type,entity_id,actor_uid,actor_name,payload)
  values('daily_closing_created','closing',v_key,v_uid,v_name,p_payload);
  return v_key;
exception when unique_violation then
  raise exception 'CLOSING_ALREADY_EXISTS';
end;
$function$;

revoke all on function public.izytel_finance_snapshot() from public;
revoke all on function public.izytel_finance_set_wave_opening(bigint,text) from public;
revoke all on function public.izytel_finance_settle_credit(text,bigint,text,text,text) from public;
revoke all on function public.izytel_finance_record_expense(text,bigint,text,text,text) from public;
revoke all on function public.izytel_finance_create_closing(jsonb) from public;
grant execute on function public.izytel_finance_snapshot() to anon, authenticated;
grant execute on function public.izytel_finance_set_wave_opening(bigint,text) to anon, authenticated;
grant execute on function public.izytel_finance_settle_credit(text,bigint,text,text,text) to anon, authenticated;
grant execute on function public.izytel_finance_record_expense(text,bigint,text,text,text) to anon, authenticated;
grant execute on function public.izytel_finance_create_closing(jsonb) to anon, authenticated;
