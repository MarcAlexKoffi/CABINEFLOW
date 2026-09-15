-- IzyTel BO-4 — Catalogue / Offres & tarifs
-- Supabase devient la source canonique du catalogue.
-- Firestore reste uniquement une source legacy de backfill ponctuel.

create table if not exists public.catalog_offers (
  id text primary key default gen_random_uuid()::text,
  network text not null check (network in ('orange', 'mtn', 'moov')),
  service text not null check (service in ('internetSubscription', 'calls')),
  operation_type text not null check (
    operation_type in ('internetSubscription', 'unitTransfer', 'callBundle', 'mixedBundle', 'other')
  ),
  title text not null check (char_length(btrim(title)) between 2 and 120),
  catalog_label text not null check (char_length(btrim(catalog_label)) between 2 and 180),
  description text check (description is null or char_length(description) <= 1200),
  selling_price bigint not null check (selling_price > 0),
  details text[] not null default '{}',
  badge_label text check (badge_label is null or char_length(badge_label) <= 80),
  category text not null default 'internet' check (char_length(category) between 2 and 40),
  validity text check (validity is null or char_length(validity) <= 120),
  volume text check (volume is null or char_length(volume) <= 120),
  minutes text check (minutes is null or char_length(minutes) <= 120),
  sms text check (sms is null or char_length(sms) <= 120),
  eligibility text check (eligibility is null or char_length(eligibility) <= 500),
  is_active boolean not null default true,
  display_order integer not null default 9999 check (display_order >= 0),
  source_kind text not null default 'supabase' check (source_kind in ('supabase', 'legacy_firestore')),
  legacy_firestore_id text unique,
  created_by_uid text,
  created_by_name text,
  updated_by_uid text,
  updated_by_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists catalog_offers_public_idx
  on public.catalog_offers(is_active, network, service, display_order, selling_price);
create index if not exists catalog_offers_admin_idx
  on public.catalog_offers(network, service, is_active, updated_at desc);

create table if not exists public.catalog_offer_audit_events (
  id uuid primary key default gen_random_uuid(),
  offer_id text not null,
  action text not null,
  before_state jsonb,
  after_state jsonb,
  actor_uid text not null,
  actor_name text not null,
  actor_role text not null,
  created_at timestamptz not null default now()
);

create index if not exists catalog_offer_audit_offer_idx
  on public.catalog_offer_audit_events(offer_id, created_at desc);

create table if not exists public.catalog_migration_state (
  migration_key text primary key,
  completed_at timestamptz not null,
  imported_count integer not null default 0,
  completed_by text not null
);

alter table public.catalog_offers enable row level security;
alter table public.catalog_offer_audit_events enable row level security;
alter table public.catalog_migration_state enable row level security;

drop policy if exists "catalog active or admin read" on public.catalog_offers;
create policy "catalog active or admin read"
  on public.catalog_offers
  for select
  to anon, authenticated
  using (
    (select public.is_izytel_firebase_jwt())
    and (
      is_active = true
      or (select private.is_izytel_finance_admin())
    )
  );

drop policy if exists "catalog audit admin read" on public.catalog_offer_audit_events;
create policy "catalog audit admin read"
  on public.catalog_offer_audit_events
  for select
  to anon, authenticated
  using ((select private.is_izytel_finance_admin()));

drop policy if exists "catalog migration admin read" on public.catalog_migration_state;
create policy "catalog migration admin read"
  on public.catalog_migration_state
  for select
  to anon, authenticated
  using ((select private.is_izytel_finance_admin()));

revoke all on public.catalog_offers from anon, authenticated;
revoke all on public.catalog_offer_audit_events from anon, authenticated;
revoke all on public.catalog_migration_state from anon, authenticated;
grant select on public.catalog_offers to anon, authenticated;
grant select on public.catalog_offer_audit_events to anon, authenticated;
grant select on public.catalog_migration_state to anon, authenticated;

create or replace function private.izytel_catalog_details(p_payload jsonb)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    array(
      select btrim(value)
      from jsonb_array_elements_text(coalesce(p_payload->'details', '[]'::jsonb)) as item(value)
      where btrim(value) <> ''
    ),
    '{}'::text[]
  );
$$;

