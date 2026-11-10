-- Riwayat chatbot (C). Hanya backend (secret key) yang mengakses tabel ini.

create table public.chat_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);

create index idx_chat_sessions_user_updated
  on public.chat_sessions (user_id, updated_at desc);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null,
  user_id uuid not null,
  role text not null check (role in ('user', 'assistant')),
  content text not null check (char_length(content) between 1 and 4000),
  -- clock_timestamp: dua baris yang di-insert sekaligus tetap punya urutan waktu
  created_at timestamptz not null default clock_timestamp(),
  -- pesan wajib milik pemilik sesi yang sama
  foreign key (session_id, user_id)
    references public.chat_sessions (id, user_id) on delete cascade
);

create index idx_chat_messages_session_created
  on public.chat_messages (session_id, created_at);

-- Setiap ada pesan baru, sesi naik ke atas daftar.
create or replace function public.chat_touch_session()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  update public.chat_sessions set updated_at = now() where id = new.session_id;
  return new;
end;
$$;

create trigger chat_messages_touch_session
  after insert on public.chat_messages
  for each row execute function public.chat_touch_session();

-- RLS aktif tanpa policy: aplikasi tidak bisa membaca langsung lewat anon key.
-- Semua akses lewat backend, yang selalu memfilter user_id.
alter table public.chat_sessions enable row level security;
alter table public.chat_messages enable row level security;