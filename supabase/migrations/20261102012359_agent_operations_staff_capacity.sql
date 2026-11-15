-- Repair managed Agent updates and reserve balances for staff operations.
-- Does not widen RLS, change roles or rewrite any account/financial data.
CREATE OR REPLACE FUNCTION private.phase3_admin_update_agent_operations(p_agent_id text, p_agent_name text, p_is_active boolean, p_zone_ids text[], p_authorized_networks text[], p_active_networks text[], p_daily_transaction_limit bigint, p_max_transactions_per_day integer, p_orange bigint, p_mtn bigint, p_moov bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id text := btrim(coalesce(p_agent_id,''));
  v_name text := nullif(btrim(coalesce(p_agent_name,'')),'');
  v_zone_ids text[] := coalesce(p_zone_ids,'{}'::text[]);
  v_authorized text[] := coalesce(p_authorized_networks,'{}'::text[]);
  v_active text[] := coalesce(p_active_networks,'{}'::text[]);
  v_row public.phase5_agent_capacities;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
  end if;
  if v_id='' or v_name is null then raise exception 'INVALID_AGENT'; end if;
  if not (v_authorized <@ array['orange','mtn','moov']::text[]) then raise exception 'INVALID_NETWORKS'; end if;
  if not (v_active <@ v_authorized) then raise exception 'ACTIVE_NETWORK_NOT_AUTHORIZED'; end if;
  if p_daily_transaction_limit < 0 or p_max_transactions_per_day < 0 then raise exception 'INVALID_LIMITS'; end if;

  select * into v_row from public.phase5_agent_capacities where agent_id=v_id for update;
  if found then
    -- Existing managed accounts must use UPDATE: BEFORE INSERT guards run even
    -- when an INSERT ... ON CONFLICT ultimately takes its update branch.
    -- Access changes still require the administration gateway first.
    update public.phase5_agent_capacities
    set agent_name=v_name,
        agent_code=case when btrim(agent_code)='' then 'AG-'||upper(substr(v_id,1,6)) else agent_code end,
        zone_ids=v_zone_ids,
        is_active=p_is_active,
        availability=case when p_is_active then availability else 'unavailable' end,
        authorized_networks=v_authorized,
        active_networks=case when p_is_active then v_active else '{}'::text[] end,
        daily_transaction_limit=p_daily_transaction_limit,
        max_transactions_per_day=p_max_transactions_per_day,
        initialized_from='supabase',updated_at=now()
    where agent_id=v_id;
  else
  insert into public.phase5_agent_capacities(
    agent_id,agent_name,orange_capacity,mtn_capacity,moov_capacity,
    initialized_from,agent_code,zone_ids,is_active,availability,authorized_networks,
    active_networks,daily_transaction_limit,max_transactions_per_day,updated_at
  ) values (
    v_id,v_name,0,0,0,'supabase','AG-'||upper(substr(v_id,1,6)),v_zone_ids,p_is_active,
    'unavailable',
    v_authorized,case when p_is_active then v_active else '{}'::text[] end,
    p_daily_transaction_limit,p_max_transactions_per_day,now()
  );
  end if;

  perform private.phase5_adjust_capacity(v_id,v_name,'orange',p_orange,'Administration','admin','Admin operational update');
  perform private.phase5_adjust_capacity(v_id,v_name,'mtn',p_mtn,'Administration','admin','Admin operational update');
  perform private.phase5_adjust_capacity(v_id,v_name,'moov',p_moov,'Administration','admin','Admin operational update');

  select * into v_row from public.phase5_agent_capacities where agent_id=v_id;
  return to_jsonb(v_row);
end;
$function$;

CREATE OR REPLACE FUNCTION private.phase3_update_own_agent_operations(p_availability text, p_active_networks text[], p_orange bigint DEFAULT NULL, p_mtn bigint DEFAULT NULL, p_moov bigint DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'),'')), '');
  v_row public.phase5_agent_capacities;
  v_active text[] := coalesce(p_active_networks,'{}'::text[]);
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode='42501';
  end if;
  if p_availability not in ('available','unavailable') then
    raise exception 'INVALID_AVAILABILITY';
  end if;

  select * into v_row from public.phase5_agent_capacities
  where agent_id=v_uid for update;
  if not found then raise exception 'CAPACITY_NOT_INITIALIZED'; end if;
  if not (v_active <@ v_row.authorized_networks) then
    raise exception 'NETWORK_NOT_AUTHORIZED';
  end if;

  if not v_row.is_active then raise exception 'AGENT_INACTIVE' using errcode='42501'; end if;
  if (p_orange is not null and p_orange is distinct from v_row.orange_capacity)
     or (p_mtn is not null and p_mtn is distinct from v_row.mtn_capacity)
     or (p_moov is not null and p_moov is distinct from v_row.moov_capacity) then
    raise exception 'CAPACITY_STAFF_REQUIRED' using errcode='42501';
  end if;

  update public.phase5_agent_capacities
  set availability=p_availability,
      active_networks=v_active,
      last_seen_at=now(),
      initialized_from='supabase',
      updated_at=now()
  where agent_id=v_uid
  returning * into v_row;

  return to_jsonb(v_row);
end;
$function$;

CREATE OR REPLACE FUNCTION public.phase3_update_own_agent_operations(p_availability text, p_active_networks text[], p_orange bigint DEFAULT NULL, p_mtn bigint DEFAULT NULL, p_moov bigint DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
  select private.phase3_update_own_agent_operations(p_availability,p_active_networks,p_orange,p_mtn,p_moov);
$function$;


-- Block the generic adjustment RPC as well as the Agent settings RPC.
CREATE OR REPLACE FUNCTION private.phase5_adjust_capacity(p_agent_id text, p_agent_name text, p_network text, p_target_capacity bigint, p_actor_name text, p_actor_role text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_capacity public.phase5_agent_capacities;
  v_before bigint;
  v_amount bigint;
  v_direction text;
  v_movement_id uuid;
  v_role text;
  v_staff_role text := private.izytel_current_staff_role();
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode='42501';
  end if;

  if private.is_izytel_finance_admin() then
    null;
  elsif v_staff_role in ('manager','supervisor')
        and private.izytel_manager_can_access_agent(p_agent_id) then
    null;
  else
    raise exception 'CAPACITY_STAFF_REQUIRED' using errcode='42501';
  end if;

  if p_network not in ('orange','mtn','moov') then
    raise exception 'INVALID_NETWORK';
  end if;
  if p_target_capacity not between 0 and 100000000 then
    raise exception 'INVALID_CAPACITY';
  end if;
  if p_reason is not null and char_length(p_reason)>1000 then
    raise exception 'INVALID_REASON';
  end if;

  select * into v_capacity
  from public.phase5_agent_capacities
  where agent_id=btrim(p_agent_id)
  for update;
  if not found then raise exception 'CAPACITY_NOT_INITIALIZED'; end if;

  v_before := case p_network
    when 'orange' then v_capacity.orange_capacity
    when 'mtn' then v_capacity.mtn_capacity
    else v_capacity.moov_capacity
  end;

  if v_before=p_target_capacity then
    return jsonb_build_object(
      'agent_id',v_capacity.agent_id,
      'network',p_network,
      'capacity_before',v_before,
      'capacity_after',p_target_capacity,
      'changed',false
    );
  end if;

  v_amount := abs(p_target_capacity-v_before);
  v_direction := case when p_target_capacity>v_before then 'incoming' else 'outgoing' end;
  v_role := case
    when v_staff_role in ('manager','supervisor') then 'manager'
    else 'admin'
  end;

  update public.phase5_agent_capacities
  set agent_name=coalesce(nullif(btrim(p_agent_name),''),agent_name),
      orange_capacity=case when p_network='orange' then p_target_capacity else orange_capacity end,
      mtn_capacity=case when p_network='mtn' then p_target_capacity else mtn_capacity end,
      moov_capacity=case when p_network='moov' then p_target_capacity else moov_capacity end,
      initialized_from='supabase',
      updated_at=now()
  where agent_id=btrim(p_agent_id);

  insert into public.phase5_network_movements(
    source_key,network,direction,movement_type,amount,capacity_before,capacity_after,
    agent_id,agent_name,created_by_uid,created_by_name,created_by_role,occurred_at
  ) values(
    'adjustment:'||gen_random_uuid()::text,
    p_network,
    v_direction,
    'manualAdjustment',
    v_amount,
    v_before,
    p_target_capacity,
    btrim(p_agent_id),
    coalesce(nullif(btrim(p_agent_name),''),v_capacity.agent_name),
    v_uid,
    nullif(btrim(p_actor_name),''),
    v_role,
    now()
  ) returning id into v_movement_id;

  insert into public.phase5_ledger_events(
    source_collection,source_id,event_kind,agent_id,agent_name,network,amount,occurred_at,payload
  ) values(
    'phase5_network_movements',
    v_movement_id::text,
    'capacity_movement',
    btrim(p_agent_id),
    coalesce(nullif(btrim(p_agent_name),''),v_capacity.agent_name),
    p_network,
    v_amount,
    now(),
    jsonb_build_object(
      'direction',v_direction,
      'type','manualAdjustment',
      'reason',p_reason,
      'capacityBefore',v_before,
      'capacityAfter',p_target_capacity,
      'actorRole',v_role
    )
  ) on conflict do nothing;

  return jsonb_build_object(
    'agent_id',btrim(p_agent_id),
    'network',p_network,
    'capacity_before',v_before,
    'capacity_after',p_target_capacity,
    'movement_id',v_movement_id,
    'changed',true
  );
end;
$function$;
CREATE OR REPLACE FUNCTION public.phase5_adjust_capacity(p_agent_id text, p_agent_name text, p_network text, p_target_capacity bigint, p_actor_name text, p_actor_role text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$ select private.phase5_adjust_capacity(p_agent_id,p_agent_name,p_network,p_target_capacity,p_actor_name,p_actor_role,p_reason); $function$;

NOTIFY pgrst, 'reload schema';


