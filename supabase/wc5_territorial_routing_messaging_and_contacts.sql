-- IzyTel WC5
-- - retire le telephone WhatsApp du circuit operationnel client
-- - route commandes et conversations par zone geographique
-- - utilise Abidjan comme centre de repli uniquement si aucune zone ne couvre
--   la localisation disponible
-- - alimente les contacts frequents avec le couple nom + beneficiaire
-- - notifie automatiquement les commandes terminees dans la messagerie IzyTel

-- ---------------------------------------------------------------------------
-- 1. Parametrage territorial
-- ---------------------------------------------------------------------------

alter table public.territory_zones
  add column if not exists coverage_radius_km double precision not null default 50.0,
  add column if not exists is_central_fallback boolean not null default false;

alter table public.territory_zones
  drop constraint if exists territory_zones_coverage_radius_km_check;
alter table public.territory_zones
  add constraint territory_zones_coverage_radius_km_check
  check (coverage_radius_km > 0 and coverage_radius_km <= 250);

create unique index if not exists territory_zones_one_active_fallback_idx
  on public.territory_zones (is_central_fallback)
  where is_central_fallback = true and is_active = true;

-- Si aucun centre n'est encore declare, selectionner automatiquement la zone
-- active d'Abidjan la plus proche du centre-ville. Aucun ID n'est code en dur.
do $block$
declare
  v_fallback_id text;
begin
  if not exists (
    select 1
    from public.territory_zones z
    where z.is_active = true
      and z.is_central_fallback = true
  ) then
    select z.id
      into v_fallback_id
    from public.territory_zones z
    where z.is_active = true
      and lower(btrim(z.city)) = 'abidjan'
    order by
      case
        when z.latitude is null or z.longitude is null then 1
        else 0
      end,
      case
        when z.latitude is null or z.longitude is null then null
        else 6371.0 * 2.0 * asin(
          sqrt(
            power(sin(radians(z.latitude - 5.35995) / 2.0), 2)
            + cos(radians(5.35995))
              * cos(radians(z.latitude))
              * power(sin(radians(z.longitude - (-4.00826)) / 2.0), 2)
          )
        )
      end nulls last,
      z.id
    limit 1;

    if v_fallback_id is not null then
      update public.territory_zones
      set is_central_fallback = true,
          updated_at = now()
      where id = v_fallback_id;
    end if;
  end if;
end;
$block$;

