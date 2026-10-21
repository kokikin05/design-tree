-- =====================================================================
-- Design Tree — Supabase schema
-- Paste this whole file into Supabase → SQL Editor → New query → Run.
-- It is safe to run on a fresh project. It creates:
--   profiles, boards, board_invites, media, designers  (+ row level security)
--   a public storage bucket "media" for uploaded images
--   helper functions: username_available(), has_board_invite()
-- =====================================================================

-- ---------- profiles: one per account, created automatically at sign-up ----------
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text not null unique check (username ~ '^[A-Za-z0-9_.-]{2,32}$'),
  bio           text not null default '' check (char_length(bio) <= 600),
  avatar_path   text,
  fav_designers text[] not null default '{}',
  fav_decades   int[]  not null default '{}',
  created_at    timestamptz not null default now()
);

-- ---------- boards ("pins"): a named collection of designers and media ----------
create table if not exists public.boards (
  id            uuid primary key default gen_random_uuid(),
  owner         uuid not null references public.profiles(id) on delete cascade,
  name          text not null check (char_length(name) between 1 and 80),
  description   text not null default '' check (char_length(description) <= 1000),
  cover_path    text,
  designers     text[] not null default '{}',
  media         uuid[] not null default '{}',
  collaborators uuid[] not null default '{}',
  is_public     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists boards_owner_idx on public.boards(owner);
create index if not exists boards_collab_idx on public.boards using gin(collaborators);

-- ---------- invitations to collaborate on a board, by e-mail ----------
create table if not exists public.board_invites (
  id          uuid primary key default gen_random_uuid(),
  board_id    uuid not null references public.boards(id) on delete cascade,
  board_name  text not null default '',
  email       text not null check (email = lower(email)),
  invited_by  uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (board_id, email)
);

-- ---------- media: images people upload for a designer ----------
create table if not exists public.media (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null references public.profiles(id) on delete cascade,
  designer    text not null,                 -- built-in designer id, or a designers.slug
  title       text not null default '' check (char_length(title) <= 200),
  description text not null default '' check (char_length(description) <= 1000),
  year        text not null default '' check (char_length(year) <= 20),
  path        text not null,                 -- object path inside the "media" bucket
  mime        text,
  width       int,
  height      int,
  created_at  timestamptz not null default now()
);
create index if not exists media_designer_idx on public.media(designer);
create index if not exists media_owner_idx on public.media(owner);

-- ---------- designers people add to the tree ----------
create table if not exists public.designers (
  id         uuid primary key default gen_random_uuid(),
  owner      uuid not null references public.profiles(id) on delete cascade,
  slug       text not null unique check (slug ~ '^c-[a-z0-9-]{2,60}$'),
  name_en    text not null check (char_length(name_en) between 1 and 80),
  name_ja    text not null default '' check (char_length(name_ja) <= 80),
  born       int check (born between 1800 and 2030),
  died       int check (died is null or died between 1800 and 2100),
  disc       text not null check (disc in ('g','t','a','d','s','p','f')),
  note       text not null default '' check (char_length(note) <= 600),
  website    text check (website is null or website ~ '^https?://'),
  created_at timestamptz not null default now()
);

-- =====================================================================
-- Functions and triggers
-- =====================================================================

-- Lets the sign-up form check a username before the account exists (profiles are public anyway).
create or replace function public.username_available(name text)
returns boolean language sql stable set search_path = public as $$
  select not exists (select 1 from public.profiles where lower(username) = lower(name));
$$;
grant execute on function public.username_available(text) to anon, authenticated;

-- True when the signed-in person's e-mail has a pending invitation to board b.
create or replace function public.has_board_invite(b uuid)
returns boolean language sql stable set search_path = public as $$
  select exists (select 1 from public.board_invites i
                 where i.board_id = b and i.email = lower(coalesce((select auth.jwt())->>'email', '')));
$$;

-- Only the owner may change ownership, visibility or the collaborator list.
-- Someone with a pending invitation can do exactly one thing: add themselves as a collaborator.
create or replace function public.boards_guard()
returns trigger language plpgsql set search_path = public as $$
begin
  if auth.uid() is distinct from old.owner then
    new.owner := old.owner;
    new.is_public := old.is_public;
    if not (auth.uid() = any(old.collaborators)) then
      new.name := old.name; new.description := old.description; new.cover_path := old.cover_path;
      new.designers := old.designers; new.media := old.media;
      if public.has_board_invite(old.id) then
        new.collaborators := array(select distinct unnest(old.collaborators || auth.uid()));
      else
        new.collaborators := old.collaborators;
      end if;
    else
      new.collaborators := old.collaborators;
    end if;
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists boards_guard on public.boards;
create trigger boards_guard
  before update on public.boards
  for each row execute function public.boards_guard();

-- (No security-definer functions: the site creates each profile row itself on first login,
--  from the username and favourites saved with the account at sign-up.)

-- =====================================================================
-- Row level security
-- =====================================================================
alter table public.profiles      enable row level security;
alter table public.boards        enable row level security;
alter table public.board_invites enable row level security;
alter table public.media         enable row level security;
alter table public.designers     enable row level security;

-- profiles: anyone can read; you can edit only your own
drop policy if exists "profiles read"   on public.profiles;
drop policy if exists "profiles update" on public.profiles;
drop policy if exists "profiles insert" on public.profiles;
create policy "profiles read"   on public.profiles for select using (true);
create policy "profiles insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles update" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

-- boards: public ones are readable by everyone; private ones by owner and collaborators
drop policy if exists "boards read"   on public.boards;
drop policy if exists "boards insert" on public.boards;
drop policy if exists "boards update" on public.boards;
drop policy if exists "boards delete" on public.boards;
create policy "boards read"   on public.boards for select
  using (is_public or owner = auth.uid() or auth.uid() = any(collaborators) or public.has_board_invite(id));
create policy "boards insert" on public.boards for insert
  with check (owner = auth.uid());
create policy "boards update" on public.boards for update
  using (owner = auth.uid() or auth.uid() = any(collaborators) or public.has_board_invite(id))
  with check (owner = auth.uid() or auth.uid() = any(collaborators) or public.has_board_invite(id));
create policy "boards delete" on public.boards for delete
  using (owner = auth.uid());

-- invites: the board owner creates them; the owner and the invited e-mail can see or remove them
drop policy if exists "invites read"   on public.board_invites;
drop policy if exists "invites insert" on public.board_invites;
drop policy if exists "invites delete" on public.board_invites;
create policy "invites read" on public.board_invites for select
  using (invited_by = auth.uid() or email = lower(coalesce(auth.jwt()->>'email', '')));
create policy "invites insert" on public.board_invites for insert
  with check (invited_by = auth.uid()
              and exists (select 1 from public.boards b where b.id = board_id and b.owner = auth.uid()));
create policy "invites delete" on public.board_invites for delete
  using (invited_by = auth.uid() or email = lower(coalesce(auth.jwt()->>'email', '')));

-- media: anyone can see; you add, edit and delete your own
drop policy if exists "media read"   on public.media;
drop policy if exists "media insert" on public.media;
drop policy if exists "media update" on public.media;
drop policy if exists "media delete" on public.media;
create policy "media read"   on public.media for select using (true);
create policy "media insert" on public.media for insert with check (owner = auth.uid());
create policy "media update" on public.media for update using (owner = auth.uid()) with check (owner = auth.uid());
create policy "media delete" on public.media for delete using (owner = auth.uid());

-- designers: anyone can see; you add, edit and delete the ones you added
drop policy if exists "designers read"   on public.designers;
drop policy if exists "designers insert" on public.designers;
drop policy if exists "designers update" on public.designers;
drop policy if exists "designers delete" on public.designers;
create policy "designers read"   on public.designers for select using (true);
create policy "designers insert" on public.designers for insert with check (owner = auth.uid());
create policy "designers update" on public.designers for update using (owner = auth.uid()) with check (owner = auth.uid());
create policy "designers delete" on public.designers for delete using (owner = auth.uid());

-- =====================================================================
-- Storage: public bucket "media"; each account writes only inside its own folder (<user id>/...)
-- =====================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 10485760, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public = true;

drop policy if exists "media files read"   on storage.objects;
drop policy if exists "media files own read" on storage.objects;
drop policy if exists "media files insert" on storage.objects;
drop policy if exists "media files update" on storage.objects;
drop policy if exists "media files delete" on storage.objects;
create policy "media files own read" on storage.objects for select to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "media files insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "media files update" on storage.objects for update to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "media files delete" on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text);
