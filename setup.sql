-- SETUP (about 10 minutes, all free). Re-run this file after app/database updates.
-- 1. Authentication > Sign In / Providers: turn OFF "Allow new users to sign up".
-- 2. Authentication > Users: keep your admin account and add one separate Satrio account.
--    Use the same Satrio email as CFG.visitorEmail in config.js; set a strong password for him.
-- 3. Replace both email addresses below with CFG.adminEmail and CFG.visitorEmail from config.js, then run this in SQL Editor.
-- 4. Keep the public anon/publishable key in config.js. Never put a service_role key in browser code.
-- 5. Put index.html, admin.html and config.js on GitHub Pages (or Netlify / Vercel / Cloudflare Pages).
-- The database returns entries and special days to invited accounts; only the admin can write posts.

create table if not exists entries (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('letter','song','hadith','reason','place','gallery')),
  day date not null default current_date,
  title text default '',
  body text default '',
  meta jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- Add Gallery to existing installations too. Re-running setup.sql remains safe.
alter table public.entries drop constraint if exists entries_kind_check;
alter table public.entries add constraint entries_kind_check
  check (kind in ('letter','song','hadith','reason','place','gallery'));

alter table entries enable row level security;

drop policy if exists "anyone can read" on entries;
drop policy if exists "only invited accounts can read entries" on entries;
create policy "only invited accounts can read entries" on entries for select to authenticated using (
  lower(coalesce(auth.jwt() ->> 'email','')) in ('azizahfebriyanti20@gmail.com','satriods547@gmail.com')
);

