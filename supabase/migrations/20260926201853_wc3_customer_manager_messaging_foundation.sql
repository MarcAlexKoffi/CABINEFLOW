-- IzyTel Web Client V2 - WC3A : messagerie interne Client -> Manager.
-- Supabase est canonique. Aucun nouveau controle Firestore n'est introduit.

create table if not exists public.customer_order_recovery_access (
  order_id text not null,
  order_reference text not null,
  customer_firebase_uid text not null,
  granted_at timestamptz not null default now(),
  primary key (order_id, customer_firebase_uid),
  constraint customer_order_recovery_access_order_check
    check (char_length(btrim(order_id)) between 8 and 128),
  constraint customer_order_recovery_access_reference_check
    check (order_reference ~ '^CF-[0-9]{8}-[A-Z0-9]{4,12}$'),
  constraint customer_order_recovery_access_uid_check
    check (char_length(btrim(customer_firebase_uid)) between 8 and 256)
);

alter table public.customer_order_recovery_access enable row level security;
revoke all on table public.customer_order_recovery_access from public, anon, authenticated;

drop policy if exists customer_order_recovery_access_rpc_only
  on public.customer_order_recovery_access;
create policy customer_order_recovery_access_rpc_only
  on public.customer_order_recovery_access
  for all
  to anon, authenticated
  using (false)
  with check (false);

