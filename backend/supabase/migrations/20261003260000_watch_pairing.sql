-- Watch ↔ phone pairing through a short code (the two emulators can't see each other over Bluetooth).
--   Watch:  POST /rest/v1/rpc/pairing_start   {"p_device_id": "<watch id>"}           → {"code":"482913","expires_at":…}
--   Phone:  POST /rest/v1/rpc/pairing_claim   {"p_code": "482913"}                     → {"device_id":…,"token":…}
--                                                     or {"error":"INVALID_CODE"|"RATE_LIMITED"} (HTTP 200: an exception
--                                                     would roll back the failure record the rate limit counts)
--   Watch:  POST /rest/v1/rpc/pairing_status  {"p_device_id": "<watch id>"}           → {"status":"PENDING|PAIRED|EXPIRED|NONE",…}
--   Phone:  POST /rest/v1/rpc/pairing_device  {"p_token": "<token>"}                   → "<watch id>" or null (unpaired)
-- One active pairing per watch: a new claim replaces the previous phone. Codes are single-use, valid 5 minutes,
-- and failed claims are rate-limited. Only a SHA-256 hash of the phone's token is stored. The token is not yet
-- used for row access (planned: RLS on watch_metrics keyed by the token).

create table if not exists public.watch_pairings (
  device_id       text primary key check (char_length(device_id) between 3 and 64),
  code            text check (code ~ '^[0-9]{6}$'),
  code_started_at timestamptz,
  code_expires_at timestamptz,
  token_hash      text,
  claimed_at      timestamptz,
  created_at      timestamptz not null default now()
);

create unique index if not exists watch_pairings_active_code_idx on public.watch_pairings (code) where code is not null;

create table if not exists public.watch_pairing_failures (
  id bigint generated always as identity primary key,
  ts timestamptz not null default now()
);

-- Functions only: no direct anon access to either table.
alter table public.watch_pairings enable row level security;
alter table public.watch_pairing_failures enable row level security;

create or replace function public.pairing_start(p_device_id text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  tries int := 0;
begin
  if p_device_id is null or char_length(p_device_id) not between 3 and 64 then
    raise exception 'invalid device id';
  end if;
  -- Expired codes free their number.
  update watch_pairings set code = null where code is not null and code_expires_at < now();
  loop
    new_code := lpad((('x' || substr(md5(gen_random_uuid()::text), 1, 8))::bit(32)::bigint % 1000000)::text, 6, '0');
    exit when not exists (select 1 from watch_pairings where code = new_code);
    tries := tries + 1;
    if tries > 20 then
      raise exception 'could not allocate a pairing code, try again';
    end if;
  end loop;
  insert into watch_pairings (device_id, code, code_started_at, code_expires_at)
  values (p_device_id, new_code, now(), now() + interval '5 minutes')
  on conflict (device_id) do update
    set code = excluded.code, code_started_at = excluded.code_started_at, code_expires_at = excluded.code_expires_at;
  return json_build_object('code', new_code, 'expires_at', now() + interval '5 minutes');
end;
$$;

create or replace function public.pairing_claim(p_code text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  dev text;
  tok text;
begin
  -- Rate limit: 6-digit codes are only safe if guessing is slow.
  if (select count(*) from watch_pairing_failures where ts > now() - interval '5 minutes') >= 30 then
    return json_build_object('error', 'RATE_LIMITED');
  end if;
  if p_code is null or p_code !~ '^[0-9]{6}$' then
    insert into watch_pairing_failures default values;
    return json_build_object('error', 'INVALID_CODE');
  end if;
  select device_id into dev from watch_pairings
  where code = p_code and code_expires_at > now()
  for update;
  if dev is null then
    insert into watch_pairing_failures default values;
    return json_build_object('error', 'INVALID_CODE');
  end if;
  tok := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  update watch_pairings
    set code = null, code_expires_at = null, claimed_at = now(),
        token_hash = encode(sha256(convert_to(tok, 'UTF8')), 'hex')
  where device_id = dev;
  delete from watch_pairing_failures where ts < now() - interval '1 hour';
  return json_build_object('device_id', dev, 'token', tok);
end;
$$;

create or replace function public.pairing_status(p_device_id text)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r watch_pairings%rowtype;
begin
  select * into r from watch_pairings where device_id = p_device_id;
  if not found then
    return json_build_object('status', 'NONE');
  end if;
  if r.code is not null and r.code_expires_at > now() then
    return json_build_object('status', 'PENDING', 'expires_at', r.code_expires_at,
                             'paired_before', r.claimed_at is not null);
  end if;
  if r.claimed_at is not null then
    -- Paired (if a newer code expired unclaimed, the previous phone simply stays paired).
    return json_build_object('status', 'PAIRED', 'claimed_at', r.claimed_at);
  end if;
  return json_build_object('status', 'EXPIRED');
end;
$$;

-- The phone checks its pairing is still current (a newer phone may have replaced it).
create or replace function public.pairing_device(p_token text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select device_id from watch_pairings
  where p_token is not null and token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex');
$$;

revoke all on function public.pairing_start(text), public.pairing_claim(text), public.pairing_status(text),
  public.pairing_device(text) from public;
grant execute on function public.pairing_start(text), public.pairing_claim(text), public.pairing_status(text),
  public.pairing_device(text) to anon;
