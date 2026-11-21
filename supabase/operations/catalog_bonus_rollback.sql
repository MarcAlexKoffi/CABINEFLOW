-- Operator-only: back up again, suspend all campaigns and restore compatible
-- clients before applying. Retains orders, transfer rules, history and audits.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
select pg_advisory_xact_lock(9261031);
select pg_advisory_xact_lock(9261032);
lock table public.catalog_offers,public.ussd_execution_rules in share row exclusive mode;
do $$begin
 if exists(select 1 from public.offer_bonus_campaigns where status='active') then
  raise exception 'SUSPEND_BONUS_CAMPAIGNS_BEFORE_ROLLBACK';end if;
 if exists(select 1 from private.catalog_bonus_release_backup s,jsonb_array_elements(s.payload) b
   join public.catalog_offers c on c.id=b->>'id' where s.key='offers'
   and (c.catalog_version<>(b->>'catalog_version')::bigint+1 or c.category<>'maxit'
    or (to_jsonb(c)-array['category','category_id','family_code','catalog_data','catalog_version'])
       is distinct from (b-array['category','category_id','family_code','catalog_data','catalog_version']))) then
  raise exception 'REVIEW_CATALOG_EDITS_BEFORE_ROLLBACK';end if;
 if exists(select 1 from private.catalog_bonus_release_backup s,jsonb_array_elements(s.payload) b
   join public.ussd_execution_rules r on r.id=(b->>'id')::uuid where s.key='rules' and b->>'deleted_at' is null
   and (r.deleted_at is not null or r.version<>(b->>'version')::integer+1
    or r.ussd_template is distinct from b->>'ussd_template')) then
  raise exception 'REVIEW_RULE_EDITS_BEFORE_ROLLBACK';end if;
end $$;
select set_config('izytel.catalog_restore','true',true);
update public.catalog_offers c set category=b.category,category_id=b.category_id,
 family_code=b.family_code,catalog_data=b.catalog_data
from (select (jsonb_populate_record(null::public.catalog_offers,x)).*
 from private.catalog_bonus_release_backup s,jsonb_array_elements(s.payload) x where s.key='offers') b
where c.id=b.id;
update public.ussd_execution_rules set status='disabled',version=version+1,updated_at=clock_timestamp()
 where commercial_category is not null;
update public.ussd_execution_rules r set status=b.status,version=r.version+1,
 validated_by=b.validated_by,validated_at=b.validated_at,validation_method=b.validation_method,
 validation_sim_type=b.validation_sim_type,internal_note=b.internal_note,updated_at=clock_timestamp()
from (select (jsonb_populate_record(null::public.ussd_execution_rules,x)).*
 from private.catalog_bonus_release_backup s,jsonb_array_elements(s.payload) x where s.key='rules') b
where r.id=b.id and r.deleted_at is null;
insert into public.ussd_rule_versions(rule_id,version,snapshot)
 select id,version,to_jsonb(r) from public.ussd_execution_rules r where purpose='order' and service<>'unitTransfer' and deleted_at is null;
do $$declare f jsonb;begin
 for f in select x from private.catalog_bonus_release_backup s,jsonb_array_elements(s.payload) x where s.key='functions' loop
  execute f->>'definition';
 end loop;
end $$;
revoke execute on function public.izytel_public_offer_bonuses(),public.izytel_bonus_campaigns(),
 public.izytel_bonus_save(uuid,integer,jsonb),public.izytel_bonus_set_status(uuid,integer,text,text),
 public.izytel_catalog_subscription_routes(),public.izytel_catalog_validate_subscription_route(uuid,integer,text)
 from public,anon,authenticated;
commit;
