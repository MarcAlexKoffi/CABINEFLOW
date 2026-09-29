-- WC14 - Round-robin automatique autoritatif cote Supabase.
--
-- Le client continue d'envoyer une liste classee, mais le serveur impose la
-- rotation sur la derniere affectation reelle afin qu'un lot de commandes ne
-- puisse plus etre attribue au premier agent avec un snapshot stale.
-- Un verrou transactionnel par zone serialise les affectations automatiques
-- concurrentes et garantit que la commande suivante voit l'affectation
-- precedente avant de choisir son agent.

create or replace function public.phase4_assign_ranked(
  p_order_id text,
  p_candidate_agent_ids text[],
  p_candidate_names jsonb,
  p_mode text default 'automatic'
)
returns public.phase4_assignment_orders
language plpgsql
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_order public.phase4_assignment_orders%rowtype;
  v_plan public.phase4_assignment_plans%rowtype;
  v_candidate text;
  v_name text;
  v_previous_agent text;
  v_previous_mode text;
begin
  if not private.is_izytel_phase4_staff() then
    raise exception 'STAFF_REQUIRED';
  end if;
  if p_mode not in ('automatic','manual') then
    raise exception 'INVALID_ASSIGNMENT_MODE';
  end if;

  select * into v_order
  from public.phase4_assignment_orders
  where order_id=p_order_id
  for update;
  if not found then raise exception 'ORDER_NOT_SYNCED'; end if;

  -- Une seule selection automatique a la fois par zone. Deux confirmations
  -- simultanees ne peuvent donc plus choisir toutes les deux le meme premier
  -- agent avant que l'historique de rotation soit mis a jour.
  if p_mode='automatic' then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'izytel:auto-assignment:' || coalesce(v_order.zone_id,''),
        0
      )
    );
  end if;

  if v_order.order_status <> 'paidReady' then return v_order; end if;
  if v_order.assignment_state in ('accepted','handed_off','closed') then
    return v_order;
  end if;

  select * into v_plan
  from public.phase4_assignment_plans
  where order_id=p_order_id
  for update;
  if not found then
    insert into public.phase4_assignment_plans(order_id)
    values(p_order_id)
    returning * into v_plan;
  end if;

  update public.phase4_assignment_plans
  set candidate_agent_ids=coalesce(p_candidate_agent_ids,'{}'::text[]),
      candidate_names=coalesce(p_candidate_names,'{}'::jsonb),
      plan_mode=p_mode,
      updated_at=now()
  where order_id=p_order_id
  returning * into v_plan;

  if v_order.assignment_state='assigned'
     and v_order.assignment_mode=p_mode
     and v_order.assigned_agent_id=any(coalesce(v_plan.candidate_agent_ids,'{}'::text[]))
     and not(v_order.assigned_agent_id=any(coalesce(v_plan.refused_agent_ids,'{}'::text[])))
     and private.phase3_agent_is_eligible(v_order.assigned_agent_id,p_order_id) then
    return v_order;
  end if;

  v_previous_agent:=v_order.assigned_agent_id;
  v_previous_mode:=v_order.assignment_mode;

  select c.candidate_id into v_candidate
  from unnest(coalesce(v_plan.candidate_agent_ids,'{}'::text[]))
       with ordinality as c(candidate_id,ord)
  left join lateral (
    select max(h.assigned_at) as last_assigned_at
    from public.phase4_assignment_history h
    where h.agent_id=c.candidate_id
  ) usage on true
  where btrim(c.candidate_id)<>''
    and not(c.candidate_id=any(coalesce(v_plan.refused_agent_ids,'{}'::text[])))
    and private.phase3_agent_is_eligible(c.candidate_id,p_order_id)
  order by
    case when p_mode='automatic' then usage.last_assigned_at end asc nulls first,
    c.ord
  limit 1;

  if v_previous_agent is not null and (
    v_candidate is null
    or v_candidate is distinct from v_previous_agent
    or v_previous_mode is distinct from p_mode
  ) then
    update public.phase4_assignment_history h
    set status='reassigned',updated_at=now()
    where h.id=(
      select h2.id
      from public.phase4_assignment_history h2
      where h2.order_id=p_order_id
        and h2.agent_id=v_previous_agent
        and h2.status='assigned'
      order by h2.assigned_at desc
      limit 1
    );
  end if;

  if v_candidate is null then
    update public.phase4_assignment_orders
    set assignment_state=case
          when cardinality(v_plan.candidate_agent_ids)>0
           and cardinality(v_plan.refused_agent_ids)>0
          then 'manual_required'
          else 'waiting'
        end,
        assigned_agent_id=null,
        assigned_agent_name=null,
        assigned_by_uid=v_uid,
        assignment_mode=null,
        assigned_at=null,
        firebase_assignment_synced_at=null,
        firebase_handoff_at=null,
        updated_at=now()
    where order_id=p_order_id
    returning * into v_order;
    return v_order;
  end if;

  v_name:=nullif(btrim(coalesce(v_plan.candidate_names->>v_candidate,'')),'');
  if v_name is null then
    select nullif(btrim(c.agent_name),'') into v_name
    from public.phase5_agent_capacities c
    where c.agent_id=v_candidate;
  end if;
  if v_name is null or char_length(v_name)<2 then v_name:='Agent'; end if;

  update public.phase4_assignment_orders
  set assignment_state='assigned',
      assigned_agent_id=v_candidate,
      assigned_agent_name=v_name,
      assigned_by_uid=v_uid,
      assignment_mode=p_mode,
      assigned_at=now(),
      firebase_assignment_synced_at=null,
      firebase_handoff_at=null,
      legacy_state_unresolved=false,
      updated_at=now()
  where order_id=p_order_id
  returning * into v_order;

  insert into public.phase4_assignment_history(
    order_id,order_reference,agent_id,agent_name,mode,status,
    assigned_by_uid,assigned_at
  ) values(
    v_order.order_id,v_order.order_reference,v_candidate,v_name,
    p_mode,'assigned',v_uid,v_order.assigned_at
  );
  return v_order;
end;
$function$;
