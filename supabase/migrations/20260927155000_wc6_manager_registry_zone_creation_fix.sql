-- IzyTel WC6 hotfix — registre Managers et création de zones
-- Objectifs :
-- 1. permettre au Back-office Admin, authentifié via JWT Firebase, d'exécuter
--    les RPC de création/mise à jour de zone (la fonction garde son contrôle
--    ADMIN_REQUIRED côté serveur) ;
-- 2. provisionner automatiquement dans Supabase les comptes Manager/Supervisor
--    canoniques créés dans Firestore /users.

create or replace function public.izytel_wc6_provision_manager_account(
  p_firebase_uid text,
  p_display_name text,
  p_is_active boolean default true
)
returns public.manager_profiles
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := btrim(coalesce(p_firebase_uid, ''));
  v_name text := coalesce(nullif(btrim(coalesce(p_display_name, '')), ''), 'Manager IzyTel');
  v_active boolean := coalesce(p_is_active, false);
  v_result public.manager_profiles;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode = '42501';
  end if;

  if v_uid = '' or char_length(v_uid) > 160 then
    raise exception 'MANAGER_UID_INVALID' using errcode = '22023';
  end if;
  if char_length(v_name) < 2 or char_length(v_name) > 120 then
    raise exception 'MANAGER_NAME_INVALID' using errcode = '22023';
  end if;

  insert into public.izytel_staff_access (
    firebase_uid, role, is_active, display_name, created_at, updated_at
  ) values (
    v_uid, 'manager', v_active, v_name, now(), now()
  )
  on conflict (firebase_uid) do update
  set role = 'manager',
      is_active = excluded.is_active,
      display_name = excluded.display_name,
      updated_at = now();

  insert into public.manager_profiles (
    firebase_uid,
    display_name,
    is_active,
    is_available,
    last_activity_at,
    created_at,
    updated_at
  ) values (
    v_uid,
    v_name,
    v_active,
    v_active,
    now(),
    now(),
    now()
  )
  on conflict (firebase_uid) do update
  set display_name = excluded.display_name,
      is_active = excluded.is_active,
      is_available = case
        when excluded.is_active = false then false
        else public.manager_profiles.is_available
      end,
      updated_at = now()
  returning * into v_result;

  return v_result;
end;
$function$;

revoke all on function public.izytel_wc6_provision_manager_account(text,text,boolean) from public;
grant execute on function public.izytel_wc6_provision_manager_account(text,text,boolean)
  to anon, authenticated, service_role;

-- Les JWT Firebase utilisés par IzyTel peuvent arriver côté PostgREST sous le
-- rôle SQL anon tout en conservant auth.jwt()->>'sub'. L'autorisation métier
-- reste donc strictement vérifiée à l'intérieur des fonctions via
-- private.is_izytel_finance_admin().
grant execute on function public.izytel_wc5_create_territory_zone(
  text,text,text,double precision,double precision,text,double precision,boolean,boolean
) to anon, authenticated, service_role;

grant execute on function public.izytel_wc5_update_territory_zone(
  text,text,text,text,double precision,double precision,text,double precision,boolean,boolean
) to anon, authenticated, service_role;

notify pgrst, 'reload schema';
