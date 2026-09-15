-- BO-4 hardening : le catalogue actif est public côté Web client.
-- Les offres suspendues restent visibles uniquement par l'Administrateur.

drop policy if exists "catalog active or admin read" on public.catalog_offers;
create policy "catalog active or admin read"
  on public.catalog_offers
  for select
  to anon, authenticated
  using (
    is_active = true
    or (
      (select public.is_izytel_firebase_jwt())
      and (select private.is_izytel_finance_admin())
    )
  );

create or replace function public.izytel_finish_catalog_backfill(p_imported_count integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_uid text := (select auth.jwt()->>'sub');
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;

  insert into public.catalog_migration_state (
    migration_key,
    completed_at,
    imported_count,
    completed_by
  ) values (
    'firestore_offers_v1',
    now(),
    greatest(coalesce(p_imported_count, 0), 0),
    v_actor_uid
  )
  on conflict (migration_key) do update
  set completed_at = excluded.completed_at,
      imported_count = public.catalog_migration_state.imported_count + excluded.imported_count,
      completed_by = excluded.completed_by;
end;
$$;
