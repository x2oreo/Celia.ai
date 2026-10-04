-- B9 (part 2 of 2): the watch gets its own secret, and the watch's remaining public-key paths require it.
--
-- pairing_start hands a watch a random secret the first time it asks for a code (only a SHA-256 hash is stored).
-- The watch sends it on every request in the `x-watch-secret` header (watch/…/sync/RestClient.ets); PostgREST exposes
-- request headers to SQL as `request.headers`. After this migration:
--   * watch_context is readable with the public key only by the watch holding the secret (or for the demo watch);
--   * a watch that has a secret must send it to insert into watch_metrics (a watch that never paired can still
--     upload under its random id; nobody can read those rows);
--   * pairing_start for a watch that has a secret needs that secret (nobody else can take over its pairing code);
--   * simulate_missed_beta_blocker needs the secret (or the demo watch).
--
-- DEPLOY ORDER: apply only together with the watch build that sends `x-watch-secret` - an older watch build loses
-- its context reads and, once it has paired again, its uploads. Retest both emulators (pair, upload, context, SOS).

alter table public.watch_pairings add column if not exists watch_secret_hash text;

create or replace function public.request_watch_secret()
returns text
language sql
stable
as $$
  select nullif(coalesce(current_setting('request.headers', true), '{}')::json ->> 'x-watch-secret', '');
$$;

-- True when the request carries this watch's secret.
create or replace function public.watch_secret_ok(p_device_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.request_watch_secret() is not null and exists (
    select 1 from watch_pairings
    where device_id = p_device_id
      and watch_secret_hash = encode(sha256(convert_to(public.request_watch_secret(), 'UTF8')), 'hex')
  );
$$;

-- Uploads: the demo watch, a watch proving its secret, or a watch that has never been given one.
create or replace function public.watch_write_ok(p_device_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_demo_device(p_device_id) or public.watch_secret_ok(p_device_id) or not exists (
    select 1 from watch_pairings where device_id = p_device_id and watch_secret_hash is not null
  );
$$;

revoke all on function public.request_watch_secret(), public.watch_secret_ok(text), public.watch_write_ok(text)
  from public;
grant execute on function public.request_watch_secret(), public.watch_secret_ok(text), public.watch_write_ok(text)
  to anon, authenticated;

create or replace function public.pairing_start(p_device_id text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  tries int := 0;
  has_secret boolean;
  secret text := null;
begin
  if p_device_id is null or char_length(p_device_id) not between 3 and 64 then
    raise exception 'invalid device id';
  end if;
  select watch_secret_hash is not null into has_secret from watch_pairings where device_id = p_device_id;
  if coalesce(has_secret, false) and not public.watch_secret_ok(p_device_id) then
    raise exception 'watch secret required' using errcode = '42501';
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
  if not coalesce(has_secret, false) then
    secret := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  end if;
  insert into watch_pairings (device_id, code, code_started_at, code_expires_at, watch_secret_hash)
  values (p_device_id, new_code, now(), now() + interval '5 minutes',
          case when secret is null then null else encode(sha256(convert_to(secret, 'UTF8')), 'hex') end)
  on conflict (device_id) do update
    set code = excluded.code, code_started_at = excluded.code_started_at, code_expires_at = excluded.code_expires_at,
        watch_secret_hash = coalesce(watch_pairings.watch_secret_hash, excluded.watch_secret_hash);
  -- The secret is returned once, when it is created; the watch keeps it.
  return json_build_object('code', new_code, 'expires_at', now() + interval '5 minutes', 'secret', secret);
end;
$$;

-- watch_metrics: uploads need the secret once the watch has one.
drop policy if exists "watch_metrics anon insert" on public.watch_metrics;
create policy "watch_metrics anon insert" on public.watch_metrics
  for insert to anon
  with check (recorded_at > now() - interval '7 days' and recorded_at < now() + interval '5 minutes'
              and public.watch_write_ok(device_id));

-- watch_context: the watch reads its own row with its secret; the open anon read is gone.
drop policy if exists "watch_context anon read" on public.watch_context;
drop policy if exists "watch_context watch read" on public.watch_context;
create policy "watch_context watch read" on public.watch_context
  for select to anon
  using (public.is_demo_device(device_id) or public.watch_secret_ok(device_id));

create or replace function public.simulate_missed_beta_blocker(p_device_id text, p_on boolean)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := (now() at time zone 'Europe/Warsaw')::date;
  i int;
begin
  if p_device_id is null or char_length(p_device_id) not between 3 and 64 then
    raise exception 'invalid device id';
  end if;
  if not (public.is_demo_device(p_device_id) or public.watch_secret_ok(p_device_id)) then
    raise exception 'watch secret required' using errcode = '42501';
  end if;
  delete from resting_day_sim where device_id = p_device_id;
  if not p_on then
    return 0;
  end if;
  -- ±1 bpm jitter so each run is a new pattern (the phone asks once per distinct pattern per day).
  for i in 1..16 loop
    insert into resting_day_sim (device_id, day, resting_bpm, rest_minutes)
    values (p_device_id, today - i,
            case when i <= 2 then 70 else 58 end + floor(random() * 3)::int - 1,
            420);
  end loop;
  return 16;
end;
$$;
