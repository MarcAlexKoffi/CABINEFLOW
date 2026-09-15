-- IzyTel BO-3C — Managers + organisation territoriale
-- Supabase devient la source canonique des zones. Firestore n'est utilisé
-- qu'une seule fois pour le backfill historique via l'application Admin.

create table if not exists public.manager_profiles (
  firebase_uid text primary key,
  display_name text not null,
  email text not null default '',
  phone_number text not null default '',
  secondary_phone text not null default '',
  city text not null default '',
  address text not null default '',
  avatar_path text,
  notes text not null default '' check (char_length(notes) <= 1200),
  is_active boolean not null default true,
  last_activity_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.territory_zones (
  id text primary key default gen_random_uuid()::text,
  name text not null check (char_length(btrim(name)) between 2 and 120),
  city text not null default '' check (char_length(city) <= 120),
  region text not null default '' check (char_length(region) <= 120),
  latitude double precision,
  longitude double precision,
  manager_id text references public.manager_profiles(firebase_uid) on delete set null,
  is_active boolean not null default true,
  legacy_firestore_id text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint territory_zones_coordinates_pair check (
    (latitude is null and longitude is null)
    or (
      latitude between -90 and 90
      and longitude between -180 and 180
    )
  )
);

create index if not exists territory_zones_manager_idx
  on public.territory_zones(manager_id)
  where manager_id is not null;
create index if not exists territory_zones_active_idx
  on public.territory_zones(is_active, city, name);

create table if not exists public.territory_audit_events (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('zone', 'manager')),
  entity_id text not null,
  action text not null,
  before_state jsonb,
  after_state jsonb,
  actor_uid text not null,
  actor_name text not null,
  actor_role text not null,
  created_at timestamptz not null default now()
);

create index if not exists territory_audit_entity_idx
  on public.territory_audit_events(entity_type, entity_id, created_at desc);

create table if not exists public.territory_migration_state (
  migration_key text primary key,
  completed_at timestamptz not null,
  imported_count integer not null default 0,
  completed_by text not null
);

alter table public.manager_profiles enable row level security;
alter table public.territory_zones enable row level security;
alter table public.territory_audit_events enable row level security;
alter table public.territory_migration_state enable row level security;

create or replace function private.is_izytel_territory_reader()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_izytel_firebase_jwt()
    and (
      exists (
        select 1
        from public.izytel_staff_access staff
        where staff.firebase_uid = (select auth.jwt()->>'sub')
          and staff.is_active = true
          and staff.role in ('admin', 'manager', 'supervisor')
      )
      or exists (
        select 1
        from public.phase5_agent_capacities agent
        where agent.agent_id = (select auth.jwt()->>'sub')
          and agent.is_active = true
      )
    );
$$;

create or replace function private.izytel_current_staff_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select staff.role
    from public.izytel_staff_access staff
    where staff.firebase_uid = (select auth.jwt()->>'sub')
      and staff.is_active = true
    limit 1
  ), 'unknown');
$$;

-- Lecture : staff pour les Managers, staff + Agents actifs pour les zones.
drop policy if exists "territory managers staff read" on public.manager_profiles;
create policy "territory managers staff read"
  on public.manager_profiles
  for select
  to anon, authenticated
  using ((select private.is_izytel_finance_staff()));

drop policy if exists "territory zones operational read" on public.territory_zones;
create policy "territory zones operational read"
  on public.territory_zones
  for select
  to anon, authenticated
  using ((select private.is_izytel_territory_reader()));

drop policy if exists "territory audit staff read" on public.territory_audit_events;
create policy "territory audit staff read"
  on public.territory_audit_events
  for select
  to anon, authenticated
  using ((select private.is_izytel_finance_staff()));

drop policy if exists "territory migration admin read" on public.territory_migration_state;
create policy "territory migration admin read"
  on public.territory_migration_state
  for select
  to anon, authenticated
  using ((select private.is_izytel_finance_admin()));

