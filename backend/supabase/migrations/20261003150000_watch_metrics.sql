-- Metrics sent by the Celia watch app (watch/). One generic table keyed by `type`, so new conditions add metric
-- types, not tables. Payload shapes are defined in watch/entry/src/main/ets/model/WatchMetric.ets.
--
-- Hackathon auth model: the watch and the phone use the public anon key. Anon may insert well-formed rows and read
-- them back. No names or contact data are stored here, only a device id and numbers.
-- TODO (post-hackathon): device tokens via an Edge Function + per-user RLS.

create table if not exists public.watch_metrics (
  id          bigint generated always as identity primary key,
  device_id   text        not null check (char_length(device_id) between 3 and 64),
  type        text        not null check (type in ('hr_live', 'hr_session', 'hr_alert', 'symptom', 'medication_taken')),
  payload     jsonb       not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  recorded_at timestamptz not null,
  source      text        not null check (source in ('watch', 'simulated')),
  created_at  timestamptz not null default now()
);

create index if not exists watch_metrics_device_type_time_idx
  on public.watch_metrics (device_id, type, recorded_at desc);

alter table public.watch_metrics enable row level security;

drop policy if exists "watch_metrics anon insert" on public.watch_metrics;
create policy "watch_metrics anon insert" on public.watch_metrics
  for insert to anon
  with check (recorded_at > now() - interval '7 days' and recorded_at < now() + interval '5 minutes');

drop policy if exists "watch_metrics anon read" on public.watch_metrics;
create policy "watch_metrics anon read" on public.watch_metrics
  for select to anon
  using (true);

-- Latest metric of each type per device, for the phone dashboard:
--   GET /rest/v1/watch_metrics_latest?device_id=eq.demo-watch-1
create or replace view public.watch_metrics_latest
with (security_invoker = true) as
select distinct on (device_id, type) *
from public.watch_metrics
order by device_id, type, recorded_at desc;

grant select on public.watch_metrics_latest to anon;
