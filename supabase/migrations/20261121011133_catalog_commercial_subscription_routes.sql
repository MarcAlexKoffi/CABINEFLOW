-- Offline-reviewed release. Apply only after the separate production approval.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
select pg_advisory_xact_lock(9261031);
lock table public.catalog_offers,public.offer_categories in share row exclusive mode;
create table private.catalog_bonus_release_backup(key text primary key,payload jsonb not null);
alter table private.catalog_bonus_release_backup enable row level security;
revoke all on private.catalog_bonus_release_backup from public,anon,authenticated;
insert into private.catalog_bonus_release_backup values
 ('offers',(select jsonb_agg(to_jsonb(c)) from public.catalog_offers c where offer_code in ('OR-DAT-20261118-003','OR-DAT-20261118-004'))),
 ('rules',(select jsonb_agg(to_jsonb(r)) from public.ussd_execution_rules r where purpose='order' and service<>'unitTransfer')),
 ('transfer_fingerprint',(select to_jsonb(md5(coalesce(string_agg(to_jsonb(r)::text,'' order by id),''))) from public.ussd_execution_rules r where service='unitTransfer')),
 ('functions',(select jsonb_agg(jsonb_build_object('definition',pg_get_functiondef(p.oid),'identity',p.oid::regprocedure::text,'acl',p.proacl::text))
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in ('ussd_resolve_before_execution','ussd_validate_rule')));

do $$begin
 if (select count(*) from public.catalog_offers)<>110
   or (select count(*) from public.catalog_offers where is_active and deleted_at is null)<>109 then
   raise exception 'CATALOG_REFERENCE_CHANGED_REVIEW_REQUIRED'; end if;
 if (select count(*) from public.catalog_offers where network='orange' and is_active and deleted_at is null
   and ((offer_code='OR-DAT-20261118-003' and selling_price=800)
     or (offer_code='OR-DAT-20261118-004' and selling_price=2500)))<>2 then
   raise exception 'ORANGE_OFFERS_REFERENCE_CHANGED'; end if;
 if (select count(*) from public.catalog_offers where network='orange' and offer_code in ('OR-DAT-20261118-003','OR-DAT-20261118-004'))<>2 then
   raise exception 'ORANGE_OFFER_CODES_NOT_UNIQUE';end if;
 if (select count(*) from public.offer_categories where slug='maxit' and is_active and deleted_at is null)<>1 then
   raise exception 'MAXIT_CATEGORY_REQUIRED'; end if;
 if (select count(*) from public.ussd_offer_families where network='orange' and service='all' and label='MAXIT' and deleted_at is null)<>1 then
   raise exception 'EXISTING_MAXIT_FAMILY_REQUIRED';end if;
end $$;
-- Keep IDs, prices, commercial descriptions, volumes, durations and bindings.
-- Existing import/presentation triggers continue to validate both rows.
update public.catalog_offers set category='maxit',
 category_id=(select id from public.offer_categories where slug='maxit' and deleted_at is null),
 family_code='MAXIT',catalog_data=jsonb_set(catalog_data,'{famille}','"MAXIT"')
where network='orange' and offer_code in ('OR-DAT-20261118-003','OR-DAT-20261118-004');

alter table public.ussd_execution_rules
 add column commercial_category text,
 add column technical_validated_at timestamptz,
 add column operator_validated_at timestamptz,
 add column operator_reference text,
 add constraint ussd_commercial_context check(commercial_category is null or
   (purpose='order' and service='all' and offer_id is null and offer_group is null
    and (family_id is null or (network='orange' and commercial_category in ('maxit','calls') and private.ussd_normalize_template(ussd_template)='APP:MAXIT'))
    and ((network='orange' and commercial_category in ('maxit','internet','calls','mixed'))
      or (network='mtn' and commercial_category in ('cchic','internet','mixed'))
      or (network='moov' and commercial_category in ('folie','internet','mixed')))));
alter table public.ussd_execution_rules drop constraint ussd_maxit_requires_association;
alter table public.ussd_execution_rules add constraint ussd_maxit_requires_association check(
 private.ussd_normalize_template(ussd_template)<>'APP:MAXIT' or
 (network='orange' and purpose='order' and
   (offer_id is not null or family_id is not null or commercial_category in ('maxit','calls'))));