-- Toutes les écritures passent par RPC.
revoke all on public.manager_profiles from anon, authenticated;
revoke all on public.territory_zones from anon, authenticated;
revoke all on public.territory_audit_events from anon, authenticated;
revoke all on public.territory_migration_state from anon, authenticated;
grant select on public.manager_profiles to anon, authenticated;
grant select on public.territory_zones to anon, authenticated;
grant select on public.territory_audit_events to anon, authenticated;
grant select on public.territory_migration_state to anon, authenticated;

-- Synchronise les comptes manager/supervisor déjà présents dans le registre staff.
insert into public.manager_profiles (
  firebase_uid,
  display_name,
  is_active,
  last_activity_at,
  created_at,
  updated_at
)
select
  staff.firebase_uid,
  coalesce(nullif(btrim(staff.display_name), ''), 'Manager IzyTel'),
  staff.is_active,
  staff.updated_at,
  staff.created_at,
  staff.updated_at
from public.izytel_staff_access staff
where staff.role in ('manager', 'supervisor')
on conflict (firebase_uid) do update
set display_name = excluded.display_name,
    is_active = excluded.is_active,
    updated_at = greatest(public.manager_profiles.updated_at, excluded.updated_at);

create or replace function public.izytel_sync_manager_profiles()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;

  insert into public.manager_profiles (
    firebase_uid,
    display_name,
    is_active,
    last_activity_at,
    created_at,
    updated_at
  )
  select
    staff.firebase_uid,
    coalesce(nullif(btrim(staff.display_name), ''), 'Manager IzyTel'),
    staff.is_active,
    staff.updated_at,
    staff.created_at,
    staff.updated_at
  from public.izytel_staff_access staff
  where staff.role in ('manager', 'supervisor')
  on conflict (firebase_uid) do update
  set display_name = case
        when btrim(public.manager_profiles.display_name) = ''
          then excluded.display_name
        else public.manager_profiles.display_name
      end,
      is_active = excluded.is_active,
      updated_at = greatest(public.manager_profiles.updated_at, excluded.updated_at);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.izytel_save_manager_profile(
  p_firebase_uid text,
  p_display_name text,
  p_email text,
  p_phone_number text,
  p_secondary_phone text,
  p_city text,
  p_address text,
  p_notes text,
  p_is_active boolean
)
returns public.manager_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := btrim(coalesce(p_firebase_uid, ''));
  v_name text := btrim(coalesce(p_display_name, ''));
  v_actor_uid text := (select auth.jwt()->>'sub');
  v_actor_name text := private.izytel_staff_display_name();
  v_before public.manager_profiles;
  v_result public.manager_profiles;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;
  if v_uid = '' or char_length(v_name) < 2 or char_length(v_name) > 120 then
    raise exception 'MANAGER_PROFILE_INVALID';
  end if;
  if char_length(coalesce(p_email, '')) > 180
     or char_length(coalesce(p_phone_number, '')) > 40
     or char_length(coalesce(p_secondary_phone, '')) > 40
     or char_length(coalesce(p_city, '')) > 120
     or char_length(coalesce(p_address, '')) > 240
     or char_length(coalesce(p_notes, '')) > 1200 then
    raise exception 'MANAGER_PROFILE_INVALID';
  end if;
  if not exists (
    select 1
    from public.izytel_staff_access staff
    where staff.firebase_uid = v_uid
      and staff.role in ('manager', 'supervisor')
  ) then
    raise exception 'MANAGER_STAFF_ACCOUNT_REQUIRED';
  end if;

  select * into v_before
  from public.manager_profiles
  where firebase_uid = v_uid;

  insert into public.manager_profiles (
    firebase_uid, display_name, email, phone_number, secondary_phone,
    city, address, notes, is_active, last_activity_at, created_at, updated_at
  ) values (
    v_uid, v_name, btrim(coalesce(p_email, '')), btrim(coalesce(p_phone_number, '')),
    btrim(coalesce(p_secondary_phone, '')), btrim(coalesce(p_city, '')),
    btrim(coalesce(p_address, '')), btrim(coalesce(p_notes, '')), p_is_active,
    coalesce(v_before.last_activity_at, now()), coalesce(v_before.created_at, now()), now()
  )
  on conflict (firebase_uid) do update
  set display_name = excluded.display_name,
      email = excluded.email,
      phone_number = excluded.phone_number,
      secondary_phone = excluded.secondary_phone,
      city = excluded.city,
      address = excluded.address,
      notes = excluded.notes,
      is_active = excluded.is_active,
      updated_at = now()
  returning * into v_result;

  insert into public.territory_audit_events (
    entity_type, entity_id, action, before_state, after_state,
    actor_uid, actor_name, actor_role
  ) values (
    'manager', v_uid, case when v_before.firebase_uid is null then 'created' else 'updated' end,
    case when v_before.firebase_uid is null then null else to_jsonb(v_before) end,
    to_jsonb(v_result), v_actor_uid, v_actor_name, private.izytel_current_staff_role()
  );

  return v_result;
