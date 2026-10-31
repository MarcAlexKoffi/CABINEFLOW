-- Read-only inventory. No business rows or secrets are selected.
-- Run/review before applying the USSD migration to an explicitly approved stage.
select relation, to_regclass(relation) is not null as present
from (values ('public.catalog_offers'),('public.phase4_assignment_orders'),
  ('public.phase5_agent_capacities'),('public.partner_accounts'),
  ('public.izytel_staff_access'),('public.territory_zones')) t(relation);
select signature, to_regprocedure(signature) is not null as present
from (values ('auth.jwt()'),('public.is_izytel_firebase_jwt()'),
  ('private.is_izytel_finance_admin()'),('private.izytel_current_staff_role()'),
  ('private.izytel_wc5_manager_owns_zone(text,text)')) t(signature);
select t.table_name,t.column_name,exists(select 1 from information_schema.columns c
  where c.table_schema='public' and c.table_name=t.table_name and c.column_name=t.column_name) as present
from (values ('catalog_offers','operation_type'),('catalog_offers','deleted_at'),
  ('phase4_assignment_orders','assigned_agent_id'),('phase4_assignment_orders','assigned_cabiniste_id'),
  ('phase4_assignment_orders','order_status'),('phase4_assignment_orders','payment_status'),
  ('phase4_assignment_orders','zone_id'),('phase5_agent_capacities','is_active'),
  ('phase5_agent_capacities','authorized_networks'),('partner_accounts','authorized_networks'),
  ('partner_accounts','status'),('partner_accounts','firebase_uid')) t(table_name,column_name);
select to_regclass('public.ussd_execution_rules') is not null as ussd_already_present;
