# Workstream B - Accounts, onboarding, emergency and platform integrations (Georgi)

You are an agent working in the Celia.ai repo. This file is your whole brief. Read it fully, then read `CLAUDE.md`
and `docs/design/DESIGN.md` before touching code. A second agent works in parallel on Workstream A
(`docs/handoff/KALOYAN_agent_and_ui.md`): the agent screen, the orb, navigation and the visual pass over the app.
Do not do A's work; the contract between the two is in section 6.

## 1. Project in one paragraph

Celia.ai is a native HarmonyOS app (ArkTS + ArkUI, API 20+) for people with Long QT syndrome (LQTS): an AI agent you
talk to, a deterministic medicine check (type, scan, photograph a box), a watch app that monitors heart rate, an
emergency card and SOS flow, and a doctor-visit brief. Built for HackYeah 2026, Huawei task "Imagine What's Next".
Submission: **Sunday 4 October 2026, 11:00**. A real Huawei phone is available only from Sunday 08:00; until then
everything runs on emulators. Judging: Originality 20, Usefulness 20, Technical execution 20, Platform capabilities
20, Demo 10, Workflow transparency 10. False or misleading claims can disqualify the team.

## 2. Your mission

The owner's words: we need authentication and a simple onboarding that still gathers everything needed; everything
is saved under the account, with the session and key data kept on the phone so the app works offline. The emergency
page must be configurable so people can add much more about themselves. When paramedics arrive, the phone must show
them what the patient has, what not to give, and what to give instead. Notifications are needed. Live View and
lock-screen presence need research into how to get access. NFC and similar may be built without being tested, as
long as they are labelled that way.

**Product decision (changes earlier docs):** the app has accounts. It is no longer "offline core, no login". The
rule is now: sign in once, then the app keeps working offline from a cached session and cached data; the emergency
card and medicine check must open with no network.

## 3. Rules that always apply

- Load the relevant skill before writing HarmonyOS code: `arkts-language`, `arkui-development`,
  `harmonyos-app-model` (permissions, abilities), `harmonyos-kits`, `harmonyos-build-deploy`, `lqts-domain`,
  `supabase-postgres-best-practices` for SQL. Verify any API you are unsure of in Context7
  (`/websites/developer_huawei_consumer_cn_doc_harmonyos-guides`, `..._harmonyos-references`). Training-data
  knowledge of HarmonyOS is stale.
- Before any UI decision, read `docs/design/DESIGN.md` and use its tokens and the resource names in
  `app/entry/src/main/resources/base/element/*.json`. No hard-coded colours or sizes. For a new screen, append a
  short subsection to DESIGN.md (Workstream A owns the file; keep to existing tokens).
- Strict ArkTS: no `any`, no untyped object literals, no destructuring, no index signatures.
- No React, Android or Flutter patterns. Networking is `@kit.NetworkKit` through `common/Net.ets`; there is no
  `supabase-js` in the app, so Supabase Auth and PostgREST are called over plain HTTPS.
- **Medical safety:** everything shown to a paramedic or on the emergency card comes from deterministic data in the
  repo (`drugs/DrugDataset.ets`, the `lqts-domain` skill, `agent/ConditionFacts.ets`). No LLM text on those
  screens. Do not write medical facts from memory; take them from `lqts-domain` and cite the source in a comment.
- Everything in English. No secrets in the repo (keys, signing files, `.env*`, `agconnect-services.json` if it
  holds secrets).
- Commit small and often, Conventional Commits, **no AI attribution** in commits or PRs.
- Other sessions edit the same tree. Stage explicit file paths only. Append to `string.json`, `color.json`,
  `float.json` with read-modify-write.
- Keep `AI_WORKFLOW.md` updated: one entry per session (asked, produced, validated, not validated).
- **Honesty:** a feature that was built but not tested on a device is marked "built, unverified" in the README
  verify table and in `docs/ARCHITECTURE.md`. Simulated data shows a `SIMULATED` badge. Do not apply a database
  migration, deploy a function or change project settings without the owner's go-ahead: both builders share one
  Supabase project and a breaking change stops the other person's app.

