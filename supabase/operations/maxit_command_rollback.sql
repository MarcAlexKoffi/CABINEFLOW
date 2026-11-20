-- Restore the four pre-Max it function definitions and prior log constraints.
-- Stop if Max it configuration or audit data exists; preserve it for review.
-- No order, ledger, rule or audit row is changed.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
do $$begin
  if exists(select 1 from public.ussd_execution_rules
      where private.ussd_normalize_template(ussd_template)='APP:MAXIT')
    or exists(select 1 from public.ussd_rule_versions
      where private.ussd_normalize_template(snapshot->>'ussd_template')='APP:MAXIT')
    or exists(select 1 from public.ussd_execution_logs
      where launch_status='app_opened' or error_code in ('maxit_not_installed','maxit_unavailable')) then
    raise exception 'MAXIT_DATA_EXISTS_REVIEW_REQUIRED';
  end if;
end $$;
alter table public.ussd_execution_rules drop constraint ussd_maxit_requires_association;
alter table public.ussd_execution_logs drop constraint ussd_execution_logs_error_code_check;
alter table public.ussd_execution_logs add constraint ussd_execution_logs_error_code_check CHECK ((error_code = ANY (ARRAY['dialer_unavailable'::text, 'interrupted'::text])));
alter table public.ussd_execution_logs drop constraint ussd_execution_logs_launch_status_check;
alter table public.ussd_execution_logs add constraint ussd_execution_logs_launch_status_check CHECK ((launch_status = ANY (ARRAY['prepared'::text, 'dialer_opened'::text, 'failed'::text])));
CREATE OR REPLACE FUNCTION private.ussd_normalize_template(p_template text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare v text:=''; token text:=''; canonical text; c text; i integer:=1; closing integer;
begin
  if p_template is null or length(p_template)>512 then return p_template; end if;
  -- Same whitespace plus clipboard format marks as UssdEngine._templatePadding.
  p_template:=btrim(p_template,U&'\0009\000A\000B\000C\000D\0020\0085\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\200B\2028\2029\202F\205F\2060\3000\FEFF');
  while i<=length(p_template) loop
    if substr(p_template,i,2)='{{' then
      closing:=strpos(substr(p_template,i+2),'}}');
      if closing=0 then return v||substr(p_template,i); end if;
      token:=substr(p_template,i+2,closing-1);
      canonical:=private.ussd_variable_name(token);
      v:=v||'{{'||coalesce(canonical,token)||'}}';
      i:=i+closing+3;
    else
      c:=substr(p_template,i,1);
      if c in ('*','#','{','}') then v:=v||c; i:=i+1;
      else
        token:='';
        while i<=length(p_template) and substr(p_template,i,1) not in ('*','#','{','}') loop
          token:=token||substr(p_template,i,1); i:=i+1;
        end loop;
        canonical:=private.ussd_variable_name(token);
        v:=v||case when canonical is null then token else '{{'||canonical||'}}' end;
      end if;
    end if;
  end loop;
  return v;
end $function$;

CREATE OR REPLACE FUNCTION private.ussd_template(p_template text)
 RETURNS text[]
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare v text; m text[]; names text[]:='{}'; t text:=private.ussd_normalize_template(p_template);
begin
  if t is null or length(t) not between 1 and 512 then raise exception 'invalid_template'; end if;
  for m in select regexp_matches(t,'\{\{([^{}]+)\}\}','g') loop
    if m[1] not in ('msisdn_local','amount','offer_code','quantity','secret_code') then raise exception 'unknown_variable'; end if;
    names:=array_append(names,m[1]);
  end loop;
  v:=regexp_replace(t,'\{\{([^{}]+)\}\}','1','g');
  if length(v)>182 or v !~ '^(\*{1,2}|#)[0-9]+(\*[0-9]+)*#$' then raise exception 'invalid_template'; end if;
  return names;
end $function$;

CREATE OR REPLACE FUNCTION private.ussd_generate(p_template text, p_beneficiary text, p_amount bigint, p_offer_code text, p_quantity integer, p_secret_code text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare names text[]:=private.ussd_template(p_template); v text:=private.ussd_normalize_template(p_template);
  secret text:=coalesce(p_secret_code,private.ussd_default_secret());
begin
  if 'msisdn_local'=any(names) then v:=replace(v,'{{msisdn_local}}',private.ussd_phone(p_beneficiary)); end if;
  if 'amount'=any(names) then
    if p_amount is null or p_amount not between 1 and 100000000 then raise exception 'missing_amount'; end if;
    v:=replace(v,'{{amount}}',p_amount::text);
  end if;
  if 'offer_code'=any(names) then
    if p_offer_code is null or p_offer_code !~ '^[0-9]{1,20}$' then raise exception 'missing_offer_code'; end if;
    v:=replace(v,'{{offer_code}}',p_offer_code);
  end if;
  if 'quantity'=any(names) then
    if p_quantity is null or p_quantity not between 1 and 999999 then raise exception 'missing_quantity'; end if;
    v:=replace(v,'{{quantity}}',p_quantity::text);
  end if;
  if 'secret_code'=any(names) then
    if secret !~ '^[0-9]{1,20}$' then raise exception 'invalid_secret_code'; end if;
    v:=replace(v,'{{secret_code}}',secret);
  end if;
  if length(v)>182 or v !~ '^(\*{1,2}|#)[0-9]+(\*[0-9]+)*#$' then raise exception 'invalid_template'; end if;
  return v;
end $function$;

CREATE OR REPLACE FUNCTION private.ussd_record_result_before_execution(p_attempt_id uuid, p_status text, p_error_code text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid text := private.ussd_uid(); l public.ussd_execution_logs;
begin
  if p_status is null or p_status not in ('dialer_opened','failed') or (p_error_code is not null and p_error_code not in ('dialer_unavailable','interrupted')) then raise exception 'invalid_status'; end if;
  select * into strict l from public.ussd_execution_logs where id=p_attempt_id and actor_uid=v_uid for update;
  if l.launch_status=p_status then return; end if;
  if l.launch_status<>'prepared' then raise exception 'attempt_already_recorded'; end if;
  update public.ussd_execution_logs set launch_status=p_status,error_code=p_error_code,
    dialer_opened_at=case when p_status='dialer_opened' then clock_timestamp() end where id=l.id;
end $function$;
commit;
