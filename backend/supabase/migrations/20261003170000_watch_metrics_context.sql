-- Watch context metrics: fall/faint detection and wear state (see watch/entry/src/main/ets/model/WatchMetric.ets).
alter table public.watch_metrics drop constraint if exists watch_metrics_type_check;
alter table public.watch_metrics add constraint watch_metrics_type_check check (type in (
  'hr_live', 'hr_session', 'hr_alert', 'symptom', 'medication_taken', 'fall_detected', 'wear_state'
));
