#!/usr/bin/env python3
"""Generate the 60-day demo history (single source of truth) for the phone and the backend.

Writes:
  app/entry/src/main/ets/vitals/DemoHistoryData.ets          the phone's built-in demo (no backend)
  backend/supabase/migrations/20261004120000_demo_history.sql the template rows the watch views read for demo devices

Usage:  python3 data/demo_history.py

Every value is SIMULATED and labelled so in the app. Rows are keyed by "days ago" (0 = today), not by date, so the
history always ends today. Weekly habits (weekend lie-ins, workout days) depend on the real weekday, so there is one
variant per weekday of "today"; the story and the noise are the same in every variant.

The story (days ago):
  59-40  steady on nadolol, resting heart rate around 58 bpm, slowly getting fitter (HRV and steps creep up)
  46-45  watch left on the charger: no data
  41     one missed dose: resting heart rate a little higher
  38-33  a cold: raised resting heart rate and breathing, oxygen 95-96 %, low HRV, broken sleep, one palpitations log
  27     watch not worn: no data
  22-21  a two-day trip: short nights, many steps, more stress time
  2-1    two missed nadolol doses: resting heart rate around 70 bpm, low HRV, a palpitations log and an alert
  0      today so far: dose taken this morning, resting heart rate on its way back down, a partial day
"""
import math
import pathlib
import random

ROOT = pathlib.Path(__file__).resolve().parent.parent
ETS_OUT = ROOT / 'app/entry/src/main/ets/vitals/DemoHistoryData.ets'
SQL_OUT = ROOT / 'backend/supabase/migrations/20261004120000_demo_history.sql'

DAYS = 60
SEED = 20261004
NO_WATCH = {46, 45, 27}
MISSED_DOSE = {41, 2, 1}
ILLNESS = {38: 0.5, 37: 1.0, 36: 1.0, 35: 0.7, 34: 0.35, 33: 0.15}
TRAVEL = {22, 21}
TODAY_SHARE = 0.55   # how much of today the "so far" row covers (early afternoon)

# Column order of one row. The phone reads these indexes; the SQL template uses the same names.
COLUMNS = ['avg_bpm', 'min_bpm', 'max_bpm', 'hrv_ms', 'spo2_x10', 'breathing_rate', 'sleep_minutes',
           'stress_minutes', 'steps', 'resting_bpm', 'rest_minutes', 'doses', 'first_dose_minute', 'symptoms',
           'alerts']


def ar1(rng: random.Random, n: int, phi: float, sd: float) -> list:
    """Smooth day-to-day noise: each day leans on the one before, so lines drift instead of jumping."""
    out, v = [], 0.0
    for _ in range(n):
        v = phi * v + rng.gauss(0, sd) * math.sqrt(1 - phi * phi)
        out.append(v)
    return out


def clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def noise_tables() -> dict:
    rng = random.Random(SEED)
    return {
        'rest': ar1(rng, DAYS, 0.6, 1.0),
        'hrv': ar1(rng, DAYS, 0.55, 3.0),
        'sleep': ar1(rng, DAYS, 0.3, 28.0),
        'steps': ar1(rng, DAYS, 0.2, 1300.0),
        'spo2': ar1(rng, DAYS, 0.5, 0.35),
        'breath': ar1(rng, DAYS, 0.5, 0.5),
        'stress': ar1(rng, DAYS, 0.3, 9.0),
        'max': ar1(rng, DAYS, 0.2, 5.0),
        'dose': [rng.randint(-25, 35) for _ in range(DAYS)],
    }