create table if not exists public.customer_conversations (
  id text primary key default gen_random_uuid()::text,
  customer_auth_uid text not null,
  order_id text,
  order_reference text,
  status text not null default 'open'
    check (status in ('open', 'inProgress', 'resolved', 'closed')),
  assigned_manager_uid text,
  assigned_manager_name text,
  source text not null default 'customerWeb'
    check (source in ('customerWeb', 'system')),
  last_message_at timestamptz not null default now(),
  last_message_preview text not null default ''
    check (char_length(last_message_preview) <= 240),
  last_sender_type text not null default 'client'
    check (last_sender_type in ('client', 'manager', 'system')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customer_conversations_customer_uid_check
    check (char_length(btrim(customer_auth_uid)) between 8 and 256),
  constraint customer_conversations_order_pair_check
    check (
      (order_id is null and order_reference is null)
      or
      (
        order_id is not null
        and order_reference is not null
        and char_length(btrim(order_id)) between 8 and 128
        and order_reference ~ '^CF-[0-9]{8}-[A-Z0-9]{4,12}$'
      )
    )
);

create index if not exists customer_conversations_customer_updated_idx
  on public.customer_conversations(customer_auth_uid, updated_at desc);
create index if not exists customer_conversations_manager_status_idx
  on public.customer_conversations(assigned_manager_uid, status, updated_at desc);
create index if not exists customer_conversations_open_updated_idx
  on public.customer_conversations(status, updated_at desc)
  where assigned_manager_uid is null;
create index if not exists customer_conversations_order_idx
  on public.customer_conversations(order_id, updated_at desc)
  where order_id is not null;

create table if not exists public.customer_messages (
  id text primary key default gen_random_uuid()::text,
  conversation_id text not null
    references public.customer_conversations(id) on delete cascade,
  sender_type text not null
    check (sender_type in ('client', 'manager', 'system')),
  sender_uid text,
  sender_name text,
  body text not null
    check (char_length(btrim(body)) between 1 and 2000),
  message_kind text not null default 'text'
    check (message_kind in ('text', 'system')),
  created_at timestamptz not null default now()
);

create index if not exists customer_messages_conversation_created_idx
  on public.customer_messages(conversation_id, created_at asc);

alter table public.customer_conversations enable row level security;
alter table public.customer_messages enable row level security;

revoke insert, update, delete on table public.customer_conversations
  from public, anon, authenticated;
revoke insert, update, delete on table public.customer_messages
  from public, anon, authenticated;
grant select on table public.customer_conversations to anon, authenticated;
grant select on table public.customer_messages to anon, authenticated;

create or replace function private.izytel_wc3_is_manager()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select public.is_izytel_firebase_jwt()
    and exists (
      select 1
      from public.izytel_staff_access staff
      where staff.firebase_uid = (select auth.jwt()->>'sub')
        and staff.is_active = true
        and staff.role in ('manager', 'supervisor')
    );
$function$;

create or replace function private.izytel_wc3_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select private.is_izytel_finance_admin();
$function$;

create or replace function private.izytel_wc3_customer_has_order_access(
  p_order_id text,
  p_order_reference text,
  p_customer_uid text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.phase4_assignment_orders order_row
    where order_row.order_id = btrim(coalesce(p_order_id, ''))
      and upper(order_row.order_reference) = upper(btrim(coalesce(p_order_reference, '')))
      and coalesce(order_row.customer_auth_uid, '') = btrim(coalesce(p_customer_uid, ''))
  ) or exists (
    select 1
    from public.customer_order_recovery_access access_row
    where access_row.order_id = btrim(coalesce(p_order_id, ''))
      and upper(access_row.order_reference) = upper(btrim(coalesce(p_order_reference, '')))
      and access_row.customer_firebase_uid = btrim(coalesce(p_customer_uid, ''))
  );
$function$;

create or replace function private.izytel_wc3_can_read_conversation(
  p_conversation_id text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select public.is_izytel_firebase_jwt()
    and exists (
      select 1
      from public.customer_conversations conversation_row
      where conversation_row.id = btrim(coalesce(p_conversation_id, ''))
        and (
          conversation_row.customer_auth_uid = (select auth.jwt()->>'sub')
          or private.izytel_wc3_is_admin()
          or (
            private.izytel_wc3_is_manager()
            and (
              conversation_row.assigned_manager_uid is null
              or conversation_row.assigned_manager_uid = (select auth.jwt()->>'sub')
            )
          )
        )
    );
$function$;

drop policy if exists customer_conversations_authorized_read
  on public.customer_conversations;
create policy customer_conversations_authorized_read
  on public.customer_conversations
  for select
  to anon, authenticated
  using (
    public.is_izytel_firebase_jwt()
    and (
      customer_auth_uid = (select auth.jwt()->>'sub')
      or private.izytel_wc3_is_admin()
      or (
        private.izytel_wc3_is_manager()
        and (
          assigned_manager_uid is null
          or assigned_manager_uid = (select auth.jwt()->>'sub')
        )
      )
    )
  );

drop policy if exists customer_messages_authorized_read
  on public.customer_messages;
create policy customer_messages_authorized_read
  on public.customer_messages
  for select
  to anon, authenticated
  using (private.izytel_wc3_can_read_conversation(conversation_id));

create or replace function private.izytel_wc3_create_conversation(
  p_order_id text,
  p_order_reference text,
  p_body text
)
returns public.customer_conversations
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := nullif(btrim((select auth.jwt()->>'sub')), '');
  v_order_id text := nullif(btrim(coalesce(p_order_id, '')), '');
  v_reference text := nullif(upper(btrim(coalesce(p_order_reference, ''))), '');
  v_body text := btrim(coalesce(p_body, ''));
  v_conversation public.customer_conversations;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'SESSION_REQUIRED' using errcode = '42501';
  end if;

  if char_length(v_body) < 1 or char_length(v_body) > 2000 then
    raise exception 'MESSAGE_INVALID' using errcode = '22023';
  end if;

  if (v_order_id is null) <> (v_reference is null) then
    raise exception 'ORDER_LINK_INVALID' using errcode = '22023';
  end if;

  if v_order_id is not null and not private.izytel_wc3_customer_has_order_access(
    v_order_id,
    v_reference,
    v_uid
  ) then
    raise exception 'ORDER_NOT_AUTHORIZED' using errcode = '42501';
  end if;

  insert into public.customer_conversations (
    customer_auth_uid,
    order_id,
    order_reference,
    status,
    source,
    last_message_at,
    last_message_preview,
    last_sender_type,
    created_at,
    updated_at
  ) values (
    v_uid,
    v_order_id,
    v_reference,
    'open',
    'customerWeb',
    now(),
    left(v_body, 240),
    'client',
    now(),
    now()
  ) returning * into v_conversation;

  insert into public.customer_messages (
    conversation_id,
    sender_type,
    sender_uid,
    sender_name,
    body,
    message_kind,
    created_at
  ) values (
    v_conversation.id,
    'client',
    v_uid,
    'Client',
    v_body,
    'text',
    now()
  );

  return v_conversation;
end;
$function$;

create or replace function private.izytel_wc3_send_client_message(
  p_conversation_id text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := nullif(btrim((select auth.jwt()->>'sub')), '');
  v_id text := btrim(coalesce(p_conversation_id, ''));
  v_body text := btrim(coalesce(p_body, ''));
  v_conversation public.customer_conversations;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'SESSION_REQUIRED' using errcode = '42501';
  end if;
  if char_length(v_body) < 1 or char_length(v_body) > 2000 then
    raise exception 'MESSAGE_INVALID' using errcode = '22023';
  end if;

  select * into v_conversation
  from public.customer_conversations
  where id = v_id
  for update;

  if not found or v_conversation.customer_auth_uid <> v_uid then
    raise exception 'CONVERSATION_NOT_AUTHORIZED' using errcode = '42501';
  end if;
  if v_conversation.status = 'closed' then
    raise exception 'CONVERSATION_CLOSED' using errcode = '22023';
  end if;

  insert into public.customer_messages (
    conversation_id,
    sender_type,
    sender_uid,
    sender_name,
    body,
    message_kind,
    created_at
  ) values (
    v_id,
    'client',
    v_uid,
    'Client',
    v_body,
    'text',
    now()
  );

  update public.customer_conversations
  set status = case
        when status = 'resolved' and assigned_manager_uid is not null then 'inProgress'
        when status = 'resolved' then 'open'
        else status
      end,
      last_message_at = now(),
      last_message_preview = left(v_body, 240),
      last_sender_type = 'client',
      updated_at = now()
  where id = v_id;
end;
$function$;

create or replace function private.izytel_wc3_take_conversation(
  p_conversation_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := nullif(btrim((select auth.jwt()->>'sub')), '');
  v_name text := private.izytel_staff_display_name();
  v_id text := btrim(coalesce(p_conversation_id, ''));
  v_conversation public.customer_conversations;
begin
  if not private.izytel_wc3_is_manager() or v_uid is null then
    raise exception 'MANAGER_REQUIRED' using errcode = '42501';
  end if;

  select * into v_conversation
  from public.customer_conversations
  where id = v_id
  for update;

  if not found then
    raise exception 'CONVERSATION_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_conversation.status = 'closed' then
    raise exception 'CONVERSATION_CLOSED' using errcode = '22023';
  end if;
  if v_conversation.assigned_manager_uid is not null
     and v_conversation.assigned_manager_uid <> v_uid then
    raise exception 'CONVERSATION_ALREADY_ASSIGNED' using errcode = '23505';
  end if;

  if v_conversation.assigned_manager_uid is null then
    update public.customer_conversations
    set status = 'inProgress',
        assigned_manager_uid = v_uid,
        assigned_manager_name = v_name,
        last_message_at = now(),
        last_message_preview = 'Un Manager IzyTel a pris en charge votre conversation.',
        last_sender_type = 'system',
        updated_at = now()
    where id = v_id;

    insert into public.customer_messages (
      conversation_id,
      sender_type,
      sender_uid,
      sender_name,
      body,
      message_kind,
      created_at
    ) values (
      v_id,
      'system',
      null,
      'IzyTel',
      'Un Manager IzyTel a pris en charge votre conversation.',
      'system',
      now()
    );
  elsif v_conversation.status = 'open' then
    update public.customer_conversations
    set status = 'inProgress', updated_at = now()
    where id = v_id;
  end if;
end;
$function$;

create or replace function private.izytel_wc3_send_manager_message(
  p_conversation_id text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := nullif(btrim((select auth.jwt()->>'sub')), '');
  v_name text := private.izytel_staff_display_name();
  v_id text := btrim(coalesce(p_conversation_id, ''));
  v_body text := btrim(coalesce(p_body, ''));
  v_conversation public.customer_conversations;
begin
  if not private.izytel_wc3_is_manager() or v_uid is null then
    raise exception 'MANAGER_REQUIRED' using errcode = '42501';
  end if;
  if char_length(v_body) < 1 or char_length(v_body) > 2000 then
    raise exception 'MESSAGE_INVALID' using errcode = '22023';
  end if;

  select * into v_conversation
  from public.customer_conversations
  where id = v_id
  for update;

  if not found
     or v_conversation.assigned_manager_uid is distinct from v_uid
     or v_conversation.status not in ('inProgress', 'open') then
    raise exception 'CONVERSATION_NOT_ASSIGNED' using errcode = '42501';
  end if;

  insert into public.customer_messages (
    conversation_id,
    sender_type,
    sender_uid,
    sender_name,
    body,
    message_kind,
    created_at
  ) values (
    v_id,
    'manager',
    v_uid,
    v_name,
    v_body,
    'text',
    now()
  );

  update public.customer_conversations
  set status = 'inProgress',
      last_message_at = now(),
      last_message_preview = left(v_body, 240),
      last_sender_type = 'manager',
      updated_at = now()
  where id = v_id;
end;
$function$;

create or replace function private.izytel_wc3_resolve_conversation(
  p_conversation_id text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := nullif(btrim((select auth.jwt()->>'sub')), '');
  v_id text := btrim(coalesce(p_conversation_id, ''));
  v_conversation public.customer_conversations;
begin
  if not private.izytel_wc3_is_manager() or v_uid is null then
    raise exception 'MANAGER_REQUIRED' using errcode = '42501';
  end if;

  select * into v_conversation
  from public.customer_conversations
  where id = v_id
  for update;

  if not found
     or v_conversation.assigned_manager_uid is distinct from v_uid
     or v_conversation.status <> 'inProgress' then
    raise exception 'CONVERSATION_NOT_ASSIGNED' using errcode = '42501';
  end if;

  insert into public.customer_messages (
    conversation_id,
    sender_type,
    sender_uid,
    sender_name,
    body,
    message_kind,
    created_at
  ) values (
    v_id,
    'system',
    null,
    'IzyTel',
    'La conversation a été marquée comme résolue. Vous pouvez répondre pour la rouvrir si nécessaire.',
    'system',
    now()
  );

  update public.customer_conversations
  set status = 'resolved',
      last_message_at = now(),
      last_message_preview = 'Conversation résolue',
      last_sender_type = 'system',
      updated_at = now()
  where id = v_id;
end;
$function$;

create or replace function public.izytel_wc3_create_conversation(
  p_order_id text,
  p_order_reference text,
  p_body text
)
returns public.customer_conversations
language sql
set search_path = ''
as $function$
  select private.izytel_wc3_create_conversation(p_order_id, p_order_reference, p_body);
$function$;

create or replace function public.izytel_wc3_send_client_message(
  p_conversation_id text,
  p_body text
)
returns void
language sql
set search_path = ''
as $function$
  select private.izytel_wc3_send_client_message(p_conversation_id, p_body);
$function$;

create or replace function public.izytel_wc3_take_conversation(
  p_conversation_id text
)
returns void
language sql
set search_path = ''
as $function$
  select private.izytel_wc3_take_conversation(p_conversation_id);
$function$;

create or replace function public.izytel_wc3_send_manager_message(
  p_conversation_id text,
  p_body text
)
returns void
language sql
set search_path = ''
as $function$
  select private.izytel_wc3_send_manager_message(p_conversation_id, p_body);
$function$;

create or replace function public.izytel_wc3_resolve_conversation(
  p_conversation_id text
)
returns void
language sql
set search_path = ''
as $function$
  select private.izytel_wc3_resolve_conversation(p_conversation_id);
$function$;

revoke all on function private.izytel_wc3_create_conversation(text,text,text) from public;
revoke all on function private.izytel_wc3_send_client_message(text,text) from public;
revoke all on function private.izytel_wc3_take_conversation(text) from public;
revoke all on function private.izytel_wc3_send_manager_message(text,text) from public;
revoke all on function private.izytel_wc3_resolve_conversation(text) from public;

grant execute on function private.izytel_wc3_create_conversation(text,text,text) to anon, authenticated;
grant execute on function private.izytel_wc3_send_client_message(text,text) to anon, authenticated;
grant execute on function private.izytel_wc3_take_conversation(text) to anon, authenticated;
grant execute on function private.izytel_wc3_send_manager_message(text,text) to anon, authenticated;
grant execute on function private.izytel_wc3_resolve_conversation(text) to anon, authenticated;

revoke all on function public.izytel_wc3_create_conversation(text,text,text) from public;
revoke all on function public.izytel_wc3_send_client_message(text,text) from public;
revoke all on function public.izytel_wc3_take_conversation(text) from public;
revoke all on function public.izytel_wc3_send_manager_message(text,text) from public;
revoke all on function public.izytel_wc3_resolve_conversation(text) from public;

grant execute on function public.izytel_wc3_create_conversation(text,text,text) to anon, authenticated;
grant execute on function public.izytel_wc3_send_client_message(text,text) to anon, authenticated;
grant execute on function public.izytel_wc3_take_conversation(text) to anon, authenticated;
grant execute on function public.izytel_wc3_send_manager_message(text,text) to anon, authenticated;
grant execute on function public.izytel_wc3_resolve_conversation(text) to anon, authenticated;

-- A recovery WC2 réussie donne désormais au nouvel appareil un accès Supabase
-- persistant à la commande, nécessaire pour la messagerie liée à la commande.
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
  v_uid text := nullif(btrim((select auth.jwt()->>'sub')), '');
  v_reference text := upper(btrim(coalesce(p_reference, '')));
  v_code text := upper(btrim(coalesce(p_recovery_code, '')));
  v_registry public.customer_order_recovery_registry;
  v_order public.phase4_assignment_orders;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
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

  insert into public.customer_order_recovery_access (
    order_id,
    order_reference,
    customer_firebase_uid,
    granted_at
  ) values (
    v_registry.order_id,
    v_registry.order_reference,
    v_uid,
    now()
  )
  on conflict (order_id, customer_firebase_uid)
  do update set
    order_reference = excluded.order_reference,
    granted_at = excluded.granted_at;

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

-- Realtime est best-effort, mais la messagerie doit pouvoir se mettre à jour
-- sans polling agressif lorsque le canal est disponible.
do $block$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'customer_conversations'
  ) then
    alter publication supabase_realtime add table public.customer_conversations;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'customer_messages'
  ) then
    alter publication supabase_realtime add table public.customer_messages;
  end if;
end;
$block$;
