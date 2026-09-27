-- Signal Realtime leger : l'UI relit un snapshot coherent apres toute mutation BO-5.
create table if not exists public.finance_change_feed (
  id smallint primary key default 1 check (id=1),
  revision bigint not null default 0,
  changed_at timestamptz not null default now()
);
insert into public.finance_change_feed(id,revision,changed_at) values(1,0,now()) on conflict(id) do nothing;
alter table public.finance_change_feed enable row level security;
revoke all on public.finance_change_feed from anon, authenticated;
grant select on public.finance_change_feed to anon, authenticated;
drop policy if exists "finance change feed staff read" on public.finance_change_feed;
create policy "finance change feed staff read" on public.finance_change_feed for select to anon, authenticated
using ((select private.is_izytel_phase4_staff()));

create or replace function private.izytel_finance_touch()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  update public.finance_change_feed set revision=revision+1,changed_at=now() where id=1;
  return null;
end;$function$;

do $do$
declare t text;
begin
  foreach t in array array['finance_suppliers','finance_customer_credits','finance_customer_credit_settlements','finance_expenses','finance_wave_settings','finance_wave_balance_adjustments','finance_daily_closings'] loop
    execute format('drop trigger if exists bo5_touch_%I on public.%I', t, t);
    execute format('create trigger bo5_touch_%I after insert or update or delete on public.%I for each statement execute function private.izytel_finance_touch()', t, t);
  end loop;
end;$do$;

do $do$
begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='finance_change_feed') then
    alter publication supabase_realtime add table public.finance_change_feed;
  end if;
end;$do$;
