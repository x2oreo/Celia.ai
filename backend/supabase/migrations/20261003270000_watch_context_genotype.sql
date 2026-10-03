-- The phone tells its paired watch the LQT genotype from the user's profile, so both apply the same limits
-- (a watch with a new paired id had no watch_context row and fell back to UNKNOWN).
--   POST /rest/v1/rpc/set_watch_genotype  {"p_device_id": "<watch id>", "p_genotype": "LQT2"}
-- Only the genotype can be set this way; other watch_context fields keep their values.

create or replace function public.set_watch_genotype(p_device_id text, p_genotype text)
returns boolean   -- true, so PostgREST answers 200 (the app's Net treats only 200 as OK)
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_device_id is null or char_length(p_device_id) not between 3 and 64 then
    raise exception 'invalid device id';
  end if;
  if p_genotype not in ('LQT1', 'LQT2', 'LQT3', 'UNKNOWN') then
    raise exception 'invalid genotype';
  end if;
  insert into watch_context (device_id, genotype, updated_at)
  values (p_device_id, p_genotype, now())
  on conflict (device_id) do update set genotype = excluded.genotype, updated_at = now();
  return true;
end;
$$;

revoke all on function public.set_watch_genotype(text, text) from public;
grant execute on function public.set_watch_genotype(text, text) to anon;
