create table public.weekly_summaries (
    id uuid primary key default gen_random_uuid(),
    mother_id uuid not null references public.profiles(user_id) on delete cascade,
    period_start date not null,
    period_end date not null,
    audience text not null
        check (audience in ('mother', 'companion', 'professional')),
    status text not null
        check (status in ('completed', 'partial', 'failed')),
    overview text,
    limitations jsonb not null default '[]'::jsonb
        check (jsonb_typeof(limitations) = 'array'),
    source_refs jsonb not null default '[]'::jsonb
        check (jsonb_typeof(source_refs) = 'array'),
    prompt_version text not null,
    schema_version text not null default '1',
    created_at timestamptz not null default now(),

    constraint weekly_summaries_period_check
        check (
            extract(isodow from period_start) = 1
            and period_end = period_start + 6
        ),

    constraint weekly_summaries_status_check
        check (
            (status = 'completed' and overview is not null)
            or (
                status = 'partial'
                and (overview is null or overview is not null)
            )
            or (status = 'failed' and overview is null)
        ),

    constraint weekly_summaries_unique_period_audience
        unique (mother_id, period_start, audience)
);

create index weekly_summaries_mother_period_idx
    on public.weekly_summaries (mother_id, period_start desc);

alter table public.weekly_summaries enable row level security;

revoke all on table public.weekly_summaries from anon, authenticated;