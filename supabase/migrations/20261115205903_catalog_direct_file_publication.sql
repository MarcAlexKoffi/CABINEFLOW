-- Admin-confirmed file imports publish offers directly.
-- Keep commercial validation, authorization, audit and optimistic locking.
-- No existing offer or verification metadata is modified by this migration.

create or replace function private.catalog_validate(p_data jsonb,p_existing public.catalog_offers) returns jsonb
language plpgsql stable set search_path='' as $$
declare errors jsonb:='[]'; k text; value text; verified date;
begin
  if coalesce(p_data->>'code_offre','') !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$' then errors:=errors||jsonb_build_array('code_offre obligatoire : lettres, chiffres, point, tiret, souligné ; 120 caractères maximum.'); end if;
  if p_data->>'action' not in ('UPSERT','DESACTIVER') then errors:=errors||jsonb_build_array('Action attendue : UPSERT ou DESACTIVER.'); end if;
  if p_existing.id is not null and p_data->>'operateur'<>'' and lower(p_data->>'operateur')<>p_existing.network then errors:=errors||jsonb_build_array('Collision de code entre opérateurs.'); end if;
  if p_existing.deleted_at is not null then errors:=errors||jsonb_build_array('Offre archivée : restauration administrative nécessaire avant modification.'); end if;
  if p_data->>'action'='DESACTIVER' then
    if p_existing.id is null then errors:=errors||jsonb_build_array('Code inconnu : aucune offre à désactiver.'); end if;
    return errors;
  end if;
  if not exists(select 1 from public.catalog_import_families where network=p_data->>'operateur' and code=p_data->>'famille' and enabled) then errors:=errors||jsonb_build_array('Famille ou opérateur non reconnu / incompatible.'); end if;
  if p_data->>'type_forfait' not in ('INTERNET','MIXTE','APPELS','SOCIAL') then errors:=errors||jsonb_build_array('type_forfait invalide.'); end if;
  if length(p_data->>'nom_affiche') not between 2 and 120 then errors:=errors||jsonb_build_array('nom_affiche : 2 à 120 caractères.'); end if;
  if p_data->>'statut' not in ('BROUILLON','ACTIF','INACTIF') then errors:=errors||jsonb_build_array('statut invalide.'); end if;
  if p_data->>'mis_en_avant' not in ('OUI','NON') or p_data->>'activable_pour_tiers' not in ('OUI','NON','A_VERIFIER') or p_data->>'canal_activation' not in ('MANUEL','USSD','API','APP_OPERATEUR','A_VERIFIER') then errors:=errors||jsonb_build_array('Valeur de vérification / activation non reconnue.'); end if;
  foreach k in array array['prix_fcfa','volume_data','minutes_appels','nombre_sms','duree_valeur','ordre_affichage'] loop
    value:=p_data->>k;
    if value='' and k in ('volume_data','minutes_appels','nombre_sms') then continue; end if;
    if value !~ '^[0-9]+(\.[0-9]+)?$' or length(value)>20 then errors:=errors||jsonb_build_array(k||' : nombre invalide.');
    elsif value::numeric>100000000 or (k in ('prix_fcfa','volume_data','duree_valeur') and value::numeric<=0) or (k<>'volume_data' and value::numeric<>trunc(value::numeric)) then errors:=errors||jsonb_build_array(k||' : quantité / précision invalide.'); end if;
  end loop;
  if p_data->>'duree_unite' not in ('JOUR','HEURE','MOIS') then errors:=errors||jsonb_build_array('duree_unite invalide.'); end if;
  if p_data->>'unite_data' not in ('','MO','GO') or ((p_data->>'volume_data'='')<>(p_data->>'unite_data'='')) then errors:=errors||jsonb_build_array('Volume et unité MO/GO à renseigner ensemble.'); end if;
  if p_data->>'verifie_le'<>'' then
    begin
      verified:=(p_data->>'verifie_le')::date;
      if p_data->>'verifie_le' !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' or verified>current_date then raise exception 'invalid date'; end if;
    exception when others then errors:=errors||jsonb_build_array('verifie_le : date AAAA-MM-JJ valide et non future attendue.'); verified:=null; end;
  end if;
  return errors;
end $$;

-- Only file imports publish drafts automatically. Editors and other bulk
-- operations keep their explicit status; no verification metadata is invented.
create function public.izytel_catalog_file_import_prepare(p_id uuid,p_name text,p_hash text,p_rows jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare rows jsonb;
begin
  perform private.catalog_admin();
  if jsonb_typeof(p_rows) is distinct from 'array' then raise exception 'CATALOG_IMPORT_INVALID'; end if;
  if jsonb_array_length(p_rows) not between 1 and 5000 or octet_length(p_rows::text)>10485760 then raise exception 'CATALOG_IMPORT_TOO_LARGE'; end if;
  select jsonb_agg(case
    when upper(btrim(coalesce(value->>'action','')))='UPSERT'
      and upper(btrim(coalesce(value->>'statut',''))) in ('','BROUILLON','ACTIF')
    then value||jsonb_build_object('statut','ACTIF') else value end order by ordinal)
    into rows from jsonb_array_elements(p_rows) with ordinality as r(value,ordinal);
  return public.izytel_catalog_import_prepare(p_id,p_name,p_hash,rows);
end $$;
revoke all on function public.izytel_catalog_file_import_prepare(uuid,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.izytel_catalog_file_import_prepare(uuid,text,text,jsonb) to anon,authenticated;
