-- Operator action only, AFTER explicit authorization, backup and a green recipe.
-- This file is deliberately outside migrations: db push cannot activate the queue.
begin;
set local lock_timeout='5s';
set local statement_timeout='20s';
lock table public.phase4_assignment_orders in share row exclusive mode;
do $$
declare v_job bigint; v_command text; v_schedule text;
begin
  if not exists(select 1 from pg_extension where extname='pg_cron') then
    raise exception 'pg_cron must be reviewed and installed separately before activation';
  end if;
  if not exists(select 1 from private.izytel_shared_queue_settings where singleton) then
    raise exception 'Shared queue migration is missing';
  end if;
  select jobid,command,schedule into v_job,v_command,v_schedule
  from cron.job where jobname='izytel-acceptance-delay-monitor';
  if v_job is not null and (v_command<>'select private.izytel_detect_order_delays(200);' or v_schedule<>'* * * * *') then
    raise exception 'Existing SLA job differs: inspect it instead of overwriting it';
  end if;
  if v_job is null then
    perform cron.schedule('izytel-acceptance-delay-monitor','* * * * *','select private.izytel_detect_order_delays(200);');
  else
    perform cron.alter_job(v_job,active:=true);
  end if;
  update private.izytel_shared_queue_settings
  set enabled=true,activated_at=coalesce(activated_at,clock_timestamp()) where singleton;
end;
$$;
commit;
