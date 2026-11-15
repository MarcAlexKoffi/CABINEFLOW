CREATE OR REPLACE FUNCTION public.izytel_sync_manager_profiles()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    is_available,
    last_activity_at,
    created_at,
    updated_at
  )
  select
    staff.firebase_uid,
    coalesce(nullif(btrim(staff.display_name), ''), 'Manager IzyTel'),
    staff.is_active,
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
      last_activity_at = excluded.last_activity_at,
      updated_at = greatest(public.manager_profiles.updated_at, excluded.updated_at);

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

CREATE OR REPLACE FUNCTION public.izytel_save_manager_profile(p_firebase_uid text, p_display_name text, p_email text, p_phone_number text, p_secondary_phone text, p_city text, p_address text, p_notes text, p_is_available boolean)
 RETURNS manager_profiles
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    city, address, notes, is_active, is_available, last_activity_at,
    created_at, updated_at
  )
  select
    v_uid, v_name, btrim(coalesce(p_email, '')), btrim(coalesce(p_phone_number, '')),
    btrim(coalesce(p_secondary_phone, '')), btrim(coalesce(p_city, '')),
    btrim(coalesce(p_address, '')), btrim(coalesce(p_notes, '')),
    staff.is_active, p_is_available, staff.updated_at, staff.created_at, now()
  from public.izytel_staff_access staff
  where staff.firebase_uid = v_uid
  on conflict (firebase_uid) do update
  set display_name = excluded.display_name,
      email = excluded.email,
      phone_number = excluded.phone_number,
      secondary_phone = excluded.secondary_phone,
      city = excluded.city,
      address = excluded.address,
      notes = excluded.notes,
      is_active = excluded.is_active,
      is_available = excluded.is_available,
      last_activity_at = excluded.last_activity_at,
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
$function$;
