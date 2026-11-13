
create table public.epds_assessments (
  id uuid primary key default gen_random_uuid(),
  mother_id uuid not null
    references public.profiles (user_id) on delete cascade,

  instrument text not null default 'EPDS-10',
  instrument_version text not null default 'demo-v1',
  evaluation_mode text not null default 'demo_only'
    check (evaluation_mode = 'demo_only'),

  answers jsonb not null,
  total_score integer not null
    check (total_score between 0 and 30),

  follow_up_required boolean not null,
  item10_positive boolean not null,
  immediate_review_required boolean not null,

  rules_version text not null,
  disclaimer text not null,

  created_at timestamptz not null default now(),

  constraint epds_answers_array
    check (jsonb_typeof(answers) = 'array'),

  constraint epds_answers_size
    check (
      case
        when jsonb_typeof(answers) = 'array'
          then jsonb_array_length(answers) = 10
        else false
      end
    ),

  constraint uq_epds_assessment_id_mother
    unique (id, mother_id)
);

create index idx_epds_assessments_mother_created
  on public.epds_assessments (mother_id, created_at desc);


create table public.alerts (
  id uuid primary key default gen_random_uuid(),

  mother_id uuid not null
    references public.profiles (user_id) on delete cascade,

  assessment_id uuid,

  alert_type text not null
    check (
      alert_type in (
        'demo_follow_up',
        'demo_immediate_review'
      )
    ),

  evaluation_mode text not null default 'demo_only'
    check (evaluation_mode = 'demo_only'),

  message text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,

  constraint fk_alert_assessment_mother
    foreign key (assessment_id, mother_id)
    references public.epds_assessments (id, mother_id)
    on delete set null (assessment_id)
);

create unique index uq_alerts_assessment_type
  on public.alerts (assessment_id, alert_type)
  where assessment_id is not null;

create index idx_alerts_mother_created
  on public.alerts (mother_id, created_at desc);


alter table public.epds_assessments enable row level security;
alter table public.alerts enable row level security;

revoke all on table public.epds_assessments from anon, authenticated;
revoke all on table public.alerts from anon, authenticated;
