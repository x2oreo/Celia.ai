-- Watch readings belong to the account that owned the watch when they were recorded, not to whoever owns it now.
--
-- Before: `watch_metrics` rows were keyed only by device id and read through device_owned(), which checks the
-- current owner. A watch that changed hands showed the new owner the previous owner's whole history, and unpairing
-- on the phone was local only, so the old account kept reading the watch.
-- After:
--   * every row carries `user_id`, stamped by a trigger from watch_pairings at upload (clients cannot set it);
--   * the phone reads rows with user_id = auth.uid() (plus the public demo watch);
--   * `owned_from` marks where the current ownership period starts. A row recorded before it is never given to the
--     current owner, so a late upload from the previous period stays out of the new owner's history;
--   * rows uploaded while the watch had no account (a pairing claimed signed out) go to the account that binds that
--     pairing. A watch's first owner also gets what it recorded before it was ever paired;
--   * `pairing_unbind(token)` ends a pairing on the server: the account stops reading the watch and its SOS contacts
--     are removed. The readings it already owns stay with the account;
--   * deleting an account deletes its readings.
--
--   Phone:  POST /rest/v1/rpc/pairing_unbind  {"p_token": "<pairing token>"}   → true | false (unknown token)
--
-- Existing rows of a bound watch go to its current owner (same access as before this migration).

alter table public.watch_metrics add column if not exists user_id uuid references auth.users (id) on delete cascade;
create index if not exists watch_metrics_user_time_idx on public.watch_metrics (user_id, recorded_at desc);

alter table public.watch_pairings add column if not exists owned_from timestamptz;

-- Keep today's access for existing data: the current owner owns the watch's rows so far.
update public.watch_pairings set owned_from = '-infinity' where owned_from is null and claimed_at is not null;
update public.watch_metrics m set user_id = p.user_id
from public.watch_pairings p
where p.device_id = m.device_id and p.user_id is not null and m.user_id is null;

-- 1. Stamp the owner on upload. Security definer: the watch uploads with the public key and cannot read
--    watch_pairings. Whatever user_id a client sends is replaced.
create or replace function public.watch_metrics_stamp_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  p watch_pairings%rowtype;
begin
  new.user_id := null;
  select * into p from watch_pairings where device_id = new.device_id;
  if found and p.user_id is not null and new.recorded_at >= coalesce(p.owned_from, '-infinity') then
    new.user_id := p.user_id;
  end if;
  return new;
end;
$$;

revoke all on function public.watch_metrics_stamp_owner() from public, anon, authenticated;

drop trigger if exists watch_metrics_stamp_owner on public.watch_metrics;
create trigger watch_metrics_stamp_owner
  before insert on public.watch_metrics
  for each row execute function public.watch_metrics_stamp_owner();

-- 2. Reads: own rows, or the demo watch.
drop policy if exists "watch_metrics read own" on public.watch_metrics;
create policy "watch_metrics read own" on public.watch_metrics
  for select to authenticated
  using (public.is_demo_device(device_id) or user_id = auth.uid());

-- 3. Rows recorded in the current ownership period while nobody owned the watch go to `uid`.
create or replace function public.watch_adopt_rows(p_device_id text, p_uid uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update watch_metrics m set user_id = p_uid
  from watch_pairings p
  where p.device_id = p_device_id and m.device_id = p_device_id and m.user_id is null
    and m.recorded_at >= coalesce(p.owned_from, '-infinity');
$$;

revoke all on function public.watch_adopt_rows(text, uuid) from public, anon, authenticated;

-- 4. pairing_claim (body from 20261004100100) + the ownership period. The first claim ever starts it at -infinity,
--    so the first owner keeps what the watch recorded before pairing; a later claim starts it now.
create or replace function public.pairing_claim(p_code text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  dev text;
  tok text;
  claimed_before boolean;
begin
  -- Rate limit: 6-digit codes are only safe if guessing is slow.
  if (select count(*) from watch_pairing_failures where ts > now() - interval '5 minutes') >= 30 then
    return json_build_object('error', 'RATE_LIMITED');
  end if;
  if p_code is null or p_code !~ '^[0-9]{6}$' then
    insert into watch_pairing_failures default values;
    return json_build_object('error', 'INVALID_CODE');
  end if;
  select device_id, owned_from is not null into dev, claimed_before from watch_pairings
  where code = p_code and code_expires_at > now()
  for update;
  if dev is null then
    insert into watch_pairing_failures default values;
    return json_build_object('error', 'INVALID_CODE');
  end if;
  tok := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  update watch_pairings
    set code = null, code_expires_at = null, claimed_at = now(),
        token_hash = encode(sha256(convert_to(tok, 'UTF8')), 'hex'),
        user_id = auth.uid(),
        owned_from = case when claimed_before then now() else '-infinity'::timestamptz end
  where device_id = dev;
  if auth.uid() is not null then
    perform public.watch_adopt_rows(dev, auth.uid());
  end if;
  -- A new owner never inherits the previous owner's contacts or name.
  delete from emergency_contacts where device_id = dev and user_id is distinct from auth.uid();
  delete from sos_profile where device_id = dev and user_id is distinct from auth.uid();
  delete from watch_pairing_failures where ts < now() - interval '1 hour';
  return json_build_object('device_id', dev, 'token', tok);
end;
$$;

-- 5. pairing_bind (body from 20261004100100) + adopting the rows of this pairing. Another account taking over the
--    pairing (account switch on the same phone) starts a new period, so it never gets the earlier account's rows.
create or replace function public.pairing_bind(p_token text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  dev text;
  prev uuid;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_token is null or char_length(p_token) < 32 then
    return null;
  end if;
  select device_id, user_id into dev, prev from watch_pairings
  where token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex')
  for update;
  if dev is null then
    return null;
  end if;
  update watch_pairings
    set user_id = auth.uid(),
        owned_from = case when prev is not null and prev <> auth.uid() then now() else owned_from end
  where device_id = dev;
  perform public.watch_adopt_rows(dev, auth.uid());
  delete from emergency_contacts where device_id = dev and user_id is distinct from auth.uid();
  delete from sos_profile where device_id = dev and user_id is distinct from auth.uid();
  return dev;
end;
$$;

-- 6. End a pairing on the server. The token proves this phone is the paired one (signed in or not).
create or replace function public.pairing_unbind(p_token text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  dev text;
begin
  if p_token is null or char_length(p_token) < 32 then
    return false;
  end if;
  update watch_pairings
    set user_id = null, token_hash = null, claimed_at = null
  where token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex')
  returning device_id into dev;
  if dev is null then
    return false;
  end if;
  delete from emergency_contacts where device_id = dev;
  delete from sos_profile where device_id = dev;
  return true;
end;
$$;

revoke all on function public.pairing_claim(text), public.pairing_unbind(text) from public;
revoke all on function public.pairing_bind(text) from public, anon;
grant execute on function public.pairing_claim(text), public.pairing_unbind(text) to anon, authenticated;
grant execute on function public.pairing_bind(text) to authenticated;
