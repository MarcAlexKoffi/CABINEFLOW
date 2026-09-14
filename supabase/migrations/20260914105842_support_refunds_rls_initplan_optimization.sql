-- IzyTel - évite la réévaluation du helper JWT pour chaque ligne Support.
drop policy if exists "support customer or staff read" on public.support_requests;
create policy "support customer or staff read"
on public.support_requests
for select
to anon, authenticated
using (
  (select public.is_izytel_firebase_jwt())
  and (
    customer_auth_uid = (select auth.jwt()->>'sub')
    or (select private.is_izytel_finance_staff())
  )
);
