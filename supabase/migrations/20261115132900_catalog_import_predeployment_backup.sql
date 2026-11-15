-- Private pre-deployment backup. Never expose commercial rows through the API.
create table private.catalog_import_backup_20261115133000 (
  source text not null,
  row_id text not null,
  data jsonb not null,
  captured_at timestamptz not null default now(),
  primary key (source, row_id)
);
alter table private.catalog_import_backup_20261115133000 enable row level security;
revoke all on private.catalog_import_backup_20261115133000 from public, anon, authenticated, service_role;
insert into private.catalog_import_backup_20261115133000 (source,row_id,data)
select 'catalog_offers',id::text,to_jsonb(o) from public.catalog_offers o;
insert into private.catalog_import_backup_20261115133000 (source,row_id,data)
select 'catalog_offer_audit_events',id::text,to_jsonb(e) from public.catalog_offer_audit_events e;
