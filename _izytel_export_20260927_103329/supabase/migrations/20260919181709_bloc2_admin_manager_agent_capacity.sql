-- IzyTel - Bloc 2 / capacites Agent depuis la fiche detaillee
-- Etend le RPC existant aux Admins sans retirer le scope Manager/Supervisor.

create or replace function private.izytel_manager_adjust_agent_capacity(
  p_agent_id text,
  p_network text,
  p_target_capacity bigint,
  p_reason text default null::text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_name text;
  v_role text := private.izytel_current_staff_role();
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'),'')),'');
  v_actor_name text;
begin
  if private.is_izytel_finance_admin() then
    null;
  elsif v_role in ('manager','supervisor')
        and private.izytel_manager_can_access_agent(p_agent_id) then
    null;
  else
    raise exception 'STAFF_AGENT_SCOPE_REQUIRED' using errcode='42501';
  end if;

  select a.agent_name
    into v_name
  from public.phase5_agent_capacities a
  where a.agent_id=btrim(p_agent_id);

  if v_name is null then
    raise exception 'AGENT_NOT_FOUND';
  end if;

  select coalesce(
    nullif(btrim(s.display_name),''),
    case when v_role='admin' then 'Administrateur' else 'Manager' end
  )
    into v_actor_name
  from public.izytel_staff_access s
  where s.firebase_uid=v_uid
    and s.is_active=true
  limit 1;

  return private.phase5_adjust_capacity(
    btrim(p_agent_id),
    v_name,
    p_network,
    p_target_capacity,
    coalesce(
      v_actor_name,
      case when v_role='admin' then 'Administrateur' else 'Manager' end
    ),
    case when v_role='admin' then 'admin' else 'manager' end,
    p_reason
  );
end;
$function$;

comment on function private.izytel_manager_adjust_agent_capacity(text,text,bigint,text)
is 'Allows scoped Manager/Supervisor or finance Admin to adjust an Agent capacity through the canonical Phase 5 ledger.';
