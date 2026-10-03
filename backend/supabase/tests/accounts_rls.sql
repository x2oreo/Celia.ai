-- Behaviour test for the accounts migrations (20261004100000, 100100, 100200): RLS on profiles, watch data by
-- device ↔ account binding, SOS contacts RPCs. Runs against a scratch Postgres with Supabase-like shims
-- (roles anon / authenticated / service_role, auth.users, auth.uid() from request.jwt.claim.sub) after every
-- migration has been applied. Each check raises on failure; the last line prints ALL ACCOUNTS RLS CHECKS PASSED.
\set ON_ERROR_STOP 1

-- Fixtures (as the owner role, bypassing RLS).
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'one@celia.test'),
  ('22222222-2222-2222-2222-222222222222', 'two@celia.test');   -- sign-up works: the broken trigger is gone
insert into watch_metrics (device_id, type, payload, recorded_at, source) values
  ('watch-one', 'hr_live', '{"bpm": 70}', now(), 'watch'),
  ('demo-watch-1', 'hr_live', '{"bpm": 72}', now(), 'simulated');

create or replace function pg_temp.as_user(uid text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', uid, false);
  execute 'set role authenticated';
end $$;
create or replace function pg_temp.as_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '', false);
  execute 'set role anon';
end $$;
create or replace function pg_temp.check(ok boolean, what text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'FAILED: %', what; end if;
  raise notice 'ok: %', what;
end $$;
grant execute on all functions in schema pg_temp to anon, authenticated;

-- Pair w1 to user one: the watch asks for a code, the signed-in phone claims it.
select (pairing_start('watch-one') ->> 'code') as code \gset
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select (pairing_claim(:'code') ->> 'token') as tok1 \gset
reset role;
select pg_temp.check((select user_id::text from watch_pairings where device_id = 'watch-one') =
  '11111111-1111-1111-1111-111111111111', 'pairing_claim binds the watch to the signed-in user');

-- profiles: own row only, nothing for anon.
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
insert into profiles (user_id, data) values ('11111111-1111-1111-1111-111111111111', '{"v": 1}');
do $$ begin
  insert into profiles (user_id, data) values ('22222222-2222-2222-2222-222222222222', '{"v": 1}');
  raise exception 'FAILED: inserted a profile for another user';
exception when insufficient_privilege then raise notice 'ok: cannot write another user''s profile';
end $$;
reset role;
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select pg_temp.check((select count(*) from profiles) = 0, 'user two cannot see user one''s profile');
update profiles set data = '{"v": 9}';
reset role;
select pg_temp.check((select data ->> 'v' from profiles) = '1', 'user two cannot update user one''s profile');
select pg_temp.as_anon();
do $$ begin
  perform count(*) from profiles;
  raise exception 'FAILED: anon read profiles';
exception when insufficient_privilege then raise notice 'ok: anon cannot read profiles';
end $$;
reset role;
do $$ begin
  insert into profiles (user_id, data) values ('22222222-2222-2222-2222-222222222222', '"text"');
  raise exception 'FAILED: non-object document accepted';
exception when check_violation then raise notice 'ok: profile document must be an object';
end $$;

-- watch data: owner and demo only.
select pg_temp.as_anon();
select pg_temp.check((select count(*) from watch_metrics where device_id = 'watch-one') = 0, 'anon cannot read a paired watch');
select pg_temp.check((select count(*) from watch_metrics where device_id = 'demo-watch-1') = 1, 'anon reads the demo watch');
select pg_temp.check((select count(*) from watch_metrics_latest) = 1, 'anon view shows only the demo watch');
reset role;
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select pg_temp.check((select count(*) from watch_metrics) = 2, 'owner reads own watch and the demo watch');
select pg_temp.check(set_watch_genotype('watch-one', 'LQT2'), 'owner sets the genotype');
insert into watch_context (device_id, genotype, risky_drug) values ('watch-one', 'LQT2', 'clarithromycin')
  on conflict (device_id) do update set risky_drug = excluded.risky_drug;
reset role;
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select pg_temp.check((select count(*) from watch_metrics where device_id = 'watch-one') = 0, 'another user cannot read the watch');
select pg_temp.check((select count(*) from watch_context where device_id = 'watch-one') = 0, 'another user cannot read its context');
do $$ begin
  perform set_watch_genotype('watch-one', 'LQT1');
  raise exception 'FAILED: another user changed the genotype';
exception when insufficient_privilege then raise notice 'ok: another user cannot set the genotype';
end $$;
do $$ begin
  insert into watch_context (device_id, genotype) values ('watch-one', 'LQT3')
    on conflict (device_id) do update set genotype = excluded.genotype;
  raise exception 'FAILED: another user wrote watch_context';
exception when insufficient_privilege then raise notice 'ok: another user cannot write watch_context';
end $$;
reset role;
select pg_temp.as_anon();
do $$ begin
  perform set_watch_genotype('watch-one', 'LQT1');
  raise exception 'FAILED: anon changed the genotype';
exception when insufficient_privilege then raise notice 'ok: anon cannot set the genotype';
end $$;
select pg_temp.check(set_watch_genotype('demo-watch-1', 'LQT1'), 'anon may still set the demo watch genotype');
reset role;
select pg_temp.check((select genotype from watch_context where device_id = 'watch-one') = 'LQT2', 'genotype unchanged by others');

-- SOS contacts: owner only, E.164 only, at most 5, no anon path, name kept out of watch_context.
select pg_temp.as_anon();
do $$ begin
  insert into emergency_contacts (device_id, name, phone) values ('watch-one', 'X', '+48600000000');
  raise exception 'FAILED: anon inserted a contact';
exception when insufficient_privilege then raise notice 'ok: anon cannot insert contacts';
end $$;
reset role;
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
do $$ begin
  perform sync_sos_contacts('watch-one', '[{"name": "Eve", "phone": "+48600000001"}]', 'Eve');
  raise exception 'FAILED: another user set contacts';
exception when insufficient_privilege then raise notice 'ok: another user cannot set contacts';
end $$;
reset role;
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select pg_temp.check(sync_sos_contacts('watch-one',
  '[{"name": "Mum", "phone": "+48600000000"}, {"name": "Bad", "phone": "600 000 000"}, {"name": "Dad", "phone": "+359888123456"}]',
  'Ola') = 2, 'owner saves the two valid contacts');
select pg_temp.check((sos_status('watch-one') ->> 'contacts')::int = 2 and (sos_status('watch-one') ->> 'has_name')::boolean,
  'sos_status reports contacts and name');
select pg_temp.check(sos_status('watch-one') -> 'last' is null or json_typeof(sos_status('watch-one') -> 'last') = 'null',
  'no dispatch yet');
do $$ begin
  perform count(*) from emergency_contacts;
  raise exception 'FAILED: owner read contacts directly';
exception when insufficient_privilege then raise notice 'ok: contacts are not readable through the API';
end $$;
reset role;
select pg_temp.check((select patient_name from sos_profile where device_id = 'watch-one') = 'Ola', 'first name in sos_profile');
select pg_temp.check((select patient_name from watch_context where device_id = 'watch-one') is null, 'no name in watch_context');
insert into sos_dispatches (device_id, status, detail) values ('watch-one', 'dry_run', '{"contacts": 2, "sms": "x"}');
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select pg_temp.check(sos_status('watch-one') -> 'last' ->> 'status' = 'dry_run', 'owner sees the last dispatch status');
select pg_temp.check(sync_sos_contacts('watch-one', '[]', null) = 0, 'consent off clears the contacts');
reset role;
select pg_temp.check((select count(*) from emergency_contacts where device_id = 'watch-one') = 0, 'contacts deleted');
select pg_temp.check((select count(*) from sos_profile where device_id = 'watch-one') = 0, 'name deleted');

-- A pairing made while signed out binds later with its token; a new owner never inherits contacts.
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select sync_sos_contacts('watch-one', '[{"name": "Mum", "phone": "+48600000000"}]', 'Ola');
reset role;
select (pairing_start('watch-one') ->> 'code') as code2 \gset
select pg_temp.as_anon();
select (pairing_claim(:'code2') ->> 'token') as tok2 \gset
reset role;
select pg_temp.check((select user_id from watch_pairings where device_id = 'watch-one') is null, 'anon claim leaves the watch unbound');
select pg_temp.check((select count(*) from emergency_contacts where device_id = 'watch-one') = 0, 'old owner''s contacts removed');
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select pg_temp.check(pairing_bind('not-a-token-but-long-enough-0123456789') is null, 'wrong token binds nothing');
select pg_temp.check(pairing_bind(:'tok2') = 'watch-one', 'token binds the watch to the signed-in user');
select pg_temp.check((select count(*) from watch_metrics where device_id = 'watch-one') = 1, 'new owner reads the watch');
reset role;
select pg_temp.as_anon();
do $$ begin
  perform pairing_bind('x');
  raise exception 'FAILED: anon called pairing_bind';
exception when insufficient_privilege then raise notice 'ok: anon cannot bind';
end $$;
reset role;

-- Deleting an account removes its profile and contacts, and unbinds its watch.
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select sync_sos_contacts('watch-one', '[{"name": "Sis", "phone": "+48600000002"}]', 'Bo');
reset role;
delete from auth.users where id = '22222222-2222-2222-2222-222222222222';
select pg_temp.check((select count(*) from emergency_contacts where device_id = 'watch-one') = 0, 'account delete removes contacts');
select pg_temp.check((select user_id from watch_pairings where device_id = 'watch-one') is null, 'account delete unbinds the watch');

select 'ALL ACCOUNTS RLS CHECKS PASSED' as result;
