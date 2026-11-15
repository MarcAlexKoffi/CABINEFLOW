-- Isolated synthetic baseline for PostgreSQL/PGlite. No production rows/keys.
create schema auth; create schema private;
create role anon nologin; create role authenticated nologin;
grant usage on schema public,auth,private to anon,authenticated;
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb;
$$;
create function public.is_izytel_firebase_jwt() returns boolean language sql stable as $$
  select coalesce(auth.jwt()->>'iss'='synthetic-firebase',false);
$$;
create table public.catalog_offers(id text primary key,network text,service text,operation_type text,
  title text,display_order integer default 0,deleted_at timestamptz);
create table public.phase4_assignment_orders(order_id text primary key,network text,operation_type text,
  amount integer,beneficiary_phone text,offer_label text,order_status text,payment_status text,
  assignment_state text,assigned_agent_id text,assigned_cabiniste_id uuid,zone_id text);
create table public.phase5_agent_capacities(agent_id text primary key,is_active boolean,
  orange_capacity integer default 5000,mtn_capacity integer default 5000,moov_capacity integer default 5000,
  authorized_networks text[] default array['orange','mtn','moov']);
create table public.partner_accounts(id uuid primary key,firebase_uid text,status text,
  authorized_networks text[] default array['orange','mtn','moov']);
create table public.izytel_staff_access(firebase_uid text primary key,role text,is_active boolean);
create table public.territory_zones(id text primary key,manager_id text,is_active boolean);
create table public.customer_order_recovery_registry(order_id text primary key,offer_id text);
create function private.izytel_current_staff_role() returns text language sql stable security definer set search_path='' as $$
  select role from public.izytel_staff_access where firebase_uid=auth.jwt()->>'sub' and is_active=true;
$$;
create function private.is_izytel_finance_admin() returns boolean language sql stable security definer set search_path='' as $$
  select public.is_izytel_firebase_jwt() and coalesce(private.izytel_current_staff_role()='admin',false);
$$;
create function private.izytel_wc5_manager_owns_zone(p_zone text,p_manager text) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.territory_zones where id=p_zone and manager_id=p_manager and is_active);
$$;
insert into public.catalog_offers(id,network,service,operation_type,title) values
 ('synthetic-offer','moov','internetSubscription','internetSubscription','Offre fictive'),
 ('synthetic-orange','orange','calls','callBundle','Appels fictifs');
-- Stable seed IDs, synthetic catalogue metadata only. No production rows copied.
insert into public.catalog_offers(id,network,service,operation_type,title)
select id,'moov','calls','callBundle','Libellé synthétique sans correspondance' from unnest(array[
 'moov-calls-500','moov-calls-1000','moov-calls-1500','moov-calls-2500','moov-calls-5000']) id;
insert into public.catalog_offers(id,network,service,operation_type,title)
values('unrelated-folie-title','moov','calls','callBundle','Moov Folie 70 min');
insert into public.izytel_staff_access values('test-admin','admin',true),('test-manager','manager',true),('test-manager-b','manager',true);
insert into public.territory_zones values('zone-a','test-manager',true),('zone-b','test-manager-b',true);
insert into public.phase5_agent_capacities(agent_id,is_active) values('test-agent',true),('other-agent',true);
insert into public.partner_accounts(id,firebase_uid,status) values('00000000-0000-4000-8000-000000000001','test-cabiniste','active');
insert into public.phase4_assignment_orders values
 ('order-agent','moov','internetSubscription',1000,'+2250101010101','Offre fictive','inProgress','confirmed','accepted','test-agent',null,'zone-a'),
 ('order-cabiniste','moov','internetSubscription',1000,'+2250101010101','Offre fictive','inProgress','credit','accepted',null,'00000000-0000-4000-8000-000000000001','zone-a'),
 ('order-zone-b','orange','callBundle',1000,'+2250707070707','Appels fictifs','inProgress','confirmed','accepted','other-agent',null,'zone-b');
insert into public.customer_order_recovery_registry values('order-agent','synthetic-offer'),('order-cabiniste','synthetic-offer');
