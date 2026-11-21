-- Release Agent admission after a terminal order, preserving execution evidence.
-- No order, execution, capacity, payment, refund or notification rows are changed.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $migration$
declare
  definition text;
  previous_predicate text;
  replacement_predicate text;
begin
  -- Admission must use the business status as well as the execution record.
  -- A failed/refunded order can retain telecom uncertainty for Manager review
  -- without reserving the Agent's next job.
  definition := pg_get_functiondef('private.izytel_exclusive_order_guard()'::regprocedure);
  previous_predicate := $old$and ((o.assignment_state in ('accepted','handed_off') and o.order_status in ('paidReady','inProgress','onHold'))
          or exists(select 1 from private.izytel_order_executions e where e.order_id=o.order_id
            and e.assignment_version=o.assignment_version and e.state='uncertain'))$old$;
  replacement_predicate := $new$and o.order_status in ('paidReady','inProgress','onHold')
        and (o.assignment_state in ('accepted','handed_off')
          or exists(select 1 from private.izytel_order_executions e where e.order_id=o.order_id
            and e.assignment_version=o.assignment_version and e.state='uncertain'))$new$;
  if position(previous_predicate in definition) = 0 then
    raise exception 'UNEXPECTED_EXCLUSIVE_ORDER_GUARD_DEFINITION';
  end if;
  execute replace(definition, previous_predicate, replacement_predicate);

  -- Fix the start gate too: acceptance alone must not lead to another lock.
  definition := pg_get_functiondef('private.izytel_begin_order_execution(text,bigint,text)'::regprocedure);
  previous_predicate := $old$select 1 from private.izytel_order_executions x where x.agent_id=u
    and x.order_id<>o.order_id and x.state in ('authorized','uncertain')$old$;
  replacement_predicate := $new$select 1 from private.izytel_order_executions x
    join public.phase4_assignment_orders active_order
      on active_order.order_id=x.order_id
      and active_order.assignment_version=x.assignment_version
      and active_order.assigned_agent_id=x.agent_id
    where x.agent_id=u and x.order_id<>o.order_id
      and x.state in ('authorized','uncertain')
      and active_order.order_status in ('paidReady','inProgress','onHold')$new$;
  if position(previous_predicate in definition) = 0 then
    raise exception 'UNEXPECTED_BEGIN_ORDER_EXECUTION_DEFINITION';
  end if;
  execute replace(definition, previous_predicate, replacement_predicate);
end;
$migration$;

commit;
