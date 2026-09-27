-- WC2 - historique client canonique Supabase + suivi des commandes recuperees.
-- La lecture est limitee a l'UID Firebase courant et n'expose jamais le hash
-- ni le code de recuperation.

create or replace function private.izytel_wc2_customer_order_history()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := nullif(btrim((select auth.jwt()->>'sub')), '');
  v_result jsonb;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'order_id', r.order_id,
        'order_reference', r.order_reference,
        'service', r.service,
        'network', coalesce(o.network, r.network),
        'operation_type', coalesce(o.operation_type, r.operation_type),
        'offer_id', r.offer_id,
        'offer_label', coalesce(o.offer_label, r.offer_label),
        'is_custom_offer', r.is_custom_offer,
        'amount', coalesce(o.amount, r.amount),
        'beneficiary_phone', coalesce(o.beneficiary_phone, r.beneficiary_phone),
        'created_at', r.created_at,
        'expires_at', r.expires_at,
        'order_status', coalesce(
          o.order_status,
          case
            when now() >= r.expires_at
                 and r.order_status = 'awaitingPayment'
                 and r.payment_status = 'notDeclared'
              then 'expired'
            else r.order_status
          end
        ),
        'payment_status', coalesce(
          o.payment_status,
          case
            when now() >= r.expires_at
                 and r.order_status = 'awaitingPayment'
                 and r.payment_status = 'notDeclared'
              then 'expired'
            else r.payment_status
          end
        ),
        'payment_declared_at', r.payment_declared_at,
        'payment_confirmed_at', coalesce(o.payment_confirmed_at, r.payment_confirmed_at),
        'expired_at', coalesce(
          r.expired_at,
          case
            when o.order_id is null
                 and now() >= r.expires_at
                 and r.order_status = 'awaitingPayment'
                 and r.payment_status = 'notDeclared'
              then r.expires_at
            else null
          end
        ),
        'processing_started_at', o.processing_started_at,
        'completed_at', o.completed_at,
        'failure_reason', o.failure_reason,
        'observation', o.observation,
        'customer_confirmation_status', o.customer_confirmation_status,
        'updated_at', coalesce(o.updated_at, r.updated_at)
      )
      order by r.created_at desc
    ),
    '[]'::jsonb
  )
  into v_result
  from public.customer_order_recovery_registry r
  left join public.phase4_assignment_orders o
    on o.order_id = r.order_id
   and upper(o.order_reference) = r.order_reference
  where r.owner_firebase_uid = v_uid
     or exists (
       select 1
       from public.customer_order_recovery_access a
       where a.order_id = r.order_id
         and upper(a.order_reference) = r.order_reference
         and a.customer_firebase_uid = v_uid
     );

  return v_result;
end;
$function$;

create or replace function public.izytel_wc2_customer_order_history()
returns jsonb
language sql
set search_path = ''
as $function$
  select private.izytel_wc2_customer_order_history();
$function$;

revoke execute on function private.izytel_wc2_customer_order_history()
  from public, anon;
grant execute on function private.izytel_wc2_customer_order_history()
  to authenticated, service_role;

revoke execute on function public.izytel_wc2_customer_order_history()
  from public, anon;
grant execute on function public.izytel_wc2_customer_order_history()
  to authenticated, service_role;

create or replace function private.izytel_wc2_customer_order_status(
  p_order_id text,
  p_reference text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := nullif(btrim((select auth.jwt()->>'sub')), '');
  v_order_id text := btrim(coalesce(p_order_id, ''));
  v_reference text := upper(btrim(coalesce(p_reference, '')));
  v_row public.phase4_assignment_orders;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  select o.* into v_row
  from public.phase4_assignment_orders o
  where o.order_id = v_order_id
    and upper(o.order_reference) = v_reference
    and (
      o.customer_auth_uid = v_uid
      or exists (
        select 1
        from public.customer_order_recovery_registry r
        where r.order_id = o.order_id
          and r.order_reference = v_reference
          and r.owner_firebase_uid = v_uid
      )
      or exists (
        select 1
        from public.customer_order_recovery_access a
        where a.order_id = o.order_id
          and upper(a.order_reference) = v_reference
          and a.customer_firebase_uid = v_uid
      )
    );

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'order_id', v_row.order_id,
    'order_reference', v_row.order_reference,
    'order_status', v_row.order_status,
    'payment_status', v_row.payment_status,
    'processing_started_at', v_row.processing_started_at,
    'completed_at', v_row.completed_at,
    'failure_reason', v_row.failure_reason,
    'observation', v_row.observation,
    'customer_confirmation_status', v_row.customer_confirmation_status,
    'updated_at', v_row.updated_at
  );
end;
$function$;

notify pgrst, 'reload schema';