def variant(today_dow: int, nz: dict) -> list:
    """Rows for ago = 0..DAYS-1 when today is weekday `today_dow` (0 = Sunday, as JS getDay and Postgres dow).
    A day without the watch is None."""
    rows = []
    prev_workout = False
    # Walk oldest to newest so "the night before" and "yesterday's workout" are known.
    built = {}
    for ago in range(DAYS - 1, -1, -1):
        t = DAYS - 1 - ago                      # 0 = oldest
        dow = (today_dow - ago) % 7
        weekend = dow in (0, 6)
        workout = dow in (2, 4, 6) and ago not in ILLNESS and ago not in TRAVEL and ago not in (1, 2)
        ill = ILLNESS.get(ago, 0.0)
        travel = ago in TRAVEL
        missed = ago in (1, 2)
        fit = t / (DAYS - 1)                    # 0..1, slowly fitter

        sleep = 432 + nz['sleep'][t] + (42 if weekend else 0) + (25 * ill) - (130 if travel else 0) - \
            (90 if missed else 0)
        deficit = max(0.0, 420 - sleep)         # minutes short of 7 h

        resting = 58.5 - 1.2 * fit + nz['rest'][t] + deficit / 30 + 9 * ill + (3 if ago == 41 else 0) + \
            (11.5 if missed else 0) + (8 if ago == 0 else 0)
        hrv = 45 + 4 * fit + nz['hrv'][t] - deficit / 12 - 15 * ill - (15 if missed else 0) + \
            (3 if prev_workout else 0) - (9 if ago == 0 else 0)
        steps = 6200 + 900 * fit + nz['steps'][t] + (2600 if dow == 6 else 0) - (600 if dow == 0 else 0) + \
            (4200 if workout else 0) - 4300 * ill + (5200 if travel else 0) - (2300 if missed else 0)
        stress = 26 + nz['stress'][t] + (18 if dow == 1 else 0) + (8 if dow in (2, 3, 4, 5) else 0) - \
            (14 if weekend else 0) + 30 * ill + (35 if travel else 0) + (62 if missed else 0) + deficit / 6
        spo2 = 97.4 + nz['spo2'][t] - 1.7 * ill
        breath = 14.2 + nz['breath'][t] + 3.6 * ill + (1.3 if missed else 0)
        avg = resting + 6 + steps / 2000 + stress / 15 + 3 * ill
        mx = 104 + steps / 650 + (24 if workout else 0) + nz['max'][t] + (12 if missed else 0)

        doses = 0 if ago in MISSED_DOSE else 1
        symptoms = 1 if ago in (36, 1) else 0
        alerts = 1 if ago == 1 else 0
        first_dose = 8 * 60 + 5 + nz['dose'][t] + (55 if weekend else 0)

        if ago == 0:                            # today so far
            steps *= TODAY_SHARE
            stress *= TODAY_SHARE
            mx -= 10
        prev_workout = workout
        if ago in NO_WATCH:
            built[ago] = None
            continue
        sleep_m = int(round(clamp(sleep, 240, 620)))
        built[ago] = [
            int(round(clamp(avg, 55, 110))),
            int(round(clamp(resting - 4.5 + nz['rest'][t] * 0.5, 42, 80))),
            int(round(clamp(mx, 95, 162))),
            int(round(clamp(hrv, 18, 85))),
            int(round(clamp(spo2, 93.5, 99.2) * 10)),
            int(round(clamp(breath, 11, 21))),
            sleep_m,
            int(round(clamp(stress, 0, 180))),
            int(round(clamp(steps, 700, 22000))),
            int(round(clamp(resting, 45, 85))),
            sleep_m + 55,
            doses,
            int(first_dose) if doses > 0 else -1,
            symptoms,
            alerts,
        ]
    for ago in range(DAYS):
        rows.append(built[ago])
    return rows


