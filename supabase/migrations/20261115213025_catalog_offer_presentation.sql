-- Presentation only: existing client fields, commercial data and units retained.
-- Format binary spreadsheet residue through the shortest float representation
-- for display only. The exact imported decimal stays in catalog_data/metadata.
create function private.catalog_quantity_label(p_value text) returns text
language sql immutable strict set search_path='' set extra_float_digits=1 as $$
  select replace(trim_scale(((p_value::double precision)::text)::numeric)::text,'.',',')
$$;

create function private.catalog_presentation(p_data jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare v_volume text; v_details text[]:='{}'; v_validity text; v_nature text; v_badge text;
begin
  v_nature:=nullif(left(regexp_replace(btrim(coalesce(p_data->>'reference_operateur','')),'[[:space:]]+',' ','g'),80),'');
  if p_data->>'mis_en_avant'='OUI' then
    v_badge:=case when v_nature is not null and length(v_nature)<=20 then v_nature else 'Mis en avant' end;
  end if;
  if nullif(p_data->>'volume_data','') is not null then
    v_volume:=private.catalog_quantity_label(p_data->>'volume_data')||' '||(p_data->>'unite_data');
    v_details:=array_append(v_details,v_volume);
  end if;
  if nullif(p_data->>'minutes_appels','') is not null then v_details:=array_append(v_details,(p_data->>'minutes_appels')||' min'); end if;
  if nullif(p_data->>'nombre_sms','') is not null then v_details:=array_append(v_details,(p_data->>'nombre_sms')||' SMS'); end if;
  v_validity:=(p_data->>'duree_valeur')||' '||case p_data->>'duree_unite'
    when 'JOUR' then case when (p_data->>'duree_valeur')::numeric>1 then 'jours' else 'jour' end
    when 'HEURE' then case when (p_data->>'duree_valeur')::numeric>1 then 'heures' else 'heure' end else 'mois' end;
  v_details:=array_append(v_details,'Validité '||v_validity);
  -- Keep the badge's presence tied to mis_en_avant: the existing client uses
  -- that presence to rank featured offers. Reuse the first detail otherwise,
  -- without adding a fifth line that would hide validity on mixed offers.
  if v_nature is not null and v_badge is distinct from v_nature then
    v_details[1]:=v_nature||' · '||v_details[1];
  end if;
  return jsonb_build_object('volume',v_volume,'details',v_details,'badge_label',v_badge);
end $$;

create function private.catalog_offer_presentation() returns trigger
language plpgsql set search_path='' as $$
declare display jsonb; reference text;
begin
  if new.catalog_data is null or coalesce(current_setting('izytel.catalog_restore',true),'')='true' then return new; end if;
  -- Runs after catalog_offer_import_version: private metadata is already saved,
  -- while comments, source URLs and delivery evidence stay out of public data.
  select data->>'reference_operateur' into reference from public.catalog_offer_import_metadata where offer_id=new.id;
  display:=private.catalog_presentation(new.catalog_data||jsonb_build_object('reference_operateur',reference));
  new.volume:=display->>'volume';
  new.details:=array(select jsonb_array_elements_text(display->'details'));
  new.badge_label:=display->>'badge_label';
  return new;
end $$;
create trigger catalog_offer_presentation before insert or update on public.catalog_offers
  for each row execute function private.catalog_offer_presentation();
revoke all on function private.catalog_quantity_label(text),private.catalog_presentation(jsonb),private.catalog_offer_presentation() from public,anon,authenticated;

-- Keep the exact previous revision for a controlled, version-checked rollback.
create table private.catalog_presentation_backup_20261115213025 (
  offer_id text primary key,
  before_state jsonb not null,
  after_version bigint not null,
  changed_at timestamptz not null default now()
);
alter table private.catalog_presentation_backup_20261115213025 enable row level security;
revoke all on private.catalog_presentation_backup_20261115213025 from public,anon,authenticated;

do $$
declare offer public.catalog_offers; before public.catalog_offers; saved public.catalog_offers; display jsonb; v_details text[];
begin
  for offer in select * from public.catalog_offers where catalog_data is not null and deleted_at is null order by id for update loop
    before:=private.catalog_enrich(offer);
    display:=private.catalog_presentation(before.catalog_data);
    v_details:=array(select jsonb_array_elements_text(display->'details'));
    if offer.volume is not distinct from display->>'volume' and offer.details is not distinct from v_details and offer.badge_label is not distinct from display->>'badge_label' then continue; end if;
    update public.catalog_offers set volume=display->>'volume',details=v_details,badge_label=display->>'badge_label',updated_at=now()
      where id=offer.id returning * into saved;
    saved:=private.catalog_enrich(saved);
    insert into private.catalog_presentation_backup_20261115213025(offer_id,before_state,after_version)
      values(offer.id,to_jsonb(before),saved.catalog_version);
    insert into public.catalog_offer_audit_events(offer_id,action,before_state,after_state,actor_uid,actor_name,actor_role)
      values(offer.id,'catalog_presentation_updated',to_jsonb(before),to_jsonb(saved),'system:catalog-presentation','Présentation du catalogue','system');
  end loop;
end $$;
