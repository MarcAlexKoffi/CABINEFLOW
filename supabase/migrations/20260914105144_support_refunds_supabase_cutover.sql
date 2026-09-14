-- IzyTel - Support + Remboursements : cutover opérationnel Supabase.
-- Firestore reste uniquement une source legacy lue par le backfill ponctuel.

create table if not exists public.support_requests (
  id text primary key default gen_random_uuid()::text,
  order_id text not null,
  order_reference text not null,
  customer_auth_uid text not null,
  type text not null check (type in (
    'paymentNotRecognized','completedButNotReceived','wrongAmount',
    'wrongNumber','transactionFailed','other'
  )),
  description text not null default '' check (char_length(description) <= 1000),
  status text not null default 'new'
    check (status in ('new','inProgress','resolved','closed')),
  assigned_to text,
  assigned_to_name text,
  in_progress_at timestamptz,
  resolution_note text check (resolution_note is null or char_length(resolution_note) <= 1000),
  resolved_at timestamptz,
  resolved_by text,
  resolved_by_name text,
  customer_notified_at timestamptz,
  customer_notified_by text,
  customer_notified_by_name text,
  notification_channel text check (notification_channel is null or notification_channel = 'whatsapp'),
  closed_at timestamptz,
  closed_by text,
  closed_by_name text,
  legacy_firestore_id text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists support_requests_order_id_idx
  on public.support_requests(order_id);
create index if not exists support_requests_status_updated_idx
  on public.support_requests(status, updated_at desc);
create index if not exists support_requests_customer_idx
  on public.support_requests(customer_auth_uid, created_at desc);

create table if not exists public.refunds (
  order_id text primary key,
  order_reference text not null,
  origin text not null check (origin in ('supportRequest','failedOrder','manual')),
  support_request_id text references public.support_requests(id) on delete set null,
  support_request_type text not null default '',
  support_request_description text not null default ''
    check (char_length(support_request_description) <= 1000),
  customer_auth_uid text,
  client_name text not null,
  client_whatsapp_phone text not null default '',
  original_amount bigint not null check (original_amount > 0),
  amount bigint not null check (amount > 0 and amount <= original_amount),
  reason text not null check (reason in (
    'serviceNotReceived','transactionFailed','wrongAmount','wrongNumber',
    'duplicatePayment','cancellation','paymentIssue','other'
  )),
  reason_note text not null default '' check (char_length(reason_note) <= 500),
  payment_channel text not null default 'wave' check (payment_channel = 'wave'),
  original_payment_reference text,
  status text not null default 'pendingApproval'
    check (status in ('pendingApproval','approved','refunded','reconciled','rejected')),
  order_status_before_refund text not null,
  requested_at timestamptz not null default now(),
  requested_by text not null,
  requested_by_name text not null,
  approved_at timestamptz,
  approved_by text,
  approved_by_name text,
  rejected_at timestamptz,
  rejected_by text,
  rejected_by_name text,
  rejection_reason text check (rejection_reason is null or char_length(rejection_reason) between 3 and 500),
  refund_reference text check (refund_reference is null or char_length(refund_reference) between 3 and 120),
  refunded_at timestamptz,
  refunded_by text,
  refunded_by_name text,
  customer_notified_at timestamptz,
  customer_notified_by text,
  customer_notified_by_name text,
  notification_channel text check (notification_channel is null or notification_channel = 'whatsapp'),
  reconciled_at timestamptz,
  reconciled_by text,
  reconciled_by_name text,
  legacy_firestore_id text unique,
  updated_at timestamptz not null default now()
);

create index if not exists refunds_status_updated_idx
  on public.refunds(status, updated_at desc);
create index if not exists refunds_support_request_idx
  on public.refunds(support_request_id)
  where support_request_id is not null;

alter table public.support_requests enable row level security;
alter table public.refunds enable row level security;

drop policy if exists "support customer or staff read" on public.support_requests;
create policy "support customer or staff read"
on public.support_requests for select to anon, authenticated
using (
  public.is_izytel_firebase_jwt()
  and (
    customer_auth_uid = (select auth.jwt()->>'sub')
    or (select private.is_izytel_finance_staff())
  )
);

drop policy if exists "refund staff read" on public.refunds;
create policy "refund staff read"
on public.refunds for select to anon, authenticated
using ((select private.is_izytel_finance_staff()));

create or replace function private.izytel_staff_display_name()
returns text
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    nullif(btrim(staff.display_name), ''),
    nullif((select auth.jwt()->>'name'), ''),
    nullif((select auth.jwt()->>'email'), ''),
    (select auth.jwt()->>'sub'),
    'Staff IzyTel'
  )
  from public.izytel_staff_access staff
  where staff.firebase_uid = (select auth.jwt()->>'sub')
    and staff.is_active = true
  limit 1;
