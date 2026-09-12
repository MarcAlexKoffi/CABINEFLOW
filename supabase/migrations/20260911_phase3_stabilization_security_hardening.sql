-- IzyTel Phase 3 - stabilisation technique
-- Security hardening without changing business roles or UI contracts.

-- ---------------------------------------------------------------------------
-- 1. Notification device RPCs: keep public API names, move privileged writes
--    to private SECURITY DEFINER implementations.
-- ---------------------------------------------------------------------------
create or replace function private.izytel_register_notification_device_internal(
  p_token text,
  p_platform text default 'android'
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_token text := btrim(coalesce(p_token, ''));
  v_platform text := lower(btrim(coalesce(p_platform, 'android')));
  v_id uuid;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if char_length(v_token) < 32 or char_length(v_token) > 4096 then
    raise exception 'INVALID_FCM_TOKEN';
  end if;
  if v_platform not in ('android', 'ios', 'web', 'windows', 'macos', 'linux', 'fuchsia') then
    v_platform := 'android';
  end if;

  insert into public.izytel_notification_devices (
    firebase_uid, fcm_token, platform, is_active, last_seen_at, updated_at
  ) values (
    v_uid, v_token, v_platform, true, now(), now()
  )
  on conflict (fcm_token) do update set
    firebase_uid = excluded.firebase_uid,
    platform = excluded.platform,
    is_active = true,
    last_seen_at = now(),
    updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function private.izytel_deactivate_notification_device_internal(
  p_token text
)
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_token text := btrim(coalesce(p_token, ''));
  v_count integer;
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if v_token = '' then return false; end if;

  update public.izytel_notification_devices
  set is_active = false, updated_at = now()
  where firebase_uid = v_uid and fcm_token = v_token and is_active = true;
  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

revoke all on function private.izytel_register_notification_device_internal(text, text) from public;
revoke all on function private.izytel_deactivate_notification_device_internal(text) from public;
grant execute on function private.izytel_register_notification_device_internal(text, text) to anon, authenticated;
grant execute on function private.izytel_deactivate_notification_device_internal(text) to anon, authenticated;

create or replace function public.izytel_register_notification_device(
  p_token text,
  p_platform text default 'android'
)
returns uuid
language sql
set search_path to ''
as $$
  select private.izytel_register_notification_device_internal(p_token, p_platform);
$$;

create or replace function public.izytel_deactivate_notification_device(
  p_token text
)
returns boolean
language sql
set search_path to ''
as $$
  select private.izytel_deactivate_notification_device_internal(p_token);
$$;

revoke all on function public.izytel_register_notification_device(text, text) from public;
revoke all on function public.izytel_deactivate_notification_device(text) from public;
grant execute on function public.izytel_register_notification_device(text, text) to anon, authenticated, service_role;
grant execute on function public.izytel_deactivate_notification_device(text) to anon, authenticated, service_role;

-- Notification tables remain inaccessible directly to clients. The explicit
-- deny policies make the isolation visible to RLS tooling as defense in depth.
drop policy if exists "deny direct notification devices" on public.izytel_notification_devices;
create policy "deny direct notification devices"
on public.izytel_notification_devices
for all
to anon, authenticated
using (false)
with check (false);

drop policy if exists "deny direct notification outbox" on public.izytel_notification_outbox;
create policy "deny direct notification outbox"
on public.izytel_notification_outbox
for all
to anon, authenticated
using (false)
with check (false);

revoke all on table public.izytel_notification_devices from anon, authenticated;
revoke all on table public.izytel_notification_outbox from anon, authenticated;
revoke all on table public.izytel_staff_access from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Align Data API grants with the Flutter access model.
--    RLS is still the authorization layer; GRANT only exposes required verbs.
-- ---------------------------------------------------------------------------
revoke all on table public.agent_personal_profiles from anon, authenticated;
grant select, insert, update on table public.agent_personal_profiles to anon, authenticated;

revoke all on table public.agent_issues from anon, authenticated;
grant select, insert, update on table public.agent_issues to anon, authenticated;

revoke all on table public.finance_suppliers from anon, authenticated;
grant select, insert, update on table public.finance_suppliers to anon, authenticated;

-- Phase 4 public RPCs are SECURITY INVOKER and intentionally rely on these
-- table privileges plus RLS. Keep only the verbs they actually need.
revoke all on table public.phase4_assignment_orders from anon, authenticated;
grant select, insert, update on table public.phase4_assignment_orders to anon, authenticated;

revoke all on table public.phase4_assignment_plans from anon, authenticated;
grant select, insert, update on table public.phase4_assignment_plans to anon, authenticated;

revoke all on table public.phase4_assignment_history from anon, authenticated;
grant select, insert, update on table public.phase4_assignment_history to anon, authenticated;

-- Phase 5 writes go through guarded RPCs, except proof metadata and sync cursor.
revoke all on table public.phase5_agent_capacities from anon, authenticated;
grant select on table public.phase5_agent_capacities to anon, authenticated;

revoke all on table public.phase5_agent_recharges from anon, authenticated;
grant select on table public.phase5_agent_recharges to anon, authenticated;

revoke all on table public.phase5_commission_accounts from anon, authenticated;
grant select on table public.phase5_commission_accounts to anon, authenticated;

revoke all on table public.phase5_commission_payouts from anon, authenticated;
grant select on table public.phase5_commission_payouts to anon, authenticated;

revoke all on table public.phase5_commissions from anon, authenticated;
grant select on table public.phase5_commissions to anon, authenticated;

revoke all on table public.phase5_ledger_events from anon, authenticated;
grant select on table public.phase5_ledger_events to anon, authenticated;

revoke all on table public.phase5_network_movements from anon, authenticated;
grant select on table public.phase5_network_movements to anon, authenticated;

revoke all on table public.phase5_order_payments from anon, authenticated;
grant select on table public.phase5_order_payments to anon, authenticated;

revoke all on table public.phase5_success_finalizations from anon, authenticated;
grant select on table public.phase5_success_finalizations to anon, authenticated;

revoke all on table public.phase5_supplier_accounts from anon, authenticated;
grant select on table public.phase5_supplier_accounts to anon, authenticated;

revoke all on table public.phase5_supplier_payments from anon, authenticated;
grant select on table public.phase5_supplier_payments to anon, authenticated;

revoke all on table public.phase5_order_proofs from anon, authenticated;
grant select, insert, update on table public.phase5_order_proofs to anon, authenticated;

revoke all on table public.phase5_sync_state from anon, authenticated;
grant select, insert, update on table public.phase5_sync_state to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Row-independent helper calls are wrapped in SELECT so PostgreSQL can use
--    initPlans instead of reevaluating them for every row.
-- ---------------------------------------------------------------------------
alter policy "staff updates issue status"
on public.agent_issues
using ((select private.is_izytel_issue_staff()))
with check (
  (select private.is_izytel_issue_staff())
  and status in ('in_progress', 'resolved', 'cancelled')
);

alter policy "finance staff reads suppliers"
on public.finance_suppliers
using ((select private.is_izytel_finance_staff()));

alter policy "finance staff updates suppliers"
on public.finance_suppliers
using ((select private.is_izytel_finance_staff()))
with check ((select private.is_izytel_finance_staff()));

alter policy "phase5 order payments staff read"
on public.phase5_order_payments
using ((select private.is_izytel_finance_staff()));

alter policy "phase5 supplier accounts staff read"
on public.phase5_supplier_accounts
using ((select private.is_izytel_finance_staff()));

alter policy "phase5 supplier payments staff read"
on public.phase5_supplier_payments
using ((select private.is_izytel_finance_staff()));
