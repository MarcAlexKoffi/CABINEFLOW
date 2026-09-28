-- IzyTel WC6 — périmètre Manager strict par zone
-- Objectifs :
-- 1) un Manager ne lit que les commandes, Agents, conversations, demandes et remboursements de ses zones ;
-- 2) l'Admin garde une vue globale ;
-- 3) les files Firestore legacy peuvent être filtrées à partir des order_id autorisés ;
-- 4) les actions Support / échec / création de remboursement sont autorisées au Manager uniquement dans son périmètre.

create or replace function private.izytel_wc6_manager_zone_ids(p_manager_uid text)
returns text[]
language sql
stable
security definer
set search_path = ''
as $function$
  select coalesce(array_agg(z.id order by z.id), array[]::text[])
  from public.territory_zones z
  where z.is_active = true
    and z.manager_id = btrim(coalesce(p_manager_uid, ''));
$function$;

create or replace function private.izytel_wc6_manager_can_access_agent(
  p_manager_uid text,
  p_agent_id text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.phase5_agent_capacities agent_row
    where agent_row.agent_id = btrim(coalesce(p_agent_id, ''))
      and exists (
        select 1
        from unnest(coalesce(agent_row.zone_ids, array[]::text[])) agent_zone(id)
        join public.territory_zones z on z.id = agent_zone.id
        where z.is_active = true
          and z.manager_id = btrim(coalesce(p_manager_uid, ''))
      )
  );
$function$;

