-- 1. New watch metric types: vitals snapshot (all risk-model inputs, some simulated), HR recovery, rhythm alert.
alter table public.watch_metrics drop constraint if exists watch_metrics_type_check;
alter table public.watch_metrics add constraint watch_metrics_type_check check (type in (
  'hr_live', 'hr_session', 'hr_alert', 'symptom', 'medication_taken', 'fall_detected', 'wear_state',
  'vitals', 'hr_recovery', 'rhythm_alert'
));

-- 2. Patient context the watch reads every minute: genotype + most recent QT-risk drug scan.
--    Written by the phone app (onboarding profile, drug check). One row per watch.
create table if not exists public.watch_context (
  device_id       text primary key check (char_length(device_id) between 3 and 64),
  genotype        text not null default 'UNKNOWN' check (genotype in ('LQT1', 'LQT2', 'LQT3', 'UNKNOWN')),
  risky_drug      text,
  risky_drug_risk text check (risky_drug_risk in ('KNOWN_RISK', 'POSSIBLE_RISK', 'CONDITIONAL_RISK')),
  risky_drug_at   timestamptz,
  updated_at      timestamptz not null default now()
);

alter table public.watch_context enable row level security;

-- Hackathon auth: shared anon key (see watch_metrics). Phone upserts, watch reads.
drop policy if exists "watch_context anon read" on public.watch_context;
create policy "watch_context anon read" on public.watch_context for select to anon using (true);
drop policy if exists "watch_context anon insert" on public.watch_context;
create policy "watch_context anon insert" on public.watch_context for insert to anon with check (true);
drop policy if exists "watch_context anon update" on public.watch_context;
create policy "watch_context anon update" on public.watch_context for update to anon using (true) with check (true);

-- Demo row so the watch has a genotype before the phone app writes one.
insert into public.watch_context (device_id, genotype) values ('demo-watch-1', 'LQT2')
on conflict (device_id) do nothing;
