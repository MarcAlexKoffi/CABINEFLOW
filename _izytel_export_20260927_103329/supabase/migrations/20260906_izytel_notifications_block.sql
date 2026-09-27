-- IzyTel Mobile Readiness - notifications Agent / Manager.
-- Isolation garantie : aucune regle Firestore et aucune fonction Phase 4 existante
-- n'est remplacee. Les triggers ci-dessous sont AFTER et tolerent les erreurs afin
-- qu'une panne de notification ne puisse jamais bloquer une affectation/refus.

create extension if not exists pg_net;

create table if not exists public.izytel_notification_devices (
  id uuid primary key default gen_random_uuid(),
  firebase_uid text not null,
  fcm_token text not null unique,
  platform text not null default 'android',
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint izytel_notification_devices_uid_nonempty
    check (char_length(btrim(firebase_uid)) > 0),
  constraint izytel_notification_devices_token_length
    check (char_length(btrim(fcm_token)) between 32 and 4096),
  constraint izytel_notification_devices_platform
    check (platform in ('android', 'ios', 'web', 'windows', 'macos', 'linux', 'fuchsia'))
);

create index if not exists izytel_notification_devices_uid_active_idx
  on public.izytel_notification_devices(firebase_uid, is_active);

alter table public.izytel_notification_devices enable row level security;
revoke all on table public.izytel_notification_devices from anon, authenticated;
grant all on table public.izytel_notification_devices to service_role;

create table if not exists public.izytel_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  recipient_uid text not null,
  event_type text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  attempt_count integer not null default 0,
  dispatch_nonce uuid not null default gen_random_uuid(),
  dedupe_key text unique,
  claimed_at timestamptz,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint izytel_notification_outbox_uid_nonempty
    check (char_length(btrim(recipient_uid)) > 0),
  constraint izytel_notification_outbox_event_nonempty
    check (char_length(btrim(event_type)) > 0),
  constraint izytel_notification_outbox_status
    check (status in ('pending', 'processing', 'sent', 'failed', 'skipped')),
  constraint izytel_notification_outbox_attempt_count
    check (attempt_count >= 0)
);

create index if not exists izytel_notification_outbox_pending_idx
  on public.izytel_notification_outbox(status, created_at)
  where status = 'pending';
create index if not exists izytel_notification_outbox_recipient_idx
  on public.izytel_notification_outbox(recipient_uid, created_at desc);

alter table public.izytel_notification_outbox enable row level security;
revoke all on table public.izytel_notification_outbox from anon, authenticated;
grant all on table public.izytel_notification_outbox to service_role;

create or replace function public.izytel_register_notification_device(
  p_token text,
  p_platform text default 'android'
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_token text := btrim(coalesce(p_token, ''));
  v_platform text := lower(btrim(coalesce(p_platform, 'android')));
  v_id uuid;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if char_length(v_token) < 32 or char_length(v_token) > 4096 then
    raise exception 'INVALID_FCM_TOKEN';
  end if;
  if v_platform not in ('android', 'ios', 'web', 'windows', 'macos', 'linux', 'fuchsia') then
    v_platform := 'android';
  end if;

  insert into public.izytel_notification_devices (
    firebase_uid, fcm_token, platform, is_active, last_seen_at, updated_at
  ) values (
    v_uid, v_token, v_platform, true, now(), now()
  )
  on conflict (fcm_token) do update set
    firebase_uid = excluded.firebase_uid,
    platform = excluded.platform,
    is_active = true,
    last_seen_at = now(),
    updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.izytel_register_notification_device(text, text) from public;
grant execute on function public.izytel_register_notification_device(text, text) to anon, authenticated;

create or replace function public.izytel_deactivate_notification_device(
  p_token text
)
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_token text := btrim(coalesce(p_token, ''));
  v_count integer;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if v_token = '' then return false; end if;

  update public.izytel_notification_devices
  set is_active = false, updated_at = now()
  where firebase_uid = v_uid and fcm_token = v_token and is_active = true;
  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

revoke all on function public.izytel_deactivate_notification_device(text) from public;
grant execute on function public.izytel_deactivate_notification_device(text) to anon, authenticated;

create or replace function public.izytel_claim_notification_batch(
  p_limit integer default 25
)
returns setof public.izytel_notification_outbox
language plpgsql
security definer
set search_path to ''
as $$
begin
  return query
  with picked as (
    select o.id
    from public.izytel_notification_outbox o
    where o.status = 'pending'
    order by o.created_at
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 25), 50))
  )
  update public.izytel_notification_outbox o
  set status = 'processing',
      attempt_count = o.attempt_count + 1,
      claimed_at = now(),
      updated_at = now()
  from picked
  where o.id = picked.id
  returning o.*;
