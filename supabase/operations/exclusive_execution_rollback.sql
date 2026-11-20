-- Operator only, during maintenance, after backup and explicit authorization.
-- No DROP TABLE, data restore, financial write, or automatic release.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
lock table public.phase4_assignment_orders in share row exclusive mode;
do $$begin
  if exists(select 1 from private.izytel_order_executions where state in ('authorized','uncertain')) then
    raise exception 'RECONCILE_EXECUTIONS_BEFORE_ROLLBACK';end if;
end $$;
drop trigger aab_izytel_exclusive_order_guard on public.phase4_assignment_orders;
drop trigger zzzz_izytel_execution_lifecycle on public.phase4_assignment_orders;
do $$declare b record;a jsonb;begin
  for b in select * from private.izytel_execution_schema_backup where object_key<>'order_select_policy' loop
    execute b.definition;
    execute 'revoke all on function '||b.object_key||' from public,anon,authenticated,service_role';
    for a in select * from jsonb_array_elements(coalesce(b.acl,'[]'::jsonb)) loop
      execute 'grant execute on function '||b.object_key||' to '||
        case when a->>'grantee'='PUBLIC' then 'public' else quote_ident(a->>'grantee') end||
        case when (a->>'grantable')::boolean then ' with grant option' else '' end;
    end loop;
  end loop;
  execute 'drop policy "phase4 scoped staff assigned agent or cabiniste reads orders" on public.phase4_assignment_orders';
  execute (select definition from private.izytel_execution_schema_backup where object_key='order_select_policy');
end $$;
revoke all on function public.izytel_begin_order_execution(text,bigint,text),
  public.izytel_read_orders(text,text),public.izytel_return_order_to_queue(text,text,text),
  public.izytel_verify_order_not_executed(text,text,bigint),private.izytel_begin_order_execution(text,bigint,text),
  private.izytel_read_orders(text,text),private.izytel_return_order_to_queue(text,text,text),
  private.izytel_verify_order_not_executed(text,text,bigint) from public,anon,authenticated;
-- Audit, verification records and schema snapshots are retained for reconciliation.
commit;
