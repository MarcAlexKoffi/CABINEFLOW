-- Les flux Phase 4/5 et remboursements doivent egalement rafraichir BO-5.
create or replace function private.izytel_finance_phase5_touch()
returns trigger language plpgsql security definer set search_path=''
as $function$
begin
  update public.finance_change_feed set revision=revision+1,changed_at=now() where id=1;
  return null;
end;$function$;

do $do$
declare t text;
begin
  foreach t in array array[
    'phase4_assignment_orders','phase5_agent_capacities','phase5_agent_recharges',
    'phase5_commission_accounts','phase5_commission_payouts','phase5_commissions',
    'phase5_ledger_events','phase5_network_movements','phase5_order_payments',
    'phase5_success_finalizations','phase5_supplier_accounts','phase5_supplier_payments','refunds'
  ] loop
    execute format('drop trigger if exists bo5_touch_%I on public.%I', t, t);
    execute format('create trigger bo5_touch_%I after insert or update or delete on public.%I for each statement execute function private.izytel_finance_phase5_touch()', t, t);
  end loop;
end;$do$;
