-- IzyTel Phase 3 - correctif terrain des preuves Agent.
--
-- La politique RLS private.is_phase5_proof_owner autorise deja une preuve pour
-- une commande acceptee/handed_off dont le statut est inProgress/onHold.
-- Le trigger historique exigeait encore assignment_state = 'handed_off', ce qui
-- rejetait les nouvelles commandes canoniques Phase 4 en etat 'accepted'.

create or replace function private.phase5_validate_order_proof()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_reference text;
  v_agent_id text;
  v_state text;
  v_order_status text;
  v_legacy_unresolved boolean;
begin
  if not public.is_izytel_firebase_jwt()
     or v_uid is null
     or btrim(v_uid) = '' then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;

  select
    o.order_reference,
    o.assigned_agent_id,
    o.assignment_state,
    o.order_status,
    o.legacy_state_unresolved
  into
    v_reference,
    v_agent_id,
    v_state,
    v_order_status,
    v_legacy_unresolved
  from public.phase4_assignment_orders o
  where o.order_id = new.order_id;

  if v_reference is null then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;

  if v_agent_id is distinct from v_uid
     or new.agent_id is distinct from v_uid then
    raise exception 'ORDER_NOT_OWNED' using errcode = '42501';
  end if;

  if coalesce(v_legacy_unresolved, false) then
    raise exception 'LEGACY_STATUS_REQUIRES_RECONCILIATION'
      using errcode = 'P0001';
  end if;

  if v_state not in ('accepted', 'handed_off') then
    raise exception 'ORDER_NOT_ACCEPTED' using errcode = 'P0001';
  end if;

  if v_order_status not in ('inProgress', 'onHold') then
    raise exception 'ORDER_NOT_IN_PROGRESS' using errcode = 'P0001';
  end if;

  if new.order_reference is distinct from v_reference then
    raise exception 'ORDER_REFERENCE_MISMATCH' using errcode = 'P0001';
  end if;

  if new.storage_path <> v_uid || '/' || new.order_id || '/proof.jpg' then
    raise exception 'INVALID_PROOF_PATH' using errcode = 'P0001';
  end if;

  if tg_op = 'INSERT' then
    new.created_at := coalesce(new.created_at, now());
  else
    new.created_at := old.created_at;
  end if;

  new.updated_at := now();
  return new;
end;
$function$;
