-- Restore only the pre-reopen preparation guard; no row or grant is changed.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
CREATE OR REPLACE FUNCTION private.ussd_prepare(p_order_id text, p_rule_id uuid, p_version integer, p_context jsonb, p_request_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare o public.phase4_assignment_orders; result jsonb;
begin
  -- Same lock order as the original USSD configuration path.
  perform pg_advisory_xact_lock(9261031);
  select * into o from public.phase4_assignment_orders where order_id=p_order_id for update;
  perform private.izytel_assert_execution(p_order_id);
  if o.assigned_agent_id is not null and exists(select 1 from private.izytel_order_executions
    where order_id=p_order_id and assignment_version=o.assignment_version and state='uncertain') then
    return jsonb_build_object('status','unavailable','reason','execution_uncertain');end if;
  result:=private.ussd_prepare_before_execution(p_order_id,p_rule_id,p_version,p_context,p_request_id);
  if result->>'status'='available' then
    update private.izytel_order_executions set state='uncertain'
      where order_id=p_order_id and assignment_version=o.assignment_version;
  end if;
  return result;
end $function$;
commit;
