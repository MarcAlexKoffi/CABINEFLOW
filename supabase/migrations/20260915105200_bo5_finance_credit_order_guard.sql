-- Un credit BO-5 doit obligatoirement correspondre a une vraie commande canonique.
create or replace function public.izytel_finance_create_credit(
  p_credit_id text,p_order_id text,p_order_reference text,p_client_name text,
  p_client_whatsapp_phone text,p_amount bigint,p_note text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_finance_actor_name();
  v_id text := btrim(coalesce(p_credit_id,''));
  v_order public.phase4_assignment_orders;
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
  if v_id='' then v_id:='credit_'||gen_random_uuid()::text; end if;
  if p_amount<=0 or btrim(coalesce(p_order_id,''))='' or btrim(coalesce(p_order_reference,''))='' then raise exception 'INVALID_CREDIT'; end if;
  select * into v_order from public.phase4_assignment_orders where order_id=btrim(p_order_id) for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if upper(v_order.order_reference)<>upper(btrim(p_order_reference)) then raise exception 'ORDER_REFERENCE_MISMATCH'; end if;
  if v_order.amount<>p_amount then raise exception 'CREDIT_AMOUNT_MISMATCH'; end if;
  if v_order.order_status in('completed','refunded','refundPending','cancelled') then raise exception 'ORDER_CREDIT_STATE_INVALID'; end if;
  if v_order.payment_status='confirmed' and v_order.payment_reference is not null then raise exception 'CONFIRMED_PAYMENT_ALREADY_EXISTS'; end if;
  update public.phase4_assignment_orders
  set payment_status='credit',payment_reference=null,payment_confirmed_at=null,paid_at=coalesce(paid_at,now()),order_status='paidReady',updated_at=now()
  where order_id=v_order.order_id;
  insert into public.finance_customer_credits(id,order_id,order_reference,client_name,client_whatsapp_phone,amount,paid_amount,status,note,created_at,created_by_uid,created_by_name,updated_at)
  values(v_id,v_order.order_id,v_order.order_reference,coalesce(nullif(btrim(p_client_name),''),v_order.client_name,'Client'),coalesce(nullif(btrim(p_client_whatsapp_phone),''),v_order.client_whatsapp_phone,''),p_amount,0,'open',nullif(btrim(coalesce(p_note,'')),''),now(),v_uid,v_name,now())
  on conflict(order_id) do nothing;
  if not found then raise exception 'CREDIT_ALREADY_EXISTS'; end if;
  insert into public.finance_audit_events(event_kind,entity_type,entity_id,actor_uid,actor_name,payload)
  values('credit_authorized','customer_credit',v_id,v_uid,v_name,jsonb_build_object('order_id',v_order.order_id,'amount',p_amount));
  return v_id;
end;
$function$;
revoke all on function public.izytel_finance_create_credit(text,text,text,text,text,bigint,text) from public;
grant execute on function public.izytel_finance_create_credit(text,text,text,text,text,bigint,text) to anon, authenticated;
