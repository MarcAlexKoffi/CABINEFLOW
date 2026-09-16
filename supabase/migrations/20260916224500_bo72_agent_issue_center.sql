-- IzyTel BO-7.2 — Centre de signalements Agents
-- Sécurise le périmètre Manager, historise les transitions et expose un RPC
-- dédié au Back-office sans casser les flux Agent/mobile existants.

alter table public.agent_issues
  add column if not exists resolution_note text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'agent_issues_resolution_note_length_check'
      and conrelid = 'public.agent_issues'::regclass
  ) then
    alter table public.agent_issues
      add constraint agent_issues_resolution_note_length_check
      check (resolution_note is null or char_length(resolution_note) <= 1000);
  end if;
end;
$$;

create table if not exists public.agent_issue_events (
  id bigint generated always as identity primary key,
  issue_id uuid not null references public.agent_issues(id) on delete cascade,
  event_kind text not null,
  status text not null,
  note text,
  actor_uid text,
  actor_name text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint agent_issue_events_kind_check
    check (event_kind in ('created', 'in_progress', 'resolved', 'cancelled')),
  constraint agent_issue_events_status_check
    check (status in ('open', 'in_progress', 'resolved', 'cancelled')),
  constraint agent_issue_events_note_length_check
    check (note is null or char_length(note) <= 1000)
);

create index if not exists idx_agent_issue_events_issue_time
  on public.agent_issue_events(issue_id, occurred_at desc, id desc);

alter table public.agent_issue_events enable row level security;
revoke all on table public.agent_issue_events from public, anon, authenticated;
revoke all on sequence public.agent_issue_events_id_seq from public, anon, authenticated;

create or replace function private.izytel_issue_agent_in_scope(p_agent_id text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_role text := private.izytel_current_staff_role();
begin
  if v_uid is null or not public.is_izytel_firebase_jwt() then
    return false;
  end if;

  if v_role = 'admin' then
    return true;
  end if;

  if v_role not in ('manager', 'supervisor') then
    return false;
  end if;

  return exists (
    select 1
    from public.phase5_agent_capacities capacity
    where capacity.agent_id = p_agent_id
      and exists (
        select 1
        from public.territory_zones zone
        where zone.manager_id = v_uid
          and zone.is_active = true
          and zone.id = any(coalesce(capacity.zone_ids, array[]::text[]))
      )
  );
end;
$$;

revoke all on function private.izytel_issue_agent_in_scope(text) from public;

drop policy if exists "agent creates own issue" on public.agent_issues;
create policy "agent creates own issue"
on public.agent_issues
for insert
with check (
  (select public.is_izytel_firebase_jwt())
  and agent_id = (select auth.jwt()->>'sub')
  and status = 'open'
  and resolved_at is null
  and resolved_by is null
  and resolved_by_uid is null
  and resolution_note is null
  and legacy_firestore_id is null
);

drop policy if exists "agent reads own issues or staff reads all" on public.agent_issues;
create policy "agent reads own issues or scoped staff reads"
on public.agent_issues
for select
using (
  (select public.is_izytel_firebase_jwt())
  and (
    agent_id = (select auth.jwt()->>'sub')
    or private.izytel_issue_agent_in_scope(agent_id)
  )
);

drop policy if exists "staff updates issue status" on public.agent_issues;
create policy "scoped staff updates issue status"
on public.agent_issues
for update
using (
  private.izytel_issue_agent_in_scope(agent_id)
)
with check (
  private.izytel_issue_agent_in_scope(agent_id)
  and status = any(array['in_progress'::text, 'resolved'::text, 'cancelled'::text])
);

create or replace function private.izytel_agent_issue_event_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_actor_name text;
  v_event_kind text;
  v_note text;
  v_occurred_at timestamptz;
begin
  if tg_op = 'INSERT' then
    insert into public.agent_issue_events(
      issue_id,
      event_kind,
      status,
      actor_uid,
      actor_name,
      occurred_at
    ) values (
      new.id,
      'created',
      'open',
      new.agent_id,
      null,
      new.created_at
    );
    return new;
  end if;

  if old.status is not distinct from new.status then
    return new;
  end if;

  v_event_kind := new.status;
  select nullif(btrim(coalesce(staff.display_name, '')), '')
    into v_actor_name
  from public.izytel_staff_access staff
  where staff.firebase_uid = v_uid
    and staff.is_active = true
  limit 1;

  if new.status in ('resolved', 'cancelled') then
    v_actor_name := coalesce(nullif(btrim(coalesce(new.resolved_by, '')), ''), v_actor_name, v_uid);
    v_note := nullif(btrim(coalesce(new.resolution_note, '')), '');
    v_occurred_at := coalesce(new.resolved_at, new.updated_at, now());
  else
    v_actor_name := coalesce(v_actor_name, v_uid);
    v_note := null;
    v_occurred_at := coalesce(new.updated_at, now());
  end if;

  insert into public.agent_issue_events(
    issue_id,
    event_kind,
    status,
    note,
    actor_uid,
    actor_name,
    occurred_at
  ) values (
    new.id,
    v_event_kind,
    new.status,
    v_note,
    v_uid,
    v_actor_name,
    v_occurred_at
  );

  return new;
end;
$$;

drop trigger if exists trg_izytel_agent_issue_event_history on public.agent_issues;
create trigger trg_izytel_agent_issue_event_history
after insert or update of status on public.agent_issues
for each row execute function private.izytel_agent_issue_event_history();

-- Historique minimal pour les signalements déjà présents avant BO-7.2.
insert into public.agent_issue_events(
  issue_id,
  event_kind,
  status,
  actor_uid,
  actor_name,
  occurred_at
)
select
  issue.id,
  'created',
  'open',
  issue.agent_id,
  null,
  issue.created_at
from public.agent_issues issue
where not exists (
  select 1
  from public.agent_issue_events event
  where event.issue_id = issue.id
    and event.event_kind = 'created'
);

insert into public.agent_issue_events(
  issue_id,
  event_kind,
  status,
  note,
  actor_uid,
  actor_name,
  occurred_at
)
select
  issue.id,
  issue.status,
  issue.status,
  issue.resolution_note,
  issue.resolved_by_uid,
  issue.resolved_by,
  coalesce(issue.resolved_at, issue.updated_at, issue.created_at)
from public.agent_issues issue
where issue.status in ('in_progress', 'resolved', 'cancelled')
  and not exists (
    select 1
    from public.agent_issue_events event
    where event.issue_id = issue.id
      and event.event_kind = issue.status
  );

create or replace function public.izytel_bo72_agent_issue_center_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_role text := private.izytel_current_staff_role();
  v_issues jsonb := '[]'::jsonb;
begin
  if v_uid is null
     or not public.is_izytel_firebase_jwt()
     or v_role not in ('admin', 'manager', 'supervisor') then
    raise exception 'STAFF_REQUIRED';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', issue.id,
        'agent_id', issue.agent_id,
        'type', issue.type,
        'network', issue.network,
        'description', issue.description,
        'status', issue.status,
        'created_at', issue.created_at,
        'updated_at', issue.updated_at,
        'resolved_at', issue.resolved_at,
        'resolved_by', issue.resolved_by,
        'resolved_by_uid', issue.resolved_by_uid,
        'resolution_note', issue.resolution_note,
        'events', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', event.id,
              'event_kind', event.event_kind,
              'status', event.status,
              'note', event.note,
              'actor_uid', event.actor_uid,
              'actor_name', event.actor_name,
              'occurred_at', event.occurred_at
            ) order by event.occurred_at asc, event.id asc
          )
          from public.agent_issue_events event
          where event.issue_id = issue.id
        ), '[]'::jsonb)
      ) order by issue.created_at desc, issue.id desc
    ),
    '[]'::jsonb
  ) into v_issues
  from public.agent_issues issue
  where private.izytel_issue_agent_in_scope(issue.agent_id);

  return jsonb_build_object(
    'generated_at', now(),
    'caller_role', v_role,
    'scope', jsonb_build_object(
      'type', case when v_role = 'admin' then 'global' else 'manager_territory' end
    ),
    'issues', v_issues
  );
