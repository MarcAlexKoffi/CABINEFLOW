-- LOCAL ONLY. Requires USSD V1 and the aliases/secret/draft follow-up.
-- No order, payment, capacity, commission or telecom mutation.
-- Keep rule identities and snapshots: execution logs/reports reference them.
alter table public.ussd_execution_rules
  add column deleted_at timestamptz,
  add column deleted_by text,
  add constraint ussd_rule_deletion_pair check ((deleted_at is null) = (deleted_by is null)),
  add constraint ussd_deleted_rule_disabled check (deleted_at is null or status='disabled');
alter table public.ussd_offer_families
  add column deleted_at timestamptz,
  add column deleted_by text,
  add constraint ussd_family_deletion_pair check ((deleted_at is null) = (deleted_by is null));
alter table public.ussd_offer_families drop constraint ussd_offer_families_network_service_label_key;
create unique index ussd_live_family_label on public.ussd_offer_families(network,service,label)
  where deleted_at is null;

-- Existing save/status RPCs must never resurrect a deleted rule, including
-- stale forms. Family references are checked for ALL existing write paths.
create function private.ussd_guard_deleted_rule() returns trigger
language plpgsql set search_path='' as $$
begin
  if tg_op='UPDATE' and old.deleted_at is not null then raise exception 'rule_deleted'; end if;
  if new.deleted_at is null and new.family_id is not null and not exists(
    select 1 from public.ussd_offer_families f where f.id=new.family_id and f.deleted_at is null
  ) then raise exception 'invalid_association'; end if;
  return new;
end $$;
create trigger ussd_guard_deleted_rule before insert or update on public.ussd_execution_rules
  for each row execute function private.ussd_guard_deleted_rule();
create function private.ussd_guard_deleted_family_binding() returns trigger
language plpgsql set search_path='' as $$
begin
  if new.family_id is not null and not exists(
    select 1 from public.ussd_offer_families f where f.id=new.family_id and f.deleted_at is null
  ) then raise exception 'invalid_association'; end if;
  return new;
end $$;
create trigger ussd_guard_deleted_family_binding before insert or update on public.ussd_offer_bindings
  for each row execute function private.ussd_guard_deleted_family_binding();

create or replace function private.ussd_configuration() returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  perform private.ussd_staff();
  return jsonb_build_object('rules',coalesce((select jsonb_agg(to_jsonb(r) order by r.updated_at desc)
    from public.ussd_execution_rules r where r.deleted_at is null and private.ussd_rule_visible(r)),'[]'::jsonb),
    'families',coalesce((select jsonb_agg(to_jsonb(f) order by f.label)
      from public.ussd_offer_families f where f.deleted_at is null),'[]'::jsonb),
    'offers',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'network',c.network,'service',private.ussd_service(c.operation_type),
      'title',c.title,'binding',to_jsonb(b)) order by c.display_order,c.id)
      from public.catalog_offers c left join public.ussd_offer_bindings b on b.offer_id=c.id
      where c.deleted_at is null and (coalesce(private.is_izytel_finance_admin(),false) or exists(
        select 1 from public.ussd_order_contexts ctx join public.phase4_assignment_orders o on o.order_id=ctx.order_id
        where ctx.offer_id=c.id and private.ussd_zone(o.zone_id)))),'[]'::jsonb));
end $$;

create function private.ussd_delete_rule(p_rule_id uuid,p_expected_version integer) returns void
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_admin(); r public.ussd_execution_rules;
begin
  perform pg_advisory_xact_lock(9261031);
  select * into r from public.ussd_execution_rules where id=p_rule_id for update;
  if not found then raise exception 'rule_changed'; end if;
  if r.deleted_at is not null then return; end if;
  if p_expected_version is distinct from r.version then raise exception 'rule_changed'; end if;
  update public.ussd_execution_rules set status='disabled',deleted_at=clock_timestamp(),deleted_by=v_uid,
    version=version+1,updated_by=v_uid,updated_at=clock_timestamp() where id=r.id returning * into r;
  insert into public.ussd_rule_versions values(r.id,r.version,to_jsonb(r));
end $$;