end;
$$;

create or replace function private.izytel_assert_manager(p_manager_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if nullif(btrim(coalesce(p_manager_id, '')), '') is null then
    return;
  end if;
  if not exists (
    select 1 from public.manager_profiles manager
    where manager.firebase_uid = btrim(p_manager_id)
      and manager.is_active = true
  ) then
    raise exception 'ACTIVE_MANAGER_REQUIRED';
  end if;
end;
$$;

create or replace function public.izytel_create_territory_zone(
  p_name text,
  p_city text,
  p_region text,
  p_latitude double precision,
  p_longitude double precision,
  p_manager_id text,
  p_is_active boolean default true
)
returns public.territory_zones
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_uid text := (select auth.jwt()->>'sub');
  v_actor_name text := private.izytel_staff_display_name();
  v_manager_id text := nullif(btrim(coalesce(p_manager_id, '')), '');
  v_result public.territory_zones;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;
  if char_length(btrim(coalesce(p_name, ''))) < 2
     or char_length(btrim(coalesce(p_name, ''))) > 120 then
    raise exception 'ZONE_NAME_INVALID';
  end if;
  if (p_latitude is null) <> (p_longitude is null) then
    raise exception 'ZONE_COORDINATES_INCOMPLETE';
  end if;
  if p_latitude is not null and (p_latitude < -90 or p_latitude > 90 or p_longitude < -180 or p_longitude > 180) then
    raise exception 'ZONE_COORDINATES_INVALID';
  end if;
  perform private.izytel_assert_manager(v_manager_id);

  insert into public.territory_zones (
    name, city, region, latitude, longitude, manager_id, is_active,
    created_at, updated_at
  ) values (
    btrim(p_name), btrim(coalesce(p_city, '')), btrim(coalesce(p_region, '')),
    p_latitude, p_longitude, v_manager_id, p_is_active, now(), now()
  ) returning * into v_result;

  insert into public.territory_audit_events (
    entity_type, entity_id, action, after_state,
    actor_uid, actor_name, actor_role
  ) values (
    'zone', v_result.id, 'created', to_jsonb(v_result),
    v_actor_uid, v_actor_name, private.izytel_current_staff_role()
  );

  return v_result;
end;
$$;

create or replace function public.izytel_update_territory_zone(
  p_zone_id text,
  p_name text,
  p_city text,
  p_region text,
  p_latitude double precision,
  p_longitude double precision,
  p_manager_id text,
  p_is_active boolean
)
returns public.territory_zones
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id text := btrim(coalesce(p_zone_id, ''));
  v_actor_uid text := (select auth.jwt()->>'sub');
  v_actor_name text := private.izytel_staff_display_name();
  v_manager_id text := nullif(btrim(coalesce(p_manager_id, '')), '');
  v_before public.territory_zones;
  v_result public.territory_zones;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;
  if v_id = '' then raise exception 'ZONE_REQUIRED'; end if;
  if char_length(btrim(coalesce(p_name, ''))) < 2
     or char_length(btrim(coalesce(p_name, ''))) > 120 then
    raise exception 'ZONE_NAME_INVALID';
  end if;
  if (p_latitude is null) <> (p_longitude is null) then
    raise exception 'ZONE_COORDINATES_INCOMPLETE';
  end if;
  if p_latitude is not null and (p_latitude < -90 or p_latitude > 90 or p_longitude < -180 or p_longitude > 180) then
    raise exception 'ZONE_COORDINATES_INVALID';
  end if;
  perform private.izytel_assert_manager(v_manager_id);

  select * into v_before
  from public.territory_zones
  where id = v_id
  for update;
  if not found then raise exception 'ZONE_NOT_FOUND'; end if;

  update public.territory_zones
  set name = btrim(p_name),
      city = btrim(coalesce(p_city, '')),
      region = btrim(coalesce(p_region, '')),
      latitude = p_latitude,
      longitude = p_longitude,
      manager_id = v_manager_id,
      is_active = p_is_active,
      updated_at = now()
  where id = v_id
  returning * into v_result;

  insert into public.territory_audit_events (
    entity_type, entity_id, action, before_state, after_state,
    actor_uid, actor_name, actor_role
  ) values (
    'zone', v_id, 'updated', to_jsonb(v_before), to_jsonb(v_result),
    v_actor_uid, v_actor_name, private.izytel_current_staff_role()
  );

  return v_result;
end;
$$;

-- Import ponctuel Firestore -> Supabase. Ne sert qu'au backfill historique.
create or replace function public.izytel_import_legacy_zone(
  p_zone_id text,
  p_name text,
  p_city text,
  p_region text,
  p_is_active boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id text := btrim(coalesce(p_zone_id, ''));
  v_count integer := 0;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;
  if v_id = '' or char_length(btrim(coalesce(p_name, ''))) < 2 then
    raise exception 'LEGACY_ZONE_INVALID';
  end if;

  insert into public.territory_zones (
    id, name, city, region, is_active, legacy_firestore_id, created_at, updated_at
  ) values (
    v_id, btrim(p_name), btrim(coalesce(p_city, '')), btrim(coalesce(p_region, '')),
    p_is_active, v_id, now(), now()
  )
  on conflict (id) do nothing;

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

create or replace function public.izytel_territory_backfill_needed()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;
  return not exists (
    select 1 from public.territory_migration_state
    where migration_key = 'firestore_zones_v1'
  );
end;
$$;

create or replace function public.izytel_finish_legacy_zone_backfill(p_imported_count integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;
  insert into public.territory_migration_state (
    migration_key, completed_at, imported_count, completed_by
  ) values (
    'firestore_zones_v1', now(), greatest(coalesce(p_imported_count, 0), 0),
    (select auth.jwt()->>'sub')
  )
  on conflict (migration_key) do update
  set completed_at = excluded.completed_at,
      imported_count = excluded.imported_count,
      completed_by = excluded.completed_by;
end;
$$;

revoke all on function public.izytel_sync_manager_profiles() from public;
revoke all on function public.izytel_save_manager_profile(text,text,text,text,text,text,text,text,boolean) from public;
revoke all on function public.izytel_create_territory_zone(text,text,text,double precision,double precision,text,boolean) from public;
revoke all on function public.izytel_update_territory_zone(text,text,text,text,double precision,double precision,text,boolean) from public;
revoke all on function public.izytel_import_legacy_zone(text,text,text,text,boolean) from public;
revoke all on function public.izytel_territory_backfill_needed() from public;
revoke all on function public.izytel_finish_legacy_zone_backfill(integer) from public;

grant execute on function public.izytel_sync_manager_profiles() to anon, authenticated;
grant execute on function public.izytel_save_manager_profile(text,text,text,text,text,text,text,text,boolean) to anon, authenticated;
grant execute on function public.izytel_create_territory_zone(text,text,text,double precision,double precision,text,boolean) to anon, authenticated;
grant execute on function public.izytel_update_territory_zone(text,text,text,text,double precision,double precision,text,boolean) to anon, authenticated;
grant execute on function public.izytel_import_legacy_zone(text,text,text,text,boolean) to anon, authenticated;
grant execute on function public.izytel_territory_backfill_needed() to anon, authenticated;
grant execute on function public.izytel_finish_legacy_zone_backfill(integer) to anon, authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'manager_profiles'
  ) then
    alter publication supabase_realtime add table public.manager_profiles;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'territory_zones'
  ) then
    alter publication supabase_realtime add table public.territory_zones;
  end if;
end
$$;
