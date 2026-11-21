-- Campaigns are empty on installation. No Tuesday or other promotion is assumed.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
create table public.offer_bonus_campaigns(
 id uuid primary key default gen_random_uuid(),name text not null check(length(btrim(name)) between 3 and 120),
 network text not null check(network in ('orange','mtn','moov')),
 status text not null default 'draft' check(status in ('draft','validated','active','suspended','expired','archived')),
 weekdays integer[] not null check(cardinality(weekdays) between 1 and 7 and weekdays<@array[1,2,3,4,5,6,7]),
 starts_at timestamptz not null,ends_at timestamptz not null,
 daily_start time not null,daily_end time not null,timezone text not null default 'Africa/Abidjan' check(timezone='Africa/Abidjan'),
 bonus_kind text not null check(bonus_kind in ('percentage','added_mb','total_mb')),
 bonus_value numeric(16,4) not null check(bonus_value>0 and bonus_value<1000000000000),
 operator_reference text,validated_at timestamptz,validated_by text,
 version integer not null default 1,created_by text not null,updated_by text not null,
 created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp(),
 check(ends_at>starts_at and ends_at<=starts_at+interval '5 years'),
 check(status not in ('validated','active') or (length(btrim(operator_reference))>=10 and validated_at is not null and validated_by is not null))
);
create table public.offer_bonus_campaign_offers(
 campaign_id uuid not null references public.offer_bonus_campaigns(id),offer_id text not null references public.catalog_offers(id),
 base_volume_mb numeric(16,4) not null check(base_volume_mb>0 and base_volume_mb<1000000000000),primary key(campaign_id,offer_id)
);
create index offer_bonus_by_offer on public.offer_bonus_campaign_offers(offer_id,campaign_id);
create index offer_bonus_visibility on public.offer_bonus_campaigns(starts_at,ends_at) where status='active';
create table private.offer_bonus_audit(
 id bigint generated always as identity primary key,campaign_id uuid not null references public.offer_bonus_campaigns(id),
 actor_uid text not null,action text not null,before_value jsonb,after_value jsonb,created_at timestamptz not null default clock_timestamp()
);
alter table public.offer_bonus_campaigns enable row level security;
alter table public.offer_bonus_campaign_offers enable row level security;
alter table private.offer_bonus_audit enable row level security;
revoke all on public.offer_bonus_campaigns,public.offer_bonus_campaign_offers,private.offer_bonus_audit from public,anon,authenticated;

create function private.catalog_volume_mb(p_data jsonb) returns numeric
language plpgsql immutable set search_path='' as $$
declare v numeric;begin
 if replace(coalesce(p_data->>'volume_data',''),',','.') !~ '^[0-9]+([.][0-9]+)?$' then return null;end if;
 v:=replace(p_data->>'volume_data',',','.')::numeric;
 return case upper(p_data->>'unite_data') when 'MO' then v when 'GO' then v*1000 else null end;
end $$;
create function private.bonus_window(c public.offer_bonus_campaigns,p_day date) returns tstzrange
language plpgsql immutable set search_path='' as $$
declare a timestamptz;b timestamptz;begin
 if not extract(isodow from p_day)::integer=any(c.weekdays) then return null;end if;
 a:=(p_day+c.daily_start) at time zone 'Africa/Abidjan';
 b:=(p_day+case when c.daily_end<=c.daily_start then 1 else 0 end+c.daily_end) at time zone 'Africa/Abidjan';
 a:=greatest(a,c.starts_at);b:=least(b,c.ends_at);
 if a>=b then return null;end if;
 return tstzrange(a,b,'[)');
end $$;
create function private.bonus_campaigns_overlap(a public.offer_bonus_campaigns,b public.offer_bonus_campaigns) returns boolean
language sql stable set search_path='' as $$
 select exists(
  select 1 from generate_series((greatest(a.starts_at,b.starts_at) at time zone 'Africa/Abidjan')::date-1,
    (least(a.ends_at,b.ends_at) at time zone 'Africa/Abidjan')::date,interval '1 day') d
  cross join generate_series(-1,1) delta
  where private.bonus_window(a,d::date)&&private.bonus_window(b,d::date+delta)
 );
$$;
create function private.bonus_assert_campaign(c public.offer_bonus_campaigns) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.offer_bonus_campaign_offers where campaign_id=c.id) then raise exception 'BONUS_OFFERS_REQUIRED';end if;
 if exists(select 1 from public.offer_bonus_campaign_offers t join public.catalog_offers o on o.id=t.offer_id
   where t.campaign_id=c.id and (o.network<>c.network or not o.is_active or o.deleted_at is not null
     or private.catalog_volume_mb(o.catalog_data) is distinct from t.base_volume_mb
     or (c.bonus_kind='total_mb' and c.bonus_value<t.base_volume_mb))) then raise exception 'BONUS_OFFER_VOLUME_MISMATCH';end if;
 if exists(select 1 from public.offer_bonus_campaigns other where other.id<>c.id and other.status in ('validated','active')
   and exists(select 1 from public.offer_bonus_campaign_offers x join public.offer_bonus_campaign_offers y using(offer_id)
     where x.campaign_id=c.id and y.campaign_id=other.id)
   and private.bonus_campaigns_overlap(c,other)) then raise exception 'BONUS_CAMPAIGN_CONFLICT';end if;
