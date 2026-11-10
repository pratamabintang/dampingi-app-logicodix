create table public.journals (
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at date not null,
  title text not null check (char_length(title) between 1 and 255),
  content text not null check (char_length(content) between 1 and 10000),
  primary key (user_id, created_at)
);

create index idx_journals_user_created
  on public.journals (user_id, created_at desc);