## 4. Where things are

All phone paths are under `app/entry/src/main/ets/`.

| Area | Files |
|---|---|
| Onboarding | `pages/OnboardingPage.ets` (348 lines, 4 steps: name + genotype + ICD, medicines, contacts, country + notes). Pushed from `pages/Index.ets:84` when `getProfile()` is undefined |
| Profile | `model/Profile.ets`: `condition`, `genotype`, `hasIcd`, `notes`, `contacts[] {name, phone, relation, email?}`, `name?`, `country?`, `cardLanguage?`. Stored as JSON under key `profile` in table `kv` of the encrypted RDB (`data/LocalStore.ets`, `encrypt: true`) |
| Settings | `pages/SettingsPage.ets` (profile, contacts, country, pair watch, test SOS, privacy, clear data) |
| App lock | `common/AppLock.ets` (`userAuth`: face, fingerprint, PIN; off by default), `components/LockScreen.ets`, toggle in `pages/PrivacyPage.ets` |
| Emergency | `pages/EmergencyPage.ets` (602 lines): call button, contacts, SOS / Bystander / Pharmacy rows, nearby help, full card, 13 languages (`common/CardStrings.ets`), read aloud, QR (`emergency/CardLink.ets`) |
| SOS | `emergency/SosController.ets` (30 s countdown, 10 min cooldown), `pages/SosPage.ets`, `emergency/SosService.ets`, `emergency/SosMessage.ets`, `emergency/LiveStatus.ets` (Live View with notification fallback) |
| Card viewer (web) | `site/card/index.html`, share crypto in `share/ShareCrypto.ets`, `share/ShareService.ets` |
| Doctor prep | `pages/DoctorPrepPage.ets`, `doctor/DoctorPrep.ets` (7 specialties, fixed watch-outs and questions), `doctor/DoctorSummary.ets` → `/doctor-summary` |
| Symptoms | `pages/SymptomLogPage.ets`, `model/SymptomEntry.ets`, check-in sheet in `pages/Index.ets` |
| Notifications | `common/Notify.ets` (ids 1001-1003, plain text, no slots or action buttons), `reminders/ReminderService.ets` (`reminderAgentManager`; the system refuses with 1700002 until an AGC quota is granted) |
| Widgets | `entryformability/EntryFormAbility.ets`, `widget/pages/CheckCard.ets` (2×2), `widget/pages/AlertCard.ets` (2×4) |
| Privacy ledger | `privacy/Ledger.ets`; `FORBIDDEN_FIELDS` (name, phone, email, contacts, notes, address, lat, lon, location) blocks requests in `common/Net.ets` and `agent/BackendClient.ets` |
| Config | `common/Config.ets`, gitignored `common/LocalConfig.ets` (template `LocalConfig.example.ets`). `BACKEND_URL` may be a local AI proxy on `127.0.0.1`; the real Supabase project URL is `Config.SHARE_BACKEND_URL` |
| Watch | `watch/entry/src/main/ets/`: `controller/WatchController.ets` (about 1,200 lines), `sync/*`, `vitals/*`, `components/*` |
| Backend | `backend/supabase/migrations/` (17 files), `backend/supabase/functions/` (`sos`, `share`, `agent`, ...) |

### Facts you need before you start

- **No auth exists.** No Account Kit, no Supabase Auth, no user id. Every request uses the public anon key. No auth
  tables or policies are in `backend/supabase/migrations/`. Supabase advisors once flagged a `handle_new_user`
  function in the deployed project; check what is there before creating anything.
- **Row-level security is open.** `watch_metrics` has anon `select using (true)`; `watch_context` has anon insert
  and update `with check (true)`; `emergency_contacts` has anon insert. Anyone with the anon key can read every
  device's heart data and SOS location and overwrite genotype. Accounts are the way to close this.
