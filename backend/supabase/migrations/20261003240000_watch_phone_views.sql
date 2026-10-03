-- Read-only views over watch_metrics for the phone app: what the watch logs that the phone does not derive from
-- heart-rate samples. Each is one GET, filtered by device:
--   GET /rest/v1/watch_status?device_id=eq.demo-watch-1
--   GET /rest/v1/watch_doses?device_id=eq.demo-watch-1&day=gte.2026-09-20&order=taken_at.desc
--   GET /rest/v1/watch_symptoms?device_id=eq.demo-watch-1&order=recorded_at.desc&limit=50
-- Days use Polish local time, like watch_resting_daily.

-- 1. Is the watch on the wrist, off the wrist, or not syncing? The watch stops sending heart rate while it is off
--    the wrist, so without this the phone can't tell "taken off" from "connection lost".
create or replace view public.watch_status
with (security_invoker = true) as
select
  d.device_id,
  coalesce(w.on_wrist, true)                         as on_wrist,
  w.changed_at                                       as wear_changed_at,
  d.last_sync,
  d.last_reading,
  case
    when d.last_sync < now() - interval '2 minutes' then 'OFFLINE'
    when not coalesce(w.on_wrist, true) then 'OFF_WRIST'
    else 'ON_WRIST'
  end                                                as status
from (
  select device_id, max(created_at) as last_sync, max(recorded_at) as last_reading
  from public.watch_metrics
  group by device_id
) d
left join lateral (
  select (payload ->> 'onWrist')::boolean as on_wrist, recorded_at as changed_at
  from public.watch_metrics m
  where m.device_id = d.device_id and m.type = 'wear_state' and payload ->> 'onWrist' in ('true', 'false')
  order by recorded_at desc
  limit 1
) w on true;

-- 2. Doses confirmed on the watch ("Taken" on the medication reminder). `name` is the watch's configured medicine
--    name; the phone matches it to its medicine list by ingredient or brand.
create or replace view public.watch_doses
with (security_invoker = true) as
select
  id,
  device_id,
  payload ->> 'name'                                                    as name,
  recorded_at                                                           as taken_at,
  to_char((recorded_at at time zone 'Europe/Warsaw')::date, 'YYYY-MM-DD') as day,
  source = 'simulated'                                                  as simulated
from public.watch_metrics
where type = 'medication_taken'
  and coalesce(payload ->> 'name', '') <> '';

-- 3. Symptoms logged on the watch, with the heart rate at that moment. kind 'fine' is a check-in answer
--    ("I'm OK"), kept so the doctor report can show the person answered.
create or replace view public.watch_symptoms
with (security_invoker = true) as
select
  id,
  device_id,
  payload ->> 'kind'                                                    as kind,
  case when (payload ->> 'bpm') ~ '^[0-9]+(\.[0-9]+)?$' then round((payload ->> 'bpm')::numeric)::int else 0 end
                                                                        as bpm,
  recorded_at,
  source = 'simulated'                                                  as simulated
from public.watch_metrics
where type = 'symptom'
  and payload ->> 'kind' in ('fine', 'palpitations', 'dizziness', 'fainting', 'other');

grant select on public.watch_status, public.watch_doses, public.watch_symptoms to anon;
