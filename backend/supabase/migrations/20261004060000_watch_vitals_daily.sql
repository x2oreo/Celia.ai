-- Daily vitals per watch for the phone's Health tab (app/.../vitals/MetricHistory.ets): heart-rate range, HRV, oxygen,
-- breathing, sleep, stress time and steps, one row per day.
--   GET /rest/v1/watch_vitals_daily?device_id=eq.demo-watch-1&order=day.desc&limit=30
-- Source: the watch's `vitals` rows (one every 30 s). HRV, SpO2 and breathing rate are simulated on the watch today
-- (payload.mocked); the phone labels them SIMULATED whatever `simulated` says here.
-- Sleep and stress are counted per calendar day (Polish local time), so a night is split at midnight.

create or replace view public.watch_vitals_daily
with (security_invoker = true) as
with v as (
  select
    device_id,
    (recorded_at at time zone 'Europe/Warsaw')::date as d,
    payload ->> 'activity' as activity,
    source,
    case when (payload ->> 'bpm') ~ '^[0-9]+(\.[0-9]+)?$' then (payload ->> 'bpm')::numeric end as bpm,
    case when (payload ->> 'hrvMs') ~ '^[0-9]+(\.[0-9]+)?$' then (payload ->> 'hrvMs')::numeric end as hrv,
    case when (payload ->> 'spo2') ~ '^[0-9]+(\.[0-9]+)?$' then (payload ->> 'spo2')::numeric end as spo2,
    case when (payload ->> 'breathingRate') ~ '^[0-9]+(\.[0-9]+)?$'
      then (payload ->> 'breathingRate')::numeric end as breathing,
    case when (payload ->> 'steps') ~ '^[0-9]+$' then (payload ->> 'steps')::bigint end as steps,
    coalesce(payload ->> 'stress', 'false') = 'true' as stress
  from public.watch_metrics
  where type = 'vitals'
)
select
  device_id,
  to_char(d, 'YYYY-MM-DD') as day,
  round(avg(bpm) filter (where bpm between 25 and 220))::int as avg_bpm,
  round(min(bpm) filter (where bpm between 25 and 220))::int as min_bpm,
  round(max(bpm) filter (where bpm between 25 and 220))::int as max_bpm,
  round(avg(hrv) filter (where hrv > 0 and activity in ('REST', 'ASLEEP')))::int as hrv_ms,
  round(avg(spo2) filter (where spo2 between 50 and 100), 1) as spo2,
  round(avg(breathing) filter (where breathing > 0 and activity in ('REST', 'ASLEEP')))::int as breathing_rate,
  (count(*) filter (where activity = 'ASLEEP') / 2)::int as sleep_minutes,     -- one vitals row per 30 s
  (count(*) filter (where stress) / 2)::int as stress_minutes,
  -- The watch reports steps since the app started, so the day's count is how far that total moved.
  greatest(coalesce(max(steps) - min(steps), 0), 0)::int as steps,
  bool_or(source = 'simulated') as simulated
from v
group by device_id, d;

-- security_invoker: the watch_metrics policies decide which rows come back (owner-only after 20261004100200).
grant select on public.watch_vitals_daily to anon, authenticated;
