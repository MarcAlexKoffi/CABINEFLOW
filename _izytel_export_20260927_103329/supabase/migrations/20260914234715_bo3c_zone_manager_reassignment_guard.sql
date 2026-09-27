-- BO-3C — un Manager devenu indisponible conserve ses zones existantes.
-- La disponibilité n'est vérifiée que lors d'une nouvelle attribution/changement.

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
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if v_id = '' then raise exception 'ZONE_REQUIRED'; end if;
  if char_length(btrim(coalesce(p_name, ''))) < 2
     or char_length(btrim(coalesce(p_name, ''))) > 120 then
    raise exception 'ZONE_NAME_INVALID';
  end if;
  if (p_latitude is null) <> (p_longitude is null) then
    raise exception 'ZONE_COORDINATES_INCOMPLETE';
  end if;
  if p_latitude is not null and
     (p_latitude < -90 or p_latitude > 90 or p_longitude < -180 or p_longitude > 180) then
    raise exception 'ZONE_COORDINATES_INVALID';
  end if;

  select * into v_before
  from public.territory_zones
  where id = v_id
  for update;
  if not found then raise exception 'ZONE_NOT_FOUND'; end if;

  if v_manager_id is distinct from v_before.manager_id then
    perform private.izytel_assert_manager(v_manager_id);
  end if;

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
