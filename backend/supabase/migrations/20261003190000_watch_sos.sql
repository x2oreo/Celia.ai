-- SOS from the watch: the countdown ran out after "Need help" or an unanswered fall. The phone app / agent reacts
-- (alert emergency contacts, offer to call 112). The watch never dials by itself.
alter table public.watch_metrics drop constraint if exists watch_metrics_type_check;
alter table public.watch_metrics add constraint watch_metrics_type_check check (type in (
  'hr_live', 'hr_session', 'hr_alert', 'symptom', 'medication_taken', 'fall_detected', 'wear_state',
  'vitals', 'hr_recovery', 'rhythm_alert', 'sos'
));
