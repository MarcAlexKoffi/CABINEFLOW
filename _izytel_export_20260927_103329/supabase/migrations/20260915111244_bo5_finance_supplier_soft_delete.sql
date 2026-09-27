-- Les fournisseurs avec historique ne sont jamais effaces physiquement.
alter table public.finance_suppliers add column if not exists is_deleted boolean not null default false;
update public.finance_suppliers set is_active=false where is_deleted=true;

create or replace function public.izytel_finance_save_supplier(p_supplier_id text,p_name text,p_phone_number text,p_note text default null)
returns text language plpgsql security definer set search_path=''
as $function$
declare v_uid text:=(select auth.jwt()->>'sub'); v_name text:=private.izytel_finance_actor_name(); v_id text:=btrim(coalesce(p_supplier_id,''));
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
  if char_length(btrim(coalesce(p_name,'')))<2 then raise exception 'INVALID_SUPPLIER_NAME'; end if;
  if v_id='' then v_id:='supplier_'||replace(gen_random_uuid()::text,'-',''); end if;
  insert into public.finance_suppliers(id,name,phone_number,note,is_active,is_deleted,created_by_uid,created_by_name,updated_by_uid,updated_by_name,created_at,updated_at)
  values(v_id,btrim(p_name),btrim(coalesce(p_phone_number,'')),nullif(btrim(coalesce(p_note,'')),''),true,false,v_uid,v_name,v_uid,v_name,now(),now())
  on conflict(id) do update set name=excluded.name,phone_number=excluded.phone_number,note=excluded.note,is_deleted=false,updated_by_uid=v_uid,updated_by_name=v_name,updated_at=now();
  insert into public.finance_audit_events(event_kind,entity_type,entity_id,actor_uid,actor_name,payload)
  values('supplier_saved','supplier',v_id,v_uid,v_name,jsonb_build_object('name',btrim(p_name)));
  return v_id;
end;$function$;

create or replace function public.izytel_finance_set_supplier_active(p_supplier_id text,p_is_active boolean)
returns void language plpgsql security definer set search_path=''
as $function$
declare v_uid text:=(select auth.jwt()->>'sub'); v_name text:=private.izytel_finance_actor_name();
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
  update public.finance_suppliers set is_active=p_is_active,updated_by_uid=v_uid,updated_by_name=v_name,updated_at=now()
  where id=btrim(p_supplier_id) and is_deleted=false;
  if not found then raise exception 'SUPPLIER_NOT_FOUND'; end if;
  insert into public.finance_audit_events(event_kind,entity_type,entity_id,actor_uid,actor_name,payload)
  values('supplier_status_changed','supplier',btrim(p_supplier_id),v_uid,v_name,jsonb_build_object('is_active',p_is_active));
end;$function$;

create or replace function public.izytel_finance_delete_supplier(p_supplier_id text)
returns void language plpgsql security definer set search_path=''
as $function$
declare v_uid text:=(select auth.jwt()->>'sub'); v_name text:=private.izytel_finance_actor_name(); v_id text:=btrim(coalesce(p_supplier_id,''));
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
  if v_id='' then raise exception 'SUPPLIER_NOT_FOUND'; end if;
  if exists(select 1 from public.phase5_supplier_accounts where supplier_id=v_id)
     or exists(select 1 from public.phase5_agent_recharges where supplier_id=v_id)
     or exists(select 1 from public.phase5_supplier_payments where supplier_id=v_id) then
    raise exception 'SUPPLIER_HAS_HISTORY';
  end if;
  update public.finance_suppliers set is_active=false,is_deleted=true,updated_by_uid=v_uid,updated_by_name=v_name,updated_at=now()
  where id=v_id and is_deleted=false;
  if not found then raise exception 'SUPPLIER_NOT_FOUND'; end if;
  insert into public.finance_audit_events(event_kind,entity_type,entity_id,actor_uid,actor_name,payload)
  values('supplier_soft_deleted','supplier',v_id,v_uid,v_name,'{}'::jsonb);
end;$function$;

revoke all on function public.izytel_finance_save_supplier(text,text,text,text) from public;
revoke all on function public.izytel_finance_set_supplier_active(text,boolean) from public;
revoke all on function public.izytel_finance_delete_supplier(text) from public;
grant execute on function public.izytel_finance_save_supplier(text,text,text,text) to anon, authenticated;
grant execute on function public.izytel_finance_set_supplier_active(text,boolean) to anon, authenticated;
grant execute on function public.izytel_finance_delete_supplier(text) to anon, authenticated;
