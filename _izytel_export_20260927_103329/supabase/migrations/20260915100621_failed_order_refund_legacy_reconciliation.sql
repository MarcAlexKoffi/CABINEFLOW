create or replace function public.izytel_create_refund(
  p_order_id text,
  p_order_reference text,
  p_origin text,
  p_support_request_id text,
  p_amount bigint,
  p_reason text,
  p_reason_note text
)
returns public.refunds
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
  v_order public.phase4_assignment_orders;
  v_support public.support_requests;
  v_support_id text := nullif(btrim(coalesce(p_support_request_id, '')), '');
  v_support_type text := '';
  v_support_description text := '';
  v_result public.refunds;
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if p_origin not in ('supportRequest', 'failedOrder', 'manual') then
    raise exception 'REFUND_ORIGIN_INVALID';
  end if;
  if p_reason not in ('serviceNotReceived','transactionFailed','wrongAmount','wrongNumber','duplicatePayment','cancellation','paymentIssue','other') then
    raise exception 'REFUND_REASON_INVALID';
  end if;
  if char_length(btrim(coalesce(p_reason_note, ''))) > 500
     or (p_reason = 'other' and char_length(btrim(coalesce(p_reason_note, ''))) < 3) then
    raise exception 'REFUND_REASON_NOTE_INVALID';
  end if;

  select * into v_order
  from public.phase4_assignment_orders
  where order_id = btrim(p_order_id)
  for update;

  if not found or upper(v_order.order_reference) <> upper(btrim(p_order_reference)) then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  if v_order.payment_status <> 'confirmed' then
    raise exception 'CONFIRMED_WAVE_PAYMENT_REQUIRED';
  end if;
  if p_amount <= 0 or p_amount > v_order.amount then
    raise exception 'REFUND_AMOUNT_INVALID';
  end if;
  if v_order.order_status in ('refundPending', 'refunded') then
    raise exception 'REFUND_STATE_ALREADY_ACTIVE';
  end if;
  if exists (select 1 from public.refunds where order_id = v_order.order_id) then
    raise exception 'REFUND_ALREADY_EXISTS';
  end if;

  if p_origin = 'supportRequest' then
    if v_support_id is null then raise exception 'SUPPORT_REQUEST_REQUIRED'; end if;
    select * into v_support
    from public.support_requests
    where id = v_support_id and order_id = v_order.order_id
    limit 1;
    if not found or v_support.status not in ('new', 'inProgress', 'resolved') then
      raise exception 'SUPPORT_REQUEST_INVALID';
    end if;
    v_support_type := v_support.type;
    v_support_description := v_support.description;
  elsif p_origin = 'failedOrder' then
    if v_order.order_status <> 'failed' then
      if coalesce(v_order.legacy_state_unresolved, false) then
        update public.phase4_assignment_orders
        set order_status = 'failed',
            failure_reason = coalesce(failure_reason, 'other'),
            observation = coalesce(
              nullif(btrim(observation), ''),
              nullif(btrim(coalesce(p_reason_note, '')), ''),
              'Commande echouee'
            ),
            completed_at = coalesce(completed_at, updated_at, now()),
            legacy_state_unresolved = false,
            updated_at = now()
        where order_id = v_order.order_id
        returning * into v_order;
      else
        raise exception 'FAILED_ORDER_REQUIRED';
      end if;
    end if;
    v_support_id := null;
    v_support_type := 'transactionFailed';
    v_support_description := coalesce(v_order.observation, 'Commande echouee');
  else
    v_support_id := null;
  end if;

  insert into public.refunds (
    order_id, order_reference, origin, support_request_id,
    support_request_type, support_request_description,
    customer_auth_uid, client_name, client_whatsapp_phone,
    original_amount, amount, reason, reason_note, payment_channel,
    original_payment_reference, status, order_status_before_refund,
    requested_at, requested_by, requested_by_name, updated_at
  ) values (
    v_order.order_id,
    v_order.order_reference,
    p_origin,
    v_support_id,
    v_support_type,
    v_support_description,
    v_order.customer_auth_uid,
    v_order.client_name,
    v_order.client_whatsapp_phone,
    v_order.amount,
    p_amount,
    p_reason,
    btrim(coalesce(p_reason_note, '')),
    'wave',
    v_order.payment_reference,
    'pendingApproval',
    v_order.order_status,
    now(),
    v_uid,
    v_name,
    now()
  ) returning * into v_result;

  update public.phase4_assignment_orders
  set order_status = 'refundPending', updated_at = now()
  where order_id = v_order.order_id;

  return v_result;
end;
$$;
