-- Low HRV / low SpO2 alerts from the watch (inputs simulated today, see watch/README.md).
alter table public.watch_metrics drop constraint if exists watch_metrics_type_check;
alter table public.watch_metrics add constraint watch_metrics_type_check check (type in (
  'hr_live', 'hr_session', 'hr_alert', 'symptom', 'medication_taken', 'fall_detected', 'wear_state',
  'vitals', 'hr_recovery', 'rhythm_alert', 'sos', 'vitals_alert'
));