drop policy if exists "only the owner writes" on entries;
create policy "only the owner writes" on entries for all to authenticated
  using ((auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com')
  with check ((auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');

-- Supabase no longer exposes new tables to its API automatically (2026), so grant access explicitly.
-- The policies above still decide who may do what; these lines only let the requests reach the table.
revoke select on public.entries from anon;
grant select on public.entries to authenticated;
grant insert, update, delete on public.entries to authenticated;

-- A reader can leave one emoji reaction per browser for each letter.
create table if not exists letter_reactions (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references entries(id) on delete cascade,
  visitor_id text not null,
  reaction text not null check (reaction in ('❤️','🥹','🥰','🌷','😂')),
  context text not null default '#letter',
  latitude double precision,
  longitude double precision,
  accuracy double precision,
  created_at timestamptz not null default now(),
  unique (entry_id, visitor_id)
);

-- Additive migration for projects that already have the earlier reactions table.
alter table letter_reactions add column if not exists context text not null default '#letter';
alter table letter_reactions add column if not exists latitude double precision;
alter table letter_reactions add column if not exists longitude double precision;
alter table letter_reactions add column if not exists accuracy double precision;

alter table letter_reactions enable row level security;
drop policy if exists "anyone can add letter reactions" on letter_reactions;
create policy "anyone can add letter reactions" on letter_reactions
  for insert to authenticated with check (
    char_length(visitor_id) between 1 and 120
    and (latitude is null or latitude between -90 and 90)
    and (longitude is null or longitude between -180 and 180)
    and (accuracy is null or accuracy >= 0)
    and lower(coalesce(auth.jwt() ->> 'email','')) in ('azizahfebriyanti20@gmail.com','satriods547@gmail.com')
  );
drop policy if exists "only the owner can read letter reactions" on letter_reactions;
create policy "only the owner can read letter reactions" on letter_reactions
  for select to authenticated using ((auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');
drop policy if exists "only the owner can delete letter reactions" on letter_reactions;
create policy "only the owner can delete letter reactions" on letter_reactions
  for delete to authenticated using ((auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');
revoke all on table public.letter_reactions from anon, authenticated;
grant select on public.letter_reactions to authenticated;
revoke insert on public.letter_reactions from anon;
grant insert on public.letter_reactions to authenticated;
grant delete on public.letter_reactions to authenticated;

-- Gallery likes and comments: only the admin can publish posts; Satrio can react to them.
create table if not exists public.gallery_activity (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.entries(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  action text not null check (action in ('like','comment')),
  body text not null default '',
  created_at timestamptz not null default now(),
  check (
    (action = 'like' and body = '') or
    (action = 'comment' and char_length(trim(body)) between 1 and 2000)
  )
);
create unique index if not exists gallery_one_like_per_user
  on public.gallery_activity(entry_id,user_id) where action='like';
create index if not exists gallery_activity_by_entry
  on public.gallery_activity(entry_id,created_at);

alter table public.gallery_activity enable row level security;
drop policy if exists "invited accounts can read gallery activity" on public.gallery_activity;
create policy "invited accounts can read gallery activity" on public.gallery_activity
  for select to authenticated using (
    lower(coalesce(auth.jwt() ->> 'email','')) in ('azizahfebriyanti20@gmail.com','satriods547@gmail.com')
  );
drop policy if exists "visitor adds gallery activity" on public.gallery_activity;
create policy "visitor adds gallery activity" on public.gallery_activity
  for insert to authenticated with check (
    user_id = auth.uid()
    and lower(coalesce(auth.jwt() ->> 'email','')) = 'satriods547@gmail.com'
    and exists (select 1 from public.entries where entries.id = gallery_activity.entry_id and entries.kind = 'gallery')
    and (
      (action = 'like' and body = '') or
      (action = 'comment' and char_length(trim(body)) between 1 and 2000)
    )
  );
drop policy if exists "owner or visitor retracts gallery likes" on public.gallery_activity;
create policy "owner or visitor retracts gallery likes" on public.gallery_activity
  for delete to authenticated using (
    lower(coalesce(auth.jwt() ->> 'email','')) = 'azizahfebriyanti20@gmail.com'
    or (lower(coalesce(auth.jwt() ->> 'email','')) = 'satriods547@gmail.com' and user_id = auth.uid() and action = 'like')
  );
revoke all on table public.gallery_activity from anon, authenticated;
grant select, insert, delete on table public.gallery_activity to authenticated;

-- Public, editable-by-owner content for countdowns and special-day greetings.
create table if not exists public.site_settings (
  id text primary key,
  value jsonb not null default '{}',
  updated_at timestamptz not null default now()
);

alter table public.site_settings enable row level security;
drop policy if exists "anyone can read site settings" on public.site_settings;
drop policy if exists "only invited accounts can read site settings" on public.site_settings;
create policy "only invited accounts can read site settings" on public.site_settings
  for select to authenticated using (
    lower(coalesce(auth.jwt() ->> 'email','')) in ('azizahfebriyanti20@gmail.com','satriods547@gmail.com')
  );
drop policy if exists "only the owner inserts site settings" on public.site_settings;
create policy "only the owner inserts site settings" on public.site_settings
  for insert to authenticated with check ((auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');
drop policy if exists "only the owner updates site settings" on public.site_settings;
create policy "only the owner updates site settings" on public.site_settings
  for update to authenticated using ((auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com')
  with check ((auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');
revoke all on table public.site_settings from anon, authenticated;
revoke select on public.site_settings from anon;
grant select on public.site_settings to authenticated;
grant insert, update on public.site_settings to authenticated;

insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

drop policy if exists "only the owner uploads photos" on storage.objects;
create policy "only the owner uploads photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');

-- Audio and video for letters and gallery posts use a separate public bucket with a 100 MB limit.
insert into storage.buckets (id, name, public, file_size_limit)
values ('media', 'media', true, 104857600)
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit;

drop policy if exists "only the owner uploads letter media" on storage.objects;
create policy "only the owner uploads letter media" on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and (auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');

drop policy if exists "only the owner deletes letter media" on storage.objects;
create policy "only the owner deletes letter media" on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');

-- Refresh the REST API's schema cache so the new table and columns appear immediately.
notify pgrst, 'reload schema';
