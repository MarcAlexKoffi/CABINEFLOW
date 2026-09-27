-- BO-3C — portée territoriale : Admin voit tout ; Manager/Supervisor voit ses zones ; Agent voit ses zones.

create or replace function private.can_read_izytel_territory_zone(p_zone_id text, p_manager_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_izytel_firebase_jwt()
    and (
      exists (
        select 1 from public.izytel_staff_access staff
        where staff.firebase_uid = (select auth.jwt()->>'sub')
          and staff.is_active = true and staff.role = 'admin'
      )
      or (
        p_manager_id = (select auth.jwt()->>'sub')
        and exists (
          select 1 from public.izytel_staff_access staff
          where staff.firebase_uid = (select auth.jwt()->>'sub')
            and staff.is_active = true
            and staff.role in ('manager', 'supervisor')
        )
      )
      or exists (
        select 1 from public.phase5_agent_capacities agent
        where agent.agent_id = (select auth.jwt()->>'sub')
          and agent.is_active = true
          and p_zone_id = any(agent.zone_ids)
      )
    );
$$;

drop policy if exists "territory zones operational read" on public.territory_zones;
create policy "territory zones operational read"
  on public.territory_zones
  for select
  to anon, authenticated
  using ((select private.can_read_izytel_territory_zone(id, manager_id)));

create or replace function private.can_read_izytel_manager_profile(p_manager_uid text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_izytel_firebase_jwt()
    and (
      exists (
        select 1 from public.izytel_staff_access staff
        where staff.firebase_uid = (select auth.jwt()->>'sub')
          and staff.is_active = true and staff.role = 'admin'
      )
      or (
        p_manager_uid = (select auth.jwt()->>'sub')
        and exists (
          select 1 from public.izytel_staff_access staff
          where staff.firebase_uid = (select auth.jwt()->>'sub')
            and staff.is_active = true
            and staff.role in ('manager', 'supervisor')
        )
      )
    );
$$;

drop policy if exists "territory managers staff read" on public.manager_profiles;
create policy "territory managers scoped read"
  on public.manager_profiles
  for select
  to anon, authenticated
  using ((select private.can_read_izytel_manager_profile(firebase_uid)));