create or replace function private.izytel_wc6_can_manage_order(p_order_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select public.is_izytel_firebase_jwt()
    and (
      private.is_izytel_finance_admin()
      or exists (
        select 1
        from public.phase4_assignment_orders o
        where o.order_id = btrim(coalesce(p_order_id, ''))
          and private.izytel_wc5_manager_owns_zone(
            o.zone_id,
            (select auth.jwt()->>'sub')
          )
      )
    );
$function$;


-- Garde serveur pour une affectation manuelle faite par un Manager : la
-- commande et l'Agent doivent appartenir au même périmètre territorial du
-- Manager courant. L'Admin conserve son accès global.
create or replace function public.izytel_wc6_manager_assignment_allowed(
  p_order_id text,
  p_agent_id text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select public.is_izytel_firebase_jwt()
    and (
      private.is_izytel_finance_admin()
      or exists (
        select 1
        from public.phase4_assignment_orders o
        join public.phase5_agent_capacities a
          on a.agent_id = btrim(coalesce(p_agent_id, ''))
        where o.order_id = btrim(coalesce(p_order_id, ''))
          and private.izytel_wc5_manager_owns_zone(
            o.zone_id,
            (select auth.jwt()->>'sub')
          )
          and o.zone_id = any(coalesce(a.zone_ids, array[]::text[]))
      )
    );
$function$;

-- IDs de commandes visibles par le staff courant. Utilisé côté Flutter pour
-- filtrer les rares files legacy Firestore qui existent avant la synchro Phase 4.
create or replace function public.izytel_wc6_visible_legacy_order_ids()
returns table(order_id text)
language sql
stable
security definer
set search_path = ''
as $function$
  select distinct scoped.order_id
  from (
    select o.order_id, o.zone_id
    from public.phase4_assignment_orders o
    union all
    select c.order_id, c.zone_id
    from public.customer_order_contexts c
  ) scoped
  where public.is_izytel_firebase_jwt()
    and scoped.order_id is not null
    and (
      private.is_izytel_finance_admin()
      or private.izytel_wc5_manager_owns_zone(
        scoped.zone_id,
        (select auth.jwt()->>'sub')
      )
    );
$function$;

-- Les Managers ne voient que les Agents rattachés à au moins une de leurs zones.
drop policy if exists "phase5 capacity own or staff read" on public.phase5_agent_capacities;
drop policy if exists "phase5 capacity territorial read" on public.phase5_agent_capacities;
create policy "phase5 capacity territorial read"
on public.phase5_agent_capacities
for select
to authenticated
using (
  (select public.is_izytel_firebase_jwt())
  and (
    agent_id = (select auth.jwt()->>'sub')
    or (select private.is_izytel_finance_admin())
    or (
      private.izytel_current_staff_role() in ('manager', 'supervisor')
      and private.izytel_wc6_manager_can_access_agent(
        (select auth.jwt()->>'sub'),
        agent_id
      )
    )
  )
);

-- Support et remboursements deviennent eux aussi zonés.
alter table public.support_requests
  add column if not exists zone_id text references public.territory_zones(id) on delete set null;
alter table public.refunds
  add column if not exists zone_id text references public.territory_zones(id) on delete set null;

update public.support_requests s
set zone_id = coalesce(
  (select o.zone_id from public.phase4_assignment_orders o where o.order_id = s.order_id limit 1),
  (select c.zone_id from public.customer_order_contexts c where c.order_id = s.order_id order by c.updated_at desc limit 1),
  private.izytel_wc5_fallback_zone_id()
)
where s.zone_id is null;

update public.refunds r
set zone_id = coalesce(
  (select o.zone_id from public.phase4_assignment_orders o where o.order_id = r.order_id limit 1),
  (select c.zone_id from public.customer_order_contexts c where c.order_id = r.order_id order by c.updated_at desc limit 1),
  private.izytel_wc5_fallback_zone_id()
)
where r.zone_id is null;

create index if not exists support_requests_zone_status_idx
  on public.support_requests(zone_id, status, updated_at desc);
create index if not exists refunds_zone_status_idx
  on public.refunds(zone_id, status, updated_at desc);

drop policy if exists "support customer or staff read" on public.support_requests;
drop policy if exists "support customer or territorial staff read" on public.support_requests;
create policy "support customer or territorial staff read"
on public.support_requests
for select
to anon, authenticated
using (
  public.is_izytel_firebase_jwt()
  and (
    customer_auth_uid = (select auth.jwt()->>'sub')
    or (select private.is_izytel_finance_admin())
    or private.izytel_wc5_manager_owns_zone(
      support_requests.zone_id,
      (select auth.jwt()->>'sub')
    )
  )
);

drop policy if exists "refund staff read" on public.refunds;
drop policy if exists "refund territorial staff read" on public.refunds;
create policy "refund territorial staff read"
on public.refunds
for select
to anon, authenticated
using (
  public.is_izytel_firebase_jwt()
  and (
    (select private.is_izytel_finance_admin())
    or private.izytel_wc5_manager_owns_zone(
      refunds.zone_id,
      (select auth.jwt()->>'sub')
    )
  )
);

-- Prise en charge Support : Admin global, Manager de la zone uniquement.
create or replace function public.izytel_take_support_request(p_request_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
  v_request public.support_requests;
begin
  select * into v_request
  from public.support_requests
  where id = btrim(p_request_id)
  for update;
  if not found then raise exception 'SUPPORT_REQUEST_NOT_FOUND'; end if;
  if not private.is_izytel_finance_admin()
     and not private.izytel_wc5_manager_owns_zone(v_request.zone_id, v_uid) then
    raise exception 'MANAGER_ZONE_REQUIRED' using errcode = '42501';
  end if;

  update public.support_requests
  set status = 'inProgress', assigned_to = v_uid, assigned_to_name = v_name,
      in_progress_at = coalesce(in_progress_at, now()), updated_at = now()
  where id = v_request.id and status = 'new';
  if not found then raise exception 'SUPPORT_TRANSITION_INVALID'; end if;
end;
$function$;

create or replace function public.izytel_resolve_support_request(
  p_request_id text,
  p_resolution_note text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
  v_note text := btrim(coalesce(p_resolution_note, ''));
  v_request public.support_requests;
begin
  if char_length(v_note) < 3 or char_length(v_note) > 1000 then
    raise exception 'RESOLUTION_NOTE_INVALID';
  end if;
  select * into v_request
  from public.support_requests
  where id = btrim(p_request_id)
  for update;
  if not found then raise exception 'SUPPORT_REQUEST_NOT_FOUND'; end if;
  if not private.is_izytel_finance_admin()
     and not private.izytel_wc5_manager_owns_zone(v_request.zone_id, v_uid) then
    raise exception 'MANAGER_ZONE_REQUIRED' using errcode = '42501';
  end if;

  update public.support_requests
  set status = 'resolved', resolution_note = v_note, resolved_at = now(),
      resolved_by = v_uid, resolved_by_name = v_name, updated_at = now()
  where id = v_request.id and status = 'inProgress';
  if not found then raise exception 'SUPPORT_TRANSITION_INVALID'; end if;
end;
$function$;

-- La création du dossier de remboursement fait partie de l'analyse Manager.
-- L'approbation et le paiement effectif restent Admin dans les RPC existants.
create or replace function public.izytel_create_refund(
  p_order_id text,
  p_order_reference text,
  p_origin text,
  p_support_request_id text,
  p_amount bigint,
  p_reason text,
  p_reason_note text
)
returns public.refunds
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
  v_order public.phase4_assignment_orders;
  v_support public.support_requests;
  v_support_id text := nullif(btrim(coalesce(p_support_request_id, '')), '');
  v_support_type text := '';
  v_support_description text := '';
  v_result public.refunds;
begin
  if p_origin not in ('supportRequest', 'failedOrder', 'manual') then
    raise exception 'REFUND_ORIGIN_INVALID';
  end if;
  if p_reason not in ('serviceNotReceived','transactionFailed','wrongAmount','wrongNumber','duplicatePayment','cancellation','paymentIssue','other') then
    raise exception 'REFUND_REASON_INVALID';
  end if;
  if char_length(btrim(coalesce(p_reason_note, ''))) > 500
     or (p_reason = 'other' and char_length(btrim(coalesce(p_reason_note, ''))) < 3) then
    raise exception 'REFUND_REASON_NOTE_INVALID';
  end if;

  select * into v_order
  from public.phase4_assignment_orders
  where order_id = btrim(p_order_id)
  for update;

  if not found or upper(v_order.order_reference) <> upper(btrim(p_order_reference)) then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  if not private.is_izytel_finance_admin()
     and not private.izytel_wc5_manager_owns_zone(v_order.zone_id, v_uid) then
    raise exception 'MANAGER_ZONE_REQUIRED' using errcode = '42501';
  end if;
  if v_order.payment_status <> 'confirmed' then
    raise exception 'CONFIRMED_WAVE_PAYMENT_REQUIRED';
  end if;
  if p_amount <= 0 or p_amount > v_order.amount then
    raise exception 'REFUND_AMOUNT_INVALID';
  end if;
  if v_order.order_status in ('refundPending', 'refunded') then
    raise exception 'REFUND_STATE_ALREADY_ACTIVE';
  end if;
  if exists (select 1 from public.refunds where order_id = v_order.order_id) then
    raise exception 'REFUND_ALREADY_EXISTS';
  end if;

  if p_origin = 'supportRequest' then
    if v_support_id is null then raise exception 'SUPPORT_REQUEST_REQUIRED'; end if;
    select * into v_support
    from public.support_requests
    where id = v_support_id and order_id = v_order.order_id
    limit 1;
    if not found or v_support.status not in ('new', 'inProgress', 'resolved') then
      raise exception 'SUPPORT_REQUEST_INVALID';
    end if;
    v_support_type := v_support.type;
    v_support_description := v_support.description;
  elsif p_origin = 'failedOrder' then
    if v_order.order_status <> 'failed' then
      raise exception 'FAILED_ORDER_REQUIRED';
    end if;
    v_support_id := null;
    v_support_type := 'transactionFailed';
    v_support_description := coalesce(v_order.observation, 'Commande échouée');
  else
    v_support_id := null;
  end if;

  insert into public.refunds (
    order_id, order_reference, origin, support_request_id,
    support_request_type, support_request_description,
    customer_auth_uid, client_name, client_whatsapp_phone,
    original_amount, amount, reason, reason_note, payment_channel,
    original_payment_reference, status, order_status_before_refund,
    requested_at, requested_by, requested_by_name, zone_id, updated_at
  ) values (
    v_order.order_id,
    v_order.order_reference,
    p_origin,
    v_support_id,
    v_support_type,
    v_support_description,
    v_order.customer_auth_uid,
    v_order.client_name,
    v_order.client_whatsapp_phone,
    v_order.amount,
    p_amount,
    p_reason,
    btrim(coalesce(p_reason_note, '')),
    'wave',
    v_order.payment_reference,
    'pendingApproval',
    v_order.order_status,
    now(),
    v_uid,
    v_name,
    v_order.zone_id,
    now()
  ) returning * into v_result;

  update public.phase4_assignment_orders
  set order_status = 'refundPending', updated_at = now()
  where order_id = v_order.order_id;

  return v_result;
end;
$function$;



-- Toute nouvelle demande Support / remboursement hérite automatiquement de la
-- zone canonique de la commande. Cela évite les dossiers orphelins et garantit
-- le routage territorial dès l'insertion.
create or replace function private.izytel_wc6_fill_case_zone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.zone_id is null and nullif(btrim(coalesce(new.order_id, '')), '') is not null then
    new.zone_id := coalesce(
      (select o.zone_id from public.phase4_assignment_orders o where o.order_id = new.order_id limit 1),
      (select c.zone_id from public.customer_order_contexts c where c.order_id = new.order_id order by c.updated_at desc limit 1),
      private.izytel_wc5_fallback_zone_id()
    );
  end if;
  return new;
end;
$function$;

drop trigger if exists wc6_support_fill_zone on public.support_requests;
create trigger wc6_support_fill_zone
before insert or update of order_id, zone_id on public.support_requests
for each row execute function private.izytel_wc6_fill_case_zone();

drop trigger if exists wc6_refund_fill_zone on public.refunds;
create trigger wc6_refund_fill_zone
before insert or update of order_id, zone_id on public.refunds
for each row execute function private.izytel_wc6_fill_case_zone();

-- Après résolution, la notification est interne IzyTel. Le Manager de la zone
-- peut notifier puis clôturer le dossier ; l'Admin conserve le périmètre global.
create or replace function public.izytel_mark_support_customer_notified(p_request_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
  v_request public.support_requests;
begin
  select * into v_request
  from public.support_requests
  where id = btrim(p_request_id)
  for update;
  if not found then raise exception 'SUPPORT_REQUEST_NOT_FOUND'; end if;
  if not private.is_izytel_finance_admin()
     and not private.izytel_wc5_manager_owns_zone(v_request.zone_id, v_uid) then
    raise exception 'MANAGER_ZONE_REQUIRED' using errcode = '42501';
  end if;

  update public.support_requests
  set customer_notified_at = now(), customer_notified_by = v_uid,
      customer_notified_by_name = v_name, notification_channel = 'izytel',
      updated_at = now()
  where id = v_request.id
    and status in ('resolved','closed')
    and customer_notified_at is null;
  if not found then raise exception 'SUPPORT_NOTIFICATION_INVALID'; end if;
end;
$function$;

create or replace function public.izytel_close_support_request(p_request_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
  v_request public.support_requests;
begin
  select * into v_request
  from public.support_requests
  where id = btrim(p_request_id)
  for update;
  if not found then raise exception 'SUPPORT_REQUEST_NOT_FOUND'; end if;
  if not private.is_izytel_finance_admin()
     and not private.izytel_wc5_manager_owns_zone(v_request.zone_id, v_uid) then
    raise exception 'MANAGER_ZONE_REQUIRED' using errcode = '42501';
  end if;

  update public.support_requests
  set status = 'closed', closed_at = now(), closed_by = v_uid,
      closed_by_name = v_name, updated_at = now()
  where id = v_request.id
    and status = 'resolved'
    and customer_notified_at is not null;
  if not found then raise exception 'SUPPORT_CLOSE_INVALID'; end if;
end;
$function$;

revoke all on function public.izytel_wc6_visible_legacy_order_ids() from public, anon;
grant execute on function public.izytel_wc6_visible_legacy_order_ids() to authenticated;
revoke all on function public.izytel_wc6_manager_assignment_allowed(text,text) from public, anon;
grant execute on function public.izytel_wc6_manager_assignment_allowed(text,text) to authenticated;
revoke all on function private.izytel_wc6_manager_zone_ids(text) from public, anon;
revoke all on function private.izytel_wc6_manager_can_access_agent(text,text) from public, anon;
revoke all on function private.izytel_wc6_can_manage_order(text) from public, anon;