end $$;

create function private.bonus_admin_list() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 perform private.ussd_admin();
 return coalesce((select jsonb_agg(to_jsonb(c)||jsonb_build_object(
   'effective_status',case when c.status<>'archived' and c.ends_at<=statement_timestamp() then 'expired' else c.status end,
   'offers',(select jsonb_agg(jsonb_build_object('offer_id',t.offer_id,'base_volume_mb',t.base_volume_mb))
     from public.offer_bonus_campaign_offers t where t.campaign_id=c.id)) order by c.updated_at desc)
   from public.offer_bonus_campaigns c),'[]'::jsonb);
end $$;
create function private.bonus_save(p_id uuid,p_expected_version integer,p_payload jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare u text:=private.ussd_admin();c public.offer_bonus_campaigns;old_value jsonb;
 target jsonb;v_id uuid:=coalesce(p_id,gen_random_uuid());begin
 perform pg_advisory_xact_lock(9261032);
 if jsonb_typeof(p_payload)<>'object' or exists(select 1 from jsonb_object_keys(p_payload) k
   where k not in ('name','network','weekdays','starts_at','ends_at','daily_start','daily_end','bonus_kind','bonus_value','operator_reference','offers')) then
   raise exception 'BONUS_INVALID_PAYLOAD';end if;
 if jsonb_typeof(p_payload->'offers') is distinct from 'array' or jsonb_array_length(p_payload->'offers') not between 1 and 200 then
  raise exception 'BONUS_OFFERS_REQUIRED';end if;
 if p_id is not null then
  select * into strict c from public.offer_bonus_campaigns where id=p_id for update;
  if c.version is distinct from p_expected_version then raise exception 'BONUS_VERSION_CHANGED';end if;
  if c.status='archived' then raise exception 'BONUS_ARCHIVED';end if;
  old_value:=to_jsonb(c);
 end if;
 insert into public.offer_bonus_campaigns(id,name,network,weekdays,starts_at,ends_at,daily_start,daily_end,
   bonus_kind,bonus_value,operator_reference,created_by,updated_by)
 values(v_id,btrim(p_payload->>'name'),p_payload->>'network',
   array(select jsonb_array_elements_text(p_payload->'weekdays')::integer),
   (p_payload->>'starts_at')::timestamptz,(p_payload->>'ends_at')::timestamptz,
   (p_payload->>'daily_start')::time,(p_payload->>'daily_end')::time,
   p_payload->>'bonus_kind',(p_payload->>'bonus_value')::numeric,nullif(btrim(p_payload->>'operator_reference'),''),u,u)
 on conflict(id) do update set name=excluded.name,network=excluded.network,weekdays=excluded.weekdays,
 starts_at=excluded.starts_at,ends_at=excluded.ends_at,daily_start=excluded.daily_start,daily_end=excluded.daily_end,
 bonus_kind=excluded.bonus_kind,bonus_value=excluded.bonus_value,operator_reference=excluded.operator_reference,
 status='draft',validated_at=null,validated_by=null,version=public.offer_bonus_campaigns.version+1,
 updated_by=u,updated_at=clock_timestamp() returning * into c;
 delete from public.offer_bonus_campaign_offers where campaign_id=v_id;
 for target in select * from jsonb_array_elements(p_payload->'offers') loop
  insert into public.offer_bonus_campaign_offers values(v_id,target->>'offer_id',(target->>'base_volume_mb')::numeric);
 end loop;
 -- Check source volumes even for drafts; overlap is enforced at validation.
 if exists(select 1 from public.offer_bonus_campaign_offers t join public.catalog_offers o on o.id=t.offer_id
   where t.campaign_id=v_id and (o.network<>c.network or o.deleted_at is not null
     or private.catalog_volume_mb(o.catalog_data) is distinct from t.base_volume_mb)) then raise exception 'BONUS_OFFER_VOLUME_MISMATCH';end if;
 insert into private.offer_bonus_audit(campaign_id,actor_uid,action,before_value,after_value) values(v_id,u,'save_draft',old_value,to_jsonb(c));
 return v_id;
end $$;
create function private.bonus_set_status(p_id uuid,p_expected_version integer,p_status text,p_reference text default null)
returns void language plpgsql security definer set search_path='' as $$
declare u text:=private.ussd_admin();c public.offer_bonus_campaigns;old_value jsonb;begin
 perform pg_advisory_xact_lock(9261032);
 select * into strict c from public.offer_bonus_campaigns where id=p_id for update;
 if c.version is distinct from p_expected_version then raise exception 'BONUS_VERSION_CHANGED';end if;
 if c.status='archived' or p_status not in ('validated','active','suspended','archived') then raise exception 'BONUS_INVALID_TRANSITION';end if;
 old_value:=to_jsonb(c);
 if p_status='validated' then
  if length(btrim(coalesce(p_reference,''))) not between 10 and 500 then raise exception 'BONUS_OPERATOR_REFERENCE_REQUIRED';end if;
  c.operator_reference:=btrim(p_reference);c.validated_at:=clock_timestamp();c.validated_by:=u;
 elsif p_status='active' and (c.status not in ('validated','suspended') or c.validated_at is null) then
  raise exception 'BONUS_VALIDATION_REQUIRED';
 end if;
 if p_status in ('validated','active') then
  if c.ends_at<=clock_timestamp() then raise exception 'BONUS_EXPIRED';end if;
  perform private.bonus_assert_campaign(c);
 end if;
 update public.offer_bonus_campaigns set status=p_status,operator_reference=c.operator_reference,
 validated_at=c.validated_at,validated_by=c.validated_by,version=version+1,updated_at=clock_timestamp(),updated_by=u where id=c.id returning * into c;
 insert into private.offer_bonus_audit(campaign_id,actor_uid,action,before_value,after_value) values(c.id,u,p_status,old_value,to_jsonb(c));
end $$;
create function private.bonus_projection(p_now timestamptz) returns jsonb
language sql stable security definer set search_path='' as $$
 with eligible as (
  select t.offer_id,c.id campaign_id,c.name,c.bonus_kind,c.bonus_value,t.base_volume_mb,
   case c.bonus_kind when 'percentage' then t.base_volume_mb*(1+c.bonus_value/100)
    when 'added_mb' then t.base_volume_mb+c.bonus_value else c.bonus_value end total_volume_mb,
   least(upper(w.valid_window),p_now+interval '30 seconds') valid_until,
   count(*) over(partition by t.offer_id) matches
  from public.offer_bonus_campaigns c join public.offer_bonus_campaign_offers t on t.campaign_id=c.id
  join public.catalog_offers o on o.id=t.offer_id
  cross join lateral (
   select private.bonus_window(c,(p_now at time zone 'Africa/Abidjan')::date-delta) valid_window
   from generate_series(0,1) delta
  ) w
  where c.status='active' and c.starts_at<=p_now and c.ends_at>p_now
   and c.validated_at is not null and c.validated_by is not null
   and nullif(btrim(c.operator_reference),'') is not null and o.is_active and o.deleted_at is null
   and o.network=c.network and private.catalog_volume_mb(o.catalog_data)=t.base_volume_mb and w.valid_window @> p_now
 )
 select jsonb_build_object('server_now',p_now,'promotions',coalesce(jsonb_agg(to_jsonb(e)-'matches') filter(where matches=1),'[]'::jsonb)) from eligible e;
$$;
create function private.bonus_public_projection() returns jsonb language sql security definer set search_path='' as $$
 select private.bonus_projection(statement_timestamp());$$;
create function public.izytel_public_offer_bonuses() returns jsonb language sql set search_path='' as $$
 select private.bonus_public_projection();$$;
create function public.izytel_bonus_campaigns() returns jsonb language sql set search_path='' as $$select private.bonus_admin_list();$$;
create function public.izytel_bonus_save(p_id uuid,p_expected_version integer,p_payload jsonb) returns uuid language sql set search_path='' as $$
 select private.bonus_save(p_id,p_expected_version,p_payload);$$;
create function public.izytel_bonus_set_status(p_id uuid,p_expected_version integer,p_status text,p_reference text default null) returns void
language sql set search_path='' as $$select private.bonus_set_status(p_id,p_expected_version,p_status,p_reference);$$;
revoke all on function private.catalog_volume_mb(jsonb),private.bonus_window(public.offer_bonus_campaigns,date),
 private.bonus_campaigns_overlap(public.offer_bonus_campaigns,public.offer_bonus_campaigns),
 private.bonus_assert_campaign(public.offer_bonus_campaigns),private.bonus_projection(timestamptz),
 private.bonus_admin_list(),private.bonus_save(uuid,integer,jsonb),private.bonus_set_status(uuid,integer,text,text),
 private.bonus_public_projection(),public.izytel_public_offer_bonuses(),public.izytel_bonus_campaigns(),
 public.izytel_bonus_save(uuid,integer,jsonb),public.izytel_bonus_set_status(uuid,integer,text,text) from public,anon,authenticated;
-- Public projection is the only anonymous read, with no arbitrary client clock.
grant execute on function public.izytel_public_offer_bonuses(),private.bonus_public_projection(),
 private.bonus_admin_list(),private.bonus_save(uuid,integer,jsonb),private.bonus_set_status(uuid,integer,text,text),
 public.izytel_bonus_campaigns(),public.izytel_bonus_save(uuid,integer,jsonb),public.izytel_bonus_set_status(uuid,integer,text,text)
 to anon,authenticated;
-- Private schema is not exposed by PostgREST. Direct calls to admin helpers still authenticate.
create trigger offer_bonus_catalog_refresh after insert or update on public.offer_bonus_campaigns
 for each statement execute function private.izytel_touch_catalog_change_feed();
commit;
