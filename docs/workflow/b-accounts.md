# S1 accounts

> Status (4 Oct 2026): working log of stream S1; merged into `main`, entry folded into `AI_WORKFLOW.md`. Deploy steps were done on 4 Oct (see [`../handoff/B_DEPLOY.md`](../handoff/B_DEPLOY.md)).

## AI_WORKFLOW entry
### 2026-10-04 - Georgi + Claude Code: accounts and profile backup (branch `georgi/b-accounts`)
- Asked: brief B1 (sign up, log in, stay signed in offline) and B2 (profile saved under the account), plus the §8
  privacy docs. Supabase Auth over plain HTTPS, no supabase-js.
- Produced:
  - Migration `20261004100000_profiles_auth.sql`: drops the leftover `on_auth_user_created` trigger and
    `handle_new_user()` (they inserted into a `profiles(id, display_name)` table that never existed, so every sign-up
    failed with "Database error saving new user"); creates `public.profiles (user_id, data jsonb, updated_at)` with RLS
    on, four `(select auth.uid()) = user_id` policies for `authenticated`, explicit `revoke all … from anon` (the
    project's default privileges grant anon full table rights), a JSON-object check and a 64 KB size cap.
  - `account/AuthClient.ets`: signup, password grant, refresh grant, logout. Endpoints checked against the Supabase
    Auth API reference; errors parsed in both the current `{code, error_code, msg}` and the older
    `{error, error_description}` shape (codes from the Supabase Auth error-code list). Sign-up with no session in the
    reply → "check your email" (in case "Confirm email" stays on).
  - `account/Session.ets`: the contract API (`isSignedIn`, `userId`, `userName`, `email`, `accessToken`, `signOut`,
    `onChange`) plus `load`, `start`, `freshToken`, `refreshNow`. Session stored in the encrypted RDB (`kv` setting
    `session`). Refresh 5 min before expiry, retry every 60 s while it fails. Only `SESSION_REVOKED` signs out;
    offline / 5xx / 429 keep the session, so an expired token offline still opens the app signed in.
  - `account/ProfileSync.ets`: last-write-wins on the document time (newer of `Profile.updatedAt` and the last
    medicine change), at sign-in, at launch and 3 s after a local edit; every run reads the account copy first.
  - `common/Net.ets`: `NetTarget.bearer` and `authHeaders()` - the one place that puts the user's JWT in
    `Authorization` (the anon key stays in `apikey`); `accountTarget()`; `requestJson()` for nested JSON bodies.
  - `privacy/Ledger.ets`: `PersonalDataException` with exactly two named entries, `ACCOUNT_AUTH` (`/auth/v1/`,
    `email`) and `PROFILE_SYNC` (`/rest/v1/profiles`, the profile's personal fields). `FORBIDDEN_FIELDS` is unchanged;
    an exception only applies on its own endpoint prefix. Ledger entries carry the exception id; the export shows it.
  - `LocalStore.saveProfile(profile, stamp = true)` stamps `updatedAt`.
  - Screens: `WelcomePage`, `AuthPage` + `components/AuthForm.ets`, `AccountPage`, Settings → Account row, launch
    routing in `pages/Index.ets` (`showOnboardingIfNeeded`). Strings in `string_accounts.json` (`acc_`).
  - Docs (brief §8): README "What leaves the phone", `AI_FEATURES.md` §3, `docs/ARCHITECTURE.md` data rule,
    `docs/PRODUCT.md` D6, `docs/TASKS.md`, `docs/IDEA.md`.
- Validated: phone unit tests 238/238 (27 new in `test/Account.test.ets`: response parsing for both error shapes,
  confirm-email sign-up, session storage round trip and corruption, refresh margin and scheduling, refresh decision,
  offline-with-expired-stored-session, launch route, last-write-wins incl. "never push another account's data",
  remote document parsing and versioning, personal-field naming, ledger exception scoping). `assembleHap` builds.
  Emulator (phone `127.0.0.1:5555`): fresh install opens on Welcome (`docs/screenshots/b/accounts-welcome.jpeg`);
  Sign up form (`accounts-signup.jpeg`); a real log-in against the live project with a wrong password comes back as
  `invalid_credentials` and shows the amber strip with the fields kept (`accounts-login-error.jpeg`). This emulator
  pass found and fixed two form bugs: the button kept the sign-up label after switching to log-in, and both inputs
  were cleared after an error (both caused by values passed by value into `@Builder` functions).
- Not validated (needs the migration applied and "Confirm email" off): real sign-up from the emulator, profile push /
  pull against the live table, the B1 acceptance run (sign up → kill → network off → reopen signed in). Context7 was
  not available in this session; the encrypted RDB and `@kit.NetworkKit` http calls reuse the patterns already in
  `data/LocalStore.ets` and `common/Net.ets`.

### 2026-10-04 - Georgi + Claude Code: SOS contacts under the account and RLS by account (B10, B9; branch `georgi/b-accounts`)
- Asked: B10 (contacts and first name reach the server with consent; show the dispatch status) and B9 (close the
  open RLS on watch data through the device ↔ account binding; give the watch its own secret).
- Produced:
  - `20261004100100_sos_contacts_account.sql`: `watch_pairings.user_id` (pairing_claim records `auth.uid()`,
    `pairing_bind(token)` binds older pairings), `emergency_contacts.user_id`, `sos_profile` (first name, no API
    access), `device_owned()`, `sync_sos_contacts()` (owner only, E.164, ≤ 5, empty = delete), `sos_status()`. Anon
    insert on `emergency_contacts` removed. A new owner never inherits the previous owner's contacts. The `sos`
    function reads the name from `sos_profile`.
  - `20261004100200_watch_rls_by_account.sql` (B9 part 1): anon reads only the demo watch; signed-in owners read
    their watch (`watch_metrics`, views, `watch_context`, `resting_day_sim`); phone writes to `watch_context`,
    `set_watch_genotype`, `ack_watch_alert` (from Workstream A's 20261004050000) need the owner. Names are wiped
    from `watch_context`.
  - `20261004100300_watch_secret.sql` (B9 part 2): `pairing_start` hands out a watch secret once (hash stored);
    `x-watch-secret` header unlocks the watch's context read, uploads (once it has a secret), `pairing_start` and the
    demo RPC. The open anon read on `watch_context` is gone.
  - `backend/supabase/tests/run-rls.sh` + `accounts_rls.sql` + `supabase-shim.sql`: every migration applied to a
    throw-away local Postgres 15 with Supabase stand-ins, then ~49 behaviour checks (profiles, watch data by owner,
    contacts RPCs, binding, account deletion, watch secret).
  - Phone: `common/Net.ets` adds the user's JWT to database paths (`/rest/v1/`) on the accounts project only; AI
    calls (`/functions/v1/`) stay anonymous because the token names the user. Expired tokens are not sent (the
    request falls back to the public key, which still reads the demo watch). `data/WatchPairing.ets`: claim binds,
    `bindToAccount()` after sign-in. `PairWatchPage` asks to sign in first. `account/SosContacts.ets`: consent
    switch, E.164 normalisation from the profile country (ITU-T calling codes), first name only, `SOS_CONTACTS`
    ledger exception, status line (incl. "test mode, no text or call was sent" for `dry_run`). README updated in the
    same commit.
  - Watch (B9 part 2): `docs/workflow/b-accounts-watch-secret.patch`, made on a detached copy of `georgi/b-watch`
    (S6's RestClient): RestClient sends `x-watch-secret`, PairingClient stores the secret from `pairing_start`,
    DeviceIdStore keeps it, WatchController wires it (3 lines). Watch build OK, watch tests 88/88 there.
- Validated: phone tests 248/248; backend Deno 68/68; RLS checks pass on local Postgres; watch patch builds and
  passes 88/88 on top of `georgi/b-watch`. Emulator: Settings → Account row, Account page signed out
  (`accounts-account-signed-out.jpeg`), Pair watch asks to sign in (`accounts-pair-sign-in.jpeg`).
- Not validated: nothing of B9/B10 against the live project (migrations not applied); the consent switch and SOS
  status signed in; a real SOS reaching contacts (no Twilio credentials: the server records `dry_run`).

## README "How to verify" rows
| Feature | How to check |
|---|---|
| Welcome on first launch | Uninstall, `app/scripts/run.sh` → Welcome with Create an account / I already have an account / Set up without an account |
| Sign up / log in (B1) | Welcome → Create an account → email + 8-char password → lands in onboarding (new) or the app (profile restored). Needs migration `20261004100000` and "Confirm email" off |
| Stay signed in offline (B1) | Sign up, kill the app, turn the network off, reopen → main screen, Settings → Account shows the email |
| Profile backup (B2) | Signed in, change the name in Settings → Account shows "Backed up …"; in Supabase `select updated_at from profiles` changes |
| Restore on a new phone (B2) | Uninstall, reinstall, Welcome → I already have an account → log in → skips onboarding, profile and medicines back |
| Delete cloud data | Settings → Account → Delete my data from my account → row gone, signed out, phone data kept |
| SOS contacts with consent (B10) | Signed in + paired: Settings → Account → switch on → "2 contacts ready"; `select count(*) from emergency_contacts` matches; switch off → 0. Built, unverified until migrations 100100/100200 are applied |
| SOS status | After a watch SOS, Account shows "Last SOS …: test mode, no text or call was sent" while Twilio is not configured |
| Watch data only for its owner (B9) | `backend/supabase/tests/run-rls.sh` → ALL ACCOUNTS RLS CHECKS PASSED; on the emulators: paired + signed in shows the watch's heart rate, signed out shows nothing for it |
| Ledger exceptions | Settings → Privacy → What left my phone → `/rest/v1/profiles` rows list field names with `exception: PROFILE_SYNC` |

## DESIGN.md subsection (new screens only)
- **Welcome** (first launch, signed out, nothing on the phone): `bg`, orb 96, "Celia" in `title-1`, tagline in
  `body` `ink_2`, a `surface` card (1 vp `border`, `radius_l`, padding 16) with three rows (icon well 36 on
  `surface_alt` + `font_small` text): medicine check offline, watch heart rate, emergency card offline. Bottom:
  primary `Create an account`, secondary `I already have an account`, quiet `Set up without an account` with a caption
  that the profile then stays on the phone, then the disclaimer caption in `ink_4`. Back does nothing.
- **Sign up / Log in**: title in `title-1`, one `font_small` `ink_3` line on what the account is for, then the form:
  labelled 48 vp inputs on `surface_alt` (`radius_m`), primary button (inactive until both fields have text), a
  `brand_text` link to switch mode, disclaimer caption. Errors use the amber 6.7 strip in plain words, never red;
  "check your email" uses the neutral strip. While working: `LoadingProgress` 28 in `brand_accent` + "One moment…".
- **Account** (Settings → Account): signed in - `surface` card with "Signed in as" caption, email in `headline`, the
  backup line (`font_small`; offline → neutral strip, failure → amber strip), secondary `Back up now`; secondary
  `Sign out` (dialog: keep data / delete from this phone, the latter in `risk_known` text); "WHERE YOUR DATA IS" card;
  a centred `risk_known` text action "Delete my data from my account" with a confirm dialog. Signed out - one body
  line, primary `Log in`, secondary `Create an account`, the same data card.

## ARCHITECTURE notes
- Decision: medicines ride in the same `profiles.data` document as the profile (`{v: 1, profile, meds[]}`): one
  round trip, one RLS policy set, one timestamp. A newer `v` than the app knows is ignored, never half-applied.
- Last-write-wins is decided on the phone after reading the account copy; `updated_at` is the local edit time, not
  the upload time. Two phones editing offline at once: the later edit wins on both.
- Local data that was last synced with another account (setting `sync_owner`) is never pushed: the account copy is
  pulled if one exists, otherwise nothing is uploaded. Known limit: in that case the new user's edits stay local until
  they wipe the phone data (Account → Sign out and delete) or their account has a copy.
- Sign-out keeps local data unless "Sign out and delete" is chosen. "Delete my data from my account" deletes the
  `profiles` row and signs out (so the next edit does not upload it again); the `auth.users` row stays (no safe
  self-delete RPC yet).
- Settings → "Clear all data" (existing, not this stream's) wipes the stored session too; the in-memory session lives
  until the app restarts.
- "Set up without an account" exists because sign-up needs a network and the card must work from the first launch.

- Phase 2 deviation: I could not merge `georgi/b-watch` into this branch (blocked), so the watch half of B9 is a
  patch file instead of commits.
- B9 trade-off: a watch that never paired can still upload under its random id with the public key (nobody can read
  those rows back); once it has a secret, uploads need it. The demo watch stays public on purpose.
- Pairing a watch now needs an account: an unbound watch's data could not be read by anyone.

## For Workstream A (routes, functions, contracts)
- Routes: `welcome`, `auth` (param `AuthParam('SIGN_UP' | 'LOG_IN')`), `account`.
- `Session`: `isSignedIn()`, `userId()`, `userName()`, `email()`, `accessToken()` (may be expired offline),
  `signOut()`, `onChange(cb)`; new and safe to call: `Session.freshToken()` (refreshes first when due).
- `AuthForm`: `@Param mode`, `@Event onDone(signedIn)`, new optional `@Event onModeChange(mode)`.
- Requests made as the user: `accountTarget(await Session.freshToken())` from `common/Net.ets`.

## B9 plan and deploy order
1. Apply `20261004100000` (accounts) and `20261004100100` (contacts, binding) - compatible with every current build.
2. Install the new phone build (sends the JWT on `/rest/v1/`, binds pairings). Sign in, re-open Pair watch: an
   existing pairing is bound automatically after sign-in (or pair again).
3. Apply `20261004100200` (owner-only reads). Retest: phone paired + signed in sees live heart rate and Trends;
   signed out it shows nothing for the paired watch; unpaired shows the demo watch. Old watch builds keep working.
4. Merge `georgi/b-watch` into integration, apply `docs/workflow/b-accounts-watch-secret.patch` (`git apply`),
   build both, install the watch, pair it again from the phone (it receives its secret), then apply
   `20261004100300`. Retest: watch uploads, watch context (genotype / risky drug badge), SOS, demo RPC.
   Do not apply 100300 before the watch build that sends the header.
5. Rollback for 100200/100300: re-create the old anon policies from 20261003150000 (watch_metrics), 20261003180000 (watch_context), 20261003230000 (resting_day_sim) and 20261003200000 (emergency_contacts insert).

## Coordinator actions
- Apply `backend/supabase/migrations/20261004100000_profiles_auth.sql` (after Georgi's OK).
- Apply `20261004100100`, `20261004100200`, `20261004100300` in the order above; deploy the `sos` function
  (reads `sos_profile`).
- After `georgi/b-watch` is in integration: `git apply docs/workflow/b-accounts-watch-secret.patch` (watch side of
  B9 part 2), run the watch tests.
- Georgi: turn off Authentication → "Confirm email" (code also handles it on).
- `scripts/worktree.sh` does not copy the local signing block of `app/build-profile.json5`; the worktree needed it
  copied by hand (kept out of git with `skip-worktree`).

## Incident
- One emulator command chained `emu.sh lock … | tail -1 && …`; the pipe hid the lock timeout, so the app was
  uninstalled and reinstalled on the phone emulator while the `emergency` stream held the lock (around 00:00). Their
  install may have been replaced; they may need to reinstall. Later runs check the lock first and pass
  `-t 127.0.0.1:5555` (a second target, the watch emulator on 5557, makes plain `hdc` refuse to pick one -
  `app/scripts/run.sh` and `ui.sh` fail in that state).
