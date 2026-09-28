-- WC6 — Web client Firebase JWT : droits sur les wrappers privés appelés par les RPC publics.

grant execute on function private.izytel_wc5_create_conversation(
  text,text,text,text,text,double precision,double precision
) to anon, authenticated, service_role;

grant execute on function private.izytel_wc2_customer_order_history()
  to anon, authenticated, service_role;

notify pgrst, 'reload schema';
