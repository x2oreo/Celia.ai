-- Daily resting heart rate per watch, for the phone's missed beta-blocker check (app/.../vitals/RestingTrend.ets).
-- Source: the watch's `vitals` rows (every 30 s). Resting HR for a day = 10th percentile of bpm while at rest or
-- asleep, which is robust to a few noisy samples and does not depend on the watch's own running estimate.
--   GET /rest/v1/watch_resting_daily?device_id=eq.demo-watch-1&order=day.desc&limit=21
-- Days use Polish local time (the team and demo are in Kraków).

create or replace view public.watch_resting_daily
with (security_invoker = true) as
select
  device_id,
  to_char((recorded_at at time zone 'Europe/Warsaw')::date, 'YYYY-MM-DD') as day,
  round(percentile_cont(0.1) within group (order by (payload ->> 'bpm')::numeric))::int as resting_bpm,
  (count(*) / 2)::int as rest_minutes,                       -- one vitals row per 30 s
  bool_or(source = 'simulated') as simulated
from public.watch_metrics
where type = 'vitals'
  and payload ->> 'activity' in ('REST', 'ASLEEP')
  and (payload ->> 'bpm') ~ '^[0-9]+(\.[0-9]+)?$'
  and (payload ->> 'bpm')::numeric between 25 and 220
group by device_id, (recorded_at at time zone 'Europe/Warsaw')::date;

grant select on public.watch_resting_daily to anon;
