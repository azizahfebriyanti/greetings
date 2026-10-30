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

create policy "anyone can read" on entries for select using (true);

create policy "only the owner writes" on entries for all to authenticated
  using ((auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com')
  with check ((auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');

-- Supabase no longer exposes new tables to its API automatically (2026), so grant access explicitly.
-- The policies above still decide who may do what; these lines only let the requests reach the table.
grant select on public.entries to anon, authenticated;
grant insert, update, delete on public.entries to authenticated;

insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

create policy "only the owner uploads photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (auth.jwt() ->> 'email') = 'azizahfebriyanti20@gmail.com');