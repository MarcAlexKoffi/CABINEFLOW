-- IzyTel BO-7.3 targeted fixes
-- 1) The Agent/Manager issue RLS policies call this scoped helper directly.
--    Data API roles must be allowed to execute it; the helper still validates
--    Firebase JWT + role/territory itself.
grant execute on function private.izytel_issue_agent_in_scope(text)
  to anon, authenticated;

-- 2) Catalogue deletion is intentionally soft: an offer disappears from the
--    live catalogue but historical orders and audit records remain intact.
alter table public.catalog_offers
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by_uid text,
  add column if not exists deleted_by_name text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'catalog_offers_deleted_inactive_check'
      and conrelid = 'public.catalog_offers'::regclass
  ) then
    alter table public.catalog_offers
      add constraint catalog_offers_deleted_inactive_check
      check (deleted_at is null or is_active = false);
  end if;
end;
$$;

create or replace function public.izytel_delete_catalog_offer(p_offer_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id text := btrim(coalesce(p_offer_id, ''));
  v_actor_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_actor_name text := private.izytel_staff_display_name();
  v_before public.catalog_offers;
  v_result public.catalog_offers;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;

  if v_id = '' then
    raise exception 'CATALOG_OFFER_REQUIRED';
  end if;

  select * into v_before
  from public.catalog_offers
  where id = v_id
    and deleted_at is null
  for update;

  if v_before.id is null then
    raise exception 'CATALOG_OFFER_NOT_FOUND';
  end if;

  update public.catalog_offers
  set is_active = false,
      deleted_at = now(),
      deleted_by_uid = v_actor_uid,
      deleted_by_name = v_actor_name,
      updated_by_uid = v_actor_uid,
      updated_by_name = v_actor_name,
      updated_at = now()
  where id = v_id
  returning * into v_result;

  insert into public.catalog_offer_audit_events(
    offer_id,
    action,
    before_state,
    after_state,
    actor_uid,
    actor_name,
    actor_role
  ) values (
    v_id,
    'deleted',
    to_jsonb(v_before),
    to_jsonb(v_result),
    v_actor_uid,
    v_actor_name,
    'admin'
  );

  return jsonb_build_object(
    'id', v_result.id,
    'deleted_at', v_result.deleted_at
  );
end;
$$;

revoke all on function public.izytel_delete_catalog_offer(text) from public;
grant execute on function public.izytel_delete_catalog_offer(text)
  to anon, authenticated;

comment on function public.izytel_delete_catalog_offer(text) is
  'Admin-only soft delete of a catalog offer while preserving historical orders and audit.';
