# Workstream B — parallel plan (Georgi)

How Workstream B (`docs/handoff/GEORGI_account_and_emergency.md`, "the brief") is split across parallel Claude Code
agents, each in its own git worktree and branch. Read the brief first; this file adds who does what, which files each
stream owns, and the rules that keep seven agents from breaking each other. Deadline: Sunday 4 October 2026, 11:00.

## 1. Shape

```
main ──────────────────────────────────────────────── (Kaloyan merges Workstream A here too)
  └─ georgi/integration          coordinator session merges streams here, runs all tests + emulator, then → main
       ├─ georgi/b-accounts       S1  B1 B2            → then B10, B9
       ├─ georgi/b-emergency      S2  B4 B5            → then B14
       ├─ georgi/b-onboarding     S3  B3               → then QA pass over every B flow
       ├─ georgi/b-notify-sos     S4  B7 B8            → then B13 / B12 code (after S7's research)
       ├─ georgi/b-doctor         S5  B6 B15
       ├─ georgi/b-watch          S6  B16
       └─ georgi/b-research       S7  B12 B13 B17 B18 research docs, B11 notes
```

- Worktrees live in `../Celia.ai-wt/<stream>`, created with `scripts/worktree.sh <stream>` (branches from
  `georgi/integration`, copies the gitignored `LocalConfig.ets`, runs `ohpm install`).
- The **coordinator** is the Claude Code session in the main checkout (`georgi/integration`). It merges a stream when
  the stream reports `READY FOR MERGE`, runs the three test suites and an emulator smoke test, applies migrations
  and deploys functions after Georgi's OK, folds the stream notes into `AI_WORKFLOW.md` / README / DESIGN.md, and
  merges `georgi/integration` into `main` every 2-3 hours.
- Visual design is out of scope for every B agent: Georgi designs separately (Claude design), Kaloyan owns the look.
  Build screens that are functional, accessible and token-correct with the existing components in
  `components/Common.ets`; no visual experiments.

## 2. Foundation already on `georgi/integration` (do not redo)

- `model/Profile.ets`: new optional fields `dateOfBirth`, `sex`, `bloodType`, `allergies`, `icdModel`,
  `cardiologistName`, `cardiologistPhone`, `hospital`, `extra[]` (`ExtraField {label, value}`), `hiddenOnCard[]`
  (ids from `CardField`), `updatedAt`; `BLOOD_TYPES`; `CardField` ids.
- `common/Routes.ets`: `WELCOME`, `AUTH` (param `AuthParam {mode: 'SIGN_UP' | 'LOG_IN'}`), `ACCOUNT`,
  `EMERGENCY_PROFILE`, `RESPONDER`, `VISITS`, `FEELING`. Each already has a stub page in `pages/` and a branch in
  `pages/Index.ets` `routeMap`. **Replace the stub's contents; do not add new routeMap branches for these.**
- `account/Session.ets`: the stable API (`isSignedIn`, `userId`, `userName`, `email`, `accessToken`, `signOut`,
  `onChange`). Stub = always signed out. S1 fills it in; everyone else only calls it.
- `components/AuthForm.ets` (`@Param mode`, `@Event onDone(signedIn)`) — S1 implements, S3 embeds in onboarding.
- `components/EmergencyDetailsForm.ets` (`@Param profile`, `@Event onChange(profile)`, never saves) — S2
  implements, S3 embeds in onboarding, S2 uses it in `EmergencyProfilePage`.
- `app/scripts/emu.sh lock|unlock|status` — the emulator lock (§3).
- Verified: HarmonyOS accepts extra files in `resources/base/element/` (e.g. `string_accounts.json`); the build merges
  them.

## 3. Rules for parallel work (on top of the brief §3 and CLAUDE.md)

1. **Stay in your worktree and your branch.** Never check out, merge into, or push `main` or `georgi/integration`.
   Do not push at all; the coordinator merges local branches. To pick up merged work from others:
   `git merge georgi/integration` into your branch (only when the coordinator says so, or at the start of Phase 2).
2. **Commits:** small Conventional Commits on your branch, authored by the repo's git identity. **No AI attribution**
   (no `Co-Authored-By`, no "Generated with" lines). Stage explicit paths only, never `git add -A` / `git add .`.