create function private.ussd_delete_family(p_family_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_admin(); f public.ussd_offer_families;
begin
  perform pg_advisory_xact_lock(9261031);
  select * into f from public.ussd_offer_families where id=p_family_id for update;
  if not found then raise exception 'family_changed'; end if;
  if f.deleted_at is not null then return; end if;
  if exists(select 1 from public.ussd_execution_rules r where r.family_id=f.id and r.deleted_at is null)
    or exists(select 1 from public.ussd_offer_bindings b where b.family_id=f.id) then
    raise exception 'family_in_use';
  end if;
  update public.ussd_offer_families set deleted_at=clock_timestamp(),deleted_by=v_uid where id=f.id;
end $$;

create function private.ussd_delete_binding(p_offer_id text,p_expected_version integer) returns void
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_admin(); b public.ussd_offer_bindings; c public.catalog_offers;
begin
  perform pg_advisory_xact_lock(9261031);
  select * into b from public.ussd_offer_bindings where offer_id=p_offer_id for update;
  if not found then return; end if;
  if p_expected_version is distinct from b.version then raise exception 'binding_changed'; end if;
  select * into strict c from public.catalog_offers where id=p_offer_id;
  if exists(select 1 from public.ussd_execution_rules r where r.deleted_at is null and r.status='active'
    and r.network=c.network and r.service=private.ussd_service(c.operation_type)
    and (r.offer_id is null or r.offer_id=c.id) and (r.family_id is null or r.family_id=b.family_id)
    and (r.offer_id=c.id or r.family_id=b.family_id or r.ussd_template ~ '\{\{(offer_code|quantity)\}\}')) then
    raise exception 'active_binding_in_use';
  end if;
  insert into public.ussd_binding_versions values(b.offer_id,b.version+1,
    to_jsonb(b) || jsonb_build_object('version',b.version+1,'deleted_at',clock_timestamp(),'deleted_by',v_uid));
  delete from public.ussd_offer_bindings where offer_id=b.offer_id;
end $$;

-- Recreating an association continues its immutable history instead of
-- resetting to version 1 or accidentally reusing a confirmation context.
create or replace function private.ussd_save_binding(p_offer_id text,p_family_id uuid,p_offer_code text,p_quantity integer) returns void
language plpgsql security definer set search_path='' as $$
declare v_uid text := private.ussd_admin(); c public.catalog_offers; b public.ussd_offer_bindings; v_next integer;
begin
  perform pg_advisory_xact_lock(9261031);
  select * into strict c from public.catalog_offers where id=p_offer_id and deleted_at is null;
  if p_family_id is not null and not exists(select 1 from public.ussd_offer_families f
    where f.id=p_family_id and f.deleted_at is null and f.network=c.network and f.service=private.ussd_service(c.operation_type)) then raise exception 'invalid_association'; end if;
  select * into b from public.ussd_offer_bindings where offer_id=p_offer_id;
  if exists(select 1 from public.ussd_execution_rules r where r.status='active' and r.network=c.network
    and r.service=private.ussd_service(c.operation_type) and (r.offer_id=p_offer_id or r.family_id in (b.family_id,p_family_id))) then
    raise exception 'active_binding_in_use';
  end if;
  select coalesce(max(version),0)+1 into v_next from public.ussd_binding_versions where offer_id=p_offer_id;
  insert into public.ussd_offer_bindings(offer_id,family_id,offer_code,quantity,version,updated_by)
  values(p_offer_id,p_family_id,nullif(p_offer_code,''),p_quantity,v_next,v_uid)
  on conflict(offer_id) do update set family_id=excluded.family_id,offer_code=excluded.offer_code,
    quantity=excluded.quantity,version=excluded.version,updated_by=v_uid,updated_at=clock_timestamp()
  returning * into b;
  insert into public.ussd_binding_versions values(b.offer_id,b.version,to_jsonb(b));
end $$;

create function public.izytel_ussd_delete_rule(p_rule_id uuid,p_expected_version integer) returns void
language sql security invoker set search_path='' as $$ select private.ussd_delete_rule(p_rule_id,p_expected_version); $$;
create function public.izytel_ussd_delete_family(p_family_id uuid) returns void
language sql security invoker set search_path='' as $$ select private.ussd_delete_family(p_family_id); $$;
create function public.izytel_ussd_delete_binding(p_offer_id text,p_expected_version integer) returns void
language sql security invoker set search_path='' as $$ select private.ussd_delete_binding(p_offer_id,p_expected_version); $$;

revoke all on function private.ussd_guard_deleted_rule(),private.ussd_guard_deleted_family_binding() from public,anon,authenticated;
revoke all on function private.ussd_delete_rule(uuid,integer),private.ussd_delete_family(uuid),private.ussd_delete_binding(text,integer),
  public.izytel_ussd_delete_rule(uuid,integer),public.izytel_ussd_delete_family(uuid),public.izytel_ussd_delete_binding(text,integer) from public,anon,authenticated;
-- Same Firebase-JWT access pattern as V1; each entry point checks the live
-- administrator role before inspecting any configuration row. No table grant.
grant execute on function private.ussd_delete_rule(uuid,integer),private.ussd_delete_family(uuid),private.ussd_delete_binding(text,integer),
  public.izytel_ussd_delete_rule(uuid,integer),public.izytel_ussd_delete_family(uuid),public.izytel_ussd_delete_binding(text,integer) to anon,authenticated;
