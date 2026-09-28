-- IzyTel WC6 — correctif d'exécution RPC Web Client
-- Le Web Client utilise un JWT Firebase transmis via le client Supabase.
-- PostgREST exécute alors les RPC sous le rôle SQL anon ; les fonctions
-- conservent leurs contrôles métier internes via public.is_izytel_firebase_jwt().

grant execute on function public.izytel_wc5_create_conversation(
  text,text,text,text,text,double precision,double precision
) to anon, authenticated, service_role;

grant execute on function public.izytel_wc2_customer_order_history()
  to anon, authenticated, service_role;

notify pgrst, 'reload schema';
