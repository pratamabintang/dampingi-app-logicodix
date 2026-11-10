drop table if exists public.moods;

create table public.moods (
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at date not null,
  mood int not null check (mood >= 1 and mood <= 5),
  description text check (char_length(description) <= 500),
  primary key (user_id, created_at)
);

create index idx_moods_user_created
  on public.moods (user_id, created_at desc);
