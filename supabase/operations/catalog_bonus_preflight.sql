-- READ ONLY. Inspect and export results before any authorized release.
begin read only;
select count(*) total,count(*) filter(where is_active and deleted_at is null) active from public.catalog_offers;
select network,category,count(*) from public.catalog_offers where is_active and deleted_at is null group by network,category order by 1,2;
select c.id,c.offer_code,c.title,c.selling_price,c.category,c.category_id,c.family_code,c.catalog_data,b.family_id,f.label family
from public.catalog_offers c left join public.ussd_offer_bindings b on b.offer_id=c.id
 left join public.ussd_offer_families f on f.id=b.family_id
where c.offer_code in ('OR-DAT-20261118-003','OR-DAT-20261118-004');
select id,network,service,purpose,ussd_template,status,version,deleted_at from public.ussd_execution_rules order by network,service,id;
select pg_get_functiondef('private.ussd_resolve_before_execution(text)'::regprocedure);
select pg_get_functiondef('private.ussd_validate_rule(public.ussd_execution_rules)'::regprocedure);
select t.tgname,pg_get_triggerdef(t.oid) from pg_trigger t where not t.tgisinternal and t.tgrelid='public.catalog_offers'::regclass;
commit;
