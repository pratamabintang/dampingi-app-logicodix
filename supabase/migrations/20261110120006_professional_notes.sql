create table public.professional_notes (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null
    references public.connections (id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,

  constraint professional_notes_content_length
    check (char_length(btrim(content)) between 1 and 10000),
  constraint professional_notes_deleted_after_created
    check (deleted_at is null or deleted_at >= created_at)
);

create or replace function public.set_professional_notes_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger professional_notes_set_updated_at
  before update on public.professional_notes
  for each row execute function public.set_professional_notes_updated_at();

create index idx_professional_notes_connection_created
  on public.professional_notes (connection_id, created_at desc);
