-- Already applied to Supabase project zrxeztxaxnzxevjuhzcc on 2026-09-03.
-- Contract: only the first Manager-selected assignment is manual.
-- After an Agent refusal, the next eligible candidate is an automatic reassignment.

create or replace function private.phase4_enforce_assignment_order_update()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_is_staff boolean := private.is_izytel_phase4_staff();
  v_reason text;
  v_plan public.phase4_assignment_plans%rowtype;
  v_refused text[];
  v_next_agent text;
  v_next_name text;
  v_history_id uuid;
begin
  if v_is_staff then
    new.updated_at := now();
    return new;
  end if;

  if not public.is_izytel_firebase_jwt() or v_uid is null or btrim(v_uid) = '' then
    raise exception 'AUTH_REQUIRED';
  end if;
  if old.assigned_agent_id is distinct from v_uid then
    raise exception 'ASSIGNMENT_OWNER_REQUIRED';
  end if;

  new.order_id := old.order_id;
  new.order_reference := old.order_reference;
  new.network := old.network;
  new.amount := old.amount;
  new.firebase_created_at := old.firebase_created_at;
  new.paid_at := old.paid_at;
  new.created_at := old.created_at;
  new.assigned_by_uid := old.assigned_by_uid;

  if old.assignment_state = 'assigned' and new.assignment_state = 'accepted' then
    new.assigned_agent_id := old.assigned_agent_id;
    new.assigned_agent_name := old.assigned_agent_name;
    new.assignment_mode := old.assignment_mode;
    new.assigned_at := old.assigned_at;
    new.last_refusal_reason := old.last_refusal_reason;
    new.last_refused_at := old.last_refused_at;
    new.last_refused_agent_id := old.last_refused_agent_id;
    new.firebase_assignment_synced_at := old.firebase_assignment_synced_at;
    new.firebase_handoff_at := null;
    new.updated_at := now();

    select h.id into v_history_id
    from public.phase4_assignment_history h
    where h.order_id = old.order_id and h.agent_id = v_uid and h.status = 'assigned'
    order by h.assigned_at desc limit 1;
    if v_history_id is not null then
      update public.phase4_assignment_history
      set status = 'accepted', accepted_at = now(), updated_at = now()
      where id = v_history_id;
    end if;
    return new;
  end if;

  if old.assignment_state = 'assigned' and new.assignment_state = 'refused' then
    v_reason := btrim(coalesce(new.last_refusal_reason, ''));
    if char_length(v_reason) < 3 or char_length(v_reason) > 500 then
      raise exception 'INVALID_REFUSAL_REASON';
    end if;

    select * into v_plan from public.phase4_assignment_plans
    where order_id = old.order_id for update;
    if not found then raise exception 'ASSIGNMENT_PLAN_MISSING'; end if;

    v_refused := coalesce(v_plan.refused_agent_ids, '{}'::text[]);
    if not (v_uid = any(v_refused)) then v_refused := array_append(v_refused, v_uid); end if;
    update public.phase4_assignment_plans
    set refused_agent_ids = v_refused, updated_at = now()
    where order_id = old.order_id;

    select h.id into v_history_id
    from public.phase4_assignment_history h
    where h.order_id = old.order_id and h.agent_id = v_uid and h.status in ('assigned','accepted')
    order by h.assigned_at desc limit 1;
    if v_history_id is not null then
      update public.phase4_assignment_history
      set status='refused', refused_at=now(), refusal_reason=v_reason,
          accepted_at=null, handed_off_at=null, updated_at=now()
      where id=v_history_id;
    end if;

    select candidate_id into v_next_agent
    from unnest(v_plan.candidate_agent_ids) with ordinality as c(candidate_id, ord)
    where not (candidate_id = any(v_refused))
    order by ord limit 1;

    new.last_refusal_reason := v_reason;
    new.last_refused_at := now();
    new.last_refused_agent_id := v_uid;
    new.firebase_assignment_synced_at := null;
    new.firebase_handoff_at := null;

    if v_next_agent is null then
      new.assignment_state := 'manual_required';
      new.assigned_agent_id := null;
      new.assigned_agent_name := null;
      new.assignment_mode := null;
      new.assigned_at := null;
    else
      v_next_name := nullif(btrim(coalesce(v_plan.candidate_names ->> v_next_agent, '')), '');
      if v_next_name is null then v_next_name := 'Agent'; end if;

      update public.phase4_assignment_plans
      set plan_mode = 'automatic', updated_at = now()
      where order_id = old.order_id;

      new.assignment_state := 'assigned';
      new.assigned_agent_id := v_next_agent;
      new.assigned_agent_name := v_next_name;
      new.assignment_mode := 'automatic';
      new.assigned_at := now();
      insert into public.phase4_assignment_history (
        order_id, order_reference, agent_id, agent_name, mode, status, assigned_by_uid, assigned_at
      ) values (
        old.order_id, old.order_reference, v_next_agent, v_next_name,
        'automatic', 'assigned', old.assigned_by_uid, now()
      );
    end if;
    new.updated_at := now();
    return new;
  end if;

  if old.assignment_state = 'accepted' and new.assignment_state = 'handed_off' then
    new.assigned_agent_id := old.assigned_agent_id;
    new.assigned_agent_name := old.assigned_agent_name;
    new.assignment_mode := old.assignment_mode;
    new.assigned_at := old.assigned_at;
    new.last_refusal_reason := old.last_refusal_reason;
    new.last_refused_at := old.last_refused_at;
    new.last_refused_agent_id := old.last_refused_agent_id;
    new.firebase_assignment_synced_at := coalesce(old.firebase_assignment_synced_at, now());
    new.firebase_handoff_at := now();
    new.updated_at := now();
    select h.id into v_history_id
    from public.phase4_assignment_history h
    where h.order_id=old.order_id and h.agent_id=v_uid and h.status='accepted'
    order by h.assigned_at desc limit 1;
    if v_history_id is not null then
      update public.phase4_assignment_history
      set status='handed_off', handed_off_at=now(), updated_at=now()
      where id=v_history_id;
    end if;
    return new;
  end if;

  if old.assignment_state='accepted' and old.firebase_handoff_at is null
     and new.assignment_state='assigned' then
    new.assigned_agent_id := old.assigned_agent_id;
    new.assigned_agent_name := old.assigned_agent_name;
    new.assignment_mode := old.assignment_mode;
    new.assigned_at := old.assigned_at;
    new.last_refusal_reason := old.last_refusal_reason;
    new.last_refused_at := old.last_refused_at;
    new.last_refused_agent_id := old.last_refused_agent_id;
    new.firebase_assignment_synced_at := old.firebase_assignment_synced_at;
    new.firebase_handoff_at := null;
    new.updated_at := now();
    select h.id into v_history_id
    from public.phase4_assignment_history h
    where h.order_id=old.order_id and h.agent_id=v_uid and h.status='accepted'
    order by h.assigned_at desc limit 1;
    if v_history_id is not null then
      update public.phase4_assignment_history
      set status='assigned', accepted_at=null, handed_off_at=null, updated_at=now()
      where id=v_history_id;
    end if;
    return new;
  end if;

  raise exception 'INVALID_AGENT_ASSIGNMENT_TRANSITION';
end;
$function$;