$$;

create or replace function public.izytel_create_support_request(
  p_order_id text,
  p_order_reference text,
  p_type text,
  p_description text
)
returns public.support_requests
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_order public.phase4_assignment_orders;
  v_result public.support_requests;
begin
  if not public.is_izytel_firebase_jwt() or nullif(btrim(v_uid), '') is null then
    raise exception 'SESSION_REQUIRED';
  end if;
  if p_type not in (
    'paymentNotRecognized','completedButNotReceived','wrongAmount',
    'wrongNumber','transactionFailed','other'
  ) then
    raise exception 'SUPPORT_TYPE_INVALID';
  end if;
  if char_length(btrim(coalesce(p_description, ''))) > 1000
     or (p_type = 'other' and char_length(btrim(coalesce(p_description, ''))) < 3) then
    raise exception 'SUPPORT_DESCRIPTION_INVALID';
  end if;

  select * into v_order
  from public.phase4_assignment_orders
  where order_id = btrim(p_order_id)
  limit 1;

  if not found
     or upper(v_order.order_reference) <> upper(btrim(p_order_reference))
     or coalesce(v_order.customer_auth_uid, '') <> v_uid then
    raise exception 'ORDER_NOT_OWNED';
  end if;

  insert into public.support_requests (
    order_id, order_reference, customer_auth_uid, type, description,
    status, created_at, updated_at
  ) values (
    v_order.order_id, v_order.order_reference, v_uid, p_type,
    btrim(coalesce(p_description, '')), 'new', now(), now()
  ) returning * into v_result;
  return v_result;
end;
$$;

