-- IzyTel WC6 - Gestion operationnelle des Agents par leur Manager de zone
-- Le Manager peut modifier uniquement quotas, reseaux autorises et capacites.
-- Identite, statut global et rattachement territorial restent hors de ce RPC.

create or replace function private.izytel_manager_update_agent_operations(
  p_agent_id text,
  p_authorized_networks text[],
  p_daily_transaction_limit bigint,
  p_max_transactions_per_day integer,
  p_orange bigint,
  p_mtn bigint,
  p_moov bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_role text := private.izytel_current_staff_role();
  v_agent_id text := btrim(coalesce(p_agent_id, ''));
  v_authorized text[] := coalesce(p_authorized_networks, '{}'::text[]);
  v_active text[] := '{}'::text[];
  v_actor_name text;
  v_row public.phase5_agent_capacities;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  if v_role not in ('manager', 'supervisor')
     or not private.izytel_manager_can_access_agent(v_agent_id) then
    raise exception 'MANAGER_AGENT_SCOPE_REQUIRED' using errcode = '42501';
  end if;

  if v_agent_id = '' then
    raise exception 'AGENT_REQUIRED' using errcode = '22023';
  end if;

  if exists (
    select 1
    from unnest(v_authorized) as network_name
    where network_name not in ('orange', 'mtn', 'moov')
  ) then
    raise exception 'INVALID_NETWORKS' using errcode = '22023';
  end if;

  select coalesce(array_agg(distinct network_name order by network_name), '{}'::text[])
    into v_authorized
  from unnest(v_authorized) as network_name;

  if p_daily_transaction_limit < 0
     or p_max_transactions_per_day < 0 then
    raise exception 'INVALID_LIMITS' using errcode = '22023';
  end if;

  if p_orange not between 0 and 100000000
     or p_mtn not between 0 and 100000000
     or p_moov not between 0 and 100000000 then
    raise exception 'INVALID_CAPACITY' using errcode = '22023';
  end if;

  select *
    into v_row
  from public.phase5_agent_capacities
  where agent_id = v_agent_id
  for update;

  if not found then
    raise exception 'AGENT_NOT_FOUND';
  end if;

  select coalesce(
           nullif(btrim(staff.display_name), ''),
           'Manager IzyTel'
         )
    into v_actor_name
  from public.izytel_staff_access staff
  where staff.firebase_uid = v_uid
    and staff.is_active = true
  limit 1;

  select coalesce(array_agg(active_network order by active_network), '{}'::text[])
    into v_active
  from unnest(coalesce(v_row.active_networks, '{}'::text[])) as active_network
  where active_network = any(v_authorized);

  update public.phase5_agent_capacities
  set authorized_networks = v_authorized,
      active_networks = v_active,
      daily_transaction_limit = p_daily_transaction_limit,
      max_transactions_per_day = p_max_transactions_per_day,
      initialized_from = 'supabase',
      updated_at = now()
  where agent_id = v_agent_id;

  perform private.phase5_adjust_capacity(
    v_agent_id,
    v_row.agent_name,
    'orange',
    p_orange,
    coalesce(v_actor_name, 'Manager IzyTel'),
    'manager',
    'Ajustement operationnel par Manager'
  );

  perform private.phase5_adjust_capacity(
    v_agent_id,
    v_row.agent_name,
    'mtn',
    p_mtn,
    coalesce(v_actor_name, 'Manager IzyTel'),
    'manager',
    'Ajustement operationnel par Manager'
  );

  perform private.phase5_adjust_capacity(
    v_agent_id,
    v_row.agent_name,
    'moov',
    p_moov,
    coalesce(v_actor_name, 'Manager IzyTel'),
    'manager',
    'Ajustement operationnel par Manager'
  );

  select *
    into v_row
  from public.phase5_agent_capacities
  where agent_id = v_agent_id;

  return to_jsonb(v_row);
end;
$function$;

create or replace function public.izytel_manager_update_agent_operations(
  p_agent_id text,
  p_authorized_networks text[],
  p_daily_transaction_limit bigint,
  p_max_transactions_per_day integer,
  p_orange bigint,
  p_mtn bigint,
  p_moov bigint
)
returns jsonb
language sql
set search_path = ''
as $function$
  select private.izytel_manager_update_agent_operations(
    p_agent_id,
    p_authorized_networks,
    p_daily_transaction_limit,
    p_max_transactions_per_day,
    p_orange,
    p_mtn,
    p_moov
  );
$function$;

revoke all on function private.izytel_manager_update_agent_operations(
  text,text[],bigint,integer,bigint,bigint,bigint
) from public;
grant execute on function private.izytel_manager_update_agent_operations(
  text,text[],bigint,integer,bigint,bigint,bigint
) to anon, authenticated, service_role;

revoke all on function public.izytel_manager_update_agent_operations(
  text,text[],bigint,integer,bigint,bigint,bigint
) from public;
grant execute on function public.izytel_manager_update_agent_operations(
  text,text[],bigint,integer,bigint,bigint,bigint
) to anon, authenticated, service_role;

notify pgrst, 'reload schema';
