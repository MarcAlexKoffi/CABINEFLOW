-- IzyTel Web Client V2 - WC4B
-- La position du client reste facultative et n'est enregistree qu'apres consentement.
-- zone_id represente la zone IzyTel active la plus proche de la position consentie.
-- source_code reste independant de la geographie.

alter table public.customer_order_contexts
  add column if not exists zone_id text references public.territory_zones(id) on delete set null;

update public.customer_order_contexts
set zone_id = nearest_zone_id
where zone_id is null
  and nearest_zone_id is not null;

create index if not exists customer_order_contexts_zone_idx
  on public.customer_order_contexts(zone_id, created_at desc)
  where zone_id is not null;

create or replace function private.izytel_wc4_register_customer_context(
  p_order_id text,
  p_order_reference text,
  p_source_code text,
  p_location_status text,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_meters double precision,
  p_location_captured_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := nullif(btrim((select auth.jwt()->>'sub')), '');
  v_order_id text := btrim(coalesce(p_order_id, ''));
  v_reference text := upper(btrim(coalesce(p_order_reference, '')));
  v_source_code text := nullif(upper(btrim(coalesce(p_source_code, ''))), '');
  v_location_status text := coalesce(nullif(btrim(p_location_status), ''), 'notRequested');
  v_nearest_zone_id text;
  v_nearest_zone_distance_km double precision;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  if char_length(v_order_id) < 8
     or char_length(v_order_id) > 128
     or v_reference !~ '^CF-[0-9]{8}-[A-Z0-9]{4,12}$'
  then
    raise exception 'ORDER_CONTEXT_INVALID' using errcode = '22023';
  end if;

  if not private.izytel_wc4_customer_owns_order(v_order_id, v_reference, v_uid) then
    raise exception 'ORDER_NOT_AUTHORIZED' using errcode = '42501';
  end if;

  if v_source_code is not null
     and v_source_code !~ '^[A-Z0-9][A-Z0-9_-]{0,63}$'
  then
    raise exception 'SOURCE_CODE_INVALID' using errcode = '22023';
  end if;

  if v_location_status not in ('notRequested', 'granted', 'denied', 'unavailable') then
    raise exception 'LOCATION_STATUS_INVALID' using errcode = '22023';
  end if;

  if v_location_status = 'granted' then
    if p_latitude is null
       or p_longitude is null
       or p_location_captured_at is null
       or p_latitude < -90
       or p_latitude > 90
       or p_longitude < -180
       or p_longitude > 180
       or (p_accuracy_meters is not null and (p_accuracy_meters < 0 or p_accuracy_meters > 100000))
    then
      raise exception 'LOCATION_INVALID' using errcode = '22023';
    end if;

    select zone.id,
           6371.0 * 2.0 * asin(
             sqrt(
               power(sin(radians(zone.latitude - p_latitude) / 2.0), 2)
               + cos(radians(p_latitude))
                 * cos(radians(zone.latitude))
                 * power(sin(radians(zone.longitude - p_longitude) / 2.0), 2)
             )
           )
      into v_nearest_zone_id, v_nearest_zone_distance_km
    from public.territory_zones zone
    where zone.is_active = true
      and zone.latitude is not null
      and zone.longitude is not null
    order by 2 asc
    limit 1;
  else
    if p_latitude is not null
       or p_longitude is not null
       or p_accuracy_meters is not null
       or p_location_captured_at is not null
    then
      raise exception 'LOCATION_CONSENT_REQUIRED' using errcode = '22023';
    end if;
  end if;

  insert into public.customer_order_contexts (
    order_id, order_reference, owner_firebase_uid, source_code,
    location_status, latitude, longitude, accuracy_meters,
    location_captured_at, nearest_zone_id, nearest_zone_distance_km,
    zone_id, created_at, updated_at
  ) values (
    v_order_id, v_reference, v_uid, v_source_code,
    v_location_status,
    case when v_location_status = 'granted' then p_latitude else null end,
    case when v_location_status = 'granted' then p_longitude else null end,
    case when v_location_status = 'granted' then p_accuracy_meters else null end,
    case when v_location_status = 'granted' then p_location_captured_at else null end,
    case when v_location_status = 'granted' then v_nearest_zone_id else null end,
    case when v_location_status = 'granted' then v_nearest_zone_distance_km else null end,
    case when v_location_status = 'granted' then v_nearest_zone_id else null end,
    now(), now()
  )
  on conflict (order_id)
  do update set
    order_reference = excluded.order_reference,
    source_code = coalesce(public.customer_order_contexts.source_code, excluded.source_code),
    location_status = excluded.location_status,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    accuracy_meters = excluded.accuracy_meters,
    location_captured_at = excluded.location_captured_at,
    nearest_zone_id = excluded.nearest_zone_id,
    nearest_zone_distance_km = excluded.nearest_zone_distance_km,
    zone_id = excluded.zone_id,
    updated_at = now()
  where public.customer_order_contexts.owner_firebase_uid = v_uid;

  if not found then
    raise exception 'ORDER_CONTEXT_NOT_AUTHORIZED' using errcode = '42501';
  end if;

  return (
    select jsonb_build_object(
      'order_id', context_row.order_id,
      'order_reference', context_row.order_reference,
      'source_code', context_row.source_code,
      'location_status', context_row.location_status,
      'zone_id', context_row.zone_id,
      'nearest_zone_id', context_row.nearest_zone_id,
      'nearest_zone_distance_km', context_row.nearest_zone_distance_km,
      'updated_at', context_row.updated_at
    )
    from public.customer_order_contexts context_row
    where context_row.order_id = v_order_id
  );
end;
$function$;
