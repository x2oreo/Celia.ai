-- The contact-limit trigger function must not be callable through PostgREST (/rest/v1/rpc). Triggers still fire:
-- EXECUTE is checked when the trigger is created, not when it runs. (Supabase security advisor 0028/0029.)
revoke execute on function public.emergency_contacts_limit() from public, anon, authenticated;
