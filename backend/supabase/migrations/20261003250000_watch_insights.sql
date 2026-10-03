-- What the watch's "Took <medicine>" taps and "How do you feel?" answers mean, for the phone, the agent and the
-- doctor report. Deterministic rules only; texts are fixed here, the LLM may explain them but never decides them.
--   GET /rest/v1/watch_daily_summary?device_id=eq.demo-watch-1&order=day.desc&limit=28
--   GET /rest/v1/watch_insights?device_id=eq.demo-watch-1&order=ts.desc
-- Days use Polish local time, like the other watch views.

-- 1. One row per day: doses, symptoms, alerts and resting HR. Feeds the doctor report and the agent.
create or replace view public.watch_daily_summary
with (security_invoker = true) as
with events as (
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

-- 2. Insights: fixed rules over doses, symptoms and the recent risky drug (watch_context). One row per finding.
--    severity: CRITICAL = see a doctor now / call 112 if it happens again; WARN = tell your doctor; INFO = nudge.
create or replace view public.watch_insights
with (security_invoker = true) as
with sym as (
  select device_id, recorded_at as ts, payload ->> 'kind' as kind,
         case when (payload ->> 'bpm') ~ '^[0-9]+(\.[0-9]+)?$' then round((payload ->> 'bpm')::numeric)::int else 0 end as bpm,
         source = 'simulated' as simulated
  from public.watch_metrics
  where type = 'symptom'
    and payload ->> 'kind' in ('palpitations', 'dizziness', 'fainting', 'other')
    and recorded_at > now() - interval '7 days'
),
dose as (
  select device_id, max(recorded_at) as last_at, (array_agg(payload ->> 'name' order by recorded_at desc))[1] as name,
         bool_or(source = 'simulated') as simulated
  from public.watch_metrics
  where type = 'medication_taken' and coalesce(payload ->> 'name', '') <> ''
  group by device_id
)
-- a) A symptom within 24 h after scanning a drug with QT risk: the most important combination in LQTS.
select s.device_id, 'SYMPTOM_AFTER_RISKY_DRUG' as kind,
       case when s.kind = 'fainting' then 'CRITICAL' else 'WARN' end as severity,
       s.ts,
       format('You reported %s %s h after %s, which can prolong the QT interval. Don''t take another dose before '
              'talking to your doctor or pharmacist today. If you faint or your heart races, call 112.',
              case s.kind when 'palpitations' then 'a racing heart' when 'other' then 'a symptom' else s.kind end,
              greatest(1, round(extract(epoch from (s.ts - c.risky_drug_at)) / 3600)),
              c.risky_drug) as message,
       s.simulated,
       jsonb_build_object('symptom', s.kind, 'bpm', s.bpm, 'drug', c.risky_drug, 'risk', c.risky_drug_risk) as detail
from sym s
join public.watch_context c on c.device_id = s.device_id
where c.risky_drug is not null and c.risky_drug_at is not null
  and s.ts between c.risky_drug_at and c.risky_drug_at + interval '24 hours'

union all
-- b) Fainting is the classic LQTS warning sign.
select s.device_id, 'FAINTING_REPORTED', 'CRITICAL', s.ts,
       format('You reported fainting on %s (heart rate %s). With Long QT, fainting can be a warning sign: see your '
              'cardiologist as soon as possible. If it happens again, call 112.',
              to_char(s.ts at time zone 'Europe/Warsaw', 'DD Mon HH24:MI'),
              case when s.bpm > 0 then s.bpm::text || ' bpm' else 'unknown' end),
       s.simulated, jsonb_build_object('bpm', s.bpm)
from sym s
where s.kind = 'fainting'

union all
-- c) Two or more symptoms within the last 24 h.
select device_id, 'REPEATED_SYMPTOMS', 'WARN', max(ts),
       format('You reported symptoms %s times in the last 24 h (%s). Tell your doctor today.',
              count(*), string_agg(distinct case kind when 'palpitations' then 'racing heart' else kind end, ', ')),
       bool_or(simulated), jsonb_build_object('count', count(*))
from sym
where ts > now() - interval '24 hours'
group by device_id
having count(*) >= 2

union all
-- d) The person logs doses on the watch, but none in the last 26 h (daily medicine + 2 h grace).
select device_id, 'NO_DOSE_LOGGED', 'INFO', now(),
       format('No %s dose logged on your watch since %s. Did you take it? If you''re not sure, don''t take an extra '
              'dose: ask your pharmacist.', name, to_char(last_at at time zone 'Europe/Warsaw', 'DD Mon HH24:MI')),
       simulated, jsonb_build_object('medicine', name, 'last_dose_at', last_at)
from dose
where last_at < now() - interval '26 hours'
  and last_at > now() - interval '14 days';   -- older than that: probably no longer logging on the watch

grant select on public.watch_daily_summary, public.watch_insights to anon;
