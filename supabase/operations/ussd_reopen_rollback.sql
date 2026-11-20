-- Restore the Max it-only reopen guard, preserving every row and grant.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
CREATE OR REPLACE FUNCTION private.ussd_prepare(p_order_id text, p_rule_id uuid, p_version integer, p_context jsonb, p_request_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare o public.phase4_assignment_orders; e private.izytel_order_executions; result jsonb;
begin
  perform pg_advisory_xact_lock(9261031);
  select * into o from public.phase4_assignment_orders where order_id=p_order_id for update;
  perform private.izytel_assert_execution(p_order_id);
  select * into e from private.izytel_order_executions
    where order_id=p_order_id and assignment_version=o.assignment_version;
  if o.assigned_agent_id is not null and e.state='uncertain' then
    result:=private.ussd_resolve_before_execution(p_order_id);
    -- The current authorized command and every attempt in this assignment's
    -- execution must be Max it. A rule edit cannot unlock an uncertain USSD.
    if result->>'status' is distinct from 'available'
      or result->>'code' is distinct from 'APP:MAXIT'
      or not exists(select 1 from public.ussd_execution_logs l
        where l.order_id=p_order_id and l.actor_uid=e.agent_id and l.generated_at>=e.authorized_at)
      or exists(select 1 from public.ussd_execution_logs l
        left join public.ussd_rule_versions rv on rv.rule_id=l.rule_id and rv.version=l.rule_version
        where l.order_id=p_order_id and l.actor_uid=e.agent_id and l.generated_at>=e.authorized_at
          and private.ussd_normalize_template(rv.snapshot->>'ussd_template') is distinct from 'APP:MAXIT') then
      return jsonb_build_object('status','unavailable','reason','execution_uncertain');
    end if;
  end if;
  -- Reuse fresh context/version, rate limit, idempotency, audit and short-lease
  -- checks. A reopened app gets an audit row, never another execution grant.
  result:=private.ussd_prepare_before_execution(p_order_id,p_rule_id,p_version,p_context,p_request_id);
  if result->>'status'='available' then
    update private.izytel_order_executions set state='uncertain'
      where order_id=p_order_id and assignment_version=o.assignment_version;
  end if;
  return result;
end $function$;
commit;
