-- Rate limits per caller instead of per project (code review, 4 Oct).
--
-- 1. pairing_claim: failed claims were counted in one project-wide bucket (30 per 5 minutes), so one script sending
--    wrong codes blocked pairing for every user. Failures are now counted per caller (the signed-in account, else a
--    hash of the client address), 10 per 5 minutes. A much higher project-wide ceiling stays, so guessing a 6-digit
--    code through many addresses is still slow: 300 guesses per 5-minute code life is a 0.03% chance per code.
-- 2. ai_rate_take: a shared counter for the OpenAI-backed Edge Functions (agent, realtime-session, speak,
--    transcribe, vision-extract, box-identify deep search). Only the functions call it, with the service role key.
--    Callers are stored as salted hashes, never as addresses.

-- The caller of a PostgREST request: the account when signed in, else the client address (the LAST
-- x-forwarded-for hop; the first ones are client-supplied). Hashed, so no address is stored.
create or replace function public.request_caller()
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  headers json := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::json;
  ip text := coalesce(nullif(trim(headers ->> 'cf-connecting-ip'), ''),
                      nullif(trim(regexp_replace(coalesce(headers ->> 'x-forwarded-for', ''), '^.*,', '')), ''),
                      'unknown');
begin
  if auth.uid() is not null then
    return 'user:' || auth.uid()::text;
  end if;
  return 'ip:' || encode(sha256(convert_to('celia-pairing|' || ip, 'UTF8')), 'hex');
end;
$$;

revoke all on function public.request_caller() from public, anon, authenticated;

alter table public.watch_pairing_failures add column if not exists caller text not null default 'unknown';
create index if not exists watch_pairing_failures_caller_ts_idx on public.watch_pairing_failures (caller, ts);
create index if not exists watch_pairing_failures_ts_idx on public.watch_pairing_failures (ts);

-- pairing_claim (body from 20261004130000) with the per-caller limit.
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
  who text := public.request_caller();
begin
  -- Rate limit: 6-digit codes are only safe if guessing is slow. Per caller, so one caller cannot lock out others.
  if (select count(*) from watch_pairing_failures where caller = who and ts > now() - interval '5 minutes') >= 10
     or (select count(*) from watch_pairing_failures where ts > now() - interval '5 minutes') >= 300 then
    return json_build_object('error', 'RATE_LIMITED');
  end if;
  if p_code is null or p_code !~ '^[0-9]{6}$' then
    insert into watch_pairing_failures (caller) values (who);
    return json_build_object('error', 'INVALID_CODE');
  end if;
  select device_id, owned_from is not null into dev, claimed_before from watch_pairings
  where code = p_code and code_expires_at > now()
  for update;
  if dev is null then
    insert into watch_pairing_failures (caller) values (who);
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

revoke all on function public.pairing_claim(text) from public;
grant execute on function public.pairing_claim(text) to anon, authenticated;

-- 2. AI rate limit buckets. One row per allowed call; old rows are pruned as calls come in.
create table if not exists public.ai_rate_hits (
  id bigint generated always as identity primary key,
  bucket text not null check (char_length(bucket) between 1 and 160),
  ts timestamptz not null default now()
);
create index if not exists ai_rate_hits_bucket_ts_idx on public.ai_rate_hits (bucket, ts);
create index if not exists ai_rate_hits_ts_idx on public.ai_rate_hits (ts);
alter table public.ai_rate_hits enable row level security;   -- no policies: the function below is the only way in

-- True (and the call is counted) when `p_bucket` has had fewer than `p_max` calls in the last `p_window_seconds`.
create or replace function public.ai_rate_take(p_bucket text, p_max int, p_window_seconds int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(hashtext(p_bucket));   -- concurrent calls on one bucket count one after another
  if (select count(*) from ai_rate_hits
      where bucket = p_bucket and ts > now() - make_interval(secs => p_window_seconds)) >= p_max then
    return false;
  end if;
  insert into ai_rate_hits (bucket) values (p_bucket);
  if random() < 0.01 then
    delete from ai_rate_hits where ts < now() - interval '1 day';
  end if;
  return true;
end;
$$;

revoke all on function public.ai_rate_take(text, int, int) from public, anon, authenticated;
grant execute on function public.ai_rate_take(text, int, int) to service_role;
