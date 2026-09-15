-- Autorisation de credit canonique : lecture de la commande legacy, puis ecriture atomique uniquement dans Supabase.
create or replace function public.izytel_finance_authorize_credit_order(p_payload jsonb,p_note text default null)
returns text language plpgsql security definer set search_path=''
as $function$
declare
  v_id text := btrim(coalesce(p_payload->>'order_id',''));
  v_reference text := btrim(coalesce(p_payload->>'order_reference',''));
  v_network text := lower(btrim(coalesce(p_payload->>'network','')));
  v_amount integer := coalesce((p_payload->>'amount')::integer,0);
  v_source text := btrim(coalesce(p_payload->>'source',''));
  v_operation_type text := btrim(coalesce(p_payload->>'operation_type',''));
  v_original_status text := btrim(coalesce(p_payload->>'original_order_status',''));
  v_original_payment_status text := btrim(coalesce(p_payload->>'original_payment_status',''));
  v_original_payment_reference text := btrim(coalesce(p_payload->>'original_payment_reference',''));
  v_created_at timestamptz := coalesce(nullif(p_payload->>'created_at','')::timestamptz,now());
  v_credit_id text;
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
  if v_id='' or v_reference='' or v_amount<=0 then raise exception 'INVALID_CREDIT_ORDER'; end if;
  if v_network not in('orange','mtn','moov') then raise exception 'INVALID_NETWORK'; end if;
  if v_source not in('customerWeb','operatorApp') then raise exception 'INVALID_SOURCE'; end if;
  if v_operation_type not in('internetSubscription','unitTransfer','callBundle','mixedBundle','other') then raise exception 'INVALID_OPERATION_TYPE'; end if;
  if v_original_status not in('awaitingPayment','paymentToVerify','expired') then raise exception 'CREDIT_ORDER_STATE_INVALID'; end if;
  if v_original_payment_status in('confirmed','credit','declared') or v_original_payment_reference<>'' then raise exception 'PAYMENT_ALREADY_IN_PROGRESS'; end if;
  if exists(select 1 from public.finance_customer_credits c where c.order_id=v_id) then
    return (select c.id from public.finance_customer_credits c where c.order_id=v_id limit 1);
  end if;
  if exists(select 1 from public.phase4_assignment_orders o where o.order_id=v_id and(o.payment_status='confirmed' or o.payment_reference is not null)) then
    raise exception 'CONFIRMED_PAYMENT_ALREADY_EXISTS';
  end if;
  perform public.phase3_sync_order(
    v_id,v_reference,v_network,v_amount,v_created_at,now(),v_source,
    coalesce(nullif(btrim(p_payload->>'client_name'),''),'Client'),
    btrim(coalesce(p_payload->>'client_whatsapp_phone','')),
    btrim(coalesce(p_payload->>'beneficiary_phone','')),
    v_operation_type,coalesce(nullif(btrim(p_payload->>'offer_label'),''),'Offre non renseignee'),
    nullif(btrim(coalesce(p_payload->>'original_whatsapp_message','')),''),
    nullif(btrim(coalesce(p_payload->>'internal_notes','')),''),
    'credit',null,null,null,nullif(btrim(coalesce(p_payload->>'customer_auth_uid','')),'')
  );
  v_credit_id := public.izytel_finance_create_credit(null,v_id,v_reference,coalesce(nullif(btrim(p_payload->>'client_name'),''),'Client'),btrim(coalesce(p_payload->>'client_whatsapp_phone','')),v_amount,p_note);
  return v_credit_id;
end;$function$;
revoke all on function public.izytel_finance_authorize_credit_order(jsonb,text) from public;
grant execute on function public.izytel_finance_authorize_credit_order(jsonb,text) to anon, authenticated;
