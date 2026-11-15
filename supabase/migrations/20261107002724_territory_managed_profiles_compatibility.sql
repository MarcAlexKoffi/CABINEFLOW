-- Profile consultation and edits preserve the secured account lifecycle.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';

-- Existing rows use UPDATE: BEFORE INSERT guards also run on ON CONFLICT.
create or replace function public.izytel_sync_manager_profiles()
returns integer language plpgsql security definer set search_path='' as $$
declare v_count integer;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
  end if;

  update public.manager_profiles m
  set display_name=case when btrim(m.display_name)='' then s.display_name else m.display_name end,
      last_activity_at=greatest(m.last_activity_at,s.updated_at),
      updated_at=greatest(m.updated_at,s.updated_at)
  from public.izytel_staff_access s
  where s.firebase_uid=m.firebase_uid and s.role in ('manager','supervisor');

  -- Only untouched legacy identities may need a missing territorial profile.
  -- Managed identities must be repaired by the secured account service.
  insert into public.manager_profiles(
    firebase_uid,display_name,is_active,is_available,last_activity_at,created_at,updated_at
  )
  select s.firebase_uid,coalesce(nullif(btrim(s.display_name),''),'Manager IzyTel'),
    s.is_active,s.is_active,s.updated_at,s.created_at,s.updated_at
  from public.izytel_staff_access s
  where s.role in ('manager','supervisor')
    and not exists(select 1 from public.manager_profiles m where m.firebase_uid=s.firebase_uid)
    and not exists(select 1 from public.izytel_user_admin_operations o
      where o.target_uid=s.firebase_uid and o.command->>'action' in ('create','update'))
  on conflict(firebase_uid) do nothing;

  select count(*) into v_count from public.manager_profiles m
    join public.izytel_staff_access s on s.firebase_uid=m.firebase_uid
    where s.role in ('manager','supervisor');
  return v_count;
end;
$$;

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
  where firebase_uid = v_uid for update;

  if v_before.firebase_uid is null then
    raise exception 'MANAGER_STAFF_ACCOUNT_REQUIRED';
  end if;

  -- Profile edits must never recreate an account or modify its active access.
  update public.manager_profiles
  set display_name=v_name,
      email=btrim(coalesce(p_email,'')),
      phone_number=btrim(coalesce(p_phone_number,'')),
      secondary_phone=btrim(coalesce(p_secondary_phone,'')),
      city=btrim(coalesce(p_city,'')),
      address=btrim(coalesce(p_address,'')),
      notes=btrim(coalesce(p_notes,'')),
      is_available=coalesce(p_is_available,false),
      updated_at=now()
  where firebase_uid=v_uid
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

-- CREATE OR REPLACE retains the existing ACL; no new endpoint or role grant.
notify pgrst,'reload schema';
commit;
