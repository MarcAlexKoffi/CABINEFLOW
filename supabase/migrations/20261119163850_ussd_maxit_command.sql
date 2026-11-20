-- Local candidate only. No rule, association, activation or order is seeded.
-- Reuse the existing template, resolver, preparation and execution-session RPCs.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';

do $$declare d text; marker text;begin
  d:=pg_get_functiondef('private.ussd_normalize_template(text)'::regprocedure);
  marker:='  while i<=length(p_template) loop';
  if position(marker in d)=0 then raise exception 'UNEXPECTED_USSD_NORMALIZER';end if;
  d:=replace(d,marker,'  if upper(p_template) in (''MAXIT'',''APP:MAXIT'') then return ''APP:MAXIT'';end if;'||chr(10)||marker);
  execute d;

  d:=pg_get_functiondef('private.ussd_template(text)'::regprocedure);
  marker:='  for m in select regexp_matches';
  if position(marker in d)=0 then raise exception 'UNEXPECTED_USSD_TEMPLATE';end if;
  d:=replace(d,marker,'  if t=''APP:MAXIT'' then return names;end if;'||chr(10)||marker);
  execute d;

  d:=pg_get_functiondef('private.ussd_generate(text,text,bigint,text,integer,text)'::regprocedure);
  marker:='  if length(v)>182';
  if position(marker in d)=0 then raise exception 'UNEXPECTED_USSD_GENERATOR';end if;
  d:=replace(d,marker,'  if v=''APP:MAXIT'' then return v;end if;'||chr(10)||marker);
  execute d;
end $$;

-- An app command must be explicitly associated; it cannot become a generic
-- Orange shortcut or a balance inquiry. Existing association validation remains.
alter table public.ussd_execution_rules add constraint ussd_maxit_requires_association
check(private.ussd_normalize_template(ussd_template)<>'APP:MAXIT' or
  (network='orange' and purpose='order' and (offer_id is not null or family_id is not null)));

alter table public.ussd_execution_logs drop constraint ussd_execution_logs_launch_status_check;
alter table public.ussd_execution_logs add constraint ussd_execution_logs_launch_status_check
check(launch_status in ('prepared','dialer_opened','app_opened','failed'));
alter table public.ussd_execution_logs drop constraint ussd_execution_logs_error_code_check;
alter table public.ussd_execution_logs add constraint ussd_execution_logs_error_code_check
check(error_code in ('dialer_unavailable','interrupted','maxit_not_installed','maxit_unavailable'));

-- Extend only the original audit implementation. In the exclusive-execution
-- schema the outer session/owner check stays untouched, as does prepare's
-- uncertain-state guard. CREATE OR REPLACE preserves existing ACLs.
do $$declare f regprocedure;d text;marker text;begin
  f:=coalesce(to_regprocedure('private.ussd_record_result_before_execution(uuid,text,text)'),
    to_regprocedure('private.ussd_record_result(uuid,text,text)'));
  d:=pg_get_functiondef(f);
  if position('p_status not in (''dialer_opened'',''failed'')' in d)=0
    or position('p_error_code not in (''dialer_unavailable'',''interrupted'')' in d)=0 then
    raise exception 'UNEXPECTED_USSD_RESULT_AUDIT';end if;
  d:=replace(d,'p_status not in (''dialer_opened'',''failed'')',
    'p_status not in (''dialer_opened'',''app_opened'',''failed'')');
  d:=replace(d,'p_error_code not in (''dialer_unavailable'',''interrupted'')',
    'p_error_code not in (''dialer_unavailable'',''interrupted'',''maxit_not_installed'',''maxit_unavailable'')');
  marker:='  if l.launch_status=p_status then return; end if;';
  if position(marker in d)=0 then raise exception 'UNEXPECTED_USSD_RESULT_AUDIT';end if;
  d:=replace(d,marker,$guard$
  if exists(select 1 from public.ussd_rule_versions rv where rv.rule_id=l.rule_id and rv.version=l.rule_version
    and private.ussd_normalize_template(rv.snapshot->>'ussd_template')='APP:MAXIT') then
    if p_status='dialer_opened' or p_error_code='dialer_unavailable'
      or (p_status='app_opened' and p_error_code is not null) then raise exception 'invalid_status';end if;
  elsif p_status='app_opened' or p_error_code in ('maxit_not_installed','maxit_unavailable') then
    raise exception 'invalid_status';
  end if;
$guard$||marker);
  d:=replace(d,'when p_status=''dialer_opened'' then',
    'when p_status in (''dialer_opened'',''app_opened'') then');
  execute d;
end $$;
commit;