- **Watch pairing** works with a 6-digit code: RPCs `pairing_start`, `pairing_claim`, `pairing_status`,
  `pairing_device` (`20261003260000_watch_pairing.sql`), phone side `data/WatchPairing.ets`. The token is stored
  hashed but not used for row access.
- **SOS does not notify anyone by itself.** After the countdown the phone shows buttons: call (dialler, user
  confirms) and share message (system share sheet). Direct SMS is impossible for third-party apps. The server
  function `backend/supabase/functions/sos` (Twilio SMS + voice call with `<Say>`) is complete but inert: nothing
  writes `emergency_contacts` or `watch_context.patient_name`, and the secrets are not set. There are no Twilio
  credentials.
- **A watch SOS runs two countdowns:** the server dispatches as soon as the `sos` row lands, and the phone starts
  its own 30 s countdown for the same event.
- **Monitoring on the watch is foreground-only.** No continuous task. Timers: 1 s tick, accelerometer 25 Hz, upload
  every 3 s while visible, outbox rewritten to Preferences on every enqueue.
- **Phone ↔ watch is a cloud relay** through Supabase REST. The two emulators cannot see each other over
  Bluetooth; Wear Engine needs AGC approval.
- Tests: 211 phone, 43 watch, 68 backend, all passing on branch `kaloyan/final-pass`.

## 5. Tasks

### Phase 1 - must work and be verified on the emulator before the deadline

**B1. Accounts: sign up, log in, stay signed in offline.**
- Use Supabase Auth over HTTPS against `Config.SHARE_BACKEND_URL` (the real project), with the anon key in the
  `apikey` header. Endpoints to confirm in the Supabase docs before coding: `POST /auth/v1/signup`,
  `POST /auth/v1/token?grant_type=password`, `POST /auth/v1/token?grant_type=refresh_token`, `POST /auth/v1/logout`.
  Email + password is enough. Instant sign-up needs "confirm email" turned off in the project; ask the owner.
- New folder `account/`: `AuthClient.ets` (HTTP), `Session.ets` (holds access token, refresh token, expiry, user
  id, email; persists them in the encrypted RDB through `LocalStore`; refreshes before expiry; exposes
  `Session.isSignedIn()`, `Session.userId()`, `Session.userName()`, `Session.accessToken()`, `Session.signOut()`).
- Offline: with a stored session the app opens straight to the main screen with no network, even if the token has
  expired; it refreshes when the network returns. The emergency card and medicine check never wait for auth.
- Screens: Welcome (what the app is, "not a medical device"), Sign up, Log in, and an Account section in Settings
  (email, sign out, delete my cloud data).
- Requests that carry the user's JWT send `Authorization: Bearer <access token>` instead of the anon key. Add this
  to `common/Net.ets` in one place.
- Privacy ledger: the profile sync legitimately carries name and contacts. Add an explicit, named exception for
  that one endpoint (do not weaken `FORBIDDEN_FIELDS` globally) and log it in the ledger like every other request.
- Tests: pure logic for session expiry, refresh decision, response parsing, and "offline with stored session".
- Acceptance: sign up → kill the app → reopen with the network off → lands signed in with the profile and card.

**B2. Profile saved under the account.**
- Migration: table `profiles` (`user_id uuid primary key references auth.users`, `data jsonb`, `updated_at`), RLS
  on, policies `using (auth.uid() = user_id)` for select, insert, update, delete. Nothing for anon.
- Phone: the local RDB copy stays the source the UI reads. Sync is last-write-wins on `updated_at`: push after a
  local edit, pull at sign-in and at launch when online. Signing in on a fresh install restores the profile and
  skips onboarding.
- Medicines can ride in the same document or a second table; choose one and write it in `docs/ARCHITECTURE.md`.

