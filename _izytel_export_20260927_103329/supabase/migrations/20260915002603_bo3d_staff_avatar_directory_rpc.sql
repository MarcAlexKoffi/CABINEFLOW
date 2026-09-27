create or replace function public.izytel_staff_directory_avatar_path(p_staff_uid text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid text := btrim(coalesce(p_staff_uid, ''));
  v_path text;
begin
  if v_uid = '' or not private.is_izytel_finance_staff() then
    return null;
  end if;
  select nullif(btrim(profile.avatar_path), '')
    into v_path
  from public.staff_profiles profile
  where profile.firebase_uid = v_uid;
  return v_path;
end;
$$;
grant execute on function public.izytel_staff_directory_avatar_path(text) to anon, authenticated;
