-- WC2 Web Client V2 - recuperation de commande canonique Supabase.
-- Aucun nouveau champ ni aucune nouvelle regle Firestore n'est necessaire.

create table if not exists public.customer_order_recovery_registry (
  order_id text primary key,
  order_reference text not null unique,
  owner_firebase_uid text not null,
  recovery_code_hash text not null,
  service text not null check (service in ('unitTransfer','internetSubscription','calls')),
  network text not null check (network in ('orange','mtn','moov')),
  operation_type text not null check (
    operation_type in ('internetSubscription','unitTransfer','callBundle','mixedBundle','other')
  ),
  offer_id text,
  offer_label text not null,
  is_custom_offer boolean not null default false,
  amount integer not null check (amount > 0 and amount <= 1000000),
  beneficiary_phone text not null,
  created_at timestamptz not null,
  expires_at timestamptz not null,
  registered_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customer_order_recovery_order_id_check
    check (char_length(btrim(order_id)) between 8 and 128),
  constraint customer_order_recovery_reference_check
    check (order_reference ~ '^CF-[0-9]{8}-[A-Z0-9]{4,12}$'),
  constraint customer_order_recovery_offer_label_check
    check (char_length(btrim(offer_label)) between 2 and 200),
  constraint customer_order_recovery_beneficiary_check
    check (char_length(btrim(beneficiary_phone)) between 10 and 24),
  constraint customer_order_recovery_expiry_check
    check (expires_at > created_at)
);

alter table public.customer_order_recovery_registry enable row level security;

revoke all on table public.customer_order_recovery_registry from public, anon, authenticated;

create or replace function private.izytel_wc2_register_customer_recovery(
  p_payload jsonb,
  p_recovery_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text;
  v_order_id text;
  v_reference text;
  v_code text;
  v_service text;
  v_network text;
  v_operation_type text;
  v_offer_id text;
  v_offer_label text;
  v_is_custom_offer boolean;
  v_amount integer;
  v_beneficiary text;
  v_created_at timestamptz;
  v_expires_at timestamptz;
  v_existing public.customer_order_recovery_registry;
begin
  if not public.is_izytel_firebase_jwt() then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  v_uid := nullif((select auth.jwt()->>'sub'), '');
  if v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  v_order_id := btrim(coalesce(p_payload->>'order_id', ''));
  v_reference := upper(btrim(coalesce(p_payload->>'order_reference', '')));
  v_code := upper(btrim(coalesce(p_recovery_code, '')));
  v_service := btrim(coalesce(p_payload->>'service', ''));
  v_network := lower(btrim(coalesce(p_payload->>'network', '')));
  v_operation_type := btrim(coalesce(p_payload->>'operation_type', ''));
  v_offer_id := nullif(btrim(coalesce(p_payload->>'offer_id', '')), '');
  v_offer_label := btrim(coalesce(p_payload->>'offer_label', ''));
  v_is_custom_offer := coalesce((p_payload->>'is_custom_offer')::boolean, false);
  v_amount := coalesce((p_payload->>'amount')::integer, 0);
  v_beneficiary := btrim(coalesce(p_payload->>'beneficiary_phone', ''));
  v_created_at := (p_payload->>'created_at')::timestamptz;
  v_expires_at := (p_payload->>'expires_at')::timestamptz;

  if char_length(v_order_id) < 8 or char_length(v_order_id) > 128
    or v_reference !~ '^CF-[0-9]{8}-[A-Z0-9]{4,12}$'
    or v_code !~ '^IZY-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$'
    or v_service not in ('unitTransfer','internetSubscription','calls')
    or v_network not in ('orange','mtn','moov')
    or v_operation_type not in ('internetSubscription','unitTransfer','callBundle','mixedBundle','other')
    or char_length(v_offer_label) < 2 or char_length(v_offer_label) > 200
    or v_amount <= 0 or v_amount > 1000000
    or char_length(v_beneficiary) < 10 or char_length(v_beneficiary) > 24
    or v_created_at is null
    or v_expires_at is null
    or v_expires_at <= v_created_at
  then
    raise exception 'INVALID_RECOVERY_PAYLOAD' using errcode = '22023';
  end if;

  select * into v_existing
  from public.customer_order_recovery_registry
  where order_id = v_order_id;

  if found then
    if v_existing.owner_firebase_uid <> v_uid
      or v_existing.order_reference <> v_reference
      or extensions.crypt(v_code, v_existing.recovery_code_hash) <> v_existing.recovery_code_hash
    then
      raise exception 'RECOVERY_REGISTRATION_CONFLICT' using errcode = '23505';
    end if;

    return jsonb_build_object(
      'order_id', v_existing.order_id,
      'order_reference', v_existing.order_reference,
      'registered', true
    );
  end if;

  if exists (
    select 1
    from public.customer_order_recovery_registry
    where order_reference = v_reference
  ) then
    raise exception 'RECOVERY_REFERENCE_CONFLICT' using errcode = '23505';
  end if;

  insert into public.customer_order_recovery_registry (
    order_id,
    order_reference,
    owner_firebase_uid,
    recovery_code_hash,
    service,
    network,
    operation_type,
    offer_id,
    offer_label,
    is_custom_offer,
    amount,
    beneficiary_phone,
    created_at,
    expires_at
  ) values (
    v_order_id,
    v_reference,
    v_uid,
    extensions.crypt(v_code, extensions.gen_salt('bf', 10)),
    v_service,
    v_network,
    v_operation_type,
    v_offer_id,
    v_offer_label,
    v_is_custom_offer,
    v_amount,
    v_beneficiary,
    v_created_at,
    v_expires_at
  );

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_reference', v_reference,
    'registered', true
  );