create or replace function public.izytel_wc5_create_territory_zone(
  p_name text,
  p_city text,
  p_region text,
  p_latitude double precision,
  p_longitude double precision,
  p_manager_id text,
  p_coverage_radius_km double precision default 50.0,
  p_is_central_fallback boolean default false,
  p_is_active boolean default true
)
returns public.territory_zones
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor_uid text := (select auth.jwt()->>'sub');
  v_actor_name text := private.izytel_staff_display_name();
  v_manager_id text := nullif(btrim(coalesce(p_manager_id, '')), '');
  v_city text := btrim(coalesce(p_city, ''));
  v_result public.territory_zones;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode = '42501';
  end if;
  if char_length(btrim(coalesce(p_name, ''))) < 2
     or char_length(btrim(coalesce(p_name, ''))) > 120 then
    raise exception 'ZONE_NAME_INVALID' using errcode = '22023';
  end if;
  if (p_latitude is null) <> (p_longitude is null) then
    raise exception 'ZONE_COORDINATES_INCOMPLETE' using errcode = '22023';
  end if;
  if p_latitude is not null and (
    p_latitude < -90 or p_latitude > 90
    or p_longitude < -180 or p_longitude > 180
  ) then
    raise exception 'ZONE_COORDINATES_INVALID' using errcode = '22023';
  end if;
  if p_coverage_radius_km is null
     or p_coverage_radius_km <= 0
     or p_coverage_radius_km > 250 then
    raise exception 'ZONE_COVERAGE_RADIUS_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_is_central_fallback, false)
     and (lower(v_city) <> 'abidjan' or not coalesce(p_is_active, true)) then
    raise exception 'CENTRAL_FALLBACK_MUST_BE_ACTIVE_ABIDJAN_ZONE' using errcode = '22023';
  end if;

  perform private.izytel_assert_manager(v_manager_id);

  if coalesce(p_is_central_fallback, false) then
    update public.territory_zones
    set is_central_fallback = false,
        updated_at = now()
    where is_central_fallback = true;
  end if;

  insert into public.territory_zones (
    name, city, region, latitude, longitude, manager_id,
    coverage_radius_km, is_central_fallback, is_active,
    created_at, updated_at
  ) values (
    btrim(p_name), v_city, btrim(coalesce(p_region, '')),
    p_latitude, p_longitude, v_manager_id,
    p_coverage_radius_km, coalesce(p_is_central_fallback, false),
    coalesce(p_is_active, true), now(), now()
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
$function$;

create or replace function public.izytel_wc5_update_territory_zone(
  p_zone_id text,
  p_name text,
  p_city text,
  p_region text,
  p_latitude double precision,
  p_longitude double precision,
  p_manager_id text,
  p_coverage_radius_km double precision,
  p_is_central_fallback boolean,
  p_is_active boolean
)
returns public.territory_zones
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_id text := btrim(coalesce(p_zone_id, ''));
  v_actor_uid text := (select auth.jwt()->>'sub');
  v_actor_name text := private.izytel_staff_display_name();
  v_manager_id text := nullif(btrim(coalesce(p_manager_id, '')), '');
  v_city text := btrim(coalesce(p_city, ''));
  v_before public.territory_zones;
  v_result public.territory_zones;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode = '42501';
  end if;
  if v_id = '' then
    raise exception 'ZONE_REQUIRED' using errcode = '22023';
  end if;
  if char_length(btrim(coalesce(p_name, ''))) < 2
     or char_length(btrim(coalesce(p_name, ''))) > 120 then
    raise exception 'ZONE_NAME_INVALID' using errcode = '22023';
  end if;
  if (p_latitude is null) <> (p_longitude is null) then
    raise exception 'ZONE_COORDINATES_INCOMPLETE' using errcode = '22023';
  end if;
  if p_latitude is not null and (
    p_latitude < -90 or p_latitude > 90
    or p_longitude < -180 or p_longitude > 180
  ) then
    raise exception 'ZONE_COORDINATES_INVALID' using errcode = '22023';
  end if;
  if p_coverage_radius_km is null
     or p_coverage_radius_km <= 0
     or p_coverage_radius_km > 250 then
    raise exception 'ZONE_COVERAGE_RADIUS_INVALID' using errcode = '22023';
  end if;
  if coalesce(p_is_central_fallback, false)
     and (lower(v_city) <> 'abidjan' or not coalesce(p_is_active, false)) then
    raise exception 'CENTRAL_FALLBACK_MUST_BE_ACTIVE_ABIDJAN_ZONE' using errcode = '22023';
  end if;

  select * into v_before
  from public.territory_zones
  where id = v_id
  for update;
  if not found then
    raise exception 'ZONE_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_manager_id is distinct from v_before.manager_id then
    perform private.izytel_assert_manager(v_manager_id);
  end if;

  if coalesce(p_is_central_fallback, false) then
    update public.territory_zones
    set is_central_fallback = false,
        updated_at = now()
    where id <> v_id
      and is_central_fallback = true;
  end if;

  update public.territory_zones
  set name = btrim(p_name),
      city = v_city,
      region = btrim(coalesce(p_region, '')),
      latitude = p_latitude,
      longitude = p_longitude,
      manager_id = v_manager_id,
      coverage_radius_km = p_coverage_radius_km,
      is_central_fallback = coalesce(p_is_central_fallback, false),
      is_active = coalesce(p_is_active, false),
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
$function$;

create or replace function private.izytel_wc5_fallback_zone_id()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_zone_id text;
begin
  select z.id
    into v_zone_id
  from public.territory_zones z
  where z.is_active = true
    and z.is_central_fallback = true
  order by z.updated_at desc, z.id
  limit 1;

  if v_zone_id is null then
    select z.id
      into v_zone_id
    from public.territory_zones z
    where z.is_active = true
      and lower(btrim(z.city)) = 'abidjan'
    order by
      case
        when z.latitude is null or z.longitude is null then 1
        else 0
      end,
      case
        when z.latitude is null or z.longitude is null then null
        else 6371.0 * 2.0 * asin(
          sqrt(
            power(sin(radians(z.latitude - 5.35995) / 2.0), 2)
            + cos(radians(5.35995))
              * cos(radians(z.latitude))
              * power(sin(radians(z.longitude - (-4.00826)) / 2.0), 2)
          )
        )
      end nulls last,
      z.id
    limit 1;
  end if;

  if v_zone_id is null then
    raise exception 'CENTRAL_ZONE_NOT_CONFIGURED' using errcode = 'P0001';
  end if;

  return v_zone_id;
end;
$function$;

create or replace function private.izytel_wc5_zone_for_location(
  p_latitude double precision,
  p_longitude double precision
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_zone_id text;
begin
  if p_latitude is null
     or p_longitude is null
     or p_latitude < -90
     or p_latitude > 90
     or p_longitude < -180
     or p_longitude > 180
  then
    return private.izytel_wc5_fallback_zone_id();
  end if;

  select candidate.id
    into v_zone_id
  from (
    select
      z.id,
      z.coverage_radius_km,
      6371.0 * 2.0 * asin(
        sqrt(
          power(sin(radians(z.latitude - p_latitude) / 2.0), 2)
          + cos(radians(p_latitude))
            * cos(radians(z.latitude))
            * power(sin(radians(z.longitude - p_longitude) / 2.0), 2)
        )
      ) as distance_km
    from public.territory_zones z
    where z.is_active = true
      and z.latitude is not null
      and z.longitude is not null
  ) candidate
  where candidate.distance_km <= candidate.coverage_radius_km
  order by candidate.distance_km asc, candidate.id
  limit 1;

  return coalesce(v_zone_id, private.izytel_wc5_fallback_zone_id());
end;
$function$;

create or replace function private.izytel_wc5_manager_owns_zone(
  p_zone_id text,
  p_manager_uid text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.territory_zones z
    join public.izytel_staff_access staff
      on staff.firebase_uid = z.manager_id
    where z.id = btrim(coalesce(p_zone_id, ''))
      and z.is_active = true
      and z.manager_id = btrim(coalesce(p_manager_uid, ''))
      and staff.is_active = true
      and staff.role in ('manager', 'supervisor')
  );
$function$;

create or replace function private.izytel_wc5_can_manage_zone(p_zone_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select public.is_izytel_firebase_jwt()
    and (
      private.is_izytel_finance_admin()
      or private.izytel_wc5_manager_owns_zone(
        p_zone_id,
        (select auth.jwt()->>'sub')
      )
    );
$function$;

-- ---------------------------------------------------------------------------
-- 2. Zone canonique sur les commandes et conversations
-- ---------------------------------------------------------------------------

alter table public.phase4_assignment_orders
  add column if not exists zone_id text references public.territory_zones(id) on delete set null;
create index if not exists phase4_assignment_orders_zone_idx
  on public.phase4_assignment_orders(zone_id, updated_at desc);

alter table public.customer_conversations
  add column if not exists zone_id text references public.territory_zones(id) on delete set null,
  add column if not exists customer_name text not null default 'Client';
create index if not exists customer_conversations_zone_status_idx
  on public.customer_conversations(zone_id, status, updated_at desc);

alter table public.customer_order_recovery_registry
  add column if not exists client_name text not null default 'Client';

-- Recalculer aussi les contextes deja captures : les versions WC4
-- utilisaient la zone la plus proche sans notion de perimetre maximal.
update public.customer_order_contexts c
set zone_id = case
      when c.location_status = 'granted'
           and c.latitude is not null
           and c.longitude is not null
        then private.izytel_wc5_zone_for_location(c.latitude, c.longitude)
      else private.izytel_wc5_fallback_zone_id()
    end,
    updated_at = now();

-- Backfill sans perdre les anciennes lignes.
update public.customer_order_recovery_registry r
set client_name = coalesce(
      nullif(btrim(o.client_name), ''),
      nullif(btrim(r.client_name), ''),
      'Client'
    )
from public.phase4_assignment_orders o
where o.order_id = r.order_id
  and upper(o.order_reference) = r.order_reference;

-- Le trigger operationnel exige une session staff pour les UPDATE normaux.
-- Pendant ce backfill de migration, neutraliser uniquement les triggers user
-- afin de ne pas transformer une maintenance serveur en action metier.
alter table public.phase4_assignment_orders disable trigger user;
update public.phase4_assignment_orders o
set zone_id = coalesce(
      (
        select c.zone_id
        from public.customer_order_contexts c
        where c.order_id = o.order_id
          and upper(c.order_reference) = upper(o.order_reference)
        limit 1
      ),
      private.izytel_wc5_fallback_zone_id()
    )
where o.zone_id is null;
alter table public.phase4_assignment_orders enable trigger user;

update public.customer_conversations conversation_row
set zone_id = coalesce(
      (
        select c.zone_id
        from public.customer_order_contexts c
        where c.order_id = conversation_row.order_id
          and upper(c.order_reference) = upper(conversation_row.order_reference)
        limit 1
      ),
      (
        select o.zone_id
        from public.phase4_assignment_orders o
        where o.order_id = conversation_row.order_id
          and upper(o.order_reference) = upper(conversation_row.order_reference)
        limit 1
      ),
      private.izytel_wc5_fallback_zone_id()
    ),
    customer_name = coalesce(
      (
        select nullif(btrim(o.client_name), '')
        from public.phase4_assignment_orders o
        where o.order_id = conversation_row.order_id
          and upper(o.order_reference) = upper(conversation_row.order_reference)
        limit 1
      ),
      (
        select nullif(btrim(r.client_name), '')
        from public.customer_order_recovery_registry r
        where r.order_id = conversation_row.order_id
          and upper(r.order_reference) = upper(conversation_row.order_reference)
        limit 1
      ),
      nullif(btrim(conversation_row.customer_name), ''),
      'Client'
    )
where conversation_row.zone_id is null
   or btrim(coalesce(conversation_row.customer_name, '')) in ('', 'Client');

-- ---------------------------------------------------------------------------
-- 3. Enregistrement du contexte client : zone couverte sinon centre Abidjan
-- ---------------------------------------------------------------------------

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
  v_zone_id text;
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

    v_zone_id := private.izytel_wc5_zone_for_location(p_latitude, p_longitude);
  else
    if p_latitude is not null
       or p_longitude is not null
       or p_accuracy_meters is not null
       or p_location_captured_at is not null
    then
      raise exception 'LOCATION_CONSENT_REQUIRED' using errcode = '22023';
    end if;

    v_zone_id := private.izytel_wc5_fallback_zone_id();
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
    v_zone_id,
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
      'routing_fallback_used', context_row.zone_id = private.izytel_wc5_fallback_zone_id(),
      'updated_at', context_row.updated_at
    )
    from public.customer_order_contexts context_row
    where context_row.order_id = v_order_id
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- 4. Nom client canonique dans la recuperation/historique
-- ---------------------------------------------------------------------------

create or replace function private.izytel_wc2_register_customer_recovery(
  p_payload jsonb,
  p_recovery_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text;
  v_order_id text;
  v_reference text;
  v_code text;
  v_client_name text;
  v_service text;
  v_network text;
  v_operation_type text;
  v_offer_id text;
  v_offer_label text;
  v_is_custom_offer boolean;
  v_amount integer;
  v_beneficiary text;
  v_created_at timestamptz;
  v_expires_at timestamptz;
  v_order_status text;
  v_payment_status text;
  v_payment_declared_at timestamptz;
  v_payment_confirmed_at timestamptz;
  v_expired_at timestamptz;
  v_existing public.customer_order_recovery_registry;
begin
  if not public.is_izytel_firebase_jwt() then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  v_uid := nullif((select auth.jwt()->>'sub'), '');
  if v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  v_order_id := btrim(coalesce(p_payload->>'order_id', ''));
  v_reference := upper(btrim(coalesce(p_payload->>'order_reference', '')));
  v_code := upper(btrim(coalesce(p_recovery_code, '')));
  v_client_name := regexp_replace(btrim(coalesce(p_payload->>'client_name', 'Client')), '\s+', ' ', 'g');
  v_service := btrim(coalesce(p_payload->>'service', ''));
  v_network := lower(btrim(coalesce(p_payload->>'network', '')));
  v_operation_type := btrim(coalesce(p_payload->>'operation_type', ''));
  v_offer_id := nullif(btrim(coalesce(p_payload->>'offer_id', '')), '');
  v_offer_label := btrim(coalesce(p_payload->>'offer_label', ''));
  v_is_custom_offer := coalesce((p_payload->>'is_custom_offer')::boolean, false);
  v_amount := coalesce((p_payload->>'amount')::integer, 0);
  v_beneficiary := btrim(coalesce(p_payload->>'beneficiary_phone', ''));
  v_created_at := (p_payload->>'created_at')::timestamptz;
  v_expires_at := (p_payload->>'expires_at')::timestamptz;
  v_order_status := btrim(coalesce(p_payload->>'order_status', 'awaitingPayment'));
  v_payment_status := btrim(coalesce(p_payload->>'payment_status', 'notDeclared'));
  v_payment_declared_at := nullif(p_payload->>'payment_declared_at', '')::timestamptz;
  v_payment_confirmed_at := nullif(p_payload->>'payment_confirmed_at', '')::timestamptz;
  v_expired_at := nullif(p_payload->>'expired_at', '')::timestamptz;

  if char_length(v_order_id) < 8 or char_length(v_order_id) > 128
    or v_reference !~ '^CF-[0-9]{8}-[A-Z0-9]{4,12}$'
    or v_code !~ '^IZY-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$'
    or char_length(v_client_name) < 2 or char_length(v_client_name) > 50
    or v_service not in ('unitTransfer','internetSubscription','calls')
    or v_network not in ('orange','mtn','moov')
    or v_operation_type not in ('internetSubscription','unitTransfer','callBundle','mixedBundle','other')
    or char_length(v_offer_label) < 2 or char_length(v_offer_label) > 200
    or v_amount <= 0 or v_amount > 1000000
    or char_length(v_beneficiary) < 10 or char_length(v_beneficiary) > 24
    or v_created_at is null
    or v_expires_at is null
    or v_expires_at <= v_created_at
    or v_order_status not in (
      'awaitingPayment', 'paymentToVerify', 'paidReady', 'inProgress', 'onHold',
      'awaitingCustomerConfirmation', 'completed', 'failed', 'expired',
      'cancelled', 'refundPending', 'refunded'
    )
    or v_payment_status not in (
      'notDeclared', 'pending', 'declared', 'confirmed', 'credit', 'rejected', 'expired'
    )
  then
    raise exception 'INVALID_RECOVERY_PAYLOAD' using errcode = '22023';
  end if;

  select * into v_existing
  from public.customer_order_recovery_registry
  where order_id = v_order_id;

  if found then
    if v_existing.owner_firebase_uid <> v_uid
      or v_existing.order_reference <> v_reference
      or extensions.crypt(v_code, v_existing.recovery_code_hash) <> v_existing.recovery_code_hash
      or v_existing.service <> v_service
      or v_existing.network <> v_network
      or v_existing.operation_type <> v_operation_type
      or coalesce(v_existing.offer_id, '') <> coalesce(v_offer_id, '')
      or v_existing.offer_label <> v_offer_label
      or v_existing.is_custom_offer <> v_is_custom_offer
      or v_existing.amount <> v_amount
      or v_existing.beneficiary_phone <> v_beneficiary
    then
      raise exception 'RECOVERY_REGISTRATION_CONFLICT' using errcode = '23505';
    end if;

    update public.customer_order_recovery_registry
    set client_name = v_client_name,
        order_status = v_order_status,
        payment_status = v_payment_status,
        payment_declared_at = v_payment_declared_at,
        payment_confirmed_at = v_payment_confirmed_at,
        expired_at = v_expired_at,
        updated_at = now()
    where order_id = v_order_id;

    return jsonb_build_object(
      'order_id', v_existing.order_id,
      'order_reference', v_existing.order_reference,
      'registered', true
    );
  end if;

  if exists (
    select 1
    from public.customer_order_recovery_registry
    where order_reference = v_reference
  ) then
    raise exception 'RECOVERY_REFERENCE_CONFLICT' using errcode = '23505';
  end if;

  insert into public.customer_order_recovery_registry (
    order_id,
    order_reference,
    owner_firebase_uid,
    recovery_code_hash,
    client_name,
    service,
    network,
    operation_type,
    offer_id,
    offer_label,
    is_custom_offer,
    amount,
    beneficiary_phone,
    created_at,
    expires_at,
    order_status,
    payment_status,
    payment_declared_at,
    payment_confirmed_at,
    expired_at
  ) values (
    v_order_id,
    v_reference,
    v_uid,
    extensions.crypt(v_code, extensions.gen_salt('bf', 10)),
    v_client_name,
    v_service,
    v_network,
    v_operation_type,
    v_offer_id,
    v_offer_label,
    v_is_custom_offer,
    v_amount,
    v_beneficiary,
    v_created_at,
    v_expires_at,
    v_order_status,
    v_payment_status,
    v_payment_declared_at,
    v_payment_confirmed_at,
    v_expired_at
  );

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_reference', v_reference,
    'registered', true
  );
end;
$function$;

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
    'client_name', coalesce(nullif(btrim(v_order.client_name), ''), v_registry.client_name),
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

create or replace function private.izytel_wc2_customer_order_history()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := nullif(btrim((select auth.jwt()->>'sub')), '');
  v_result jsonb;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'order_id', r.order_id,
        'order_reference', r.order_reference,
        'client_name', coalesce(nullif(btrim(o.client_name), ''), r.client_name),
        'service', r.service,
        'network', coalesce(o.network, r.network),
        'operation_type', coalesce(o.operation_type, r.operation_type),
        'offer_id', r.offer_id,
        'offer_label', coalesce(o.offer_label, r.offer_label),
        'is_custom_offer', r.is_custom_offer,
        'amount', coalesce(o.amount, r.amount),
        'beneficiary_phone', coalesce(o.beneficiary_phone, r.beneficiary_phone),
        'created_at', r.created_at,
        'expires_at', r.expires_at,
        'order_status', coalesce(
          o.order_status,
          case
            when now() >= r.expires_at
                 and r.order_status = 'awaitingPayment'
                 and r.payment_status = 'notDeclared'
              then 'expired'
            else r.order_status
          end
        ),
        'payment_status', coalesce(
          o.payment_status,
          case
            when now() >= r.expires_at
                 and r.order_status = 'awaitingPayment'
                 and r.payment_status = 'notDeclared'
              then 'expired'
            else r.payment_status
          end
        ),
        'payment_declared_at', r.payment_declared_at,
        'payment_confirmed_at', coalesce(o.payment_confirmed_at, r.payment_confirmed_at),
        'expired_at', coalesce(
          r.expired_at,
          case
            when o.order_id is null
                 and now() >= r.expires_at
                 and r.order_status = 'awaitingPayment'
                 and r.payment_status = 'notDeclared'
              then r.expires_at
            else null
          end
        ),
        'processing_started_at', o.processing_started_at,
        'completed_at', o.completed_at,
        'failure_reason', o.failure_reason,
        'observation', o.observation,
        'customer_confirmation_status', o.customer_confirmation_status,
        'updated_at', coalesce(o.updated_at, r.updated_at)
      )
      order by r.created_at desc
    ),
    '[]'::jsonb
  )
  into v_result
  from public.customer_order_recovery_registry r
  left join public.phase4_assignment_orders o
    on o.order_id = r.order_id
   and upper(o.order_reference) = r.order_reference
  where r.owner_firebase_uid = v_uid
     or exists (
       select 1
       from public.customer_order_recovery_access a
       where a.order_id = r.order_id
         and upper(a.order_reference) = r.order_reference
         and a.customer_firebase_uid = v_uid
     );

  return v_result;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Synchronisation/eligibilite : meme zone uniquement
