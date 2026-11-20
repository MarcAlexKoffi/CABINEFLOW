-- Reopen only ACTION_DIAL after an explicit no-execution confirmation.
-- The execution remains uncertain; no payment, completion or new grant occurs.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
do $$begin
  if to_regprocedure('private.ussd_prepare_before_execution(text,uuid,integer,jsonb,text)') is null
    or to_regprocedure('private.izytel_assert_execution(text)') is null
    or not exists(select 1 from pg_constraint where conname='ussd_maxit_requires_association') then
    raise exception 'EXCLUSIVE_EXECUTION_REQUIRED';
  end if;
end $$;
create or replace function private.ussd_prepare(p_order_id text,p_rule_id uuid,p_version integer,p_context jsonb,p_request_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.phase4_assignment_orders; e private.izytel_order_executions; result jsonb;
begin
  perform pg_advisory_xact_lock(9261031);
  select * into o from public.phase4_assignment_orders where order_id=p_order_id for update;
  perform private.izytel_assert_execution(p_order_id);
  select * into e from private.izytel_order_executions
    where order_id=p_order_id and assignment_version=o.assignment_version;
  if o.assigned_agent_id is not null and e.state='uncertain' then
    result:=private.ussd_resolve_before_execution(p_order_id);
    if result->>'status' is distinct from 'available'
      or not exists(select 1 from public.ussd_execution_logs l
        where l.order_id=p_order_id and l.actor_uid=e.agent_id and l.generated_at>=e.authorized_at) then
      return jsonb_build_object('status','unavailable','reason','execution_uncertain');
    end if;
    if result->>'code'='APP:MAXIT' then
      if exists(select 1 from public.ussd_execution_logs l
        left join public.ussd_rule_versions rv on rv.rule_id=l.rule_id and rv.version=l.rule_version
        where l.order_id=p_order_id and l.actor_uid=e.agent_id and l.generated_at>=e.authorized_at
          and private.ussd_normalize_template(rv.snapshot->>'ussd_template') is distinct from 'APP:MAXIT') then
        return jsonb_build_object('status','unavailable','reason','execution_uncertain');
      end if;
    else
      -- Reopening a changed rule/binding or a former app command needs review.
      if exists(select 1 from public.ussd_execution_logs l
        left join public.ussd_rule_versions rv on rv.rule_id=l.rule_id and rv.version=l.rule_version
        where l.order_id=p_order_id and l.actor_uid=e.agent_id and l.generated_at>=e.authorized_at
          and (rv.rule_id is null or private.ussd_normalize_template(rv.snapshot->>'ussd_template')='APP:MAXIT'
            or l.rule_id is distinct from (result->'rule'->>'id')::uuid
            or l.rule_version is distinct from (result->'rule'->>'version')::integer
            or l.offer_id is distinct from (result->'context'->>'offer_id')
            or l.binding_version is distinct from (result->'context'->>'binding_version')::integer)) then
        return jsonb_build_object('status','unavailable','reason','execution_uncertain');
      end if;
      if p_context->'_ussd_not_executed_confirmed' is distinct from 'true'::jsonb then
        return jsonb_build_object('status','unavailable','reason','ussd_retry_confirmation_required');
      end if;
    end if;
  end if;
  result:=private.ussd_prepare_before_execution(p_order_id,p_rule_id,p_version,
    p_context-'_ussd_not_executed_confirmed',p_request_id);
  if result->>'status'='available' then
    update private.izytel_order_executions set state='uncertain'
      where order_id=p_order_id and assignment_version=o.assignment_version;
  end if;
  return result;
end $$;
commit;
