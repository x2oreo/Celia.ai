-- B10: emergency contacts reach the server, under the account, only with the user's consent.
--
-- Until now nothing wrote `emergency_contacts` or a patient name, so the `sos` function never had anyone to alert.
-- The phone now sends them (switch "Alert my contacts from my watch", off by default) through one RPC that only the
-- signed-in owner of the paired watch may call. The patient's first name moves to `sos_profile`, a table nobody can
-- read through the API (the `sos` function reads it with the service role); `watch_context` is readable by the watch
-- with the public key, so a name must not live there.
--
-- Binding a watch to an account: `pairing_claim` now records `auth.uid()` when the phone is signed in, and
-- `pairing_bind(token)` binds a pairing made before accounts (or while signed out) once the user signs in.
--
--   Phone (signed in):  POST /rest/v1/rpc/pairing_bind        {"p_token": "<pairing token>"}   → "<watch id>" | null
--   Phone (signed in):  POST /rest/v1/rpc/sync_sos_contacts   {"p_device_id", "p_contacts": [{name, phone}], "p_first_name"}
--                                                              → number of contacts saved (empty list + null name = clear)
--   Phone (signed in):  POST /rest/v1/rpc/sos_status          {"p_device_id"} → {"contacts": n, "has_name": bool,
--                                                              "last": {"status", "at", "contacts"} | null}

-- 1. Who owns a paired watch. Deleting the account unbinds the watch (its data stays keyed by the device id).
alter table public.watch_pairings add column if not exists user_id uuid references auth.users (id) on delete set null;
create index if not exists watch_pairings_user_idx on public.watch_pairings (user_id);

-- 2. Contacts belong to the account that sent them; deleting the account deletes them.
alter table public.emergency_contacts add column if not exists user_id uuid references auth.users (id) on delete cascade;
create index if not exists emergency_contacts_user_idx on public.emergency_contacts (user_id);

-- The anon insert path is gone: contacts are written only through sync_sos_contacts (owner check inside).
drop policy if exists "emergency_contacts anon insert" on public.emergency_contacts;
revoke all on table public.emergency_contacts from anon, authenticated;
revoke all on table public.sos_dispatches from anon, authenticated;

-- 3. The name used in the alert text ("Anna may have fainted"). Service role only.
create table if not exists public.sos_profile (
  device_id    text primary key check (char_length(device_id) between 3 and 64),
  user_id      uuid not null references auth.users (id) on delete cascade,
  patient_name text check (patient_name is null or char_length(patient_name) between 1 and 40),
  updated_at   timestamptz not null default now()
);
alter table public.sos_profile enable row level security;
revoke all on table public.sos_profile from anon, authenticated;

-- 4. Is this watch bound to the signed-in user? Used by the RPCs below and by the RLS policies in the next
--    migration. Security definer so it can read watch_pairings (which has no policies); it reveals one boolean.
create or replace function public.device_owned(p_device_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null and exists (
    select 1 from watch_pairings where device_id = p_device_id and user_id = auth.uid()
  );
$$;

revoke all on function public.device_owned(text) from public, anon;
grant execute on function public.device_owned(text) to authenticated;

-- 5. Claiming a code binds the watch to the signed-in user (null when claimed with the public key alone).
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
        token_hash = encode(sha256(convert_to(tok, 'UTF8')), 'hex'),
        user_id = auth.uid()
  where device_id = dev;
  -- A new owner never inherits the previous owner's contacts or name.
  delete from emergency_contacts where device_id = dev and user_id is distinct from auth.uid();
  delete from sos_profile where device_id = dev and user_id is distinct from auth.uid();
  delete from watch_pairing_failures where ts < now() - interval '1 hour';
  return json_build_object('device_id', dev, 'token', tok);
end;
$$;

-- 6. Bind an existing pairing (the phone holds its token) to the signed-in user.
create or replace function public.pairing_bind(p_token text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  dev text;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if p_token is null or char_length(p_token) < 32 then
    return null;
  end if;
  update watch_pairings set user_id = auth.uid()
  where token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex')
  returning device_id into dev;
  if dev is not null then
    delete from emergency_contacts where device_id = dev and user_id is distinct from auth.uid();
    delete from sos_profile where device_id = dev and user_id is distinct from auth.uid();
  end if;
  return dev;
end;
$$;

-- 7. Replace this watch's SOS contacts and first name. Owner only. At most 5 contacts; phones must already be E.164
--    (the phone normalises them); invalid entries are skipped, not fatal.
create or replace function public.sync_sos_contacts(p_device_id text, p_contacts jsonb, p_first_name text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  c jsonb;
  saved int := 0;
  nm text;
  ph text;
begin
  if not public.device_owned(p_device_id) then
    raise exception 'not your watch' using errcode = '42501';
  end if;
  if p_contacts is null or jsonb_typeof(p_contacts) <> 'array' then
    raise exception 'contacts must be an array';
  end if;
  delete from emergency_contacts where device_id = p_device_id;
  for c in select value from jsonb_array_elements(p_contacts) limit 5 loop
    nm := left(btrim(coalesce(c ->> 'name', '')), 40);
    ph := btrim(coalesce(c ->> 'phone', ''));
    if char_length(nm) >= 1 and ph ~ '^\+[1-9][0-9]{6,14}$' then
      insert into emergency_contacts (device_id, user_id, name, phone, priority)
      values (p_device_id, auth.uid(), nm, ph, saved + 1)
      on conflict (device_id, phone) do nothing;
      if found then
        saved := saved + 1;
      end if;
    end if;
  end loop;
  nm := nullif(left(btrim(coalesce(p_first_name, '')), 40), '');
  if nm is null and saved = 0 then
    delete from sos_profile where device_id = p_device_id;
  else
    insert into sos_profile (device_id, user_id, patient_name, updated_at)
    values (p_device_id, auth.uid(), nm, now())
    on conflict (device_id) do update
      set user_id = excluded.user_id, patient_name = excluded.patient_name, updated_at = now();
  end if;
  -- The old name column on watch_context is readable with the public key; never keep a name there.
  update watch_context set patient_name = null where device_id = p_device_id and patient_name is not null;
  return saved;
end;
$$;

-- 8. What the app shows under the switch: how many contacts the server has and the last dispatch attempt.
create or replace function public.sos_status(p_device_id text)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  last_row sos_dispatches%rowtype;
begin
  if not public.device_owned(p_device_id) then
    raise exception 'not your watch' using errcode = '42501';
  end if;
  select * into last_row from sos_dispatches where device_id = p_device_id order by created_at desc limit 1;
  return json_build_object(
    'contacts', (select count(*) from emergency_contacts where device_id = p_device_id),
    'has_name', exists (select 1 from sos_profile where device_id = p_device_id and patient_name is not null),
    'last', case when last_row.id is null then null else json_build_object(
      'status', last_row.status,
      'at', last_row.created_at,
      'contacts', coalesce((last_row.detail ->> 'contacts')::int, jsonb_array_length(coalesce(last_row.detail -> 'results', '[]'::jsonb)))
    ) end
  );
end;
$$;

revoke all on function public.pairing_bind(text), public.sync_sos_contacts(text, jsonb, text),
  public.sos_status(text) from public, anon;
grant execute on function public.pairing_bind(text), public.sync_sos_contacts(text, jsonb, text),
  public.sos_status(text) to authenticated;