def check(rows: list) -> None:
    """The missed-dose question must still fire: days 1-2 at least 10 bpm above the median of days 3-16."""
    r = COLUMNS.index('resting_bpm')
    base = sorted(rows[a][r] for a in range(3, 17) if rows[a] is not None)
    median = base[len(base) // 2] if len(base) % 2 else (base[len(base) // 2 - 1] + base[len(base) // 2]) / 2
    assert rows[1][r] >= median + 10 and rows[2][r] >= median + 10, (median, rows[1][r], rows[2][r])
    for row in rows:
        if row is not None:
            assert row[1] < row[0] < row[2], row


def ets(variants: list) -> str:
    lines = [
        '// Generated by data/demo_history.py - do not edit by hand. 60 days of SIMULATED watch history, one variant',
        '// per weekday of today (0 = Sunday). DEMO_HISTORY[weekday][ago]: ago 0 is today so far; an empty row is a',
        '// day the watch was not worn. Read through DemoHistory.ets.',
        '',
        f'export const DEMO_DAYS: number = {DAYS};',
        '',
    ]
    for i, c in enumerate(COLUMNS):
        name = c.upper()
        lines.append(f'export const COL_{name}: number = {i};')
    lines.append('')
    lines.append('export const DEMO_HISTORY: number[][][] = [')
    for v in variants:
        lines.append('  [')
        body = []
        for row in v:
            body.append('    [' + ', '.join(str(x) for x in row) + ']' if row is not None else '    []')
        lines.append(',\n'.join(body))
        lines.append('  ],' if v is not variants[-1] else '  ]')
    lines.append('];')
    return '\n'.join(lines) + '\n'


SQL_HEAD = """-- Generated by data/demo_history.py - do not edit by hand.
-- 60 days of SIMULATED watch history for demo devices, so the phone's Health charts, Trends, the agent and the doctor
-- report have two months to show. Same story and numbers as the phone's built-in demo (vitals/DemoHistoryData.ets).
--
-- demo_history_template holds one row per (weekday of today, days ago). The views below join it to the devices in
-- demo_history_on and turn "days ago" into a date at read time, so the history always ends yesterday (today stays the
-- watch's own live rows). A simulated day takes the place of real rows on the same date, like resting_day_sim.
--   POST /rest/v1/rpc/seed_demo_history  { "p_device_id": "demo-watch-1", "p_on": true }
-- turns it on or off for a device (the demo watch, or a watch that sends its secret). demo-watch-1 starts on.

create table if not exists public.demo_history_template (
  weekday           smallint not null check (weekday between 0 and 6),
  ago               smallint not null check (ago between 1 and 59),
  avg_bpm           int      not null,
  min_bpm           int      not null,
  max_bpm           int      not null,
  hrv_ms            int      not null,
  spo2              numeric  not null,
  breathing_rate    int      not null,
  sleep_minutes     int      not null,
  stress_minutes    int      not null,
  steps             int      not null,
  resting_bpm       int      not null,
  rest_minutes      int      not null,
  doses             int      not null,
  first_dose_minute int,
  symptoms          int      not null,
  alerts            int      not null,
  primary key (weekday, ago)
);

-- Fixed demo numbers, no personal data: anyone may read them.
alter table public.demo_history_template enable row level security;
drop policy if exists "demo_history_template read" on public.demo_history_template;
create policy "demo_history_template read" on public.demo_history_template for select to anon, authenticated
  using (true);
grant select on public.demo_history_template to anon, authenticated;

create table if not exists public.demo_history_on (
  device_id text primary key check (char_length(device_id) between 3 and 64),
  since     timestamptz not null default now()
);

alter table public.demo_history_on enable row level security;
drop policy if exists "demo_history_on read demo" on public.demo_history_on;
create policy "demo_history_on read demo" on public.demo_history_on for select to anon
  using (public.is_demo_device(device_id));
drop policy if exists "demo_history_on read own" on public.demo_history_on;
create policy "demo_history_on read own" on public.demo_history_on for select to authenticated
  using (public.is_demo_device(device_id) or public.device_owned(device_id));
grant select on public.demo_history_on to anon, authenticated;

truncate public.demo_history_template;
"""

SQL_TAIL = """
insert into public.demo_history_on (device_id) values ('demo-watch-1') on conflict (device_id) do nothing;

create or replace function public.seed_demo_history(p_device_id text, p_on boolean)
returns integer
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_device_id is null or char_length(p_device_id) not between 3 and 64 then
    raise exception 'invalid device id';
  end if;
  if not (public.is_demo_device(p_device_id) or public.watch_secret_ok(p_device_id)) then
    raise exception 'watch secret required' using errcode = '42501';
  end if;
  if not p_on then
    delete from demo_history_on where device_id = p_device_id;
    return 0;
  end if;
  insert into demo_history_on (device_id) values (p_device_id) on conflict (device_id) do nothing;
  return 59;
end;
$$;

revoke all on function public.seed_demo_history(text, boolean) from public;
grant execute on function public.seed_demo_history(text, boolean) to anon, authenticated;

-- The demo days of every device that has the history on, as dates (Polish local time, like the other watch views).
create or replace view public.demo_history_days
with (security_invoker = true) as
with today as (select (now() at time zone 'Europe/Warsaw')::date as d)
select o.device_id, today.d - t.ago as d, t.*
from public.demo_history_on o
cross join today
join public.demo_history_template t on t.weekday = extract(dow from today.d)::int;

grant select on public.demo_history_days to anon, authenticated;

-- Same columns as 20261004060000_watch_vitals_daily.sql; demo days replace real rows on the same date.
create or replace view public.watch_vitals_daily
with (security_invoker = true) as
with v as (
  select
    device_id,
    (recorded_at at time zone 'Europe/Warsaw')::date as d,
    payload ->> 'activity' as activity,
    source,
    case when (payload ->> 'bpm') ~ '^[0-9]+(\\.[0-9]+)?$' then (payload ->> 'bpm')::numeric end as bpm,
    case when (payload ->> 'hrvMs') ~ '^[0-9]+(\\.[0-9]+)?$' then (payload ->> 'hrvMs')::numeric end as hrv,
    case when (payload ->> 'spo2') ~ '^[0-9]+(\\.[0-9]+)?$' then (payload ->> 'spo2')::numeric end as spo2,
    case when (payload ->> 'breathingRate') ~ '^[0-9]+(\\.[0-9]+)?$'
      then (payload ->> 'breathingRate')::numeric end as breathing,
    case when (payload ->> 'steps') ~ '^[0-9]+$' then (payload ->> 'steps')::bigint end as steps,
    coalesce(payload ->> 'stress', 'false') = 'true' as stress
  from public.watch_metrics
  where type = 'vitals'
),
real_days as (
  select
    device_id,
    d,
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
  group by device_id, d
)
select device_id, to_char(d, 'YYYY-MM-DD') as day, avg_bpm, min_bpm, max_bpm, hrv_ms, spo2, breathing_rate,
       sleep_minutes, stress_minutes, steps, true as simulated
from public.demo_history_days
union all
select r.device_id, to_char(r.d, 'YYYY-MM-DD'), r.avg_bpm, r.min_bpm, r.max_bpm, r.hrv_ms, r.spo2, r.breathing_rate,
       r.sleep_minutes, r.stress_minutes, r.steps, r.simulated
from real_days r
where not exists (select 1 from public.demo_history_days s where s.device_id = r.device_id and s.d = r.d);

-- Same columns as 20261003230000_resting_day_sim.sql. The missed beta-blocker button (resting_day_sim) wins over the
-- demo history, which wins over real rows.
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
    and (payload ->> 'bpm') ~ '^[0-9]+(\\.[0-9]+)?$'
    and (payload ->> 'bpm')::numeric between 25 and 220
  group by device_id, (recorded_at at time zone 'Europe/Warsaw')::date
)
select device_id, to_char(day, 'YYYY-MM-DD') as day, resting_bpm, rest_minutes, true as simulated
from public.resting_day_sim
union all
select h.device_id, to_char(h.d, 'YYYY-MM-DD'), h.resting_bpm, h.rest_minutes, true
from public.demo_history_days h
where not exists (select 1 from public.resting_day_sim s where s.device_id = h.device_id and s.day = h.d)
union all
select r.device_id, to_char(r.d, 'YYYY-MM-DD'), r.resting_bpm, r.rest_minutes, r.simulated
from real_days r
where not exists (select 1 from public.resting_day_sim s where s.device_id = r.device_id and s.day = r.d)
  and not exists (select 1 from public.demo_history_days h where h.device_id = r.device_id and h.d = r.d);

-- Same columns as 20261003250000_watch_insights.sql; the demo days add their doses, palpitations and alerts.
create or replace view public.watch_daily_summary
with (security_invoker = true) as
with real_events as (
  select
    device_id,
    (recorded_at at time zone 'Europe/Warsaw')::date as d,
    count(*) filter (where type = 'medication_taken')                                  as doses_taken,
    min(recorded_at) filter (where type = 'medication_taken')                          as first_dose_at,
    count(*) filter (where type = 'symptom' and payload ->> 'kind' in ('palpitations', 'dizziness', 'fainting', 'other'))
                                                                                       as symptoms,
    coalesce(array_agg(distinct payload ->> 'kind') filter (
      where type = 'symptom' and payload ->> 'kind' in ('palpitations', 'dizziness', 'fainting', 'other')),
      '{}')                                                                            as symptom_kinds,
    count(*) filter (where type = 'symptom' and payload ->> 'kind' = 'fine')            as fine_check_ins,
    count(*) filter (where type in ('hr_alert', 'vitals_alert', 'rhythm_alert'))      as alerts,
    count(*) filter (where type = 'fall_detected')                                     as falls,
    count(*) filter (where type = 'sos')                                               as sos,
    bool_or(source = 'simulated')                                                      as simulated
  from public.watch_metrics
  where type in ('medication_taken', 'symptom', 'hr_alert', 'vitals_alert', 'rhythm_alert', 'fall_detected', 'sos')
  group by device_id, (recorded_at at time zone 'Europe/Warsaw')::date
),
events as (
  select device_id, d, doses_taken::bigint as doses_taken,
         case when first_dose_minute is null then null::timestamptz
              else (d + make_interval(mins => first_dose_minute)) at time zone 'Europe/Warsaw' end as first_dose_at,
         symptoms::bigint as symptoms,
         case when symptoms > 0 then array['palpitations'] else '{}'::text[] end as symptom_kinds,
         0::bigint as fine_check_ins, alerts::bigint as alerts, 0::bigint as falls, 0::bigint as sos,
         true as simulated
  from (select device_id, d, doses as doses_taken, first_dose_minute, symptoms, alerts from public.demo_history_days) h
  union all
  select e.device_id, e.d, e.doses_taken, e.first_dose_at, e.symptoms, e.symptom_kinds, e.fine_check_ins, e.alerts,
         e.falls, e.sos, e.simulated
  from real_events e
  where not exists (select 1 from public.demo_history_days h where h.device_id = e.device_id and h.d = e.d)
)
select
  coalesce(e.device_id, r.device_id)                                  as device_id,
  coalesce(to_char(e.d, 'YYYY-MM-DD'), r.day)                         as day,
  coalesce(e.doses_taken, 0)::int                                     as doses_taken,
  e.first_dose_at,
  coalesce(e.symptoms, 0)::int                                        as symptoms,
  coalesce(e.symptom_kinds, '{}')                                     as symptom_kinds,
  coalesce(e.fine_check_ins, 0)::int                                  as fine_check_ins,
  coalesce(e.alerts, 0)::int                                          as alerts,
  coalesce(e.falls, 0)::int                                           as falls,
  coalesce(e.sos, 0)::int                                             as sos,
  r.resting_bpm,
  coalesce(e.simulated, false) or coalesce(r.simulated, false)        as simulated
from events e
full join public.watch_resting_daily r
  on r.device_id = e.device_id and r.day = to_char(e.d, 'YYYY-MM-DD');

grant select on public.watch_vitals_daily, public.watch_resting_daily, public.watch_daily_summary to anon, authenticated;
"""


def sql(variants: list) -> str:
    values = []
    for dow, v in enumerate(variants):
        for ago, row in enumerate(v):
            if ago == 0 or row is None:
                continue
            cells = list(row)
            cells[COLUMNS.index('spo2_x10')] = f"{row[COLUMNS.index('spo2_x10')] / 10:.1f}"
            fd = row[COLUMNS.index('first_dose_minute')]
            cells[COLUMNS.index('first_dose_minute')] = 'null' if fd < 0 else str(fd)
            values.append(f"({dow}, {ago}, " + ', '.join(str(c) for c in cells) + ')')
    names = ', '.join('spo2' if c == 'spo2_x10' else c for c in COLUMNS)
    insert = f'insert into public.demo_history_template (weekday, ago, {names}) values\n' + ',\n'.join(values) + ';\n'
    return SQL_HEAD + insert + SQL_TAIL


def main() -> None:
    nz = noise_tables()
    variants = [variant(dow, nz) for dow in range(7)]
    for v in variants:
        check(v)
    ETS_OUT.write_text(ets(variants), encoding='utf-8')
    SQL_OUT.write_text(sql(variants), encoding='utf-8')
    print(f'wrote {ETS_OUT.relative_to(ROOT)} and {SQL_OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
