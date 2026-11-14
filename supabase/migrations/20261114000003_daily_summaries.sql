
create table public.daily_summaries (
    id uuid primary key default gen_random_uuid(),
    mother_id uuid not null references public.profiles(user_id) on delete cascade,
    summary_date date not null,
    status text not null check (status in ('completed', 'partial')),
    overview text,
    limitations jsonb not null default '[]'::jsonb
        check (jsonb_typeof(limitations) = 'array'),
    source_refs jsonb not null default '[]'::jsonb
        check (jsonb_typeof(source_refs) = 'array'),
    prompt_version text not null,
    schema_version text not null default '1',
    updated_at timestamptz not null default now(),

    constraint daily_summaries_unique_day
        unique (mother_id, summary_date)
);

create index daily_summaries_mother_date_idx
    on public.daily_summaries (mother_id, summary_date desc);

alter table public.daily_summaries enable row level security;

revoke all on table public.daily_summaries from anon, authenticated;
