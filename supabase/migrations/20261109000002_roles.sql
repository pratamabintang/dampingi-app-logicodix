alter table public.profiles
  add column if not exists role text not null default 'mother'
  check (role in ('mother', 'companion', 'professional'));

alter table public.profiles
  alter column role drop default;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (user_id, name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    new.raw_user_meta_data ->> 'role'
  );
  return new;
end;
$$;