create or replace function private.izytel_catalog_validate_payload(p_payload jsonb)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  v_network text := btrim(coalesce(p_payload->>'network', ''));
  v_service text := btrim(coalesce(p_payload->>'service', ''));
  v_operation text := btrim(coalesce(p_payload->>'operationType', p_payload->>'operation_type', ''));
  v_title text := btrim(coalesce(p_payload->>'title', ''));
  v_label text := btrim(coalesce(p_payload->>'catalogLabel', p_payload->>'catalog_label', ''));
  v_price bigint := coalesce(nullif(p_payload->>'sellingPrice', ''), nullif(p_payload->>'selling_price', ''))::bigint;
  v_order integer := coalesce(nullif(p_payload->>'displayOrder', ''), nullif(p_payload->>'display_order', ''), '9999')::integer;
begin
  if v_network not in ('orange', 'mtn', 'moov') then raise exception 'CATALOG_NETWORK_INVALID'; end if;
  if v_service not in ('internetSubscription', 'calls') then raise exception 'CATALOG_SERVICE_INVALID'; end if;
  if v_operation not in ('internetSubscription', 'unitTransfer', 'callBundle', 'mixedBundle', 'other') then raise exception 'CATALOG_OPERATION_INVALID'; end if;
  if char_length(v_title) < 2 or char_length(v_title) > 120 then raise exception 'CATALOG_TITLE_INVALID'; end if;
  if char_length(v_label) < 2 or char_length(v_label) > 180 then raise exception 'CATALOG_LABEL_INVALID'; end if;
  if v_price is null or v_price <= 0 then raise exception 'CATALOG_PRICE_INVALID'; end if;
  if v_order < 0 then raise exception 'CATALOG_ORDER_INVALID'; end if;
  if char_length(coalesce(p_payload->>'description', '')) > 1200
     or char_length(coalesce(p_payload->>'badgeLabel', p_payload->>'badge_label', '')) > 80
     or char_length(coalesce(p_payload->>'validity', '')) > 120
     or char_length(coalesce(p_payload->>'volume', '')) > 120
     or char_length(coalesce(p_payload->>'minutes', '')) > 120
     or char_length(coalesce(p_payload->>'sms', '')) > 120
     or char_length(coalesce(p_payload->>'eligibility', '')) > 500 then
    raise exception 'CATALOG_TEXT_TOO_LONG';
  end if;
end;
$$;

create or replace function public.izytel_create_catalog_offer(p_payload jsonb)
returns public.catalog_offers
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_uid text := (select auth.jwt()->>'sub');
  v_actor_name text := private.izytel_staff_display_name();
  v_result public.catalog_offers;
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  perform private.izytel_catalog_validate_payload(p_payload);
  insert into public.catalog_offers (
    network, service, operation_type, title, catalog_label, description,
    selling_price, details, badge_label, category, validity, volume, minutes,
    sms, eligibility, is_active, display_order, source_kind,
    created_by_uid, created_by_name, updated_by_uid, updated_by_name
  ) values (
    btrim(p_payload->>'network'), btrim(p_payload->>'service'),
    btrim(coalesce(p_payload->>'operationType', p_payload->>'operation_type')),
    btrim(p_payload->>'title'), btrim(coalesce(p_payload->>'catalogLabel', p_payload->>'catalog_label')),
    nullif(btrim(coalesce(p_payload->>'description', '')), ''),
    coalesce(nullif(p_payload->>'sellingPrice', ''), p_payload->>'selling_price')::bigint,
    private.izytel_catalog_details(p_payload),
    nullif(btrim(coalesce(p_payload->>'badgeLabel', p_payload->>'badge_label', '')), ''),
    btrim(coalesce(nullif(p_payload->>'category', ''), 'internet')),
    nullif(btrim(coalesce(p_payload->>'validity', '')), ''),
    nullif(btrim(coalesce(p_payload->>'volume', '')), ''),
    nullif(btrim(coalesce(p_payload->>'minutes', '')), ''),
    nullif(btrim(coalesce(p_payload->>'sms', '')), ''),
    nullif(btrim(coalesce(p_payload->>'eligibility', '')), ''),
    coalesce((p_payload->>'isActive')::boolean, (p_payload->>'is_active')::boolean, true),
    coalesce(nullif(p_payload->>'displayOrder', ''), nullif(p_payload->>'display_order', ''), '9999')::integer,
    'supabase', v_actor_uid, v_actor_name, v_actor_uid, v_actor_name
  ) returning * into v_result;

  insert into public.catalog_offer_audit_events (
    offer_id, action, before_state, after_state, actor_uid, actor_name, actor_role
  ) values (
    v_result.id, 'created', null, to_jsonb(v_result),
    v_actor_uid, v_actor_name, 'admin'
  );
  return v_result;
