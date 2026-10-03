# Workstream B - pending deploy steps (coordinator / Georgi)

Everything Workstream B still needs on the live Supabase project, in order. Collected from the stream notes
(`docs/workflow/b-accounts.md` "B9 plan and deploy order" and "Coordinator actions", `b-notify-sos.md` "For the
coordinator", `b-doctor.md` "Coordinator actions", `b-research.md` B11 notes). All code is merged on
`georgi/integration`; none of the steps below has been done yet. Each migration and deploy waits for Georgi's OK.

Apply the migrations one at a time (SQL editor or `apply_migration`), not with `supabase db push`: a push applies every
pending file, including `20261004100300`, which must wait for the re-paired watch (step 6).

## Checklist

1. [x] **Georgi:** Supabase → Authentication → turn off **"Confirm email"** (the app also handles it on: sign-up
   then says "check your email").
2. [x] Apply `backend/supabase/migrations/20261004100000_profiles_auth.sql` (accounts: drops the broken
   `on_auth_user_created` trigger, creates `profiles` with owner-only RLS). Compatible with every current build.
3. [x] Apply `20261004100100_sos_contacts_account.sql` (contacts under the account, `watch_pairings.user_id`,
   `pairing_bind`, `sos_profile`, `sync_sos_contacts()`, `sos_status()`). Compatible with every current build.
4. [x] Apply `20261004110000_push_tokens.sql` (owner-only RLS, nothing for anon; references only `auth.users`).
5. [x] Deploy the functions (`sos` keeps `--no-verify-jwt`):
   - `supabase functions deploy sos --no-verify-jwt` - reads the first name from `sos_profile`, reads
     `watch_pairings.user_id` for the push, sends Huawei Push when configured.
   - `supabase functions deploy doctor-summary` - accepts optional `reason` / `worries`; old requests still work.
6. [x] Install the new phone build (sends the user's JWT on `/rest/v1/`, binds pairings). Sign in, re-open Pair
   watch: an existing pairing is bound automatically after sign-in (or pair again).
   Retest B1/B2 here: sign up → kill → network off → reopen signed in; profile push / pull (`select updated_at from
   profiles`); restore on a fresh install.
7. [x] Apply `20261004100200_watch_rls_by_account.sql` (B9 part 1: owner-only reads of watch data). Retest: phone
   paired + signed in sees live heart rate and Trends; signed out shows nothing for the paired watch; unpaired shows
   the demo watch. Old watch builds keep working.
8. [x] Merge `georgi/b-watch` and `git apply docs/workflow/b-accounts-watch-secret.patch` - **done** at the
   integration merge (watch tests 88/88, watch HAP builds).
9. [x] Install the new watch build on the watch emulator / watch and **pair it again from the phone** so it receives
   its watch secret from `pairing_start`.
10. [x] Only then apply `20261004100300_watch_secret.sql` (B9 part 2: `x-watch-secret` required; open anon read on
    `watch_context` removed). **Never before step 9** - a watch without the secret header loses uploads and context.
    Retest: watch uploads, watch context (genotype / risky-drug badge), SOS, demo RPC.
11. [x] Retest B10: signed in + paired, Settings → Account → "Let my watch alert my contacts" on →
    `select count(*) from emergency_contacts` matches; off → 0. After a watch SOS, Account shows
    "Last SOS …: test mode, no text or call was sent" (dry run).

Done on 4 Oct 2026 (Kaloyan + Claude Code): steps 1-11, each migration applied on its own and recorded with
`supabase migration repair`; retested on the emulators (see AI_WORKFLOW.md). Step 13 is what makes a watch SOS
reach contacts: until then no dispatch is recorded and the phone says the server has not confirmed it.

## Later (secrets, not needed for the demo)

12. [ ] Huawei Push: `supabase secrets set HUAWEI_PUSH_PROJECT_ID=... HUAWEI_PUSH_SA_KEY=...` (needs an AGC project
    with Push Kit and a service-account key; receiving pushes needs a Chinese-mainland phone).
13. [ ] SOS to contacts (B11, see `backend/supabase/functions/sos/README.md`): `SOS_WEBHOOK_SECRET`, Vault secrets
    `sos_function_url` and `sos_webhook_secret`, and Twilio `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` /
    `TWILIO_FROM_NUMBER`. Without them the `sos` function records `dry_run`. A Twilio trial account only reaches
    verified numbers.

## Rollback (100200 / 100300)

Re-create the old anon policies from `20261003150000` (`watch_metrics`), `20261003180000` (`watch_context`),
`20261003230000` (`resting_day_sim`) and `20261003200000` (`emergency_contacts` insert).

## Local tooling notes

- With the watch emulator attached (`127.0.0.1:5557`) plain `hdc` refuses to pick a target, so `app/scripts/run.sh`
  and `ui.sh` fail; pass `-t 127.0.0.1:5555`. If the watch emulator starts first it takes 5555.
- `scripts/worktree.sh` does not copy the local signing block of `app/build-profile.json5`; copy it by hand and keep
  it out of git with `skip-worktree`.