**B3. Onboarding.**
Simple, but it gathers everything needed. One question group per screen, progress shown, every optional step has
Skip, nothing is lost when going back.
1. Welcome and consent ("Not a medical device. Always ask your doctor or pharmacist.").
2. Account (B1).
3. About you: name, date of birth, genotype (LQT1 / LQT2 / LQT3 / Not sure), ICD yes/no and model.
4. Medicines (reuse `components/AddMedForm.ets`; each one is checked by `DrugChecker` as it is added).
5. Emergency contacts.
6. Emergency details (B4 fields).
7. Permissions, each with one sentence of why: notifications, microphone, location. Ask at the moment it is
   explained; today notifications are requested on every launch from `pages/Index.ets:72`, move that here.
8. Pair a watch (optional; route `pairWatch` exists).
Acceptance: a new user finishes in under two minutes; a returning user who signs in skips to the app.

**B4. Configurable emergency profile.**
- Add to `model/Profile.ets`: date of birth, sex, blood type, allergies (list), cardiologist name and phone,
  hospital, ICD model, and `extra[]` of `{label, value}` so the user can add anything else.
- Old stored profiles must still load (every new field optional, defaults applied on read).
- Edit in Settings and in onboarding. Show on the emergency card in a fixed order; empty fields are hidden. The
  user can choose which fields appear on the shared card (a "show on card" switch per field).
- `common/CardStrings.ets` has 13 languages. Add English labels for new fields and fall back to English where a
  translation is missing; do not invent translations.
- The QR / share payload and `site/card/index.html` must render the new fields. Version the payload so old links
  still open. Keep the unencrypted-fragment fallback (`emergency/CardLink.ets`) small enough for a QR code.

**B5. First-responder view.**
A full-screen page for the person who arrives to help. Route `responder`.
- Content, in this order, large type, always-light `card_fixed_*` colours:
  1. Who and what: name, age, "Long QT syndrome", genotype, ICD yes/no and model.
  2. **Do not give**: the drug classes and named drugs to avoid, from `drugs/DrugDataset.ets` (known-risk entries
     and `avoidCongenital`) and the `lqts-domain` emergency facts.
  3. **Use instead**: alternatives from the dataset's `alternatives[]`, grouped by what they replace.
  4. Immediate care notes from `lqts-domain` (take them from the skill, with its sources).
  5. Current medicines and the last risky medicine taken with its time (`drugs/DrugIntake.ets`, `riskyIntakeLast`).
  6. Allergies, blood type, cardiologist, hospital, emergency contacts with call buttons.
- No LLM. Opening the page makes no network request (check the ledger).
- Reachable from: the top of the Emergency tab, the SOS page once the countdown ends, the app lock screen
  (`components/LockScreen.ets` already has a Bystander button), the 2×4 alert widget, and a route name handed to
  Workstream A for the agent and the home quick actions.
- Language follows `cardLanguage` where strings exist, English otherwise.
- Tests: the do-not-give and use-instead lists for a given profile are pure functions; unit-test them.

**B6. Doctor visit prep with questions.**
- Flow: "Add a visit" → which doctor (the 7 specialties), date, reason for the visit, what worries you → the app
  builds the deterministic brief (`doctor/DoctorPrep.ets`) and the AI writes the summary (`/doctor-summary`) from
  the brief plus the answers.
- `doctor/DoctorSummary.ets` already rejects replies with banned words or doses; keep that. The free-text answers
  go to the model, so strip names and contacts and add the new fields to the request validation in the function.
- Save visits (list, reopen, delete). The agent tile already opens the page on a specialty
  (`DoctorPrepParam` in `common/Routes.ets`); keep that working.

**B7. Local notifications that can be acted on.**
- `common/Notify.ets`: proper slots per kind (emergency, heart alert, dose due, risky check), and action buttons
  where the kit allows them: "Taken" on a dose, "I'm OK" / "Open" on an alert. Verify the wanted-agent / action
  button API in Context7 first.
- Tapping a notification opens the right page (see `EntryAbility.ets` `handleCardTap` for the existing pattern).

