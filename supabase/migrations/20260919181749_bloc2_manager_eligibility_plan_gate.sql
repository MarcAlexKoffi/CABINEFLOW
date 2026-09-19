-- IzyTel - Bloc 2 / eligibilite Manager
-- Une remuneration n'est eligible que si le plan est actif ET les deux seuils sont atteints.

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
  v_thresholds_met boolean := false;
  v_plan_active boolean := false;
  v_eligible boolean := false;
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

  v_thresholds_met := coalesce((v_thresholds->>'allMet')::boolean,false);
  v_plan_active := coalesce(v_plan->>'status','')='active';
  v_eligible := v_thresholds_met and v_plan_active;

  v_theoretical_base := coalesce((v_projection->>'baseAmount')::bigint,0);
  v_theoretical_variable_raw := coalesce((v_projection->>'variableRawAmount')::bigint,0);
  v_theoretical_variable := coalesce((v_projection->>'variableAmount')::bigint,0);
  v_theoretical_total := coalesce((v_projection->>'projectedTotalAmount')::bigint,0);

  if v_eligible then
    v_eligible_base := v_theoretical_base;
    v_eligible_variable := v_theoretical_variable;
    v_eligible_total := v_theoretical_total;
  end if;

  v_bookable :=
    coalesce((v_projection->>'bookable')::boolean,false)
    and v_thresholds_met
    and v_plan_active;

  return v_raw
    || jsonb_build_object(
      'eligibility',jsonb_build_object(
        'eligible',v_eligible,
        'thresholdsMet',v_thresholds_met,
        'planActive',v_plan_active,
        'status',case
          when not v_plan_active then 'plan_draft'
          when v_thresholds_met then 'eligible'
          else 'thresholds_not_met'
        end,
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
        'activationReady',v_thresholds_met,
        'eligible',v_eligible,
        'bookable',v_bookable
      )
    );
end;
$function$;

comment on function private.izytel_manager_compensation_preview_v2(text,date)
is 'Bloc 2: separates theoretical Manager compensation from compensation eligible only when the plan is active and both thresholds are met.';
