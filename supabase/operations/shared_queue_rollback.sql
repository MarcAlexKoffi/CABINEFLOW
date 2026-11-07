-- Operator action only, AFTER explicit authorization and a Manager drain.
-- Keep all orders, alerts, history, financial writes and the existing outbox job.
begin;
set local lock_timeout='5s';
set local statement_timeout='20s';
lock table public.phase4_assignment_orders in share row exclusive mode;
do $$
declare v_job bigint;
begin
  if exists(select 1 from public.phase4_assignment_orders
    where assignment_route='shared' and order_status in ('paidReady','inProgress','onHold')) then
    raise exception 'Drain or finalize shared orders through authorized Manager actions before rollback';
  end if;
  -- A new activation gets a new boundary. Historical records are never relabeled.
  update private.izytel_shared_queue_settings set enabled=false,activated_at=null where singleton;
  select jobid into v_job from cron.job where jobname='izytel-acceptance-delay-monitor';
  if v_job is not null then perform cron.alter_job(v_job,active:=false);end if;
end;
$$;
commit;
