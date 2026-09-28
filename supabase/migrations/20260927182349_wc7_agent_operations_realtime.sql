-- IzyTel WC7 - profil operationnel Agent en Realtime
-- Remplace le polling REST agressif de 3 secondes par Supabase Realtime.

do $block$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'phase5_agent_capacities'
  ) then
    alter publication supabase_realtime add table public.phase5_agent_capacities;
  end if;
end
$block$;
