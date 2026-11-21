-- Restore web shortcuts from their immutable server-side checkout snapshot.
-- Existing context associations, order ownership and execution gates are preserved.
-- No order, payment, execution attempt or financial row is modified.
CREATE OR REPLACE FUNCTION private.ussd_resolve_before_execution(p_order_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare o public.phase4_assignment_orders;r public.ussd_execution_rules;offer text;actor text;code text;phone text;
 snapshot jsonb;fields jsonb;route_operation text;
begin
 perform private.ussd_uid();
 select * into strict o from public.phase4_assignment_orders where order_id=p_order_id;
 actor:=private.ussd_actor(o);
 if o.operation_type='unitTransfer' then return private.ussd_resolve_before_commercial_categories(p_order_id);end if;
 if o.order_status<>'inProgress' or o.assignment_state<>'accepted' or o.payment_status not in ('confirmed','credit') then
  return jsonb_build_object('status','unavailable','reason','order_not_processable');end if;
 select offer_id into offer from public.ussd_order_contexts where order_id=o.order_id;
 route_operation:=o.operation_type;
 -- The web checkout already freezes the exact selected offer in the canonical
 -- order snapshot. Its separate best-effort context RPC can be absent.
 -- Never guess by title, price, phone prefix, or an offer currently on sale.
 if offer is null and o.source='customerWeb' then
  snapshot:=o.catalog_snapshot;
  fields:=snapshot->'order_fields';
  begin
   if nullif(snapshot->>'offer_id','') is not null
    and fields->>'offer_id'=snapshot->>'offer_id'
    and fields->>'order_id'=o.order_id
    and fields->>'order_reference'=o.order_reference
    and nullif(fields->>'owner_firebase_uid','')=o.customer_auth_uid
    and fields->>'network'=o.network
    and fields->>'operation_type'=o.operation_type
    and fields->'amount'=to_jsonb(o.amount)
    and fields->'is_custom_offer'='false'::jsonb
    and private.ussd_phone(fields->>'beneficiary_phone')=private.ussd_phone(o.beneficiary_phone) then
    offer:=snapshot->>'offer_id';
    -- Older web clients labelled selected mixed bundles as callBundle.
    -- The immutable offer ID (not that historic label) identifies the route.
    -- Keep the stored order and all financial records unchanged.
    if o.operation_type='callBundle' and fields->>'service'='calls'
     and exists(select 1 from public.catalog_offers c where c.id=offer
       and c.network=o.network and c.operation_type='mixedBundle' and c.category='mixed') then
     route_operation:='mixedBundle';
    end if;
   end if;
  exception when raise_exception then
   offer:=null;
   route_operation:=o.operation_type;
  end;
 end if;
 begin
  r:=private.catalog_subscription_rule(offer,o.network,route_operation,actor);
  code:=private.ussd_generate(r.ussd_template,o.beneficiary_phone,o.amount,null,null,null);
 exception when raise_exception then return jsonb_build_object('status','unavailable','reason',sqlerrm);end;
 phone:=private.ussd_phone(o.beneficiary_phone);
 return jsonb_build_object('status','available','reason','',
 'rule',to_jsonb(r)-'internal_note'-'created_by'-'updated_by','code',code,
 'context',jsonb_build_object('network',o.network,'service',private.ussd_service(o.operation_type),'offer_id',offer,
  'commercial_category',r.commercial_category,'offer_label',o.offer_label,'beneficiary',o.beneficiary_phone,'amount',o.amount,
  'binding_version',null,'quantity',null,'offer_code',null,'secret_revision',null),
 'network_mismatch',case left(phone,2) when '07' then o.network<>'orange' when '05' then o.network<>'mtn' when '01' then o.network<>'moov' else false end);
end $function$
;
