-- Profile timezone is captured at registration and defaults to Jakarta.
--
-- The column already exists (20261110000002) with default 'UTC'. Jakarta is
-- the product's home timezone: fixed UTC+7, no DST, so a day boundary never
-- depends on a transition table. The trigger now copies the IANA zone the
-- client sent in signup metadata, falling back to Jakarta when the field is
-- missing or blank.

alter table public.profiles
  alter column timezone set default 'Asia/Jakarta';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''

as $$
begin
  insert into public.profiles (user_id, name, role, timezone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    new.raw_user_meta_data ->> 'role',
    coalesce(nullif(new.raw_user_meta_data ->> 'timezone', ''), 'Asia/Jakarta')
  );
  return new;
end;
$$;
