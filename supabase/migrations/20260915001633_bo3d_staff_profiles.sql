-- IzyTel BO-3D — couche commune de profils Staff
-- Supabase = source canonique des informations personnelles Agent / Manager / Admin.
-- Les tables agent_personal_profiles et manager_profiles restent compatibles
-- pendant la transition, mais les nouvelles interfaces lisent staff_profiles.

create table if not exists public.staff_profiles (
  firebase_uid text primary key,
  role text not null check (role in ('admin', 'manager', 'agent')),
  first_name text not null default '' check (char_length(first_name) <= 120),
  last_name text not null default '' check (char_length(last_name) <= 120),
  email text not null default '' check (char_length(email) <= 180),
  phone_number text not null default '' check (char_length(phone_number) <= 40),
  secondary_phone text not null default '' check (char_length(secondary_phone) <= 40),
  date_of_birth date,
  address text not null default '' check (char_length(address) <= 240),
  city text not null default '' check (char_length(city) <= 120),
  emergency_contact_name text not null default '' check (char_length(emergency_contact_name) <= 160),
  emergency_contact_phone text not null default '' check (char_length(emergency_contact_phone) <= 40),
  avatar_path text,
  identity_document_type text,
  identity_document_number text not null default '' check (char_length(identity_document_number) <= 120),
  identity_document_path text,
  identity_document_file_name text,
  identity_document_mime_type text,
  verification_status text not null default 'incomplete'
    check (verification_status in ('incomplete', 'pending_review', 'needs_correction', 'verified')),
  verification_note text check (verification_note is null or char_length(verification_note) <= 1200),
  last_activity_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists staff_profiles_role_idx
  on public.staff_profiles(role, updated_at desc);
create index if not exists staff_profiles_verification_idx
  on public.staff_profiles(verification_status, updated_at desc);

create table if not exists public.staff_profile_audit_events (
  id uuid primary key default gen_random_uuid(),
  firebase_uid text not null,
  action text not null,
  actor_uid text not null,
  actor_role text not null,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists staff_profile_audit_uid_idx
  on public.staff_profile_audit_events(firebase_uid, created_at desc);

alter table public.staff_profiles enable row level security;
alter table public.staff_profile_audit_events enable row level security;

create or replace function private.izytel_profile_role_for_uid(p_uid text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select case
        when staff.role = 'admin' then 'admin'
        when staff.role in ('manager', 'supervisor') then 'manager'
        else null
      end
      from public.izytel_staff_access staff
      where staff.firebase_uid = p_uid
        and staff.is_active = true
      limit 1
    ),
    (
      select 'agent'
      from public.phase5_agent_capacities agent
      where agent.agent_id = p_uid
      limit 1
    ),
    'unknown'
  );
$$;

create or replace function private.izytel_current_profile_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select private.izytel_profile_role_for_uid((select auth.jwt()->>'sub'));
$$;

-- Backfill Agent vers la couche commune.
insert into public.staff_profiles (
  firebase_uid, role, first_name, last_name, phone_number, secondary_phone,
  date_of_birth, address, city, emergency_contact_name, emergency_contact_phone,
  avatar_path, identity_document_type, identity_document_number,
  identity_document_path, identity_document_file_name, identity_document_mime_type,
  verification_status, verification_note, last_activity_at, created_at, updated_at
)
select
  p.firebase_uid, 'agent', p.first_name, p.last_name, p.contact1, p.contact2,
  p.date_of_birth, p.address, p.city, p.emergency_contact_name, p.emergency_contact_phone,
  p.avatar_path, p.identity_document_type, p.identity_document_number,
  p.identity_document_path, p.identity_document_file_name, p.identity_document_mime_type,
  p.verification_status, p.verification_note, p.updated_at, p.created_at, p.updated_at
from public.agent_personal_profiles p
on conflict (firebase_uid) do update
set role = 'agent',
    first_name = excluded.first_name,
    last_name = excluded.last_name,
    phone_number = excluded.phone_number,
    secondary_phone = excluded.secondary_phone,
    date_of_birth = excluded.date_of_birth,
    address = excluded.address,
    city = excluded.city,
    emergency_contact_name = excluded.emergency_contact_name,
    emergency_contact_phone = excluded.emergency_contact_phone,
    avatar_path = excluded.avatar_path,
    identity_document_type = excluded.identity_document_type,
    identity_document_number = excluded.identity_document_number,
    identity_document_path = excluded.identity_document_path,
    identity_document_file_name = excluded.identity_document_file_name,
    identity_document_mime_type = excluded.identity_document_mime_type,
    verification_status = excluded.verification_status,
    verification_note = excluded.verification_note,
    last_activity_at = excluded.last_activity_at,
    updated_at = greatest(public.staff_profiles.updated_at, excluded.updated_at);

-- Backfill Manager existant.
insert into public.staff_profiles (
  firebase_uid, role, first_name, email, phone_number, secondary_phone,
  address, city, avatar_path, last_activity_at, created_at, updated_at
)
select
  p.firebase_uid, 'manager', p.display_name, p.email, p.phone_number, p.secondary_phone,
  p.address, p.city, p.avatar_path, p.last_activity_at, p.created_at, p.updated_at
from public.manager_profiles p
on conflict (firebase_uid) do update
set role = 'manager',
    email = excluded.email,
    phone_number = excluded.phone_number,
    secondary_phone = excluded.secondary_phone,
    address = excluded.address,
    city = excluded.city,
    avatar_path = coalesce(excluded.avatar_path, public.staff_profiles.avatar_path),
    last_activity_at = excluded.last_activity_at,
    first_name = case
      when btrim(public.staff_profiles.first_name || public.staff_profiles.last_name) = ''
        then excluded.first_name
      else public.staff_profiles.first_name
    end,
    updated_at = greatest(public.staff_profiles.updated_at, excluded.updated_at);

-- Crée aussi le profil minimal des comptes Admin / Manager sans fiche personnelle.
insert into public.staff_profiles (
  firebase_uid, role, first_name, last_activity_at, created_at, updated_at
)
select
  staff.firebase_uid,
  case when staff.role = 'admin' then 'admin' else 'manager' end,
  coalesce(nullif(btrim(staff.display_name), ''),
    case when staff.role = 'admin' then 'Administrateur IzyTel' else 'Manager IzyTel' end),
  staff.updated_at,
  staff.created_at,
  staff.updated_at
from public.izytel_staff_access staff
where staff.is_active = true
  and staff.role in ('admin', 'manager', 'supervisor')
on conflict (firebase_uid) do update
set role = excluded.role,
    last_activity_at = excluded.last_activity_at,
    first_name = case
      when btrim(public.staff_profiles.first_name || public.staff_profiles.last_name) = ''
        then excluded.first_name
      else public.staff_profiles.first_name
    end,
    updated_at = greatest(public.staff_profiles.updated_at, excluded.updated_at);

-- Compatibilité : les anciennes écritures Agent alimentent automatiquement staff_profiles.
create or replace function private.izytel_agent_profile_to_staff_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.staff_profiles (
    firebase_uid, role, first_name, last_name, phone_number, secondary_phone,
    date_of_birth, address, city, emergency_contact_name, emergency_contact_phone,
    avatar_path, identity_document_type, identity_document_number,
    identity_document_path, identity_document_file_name, identity_document_mime_type,
    verification_status, verification_note, last_activity_at, created_at, updated_at
  ) values (
    new.firebase_uid, 'agent', new.first_name, new.last_name, new.contact1, new.contact2,
    new.date_of_birth, new.address, new.city, new.emergency_contact_name, new.emergency_contact_phone,
    new.avatar_path, new.identity_document_type, new.identity_document_number,
    new.identity_document_path, new.identity_document_file_name, new.identity_document_mime_type,
    new.verification_status, new.verification_note, new.updated_at, new.created_at, new.updated_at
  )
  on conflict (firebase_uid) do update
  set role = 'agent',
      first_name = excluded.first_name,
      last_name = excluded.last_name,
      phone_number = excluded.phone_number,
      secondary_phone = excluded.secondary_phone,
      date_of_birth = excluded.date_of_birth,
      address = excluded.address,
      city = excluded.city,
      emergency_contact_name = excluded.emergency_contact_name,
      emergency_contact_phone = excluded.emergency_contact_phone,
      avatar_path = excluded.avatar_path,
      identity_document_type = excluded.identity_document_type,
      identity_document_number = excluded.identity_document_number,
      identity_document_path = excluded.identity_document_path,
      identity_document_file_name = excluded.identity_document_file_name,
      identity_document_mime_type = excluded.identity_document_mime_type,
      verification_status = excluded.verification_status,
      verification_note = excluded.verification_note,
      last_activity_at = excluded.last_activity_at,
      updated_at = excluded.updated_at;
  return new;
end;
$$;

drop trigger if exists trg_agent_profile_to_staff_profile on public.agent_personal_profiles;
create trigger trg_agent_profile_to_staff_profile
after insert or update on public.agent_personal_profiles
for each row execute function private.izytel_agent_profile_to_staff_profile();

-- Compatibilité : les modifications de la fiche Manager BO-3C alimentent staff_profiles.
create or replace function private.izytel_manager_profile_to_staff_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.staff_profiles (
    firebase_uid, role, first_name, email, phone_number, secondary_phone,
    address, city, avatar_path, last_activity_at, created_at, updated_at
  ) values (
    new.firebase_uid, 'manager', new.display_name, new.email, new.phone_number,
    new.secondary_phone, new.address, new.city, new.avatar_path,
    new.last_activity_at, new.created_at, new.updated_at
  )
  on conflict (firebase_uid) do update
  set role = 'manager',
      email = excluded.email,
      phone_number = excluded.phone_number,
      secondary_phone = excluded.secondary_phone,
      address = excluded.address,
      city = excluded.city,
      avatar_path = coalesce(excluded.avatar_path, public.staff_profiles.avatar_path),
      last_activity_at = excluded.last_activity_at,
      first_name = case
        when btrim(public.staff_profiles.first_name || public.staff_profiles.last_name) = ''
          then excluded.first_name
        else public.staff_profiles.first_name
      end,
      updated_at = excluded.updated_at;
  return new;
end;
$$;

drop trigger if exists trg_manager_profile_to_staff_profile on public.manager_profiles;
create trigger trg_manager_profile_to_staff_profile
after insert or update on public.manager_profiles
for each row execute function private.izytel_manager_profile_to_staff_profile();

-- Les lectures de la fiche complète sont limitées à soi-même ou à l'Admin.
drop policy if exists "staff profile self or admin read" on public.staff_profiles;
create policy "staff profile self or admin read"
  on public.staff_profiles
  for select
  to anon, authenticated
  using (
    (select public.is_izytel_firebase_jwt())
    and (
      firebase_uid = (select auth.jwt()->>'sub')
      or (select private.is_izytel_finance_admin())
    )
  );

drop policy if exists "staff profile audit self or admin read" on public.staff_profile_audit_events;
create policy "staff profile audit self or admin read"
  on public.staff_profile_audit_events
  for select
  to anon, authenticated
  using (
    (select public.is_izytel_firebase_jwt())
    and (
      firebase_uid = (select auth.jwt()->>'sub')
      or (select private.is_izytel_finance_admin())
    )
  );

revoke all on public.staff_profiles from anon, authenticated;
revoke all on public.staff_profile_audit_events from anon, authenticated;
grant select on public.staff_profiles to anon, authenticated;
grant select on public.staff_profile_audit_events to anon, authenticated;

create or replace function public.izytel_sync_staff_profiles()
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

  insert into public.staff_profiles (
    firebase_uid, role, first_name, last_activity_at, created_at, updated_at
  )
  select
    staff.firebase_uid,
    case when staff.role = 'admin' then 'admin' else 'manager' end,
    coalesce(nullif(btrim(staff.display_name), ''), 'Staff IzyTel'),
    staff.updated_at,
    staff.created_at,
    staff.updated_at
  from public.izytel_staff_access staff
  where staff.is_active = true
    and staff.role in ('admin', 'manager', 'supervisor')
  on conflict (firebase_uid) do update
  set role = excluded.role,
      last_activity_at = excluded.last_activity_at,
      updated_at = greatest(public.staff_profiles.updated_at, excluded.updated_at);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.izytel_save_own_staff_profile(
  p_first_name text,
  p_last_name text,
  p_email text,
  p_phone_number text,
  p_secondary_phone text,
  p_date_of_birth date,
  p_address text,
  p_city text,
  p_emergency_contact_name text,
  p_emergency_contact_phone text,
  p_avatar_path text,
  p_identity_document_type text,
  p_identity_document_number text,
  p_identity_document_path text,
  p_identity_document_file_name text,
  p_identity_document_mime_type text
)
returns public.staff_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_role text;
  v_existing public.staff_profiles;
  v_result public.staff_profiles;
  v_name text;
begin
  if v_uid is null or not public.is_izytel_firebase_jwt() then
    raise exception 'AUTH_REQUIRED';
  end if;

  v_role := private.izytel_profile_role_for_uid(v_uid);
  if v_role not in ('admin', 'manager', 'agent') then
    raise exception 'STAFF_PROFILE_ROLE_REQUIRED';
  end if;

  if char_length(btrim(coalesce(p_first_name, ''))) < 1
     or char_length(coalesce(p_first_name, '')) > 120
     or char_length(coalesce(p_last_name, '')) > 120
     or char_length(coalesce(p_email, '')) > 180
     or char_length(coalesce(p_phone_number, '')) > 40
     or char_length(coalesce(p_secondary_phone, '')) > 40
     or char_length(coalesce(p_address, '')) > 240
     or char_length(coalesce(p_city, '')) > 120
     or char_length(coalesce(p_emergency_contact_name, '')) > 160
     or char_length(coalesce(p_emergency_contact_phone, '')) > 40
     or char_length(coalesce(p_identity_document_number, '')) > 120 then
    raise exception 'STAFF_PROFILE_INVALID';
  end if;

  if nullif(btrim(coalesce(p_avatar_path, '')), '') is not null
     and btrim(p_avatar_path) not like v_uid || '/avatar/%' then
    raise exception 'STAFF_AVATAR_PATH_INVALID';
  end if;
  if nullif(btrim(coalesce(p_identity_document_path, '')), '') is not null
     and btrim(p_identity_document_path) not like v_uid || '/identity/%' then
    raise exception 'STAFF_IDENTITY_PATH_INVALID';
  end if;

  select * into v_existing
  from public.staff_profiles
  where firebase_uid = v_uid;

  insert into public.staff_profiles (
    firebase_uid, role, first_name, last_name, email, phone_number, secondary_phone,
    date_of_birth, address, city, emergency_contact_name, emergency_contact_phone,
    avatar_path, identity_document_type, identity_document_number,
    identity_document_path, identity_document_file_name, identity_document_mime_type,
    verification_status, verification_note, last_activity_at, created_at, updated_at
  ) values (
    v_uid, v_role, btrim(p_first_name), btrim(coalesce(p_last_name, '')),
    btrim(coalesce(p_email, '')), btrim(coalesce(p_phone_number, '')),
    btrim(coalesce(p_secondary_phone, '')), p_date_of_birth,
    btrim(coalesce(p_address, '')), btrim(coalesce(p_city, '')),
    btrim(coalesce(p_emergency_contact_name, '')),
    btrim(coalesce(p_emergency_contact_phone, '')),
    nullif(btrim(coalesce(p_avatar_path, '')), ''),
    nullif(btrim(coalesce(p_identity_document_type, '')), ''),
    btrim(coalesce(p_identity_document_number, '')),
    nullif(btrim(coalesce(p_identity_document_path, '')), ''),
    nullif(btrim(coalesce(p_identity_document_file_name, '')), ''),
    nullif(btrim(coalesce(p_identity_document_mime_type, '')), ''),
    coalesce(v_existing.verification_status, 'incomplete'),
    v_existing.verification_note,
    now(), coalesce(v_existing.created_at, now()), now()
  )
  on conflict (firebase_uid) do update
  set role = excluded.role,
      first_name = excluded.first_name,
      last_name = excluded.last_name,
      email = excluded.email,
      phone_number = excluded.phone_number,
      secondary_phone = excluded.secondary_phone,
      date_of_birth = excluded.date_of_birth,
      address = excluded.address,
      city = excluded.city,
      emergency_contact_name = excluded.emergency_contact_name,
      emergency_contact_phone = excluded.emergency_contact_phone,
      avatar_path = excluded.avatar_path,
      identity_document_type = excluded.identity_document_type,
      identity_document_number = excluded.identity_document_number,
      identity_document_path = excluded.identity_document_path,
      identity_document_file_name = excluded.identity_document_file_name,
      identity_document_mime_type = excluded.identity_document_mime_type,
      last_activity_at = now(),
      updated_at = now()
  returning * into v_result;

  v_name := btrim(v_result.first_name || ' ' || v_result.last_name);

  if v_role = 'agent' then
    insert into public.agent_personal_profiles (
      firebase_uid, first_name, last_name, date_of_birth, address, city,
      contact1, contact2, emergency_contact_name, emergency_contact_phone,
      identity_document_type, identity_document_number, avatar_path,
      identity_document_path, identity_document_file_name, identity_document_mime_type,
      verification_status, verification_note, created_at, updated_at
    ) values (
      v_uid, v_result.first_name, v_result.last_name, v_result.date_of_birth,
      v_result.address, v_result.city, v_result.phone_number, v_result.secondary_phone,
      v_result.emergency_contact_name, v_result.emergency_contact_phone,
      v_result.identity_document_type, v_result.identity_document_number,
      v_result.avatar_path, v_result.identity_document_path,
      v_result.identity_document_file_name, v_result.identity_document_mime_type,
      v_result.verification_status, v_result.verification_note,
      coalesce(v_existing.created_at, now()), now()
    )
    on conflict (firebase_uid) do update
    set first_name = excluded.first_name,
        last_name = excluded.last_name,
        date_of_birth = excluded.date_of_birth,
        address = excluded.address,
        city = excluded.city,
        contact1 = excluded.contact1,
        contact2 = excluded.contact2,
        emergency_contact_name = excluded.emergency_contact_name,
        emergency_contact_phone = excluded.emergency_contact_phone,
        identity_document_type = excluded.identity_document_type,
        identity_document_number = excluded.identity_document_number,
        avatar_path = excluded.avatar_path,
        identity_document_path = excluded.identity_document_path,
        identity_document_file_name = excluded.identity_document_file_name,
        identity_document_mime_type = excluded.identity_document_mime_type,
        verification_status = excluded.verification_status,
        verification_note = excluded.verification_note,
        updated_at = now();
  elsif v_role = 'manager' then
    update public.manager_profiles
    set display_name = case when v_name = '' then display_name else v_name end,
        email = v_result.email,
        phone_number = v_result.phone_number,
        secondary_phone = v_result.secondary_phone,
        city = v_result.city,
        address = v_result.address,
        avatar_path = v_result.avatar_path,
        last_activity_at = now(),
        updated_at = now()
    where firebase_uid = v_uid;
  end if;

  insert into public.staff_profile_audit_events (
    firebase_uid, action, actor_uid, actor_role, note
  ) values (
    v_uid,
    case when v_existing.firebase_uid is null then 'profile_created' else 'profile_updated' end,
    v_uid, v_role, null
  );

  return v_result;
end;
$$;

create or replace function public.izytel_review_staff_profile(
  p_firebase_uid text,
  p_status text,
  p_note text
)
returns public.staff_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid text := btrim(coalesce(p_firebase_uid, ''));
  v_status text := btrim(coalesce(p_status, ''));
  v_actor_uid text := (select auth.jwt()->>'sub');
  v_result public.staff_profiles;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;
  if v_uid = '' or v_status not in ('incomplete', 'pending_review', 'needs_correction', 'verified') then
    raise exception 'STAFF_REVIEW_INVALID';
  end if;
  if char_length(coalesce(p_note, '')) > 1200 then
    raise exception 'STAFF_REVIEW_INVALID';
  end if;

  update public.staff_profiles
  set verification_status = v_status,
      verification_note = nullif(btrim(coalesce(p_note, '')), ''),
      updated_at = now()
  where firebase_uid = v_uid
  returning * into v_result;

  if v_result.firebase_uid is null then
    raise exception 'STAFF_PROFILE_NOT_FOUND';
  end if;

  if v_result.role = 'agent' then
    update public.agent_personal_profiles
    set verification_status = v_status,
        verification_note = v_result.verification_note,
        updated_at = now()
    where firebase_uid = v_uid;
  end if;

  insert into public.staff_profile_audit_events (
    firebase_uid, action, actor_uid, actor_role, note
  ) values (
    v_uid, 'verification_' || v_status, v_actor_uid,
    private.izytel_current_staff_role(), v_result.verification_note
  );

  return v_result;
end;
$$;

-- Les fonctions sont exposées aux JWT Firebase, puis valident l'identité en interne.
grant execute on function public.izytel_sync_staff_profiles() to anon, authenticated;
grant execute on function public.izytel_save_own_staff_profile(
  text, text, text, text, text, date, text, text, text, text,
  text, text, text, text, text, text
) to anon, authenticated;
grant execute on function public.izytel_review_staff_profile(text, text, text) to anon, authenticated;

-- L'Admin peut consulter la pièce d'identité d'un Staff pour la vérification.
drop policy if exists "admin reads staff identity media" on storage.objects;
create policy "admin reads staff identity media"
  on storage.objects
  for select
  to anon, authenticated
  using (
    bucket_id = 'agent-personal'
    and (select private.is_izytel_finance_admin())
    and (storage.foldername(name))[2] = 'identity'
  );

-- Realtime pour avatar / fiche courante, sans polling.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'staff_profiles'
  ) then
    alter publication supabase_realtime add table public.staff_profiles;
  end if;
end;
$$;