-- ---------------------------------------------------------------------------

create or replace function public.phase3_sync_order(
  p_order_id text,
  p_order_reference text,
  p_network text,
  p_amount integer,
  p_firebase_created_at timestamptz,
  p_paid_at timestamptz,
  p_source text,
  p_client_name text,
  p_client_whatsapp_phone text,
  p_beneficiary_phone text,
  p_operation_type text,
  p_offer_label text,
  p_original_whatsapp_message text,
  p_internal_notes text,
  p_payment_status text,
  p_payment_payer_name text,
  p_payment_reference text,
  p_payment_confirmed_at timestamptz,
  p_customer_auth_uid text default null
)
returns public.phase4_assignment_orders
language plpgsql
set search_path = ''
as $function$
declare
  v_row public.phase4_assignment_orders;
  v_zone_id text;
begin
  if not private.is_izytel_phase4_staff() then
    raise exception 'STAFF_REQUIRED';
  end if;
  if btrim(coalesce(p_order_id,''))='' or btrim(coalesce(p_order_reference,''))='' then
    raise exception 'INVALID_ORDER';
  end if;
  if p_network not in ('orange','mtn','moov') or p_amount<=0 then
    raise exception 'INVALID_ORDER';
  end if;
  if p_source not in ('customerWeb','operatorApp') then
    raise exception 'INVALID_SOURCE';
  end if;
  if p_operation_type not in ('internetSubscription','unitTransfer','callBundle','mixedBundle','other') then
    raise exception 'INVALID_OPERATION_TYPE';
  end if;
  if p_payment_status not in ('confirmed','credit') then
    raise exception 'INVALID_PAYMENT_STATUS';
  end if;

  select c.zone_id
    into v_zone_id
  from public.customer_order_contexts c
  where c.order_id = btrim(p_order_id)
    and upper(c.order_reference) = upper(btrim(p_order_reference))
  limit 1;

  v_zone_id := coalesce(v_zone_id, private.izytel_wc5_fallback_zone_id());

  insert into public.phase4_assignment_orders(
    order_id,order_reference,network,amount,firebase_created_at,paid_at,
    source,customer_auth_uid,client_name,client_whatsapp_phone,beneficiary_phone,
    operation_type,offer_label,original_whatsapp_message,internal_notes,
    payment_status,payment_payer_name,payment_reference,payment_confirmed_at,
    zone_id,assignment_state,order_status,legacy_state_unresolved
  ) values (
    btrim(p_order_id),btrim(p_order_reference),p_network,p_amount,p_firebase_created_at,p_paid_at,p_source,
    nullif(btrim(coalesce(p_customer_auth_uid,'')),''),
    coalesce(nullif(btrim(p_client_name),''),'Client'),'',
    btrim(coalesce(p_beneficiary_phone,'')),p_operation_type,
    coalesce(nullif(btrim(p_offer_label),''),'Offre non renseignee'),
    null,nullif(btrim(coalesce(p_internal_notes,'')),''),
    p_payment_status,nullif(btrim(coalesce(p_payment_payer_name,'')),''),nullif(btrim(coalesce(p_payment_reference,'')),''),
    p_payment_confirmed_at,v_zone_id,'waiting','paidReady',false
  ) on conflict (order_id) do update set
    order_reference=excluded.order_reference,network=excluded.network,amount=excluded.amount,
    firebase_created_at=excluded.firebase_created_at,paid_at=excluded.paid_at,source=excluded.source,
    customer_auth_uid=coalesce(public.phase4_assignment_orders.customer_auth_uid,excluded.customer_auth_uid),
    client_name=excluded.client_name,
    client_whatsapp_phone='',
    beneficiary_phone=excluded.beneficiary_phone,operation_type=excluded.operation_type,offer_label=excluded.offer_label,
    original_whatsapp_message=null,internal_notes=excluded.internal_notes,
    payment_status=excluded.payment_status,payment_payer_name=excluded.payment_payer_name,
    payment_reference=excluded.payment_reference,payment_confirmed_at=excluded.payment_confirmed_at,
    zone_id=excluded.zone_id,
    legacy_state_unresolved=public.phase4_assignment_orders.legacy_state_unresolved,updated_at=now()
  returning * into v_row;

  insert into public.phase4_assignment_plans(order_id) values(v_row.order_id)
  on conflict(order_id) do nothing;
  return v_row;
