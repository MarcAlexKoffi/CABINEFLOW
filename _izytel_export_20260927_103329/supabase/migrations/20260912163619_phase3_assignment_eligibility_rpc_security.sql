-- IzyTel Phase 3 - public RPC remains SECURITY INVOKER.
-- The private eligibility helper keeps privileged table access, while this
-- exposed wrapper always validates the current staff role first.

create or replace function public.phase3_agent_is_eligible_for_order(
  p_agent_id text,
  p_order_id text
)
returns boolean
language plpgsql
security invoker
set search_path to ''
as $$
begin
  if not private.is_izytel_phase4_staff() then
    raise exception 'STAFF_REQUIRED' using errcode='42501';
  end if;
  return private.phase3_agent_is_eligible(
    btrim(coalesce(p_agent_id,'')),
    btrim(coalesce(p_order_id,''))
  );
end;
$$;

revoke all on function public.phase3_agent_is_eligible_for_order(text,text) from public;
grant execute on function public.phase3_agent_is_eligible_for_order(text,text) to anon, authenticated;
