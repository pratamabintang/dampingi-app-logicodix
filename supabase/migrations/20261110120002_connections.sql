create table public.connections (
  id uuid primary key default gen_random_uuid(),
  mother_id uuid not null references public.profiles (user_id) on delete cascade,
  counterpart_id uuid not null references public.profiles (user_id) on delete cascade,
  counterpart_role text not null check (counterpart_role in ('companion', 'professional')),
  connected_at timestamptz not null default now(),
  ended_at timestamptz,
  ended_by uuid references public.profiles (user_id) on delete set null,

  constraint connections_distinct_ends check (mother_id <> counterpart_id),
  constraint connections_ended_after_connected
    check (ended_at is null or ended_at >= connected_at)
);

create unique index uq_connections_one_professional_per_mother
  on public.connections (mother_id)
  where ended_at is null and counterpart_role = 'professional';

create unique index uq_connections_one_mother_per_companion
  on public.connections (counterpart_id)
  where ended_at is null and counterpart_role = 'companion';

create index idx_connections_mother
  on public.connections (mother_id, connected_at desc);

create index idx_connections_counterpart
  on public.connections (counterpart_id, connected_at desc);

create table public.invite_codes (
  id uuid primary key default gen_random_uuid(),
  issuer_id uuid not null references public.profiles (user_id) on delete cascade,
  target_role text not null check (target_role in ('mother', 'companion', 'professional')),
  code text not null check (code ~ '^[A-HJKMNP-Z2-9]{4}-[A-HJKMNP-Z2-9]{4}$'),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  redeemed_at timestamptz,
  redeemed_by uuid references public.profiles (user_id) on delete set null,
  revoked_at timestamptz,

  constraint invite_codes_expires_after_created check (expires_at > created_at),
  constraint invite_codes_not_both_redeemed_and_revoked
    check (redeemed_at is null or revoked_at is null)
);

create unique index uq_invite_codes_code_unspent
  on public.invite_codes (code)
  where redeemed_at is null and revoked_at is null;

create index idx_invite_codes_issuer
  on public.invite_codes (issuer_id, created_at desc);

create index idx_invite_codes_code
  on public.invite_codes (code);