end;
$function$;

create or replace function private.phase3_agent_is_eligible(
  p_agent_id text,
  p_order_id text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  with target as (
    select o.* from public.phase4_assignment_orders o where o.order_id=btrim(coalesce(p_order_id,''))
  ), reserved as (
    select
      coalesce(sum(o.amount) filter (where o.network='orange'),0)::bigint as orange_reserved,
      coalesce(sum(o.amount) filter (where o.network='mtn'),0)::bigint as mtn_reserved,
      coalesce(sum(o.amount) filter (where o.network='moov'),0)::bigint as moov_reserved
    from public.phase4_assignment_orders o
    where o.assigned_agent_id=btrim(coalesce(p_agent_id,''))
      and o.order_id is distinct from btrim(coalesce(p_order_id,''))
      and o.assignment_state in ('assigned','accepted')
      and o.order_status in ('paidReady','inProgress','onHold')
      and o.legacy_state_unresolved=false
  ), today as (
    select count(*)::bigint as assignment_count,
           coalesce(sum(coalesce(h.amount,0)),0)::bigint as assigned_amount
    from public.phase4_assignment_history h
    where h.agent_id=btrim(coalesce(p_agent_id,''))
      and h.order_id is distinct from btrim(coalesce(p_order_id,''))
      and h.assigned_at >= date_trunc('day',now())
  )
  select exists (
    select 1
    from public.phase5_agent_capacities c,target t,reserved r,today d
    where c.agent_id=btrim(coalesce(p_agent_id,''))
      and c.is_active=true
      and c.availability='available'
      and t.zone_id is not null
      and t.zone_id=any(c.zone_ids)
      and t.network=any(c.authorized_networks)
      and t.network=any(c.active_networks)
      and case t.network
        when 'orange' then c.orange_capacity-r.orange_reserved
        when 'mtn' then c.mtn_capacity-r.mtn_reserved
        else c.moov_capacity-r.moov_reserved end >= t.amount
      and (c.max_transactions_per_day=0 or d.assignment_count < c.max_transactions_per_day)
      and (c.daily_transaction_limit=0 or d.assigned_amount+t.amount <= c.daily_transaction_limit)
  );
$function$;

create or replace function private.izytel_cabiniste_is_eligible(
  p_partner_id uuid,
  p_order_id text
)
returns boolean
language sql
stable
set search_path = ''
as $function$
  with target as (
    select o.*
    from public.phase4_assignment_orders o
    where o.order_id=btrim(coalesce(p_order_id,''))
  ),
  reserved as (
    select
      coalesce(sum(h.amount) filter (where h.network='orange'),0)::bigint as orange_reserved,
      coalesce(sum(h.amount) filter (where h.network='mtn'),0)::bigint as mtn_reserved,
      coalesce(sum(h.amount) filter (where h.network='moov'),0)::bigint as moov_reserved
    from public.phase4_partner_assignment_history h
    where h.partner_id=p_partner_id
      and h.order_id is distinct from btrim(coalesce(p_order_id,''))
      and h.status in ('assigned','accepted','in_progress','on_hold')
  ),
  today as (
    select
      count(*)::bigint as assignment_count,
      coalesce(sum(coalesce(h.amount,0)),0)::bigint as assigned_amount
    from public.phase4_partner_assignment_history h
    where h.partner_id=p_partner_id
      and h.order_id is distinct from btrim(coalesce(p_order_id,''))
      and h.assigned_at >= date_trunc('day',now())
  )
  select exists (
    select 1
    from public.partner_accounts a
    join public.partner_capacities c on c.partner_id=a.id,
         target t,
         reserved r,
         today d
    where a.id=p_partner_id
      and a.status='active'
      and a.availability='available'
      and t.zone_id is not null
      and t.zone_id=any(a.zone_ids)
      and t.network=any(a.authorized_networks)
      and t.network=any(a.active_networks)
      and case t.network
        when 'orange' then c.orange_capacity-r.orange_reserved
        when 'mtn' then c.mtn_capacity-r.mtn_reserved
        else c.moov_capacity-r.moov_reserved
      end >= t.amount
      and (
        a.max_transactions_per_day=0
        or d.assignment_count < a.max_transactions_per_day
      )
      and (
        a.daily_transaction_limit=0
        or d.assigned_amount+t.amount <= a.daily_transaction_limit
      )
  );
$function$;

-- Le Manager ne voit et ne modifie que les commandes de ses zones. Admin est
-- global. Agent et Cabiniste ne voient que leur propre affectation.
drop policy if exists "phase4 staff assigned agent or cabiniste reads orders"
  on public.phase4_assignment_orders;
drop policy if exists "phase4 staff inserts orders"
  on public.phase4_assignment_orders;
drop policy if exists "phase4 staff updates orders"
  on public.phase4_assignment_orders;

create policy "phase4 scoped staff assigned agent or cabiniste reads orders"
on public.phase4_assignment_orders
for select
to authenticated
using (
  (select public.is_izytel_firebase_jwt())
  and (
    (select private.is_izytel_finance_admin())
    or private.izytel_wc5_manager_owns_zone(
      phase4_assignment_orders.zone_id,
      (select auth.jwt()->>'sub')
    )
    or phase4_assignment_orders.assigned_agent_id = (select auth.jwt()->>'sub')
    or exists (
      select 1
      from public.partner_accounts partner_row
      where partner_row.id = phase4_assignment_orders.assigned_cabiniste_id
        and partner_row.firebase_uid = (select auth.jwt()->>'sub')
        and partner_row.status = 'active'
    )
  )
);

-- Les ecritures techniques Phase 4 restent compatibles avec le moteur
-- historique : n'importe quel staff authentifie peut synchroniser une commande,
-- mais aucune ligne operationnelle ne peut desormais etre creee sans zone.
-- La restriction territoriale qui fait foi pour l'affectation est appliquee
-- dans les fonctions d'eligibilite Agent/Cabiniste ci-dessus.
create policy "phase4 staff inserts zoned orders"
on public.phase4_assignment_orders
for insert
to authenticated
with check (
  (select private.is_izytel_phase4_staff())
  and zone_id is not null
);

create policy "phase4 staff updates zoned orders"
on public.phase4_assignment_orders
for update
to authenticated
using ((select private.is_izytel_phase4_staff()))
with check (
  (select private.is_izytel_phase4_staff())
  and zone_id is not null
);

-- ---------------------------------------------------------------------------
-- 6. Messagerie zonale Client -> Manager
-- ---------------------------------------------------------------------------

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
              conversation_row.assigned_manager_uid = (select auth.jwt()->>'sub')
              or (
                conversation_row.assigned_manager_uid is null
                and private.izytel_wc5_manager_owns_zone(
                  conversation_row.zone_id,
                  (select auth.jwt()->>'sub')
                )
              )
            )
          )
        )
    );
