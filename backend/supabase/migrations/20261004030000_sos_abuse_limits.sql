-- SOS abuse limits (code review, 3 Oct). The anon key ships in the app, so anyone could register contacts under any
-- device_id and fire SOS rows that make the `sos` function text and call those numbers.
--  1. The function now caps real alert rounds per hour across all devices ('skipped_global_limit').
--  2. At most 5 emergency contacts per device (the function only ever reads 5).

alter table public.sos_dispatches drop constraint if exists sos_dispatches_status_check;
alter table public.sos_dispatches add constraint sos_dispatches_status_check
  check (status in ('sent', 'partial', 'failed', 'dry_run', 'skipped_cooldown', 'no_contacts', 'skipped_global_limit'));

create or replace function public.emergency_contacts_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.emergency_contacts where device_id = new.device_id) >= 5 then
    raise exception 'too many emergency contacts for this device';
  end if;
  return new;
end;
$$;

drop trigger if exists emergency_contacts_limit on public.emergency_contacts;
create trigger emergency_contacts_limit before insert on public.emergency_contacts
  for each row execute function public.emergency_contacts_limit();
