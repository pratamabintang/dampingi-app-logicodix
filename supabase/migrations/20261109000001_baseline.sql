create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  role text not null
    check (role in ('mother', 'companion', 'professional')),
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

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

create trigger on_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
