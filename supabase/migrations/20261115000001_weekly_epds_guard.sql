-- First assessment: registration + 168 hours. Later: latest assessment + 168 hours.
-- Existing records remain intact. Serialize new submissions per mother.
create or replace function public.enforce_weekly_epds()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  registered_at timestamptz;
  latest_at timestamptz;
  next_at timestamptz;
begin
  select u.created_at into registered_at from auth.users u where u.id = new.mother_id;
  if registered_at is null then
    raise exception using errcode = '23503', message = 'Akun ibu tidak ditemukan.';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(new.mother_id::text, 0));
  select max(e.created_at) into latest_at
    from public.epds_assessments e where e.mother_id = new.mother_id;
  next_at := registered_at + interval '168 hours';
  if latest_at is not null then
    next_at := greatest(next_at, latest_at + interval '168 hours');
  end if;
  new.created_at := now();
  if new.created_at < next_at then
    if latest_at is not null then
      raise exception using errcode = '23505',
        message = 'EPDS dapat diisi lagi 7 hari setelah pengisian terakhir.';
    else
      raise exception using errcode = 'P0002',
        message = 'EPDS pertama dapat diisi 7 hari setelah daftar.';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_weekly_epds() from public;
drop trigger if exists weekly_epds_guard on public.epds_assessments;
create trigger weekly_epds_guard
before insert on public.epds_assessments
for each row execute function public.enforce_weekly_epds();
