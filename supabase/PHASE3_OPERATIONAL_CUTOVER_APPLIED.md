# Phase 3 operational cutover - backend state

Already applied to Supabase project IzyTel (`zrxeztxaxnzxevjuhzcc`):

- `20260911224156 phase3_supabase_operational_cutover`
- `20260912162341 phase3_assignment_eligibility_rpc`
- `phase3_assignment_eligibility_rpc_security` (public wrapper hardened to SECURITY INVOKER)

Do not re-run these migrations manually on production.

The cutover makes Supabase canonical after a paid order is synchronized into Phase 4. Firestore remains only for pre-sync/customer legacy data and historical enrichment. No Firestore Rules deployment is required by this cutover.
