-- SETUP (about 10 minutes, all free)
-- 1. supabase.com > New project. Authentication > Sign In / Providers: turn OFF "Allow new users to sign up".
-- 2. Authentication > Users > Add user: your email + a strong password. This is the only login that can write.
-- 3. Replace YOUR_EMAIL below (3 places) with that same email, paste this whole file into SQL Editor, Run.
-- 4. Project Settings > API: copy the Project URL and the public key into config.js.
-- 5. Put index.html, admin.html and config.js on GitHub Pages (or Netlify / Vercel / Cloudflare Pages).
--    Rename admin.html to something only you know, and never link to it.
-- Your letters and photos live in Supabase, not in the repo, so pushing the code to GitHub does not expose them.

create table if not exists entries (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('letter','song','hadith','reason','place')),
  day date not null default current_date,
  title text default '',
  body text default '',
  meta jsonb not null default '{}',
  created_at timestamptz not null default now()
);

alter table entries enable row level security;

drop policy if exists "anyone can read" on entries;
create policy "anyone can read" on entries for select using (true);

drop policy if exists "only the owner writes" on entries;
create policy "only the owner writes" on entries for all to authenticated
  using ((auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com')
  with check ((auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');

-- Supabase no longer exposes new tables to its API automatically (2026), so grant access explicitly.
-- The policies above still decide who may do what; these lines only let the requests reach the table.
grant select on public.entries to anon, authenticated;
grant insert, update, delete on public.entries to authenticated;

-- A reader can leave one emoji reaction per browser for each letter.
create table if not exists letter_reactions (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references entries(id) on delete cascade,
  visitor_id text not null,
  reaction text not null check (reaction in ('❤️','🥹','🥰','🌷','😂')),
  created_at timestamptz not null default now(),
  unique (entry_id, visitor_id)
);

alter table letter_reactions enable row level security;
drop policy if exists "anyone can add letter reactions" on letter_reactions;
create policy "anyone can add letter reactions" on letter_reactions
  for insert to anon, authenticated with check (true);
drop policy if exists "only the owner can read letter reactions" on letter_reactions;
create policy "only the owner can read letter reactions" on letter_reactions
  for select to authenticated using ((auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');
grant select on public.letter_reactions to authenticated;
grant insert on public.letter_reactions to anon, authenticated;

insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

drop policy if exists "only the owner uploads photos" on storage.objects;
create policy "only the owner uploads photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');

-- Audio and video for letter entries use a separate public bucket with a 100 MB limit.
insert into storage.buckets (id, name, public, file_size_limit)
values ('media', 'media', true, 104857600)
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit;

drop policy if exists "only the owner uploads letter media" on storage.objects;
create policy "only the owner uploads letter media" on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');