**B8. SOS honesty and one countdown.**
- A watch SOS must not start a second 30 s countdown on the phone; open the SOS page already in its "sent" state.
- The SOS page states plainly what happened: what was sent, to whom, and what still needs a tap.

### Phase 2 - more. Build after Phase 1 is merged; may ship unverified if labelled so

**B9. Close the RLS hole with accounts.** Bind a paired device to `auth.uid()` in `watch_pairings`; replace the
open policies on `watch_metrics`, `watch_context`, `emergency_contacts` with policies through that binding; give
the watch its own secret from `pairing_start` and expose its reads and writes as `security definer` RPCs that check
it. Update `vitals/WatchCloudSource.ets`, `vitals/WatchContextSync.ets`, `data/WatchDataClient.ets`,
`vitals/RestingHistory.ets` and the watch's `sync/*Client.ets`. Needs the owner's go-ahead and a retest of both
emulators before and after.

**B10. Emergency contacts reach the server.** With consent (a switch, off by default, explained), sync contacts and
the patient's first name to `emergency_contacts` / `watch_context.patient_name` under the account. Then the `sos`
function has someone to notify. Without Twilio secrets it records `dry_run`; show that status in the app (read
`sos_dispatches` through an RPC). Update the "What leaves the phone" table in the README in the same commit.

**B11. Voice call to emergency contacts.** The Twilio path exists (`backend/supabase/functions/sos/twilio.ts`:
SMS plus a call that reads the message twice). It needs `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`,
`TWILIO_FROM_NUMBER`, `SOS_WEBHOOK_SECRET` and the Vault secrets `sos_function_url`, `sos_webhook_secret`. The
owner will send a reference implementation from an earlier project (Cardbeat); ask for it before designing a
conversational agent. Until credentials exist this stays "built, unverified".

**B12. Push notifications (Push Kit).** Research first and write the steps into `docs/research/push-kit.md`: AGC
project and app id, enabling Push Kit, client id in `module.json5`, getting the push token (`@kit.PushKit`),
storing it under the account, sending from an Edge Function (Huawei Push REST API, OAuth client credentials),
emulator support. Then implement token registration and one server-sent alert (watch SOS → phone). State clearly
what needed an account or approval you did not have.

**B13. Live View and lock-screen presence.** `emergency/LiveStatus.ets` already calls `liveViewManager` and falls
back to a notification because the scenario is not approved. Research and write `docs/research/live-view.md`: how
to apply for the Live View Kit scenario in AGC, which scenario type fits an emergency countdown, what the capsule
and lock-screen card can show, test steps on a real phone. Also research whether a medical-ID style card can be
shown on the lock screen by a third-party app (widget on the lock screen, Form Kit lock-screen cards). Implement
what is possible; list the rest as blocked with the reason.

**B14. NFC handover of the emergency card.** Build, expect not to test (no NFC on the emulator): write the card
link as an NDEF URI record to a tag (`@kit.ConnectivityKit`, tag / NDEF modules; verify names and the
`ohos.permission.NFC_TAG` permission in Context7), from a "Write to NFC tag" action next to the QR. Guard on NFC
availability. Mark "built, unverified" everywhere it is mentioned.

**B15. Feeling diary and shortcuts.** A quick "How are you feeling?" entry (mood plus optional note) stored as an
event in `LocalStore` next to symptoms; reachable from a widget action and from the route Workstream A puts on the
agent home. Workstream A's Trends reads watch data today; give A a pure function that returns diary and symptom
counts per day so the chart can show them.

**B16. Watch internals.** Split `WatchController.ets` (sensors, rules, SOS, sync, pairing). Energy: lower the
accelerometer rate at rest, write the outbox once per sync instead of per enqueue, reuse one HTTP client. Research
background monitoring (continuous task with a suitable background mode on wearables, Health Service Kit) and write
what approval it needs into `watch/README.md`. Add a build-and-install script for the watch like
`app/scripts/run.sh`.

