-- BO-5 : les Managers peuvent consulter les finances, mais seules les sessions Admin ecrivent le registre fournisseurs.
drop policy if exists "finance staff creates suppliers" on public.finance_suppliers;
drop policy if exists "finance admin creates suppliers" on public.finance_suppliers;
create policy "finance admin creates suppliers" on public.finance_suppliers for insert to anon, authenticated
with check ((select private.is_izytel_finance_admin()) and created_by_uid=(select auth.jwt()->>'sub') and updated_by_uid=(select auth.jwt()->>'sub') and is_deleted=false);

drop policy if exists "finance staff updates suppliers" on public.finance_suppliers;
drop policy if exists "finance admin updates suppliers" on public.finance_suppliers;
create policy "finance admin updates suppliers" on public.finance_suppliers for update to anon, authenticated
using ((select private.is_izytel_finance_admin())) with check ((select private.is_izytel_finance_admin()));
