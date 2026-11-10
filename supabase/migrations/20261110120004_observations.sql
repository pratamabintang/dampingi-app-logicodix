create table public.observations (
  id uuid primary key default gen_random_uuid(),
  companion_id uuid not null references public.profiles (user_id) on delete cascade,
  mother_id uuid not null references public.profiles (user_id) on delete cascade,
  questions jsonb not null,
  answers jsonb,
  day date,
  created_at timestamptz not null default now(),
  completed_at timestamptz,

  constraint observations_distinct_ends check (companion_id <> mother_id),
  constraint observations_questions_array
    check (jsonb_typeof(questions) = 'array'),
  constraint observations_questions_size
    check (
      case
        when jsonb_typeof(questions) = 'array'
          then jsonb_array_length(questions) between 1 and 50
        else false
      end
    ),
  constraint observations_answers_array
    check (answers is null or jsonb_typeof(answers) = 'array'),
  constraint observations_complete_or_draft
    check (
      (answers is null and day is null and completed_at is null)
      or (answers is not null and day is not null and completed_at is not null)
    ),
  unique (companion_id, mother_id, day)
);
