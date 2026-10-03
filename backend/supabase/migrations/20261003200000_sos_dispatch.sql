-- SOS dispatch: when the watch inserts an `sos` row, call the `sos` Edge Function, which texts and calls the
-- emergency contacts (backend/supabase/functions/sos). The watch itself never dials.
--
-- One-time setup per project (secrets live in Vault, never in git):
--   select vault.create_secret('https://<project-ref>.supabase.co/functions/v1/sos', 'sos_function_url');
--   select vault.create_secret('<random string, same as the SOS_WEBHOOK_SECRET function secret>', 'sos_webhook_secret');
-- Without these secrets the trigger logs a warning and does nothing; inserts never fail because of SOS dispatch.

create extension if not exists pg_net;

-- 1. Patient display name for the alert text ("Anna may have fainted"). Optional; set by the phone app.
alter table public.watch_context add column if not exists patient_name text
  check (patient_name is null or char_length(patient_name) between 1 and 40);

-- 2. Emergency contacts. Personal data: anon (phone app) may add contacts but never read them back.
--    The Edge Function reads them with the service role.
create table if not exists public.emergency_contacts (
  id         bigint generated always as identity primary key,
  device_id  text        not null check (char_length(device_id) between 3 and 64),
  name       text        not null check (char_length(name) between 1 and 40),
  phone      text        not null check (phone ~ '^\+[1-9][0-9]{6,14}$'),
  priority   smallint    not null default 1 check (priority between 1 and 9),
  created_at timestamptz not null default now(),
  unique (device_id, phone)
);

alter table public.emergency_contacts enable row level security;

drop policy if exists "emergency_contacts anon insert" on public.emergency_contacts;
create policy "emergency_contacts anon insert" on public.emergency_contacts
  for insert to anon with check (true);

-- 3. Audit log of every dispatch attempt (also drives the cooldown). Service role only; no phone numbers inside.
create table if not exists public.sos_dispatches (
  id         bigint generated always as identity primary key,
  metric_id  bigint      references public.watch_metrics (id) on delete set null,
  device_id  text        not null,
  status     text        not null check (status in ('sent', 'partial', 'failed', 'dry_run', 'skipped_cooldown', 'no_contacts')),
  detail     jsonb       not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists sos_dispatches_device_time_idx on public.sos_dispatches (device_id, created_at desc);

alter table public.sos_dispatches enable row level security;

-- 4. Trigger: fire-and-forget HTTP call (pg_net is async, so the watch's insert is not slowed down).
create or replace function public.notify_sos() returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  fn_url text;
  fn_secret text;
begin
  select decrypted_secret into fn_url from vault.decrypted_secrets where name = 'sos_function_url';
  select decrypted_secret into fn_secret from vault.decrypted_secrets where name = 'sos_webhook_secret';
  if fn_url is null or fn_secret is null then
    raise warning 'notify_sos: vault secrets sos_function_url / sos_webhook_secret missing, SOS % not dispatched', new.id;
    return new;
  end if;

  perform net.http_post(
    url := fn_url,
    body := jsonb_build_object('record', to_jsonb(new)),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-sos-secret', fn_secret),
    timeout_milliseconds := 30000
  );
  return new;
exception when others then
  -- Never lose the watch's row because dispatch failed; the row itself is still visible to the phone app.
  raise warning 'notify_sos: dispatch for % failed: %', new.id, sqlerrm;
  return new;
end;
$$;

revoke all on function public.notify_sos() from public, anon, authenticated;

drop trigger if exists watch_metrics_sos_notify on public.watch_metrics;
create trigger watch_metrics_sos_notify
  after insert on public.watch_metrics
  for each row
  when (new.type = 'sos')
  execute function public.notify_sos();
