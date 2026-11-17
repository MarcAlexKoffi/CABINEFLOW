CREATE OR REPLACE FUNCTION private.izytel_team_member_activity_history(p_actor_type text, p_actor_id text, p_limit integer DEFAULT 25)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_type text := lower(btrim(coalesce(p_actor_type,'')));
  v_id text := btrim(coalesce(p_actor_id,''));
  v_limit integer := least(greatest(coalesce(p_limit,25),1),50);
  v_partner_id uuid;
  v_month_start timestamptz := date_trunc('month',now());
  v_next_month timestamptz := date_trunc('month',now()) + interval '1 month';
  v_result jsonb;
begin
  if not public.is_izytel_firebase_jwt() then
    raise exception 'AUTH_REQUIRED' using errcode='42501';
  end if;

  if v_id='' then
    raise exception 'ACTOR_ID_REQUIRED';
  end if;

  if v_type='agent' then
    if not private.izytel_staff_can_access_agent(v_id) then
      raise exception 'AGENT_SCOPE_DENIED' using errcode='42501';
    end if;

    select jsonb_build_object(
      'actorType','agent',
      'actorId',v_id,
      'periodKey',to_char(v_month_start,'YYYY-MM'),
      'currentMonth',jsonb_build_object(
        'processedAmount',coalesce((
          select sum(f.order_amount)
          from public.phase5_success_finalizations f
          where f.agent_id=v_id
            and f.financial_applied_at>=v_month_start
            and f.financial_applied_at<v_next_month
        ),0),
        'completedOrders',coalesce((
          select count(*)::int
          from public.phase5_success_finalizations f
          where f.agent_id=v_id
            and f.financial_applied_at>=v_month_start
            and f.financial_applied_at<v_next_month
        ),0),
        'commissionEarned',coalesce((
          select sum(c.commission_amount)
          from public.phase5_commissions c
          where c.agent_id=v_id
            and c.earned_at>=v_month_start
            and c.earned_at<v_next_month
        ),0),
        'izytelGrossGain',coalesce((
          select sum(
            coalesce(
              e.izytel_gross_gain,
              (
                private.izytel_calculate_order_economics(
                  f.network,
                  f.order_amount,
                  'izytel',
                  'agent',
                  f.agent_id,
                  null,
                  private.izytel_resolve_manager_for_zone_ids(a.zone_ids)
                )->>'izytel_gross_gain'
              )::bigint
            )
          )
          from public.phase5_success_finalizations f
          join public.phase5_agent_capacities a
            on a.agent_id=f.agent_id
          left join public.order_economics e
            on e.order_id=f.order_id
          where f.agent_id=v_id
            and f.financial_applied_at>=v_month_start
            and f.financial_applied_at<v_next_month
            and (e.order_id is null or e.reversed_at is null)
        ),0)
      ),
      'earnings',coalesce((
        select jsonb_agg(x.payload order by x.occurred_at desc)
        from (
          select
            c.earned_at as occurred_at,
            jsonb_build_object(
              'kind','commission',
              'orderId',c.order_id,
              'orderReference',c.order_reference,
              'network',c.network,
              'orderAmount',c.order_amount,
              'amount',c.commission_amount,
              'occurredAt',c.earned_at
            ) as payload
          from public.phase5_commissions c
          where c.agent_id=v_id
          order by c.earned_at desc
          limit v_limit
        ) x
      ),'[]'::jsonb),
      'payouts',coalesce((
        select jsonb_agg(x.payload order by x.occurred_at desc)
        from (
          select
            p.paid_at as occurred_at,
            jsonb_build_object(
              'kind','payout',
              'amount',p.amount,
              'channel',p.payment_channel,
              'reference',p.payment_reference,
              'note',p.note,
              'occurredAt',p.paid_at
            ) as payload
          from public.phase5_commission_payouts p
          where p.agent_id=v_id
          order by p.paid_at desc
          limit v_limit
        ) x
      ),'[]'::jsonb),
      'movements',coalesce((
        select jsonb_agg(x.payload order by x.occurred_at desc)
        from (
          select
            m.occurred_at,
            jsonb_build_object(
              'kind','capacity',
              'network',m.network,
              'direction',m.direction,
              'movementType',m.movement_type,
              'amount',m.amount,
              'capacityBefore',m.capacity_before,
              'capacityAfter',m.capacity_after,
              'orderReference',m.order_reference,
              'occurredAt',m.occurred_at
            ) as payload
          from public.phase5_network_movements m
          where m.agent_id=v_id
          order by m.occurred_at desc
          limit v_limit
        ) x
      ),'[]'::jsonb)
    ) into v_result;

  elsif v_type='cabiniste' then
    begin
      v_partner_id := v_id::uuid;
    exception when others then
      raise exception 'INVALID_CABINISTE_ID';
    end;

    if not private.izytel_staff_can_access_partner(v_partner_id) then
      raise exception 'CABINISTE_SCOPE_DENIED' using errcode='42501';
    end if;

    select jsonb_build_object(
      'actorType','cabiniste',
      'actorId',v_partner_id::text,
      'periodKey',to_char(v_month_start,'YYYY-MM'),
      'currentMonth',jsonb_build_object(
        'processedAmount',coalesce((
          select sum(f.order_amount)
          from public.partner_success_finalizations f
          where f.partner_id=v_partner_id
            and f.financial_applied_at>=v_month_start
            and f.financial_applied_at<v_next_month
        ),0),
        'completedOrders',coalesce((
          select count(*)::int
          from public.partner_success_finalizations f
          where f.partner_id=v_partner_id
            and f.financial_applied_at>=v_month_start
            and f.financial_applied_at<v_next_month
        ),0),
        'cabinisteMargin',coalesce((
          select sum(f.cabiniste_margin_amount)
          from public.partner_success_finalizations f
          where f.partner_id=v_partner_id
            and f.financial_applied_at>=v_month_start
            and f.financial_applied_at<v_next_month
        ),0),
        'settlementEarned',coalesce((
          select sum(f.cabiniste_settlement_amount)
          from public.partner_success_finalizations f
          where f.partner_id=v_partner_id
            and f.financial_applied_at>=v_month_start
            and f.financial_applied_at<v_next_month
        ),0),
        'izytelGrossGain',coalesce((
          select sum(f.izytel_gross_gain)
          from public.partner_success_finalizations f
          where f.partner_id=v_partner_id
            and f.financial_applied_at>=v_month_start
            and f.financial_applied_at<v_next_month
        ),0)
      ),
      'earnings',coalesce((
        select jsonb_agg(x.payload order by x.occurred_at desc)
        from (
          select
            e.occurred_at,
            jsonb_build_object(
              'kind','settlement',
              'entryId',e.id,
              'orderId',e.order_id,
              'orderReference',e.order_reference,
              'entryType',e.entry_type,
              'amount',e.amount,
              'metadata',e.metadata,
              'occurredAt',e.occurred_at
            ) as payload
          from public.compensation_entries e
          where e.actor_type='cabiniste'
            and e.actor_id=v_partner_id::text
          order by e.occurred_at desc
          limit v_limit
        ) x
      ),'[]'::jsonb),
      'payouts',coalesce((
        select jsonb_agg(x.payload order by x.occurred_at desc)
        from (
          select
            p.paid_at as occurred_at,
            jsonb_build_object(
              'kind','payout',
              'payoutId',p.id,
              'amount',p.amount,
              'channel',p.payment_channel,
              'reference',p.payment_reference,
              'note',p.note,
              'occurredAt',p.paid_at
            ) as payload
          from public.compensation_payouts p
          where p.actor_type='cabiniste'
            and p.actor_id=v_partner_id::text
          order by p.paid_at desc
          limit v_limit
        ) x
      ),'[]'::jsonb),
      'movements',coalesce((
        select jsonb_agg(x.payload order by x.occurred_at desc)
        from (
          select
            m.occurred_at,
            jsonb_build_object(
              'kind','capacity',
              'network',m.network,
              'direction',m.direction,
              'movementType',m.movement_type,
              'amount',m.amount,
              'capacityBefore',m.capacity_before,
              'capacityAfter',m.capacity_after,
              'orderReference',m.order_reference,
              'occurredAt',m.occurred_at
            ) as payload
          from public.partner_capacity_movements m
          where m.partner_id=v_partner_id
          order by m.occurred_at desc
          limit v_limit
        ) x
      ),'[]'::jsonb)
    ) into v_result;

  else
    raise exception 'UNSUPPORTED_ACTIVITY_HISTORY_ACTOR_TYPE';
  end if;

  return v_result;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.izytel_close_support_request(p_request_id text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  update public.support_requests
  set status = 'closed',
      closed_at = now(),
      closed_by = v_uid,
      closed_by_name = v_name,
      updated_at = now()
  where id = btrim(p_request_id)
    and status = 'resolved'
    and customer_notified_at is not null;
  if not found then raise exception 'SUPPORT_CLOSE_INVALID'; end if;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.izytel_mark_support_customer_notified(p_request_id text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED';
  end if;

  update public.support_requests
  set customer_notified_at=now(),
      customer_notified_by=v_uid,
      customer_notified_by_name=v_name,
      notification_channel='messaging',
      updated_at=now()
  where id=btrim(p_request_id)
    and status in ('resolved','closed')
    and customer_notified_at is null;

  if not found then
    raise exception 'SUPPORT_NOTIFICATION_INVALID';
  end if;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.izytel_resolve_support_request(p_request_id text, p_resolution_note text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
  v_note text := btrim(coalesce(p_resolution_note, ''));
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  if char_length(v_note) < 3 or char_length(v_note) > 1000 then
    raise exception 'RESOLUTION_NOTE_INVALID';
  end if;
  update public.support_requests
  set status = 'resolved',
      resolution_note = v_note,
      resolved_at = now(),
      resolved_by = v_uid,
      resolved_by_name = v_name,
      updated_at = now()
  where id = btrim(p_request_id) and status = 'inProgress';
  if not found then raise exception 'SUPPORT_TRANSITION_INVALID'; end if;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.izytel_take_support_request(p_request_id text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_name text := private.izytel_staff_display_name();
begin
  if not private.is_izytel_finance_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  update public.support_requests
  set status = 'inProgress',
      assigned_to = v_uid,
      assigned_to_name = v_name,
      in_progress_at = now(),
      updated_at = now()
  where id = btrim(p_request_id) and status = 'new';
  if not found then raise exception 'SUPPORT_TRANSITION_INVALID'; end if;
end;
$function$
;
drop function private.izytel_can_process_support_order(text);