create or replace function public.izytel_take_support_request(p_request_id text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  update public.support_requests
  set status='inProgress', assigned_to=v_uid, assigned_to_name=v_name,
      in_progress_at=now(), updated_at=now()
  where id=btrim(p_request_id) and status='new';
  if not found then raise exception 'SUPPORT_TRANSITION_INVALID'; end if;
end;
$$;

create or replace function public.izytel_resolve_support_request(
  p_request_id text,
  p_resolution_note text
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
  v_note text := btrim(coalesce(p_resolution_note, ''));
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if char_length(v_note) < 3 or char_length(v_note) > 1000 then
    raise exception 'RESOLUTION_NOTE_INVALID';
  end if;
  update public.support_requests
  set status='resolved', resolution_note=v_note, resolved_at=now(),
      resolved_by=v_uid, resolved_by_name=v_name, updated_at=now()
  where id=btrim(p_request_id) and status='inProgress';
  if not found then raise exception 'SUPPORT_TRANSITION_INVALID'; end if;
end;
$$;

create or replace function public.izytel_mark_support_customer_notified(p_request_id text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  update public.support_requests
  set customer_notified_at=now(), customer_notified_by=v_uid,
      customer_notified_by_name=v_name, notification_channel='whatsapp',
      updated_at=now()
  where id=btrim(p_request_id)
    and status in ('resolved','closed')
    and customer_notified_at is null;
  if not found then raise exception 'SUPPORT_NOTIFICATION_INVALID'; end if;
end;
$$;

create or replace function public.izytel_close_support_request(p_request_id text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  update public.support_requests
  set status='closed', closed_at=now(), closed_by=v_uid,
      closed_by_name=v_name, updated_at=now()
  where id=btrim(p_request_id)
    and status='resolved'
    and customer_notified_at is not null;
  if not found then raise exception 'SUPPORT_CLOSE_INVALID'; end if;
end;
$$;

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
language plpgsql security definer set search_path = ''
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
  if p_reason not in (
    'serviceNotReceived','transactionFailed','wrongAmount','wrongNumber',
    'duplicatePayment','cancellation','paymentIssue','other'
  ) then
    raise exception 'REFUND_REASON_INVALID';
  end if;
  if char_length(btrim(coalesce(p_reason_note, ''))) > 500
     or (p_reason='other' and char_length(btrim(coalesce(p_reason_note, ''))) < 3) then
    raise exception 'REFUND_REASON_NOTE_INVALID';
  end if;

  select * into v_order
  from public.phase4_assignment_orders
  where order_id=btrim(p_order_id)
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
  if v_order.order_status in ('refundPending','refunded') then
    raise exception 'REFUND_STATE_ALREADY_ACTIVE';
  end if;
  if exists (select 1 from public.refunds where order_id=v_order.order_id) then
    raise exception 'REFUND_ALREADY_EXISTS';
  end if;

  if p_origin='supportRequest' then
    if v_support_id is null then raise exception 'SUPPORT_REQUEST_REQUIRED'; end if;
    select * into v_support
    from public.support_requests
    where id=v_support_id and order_id=v_order.order_id
    limit 1;
    if not found or v_support.status not in ('new','inProgress','resolved') then
      raise exception 'SUPPORT_REQUEST_INVALID';
    end if;
    v_support_type := v_support.type;
    v_support_description := v_support.description;
  elsif p_origin='failedOrder' then
    if v_order.order_status <> 'failed' then raise exception 'FAILED_ORDER_REQUIRED'; end if;
    v_support_id := null;
    v_support_type := 'transactionFailed';
    v_support_description := coalesce(v_order.observation, 'Commande échouée');
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
    v_order.order_id, v_order.order_reference, p_origin, v_support_id,
    v_support_type, v_support_description, v_order.customer_auth_uid,
    v_order.client_name, v_order.client_whatsapp_phone, v_order.amount,
    p_amount, p_reason, btrim(coalesce(p_reason_note, '')), 'wave',
    v_order.payment_reference, 'pendingApproval', v_order.order_status,
    now(), v_uid, v_name, now()
  ) returning * into v_result;

  update public.phase4_assignment_orders
  set order_status='refundPending', updated_at=now()
  where order_id=v_order.order_id;
  return v_result;
end;
$$;

create or replace function public.izytel_approve_refund(p_order_id text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  update public.refunds
  set status='approved', approved_at=now(), approved_by=v_uid,
      approved_by_name=v_name, updated_at=now()
  where order_id=btrim(p_order_id) and status='pendingApproval';
  if not found then raise exception 'REFUND_TRANSITION_INVALID'; end if;
end;
$$;

create or replace function public.izytel_reject_refund(p_order_id text, p_reason text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
  v_previous_status text;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if char_length(v_reason) < 3 or char_length(v_reason) > 500 then
    raise exception 'REFUND_REJECTION_REASON_INVALID';
  end if;
  select order_status_before_refund into v_previous_status
  from public.refunds
  where order_id=btrim(p_order_id) and status='pendingApproval'
  for update;
  if not found then raise exception 'REFUND_TRANSITION_INVALID'; end if;

  update public.refunds
  set status='rejected', rejected_at=now(), rejected_by=v_uid,
      rejected_by_name=v_name, rejection_reason=v_reason, updated_at=now()
  where order_id=btrim(p_order_id);

  update public.phase4_assignment_orders
  set order_status=v_previous_status, updated_at=now()
  where order_id=btrim(p_order_id) and order_status='refundPending';
end;
$$;

create or replace function public.izytel_mark_refund_paid(
  p_order_id text,
  p_refund_reference text
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
  v_reference text := btrim(coalesce(p_refund_reference, ''));
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if char_length(v_reference) < 3 or char_length(v_reference) > 120 then
    raise exception 'REFUND_REFERENCE_INVALID';
  end if;
  update public.refunds
  set status='refunded', refund_reference=v_reference, refunded_at=now(),
      refunded_by=v_uid, refunded_by_name=v_name, updated_at=now()
  where order_id=btrim(p_order_id) and status='approved';
  if not found then raise exception 'REFUND_TRANSITION_INVALID'; end if;

  update public.phase4_assignment_orders
  set order_status='refunded', updated_at=now()
  where order_id=btrim(p_order_id);
end;
$$;

create or replace function public.izytel_mark_refund_customer_notified(p_order_id text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  update public.refunds
  set customer_notified_at=now(), customer_notified_by=v_uid,
      customer_notified_by_name=v_name, notification_channel='whatsapp',
      updated_at=now()
  where order_id=btrim(p_order_id)
    and status in ('refunded','reconciled')
    and customer_notified_at is null;
  if not found then raise exception 'REFUND_NOTIFICATION_INVALID'; end if;
end;
$$;

create or replace function public.izytel_reconcile_refund(p_order_id text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  update public.refunds
  set status='reconciled', reconciled_at=now(), reconciled_by=v_uid,
      reconciled_by_name=v_name, updated_at=now()
  where order_id=btrim(p_order_id) and status='refunded';
  if not found then raise exception 'REFUND_TRANSITION_INVALID'; end if;
end;
$$;

-- Backfill Firestore ponctuel, idempotent et Admin-only.
create or replace function public.izytel_import_legacy_support_request(p_payload jsonb)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_id text := nullif(btrim(coalesce(p_payload->>'id','')), '');
  v_order_id text := nullif(btrim(coalesce(p_payload->>'orderId','')), '');
  v_reference text := nullif(btrim(coalesce(p_payload->>'orderReference','')), '');
  v_customer text := nullif(btrim(coalesce(p_payload->>'customerAuthUid','')), '');
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if v_id is null or v_order_id is null or v_reference is null or v_customer is null then
    raise exception 'LEGACY_SUPPORT_INVALID';
  end if;

  insert into public.support_requests (
    id, order_id, order_reference, customer_auth_uid, type, description, status,
    assigned_to, assigned_to_name, in_progress_at, resolution_note,
    resolved_at, resolved_by, resolved_by_name, customer_notified_at,
    customer_notified_by, customer_notified_by_name, notification_channel,
    closed_at, closed_by, closed_by_name, legacy_firestore_id,
    created_at, updated_at
  ) values (
    v_id, v_order_id, v_reference, v_customer,
    case when p_payload->>'type' in (
      'paymentNotRecognized','completedButNotReceived','wrongAmount',
      'wrongNumber','transactionFailed','other'
    ) then p_payload->>'type' else 'other' end,
    left(coalesce(p_payload->>'description',''), 1000),
    case when p_payload->>'status' in ('new','inProgress','resolved','closed')
      then p_payload->>'status' else 'new' end,
    nullif(p_payload->>'assignedTo',''),
    nullif(p_payload->>'assignedToName',''),
    nullif(p_payload->>'inProgressAt','')::timestamptz,
    left(nullif(p_payload->>'resolutionNote',''), 1000),
    nullif(p_payload->>'resolvedAt','')::timestamptz,
    nullif(p_payload->>'resolvedBy',''),
    nullif(p_payload->>'resolvedByName',''),
    nullif(p_payload->>'customerNotifiedAt','')::timestamptz,
    nullif(p_payload->>'customerNotifiedBy',''),
    nullif(p_payload->>'customerNotifiedByName',''),
    case when p_payload->>'notificationChannel'='whatsapp' then 'whatsapp' else null end,
    nullif(p_payload->>'closedAt','')::timestamptz,
    nullif(p_payload->>'closedBy',''),
    nullif(p_payload->>'closedByName',''),
    v_id,
    coalesce(nullif(p_payload->>'createdAt','')::timestamptz, now()),
    coalesce(nullif(p_payload->>'updatedAt','')::timestamptz, now())
  ) on conflict (id) do nothing;
end;
$$;

create or replace function public.izytel_import_legacy_refund(p_payload jsonb)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_order_id text := nullif(btrim(coalesce(p_payload->>'orderId','')), '');
  v_reference text := nullif(btrim(coalesce(p_payload->>'orderReference','')), '');
  v_support_id text := nullif(btrim(coalesce(p_payload->>'supportRequestId','')), '');
  v_origin text := coalesce(nullif(p_payload->>'origin',''), 'supportRequest');
  v_status text := coalesce(nullif(p_payload->>'status',''), 'pendingApproval');
  v_current_order_status text;
  v_original_amount bigint;
  v_amount bigint;
  v_linked_support_id text;
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if v_order_id is null or v_reference is null then raise exception 'LEGACY_REFUND_INVALID'; end if;

  if left(coalesce(v_support_id,''), 7)='failed_' then
    v_origin := 'failedOrder';
    v_support_id := null;
  end if;
  if v_origin not in ('supportRequest','failedOrder','manual') then
    v_origin := 'supportRequest';
  end if;
  if v_status not in ('pendingApproval','approved','refunded','reconciled','rejected') then
    v_status := 'pendingApproval';
  end if;

  v_original_amount := greatest(
    coalesce(nullif(p_payload->>'originalAmount','')::bigint, 0), 1
  );
  v_amount := least(
    v_original_amount,
    greatest(coalesce(nullif(p_payload->>'amount','')::bigint, v_original_amount), 1)
  );

  if v_origin='supportRequest' and v_support_id is not null and exists (
    select 1 from public.support_requests where id=v_support_id
  ) then
    v_linked_support_id := v_support_id;
  else
    v_linked_support_id := null;
  end if;

  select order_status into v_current_order_status
  from public.phase4_assignment_orders
  where order_id=v_order_id;
  v_current_order_status := coalesce(v_current_order_status, 'failed');

  insert into public.refunds (
    order_id, order_reference, origin, support_request_id,
    support_request_type, support_request_description,
    customer_auth_uid, client_name, client_whatsapp_phone,
    original_amount, amount, reason, reason_note, payment_channel,
    original_payment_reference, status, order_status_before_refund,
    requested_at, requested_by, requested_by_name,
    approved_at, approved_by, approved_by_name,
    rejected_at, rejected_by, rejected_by_name, rejection_reason,
    refund_reference, refunded_at, refunded_by, refunded_by_name,
    customer_notified_at, customer_notified_by, customer_notified_by_name,
    notification_channel, reconciled_at, reconciled_by, reconciled_by_name,
    legacy_firestore_id, updated_at
  ) values (
    v_order_id, v_reference, v_origin, v_linked_support_id,
    coalesce(p_payload->>'supportRequestType',''),
    left(coalesce(p_payload->>'supportRequestDescription',''), 1000),
    nullif(p_payload->>'customerAuthUid',''),
    coalesce(nullif(p_payload->>'clientName',''), 'Client'),
    coalesce(p_payload->>'clientWhatsappPhone',''),
    v_original_amount, v_amount,
    case when p_payload->>'reason' in (
      'serviceNotReceived','transactionFailed','wrongAmount','wrongNumber',
      'duplicatePayment','cancellation','paymentIssue','other'
    ) then p_payload->>'reason' else 'other' end,
    left(coalesce(p_payload->>'reasonNote',''), 500),
    'wave', nullif(p_payload->>'originalPaymentReference',''),
    v_status, v_current_order_status,
    coalesce(nullif(p_payload->>'requestedAt','')::timestamptz, now()),
    coalesce(nullif(p_payload->>'requestedBy',''), 'legacy_firestore'),
    coalesce(nullif(p_payload->>'requestedByName',''), 'Migration Firestore'),
    nullif(p_payload->>'approvedAt','')::timestamptz,
    nullif(p_payload->>'approvedBy',''),
    nullif(p_payload->>'approvedByName',''),
    nullif(p_payload->>'rejectedAt','')::timestamptz,
    nullif(p_payload->>'rejectedBy',''),
    nullif(p_payload->>'rejectedByName',''),
    case when char_length(btrim(coalesce(p_payload->>'rejectionReason',''))) between 3 and 500
      then left(btrim(p_payload->>'rejectionReason'), 500) else null end,
    case when char_length(btrim(coalesce(p_payload->>'refundReference',''))) between 3 and 120
      then left(btrim(p_payload->>'refundReference'), 120) else null end,
    nullif(p_payload->>'refundedAt','')::timestamptz,
    nullif(p_payload->>'refundedBy',''),
    nullif(p_payload->>'refundedByName',''),
    nullif(p_payload->>'customerNotifiedAt','')::timestamptz,
    nullif(p_payload->>'customerNotifiedBy',''),
    nullif(p_payload->>'customerNotifiedByName',''),
    case when p_payload->>'notificationChannel'='whatsapp' then 'whatsapp' else null end,
    nullif(p_payload->>'reconciledAt','')::timestamptz,
    nullif(p_payload->>'reconciledBy',''),
    nullif(p_payload->>'reconciledByName',''),
    coalesce(nullif(p_payload->>'id',''), v_order_id),
    coalesce(nullif(p_payload->>'updatedAt','')::timestamptz, now())
  ) on conflict (order_id) do nothing;

  if v_status in ('refunded','reconciled') then
    update public.phase4_assignment_orders
    set order_status='refunded', updated_at=now()
    where order_id=v_order_id;
  elsif v_status in ('pendingApproval','approved') then
    update public.phase4_assignment_orders
    set order_status='refundPending', updated_at=now()
    where order_id=v_order_id;
  end if;
end;
$$;

revoke all on public.support_requests from anon, authenticated;
revoke all on public.refunds from anon, authenticated;
grant select on public.support_requests to anon, authenticated;
grant select on public.refunds to anon, authenticated;

revoke all on function public.izytel_create_support_request(text,text,text,text) from public;
revoke all on function public.izytel_take_support_request(text) from public;
revoke all on function public.izytel_resolve_support_request(text,text) from public;
revoke all on function public.izytel_mark_support_customer_notified(text) from public;
revoke all on function public.izytel_close_support_request(text) from public;
revoke all on function public.izytel_create_refund(text,text,text,text,bigint,text,text) from public;
revoke all on function public.izytel_approve_refund(text) from public;
revoke all on function public.izytel_reject_refund(text,text) from public;
revoke all on function public.izytel_mark_refund_paid(text,text) from public;
revoke all on function public.izytel_mark_refund_customer_notified(text) from public;
revoke all on function public.izytel_reconcile_refund(text) from public;
revoke all on function public.izytel_import_legacy_support_request(jsonb) from public;
revoke all on function public.izytel_import_legacy_refund(jsonb) from public;

grant execute on function public.izytel_create_support_request(text,text,text,text) to anon, authenticated;
grant execute on function public.izytel_take_support_request(text) to anon, authenticated;
grant execute on function public.izytel_resolve_support_request(text,text) to anon, authenticated;
grant execute on function public.izytel_mark_support_customer_notified(text) to anon, authenticated;
grant execute on function public.izytel_close_support_request(text) to anon, authenticated;
grant execute on function public.izytel_create_refund(text,text,text,text,bigint,text,text) to anon, authenticated;
grant execute on function public.izytel_approve_refund(text) to anon, authenticated;
grant execute on function public.izytel_reject_refund(text,text) to anon, authenticated;
grant execute on function public.izytel_mark_refund_paid(text,text) to anon, authenticated;
grant execute on function public.izytel_mark_refund_customer_notified(text) to anon, authenticated;
grant execute on function public.izytel_reconcile_refund(text) to anon, authenticated;
grant execute on function public.izytel_import_legacy_support_request(jsonb) to anon, authenticated;
grant execute on function public.izytel_import_legacy_refund(jsonb) to anon, authenticated;