create unique index ussd_one_commercial_rule on public.ussd_execution_rules(network,commercial_category,actor_scope)
 where commercial_category is not null and status='active' and deleted_at is null;

create function private.catalog_route_invalidate_evidence() returns trigger language plpgsql set search_path='' as $$
begin
 if row(new.network,new.service,new.commercial_category,new.ussd_template,new.actor_scope,new.status,new.family_id,new.offer_id,new.offer_group)
   is distinct from row(old.network,old.service,old.commercial_category,old.ussd_template,old.actor_scope,old.status,old.family_id,old.offer_id,old.offer_group) then
  new.technical_validated_at:=null;new.operator_validated_at:=null;new.operator_reference:=null;
 end if;
 return new;
end $$;
revoke all on function private.catalog_route_invalidate_evidence() from public,anon,authenticated;
create trigger catalog_route_invalidate_evidence before update on public.ussd_execution_rules
 for each row execute function private.catalog_route_invalidate_evidence();

-- Archive subscription rules only. No unitTransfer or balance row is touched.
update public.ussd_execution_rules set status='disabled',version=version+1,updated_at=clock_timestamp()
 where purpose='order' and service<>'unitTransfer' and deleted_at is null;
insert into public.ussd_rule_versions(rule_id,version,snapshot)
 select id,version,to_jsonb(r) from public.ussd_execution_rules r
 where purpose='order' and service<>'unitTransfer' and deleted_at is null;
-- Keep the existing MAXIT family marker for older Agents. Selection itself
-- depends only on the exact network/category pair in catalog_subscription_rule.
insert into public.ussd_execution_rules(network,service,commercial_category,family_id,purpose,actor_scope,
 ussd_template,priority,status,effective_from,validated_by,validated_at,validation_method,created_by,updated_by,seed_key,internal_note)
select network,'all',category,case when network='orange' and template='APP:MAXIT' then
 (select id from public.ussd_offer_families where network='orange' and service='all' and label='MAXIT' and deleted_at is null) end,
 'order','both',template,0,'active','2020-01-01T00:00:00Z',
 'catalog-commercial-release',clock_timestamp(),'creation','catalog-commercial-release','catalog-commercial-release',
 'commercial-v1-'||network||'-'||category,'Configuration demandée ; validation opérateur nécessaire.'
from (values
 ('orange','maxit','APP:MAXIT'),('orange','calls','APP:MAXIT'),
 ('orange','internet','#154*1*{{msisdn_local}}*2*2#'),('orange','mixed','#154*1*{{msisdn_local}}*2*1#'),
 ('mtn','cchic','*133*6*8*{{msisdn_local}}#'),('mtn','internet','*133*6*3*{{msisdn_local}}#'),
 ('mtn','mixed','*133*6*2*{{msisdn_local}}#'),('moov','folie','*412*4*{{msisdn_local}}#'),
 ('moov','internet','*412*2*{{msisdn_local}}#'),('moov','mixed','*412*2*{{msisdn_local}}#')) v(network,category,template);
insert into public.ussd_rule_versions(rule_id,version,snapshot)
 select id,version,to_jsonb(r) from public.ussd_execution_rules r where commercial_category is not null;

-- Keep the existing credit-transfer decision path, excluding category-only rules.
do $$declare definition text; begin
 definition:=pg_get_functiondef('private.ussd_resolve_before_execution(text)'::regprocedure);
 definition:=replace(definition,'private.ussd_resolve_before_execution(', 'private.ussd_resolve_before_commercial_categories(');
 if position('where x.purpose=''order''' in definition)=0 then raise exception 'UNEXPECTED_USSD_RESOLVER'; end if;
 definition:=replace(definition,'where x.purpose=''order''','where x.commercial_category is null and x.purpose=''order''');
 definition:=replace(definition,'where x.id<>r.id','where x.commercial_category is null and x.id<>r.id');
 execute definition;
end $$;
revoke all on function private.ussd_resolve_before_commercial_categories(text) from public,anon,authenticated;

