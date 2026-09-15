-- BO-3 recette réelle : récupération des avatars Staff existants et
-- protection contre leur effacement par un formulaire resté en mémoire.

update public.staff_profiles p
set avatar_path = p.firebase_uid || '/avatar/profile.jpg'
where nullif(btrim(coalesce(p.avatar_path, '')), '') is null
  and exists (
    select 1
    from storage.objects o
    where o.bucket_id = 'agent-personal'
      and o.name = p.firebase_uid || '/avatar/profile.jpg'
  );

update public.manager_profiles m
set avatar_path = s.avatar_path
from public.staff_profiles s
where s.firebase_uid = m.firebase_uid
  and nullif(btrim(coalesce(m.avatar_path, '')), '') is null
  and nullif(btrim(coalesce(s.avatar_path, '')), '') is not null;

update public.agent_personal_profiles a
set avatar_path = s.avatar_path
from public.staff_profiles s
where s.firebase_uid = a.firebase_uid
  and nullif(btrim(coalesce(a.avatar_path, '')), '') is null
  and nullif(btrim(coalesce(s.avatar_path, '')), '') is not null;

create or replace function private.izytel_preserve_staff_avatar_path()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if nullif(btrim(coalesce(new.avatar_path, '')), '') is null
     and nullif(btrim(coalesce(old.avatar_path, '')), '') is not null then
    new.avatar_path := old.avatar_path;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_preserve_staff_avatar_path on public.staff_profiles;
create trigger trg_preserve_staff_avatar_path
before update of avatar_path on public.staff_profiles
for each row execute function private.izytel_preserve_staff_avatar_path();
