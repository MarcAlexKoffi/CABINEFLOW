-- WC13 - Firebase Third-party Auth / Phase 4 role compatibility.
--
-- The hosted Supabase gateway validates the Firebase token. IzyTel then applies
-- its own Firebase JWT + staff/territory checks in the policy expressions.
-- Some existing Firebase users can still execute PostgREST as `anon` when
-- their token does not carry the optional `role=authenticated` custom claim.
-- WC6 had restricted these three policies to `authenticated`, preventing the
-- canonical order synchronization/assignment flow even with a valid IzyTel
-- Firebase UID. Keep all existing USING/WITH CHECK checks and only restore the
-- role coverage already used by the other IzyTel policies.

alter policy "phase4 scoped staff assigned agent or cabiniste reads orders"
  on public.phase4_assignment_orders
  to anon, authenticated;

alter policy "phase4 staff inserts zoned orders"
  on public.phase4_assignment_orders
  to anon, authenticated;

alter policy "phase4 staff updates zoned orders"
  on public.phase4_assignment_orders
  to anon, authenticated;
