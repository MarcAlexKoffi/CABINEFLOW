-- BO-4 hotfix: canonical realtime invalidation signal for public/client/staff catalog readers.
-- The signal contains no offer data. It only tells consumers to refetch the
-- active catalog, which also makes deactivation/removal propagate immediately.

create table if not exists public.catalog_change_feed (
  id smallint primary key default 1 check (id = 1),
  revision bigint not null default 0,
  changed_at timestamptz not null default now()
);

insert into public.catalog_change_feed (id, revision, changed_at)
values (1, 0, now())
on conflict (id) do nothing;

alter table public.catalog_change_feed enable row level security;

drop policy if exists "catalog change feed public read" on public.catalog_change_feed;
create policy "catalog change feed public read"
on public.catalog_change_feed
for select
to anon, authenticated
using (true);

revoke all on table public.catalog_change_feed from anon, authenticated;
grant select on table public.catalog_change_feed to anon, authenticated;

create or replace function private.izytel_touch_catalog_change_feed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.catalog_change_feed
  set revision = revision + 1,
      changed_at = now()
  where id = 1;
  return null;
end;
$$;

revoke all on function private.izytel_touch_catalog_change_feed() from public, anon, authenticated;

drop trigger if exists catalog_offers_touch_change_feed on public.catalog_offers;
create trigger catalog_offers_touch_change_feed
after insert or update or delete on public.catalog_offers
for each statement
execute function private.izytel_touch_catalog_change_feed();

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'catalog_change_feed'
  ) then
    alter publication supabase_realtime add table public.catalog_change_feed;
  end if;
end;
$$;