end;
$function$;

create or replace function private.izytel_wc2_recover_customer_order(
  p_reference text,
  p_recovery_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_reference text := upper(btrim(coalesce(p_reference, '')));
  v_code text := upper(btrim(coalesce(p_recovery_code, '')));
  v_registry public.customer_order_recovery_registry;
  v_order public.phase4_assignment_orders;
  v_pre_sync_expired boolean := false;
begin
  if not public.is_izytel_firebase_jwt() then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  if v_reference !~ '^CF-[0-9]{8}-[A-Z0-9]{4,12}$'
    or v_code !~ '^IZY-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$'
  then
    return null;
  end if;

  select * into v_registry
  from public.customer_order_recovery_registry
  where order_reference = v_reference;

  if not found
    or extensions.crypt(v_code, v_registry.recovery_code_hash) <> v_registry.recovery_code_hash
  then
    return null;
  end if;

  select * into v_order
  from public.phase4_assignment_orders
  where order_id = v_registry.order_id
    and upper(order_reference) = v_registry.order_reference;

  v_pre_sync_expired := not found and now() >= v_registry.expires_at;

  return jsonb_build_object(
    'order_id', v_registry.order_id,
    'order_reference', v_registry.order_reference,
    'service', v_registry.service,
    'network', coalesce(v_order.network, v_registry.network),
    'operation_type', coalesce(v_order.operation_type, v_registry.operation_type),
    'offer_id', v_registry.offer_id,
    'offer_label', coalesce(v_order.offer_label, v_registry.offer_label),
    'is_custom_offer', v_registry.is_custom_offer,
    'amount', coalesce(v_order.amount, v_registry.amount),
    'beneficiary_phone', coalesce(v_order.beneficiary_phone, v_registry.beneficiary_phone),
    'created_at', v_registry.created_at,
    'expires_at', v_registry.expires_at,
    'order_status', case
      when v_order.order_id is not null then v_order.order_status
      when v_pre_sync_expired then 'expired'
      else 'awaitingPayment'
    end,
    'payment_status', case
      when v_order.order_id is not null then v_order.payment_status
      when v_pre_sync_expired then 'expired'
      else 'notDeclared'
    end,
    'payment_confirmed_at', v_order.payment_confirmed_at,
    'processing_started_at', v_order.processing_started_at,
    'completed_at', v_order.completed_at,
    'failure_reason', v_order.failure_reason,
    'observation', v_order.observation,
    'customer_confirmation_status', v_order.customer_confirmation_status,
    'updated_at', coalesce(v_order.updated_at, v_registry.updated_at)
  );
end;
$function$;

create or replace function private.izytel_wc2_customer_order_status(
  p_order_id text,
  p_reference text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text;
  v_row public.phase4_assignment_orders;
begin
  if not public.is_izytel_firebase_jwt() then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  v_uid := nullif((select auth.jwt()->>'sub'), '');
  if v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  select * into v_row
  from public.phase4_assignment_orders
  where order_id = btrim(coalesce(p_order_id, ''))
    and upper(order_reference) = upper(btrim(coalesce(p_reference, '')))
    and customer_auth_uid = v_uid;

  if not found then return null; end if;

  return jsonb_build_object(
    'order_id', v_row.order_id,
    'order_reference', v_row.order_reference,
    'order_status', v_row.order_status,
    'payment_status', v_row.payment_status,
    'processing_started_at', v_row.processing_started_at,
    'completed_at', v_row.completed_at,
    'failure_reason', v_row.failure_reason,
    'observation', v_row.observation,
    'customer_confirmation_status', v_row.customer_confirmation_status,
    'updated_at', v_row.updated_at
  );
end;
$function$;

create or replace function public.izytel_wc2_register_customer_recovery(
  p_payload jsonb,
  p_recovery_code text
)
returns jsonb
language sql
set search_path = ''
as $function$
  select private.izytel_wc2_register_customer_recovery(p_payload, p_recovery_code);
$function$;

create or replace function public.izytel_wc2_recover_customer_order(
  p_reference text,
  p_recovery_code text
)
returns jsonb
language sql
set search_path = ''
as $function$
  select private.izytel_wc2_recover_customer_order(p_reference, p_recovery_code);
$function$;

create or replace function public.izytel_wc2_customer_order_status(
  p_order_id text,
  p_reference text
)
returns jsonb
language sql
set search_path = ''
as $function$
  select private.izytel_wc2_customer_order_status(p_order_id, p_reference);
$function$;

revoke all on function private.izytel_wc2_register_customer_recovery(jsonb,text) from public;
revoke all on function private.izytel_wc2_recover_customer_order(text,text) from public;
revoke all on function private.izytel_wc2_customer_order_status(text,text) from public;

grant execute on function private.izytel_wc2_register_customer_recovery(jsonb,text) to anon, authenticated;
grant execute on function private.izytel_wc2_recover_customer_order(text,text) to anon, authenticated;
grant execute on function private.izytel_wc2_customer_order_status(text,text) to anon, authenticated;

revoke all on function public.izytel_wc2_register_customer_recovery(jsonb,text) from public;
revoke all on function public.izytel_wc2_recover_customer_order(text,text) from public;
revoke all on function public.izytel_wc2_customer_order_status(text,text) from public;

grant execute on function public.izytel_wc2_register_customer_recovery(jsonb,text) to anon, authenticated;
grant execute on function public.izytel_wc2_recover_customer_order(text,text) to anon, authenticated;
grant execute on function public.izytel_wc2_customer_order_status(text,text) to anon, authenticated;