end;
$$;

revoke all on function public.izytel_claim_notification_batch(integer) from public, anon, authenticated;
grant execute on function public.izytel_claim_notification_batch(integer) to service_role;

create or replace function private.enqueue_izytel_notification(
  p_recipient_uid text,
  p_event_type text,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb,
  p_dedupe_key text default null
)
returns void
language plpgsql
security definer
set search_path to ''
as $$
begin
  if nullif(btrim(coalesce(p_recipient_uid, '')), '') is null then return; end if;
  insert into public.izytel_notification_outbox (
    recipient_uid, event_type, title, body, data, dedupe_key
  ) values (
    btrim(p_recipient_uid),
    btrim(coalesce(p_event_type, 'generic')),
    left(coalesce(nullif(btrim(p_title), ''), 'IzyTel'), 160),
    left(coalesce(nullif(btrim(p_body), ''), 'Nouvelle notification IzyTel.'), 500),
    coalesce(p_data, '{}'::jsonb),
    nullif(btrim(coalesce(p_dedupe_key, '')), '')
  )
  on conflict (dedupe_key) do nothing;
end;
$$;

revoke all on function private.enqueue_izytel_notification(text, text, text, text, jsonb, text) from public, anon, authenticated;

create or replace function private.izytel_phase4_notification_trigger()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_changed boolean := false;
  v_is_reassignment boolean := false;
  v_type text;
  v_title text;
  v_body text;
  v_staff record;
begin
  begin
    if tg_op = 'INSERT' then
      v_changed := true;
    else
      v_changed := old.assignment_state is distinct from new.assignment_state
        or old.assigned_agent_id is distinct from new.assigned_agent_id
        or old.assigned_at is distinct from new.assigned_at;
    end if;

    if new.assignment_state = 'assigned'
       and nullif(btrim(coalesce(new.assigned_agent_id, '')), '') is not null
       and v_changed then
      v_is_reassignment := new.last_refused_agent_id is not null;
      if tg_op = 'UPDATE' and old.assigned_agent_id is distinct from new.assigned_agent_id then
        v_is_reassignment := true;
      end if;
      v_type := case when v_is_reassignment then 'order_reassigned' else 'order_assigned' end;
      v_title := case when v_is_reassignment then 'Commande reaffectee' else 'Nouvelle commande' end;
      v_body := new.order_reference || ' - ' || upper(coalesce(new.network, '')) ||
        ' - ' || new.amount::text || ' F';

      perform private.enqueue_izytel_notification(
        new.assigned_agent_id,
        v_type,
        v_title,
        v_body,
        jsonb_build_object(
          'type', v_type,
          'orderId', new.order_id,
          'orderReference', new.order_reference,
          'route', 'order_detail',
          'assignmentMode', coalesce(new.assignment_mode, 'automatic')
        ),
        'order:' || new.order_id || ':assigned:' || new.assigned_agent_id || ':' ||
          coalesce(extract(epoch from new.assigned_at)::text, extract(epoch from new.updated_at)::text)
      );
    end if;

    if new.assignment_state = 'manual_required' then
      if tg_op = 'INSERT' then
        v_changed := true;
      else
        v_changed := old.assignment_state is distinct from 'manual_required';
      end if;
      if v_changed then
        v_body := new.order_reference || ' - ' || upper(coalesce(new.network, '')) ||
          ' - ' || new.amount::text || ' F';
        for v_staff in
          select s.firebase_uid
          from public.izytel_staff_access s
          where s.is_active = true and s.role in ('manager', 'supervisor', 'admin')
        loop
          perform private.enqueue_izytel_notification(
            v_staff.firebase_uid,
            'order_manual_required',
            'Affectation manuelle requise',
            v_body,
            jsonb_build_object(
              'type', 'order_manual_required',
              'orderId', new.order_id,
              'orderReference', new.order_reference,
              'route', 'order_detail'
            ),
            'order:' || new.order_id || ':manual:' || v_staff.firebase_uid || ':' ||
              extract(epoch from new.updated_at)::text
          );
        end loop;
      end if;
    end if;
  exception when others then
    raise warning '[IzyTel Notifications][phase4] %', sqlerrm;
  end;
  return new;
