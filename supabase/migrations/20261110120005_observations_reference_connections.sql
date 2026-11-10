alter table public.observations
  add column connection_id uuid
    references public.connections (id) on delete cascade;

update public.observations as o
set connection_id = c.id
from (
  select distinct on (mother_id, counterpart_id)
         id, mother_id, counterpart_id
    from public.connections
   where counterpart_role = 'companion'
   order by mother_id,
            counterpart_id,
            (ended_at is null) desc,
            connected_at desc
) as c
where c.mother_id = o.mother_id
  and c.counterpart_id = o.companion_id;

do $$
declare
  orphans bigint;
begin
  select count(*) into orphans
    from public.observations
   where connection_id is null;
  if orphans > 0 then
    raise exception
      'Cannot backfill connection_id for % observation(s); delete them or create the matching Connections first',
      orphans;
  end if;
end;
$$;

alter table public.observations
  alter column connection_id set not null;

alter table public.observations
  drop constraint observations_companion_id_mother_id_day_key;

alter table public.observations
  drop column companion_id,
  drop column mother_id;

alter table public.observations
  add constraint observations_connection_id_day_key
    unique (connection_id, day);
