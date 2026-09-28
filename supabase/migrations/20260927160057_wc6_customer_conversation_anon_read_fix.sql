-- IzyTel WC6 - Lecture conversations avec JWT Firebase via role anon
-- Les clients Web et le staff Firebase utilisent le JWT Firebase tout en
-- passant par le role PostgREST anon. La policy doit donc couvrir anon ET
-- authenticated, la fonction private conservant le controle d'acces metier.

drop policy if exists "customer_conversations_authorized_read"
on public.customer_conversations;

create policy "customer_conversations_authorized_read"
on public.customer_conversations
for select
to anon, authenticated
using (
  private.izytel_wc3_can_read_conversation(id)
);

notify pgrst, 'reload schema';
