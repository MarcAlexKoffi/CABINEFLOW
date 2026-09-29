-- IzyTel WC13B - correction RLS territoriale + RPC WC6 manquants.
-- Cette migration est deja appliquee sur la production Supabase le 29/09/2026.

-- Les policies RLS territoriales invoquent ce helper SECURITY DEFINER.
-- Le schema private n'est pas expose par l'API, mais les roles applicatifs
-- doivent disposer de EXECUTE pour que l'evaluation de la policy fonctionne.
grant execute on function private.izytel_wc5_manager_owns_zone(text,text)
  to anon, authenticated;

create or replace function public.izytel_wc6_visible_legacy_order_ids()
returns table(order_id text)
language sql
stable
security definer
set search_path = ''
as $function$
  select distinct scoped.order_id
  from (
    select o.order_id, o.zone_id
    from public.phase4_assignment_orders o
    union all
    select c.order_id, c.zone_id
    from public.customer_order_contexts c
  ) scoped
  where public.is_izytel_firebase_jwt()
    and scoped.order_id is not null
    and (
      private.is_izytel_finance_admin()
      or private.izytel_wc5_manager_owns_zone(
        scoped.zone_id,
        (select auth.jwt()->>'sub')
      )
    );
$function$;

revoke all on function public.izytel_wc6_visible_legacy_order_ids()
  from public;
grant execute on function public.izytel_wc6_visible_legacy_order_ids()
  to anon, authenticated;

create or replace function public.izytel_wc6_manager_assignment_allowed(
  p_order_id text,
  p_agent_id text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select public.is_izytel_firebase_jwt()
    and (
      private.is_izytel_finance_admin()
      or exists (
        select 1
        from public.phase4_assignment_orders o
        join public.phase5_agent_capacities a
          on a.agent_id = btrim(coalesce(p_agent_id, ''))
        where o.order_id = btrim(coalesce(p_order_id, ''))
          and private.izytel_wc5_manager_owns_zone(
            o.zone_id,
            (select auth.jwt()->>'sub')
          )
          and o.zone_id = any(coalesce(a.zone_ids, array[]::text[]))
      )
    );
$function$;

revoke all on function public.izytel_wc6_manager_assignment_allowed(text,text)
  from public;
grant execute on function public.izytel_wc6_manager_assignment_allowed(text,text)
  to anon, authenticated;
