-- WC15 — Audit technique / performance hardening
-- Safe, additive changes only. No business data is rewritten.

-- Agent history is operational data used by the mobile history/activity pages.
-- Realtime replaces the former 3-second polling loops.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'phase4_assignment_history'
  ) then
    alter publication supabase_realtime
      add table public.phase4_assignment_history;
  end if;
end
$$;

-- finance_change_feed contains only a revision counter + timestamp. It is a
-- non-sensitive signal used to invalidate local finance caches. Firebase
-- third-party Auth can execute as anon in PostgREST, therefore access is based
-- on the validated IzyTel Firebase JWT rather than the PostgreSQL role name.
alter policy "finance change feed staff read"
  on public.finance_change_feed
  to anon, authenticated
  using ((select public.is_izytel_firebase_jwt()));

-- Missing FK indexes reported by the Supabase performance advisor.
create index if not exists compensation_accounts_last_entry_id_idx
  on public.compensation_accounts(last_entry_id)
  where last_entry_id is not null;

create index if not exists compensation_accounts_last_payout_id_idx
  on public.compensation_accounts(last_payout_id)
  where last_payout_id is not null;

create index if not exists compensation_entries_source_entry_id_idx
  on public.compensation_entries(source_entry_id)
  where source_entry_id is not null;

create index if not exists partner_success_finalizations_compensation_entry_id_idx
  on public.partner_success_finalizations(compensation_entry_id)
  where compensation_entry_id is not null;

create index if not exists phase4_assignment_orders_last_refused_cabiniste_id_idx
  on public.phase4_assignment_orders(last_refused_cabiniste_id)
  where last_refused_cabiniste_id is not null;

-- Global chronological reads are used by Finance/Admin screens. Existing
-- indexes are mostly agent/supplier-prefixed and cannot efficiently satisfy
-- the unfiltered ORDER BY queries used by the staff dashboards.
create index if not exists phase5_commissions_earned_at_idx
  on public.phase5_commissions(earned_at desc, order_id desc);

create index if not exists phase5_commission_payouts_paid_at_idx
  on public.phase5_commission_payouts(paid_at desc, id desc);

create index if not exists phase5_network_movements_occurred_at_idx
  on public.phase5_network_movements(occurred_at desc, id desc);

create index if not exists phase5_agent_recharges_occurred_at_idx
  on public.phase5_agent_recharges(occurred_at desc, id desc);

create index if not exists phase5_supplier_payments_paid_at_idx
  on public.phase5_supplier_payments(paid_at desc, id desc);

create index if not exists phase4_assignment_orders_updated_at_idx
  on public.phase4_assignment_orders(updated_at desc, order_id);

create index if not exists phase4_assignment_history_refused_agent_idx
  on public.phase4_assignment_history(agent_id, refused_at desc)
  where status = 'refused';
