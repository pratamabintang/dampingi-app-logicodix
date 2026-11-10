drop table if exists public.moods;
drop table if exists public.journals;

create table public.moods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  created_at date not null,
  mood int not null check (mood >= 1 and mood <= 5),
  description text check (char_length(description) <= 500),
  unique (user_id, created_at)
);

create table public.journals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  created_at date not null,
  title text not null check (char_length(title) between 1 and 255),
  content text not null check (char_length(content) between 1 and 10000),
  unique (user_id, created_at)
);