$function$;

create or replace function private.izytel_wc5_conversation_zone(
  p_customer_uid text,
  p_order_id text,
  p_order_reference text,
  p_location_status text,
  p_latitude double precision,
  p_longitude double precision
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_zone_id text;
  v_order_id text := nullif(btrim(coalesce(p_order_id, '')), '');
  v_reference text := nullif(upper(btrim(coalesce(p_order_reference, ''))), '');
begin
  if v_order_id is not null and v_reference is not null then
    select c.zone_id
      into v_zone_id
    from public.customer_order_contexts c
    where c.order_id = v_order_id
      and upper(c.order_reference) = v_reference
    limit 1;

    if v_zone_id is null then
      select o.zone_id
        into v_zone_id
      from public.phase4_assignment_orders o
      where o.order_id = v_order_id
        and upper(o.order_reference) = v_reference
      limit 1;
    end if;
  end if;

  if v_zone_id is null
     and btrim(coalesce(p_location_status, '')) = 'granted'
     and p_latitude is not null
     and p_longitude is not null
  then
    v_zone_id := private.izytel_wc5_zone_for_location(p_latitude, p_longitude);
  end if;

  if v_zone_id is null then
    select c.zone_id
      into v_zone_id
    from public.customer_order_contexts c
    where c.owner_firebase_uid = btrim(coalesce(p_customer_uid, ''))
      and c.zone_id is not null
    order by c.updated_at desc
    limit 1;
  end if;

  return coalesce(v_zone_id, private.izytel_wc5_fallback_zone_id());
end;
$function$;

create or replace function private.izytel_wc5_create_conversation_internal(
  p_order_id text,
  p_order_reference text,
  p_body text,
  p_customer_name text,
  p_location_status text,
  p_latitude double precision,
  p_longitude double precision
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
  v_customer_name text := regexp_replace(btrim(coalesce(p_customer_name, '')), '\s+', ' ', 'g');
  v_zone_id text;
  v_manager_uid text;
  v_manager_name text;
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

  if v_customer_name = '' and v_order_id is not null then
    select coalesce(nullif(btrim(o.client_name), ''), nullif(btrim(r.client_name), ''))
      into v_customer_name
    from public.customer_order_recovery_registry r
    left join public.phase4_assignment_orders o
      on o.order_id = r.order_id
     and upper(o.order_reference) = r.order_reference
    where r.order_id = v_order_id
      and r.order_reference = v_reference
    limit 1;
  end if;

  if v_customer_name = '' then
    select coalesce(nullif(btrim(o.client_name), ''), nullif(btrim(r.client_name), ''))
      into v_customer_name
    from public.customer_order_recovery_registry r
    left join public.phase4_assignment_orders o
      on o.order_id = r.order_id
     and upper(o.order_reference) = r.order_reference
    where r.owner_firebase_uid = v_uid
    order by r.created_at desc
    limit 1;
  end if;

  v_customer_name := coalesce(nullif(v_customer_name, ''), 'Client');
  if char_length(v_customer_name) > 50 then
    v_customer_name := left(v_customer_name, 50);
  end if;

  v_zone_id := private.izytel_wc5_conversation_zone(
    v_uid,
    v_order_id,
    v_reference,
    p_location_status,
    p_latitude,
    p_longitude
  );

  select z.manager_id, coalesce(nullif(btrim(m.display_name), ''), 'Manager IzyTel')
    into v_manager_uid, v_manager_name
  from public.territory_zones z
  left join public.manager_profiles m on m.firebase_uid = z.manager_id
  where z.id = v_zone_id
    and z.is_active = true
    and z.manager_id is not null
  limit 1;

  insert into public.customer_conversations (
    customer_auth_uid,
    customer_name,
    zone_id,
    order_id,
    order_reference,
    status,
    assigned_manager_uid,
    assigned_manager_name,
    source,
    last_message_at,
    last_message_preview,
    last_sender_type,
    created_at,
    updated_at
  ) values (
    v_uid,
    v_customer_name,
    v_zone_id,
    v_order_id,
    v_reference,
    case when v_manager_uid is null then 'open' else 'inProgress' end,
    v_manager_uid,
    v_manager_name,
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
    v_customer_name,
    v_body,
    'text',
    now()
  );

  return v_conversation;
end;
$function$;

-- Compatibilite avec les clients deja deployes : l'ancien RPC reste disponible
-- mais beneficie maintenant du routage zonal/fallback.
create or replace function private.izytel_wc3_create_conversation(
  p_order_id text,
  p_order_reference text,
  p_body text
)
returns public.customer_conversations
language sql
security definer
set search_path = ''
as $function$
  select private.izytel_wc5_create_conversation_internal(
    p_order_id,
    p_order_reference,
    p_body,
    '',
    'notRequested',
    null,
    null
  );
$function$;

create or replace function private.izytel_wc5_create_conversation(
  p_order_id text,
  p_order_reference text,
  p_body text,
  p_customer_name text,
  p_location_status text,
  p_latitude double precision,
  p_longitude double precision
)
returns public.customer_conversations
language sql
security definer
set search_path = ''
as $function$
  select private.izytel_wc5_create_conversation_internal(
    p_order_id,
    p_order_reference,
    p_body,
    p_customer_name,
    p_location_status,
    p_latitude,
    p_longitude
  );
$function$;

create or replace function public.izytel_wc5_create_conversation(
  p_order_id text,
  p_order_reference text,
  p_body text,
  p_customer_name text,
  p_location_status text,
  p_latitude double precision,
  p_longitude double precision
)
returns public.customer_conversations
language sql
security invoker
set search_path = ''
as $function$
  select private.izytel_wc5_create_conversation(
    p_order_id,
    p_order_reference,
    p_body,
    p_customer_name,
    p_location_status,
    p_latitude,
    p_longitude
  );
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
  if v_conversation.assigned_manager_uid is null
     and not private.izytel_wc5_manager_owns_zone(v_conversation.zone_id, v_uid)
  then
    raise exception 'CONVERSATION_OUT_OF_SCOPE' using errcode = '42501';
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

-- La lecture directe de la Data API reutilise le meme garde serveur.
drop policy if exists customer_conversations_authorized_read
  on public.customer_conversations;
create policy customer_conversations_authorized_read
on public.customer_conversations
for select
to authenticated
using (private.izytel_wc3_can_read_conversation(id));

-- ---------------------------------------------------------------------------
-- 7. Notifications systeme IzyTel (aucun numero client)
-- ---------------------------------------------------------------------------

create or replace function private.izytel_wc5_emit_customer_system_message(
  p_order_id text,
  p_order_reference text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_order_id text := btrim(coalesce(p_order_id, ''));
  v_reference text := upper(btrim(coalesce(p_order_reference, '')));
  v_body text := btrim(coalesce(p_body, ''));
  v_customer_uid text;
  v_customer_name text;
  v_zone_id text;
  v_manager_uid text;
  v_manager_name text;
  v_conversation_id text;
begin
  if v_order_id = '' or v_reference = '' or char_length(v_body) < 1 or char_length(v_body) > 2000 then
    raise exception 'CUSTOMER_MESSAGE_INVALID' using errcode = '22023';
  end if;

  select
    coalesce(nullif(btrim(o.customer_auth_uid), ''), r.owner_firebase_uid),
    coalesce(nullif(btrim(o.client_name), ''), nullif(btrim(r.client_name), ''), 'Client'),
    coalesce(o.zone_id, c.zone_id)
    into v_customer_uid, v_customer_name, v_zone_id
  from public.customer_order_recovery_registry r
  left join public.phase4_assignment_orders o
    on o.order_id = r.order_id
   and upper(o.order_reference) = r.order_reference
  left join public.customer_order_contexts c
    on c.order_id = r.order_id
   and upper(c.order_reference) = r.order_reference
  where r.order_id = v_order_id
    and r.order_reference = v_reference
  limit 1;

  if v_customer_uid is null then
    select
      nullif(btrim(o.customer_auth_uid), ''),
      coalesce(nullif(btrim(o.client_name), ''), 'Client'),
      o.zone_id
      into v_customer_uid, v_customer_name, v_zone_id
    from public.phase4_assignment_orders o
    where o.order_id = v_order_id
      and upper(o.order_reference) = v_reference
    limit 1;
  end if;

  if v_customer_uid is null then
    -- Une ancienne commande sans UID client ne peut pas recevoir de message
    -- Web. On ne fabrique pas de canal externe de secours.
    return;
  end if;

  v_zone_id := coalesce(v_zone_id, private.izytel_wc5_fallback_zone_id());

  select z.manager_id, coalesce(nullif(btrim(m.display_name), ''), 'Manager IzyTel')
    into v_manager_uid, v_manager_name
  from public.territory_zones z
  left join public.manager_profiles m on m.firebase_uid = z.manager_id
  where z.id = v_zone_id
    and z.is_active = true
    and z.manager_id is not null
  limit 1;

  select conversation_row.id
    into v_conversation_id
  from public.customer_conversations conversation_row
  where conversation_row.customer_auth_uid = v_customer_uid
    and conversation_row.order_id = v_order_id
    and upper(coalesce(conversation_row.order_reference, '')) = v_reference
    and conversation_row.status <> 'closed'
  order by conversation_row.updated_at desc
  limit 1;

  if v_conversation_id is null then
    insert into public.customer_conversations (
      customer_auth_uid,
      customer_name,
      zone_id,
      order_id,
      order_reference,
      status,
      assigned_manager_uid,
      assigned_manager_name,
      source,
      last_message_at,
      last_message_preview,
      last_sender_type,
      created_at,
      updated_at
    ) values (
      v_customer_uid,
      v_customer_name,
      v_zone_id,
      v_order_id,
      v_reference,
      case when v_manager_uid is null then 'open' else 'inProgress' end,
      v_manager_uid,
      v_manager_name,
      'system',
      now(),
      left(v_body, 240),
      'system',
      now(),
      now()
    ) returning id into v_conversation_id;
  else
    update public.customer_conversations
    set customer_name = coalesce(nullif(btrim(customer_name), ''), v_customer_name),
        zone_id = coalesce(zone_id, v_zone_id),
        assigned_manager_uid = coalesce(assigned_manager_uid, v_manager_uid),
        assigned_manager_name = coalesce(assigned_manager_name, v_manager_name),
        status = case
          when assigned_manager_uid is null and v_manager_uid is not null and status = 'open'
            then 'inProgress'
          else status
        end,
        last_message_at = now(),
        last_message_preview = left(v_body, 240),
        last_sender_type = 'system',
        updated_at = now()
    where id = v_conversation_id;
  end if;

  if exists (
    select 1
    from public.customer_messages message_row
    where message_row.conversation_id = v_conversation_id
      and message_row.sender_type = 'system'
      and message_row.body = v_body
      and message_row.created_at >= now() - interval '30 seconds'
  ) then
    return;
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
    v_conversation_id,
    'system',
    null,
    'IzyTel',
    v_body,
    'system',
    now()
  );
end;
$function$;

create or replace function private.izytel_wc3_notify_customer_order(
  p_order_id text,
  p_order_reference text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_zone_id text;
begin
  if not public.is_izytel_firebase_jwt() then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  select o.zone_id
    into v_zone_id
  from public.phase4_assignment_orders o
  where o.order_id = btrim(coalesce(p_order_id, ''))
    and upper(o.order_reference) = upper(btrim(coalesce(p_order_reference, '')))
  limit 1;

  v_zone_id := coalesce(v_zone_id, private.izytel_wc5_fallback_zone_id());

  if not private.is_izytel_finance_admin()
     and not private.izytel_wc5_manager_owns_zone(
       v_zone_id,
       (select auth.jwt()->>'sub')
     )
  then
    raise exception 'STAFF_ZONE_REQUIRED' using errcode = '42501';
  end if;

  perform private.izytel_wc5_emit_customer_system_message(
    p_order_id,
    p_order_reference,
    p_body
  );
end;
$function$;

create or replace function public.izytel_wc3_notify_customer_order(
  p_order_id text,
  p_order_reference text,
  p_body text
)
returns void
language sql
security invoker
set search_path = ''
as $function$
  select private.izytel_wc3_notify_customer_order(
    p_order_id,
    p_order_reference,
    p_body
  );
$function$;

create or replace function private.izytel_wc5_notify_completed_order_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_body text;
begin
  if old.order_status is distinct from new.order_status
     and new.order_status = 'completed'
  then
    v_body := format(
      'Bonjour %s, votre commande %s a été réalisée avec succès. Merci pour votre confiance.',
      coalesce(nullif(btrim(new.client_name), ''), 'Client'),
      new.order_reference
    );
    perform private.izytel_wc5_emit_customer_system_message(
      new.order_id,
      new.order_reference,
      v_body
    );
  end if;
  return new;
end;
$function$;

drop trigger if exists izytel_wc5_completed_order_message
  on public.phase4_assignment_orders;
create trigger izytel_wc5_completed_order_message
after update of order_status
on public.phase4_assignment_orders
for each row
execute function private.izytel_wc5_notify_completed_order_trigger();

-- ---------------------------------------------------------------------------
-- 8. Traces support/remboursement : nouveau canal = messaging
-- ---------------------------------------------------------------------------

alter table public.support_requests
  drop constraint if exists support_requests_notification_channel_check;
alter table public.support_requests
  add constraint support_requests_notification_channel_check
  check (notification_channel is null or notification_channel in ('whatsapp', 'messaging'));

alter table public.refunds
  drop constraint if exists refunds_notification_channel_check;
alter table public.refunds
  add constraint refunds_notification_channel_check
  check (notification_channel is null or notification_channel in ('whatsapp', 'messaging'));

create or replace function public.izytel_mark_support_customer_notified(p_request_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;
  update public.support_requests
  set customer_notified_at = now(),
      customer_notified_by = v_uid,
      customer_notified_by_name = v_name,
      notification_channel = 'messaging',
      updated_at = now()
  where id = btrim(p_request_id)
    and status in ('resolved', 'closed')
    and customer_notified_at is null;
  if not found then
    raise exception 'SUPPORT_NOTIFICATION_INVALID';
  end if;
end;
$function$;

create or replace function public.izytel_mark_refund_customer_notified(p_order_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;
  update public.refunds
  set customer_notified_at = now(),
      customer_notified_by = v_uid,
      customer_notified_by_name = v_name,
      notification_channel = 'messaging',
      updated_at = now()
  where order_id = btrim(p_order_id)
    and status in ('refunded', 'reconciled')
    and customer_notified_at is null;
  if not found then
    raise exception 'REFUND_NOTIFICATION_INVALID';
  end if;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 9. Privileges RPC exposes
-- ---------------------------------------------------------------------------

revoke execute on function private.izytel_wc5_fallback_zone_id() from public, anon;
revoke execute on function private.izytel_wc5_zone_for_location(double precision,double precision) from public, anon;
revoke execute on function private.izytel_wc5_manager_owns_zone(text,text) from public, anon;
revoke execute on function private.izytel_wc5_can_manage_zone(text) from public, anon;
revoke execute on function private.izytel_wc5_conversation_zone(text,text,text,text,double precision,double precision) from public, anon;
revoke execute on function private.izytel_wc5_create_conversation_internal(text,text,text,text,text,double precision,double precision) from public, anon;
revoke execute on function private.izytel_wc5_create_conversation(text,text,text,text,text,double precision,double precision) from public, anon;
grant execute on function private.izytel_wc5_create_conversation(text,text,text,text,text,double precision,double precision) to authenticated, service_role;
revoke execute on function private.izytel_wc5_emit_customer_system_message(text,text,text) from public, anon;
revoke execute on function private.izytel_wc3_notify_customer_order(text,text,text) from public, anon;
grant execute on function private.izytel_wc3_notify_customer_order(text,text,text) to authenticated, service_role;
revoke execute on function private.izytel_wc5_notify_completed_order_trigger() from public, anon, authenticated;

revoke execute on function public.izytel_wc5_create_territory_zone(text,text,text,double precision,double precision,text,double precision,boolean,boolean) from public, anon;
grant execute on function public.izytel_wc5_create_territory_zone(text,text,text,double precision,double precision,text,double precision,boolean,boolean) to authenticated, service_role;

revoke execute on function public.izytel_wc5_update_territory_zone(text,text,text,text,double precision,double precision,text,double precision,boolean,boolean) from public, anon;
grant execute on function public.izytel_wc5_update_territory_zone(text,text,text,text,double precision,double precision,text,double precision,boolean,boolean) to authenticated, service_role;

revoke execute on function public.izytel_wc5_create_conversation(text,text,text,text,text,double precision,double precision) from public, anon;
grant execute on function public.izytel_wc5_create_conversation(text,text,text,text,text,double precision,double precision) to authenticated, service_role;

revoke execute on function public.izytel_wc3_notify_customer_order(text,text,text) from public, anon;
grant execute on function public.izytel_wc3_notify_customer_order(text,text,text) to authenticated, service_role;

revoke execute on function public.izytel_mark_support_customer_notified(text) from public, anon;
grant execute on function public.izytel_mark_support_customer_notified(text) to authenticated, service_role;
revoke execute on function public.izytel_mark_refund_customer_notified(text) from public, anon;
grant execute on function public.izytel_mark_refund_customer_notified(text) to authenticated, service_role;

notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- 10. Pont de compatibilite : succes ancien flux -> notification systeme fixe
-- ---------------------------------------------------------------------------
-- Ce RPC ne prend aucun texte libre. Un Agent/Cabiniste ne peut donc pas
-- contacter directement le client ; il ne peut que declencher le message
-- systeme de succes, deja automatiquement produit par le trigger sur le flux
-- Supabase canonique.

create or replace function private.izytel_wc5_notify_completed_order(
  p_order_id text,
  p_order_reference text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := nullif(btrim((select auth.jwt()->>'sub')), '');
  v_order public.phase4_assignment_orders;
  v_is_partner boolean := false;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  select * into v_order
  from public.phase4_assignment_orders
  where order_id = btrim(coalesce(p_order_id, ''))
    and upper(order_reference) = upper(btrim(coalesce(p_order_reference, '')))
  limit 1;

  if not found then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_order.assigned_cabiniste_id is not null then
    select exists (
      select 1
      from public.partner_accounts p
      where p.id = v_order.assigned_cabiniste_id
        and p.firebase_uid = v_uid
        and p.status = 'active'
    ) into v_is_partner;
  end if;

  if not private.izytel_wc3_is_admin()
     and not (
       private.izytel_wc3_is_manager()
       and private.izytel_wc5_manager_owns_zone(v_order.zone_id, v_uid)
     )
     and coalesce(v_order.assigned_agent_id, '') <> v_uid
     and not v_is_partner then
    raise exception 'ORDER_OUT_OF_SCOPE' using errcode = '42501';
  end if;

  perform private.izytel_wc5_emit_customer_system_message(
    v_order.order_id,
    v_order.order_reference,
    'Votre commande ' || v_order.order_reference ||
    ' a été traitée avec succès.'
  );
end;
$function$;

create or replace function public.izytel_wc5_notify_completed_order(
  p_order_id text,
  p_order_reference text
)
returns void
language sql
security invoker
set search_path = ''
as $function$
  select private.izytel_wc5_notify_completed_order(
    p_order_id,
    p_order_reference
  );
$function$;

revoke execute on function private.izytel_wc5_notify_completed_order(text, text)
  from public, anon;
grant execute on function private.izytel_wc5_notify_completed_order(text, text)
  to authenticated, service_role;
revoke execute on function public.izytel_wc5_notify_completed_order(text, text)
  from public, anon;
grant execute on function public.izytel_wc5_notify_completed_order(text, text)
  to authenticated, service_role;

notify pgrst, 'reload schema';
