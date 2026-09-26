-- WC2 - keep the pre-sync recovery snapshot in Supabase as well.
-- This lets a recovered order reflect payment declaration/expiration before
-- Phase 4 becomes canonical, without adding any Firestore field or rule.

alter table public.customer_order_recovery_registry
  add column if not exists order_status text not null default 'awaitingPayment',
  add column if not exists payment_status text not null default 'notDeclared',
  add column if not exists payment_declared_at timestamptz,
  add column if not exists payment_confirmed_at timestamptz,
  add column if not exists expired_at timestamptz;

alter table public.customer_order_recovery_registry
  drop constraint if exists customer_order_recovery_order_status_check,
  add constraint customer_order_recovery_order_status_check check (
    order_status in (
      'awaitingPayment', 'paymentToVerify', 'paidReady', 'inProgress', 'onHold',
      'awaitingCustomerConfirmation', 'completed', 'failed', 'expired',
      'cancelled', 'refundPending', 'refunded'
    )
  ),
  drop constraint if exists customer_order_recovery_payment_status_check,
  add constraint customer_order_recovery_payment_status_check check (
    payment_status in (
      'notDeclared', 'pending', 'declared', 'confirmed', 'credit', 'rejected', 'expired'
    )
  );

-- Direct table access stays denied. The public client only uses the validated
-- RPCs below; SECURITY DEFINER private functions own the table interaction.
drop policy if exists customer_order_recovery_rpc_only
  on public.customer_order_recovery_registry;
create policy customer_order_recovery_rpc_only
  on public.customer_order_recovery_registry
  for all
  to anon, authenticated
  using (false)
  with check (false);

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
  v_order_status text;
  v_payment_status text;
  v_payment_declared_at timestamptz;
  v_payment_confirmed_at timestamptz;
  v_expired_at timestamptz;
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
  v_order_status := btrim(coalesce(p_payload->>'order_status', 'awaitingPayment'));
  v_payment_status := btrim(coalesce(p_payload->>'payment_status', 'notDeclared'));
  v_payment_declared_at := nullif(p_payload->>'payment_declared_at', '')::timestamptz;
  v_payment_confirmed_at := nullif(p_payload->>'payment_confirmed_at', '')::timestamptz;
  v_expired_at := nullif(p_payload->>'expired_at', '')::timestamptz;

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
    or v_order_status not in (
      'awaitingPayment', 'paymentToVerify', 'paidReady', 'inProgress', 'onHold',
      'awaitingCustomerConfirmation', 'completed', 'failed', 'expired',
      'cancelled', 'refundPending', 'refunded'
    )
    or v_payment_status not in (
      'notDeclared', 'pending', 'declared', 'confirmed', 'credit', 'rejected', 'expired'
    )
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
      or v_existing.service <> v_service
      or v_existing.network <> v_network
      or v_existing.operation_type <> v_operation_type
      or coalesce(v_existing.offer_id, '') <> coalesce(v_offer_id, '')
      or v_existing.offer_label <> v_offer_label
      or v_existing.is_custom_offer <> v_is_custom_offer
      or v_existing.amount <> v_amount
      or v_existing.beneficiary_phone <> v_beneficiary
    then
      raise exception 'RECOVERY_REGISTRATION_CONFLICT' using errcode = '23505';
    end if;

    update public.customer_order_recovery_registry
    set order_status = v_order_status,
        payment_status = v_payment_status,
        payment_declared_at = v_payment_declared_at,
        payment_confirmed_at = v_payment_confirmed_at,
        expired_at = v_expired_at,
        updated_at = now()
    where order_id = v_order_id;

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
    expires_at,
    order_status,
    payment_status,
    payment_declared_at,
    payment_confirmed_at,
    expired_at
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
    v_expires_at,
    v_order_status,
    v_payment_status,
    v_payment_declared_at,
    v_payment_confirmed_at,
    v_expired_at
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
    'order_status', coalesce(v_order.order_status, v_registry.order_status),
    'payment_status', coalesce(v_order.payment_status, v_registry.payment_status),
    'payment_declared_at', v_registry.payment_declared_at,
    'payment_confirmed_at', coalesce(v_order.payment_confirmed_at, v_registry.payment_confirmed_at),
    'expired_at', v_registry.expired_at,
    'processing_started_at', v_order.processing_started_at,
    'completed_at', v_order.completed_at,
    'failure_reason', v_order.failure_reason,
    'observation', v_order.observation,
    'customer_confirmation_status', v_order.customer_confirmation_status,
    'updated_at', coalesce(v_order.updated_at, v_registry.updated_at)
  );
end;
$function$;
