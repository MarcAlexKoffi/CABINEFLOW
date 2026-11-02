-- READ ONLY. Run only after applying the migration in an isolated environment.
-- Expected: every service-only RPC denied to anon/authenticated, granted service.
select p.proname,
 has_function_privilege('anon',p.oid,'execute') as anon_must_be_false,
 has_function_privilege('authenticated',p.oid,'execute') as authenticated_must_be_false,
 has_function_privilege('service_role',p.oid,'execute') as service_must_be_true
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname like 'izytel_user_admin_%'
order by p.proname;
select relrowsecurity as must_be_true from pg_class
where oid='public.izytel_user_admin_operations'::regclass;
select indexdef from pg_indexes where schemaname='public'
and indexname='izytel_user_admin_single_mutation';