end;
$$;

create or replace function public.izytel_update_catalog_offer(p_offer_id text, p_payload jsonb)
returns public.catalog_offers
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id text := btrim(coalesce(p_offer_id, ''));
  v_actor_uid text := (select auth.jwt()->>'sub');
  v_actor_name text := private.izytel_staff_display_name();
  v_before public.catalog_offers;
  v_result public.catalog_offers;
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if v_id = '' then raise exception 'CATALOG_OFFER_REQUIRED'; end if;
  perform private.izytel_catalog_validate_payload(p_payload);
  select * into v_before from public.catalog_offers where id = v_id;
  if v_before.id is null then raise exception 'CATALOG_OFFER_NOT_FOUND'; end if;

  update public.catalog_offers
  set network = btrim(p_payload->>'network'),
      service = btrim(p_payload->>'service'),
      operation_type = btrim(coalesce(p_payload->>'operationType', p_payload->>'operation_type')),
      title = btrim(p_payload->>'title'),
      catalog_label = btrim(coalesce(p_payload->>'catalogLabel', p_payload->>'catalog_label')),
      description = nullif(btrim(coalesce(p_payload->>'description', '')), ''),
      selling_price = coalesce(nullif(p_payload->>'sellingPrice', ''), p_payload->>'selling_price')::bigint,
      details = private.izytel_catalog_details(p_payload),
      badge_label = nullif(btrim(coalesce(p_payload->>'badgeLabel', p_payload->>'badge_label', '')), ''),
      category = btrim(coalesce(nullif(p_payload->>'category', ''), 'internet')),
      validity = nullif(btrim(coalesce(p_payload->>'validity', '')), ''),
      volume = nullif(btrim(coalesce(p_payload->>'volume', '')), ''),
      minutes = nullif(btrim(coalesce(p_payload->>'minutes', '')), ''),
      sms = nullif(btrim(coalesce(p_payload->>'sms', '')), ''),
      eligibility = nullif(btrim(coalesce(p_payload->>'eligibility', '')), ''),
      is_active = coalesce((p_payload->>'isActive')::boolean, (p_payload->>'is_active')::boolean, v_before.is_active),
      display_order = coalesce(nullif(p_payload->>'displayOrder', ''), nullif(p_payload->>'display_order', ''), v_before.display_order::text)::integer,
      updated_by_uid = v_actor_uid,
      updated_by_name = v_actor_name,
      updated_at = now()
  where id = v_id
  returning * into v_result;

  insert into public.catalog_offer_audit_events (
    offer_id, action, before_state, after_state, actor_uid, actor_name, actor_role
  ) values (
    v_id, 'updated', to_jsonb(v_before), to_jsonb(v_result),
    v_actor_uid, v_actor_name, 'admin'
  );
  return v_result;
end;
$$;

create or replace function public.izytel_set_catalog_offer_active(p_offer_id text, p_is_active boolean)
returns public.catalog_offers
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id text := btrim(coalesce(p_offer_id, ''));
  v_actor_uid text := (select auth.jwt()->>'sub');
  v_actor_name text := private.izytel_staff_display_name();
  v_before public.catalog_offers;
  v_result public.catalog_offers;
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  select * into v_before from public.catalog_offers where id = v_id;
  if v_before.id is null then raise exception 'CATALOG_OFFER_NOT_FOUND'; end if;

  update public.catalog_offers
  set is_active = p_is_active,
      updated_by_uid = v_actor_uid,
      updated_by_name = v_actor_name,
      updated_at = now()
  where id = v_id
  returning * into v_result;

  insert into public.catalog_offer_audit_events (
    offer_id, action, before_state, after_state, actor_uid, actor_name, actor_role
  ) values (
    v_id,
    case when p_is_active then 'reactivated' else 'suspended' end,
    to_jsonb(v_before), to_jsonb(v_result),
    v_actor_uid, v_actor_name, 'admin'
  );
  return v_result;
end;
$$;

create or replace function public.izytel_catalog_backfill_needed()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  return not exists (
    select 1
    from public.catalog_migration_state
    where migration_key = 'firestore_offers_v1'
  );
end;
$$;