3. **Own your files.** Edit only files your stream owns (§4). If you must touch another stream's file, keep it to a
   few lines and say so in the commit body. Shared hot spots and how to touch them:
   - `pages/Index.ets` — only the lines your task names (S1 launch routing, S3 notification ask, S4 watch SOS).
   - `pages/SettingsPage.ets` — S1 adds one `NavRow` to Account, S2 one to Emergency details. Nothing else.
   - `data/LocalStore.ets` — S1 `saveProfile` (stamp `updatedAt`), S2 `getProfile` (defaults on read). Others store
     through existing `getSetting/setSetting/logEvent`; no schema changes without the coordinator.
   - `README.md` — only S1 edits the "What leaves the phone" section (brief §8). Everyone else: notes file (rule 5).
4. **Strings:** never edit `string.json`. Put new strings in `app/entry/src/main/resources/base/element/
   string_<stream>.json` (e.g. `string_accounts.json`), keys prefixed with your stream (`acc_`, `em_`, `onb_`, `ntf_`,
   `doc_`). Colours and sizes: use existing tokens only; if one is truly missing, ask the coordinator.
5. **Notes instead of shared docs:** write your `AI_WORKFLOW.md` entry, README "How to verify" rows, DESIGN.md
   subsection for new screens, and ARCHITECTURE notes into `docs/workflow/b-<stream>.md`. The coordinator folds them
   into the real files at merge. Format at the end of this file.
6. **Backend:** write migrations and function code + Deno tests only. **Never apply a migration, deploy a function,
   or change project settings** — the coordinator does that after Georgi's OK (shared project with Kaloyan's app).
   Read-only SQL on the live project through the Supabase MCP is fine. Migration timestamp ranges, so names never
   clash: S1 `20261004100000-109999`, S4 `2026100411xxxx`, S5 `2026100412xxxx`, S7 `2026100413xxxx`.
7. **Emulator (one phone emulator, `127.0.0.1:5555`):** build and unit-test any time. Before `run.sh`, `ui.sh`, or any
   `hdc install/shell`, run `app/scripts/emu.sh lock <stream>`; when your screenshots are saved,
   `app/scripts/emu.sh unlock`. Hold it for minutes, not hours. Installing replaces whatever another stream had
   installed, so log in / onboard again if your test needs it. Save screenshots to
   `docs/screenshots/b/<stream>-<what>.jpeg`.
8. **Tests:** `app/scripts/test.sh` must pass before every `READY FOR MERGE` (211+ phone tests). Watch and backend
   suites too if you touched them. Add tests for every pure function.
9. **Honesty:** built-but-not-device-tested = "built, unverified" in your notes. Simulated data = `SIMULATED` badge.
   Medical content only from `drugs/DrugDataset.ets`, the `lqts-domain` skill, `agent/ConditionFacts.ets`, with the
   source cited in a comment. No LLM text on emergency or responder screens.
10. **Ask Georgi** (in your terminal) when you are blocked on a decision that is his; otherwise pick the sensible
    default, note it, and keep going.
11. **Done = report.** When a phase is finished, end your turn with:
    ```
    READY FOR MERGE: georgi/b-<stream> @ <short sha>
    Tests: phone N/N, watch N/N, backend N/N (or "not touched")
    Emulator: <what you verified, screenshot paths>
    Coordinator actions needed: <migrations to apply, functions to deploy, settings, or "none">
    Touched outside my files: <list or "none">
    Unverified: <list>
    ```

## 4. Streams

### S1 — accounts (`georgi/b-accounts`): B1, B2; Phase 2: B10, then B9

Owns: `account/*` (AuthClient, Session, ProfileSync), `components/AuthForm.ets`, `pages/WelcomePage.ets`,
`pages/AuthPage.ets`, `pages/AccountPage.ets`, `common/Net.ets` (JWT header in one place), `privacy/Ledger.ets`
(named exception for the profile sync endpoint only), `common/Config.ets` if needed, launch routing in
`pages/Index.ets` (`showOnboardingIfNeeded`: signed out and no local profile → Welcome; stored session → straight in,
offline too), `LocalStore.saveProfile` (stamp `updatedAt`), migrations in its range, the privacy docs in brief §8.