create function private.catalog_subscription_rule(p_offer_id text,p_network text,p_operation text,p_actor text)
returns public.ussd_execution_rules language plpgsql stable security definer set search_path='' as $$
declare c public.catalog_offers;r public.ussd_execution_rules;n integer;
begin
 select * into c from public.catalog_offers where id=p_offer_id;
 if not found then raise exception 'catalog_offer_required'; end if;
 if c.deleted_at is not null or not c.is_active then raise exception 'catalog_offer_inactive';end if;
 if c.network is distinct from p_network or c.operation_type is distinct from p_operation
   or p_operation='unitTransfer' then raise exception 'catalog_offer_mismatch';end if;
 if not exists(select 1 from public.offer_categories k where k.id=c.category_id
   and k.slug=c.category and k.is_active and k.deleted_at is null) then raise exception 'catalog_category_mismatch';end if;
 select count(*) into n from public.ussd_execution_rules x
  where x.network=c.network and x.commercial_category=c.category and x.purpose='order'
   and x.status='active' and x.deleted_at is null and x.actor_scope in (p_actor,'both')
   and x.effective_from<=statement_timestamp() and (x.effective_until is null or x.effective_until>statement_timestamp());
 if n<>1 then raise exception '%',case when n=0 then 'commercial_route_missing' else 'commercial_route_conflict' end;end if;
 select * into r from public.ussd_execution_rules x where x.network=c.network and x.commercial_category=c.category
   and x.status='active' and x.deleted_at is null and x.actor_scope in (p_actor,'both')
   and x.effective_from<=statement_timestamp() and (x.effective_until is null or x.effective_until>statement_timestamp());
 return r;
