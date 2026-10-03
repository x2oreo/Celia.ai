-- Demo control for the missed beta-blocker check. The watch's Simulate page calls
--   POST /rest/v1/rpc/simulate_missed_beta_blocker  { "p_device_id": "demo-watch-1", "p_on": true }
-- which writes 16 simulated days (14 steady around 58 bpm, then 2 around 70 bpm) that the phone reads through the
-- same watch_resting_daily view as real data. Every simulated day is labelled `simulated = true`. `p_on: false`
-- removes them. Anon can only produce this fixed pattern, not arbitrary history.

create table if not exists public.resting_day_sim (
  device_id    text not null check (char_length(device_id) between 3 and 64),
  day          date not null,
  resting_bpm  int  not null,
  rest_minutes int  not null,
  primary key (device_id, day)
);

alter table public.resting_day_sim enable row level security;

-- Demo data only (no personal data): anon may read it; only the function below writes.
drop policy if exists "resting_day_sim anon read" on public.resting_day_sim;
create policy "resting_day_sim anon read" on public.resting_day_sim for select to anon using (true);
grant select on public.resting_day_sim to anon;

create or replace function public.simulate_missed_beta_blocker(p_device_id text, p_on boolean)
returns int
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

revoke all on function public.simulate_missed_beta_blocker(text, boolean) from public;
grant execute on function public.simulate_missed_beta_blocker(text, boolean) to anon;

-- Simulated days take the place of real ones on the same date.
create or replace view public.watch_resting_daily
with (security_invoker = true) as
with real_days as (
  select
    device_id,
    (recorded_at at time zone 'Europe/Warsaw')::date as d,
    round(percentile_cont(0.1) within group (order by (payload ->> 'bpm')::numeric))::int as resting_bpm,
    (count(*) / 2)::int as rest_minutes,
    bool_or(source = 'simulated') as simulated
  from public.watch_metrics
  where type = 'vitals'
    and payload ->> 'activity' in ('REST', 'ASLEEP')
    and (payload ->> 'bpm') ~ '^[0-9]+(\.[0-9]+)?$'
    and (payload ->> 'bpm')::numeric between 25 and 220
  group by device_id, (recorded_at at time zone 'Europe/Warsaw')::date
)
select device_id, to_char(day, 'YYYY-MM-DD') as day, resting_bpm, rest_minutes, true as simulated
from public.resting_day_sim
union all
select r.device_id, to_char(r.d, 'YYYY-MM-DD'), r.resting_bpm, r.rest_minutes, r.simulated
from real_days r
where not exists (select 1 from public.resting_day_sim s where s.device_id = r.device_id and s.day = r.d);

grant select on public.watch_resting_daily to anon;