end;
$$;

revoke all on function public.izytel_bo72_agent_issue_center_snapshot() from public;
grant execute on function public.izytel_bo72_agent_issue_center_snapshot() to anon, authenticated;

create or replace function public.izytel_bo72_transition_agent_issue(
  p_issue_id uuid,
  p_status text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_role text := private.izytel_current_staff_role();
  v_actor_name text;
  v_current_status text;
  v_agent_id text;
  v_status text := lower(btrim(coalesce(p_status, '')));
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if v_uid is null
     or not public.is_izytel_firebase_jwt()
     or v_role not in ('admin', 'manager', 'supervisor') then
    raise exception 'STAFF_REQUIRED';
  end if;

  if v_status not in ('in_progress', 'resolved', 'cancelled') then
    raise exception 'INVALID_STATUS';
  end if;

  select issue.status, issue.agent_id
    into v_current_status, v_agent_id
  from public.agent_issues issue
  where issue.id = p_issue_id
  for update;

  if not found then
    raise exception 'ISSUE_NOT_FOUND';
  end if;

  if not private.izytel_issue_agent_in_scope(v_agent_id) then
    raise exception 'ISSUE_OUT_OF_SCOPE';
  end if;

  if v_current_status in ('resolved', 'cancelled') then
    raise exception 'ISSUE_ALREADY_CLOSED';
  end if;

  if v_status = 'in_progress' and v_current_status <> 'open' then
    raise exception 'INVALID_TRANSITION';
  end if;

  if v_status = 'resolved' and v_current_status <> 'in_progress' then
    raise exception 'INVALID_TRANSITION';
  end if;

  if v_status = 'cancelled' and v_current_status not in ('open', 'in_progress') then
    raise exception 'INVALID_TRANSITION';
  end if;

  if v_status in ('resolved', 'cancelled') then
    if v_note is null or char_length(v_note) < 3 or char_length(v_note) > 1000 then
      raise exception 'RESOLUTION_NOTE_REQUIRED';
    end if;
  else
    v_note := null;
  end if;

  select coalesce(nullif(btrim(coalesce(staff.display_name, '')), ''), v_uid)
    into v_actor_name
  from public.izytel_staff_access staff
  where staff.firebase_uid = v_uid
    and staff.is_active = true
  limit 1;

  v_actor_name := coalesce(v_actor_name, v_uid);

  update public.agent_issues
  set status = v_status,
      resolution_note = case when v_status in ('resolved', 'cancelled') then v_note else null end,
      resolved_by = case when v_status in ('resolved', 'cancelled') then v_actor_name else null end
  where id = p_issue_id;

  return jsonb_build_object(
    'issue_id', p_issue_id,
    'status', v_status,
    'actor_uid', v_uid,
    'actor_name', v_actor_name
  );
end;
$$;

revoke all on function public.izytel_bo72_transition_agent_issue(uuid, text, text) from public;
grant execute on function public.izytel_bo72_transition_agent_issue(uuid, text, text) to anon, authenticated;

comment on function public.izytel_bo72_agent_issue_center_snapshot() is
  'BO-7.2 signalements Agents : Admin global, Manager/supervisor limité aux Agents de ses zones.';
comment on function public.izytel_bo72_transition_agent_issue(uuid, text, text) is
  'BO-7.2 transition sécurisée : prise en charge, résolution ou classement sans suite avec note de clôture.';