**B17. Production wiring of phone ↔ watch.** Write `docs/research/phone-watch-link.md`: Wear Engine (what it
offers, how to apply), distributed data objects, the cloud relay used today, and a recommendation. No code needed
unless access is granted.

**B18. Huawei Account Kit** as a second sign-in method. Research what it needs in AGC; implement only if access
exists.

## 6. Contract with Workstream A

| Thing | Owner | Rule |
|---|---|---|
| `model/Profile.ets`, profile methods in `data/LocalStore.ets` | You | Announce new fields; keep old profiles loading |
| `account/Session.ets` | You | Keep `isSignedIn()`, `userId()`, `userName()`, `accessToken()`, `signOut()` stable; A only calls them |
| Routes | Each adds their own constants to `common/Routes.ets` and their own branch in `pages/Index.ets` `routeMap` | You add `welcome`, `account`, `responder`, and any visit routes. `trends` and `DoctorPrepParam` already exist |
| Pages you own | `OnboardingPage`, `EmergencyPage`, new `ResponderPage`, `SettingsPage`, `PrivacyPage`, `DoctorPrepPage`, `SosPage`, `BystanderPage`, `PharmacyCardPage`, `PairWatchPage`, `LockScreen` | A restyles them only after you say the feature is merged |
| Pages A owns | `MainTabs`, `HomePage`, `AgentPage`, `components/agent/*`, `VoiceOrb`, `MedicinesPage`, `HeartPage`, `TrendsPage`, `Common.ets` | Give A a route name; A places the entry point |
| DESIGN.md | A | You may append a subsection for a new screen using existing tokens |
| `string.json` and other resource files | Both | Append-only |
| `watch/` | Controller, sync, sensors, energy: you. Look of the screens: A (Phase 2) | |
| `backend/` | Auth, tables, RLS, SOS, push: you. Prompt, tools, AI functions: A | |

Merge to `main` at least every 2-3 hours. `main` must always build. If you must touch a file A owns, keep it to a
small addition and say so in the commit body.

## 7. Build, run, test

```bash
# phone
app/scripts/test.sh                       # 211 unit tests, no device needed
app/scripts/run.sh [screenshot.jpeg]      # build → install → launch → screenshot (emulator 127.0.0.1:5555)
app/scripts/ui.sh list | tapt "text" | tap X Y | type X Y "text" | swipe X1 Y1 X2 Y2 | back | shot [file]
app/scripts/device.sh check               # preflight for a real phone (signing, API level, backend reachable)

# watch
cd watch && source env.sh
hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon
hvigorw test -p module=entry -p coverage=false --no-daemon          # 43 tests

# backend
npx -y deno test --no-lock backend/supabase/functions/              # 68 tests

# logs
hdc shell hilog -x | grep CeliaAI
```

The unit tests run with `Config.forceOffline(true)`, so they never call the network. For auth, test against the
real project from the emulator: `LocalConfig.ets` needs the real anon key in `SHARE_ANON_KEY` (or
`SUPABASE_ANON_KEY`). If the emulator drops off hdc:
`/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator -hvd "Pura 90"`.

## 8. Docs you must update when accounts land

The current docs say the profile, contacts and notes never leave the phone. With B2 and B10 that stops being true.
In the same commits, update: README "What leaves the phone" table, `AI_FEATURES.md` §3, `docs/ARCHITECTURE.md` data
rule, `docs/PRODUCT.md` decision D6, `docs/TASKS.md` ("Out of scope: user accounts"), `docs/IDEA.md` sovereignty
paragraph. Say where the data is stored, who can read it (RLS by user), and how to delete it.

## 9. Done means

- All three test suites pass and both apps build.
- Each Phase 1 task has a screenshot from the emulator and a line in `AI_WORKFLOW.md` saying what was and was not
  validated.
- README "How to verify each feature" has a row for every new feature, with "built, unverified" where that is the
  truth.
- Each Phase 2 research task has its file in `docs/research/` with sources and a clear "needs: ..." list.
