-- B9 (part 1 of 2): close the open read paths on watch data with the device ↔ account binding.
--
-- Before: anyone with the public key could read every device's heart data, SOS rows (with location) and context,
-- and overwrite any device's genotype. After this migration:
--   * the phone reads a paired watch's data only as the signed-in owner (watch_pairings.user_id = auth.uid(), set
--     by pairing_claim / pairing_bind in 20261004100100);
--   * the shared demo watch (`demo-watch-1`, simulated data the app shows before pairing) stays public;
--   * phone writes to watch_context (genotype, risky medicine, alert acknowledgement) need the owner too.
-- What still uses the public key until part 2 (watch secret, needs the watch build that sends it): the watch's own
-- inserts into watch_metrics, its read of watch_context, and the demo RPC simulate_missed_beta_blocker. Those rows
-- are keyed by a random per-watch UUID that can no longer be listed.
--
-- Apply together with the phone build that sends the user's JWT (common/Net.ets backendTarget) and binds pairings
-- (data/WatchPairing.ets), and retest both emulators: phone paired + signed in sees the watch; signed out it does not.

create or replace function public.is_demo_device(p_device_id text)
returns boolean
language sql
immutable
as $$
  select p_device_id = 'demo-watch-1';
$$;

grant execute on function public.is_demo_device(text) to anon, authenticated;

-- watch_metrics: reads by owner (or the demo watch). The watch's insert policy is unchanged here (part 2).
drop policy if exists "watch_metrics anon read" on public.watch_metrics;
drop policy if exists "watch_metrics read demo" on public.watch_metrics;
create policy "watch_metrics read demo" on public.watch_metrics
  for select to anon
  using (public.is_demo_device(device_id));
drop policy if exists "watch_metrics read own" on public.watch_metrics;
create policy "watch_metrics read own" on public.watch_metrics
  for select to authenticated
  using (public.is_demo_device(device_id) or public.device_owned(device_id));

-- The phone views are security_invoker, so the policies above apply to them; signed-in phones read them too.
grant select on public.watch_metrics_latest, public.watch_resting_daily, public.watch_status, public.watch_doses,
  public.watch_symptoms, public.watch_daily_summary, public.watch_insights to authenticated;

-- watch_context: the phone writes it as the owner. The watch still reads it with the public key (part 2 closes it);
-- names never live here (sync_sos_contacts keeps patient_name null, the name is in sos_profile).
drop policy if exists "watch_context anon insert" on public.watch_context;
drop policy if exists "watch_context anon update" on public.watch_context;
drop policy if exists "watch_context own read" on public.watch_context;
create policy "watch_context own read" on public.watch_context
  for select to authenticated
  using (public.is_demo_device(device_id) or public.device_owned(device_id));
drop policy if exists "watch_context own insert" on public.watch_context;
create policy "watch_context own insert" on public.watch_context
  for insert to authenticated
  with check (public.is_demo_device(device_id) or public.device_owned(device_id));
drop policy if exists "watch_context own update" on public.watch_context;
create policy "watch_context own update" on public.watch_context
  for update to authenticated
  using (public.is_demo_device(device_id) or public.device_owned(device_id))
  with check (public.is_demo_device(device_id) or public.device_owned(device_id));
grant select, insert, update on public.watch_context to authenticated;
update public.watch_context set patient_name = null where patient_name is not null;

-- resting_day_sim (simulated resting days): owner or demo.
drop policy if exists "resting_day_sim anon read" on public.resting_day_sim;
drop policy if exists "resting_day_sim read demo" on public.resting_day_sim;
create policy "resting_day_sim read demo" on public.resting_day_sim
  for select to anon
  using (public.is_demo_device(device_id));
drop policy if exists "resting_day_sim read own" on public.resting_day_sim;
create policy "resting_day_sim read own" on public.resting_day_sim
  for select to authenticated
  using (public.is_demo_device(device_id) or public.device_owned(device_id));
grant select on public.resting_day_sim to authenticated;

-- Phone RPCs that write watch_context: owner (or demo) only. Same bodies as before plus the check.
create or replace function public.set_watch_genotype(p_device_id text, p_genotype text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_device_id is null or char_length(p_device_id) not between 3 and 64 then
    raise exception 'invalid device id';
  end if;
  if not (public.is_demo_device(p_device_id) or public.device_owned(p_device_id)) then
    raise exception 'not your watch' using errcode = '42501';
  end if;
  if p_genotype not in ('LQT1', 'LQT2', 'LQT3', 'UNKNOWN') then
    raise exception 'invalid genotype';
  end if;
  insert into watch_context (device_id, genotype, updated_at)
  values (p_device_id, p_genotype, now())
  on conflict (device_id) do update set genotype = excluded.genotype, updated_at = now();
  return true;
end;
$$;

-- From 20261004050000_watch_alert_ack.sql (Workstream A): a phone "I'm fine" reaches the watch. Owner or demo.
create or replace function public.ack_watch_alert(p_device_id text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_device_id is null or char_length(p_device_id) not between 3 and 64 then
    raise exception 'invalid device id';
  end if;
  if not (public.is_demo_device(p_device_id) or public.device_owned(p_device_id)) then
    raise exception 'not your watch' using errcode = '42501';
  end if;
  insert into watch_context (device_id, alert_ack_at, updated_at)
  values (p_device_id, now(), now())
  on conflict (device_id) do update set alert_ack_at = now(), updated_at = now();
  return true;
end;
$$;

revoke all on function public.set_watch_genotype(text, text), public.ack_watch_alert(text) from public;
grant execute on function public.set_watch_genotype(text, text), public.ack_watch_alert(text) to anon, authenticated;
