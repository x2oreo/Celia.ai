-- Minimal stand-ins for what Supabase provides, so the migrations run on a plain local Postgres (run-rls.sh):
-- the API roles, auth.users, auth.uid() from the request.jwt.claim.sub setting, empty vault and pg_net stubs, and the
-- broken sign-up trigger the live project had (20261004100000 removes it).
do $$ begin if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls; create role authenticator login noinherit; grant anon, authenticated, service_role to authenticator; end if; end $$;

create schema auth; create schema extensions; create schema vault; create schema net;
create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create view vault.decrypted_secrets as select ''::text as name, ''::text as decrypted_secret where false;
create function net.http_post(url text, body jsonb, headers jsonb, timeout_milliseconds int) returns bigint language sql as $$ select 1::bigint $$;
grant usage on schema public, auth, extensions to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
-- the broken live state the first accounts migration repairs
create function public.handle_new_user() returns trigger language plpgsql security definer as $$ begin insert into public.profiles (id, display_name) values (new.id, null); return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
