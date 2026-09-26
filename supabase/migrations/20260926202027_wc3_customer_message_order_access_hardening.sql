-- WC3A hardening : une commande Web peut ouvrir une conversation avant son
-- handoff Phase 4. Le registre WC2 reste donc une source d'autorisation client.

create or replace function private.izytel_wc3_customer_has_order_access(
  p_order_id text,
  p_order_reference text,
  p_customer_uid text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.phase4_assignment_orders order_row
    where order_row.order_id = btrim(coalesce(p_order_id, ''))
      and upper(order_row.order_reference) = upper(btrim(coalesce(p_order_reference, '')))
      and coalesce(order_row.customer_auth_uid, '') = btrim(coalesce(p_customer_uid, ''))
  ) or exists (
    select 1
    from public.customer_order_recovery_registry recovery_row
    where recovery_row.order_id = btrim(coalesce(p_order_id, ''))
      and upper(recovery_row.order_reference) = upper(btrim(coalesce(p_order_reference, '')))
      and recovery_row.owner_firebase_uid = btrim(coalesce(p_customer_uid, ''))
  ) or exists (
    select 1
    from public.customer_order_recovery_access access_row
    where access_row.order_id = btrim(coalesce(p_order_id, ''))
      and upper(access_row.order_reference) = upper(btrim(coalesce(p_order_reference, '')))
      and access_row.customer_firebase_uid = btrim(coalesce(p_customer_uid, ''))
  );
$function$;