Facts found on the live project (`jxiggumhircfuhianmel`, read-only, 2026-10-03 22:40):
- Trigger `on_auth_user_created` on `auth.users` runs `public.handle_new_user()`, which inserts into
  `public.profiles(id, display_name)`. **That table does not exist, so every sign-up fails today** ("Database error
  saving new user"). Georgi's decision: the first migration drops the trigger and the function, then creates
  `profiles (user_id uuid primary key references auth.users on delete cascade, data jsonb not null, updated_at
  timestamptz not null default now())` with RLS on and four `auth.uid() = user_id` policies for `authenticated`,
  nothing for `anon`. One user already exists in `auth.users`.
- "Confirm email" will be turned off by Georgi (instant sign-up). Code must still handle a sign-up response with no
  session (show "check your email") in case it is on.
- Edge functions `share` and `sos` have `verify_jwt: false`; the others `true`.

Decide and record in your notes: medicines in the same `profiles.data` document or a separate table (recommend: same
document, one round trip, one RLS policy). Sign-out keeps local data unless the user also chooses "delete my data on
this phone". "Delete my cloud data" deletes the `profiles` row (and later contacts) — not the auth user unless you add
a safe RPC for it.

Acceptance (brief B1): sign up → kill app → network off → reopen → signed in, profile and card present. Pure tests for
session expiry, refresh decision, response parsing, offline-with-stored-session, last-write-wins merge.

Phase 2: B10 (consent switch, contacts + first name to `emergency_contacts` / `watch_context.patient_name` under the
account, `sos_dispatches` status through an RPC, README table updated in the same commit), then B9 (RLS through
device ↔ account binding — needs Georgi's go-ahead and a before/after retest of both emulators; plan it in your notes
first and wait for "go").

### S2 — emergency (`georgi/b-emergency`): B4, B5; Phase 2: B14

Owns: `components/EmergencyDetailsForm.ets`, `pages/EmergencyProfilePage.ets`, `pages/EmergencyPage.ets`,
`pages/ResponderPage.ets`, new `emergency/Responder.ets` (pure do-not-give / use-instead / care-notes functions),
`emergency/CardContent.ets`, `emergency/CardLink.ets`, `emergency/CardSpeech.ets`, `common/CardStrings.ets`,
`share/*`, `site/card/index.html`, `components/LockScreen.ets`, `pages/BystanderPage.ets`,
`pages/PharmacyCardPage.ets`, `widget/pages/AlertCard.ets` + its tap target in `entryformability/`,
`LocalStore.getProfile` (defaults on read), one Settings row.

Notes: the responder view must be reachable from Emergency tab top, lock screen, alert widget, and the SOS page once
the countdown ends — **S4 owns `SosPage.ets`**, so give S4 nothing to do: S4 adds the button pushing
`Routes.RESPONDER`. Give Workstream A the route name `responder` in your notes. Payload versioning: old share links and
QR codes must still open; keep the unencrypted QR fallback under the size it has today (measure, put the number in a
test). Translations: English for new labels, fall back to English, never invent.

Phase 2: B14 NFC write of the card link (build, mark "built, unverified").

### S3 — onboarding (`georgi/b-onboarding`): B3; Phase 2: QA pass

Owns: `pages/OnboardingPage.ets` (rewrite, 8 steps per brief B3), new `components/onboarding/*` if you split it,
removing `askNotificationPermission` from `pages/Index.ets` `aboutToAppear` (and asking in step 7 instead).

Embeds `AuthForm` (S1) and `EmergencyDetailsForm` (S2) — both are stubs now; build against their contracts and the
flow works for real once their streams merge. Medicines step reuses `components/AddMedForm.ets` with `DrugChecker`.
Permissions step: notifications, microphone, location, each with one sentence of why, requested on tap. Steps keep
their state when going back; optional steps have Skip; progress shown. A returning user who signs in and whose
profile is restored skips the rest (S1's `ProfileSync` restores; you check `getProfile()` after `onDone(true)`).
Write the new screens' subsection into your notes (DESIGN.md is folded in by the coordinator).

Acceptance: fresh install → finished in under 2 minutes (time it on the emulator, screenshot each step).

Phase 2 (after S1, S2, S4, S5 are merged into integration): `git merge georgi/integration`, then a QA pass over every
B flow on the emulator (sign up/in/out offline, onboarding, emergency edit → card → share link → web viewer,
responder from all entry points, notifications actions, SOS states, visits, diary). File bugs as a list in your notes
with repro steps; fix only small bugs in files nobody else is changing, report the rest.

### S4 — notifications + SOS (`georgi/b-notify-sos`): B7, B8; Phase 2: B13 / B12 code

Owns: `common/Notify.ets`, `entryability/EntryAbility.ets` (notification taps and actions), `reminders/*`,
`emergency/SosController.ets`, `emergency/SosService.ets`, `emergency/SosMessage.ets`, `emergency/LiveStatus.ets`,
`pages/SosPage.ets`, `common/Routes.ets` `SosParam` (add a "sent by watch" state), the watch-SOS lines in
`pages/Index.ets` (`onAlert`, ~line 129 / 161).

B7: verify in Context7 the notification slot API and action buttons (`notificationManager` `actionButtons` with a
`wantAgent`; how a button reaches the app without opening it — e.g. a `CommonEvent` or `ServiceExtension`?). Build what
the kit allows on API 20; if a button cannot act without opening the app, make it open the right page and say so.
Slots per kind: emergency, heart alert, dose due, risky check. "Taken" on a dose records the dose
(`DrugIntake`/reminder state), "I'm OK" / "Open" on an alert.

B8: a watch SOS opens the SOS page already in "sent" state, no second 30 s countdown. The page says what was sent, to
whom, and what still needs a tap. Add the "For first responders" button (route `responder`) once the countdown ends.

Phase 2 (after S7's research docs land): implement what `docs/research/live-view.md` and `push-kit.md` say is possible
without approvals; list the rest as blocked.

### S5 — doctor visits + diary (`georgi/b-doctor`): B6, B15

Owns: `pages/DoctorPrepPage.ets`, `pages/VisitsPage.ets`, `pages/FeelingPage.ets`, `doctor/*`, new `diary/*`,
`backend/supabase/functions/doctor-summary/*` (+ its tests), `pages/SymptomLogPage.ets` only if needed for the diary.

Visits: store as JSON under one `LocalStore` setting key (`doctor_visits`), no schema change. Free-text answers go to
the model: strip names and contacts (reuse the Ledger `FORBIDDEN_FIELDS` idea, plus the profile's name and contact
names/phones as literal strings), extend the function's request validation, keep the banned-word / dose rejection.
`DoctorPrepParam` from the agent tile must keep working. Diary: an `AppEvent` kind (`model/AppEvent.ets`) next to
symptoms; a widget action (coordinate with S2 only if you need `AlertCard`; prefer `CheckCard` or a new route tap);
a pure `dailyCounts(days)` for Workstream A's Trends (put the signature in your notes so the coordinator hands it to
Kaloyan). Function changes need a deploy: list it under "Coordinator actions".

### S6 — watch (`georgi/b-watch`): B16

Owns: everything under `watch/` except the look of the screens (`watch/entry/src/main/ets/components/*`, theme) which
is Workstream A's. Split `controller/WatchController.ets` (sensors, rules, SOS, sync, pairing) without behaviour
change, energy (lower accelerometer rate at rest, outbox written once per sync, one reused HTTP client), background
monitoring research into `watch/README.md` (continuous task modes on wearables, Health Service Kit, what approval
it needs), and `watch/scripts/run.sh` like `app/scripts/run.sh`. The wearable emulator is `Huawei_Wearable`; it has
its own hdc target — take the same emulator lock only if you must also drive the phone. 43 watch tests must pass,
add tests for the split units.

### S7 — research (`georgi/b-research`): B12, B13, B17, B18, B11 notes

Docs only, no app code: `docs/research/push-kit.md`, `live-view.md` (including lock-screen medical-ID options:
Form Kit lock-screen cards, widgets), `phone-watch-link.md`, `account-kit.md`. Each with sources (official Huawei
docs via Context7 and the web), what works on the emulator, exact AGC steps, and a "needs: …" list. Write them so S4
can implement straight from them. B11: summarise what `backend/supabase/functions/sos/twilio.ts` already does and
what is missing; ask Georgi for the Cardbeat reference before proposing a conversational call design.

## 5. Merge order (coordinator)

1. Foundation (this file, stubs, scripts) → `georgi/integration` → `main` so Kaloyan sees the routes and contracts.
2. Whichever of S7 (docs), S6 (watch), S5, S4 finish first — low overlap.
3. S1 (accounts; apply its migration after Georgi's OK, Georgi turns off "Confirm email").
4. S2 (emergency), then S3 (onboarding, now live with the real forms).
5. Phase 2 streams in the same order. Merge `georgi/integration` → `main` after each green round.

## 6. Notes file format (`docs/workflow/b-<stream>.md`)

```markdown
# S<n> <stream>

## AI_WORKFLOW entry
### 2026-10-0X — Georgi + Claude Code: <title> (branch `georgi/b-<stream>`)
- Asked: …
- Produced: …
- Validated: … (tests, emulator, screenshots)
- Not validated: …

## README "How to verify" rows
| <feature> | <how to check> |

## DESIGN.md subsection (new screens only)
## ARCHITECTURE notes
## For Workstream A (routes, functions, contracts)
```