create or replace function public.izytel_import_legacy_catalog_offer(p_offer_id text, p_payload jsonb)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id text := btrim(coalesce(p_offer_id, ''));
  v_actor_uid text := (select auth.jwt()->>'sub');
  v_actor_name text := private.izytel_staff_display_name();
  v_created_at timestamptz;
  v_inserted integer := 0;
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if v_id = '' then raise exception 'CATALOG_OFFER_REQUIRED'; end if;
  perform private.izytel_catalog_validate_payload(p_payload);

  begin
    v_created_at := nullif(p_payload->>'createdAt', '')::timestamptz;
  exception when others then
    v_created_at := null;
  end;

  insert into public.catalog_offers (
    id, network, service, operation_type, title, catalog_label, description,
    selling_price, details, badge_label, category, validity, volume, minutes,
    sms, eligibility, is_active, display_order, source_kind, legacy_firestore_id,
    created_by_uid, created_by_name, updated_by_uid, updated_by_name,
    created_at, updated_at
  ) values (
    v_id,
    btrim(p_payload->>'network'),
    btrim(p_payload->>'service'),
    btrim(coalesce(p_payload->>'operationType', p_payload->>'operation_type')),
    btrim(p_payload->>'title'),
    btrim(coalesce(p_payload->>'catalogLabel', p_payload->>'catalog_label')),
    nullif(btrim(coalesce(p_payload->>'description', '')), ''),
    coalesce(nullif(p_payload->>'sellingPrice', ''), p_payload->>'selling_price')::bigint,
    private.izytel_catalog_details(p_payload),
    nullif(btrim(coalesce(p_payload->>'badgeLabel', p_payload->>'badge_label', '')), ''),
    btrim(coalesce(
      nullif(p_payload->>'category', ''),
      case
        when coalesce(p_payload->>'operationType', p_payload->>'operation_type') = 'mixedBundle' then 'mixed'
        when btrim(p_payload->>'service') = 'calls' then 'calls'
        else 'internet'
      end
    )),
    nullif(btrim(coalesce(p_payload->>'validity', '')), ''),
    nullif(btrim(coalesce(p_payload->>'volume', '')), ''),
    nullif(btrim(coalesce(p_payload->>'minutes', '')), ''),
    nullif(btrim(coalesce(p_payload->>'sms', '')), ''),
    nullif(btrim(coalesce(p_payload->>'eligibility', '')), ''),
    coalesce((p_payload->>'isActive')::boolean, true),
    coalesce(nullif(p_payload->>'displayOrder', ''), '9999')::integer,
    'legacy_firestore',
    v_id,
    v_actor_uid, v_actor_name,
    v_actor_uid, v_actor_name,
    coalesce(v_created_at, now()),
    now()
  )
  on conflict (id) do nothing;

  get diagnostics v_inserted = row_count;
  if v_inserted > 0 then
    insert into public.catalog_offer_audit_events (
      offer_id, action, before_state, after_state, actor_uid, actor_name, actor_role
    )
    select id, 'legacy_imported', null, to_jsonb(o),
           v_actor_uid, v_actor_name, 'admin'
    from public.catalog_offers o
    where id = v_id;
  end if;

  return v_inserted > 0;
end;
$$;

create or replace function public.izytel_finish_catalog_backfill(p_imported_count integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_uid text := (select auth.jwt()->>'sub');
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  insert into public.catalog_migration_state (
    migration_key, completed_at, imported_count, completed_by
  ) values (
    'firestore_offers_v1', now(), greatest(coalesce(p_imported_count, 0), 0), v_actor_uid
  )
  on conflict (migration_key) do update
  set completed_at = excluded.completed_at,
      imported_count = excluded.imported_count,
      completed_by = excluded.completed_by;
end;
$$;

grant execute on function public.izytel_create_catalog_offer(jsonb) to anon, authenticated;
grant execute on function public.izytel_update_catalog_offer(text, jsonb) to anon, authenticated;
grant execute on function public.izytel_set_catalog_offer_active(text, boolean) to anon, authenticated;
grant execute on function public.izytel_catalog_backfill_needed() to anon, authenticated;
grant execute on function public.izytel_import_legacy_catalog_offer(text, jsonb) to anon, authenticated;
grant execute on function public.izytel_finish_catalog_backfill(integer) to anon, authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'catalog_offers'
  ) then
    alter publication supabase_realtime add table public.catalog_offers;
  end if;
end $$;