end $$;
revoke all on function private.catalog_subscription_rule(text,text,text,text) from public,anon,authenticated;
create or replace function private.ussd_resolve_before_execution(p_order_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare o public.phase4_assignment_orders;r public.ussd_execution_rules;offer text;actor text;code text;phone text;
begin
 perform private.ussd_uid();
 select * into strict o from public.phase4_assignment_orders where order_id=p_order_id;
 actor:=private.ussd_actor(o);
 if o.operation_type='unitTransfer' then return private.ussd_resolve_before_commercial_categories(p_order_id);end if;
 if o.order_status<>'inProgress' or o.assignment_state<>'accepted' or o.payment_status not in ('confirmed','credit') then
  return jsonb_build_object('status','unavailable','reason','order_not_processable');end if;
 select offer_id into offer from public.ussd_order_contexts where order_id=o.order_id;
 begin
  r:=private.catalog_subscription_rule(offer,o.network,o.operation_type,actor);
  code:=private.ussd_generate(r.ussd_template,o.beneficiary_phone,o.amount,null,null,null);
 exception when raise_exception then return jsonb_build_object('status','unavailable','reason',sqlerrm);end;
 phone:=private.ussd_phone(o.beneficiary_phone);
 return jsonb_build_object('status','available','reason','',
 'rule',to_jsonb(r)-'internal_note'-'created_by'-'updated_by','code',code,
 'context',jsonb_build_object('network',o.network,'service',private.ussd_service(o.operation_type),'offer_id',offer,
  'commercial_category',r.commercial_category,'offer_label',o.offer_label,'beneficiary',o.beneficiary_phone,'amount',o.amount,
  'binding_version',null,'quantity',null,'offer_code',null,'secret_revision',null),
 'network_mismatch',case left(phone,2) when '07' then o.network<>'orange' when '05' then o.network<>'mtn' when '01' then o.network<>'moov' else false end);
end $$;

-- Old rule activation must not conflict with unrelated category routes.
do $$declare definition text;begin
 definition:=pg_get_functiondef('private.ussd_validate_rule(public.ussd_execution_rules)'::regprocedure);
 definition:=replace(definition,'where x.id<>r.id and x.status=''active''',
  'where x.commercial_category is not distinct from r.commercial_category and x.id<>r.id and x.status=''active''');
 execute definition;
end $$;
create function private.catalog_subscription_routes() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform private.ussd_staff();
 return (select coalesce(jsonb_agg(v order by network,category),'[]') from (
  select r.id,r.network,r.commercial_category category,r.ussd_template action,r.version,
   r.status='active' and r.effective_from<=statement_timestamp()
    and (r.effective_until is null or r.effective_until>statement_timestamp()) configured,
   r.technical_validated_at,r.operator_validated_at,r.operator_reference,
   (select count(*) from public.catalog_offers c where c.network=r.network and c.category=r.commercial_category
     and c.is_active and c.deleted_at is null) offers
  from public.ussd_execution_rules r where r.commercial_category is not null and r.deleted_at is null) v);
end $$;
create function public.izytel_catalog_subscription_routes() returns jsonb language sql set search_path='' as $$
 select private.catalog_subscription_routes();$$;
create function private.catalog_validate_subscription_route(p_rule_id uuid,p_expected_version integer,p_operator_reference text default null)
returns void language plpgsql security definer set search_path='' as $$
declare u text:=private.ussd_admin();r public.ussd_execution_rules;c public.catalog_offers;begin
 perform pg_advisory_xact_lock(9261031);
 select * into strict r from public.ussd_execution_rules where id=p_rule_id and commercial_category is not null for update;
 if r.version is distinct from p_expected_version then raise exception 'rule_changed';end if;
 perform private.ussd_generate(r.ussd_template,'0700000000',1,null,null,null);
 for c in select * from public.catalog_offers where network=r.network and category=r.commercial_category and is_active and deleted_at is null loop
  perform private.catalog_subscription_rule(c.id,c.network,c.operation_type,'agent');
  perform private.ussd_generate(r.ussd_template,'0700000000',c.selling_price,null,null,null);
 end loop;
 if p_operator_reference is not null and length(btrim(p_operator_reference)) not between 10 and 500 then
  raise exception 'operator_evidence_required';end if;
 update public.ussd_execution_rules set technical_validated_at=clock_timestamp(),
  operator_validated_at=case when p_operator_reference is not null then clock_timestamp() else operator_validated_at end,
  operator_reference=coalesce(nullif(btrim(p_operator_reference),''),operator_reference),
  updated_by=u,updated_at=clock_timestamp(),version=version+1 where id=r.id;
 insert into public.ussd_rule_versions select id,version,to_jsonb(x) from public.ussd_execution_rules x where id=r.id;
end $$;
create function public.izytel_catalog_validate_subscription_route(p_rule_id uuid,p_expected_version integer,p_operator_reference text default null)
returns void language sql set search_path='' as $$
 select private.catalog_validate_subscription_route(p_rule_id,p_expected_version,p_operator_reference);$$;
revoke all on function private.catalog_subscription_routes(),public.izytel_catalog_subscription_routes(),
 private.catalog_validate_subscription_route(uuid,integer,text),public.izytel_catalog_validate_subscription_route(uuid,integer,text) from public;
grant execute on function private.catalog_subscription_routes(),public.izytel_catalog_subscription_routes(),
 private.catalog_validate_subscription_route(uuid,integer,text),public.izytel_catalog_validate_subscription_route(uuid,integer,text) to anon,authenticated;
-- Pure local generation only: no operator request, payment or execution log.
do $$declare c public.catalog_offers;r public.ussd_execution_rules;distribution jsonb;n integer:=0;begin
 select jsonb_object_agg(key,count) into distribution from (
  select network||'/'||category key,count(*) count from public.catalog_offers where is_active and deleted_at is null group by network,category) x;
 if distribution is distinct from '{"orange/maxit":8,"orange/internet":10,"orange/calls":1,"orange/mixed":10,"mtn/cchic":20,"mtn/internet":12,"mtn/mixed":10,"moov/folie":15,"moov/internet":14,"moov/mixed":9}'::jsonb then
  raise exception 'CATALOG_DISTRIBUTION_CHANGED_REVIEW_REQUIRED';end if;
 for c in select * from public.catalog_offers where is_active and deleted_at is null loop
  r:=private.catalog_subscription_rule(c.id,c.network,c.operation_type,'agent');
  if private.ussd_generate(r.ussd_template,'0700000000',c.selling_price,null,null,null)='APP:MAXIT' then n:=n+1;end if;
 end loop;
 if n<>9 then raise exception 'MAXIT_ACTION_COUNT_MISMATCH';end if;
 if (select payload from private.catalog_bonus_release_backup where key='transfer_fingerprint') is distinct from
  (select to_jsonb(md5(coalesce(string_agg((to_jsonb(x)-array['commercial_category','technical_validated_at','operator_validated_at','operator_reference'])::text,'' order by id),''))) from public.ussd_execution_rules x where service='unitTransfer') then
  raise exception 'CREDIT_TRANSFER_REGRESSION';end if;
end $$;
commit;
