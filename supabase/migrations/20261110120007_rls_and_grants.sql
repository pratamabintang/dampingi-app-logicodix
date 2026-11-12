alter table public.profiles           enable row level security;
alter table public.moods              enable row level security;
alter table public.journals           enable row level security;
alter table public.connections        enable row level security;
alter table public.invite_codes       enable row level security;
alter table public.observations       enable row level security;
alter table public.professional_notes enable row level security;

revoke all on table public.profiles           from anon, authenticated;
revoke all on table public.moods              from anon, authenticated;
revoke all on table public.journals           from anon, authenticated;
revoke all on table public.connections        from anon, authenticated;
revoke all on table public.invite_codes       from anon, authenticated;
revoke all on table public.observations       from anon, authenticated;
revoke all on table public.professional_notes from anon, authenticated;

revoke all on all sequences in schema public from anon, authenticated;

do $$
declare
  t record;
begin
  for t in
    select c.relname
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind = 'r'
       and has_table_privilege('anon', c.oid, 'select')
  loop
    execute format('alter table public.%I enable row level security', t.relname);
    execute format('revoke all on table public.%I from anon, authenticated', t.relname);
  end loop;
end $$;
