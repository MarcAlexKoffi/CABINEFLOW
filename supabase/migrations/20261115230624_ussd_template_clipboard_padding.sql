-- Remove clipboard padding at template boundaries only. No rule, activation,
-- secret, grant or order is changed. Internal characters remain validated.
create or replace function private.ussd_normalize_template(p_template text) returns text
language plpgsql immutable set search_path='' as $$
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
end $$;
