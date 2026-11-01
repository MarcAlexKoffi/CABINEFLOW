-- Read-only checks before an explicitly approved application of USSD follow-ups.
-- Inspect results; this file does not apply or repair any migration.
select relation, to_regclass(relation) is not null as present
from (values ('public.ussd_execution_rules'),('public.ussd_offer_families'),
  ('public.ussd_offer_bindings'),('public.ussd_rule_versions'),
  ('public.ussd_binding_versions'),('public.catalog_offers'),
  ('public.phase4_assignment_orders')) t(relation);

select signature, to_regprocedure(signature) is not null as present
from (values ('private.ussd_admin()'),('private.ussd_staff()'),
  ('private.ussd_actor(public.phase4_assignment_orders)'),
  ('private.ussd_generate(text,text,bigint,text,integer)'),
  ('private.ussd_prepare(text,uuid,integer,jsonb,text)')) t(signature);

select version, name from supabase_migrations.schema_migrations
where name in ('ussd_dynamic_shortcuts_v1',
  'ussd_template_aliases_secret_and_draft_catalog','ussd_admin_deletion') order by version;

-- If any V2 object already exists, inspect history/partial changes before DDL.
select to_regclass('private.ussd_secret_configuration') is not null as v2_secret_table_present,
  exists(select 1 from information_schema.columns where table_schema='public'
    and table_name='ussd_execution_rules' and column_name='purpose') as v2_purpose_present;

-- Stable catalogue mapping; no customer rows, secrets or display-name inference.
select id, network, operation_type, deleted_at is null as not_deleted
from public.catalog_offers where id in ('moov-calls-500','moov-calls-1000',
  'moov-calls-1500','moov-calls-2500','moov-calls-5000') order by id;

select id, network, service from public.ussd_offer_families where id in (
  '71000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000002');
select id from public.ussd_execution_rules where id between
  '72000000-0000-4000-8000-000000000001'::uuid and '72000000-0000-4000-8000-000000000012'::uuid;

-- If deletion objects already exist, inspect migration history before DDL.
select table_name,column_name from information_schema.columns where table_schema='public'
  and table_name in ('ussd_execution_rules','ussd_offer_families')
  and column_name in ('deleted_at','deleted_by') order by table_name,column_name;
select signature,to_regprocedure(signature) is not null as present from (values
  ('public.izytel_ussd_delete_rule(uuid,integer)'),
  ('public.izytel_ussd_delete_family(uuid)'),
  ('public.izytel_ussd_delete_binding(text,integer)')) t(signature);
