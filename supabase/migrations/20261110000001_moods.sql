create table public.moods (
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at date not null,
  mood text not null
    check (mood in ('very_low', 'low', 'neutral', 'good', 'very_good')),
  primary key (user_id, created_at)
);

create index idx_moods_user_created on public.moods (user_id, created_at desc);
