-- "I'm fine" answered on the phone closes the same heart-rate alert / check-in on the watch.
--   Phone: POST /rest/v1/rpc/ack_watch_alert  {"p_device_id": "<paired watch id>"}  → true
--   Watch: polls watch_context.alert_ack_at every 3 s, only while an alert or check-in is open.
-- Falls and the SOS countdown are never closed from the phone: those must be answered on the wrist.

alter table public.watch_context add column if not exists alert_ack_at timestamptz;

create or replace function public.ack_watch_alert(p_device_id text)
returns boolean   -- true, so PostgREST answers 200 (the app's Net treats only 200 as OK)
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_device_id is null or char_length(p_device_id) not between 3 and 64 then
    raise exception 'invalid device id';
  end if;
  insert into watch_context (device_id, alert_ack_at, updated_at)
  values (p_device_id, now(), now())
  on conflict (device_id) do update set alert_ack_at = now(), updated_at = now();
  return true;
end;
$$;

revoke all on function public.ack_watch_alert(text) from public;
grant execute on function public.ack_watch_alert(text) to anon;
