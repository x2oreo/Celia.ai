-- Push Kit tokens under the account (B12, docs/research/push-kit.md).
-- The phone upserts its own token with the user's JWT; the `sos` function reads tokens with the service role to
-- push "SOS from your watch" to the owner's phone. Row access only through auth.uid(); nothing for anon, so this does
-- not repeat the open device-keyed tables. Deleting the user deletes their tokens.

create table if not exists public.push_tokens (
  user_id    uuid not null references auth.users on delete cascade,
  token      text not null check (char_length(token) between 16 and 512),
  platform   text not null default 'harmonyos' check (platform in ('harmonyos')),
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);

alter table public.push_tokens enable row level security;

drop policy if exists "own push tokens select" on public.push_tokens;
drop policy if exists "own push tokens insert" on public.push_tokens;
drop policy if exists "own push tokens update" on public.push_tokens;
drop policy if exists "own push tokens delete" on public.push_tokens;

create policy "own push tokens select" on public.push_tokens
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "own push tokens insert" on public.push_tokens
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "own push tokens update" on public.push_tokens
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own push tokens delete" on public.push_tokens
  for delete to authenticated using ((select auth.uid()) = user_id);

revoke all on public.push_tokens from anon;
