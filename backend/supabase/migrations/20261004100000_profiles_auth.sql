-- Accounts (Workstream B1/B2): one profile document per signed-in user.
--
-- The live project has a leftover trigger `on_auth_user_created` → `public.handle_new_user()` that inserts into a
-- `public.profiles(id, display_name)` table which does not exist, so every sign-up fails with "Database error saving
-- new user". Drop both; the phone creates its own row on the first profile push, so no trigger is needed.
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

-- The phone's profile (model/Profile.ets) and medicines, as one JSON document. The phone's encrypted RDB stays the
-- copy the UI reads; this row is the account backup. Sync is last-write-wins on updated_at, which the phone sets
-- from Profile.updatedAt (the time of the local edit), not the time of the upload.
create table if not exists public.profiles (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  constraint profiles_data_is_object check (jsonb_typeof(data) = 'object'),
  constraint profiles_data_size check (pg_column_size(data) <= 65536)
);

comment on table public.profiles is
  'One profile document per user (Celia phone app). RLS: each user reads and writes only their own row.';

alter table public.profiles enable row level security;

-- Only signed-in users, only their own row. Nothing for anon.
revoke all on table public.profiles from anon;
revoke all on table public.profiles from authenticated;
grant select, insert, update, delete on table public.profiles to authenticated;

create policy profiles_select_own on public.profiles
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy profiles_update_own on public.profiles
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy profiles_delete_own on public.profiles
  for delete to authenticated
  using ((select auth.uid()) = user_id);