end;
$$;

revoke all on function private.izytel_phase4_notification_trigger() from public, anon, authenticated;

drop trigger if exists trg_izytel_phase4_notifications on public.phase4_assignment_orders;
create trigger trg_izytel_phase4_notifications
after insert or update on public.phase4_assignment_orders
for each row execute function private.izytel_phase4_notification_trigger();

create or replace function private.izytel_agent_issue_notification_trigger()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_staff record;
  v_label text;
begin
  begin
    if tg_op = 'INSERT' then
      v_label := coalesce(nullif(btrim(new.type), ''), 'Signalement agent');
      for v_staff in
        select s.firebase_uid
        from public.izytel_staff_access s
        where s.is_active = true and s.role in ('manager', 'supervisor', 'admin')
      loop
        perform private.enqueue_izytel_notification(
          v_staff.firebase_uid,
          'agent_issue_new',
          'Nouveau signalement agent',
          v_label,
          jsonb_build_object(
            'type', 'agent_issue_new',
            'issueId', new.id::text,
            'route', 'agent_issues'
          ),
          'issue:' || new.id::text || ':new:' || v_staff.firebase_uid
        );
      end loop;
    elsif tg_op = 'UPDATE'
      and new.status = 'resolved'
      and old.status is distinct from 'resolved' then
      perform private.enqueue_izytel_notification(
        new.agent_id,
        'agent_issue_resolved',
        'Signalement resolu',
        'Ton signalement IzyTel a ete resolu.',
        jsonb_build_object(
          'type', 'agent_issue_resolved',
          'issueId', new.id::text,
          'route', 'agent_issues'
        ),
        'issue:' || new.id::text || ':resolved'
      );
    end if;
  exception when others then
    raise warning '[IzyTel Notifications][issues] %', sqlerrm;
  end;
  return new;
end;
$$;

revoke all on function private.izytel_agent_issue_notification_trigger() from public, anon, authenticated;

drop trigger if exists trg_izytel_agent_issue_notifications on public.agent_issues;
create trigger trg_izytel_agent_issue_notifications
after insert or update on public.agent_issues
for each row execute function private.izytel_agent_issue_notification_trigger();

create or replace function private.izytel_notification_dispatch_wakeup()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
begin
  begin
    perform net.http_post(
      url := 'https://zrxeztxaxnzxevjuhzcc.supabase.co/functions/v1/izytel-notification-dispatch',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', 'sb_publishable_6i0SKdOpBIAdTJj-TdepsA_LyB9dGeX'
      ),
      body := jsonb_build_object(
        'outboxId', new.id::text,
        'nonce', new.dispatch_nonce::text
      ),
      timeout_milliseconds := 4000
    );
  exception when others then
    -- L'echec du webhook n'annule jamais l'evenement metier qui a cree l'outbox.
    raise warning '[IzyTel Notifications][dispatch] %', sqlerrm;
  end;
  return new;
end;
$$;

revoke all on function private.izytel_notification_dispatch_wakeup() from public, anon, authenticated;

drop trigger if exists trg_izytel_notification_dispatch on public.izytel_notification_outbox;
create trigger trg_izytel_notification_dispatch
after insert on public.izytel_notification_outbox
for each row execute function private.izytel_notification_dispatch_wakeup();
