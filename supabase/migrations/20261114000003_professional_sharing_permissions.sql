alter table public.connections
  add column share_weekly_summary boolean not null default false,
  add column share_epds boolean not null default false,
  add column share_journal boolean not null default false;
