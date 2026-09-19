-- IzyTel - Bloc 2 / passe finale
-- Aligne les performances mensuelles, distingue theorique/eligible et durcit la cloture Manager.

create or replace function private.izytel_manager_compensation_preview_v2(
  p_manager_id text default null::text,
  p_period_start date default null::date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_raw jsonb;
  v_projection jsonb;
  v_thresholds jsonb;
  v_plan jsonb;
  v_ready boolean := false;
  v_theoretical_base bigint := 0;
  v_theoretical_variable_raw bigint := 0;
  v_theoretical_variable bigint := 0;
  v_theoretical_total bigint := 0;
  v_eligible_base bigint := 0;
  v_eligible_variable bigint := 0;
  v_eligible_total bigint := 0;
  v_bookable boolean := false;
begin
  v_raw := private.izytel_manager_compensation_preview(
    p_manager_id,
    p_period_start
  );

  v_projection := coalesce(v_raw->'projection','{}'::jsonb);
  v_thresholds := coalesce(v_raw->'thresholds','{}'::jsonb);
  v_plan := coalesce(v_raw->'plan','{}'::jsonb);

  v_ready := coalesce((v_thresholds->>'allMet')::boolean,false);
  v_theoretical_base := coalesce((v_projection->>'baseAmount')::bigint,0);
  v_theoretical_variable_raw := coalesce((v_projection->>'variableRawAmount')::bigint,0);
  v_theoretical_variable := coalesce((v_projection->>'variableAmount')::bigint,0);
  v_theoretical_total := coalesce((v_projection->>'projectedTotalAmount')::bigint,0);

  if v_ready then
    v_eligible_base := v_theoretical_base;
    v_eligible_variable := v_theoretical_variable;
    v_eligible_total := v_theoretical_total;
  end if;

  v_bookable :=
    coalesce((v_projection->>'bookable')::boolean,false)
    and v_ready
    and coalesce(v_plan->>'status','')='active';

  return v_raw
    || jsonb_build_object(
      'eligibility',jsonb_build_object(
        'eligible',v_ready,
        'status',case when v_ready then 'eligible' else 'not_eligible' end,
        'grossThresholdMet',coalesce((v_thresholds->>'grossThresholdMet')::boolean,false),
        'dailyOrderThresholdMet',coalesce((v_thresholds->>'dailyOrderThresholdMet')::boolean,false)
      ),
      'projection',v_projection || jsonb_build_object(
        'theoreticalBaseAmount',v_theoretical_base,
        'theoreticalVariableRawAmount',v_theoretical_variable_raw,
        'theoreticalVariableAmount',v_theoretical_variable,
        'theoreticalTotalAmount',v_theoretical_total,
        'eligibleBaseAmount',v_eligible_base,
        'eligibleVariableAmount',v_eligible_variable,
        'eligibleTotalAmount',v_eligible_total,
        'activationReady',v_ready,
        'bookable',v_bookable
      )
    );
end;
$function$;

create or replace function public.izytel_manager_compensation_preview(
  p_manager_id text default null::text,
  p_period_start date default null::date
)
returns jsonb
language sql
set search_path = ''
as $function$
  select private.izytel_manager_compensation_preview_v2(
    p_manager_id,
    p_period_start
  );
$function$;

create or replace function private.izytel_admin_close_manager_compensation_period_v2(
  p_manager_id text,
  p_period_start date
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_period_start date := date_trunc(
    'month',
    coalesce(p_period_start,current_date)::timestamp
  )::date;
  v_period_end date := (
    date_trunc('month',coalesce(p_period_start,current_date)::timestamp)
    + interval '1 month - 1 day'
  )::date;
  v_preview jsonb;
  v_plan jsonb;
  v_projection jsonb;
  v_ready boolean := false;
begin
  if not private.is_izytel_finance_admin() then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
  end if;

  if nullif(btrim(coalesce(p_manager_id,'')),'') is null then
    raise exception 'MANAGER_ID_REQUIRED';
  end if;

  if v_period_end>=current_date then
    raise exception 'MANAGER_PERIOD_NOT_CLOSED_YET';
  end if;

  v_preview := private.izytel_manager_compensation_preview_v2(
    p_manager_id,
    v_period_start
  );
  v_plan := coalesce(v_preview->'plan','{}'::jsonb);
  v_projection := coalesce(v_preview->'projection','{}'::jsonb);
  v_ready := coalesce((v_projection->>'activationReady')::boolean,false);

  if coalesce(v_plan->>'status','')<>'active' then
    raise exception 'MANAGER_COMPENSATION_PLAN_NOT_ACTIVE';
  end if;

  if not v_ready then
    raise exception 'MANAGER_COMPENSATION_THRESHOLDS_NOT_MET';
  end if;

  return private.izytel_admin_close_manager_compensation_period(
    p_manager_id,
    v_period_start
  );
end;
$function$;

create or replace function public.izytel_admin_close_manager_compensation_period(
  p_manager_id text,
  p_period_start date
)
returns jsonb
language sql
set search_path = ''
as $function$
  select private.izytel_admin_close_manager_compensation_period_v2(
    p_manager_id,
    p_period_start
  );
$function$;

create or replace function private.izytel_team_performance_snapshot_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_role text := private.izytel_current_staff_role();
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'),'')),'');
  v_zone_ids text[];
  v_period_start date := date_trunc('month',current_date)::date;
  v_period_end date := (
    date_trunc('month',current_date)::timestamp + interval '1 month - 1 day'
  )::date;
  v_base jsonb;
  v_agents jsonb := '[]'::jsonb;
  v_cabinistes jsonb := '[]'::jsonb;
  v_managers jsonb := '[]'::jsonb;
  v_summary jsonb := '{}'::jsonb;
  v_scope jsonb := '{}'::jsonb;
begin
  if not public.is_izytel_firebase_jwt()
     or (v_role is null or v_role not in ('admin','manager','supervisor')) then
    raise exception 'STAFF_REQUIRED' using errcode='42501';
  end if;

  v_base := private.izytel_team_performance_snapshot();

  if v_role='admin' then
    select coalesce(array_agg(z.id order by z.id),'{}'::text[])
      into v_zone_ids
    from public.territory_zones z
    where z.is_active=true;
  else
    v_zone_ids := private.izytel_current_manager_zone_ids();
  end if;

  with agent_success as (
    select
      f.agent_id,
      f.order_amount::bigint as order_amount,
      f.commission_amount::bigint as commission_amount,
      coalesce(
        e.manager_id,
        private.izytel_resolve_manager_for_zone_ids(a.zone_ids)
      ) as effective_manager_id,
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
            coalesce(
              e.manager_id,
              private.izytel_resolve_manager_for_zone_ids(a.zone_ids)
            )
          )->>'izytel_gross_gain'
        )::bigint
      ) as izytel_gross_gain
    from public.phase5_success_finalizations f
    join public.phase5_agent_capacities a
      on a.agent_id=f.agent_id
    left join public.order_economics e
      on e.order_id=f.order_id
    where f.financial_applied_at::date between v_period_start and v_period_end
      and (e.order_id is null or e.reversed_at is null)
      and (
        v_role='admin'
        or coalesce(
          e.manager_id,
          private.izytel_resolve_manager_for_zone_ids(a.zone_ids)
        )=v_uid
      )
  ),
  partner_success as (
    select
      f.partner_id,
      f.order_amount::bigint as order_amount,
      f.cabiniste_margin_amount::bigint as cabiniste_margin_amount,
      f.cabiniste_settlement_amount::bigint as cabiniste_settlement_amount,
      f.izytel_gross_gain::bigint as izytel_gross_gain,
      coalesce(
        e.manager_id,
        private.izytel_resolve_manager_for_zone_ids(p.zone_ids)
      ) as effective_manager_id
    from public.partner_success_finalizations f
    join public.partner_accounts p
      on p.id=f.partner_id
    left join public.order_economics e
      on e.order_id=f.order_id
    where f.financial_applied_at::date between v_period_start and v_period_end
      and (e.order_id is null or e.reversed_at is null)
      and (
        v_role='admin'
        or coalesce(
          e.manager_id,
          private.izytel_resolve_manager_for_zone_ids(p.zone_ids)
        )=v_uid
      )
  ),
  agent_period as (
    select
      s.agent_id,
      coalesce(sum(s.order_amount),0)::bigint as processed_amount,
      coalesce(sum(s.commission_amount),0)::bigint as period_commission_earned,
      coalesce(sum(s.izytel_gross_gain),0)::bigint as izytel_gross_gain
    from agent_success s
    group by s.agent_id
  ),
  partner_period as (
    select
      s.partner_id,
      coalesce(sum(s.order_amount),0)::bigint as processed_amount,
      coalesce(sum(s.cabiniste_margin_amount),0)::bigint as cabiniste_margin,
      coalesce(sum(s.cabiniste_settlement_amount),0)::bigint as period_settlement_earned,
      coalesce(sum(s.izytel_gross_gain),0)::bigint as izytel_gross_gain
    from partner_success s
    group by s.partner_id
  ),
  base_agents as (
    select value as payload
    from jsonb_array_elements(coalesce(v_base->'agents','[]'::jsonb))
  ),
  base_partners as (
    select value as payload
    from jsonb_array_elements(coalesce(v_base->'cabinistes','[]'::jsonb))
  ),
  base_managers as (
    select value as payload
    from jsonb_array_elements(coalesce(v_base->'managers','[]'::jsonb))
  ),
  manager_period as (
    select
      x.manager_id,
      sum(x.processed_amount)::bigint as processed_amount,
      sum(x.izytel_gross_gain)::bigint as izytel_gross_gain
    from (
      select effective_manager_id as manager_id,
             order_amount as processed_amount,
             izytel_gross_gain
      from agent_success
      where effective_manager_id is not null
      union all
      select effective_manager_id,
             order_amount,
             izytel_gross_gain
      from partner_success
      where effective_manager_id is not null
    ) x
    group by x.manager_id
  )
  select
    coalesce((
      select jsonb_agg(
        a.payload || jsonb_build_object(
          'processedAmount',coalesce(ap.processed_amount,0),
          'periodCommissionEarned',coalesce(ap.period_commission_earned,0),
          'izytelGrossGainObserved',coalesce(ap.izytel_gross_gain,0)
        )
        order by a.payload->>'displayName'
      )
      from base_agents a
      left join agent_period ap
        on ap.agent_id=a.payload->>'agentId'
    ),'[]'::jsonb),
    coalesce((
      select jsonb_agg(
        p.payload || jsonb_build_object(
          'processedAmount',coalesce(pp.processed_amount,0),
          'cabinisteMarginEarned',coalesce(pp.cabiniste_margin,0),
          'periodSettlementEarned',coalesce(pp.period_settlement_earned,0),
          'izytelGrossGain',coalesce(pp.izytel_gross_gain,0)
        )
        order by p.payload->>'displayName'
      )
      from base_partners p
      left join partner_period pp
        on pp.partner_id::text=p.payload->>'partnerId'
    ),'[]'::jsonb),
    coalesce((
      select jsonb_agg(
        m.payload || jsonb_build_object(
          'zoneProcessedAmount',coalesce(mp.processed_amount,0),
          'zoneIzytelGrossGain',coalesce(mp.izytel_gross_gain,0)
        )
        order by m.payload->>'displayName'
      )
      from base_managers m
      left join manager_period mp
        on mp.manager_id=m.payload->>'managerId'
    ),'[]'::jsonb),
    jsonb_build_object(
      'agentCount',jsonb_array_length(coalesce(v_base->'agents','[]'::jsonb)),
      'cabinisteCount',jsonb_array_length(coalesce(v_base->'cabinistes','[]'::jsonb)),
      'managerCount',jsonb_array_length(coalesce(v_base->'managers','[]'::jsonb)),
      'processedAmount',
        coalesce((select sum(s.order_amount) from agent_success s),0)
        + coalesce((select sum(s.order_amount) from partner_success s),0),
      'izytelGrossGain',
        coalesce((select sum(s.izytel_gross_gain) from agent_success s),0)
        + coalesce((select sum(s.izytel_gross_gain) from partner_success s),0),
      'agentCommissionEarned',coalesce((v_base#>>'{summary,agentCommissionEarned}')::bigint,0),
      'agentCommissionEarnedPeriod',coalesce((select sum(s.commission_amount) from agent_success s),0),
      'agentCommissionDue',coalesce((v_base#>>'{summary,agentCommissionDue}')::bigint,0),
      'cabinisteMarginEarned',coalesce((select sum(s.cabiniste_margin_amount) from partner_success s),0),
      'cabinisteSettlementEarnedPeriod',coalesce((select sum(s.cabiniste_settlement_amount) from partner_success s),0),
      'cabinisteSettlementDue',coalesce((v_base#>>'{summary,cabinisteSettlementDue}')::bigint,0)
    ),
    coalesce(v_base->'scope','{}'::jsonb) || jsonb_build_object(
      'periodKey',to_char(v_period_start,'YYYY-MM'),
      'periodStart',v_period_start,
      'periodEnd',v_period_end,
      'observationEnd',least(current_date,v_period_end)
    )
  into v_agents,v_cabinistes,v_managers,v_summary,v_scope;

  return v_base || jsonb_build_object(
    'scope',v_scope,
    'summary',v_summary,
    'agents',v_agents,
    'cabinistes',v_cabinistes,
    'managers',v_managers
  );
end;
$function$;

create or replace function public.izytel_team_performance_snapshot()
returns jsonb
language sql
set search_path = ''
as $function$
  select private.izytel_team_performance_snapshot_v2();
$function$;

comment on function private.izytel_manager_compensation_preview_v2(text,date)
is 'Bloc 2: separates theoretical Manager compensation from threshold-eligible compensation.';

comment on function private.izytel_admin_close_manager_compensation_period_v2(text,date)
is 'Bloc 2: refuses Manager monthly closing unless plan is active, month ended, and both activation thresholds are met.';

comment on function private.izytel_team_performance_snapshot_v2()
is 'Bloc 2: current-month canonical team performance based on successful finalizations with historical manager attribution when captured.';
