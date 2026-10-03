# Celia.ai

Agent-first heart-safety companion for people with Long QT syndrome — HarmonyOS (API 20+), HackYeah 2026 Huawei task.

## Team docs
- [Product spec](docs/PRODUCT.md) — locked decisions, screens, feature catalogue, demo
- [Idea](docs/IDEA.md) — what we build and why, MVP scope, demo story
- [Architecture](docs/ARCHITECTURE.md) — big picture, ownership, shared contracts, API
- [Plan](docs/PLAN.md) — checkpoints, mentor questions, submission checklist
- [Tasks](docs/TASKS.md) — feature expansion (F-19..F-34) as implementable tasks
- Per person: [Kaloyan — agent](docs/team/kaloyan-agent.md) · [Georgi — app](docs/team/georgi-app.md) · [Mark — data & watch](docs/team/mark-data-watch.md)
- [Watch app](watch/README.md) — HarmonyOS wearable app (emulator), metrics → Supabase
- [SOS backend](backend/supabase/functions/sos/README.md) — watch SOS → SMS + call to emergency contacts (Twilio)
- Background: [task text](docs/hackathon/huawei-task.txt) · [condition research](docs/hackathon/conditions-research.md)

## Build & run

Native HarmonyOS app: ArkTS + ArkUI, Stage model, **minimum and target API 20** (`6.0.0(20)`).
Project lives in [`app/`](app) — open that folder in DevEco Studio 6.x.

```bash
source app/env.sh          # puts DevEco's hvigorw / ohpm / hdc on PATH (override DEVECO=... if installed elsewhere)
app/scripts/test.sh        # local unit tests (Hypium, no device needed); non-zero exit on failure
app/scripts/run.sh         # build → install → launch → screenshot on a running emulator/device (needs signing)
app/scripts/device.sh      # real phone: preflight (API level, signing, backend) → build → install → launch
```

On the first build `entry/hvigorfile.ts` creates `app/entry/src/main/ets/common/LocalConfig.ets` from
`LocalConfig.example.ets`. That file is gitignored — put the backend URL / Supabase anon key there. Without it the
app runs fully offline (deterministic drug check, emergency card).

### Signing

`hvigorw assembleHap` without signing produces only `entry-default-unsigned.hap`, which cannot be installed.

1. DevEco Studio → File → Project Structure → Signing Configs → sign in with a Huawei ID →
   **Automatically generate signature** (works for the emulator and for a real device).
2. DevEco writes local cert paths and encrypted passwords into `app/build-profile.json5`. **Never commit that hunk.**
   Right after enabling signing, run once **from the repo root** (the file must already be tracked — it is, once
   you've pulled `main`):
   ```bash
   git update-index --skip-worktree app/build-profile.json5
   ```
   (undo with `--no-skip-worktree` before you intentionally change that file). Certificates (`*.p12`, `*.cer`,
   `*.p7b`, `*.csr`) are gitignored and live outside the repo (`~/.ohos/config`).
3. Safety net — enable the repo's pre-commit hook once per clone; it refuses commits that contain signing
   material, certificates, `LocalConfig.ets` or `.env` files:
   ```bash
   git config core.hooksPath .githooks
   ```
4. `app/scripts/run.sh` now finds `entry-default-signed.hap` and installs it.

Real phone (HarmonyOS 6.0+): step-by-step setup, what to test and install errors are in
[docs/REAL_DEVICE.md](docs/REAL_DEVICE.md); `app/scripts/device.sh check` tells you what is still missing.

## How to verify each feature (emulator)

Everything below runs on the emulator with no backend and no watch. Heart data is **simulated** and labelled so.

| Feature | How to check |
|---|---|
| Onboarding (F-01, B3) | Fresh install (`hdc uninstall com.celiaai.app`, then `app/scripts/run.sh`): 8 steps with a progress bar and "Step N of 8". Continue stays inactive until the consent box is ticked. Type a contact name, go Back and forward again: the text is still there. Skip on steps 2 and 4-8. Permissions step: each Allow opens the system dialog only when tapped. Finish lands on Home; relaunch does not show onboarding again. |
| Drug check (F-05, F-07, F-20, F-21) | Medicines → type `Klacid`, `Zofran 8 mg`, `Сумамед`, `ondansetrom` (typo) or `xyz` → verdict card; "How we know" shows each step. |
| Interactions (F-19) | Add `Cipralex` to my medicines, then check `ondansetron` (adds up) or `clarithromycin` (CYP3A4). |
| Barcode (F-36) | Medicines → Scan (camera or album). Any Polish box resolves from the bundled register (≈68k packs), e.g. type `5909990331710` (Klacid) or `5909990296026` (Apap) → verdict + "About this medicine" (substance, strength, form, pack, Rx/OTC, ATC group, holder, leaflet). Unknown boxes (e.g. Bulgarian) open "teach this barcode"; the next scan resolves instantly. Demo codes `2000000000015`… still work. Regenerate the register with `python3 data/export_gtins.py`. |
| History, dashboard (F-23, F-24) | Home shows meds by risk, interactions and recent checks; Medicines → Check history (filters). |
| v2 layout, silk orb, Lucide icons | Cold start lands on **Today** (agent line, next dose, resting 7 days, four tiles). Tab bar: Today · Medicines · orb · Health · Emergency. Orb → agent stage: the orb sits at the bottom centre, tap it to talk, tap again to mute, `End` on the left; captions grow above it, "Show conversation" opens the thread. Health: Today / 14 days / 30 days switch. Medicines: Today's doses row. Emergency: Start SOS + Call first. Spec: `docs/design/DESIGN.md` §6.5, §6.6, §6.6b, §10.1a. |
| Heart + alerts (F-09, F-32) | Health → Demo controls → `lqt2 startle tachy`, `lqt3 night brady`, `lqt1 exercise`, `irregular rhythm`, `watch disconnect`. |
| Health metrics | Health → a card per watch metric (resting heart rate, HRV, oxygen, breathing, sleep, steps, stress time) with a mini chart and a fixed-rule status (Good / Okay / Worth a look). Tap a card, or the live heart-rate card, for its page: chart with the usual-range band (drag across it to read a day), `14 days · 30 days` (heart rate adds `Now`), "What this means", average / lowest / highest. HRV, oxygen and breathing are simulated by the watch and always labelled. No ECG, no QT. Seen on the emulator with demo data; not with real watch rows (the `watch_vitals_daily` view is not deployed yet). |
| SOS (F-27, F-28, F-35) | A CRITICAL alert (e.g. `lqt2 startle tachy`) opens the 30 s "Are you OK?" countdown → "I'm OK" or let it run → call / share message / call contacts. Settings → Test SOS runs a 10 s test marked TEST. 10-min cooldown for automatic SOS. |
| Emergency card (F-08, F-26, F-29, F-30) | Emergency tab → Show card as QR code. With a backend, the card is encrypted on the phone and uploaded to the `share` function; the QR is a short link (`/card/#<id>.<key>`) that any phone camera opens as the formatted card in the reader's language (13 languages), with 112 first. "Remove this link" revokes it. Offline/no backend: the QR carries the whole card (legacy link). Celia's own scanner opens both kinds inside the app. |
| Help guide (F-41) | Emergency → Help guide: 3 steps + CPR metronome 110/min (haptic). Also reachable from the lock screen. |
| Pharmacy card, travel (F-40, T23) | Emergency → Pharmacy card: in the language of the country you're in, with English below. With location allowed, being in another country than Settings shows "You're in …" on Home (country found on the phone; nothing uploaded). |
| Doctor visits (F-31) | Today → Doctor visit → **New visit**: pick the kind of doctor, write why you are going (or tap a starter); a card shows what the visit looks like (fixed keyword rules on the phone, no AI) → **Create visit page**. The page is what you hand to the doctor: who you are and why you came, **Please don't prescribe** (known-risk medicines for this kind of visit, from the QT list; possible/conditional fold open; what is not on the lists), a labelled AI summary, then the full brief folded. **Share** in the header sends an encrypted web report with the same card at the top (48 h link, printable); copy link / copy text / share as text below. Every visit stays in the gallery (latest on top, long press to delete). New-visit form and visit page seen on the emulator; gallery cards, share and the web block not yet. |
| Reminders (F-38) | Medicines → Medicine reminders. See ARCHITECTURE: system reminders need an AGC quota; the in-app fallback notifies while the app runs. |
| Symptom log (F-44, T27) | Today → Log how I feel (or Health → Log how I feel); fainting / chest pain shows an SOS button. Or tell the agent "I felt dizzy after the alarm" (backend): it calls `log_symptom`; red flags start the SOS countdown by rule, not by the model. Appears in the doctor brief. |
| Card language, read aloud (T11, T25) | Emergency → pick one of 13 card languages (saved) → **Read the card aloud**: only the medical part, never name or contacts (on-device English voice, cloud `/speak` otherwise; hidden with neither). |
| Nearby help (T26 fallback) | Emergency → Nearby help → Hospital / Pharmacy / Defibrillator: a map search around the phone (map app or browser; the app sends no location). The in-app map needs a Map Kit key. |
| Agent stage, saved chats (F-02, T7) | Tap the orb in the tab bar → "Aa" → ask "Can I take Klacid?" (works offline with the deterministic agent). Header: Chats and + (new chat). Chats → long press → Rename / Delete. "new chat" / "start over" work offline. |
| Agent reaches the screens (page tools) | Ask or say "Show me the symptoms I logged recently", "Open my medicine reminders", "How has my heart rate been?", "I'm seeing the dentist tomorrow" → a tool step, a sentence built from the phone's own data, and a tile that opens Symptom log, Reminders, Trends or Doctor prep. Symptom-log tile seen opening the page on the emulator; the reminders, trends and doctor-prep tiles were seen, not all tapped. The deployed backend needs the `agent` and `realtime-session` functions redeployed (prompt `2026-10-03.6`, 18 tools); until then only the local dev backend offers the new tools. |
| Agent logs a dose, with confirmation | Set a reminder for a time that has passed today, say "I just took my nadolol" → a card "Mark this dose as taken?" → Confirm → the reminder shows Taken. Nothing is written before the tap. **Unit tests only (6); the card has not been seen on screen.** |
| Follow-up chips after a verdict | Ask "Can I take ondansetron?" → chips under the verdict card, chosen by the risk level, not by the model. Seen on the emulator; not tapped. |
| Photo of a box from the agent | Agent → camera button: opens the system camera; when no camera can be opened it opens the gallery. On the emulator the gallery fallback was seen. **Camera capture is unverified (needs a real phone).** |
| Demo voice without a microphone | `DEMO_VOICE_INPUT = 'on'`: each new voice session plays the next bundled clip (ondansetron, dentist, doses, trends, symptoms, reminders, took a dose, dizzy, then a barge-in pair) with the `SIMULATED VOICE INPUT` badge. All nine run on the emulator; the audio output was not listened to. |
| One header, quick links | Medicines, Heart, History, Reminders, Symptom log, Trends, Chats, Check result and Scan have the same header (back on pushed pages, title, settings gear). Heart: chips under the ring for Log a symptom, Trends, Doctor prep. Medicines: chips under the search for Reminders, History. Seen on the emulator. |
| Trends from the cloud project | With `SHARE_ANON_KEY` set in `LocalConfig.ets`, Health (14 / 30 days) and the Trends page read `watch_daily_summary` and `watch_insights` of the paired watch even while the AI backend is a local dev server; `SIMULATED` shows when a row is marked simulated, `WATCH` for real rows. Seen with the project's simulated rows, 14 and 30 days, and offline with "Try again". **Unverified with real watch rows: the demo watch has none.** |
| Screen-reader text | Verdicts are read by their word ("Known risk"), cards as one sentence, selected chips as selected. **In the code; not checked with the screen reader on.** |
| Reduced motion | API 23+: follows the system "reduce animations" setting; API 20-22 have no such setting, so an animation scale of 0 is used instead. **Read path runs without errors; never seen switched on.** |
| Medicine sheet, AI explanation | Medicines → tap a medicine: risk band, what it's for, interactions, brands. "Explain it in plain words" (backend only; hidden offline) shows an `AI SUMMARY`; replies that mention QT/arrhythmia/doses are dropped. |
| Doctor summary (T13) | Opening a visit page fetches it once (backend only) and keeps it with the visit: 2–3 sentences from the brief's medicines, risk words, interactions, counts, and the visit plan's purpose titles and known-risk names — never name, notes, symptom notes or the reason you typed. Reassurance or doses → dropped; a retry button appears when it fails. |
| Celia intents (F-11, T20) | `CheckDrugSafety`, `ShowEmergencyCard`, `LogSymptom`, `TakeDose`, `ShowPharmacyCard`, `AddMedication`, `ReadEmergencyCard` (`insight_intent.json`). Built and compiled; routing from Celia needs a real device with Celia/Xiaoyi. |
| Widgets (F-12) | Home screen → add Celia "Check a medicine" (2×2) and "Medical alert" (2×4); Help this person opens the bystander guide. |
| Watch context (T15) | With the cloud backend, a risky check writes `watch_context` (genotype, ingredient, risk) and the Celia watch shows the verdict glance within 60 s. |
| Privacy, app lock (F-45, F-46) | Settings → What left my phone: every outbound request — drug check, agent, voice, vision, explanations, share links, live voice — with field names and size, never values; **Export the list**. App lock needs a screen lock (PIN) on the device. |
| Watch build + install | `watch/scripts/run.sh` with the `Huawei_Wearable` emulator running → screenshot in `watch/build/screenshot.jpeg` |
| Watch internals split | `cd watch && source env.sh && hvigorw test -p module=entry -p coverage=false --no-daemon` → 88/88 (with the watch-secret patch) |
| Accelerometer slows at rest | run the watch app, keep the emulator still 30 s, `hdc -t <watch> hilog \| grep CeliaWatch` → `accelerometer every 100 ms` |
| Shared HTTP session | with `watch/.env` filled, tap *Fine* on the check-in page → row in `watch_metrics` for the device id |
| Doctor visits (B6) | Heart → Doctor visit prep → My visits → Add a visit → pick Dentist, a date, a reason and a worry → Save. The brief opens with "This visit" and "What worries me". Back → the visit is listed under UPCOMING; tap it to reopen, bin icon → Delete. AI summary works with the deployed function; using reason/worries in it needs this branch's function deployed. |
| Redaction before the AI summary | Unit tests `Redact` / `summarySendsRedactedAnswersOnly`: names of the patient, contacts, cardiologist, hospital, phone numbers, e-mails and links become `[removed]`; Privacy ledger shows `reason`, `worries` field names only. |
| Feeling diary (B15) | Route `feeling` (agent home tile from Workstream A, or the "How are you feeling?" widget): pick a mood, optional note, Save → listed under RECENT. Low / Unwell offers "Log a symptom". |
| Notifications per kind (B7) | Settings → notifications for Celia.ai: emergency is a separate loud category. Start an SOS countdown and pull down the panel: "SOS in N s" notification. Real phone: tap it to show I'm OK / Open (built, unverified on screen: emulator does not draw buttons). |
| Dose "Taken" from the notification (B7) | Add a reminder; when it is due the notification has Taken / Open. Taken opens Celia on Reminders with the dose TAKEN. Emulator check: `hdc shell aa start -a EntryAbility -b com.celiaai.app --ps notifyAction DOSE_TAKEN --ps notifyKind DOSE_DUE --pi notifyId <2000+id%1000> --pi reminderId <id>` |
| Watch SOS without a second countdown (B8) | Press SOS on the paired watch. The phone opens "Your watch sent an SOS" directly (no countdown): what was sent, to whom, what still needs a tap, plus For first responders. |
| SOS page honesty (B8) | Let a phone SOS countdown run out: "Nothing has been sent yet … Nobody yet", then the call / share / contact / responder buttons. |
| SOS Live View (B13) | Start an SOS countdown, pull down the panel / lock the screen: a live card "SOS in 00:25" ticking, red capsule. "I'm OK" → card "SOS cancelled". Works on the emulator; on a real phone needs Live View approval (built, unverified there). |
| Lock-screen medical ID (B13) | Long-press the app icon → Widgets → "Medical ID (lock screen)". Shows condition, AVOID line, ICD, medicines; hidden card fields stay off; no contacts. Lock-screen placement: real phone only (built, unverified). |
| Push: watch SOS to the phone (B12) | Built, unverified: needs an AGC project with Push Kit, the service-account key in Supabase secrets, B9's watch↔account binding and a Chinese-mainland phone. Emulator check of the tap: `hdc shell aa start -a EntryAbility -b com.celiaai.app --ps route sos --ps source watch --ps loc 1` → "Your watch sent an SOS". `hilog | grep PushToken` shows why no token. |
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
| Emergency details (B4) | Settings → Emergency details → fill blood type, allergies, cardiologist; Emergency tab → full card shows them in a fixed order; switch "Show on card" off → the field disappears from the card and the QR |
| Old profiles load | `app/scripts/test.sh` → `StoredProfile.oldStoredProfileLoadsWithDefaults` |
| Card payload v2 | Emergency tab → QR → open link: details shown; an old v1 link still opens (test `CardPayloadV2.oldV1LinksStillOpen`) |
| First-responder view (B5) | Emergency tab → "For first responders": do not give, use instead, care notes, medicines, details, call buttons; works in airplane mode |
| Responder from lock screen | Privacy → App lock on → background 5 min → lock screen → "For first responders" (built, unverified on the emulator) |
| NFC card tag (B14) | Real phone with NFC: Emergency → Show card as QR → Write to NFC tag → hold an NTAG213+ sticker → tap the tag with another phone (built, unverified) |
| Responder from widget | Add the 2×4 Medical alert card → tap its text (built, unverified) |
| No notification prompt on launch | Relaunch the app after onboarding: no notification dialog appears (it is asked only in onboarding step 7). |

Unit tests: `app/scripts/test.sh` — **386 tests, 0 failures** (4 Oct 2026): drug data + checker, interactions, health metric rules and chart maths,
agent safety gate + validator + tool registry, offline agent, saved chats, alarm rules, SOS state machine and message,
doctor brief + AI summary guard, report payload + share links, medicine info + AI reply guard, symptom tool, GS1,
emergency numbers, card text + read-aloud privacy, dose schedule, travel, privacy guard + ledger, accounts + profile
sync, onboarding, emergency details + responder + card payload v2 + NFC, notification kinds + watch SOS + Live View
text + medical ID card, doctor visits + redaction + feeling diary. Tests never call the network
(`Config.forceOffline`).
Watch: `cd watch && source env.sh && hvigorw test -p module=entry -p coverage=false --no-daemon` — **88 tests, 0
failures**.
Backend: `npx -y deno test --no-lock backend/supabase/functions/` — **75 tests, 0 failures** (labels, RxNav/openFDA
tier 2, share, SOS message + Huawei Push sender, box identify, med-info and doctor-summary output guards).
Accounts RLS: `backend/supabase/tests/run-rls.sh` (throw-away local Postgres) → ALL ACCOUNTS RLS CHECKS PASSED.

Optional online drug check: create a Supabase project, run `backend/supabase/migrations/0001_drugs.sql` and
`backend/supabase/seed.sql` (regenerate with `python3 data/export_seed.py`), deploy `functions/drug-check`, and put
the URL + anon key in `app/entry/src/main/ets/common/LocalConfig.ets`. Without it the app is fully offline.

## AI usage

How AI tools were used, and which pre-existing components are reused: [`AI_WORKFLOW.md`](AI_WORKFLOW.md).

**Pre-existing / third-party components (Challenge Rules §4):** DevEco Studio's Empty Ability template
(hvigor files, `EntryAbility` skeleton, Hypium test harness) and the `@ohos/hypium` / `@ohos/hamock` test libraries.
Icons: Lucide (lucide.dev, ISC licence, `lucide-static` 1.51.0), strokes outlined to fills so ArkUI can tint them
(`app/entry/src/main/resources/base/media/ic_*.svg`; the risk shapes `ic_risk_*` are our own).
`npm:jose@5` signs the Huawei Push Kit service-account JWT in the `sos` Edge Function; Twilio (SOS SMS and calls)
and Huawei Push Kit are external services called from that function.
Hosting: Supabase (Edge Functions, Storage) and Vercel (static viewer pages in `site/`; they hold no data).
Public APIs called by the `/drug-check` and `/box-identify` Edge Functions for medicines outside our data: NLM RxNav
(name → ingredient, rxnav.nlm.nih.gov), openFDA drug labels (api.fda.gov, public domain), AEMPS CIMA (Spanish
medicines register, cima.aemps.es), UPCitemdb (free trial API) and Open Food / Products / Beauty Facts (ODbL). Only a
medicine name or a barcode is sent to those APIs; no personal data.
Nearby help opens Google Maps search URLs (developers.google.com/maps/documentation/urls, no key, no location sent
by the app).
The three demo voice clips in `app/entry/src/main/resources/rawfile/voice/` were made with the macOS system voice
(`say`); they stand in for the microphone on the emulator when `DEMO_VOICE_INPUT` is `'on'` in `LocalConfig.ets`, and
the agent screen then shows a `SIMULATED VOICE INPUT` badge.
App code, data and prompts are written in this repo.

### What leaves the phone

The safety core (drug verdicts, emergency card, profile, medicines, reminders) works with no network, signed in or
not. Everything below is optional and the phone lists each request in Settings → Privacy → "What left my phone".

| Goes to | What | When |
|---|---|---|
| Supabase Auth (our project) | Your email and password (the password is checked by Supabase Auth and stored there only as a hash) | You create an account or log in; token refreshes about once an hour while signed in |
| Supabase `profiles` table (our project) | Your whole profile and medicine list as one document: name, genotype, ICD, emergency contacts with phone numbers and emails, card notes, emergency details, medicines and doses | You are signed in: at sign-in, at launch, and a few seconds after you change your profile or medicines |
| Supabase (our project) | Watch readings keyed by a device id: heart rate, alerts, symptoms, doses taken, falls, wear state, simulated vitals, `sos` row with location if allowed | A linked watch app is running |
| Supabase (our project) | `watch_context`: genotype, last risky medicine and time | You tap "I took it" on a risky medicine, or change genotype while paired |
| OpenAI, via our Edge Functions | Condition, genotype, medicine ingredients, one-line heart summary, last 12 chat messages; for the optional summaries, a medicine name or the doctor brief's medicine lines | You talk or type to the agent online, or tap "Explain it in plain words" / "Summarise for the doctor" |
| OpenAI, via our Edge Functions or a direct WebSocket | Voice audio; a downscaled box photo | Live voice, cloud tap-to-talk, or a photo scan the on-device reader could not handle |
| Supabase Storage | Card or doctor report, encrypted on the phone; the key stays in the link | You create a share link or card QR |
| Supabase, SOS tables (our project) | Your emergency contacts' names and international phone numbers (at most 5) and your first name, for your paired watch; readable by nobody through the API, only by our `sos` function | Only after you switch on Settings → Account → "Let my watch alert my contacts" (off by default); switching it off deletes them |
| Never uploaded in the clear | Without an account: name, phone numbers, contacts, notes | — |

**With an account:** the `profiles` row is readable and writable only by your own login (row-level security
`auth.uid() = user_id`; nothing for the public key). It is stored in our Supabase project. Delete it any time in
Settings → Account → "Delete my data from my account" (this also signs you out; the phone keeps its copy). Signing
out keeps the data on the phone unless you choose "Sign out and delete". The ledger marks these requests with their
named exception (`ACCOUNT_AUTH`, `PROFILE_SYNC`, `SOS_CONTACTS`); no other request may carry personal fields.
When a watch SOS fires, the `sos` function texts and calls those contacts; without Twilio credentials on the server
it records a test run instead (`dry_run`) and the Account page says that nobody was contacted.

Known limits of this build: watch rows are guarded by a shared anon key plus the device id rather than per-user
auth; the watch app has no ledger of its own.

**Data sources:** drug risk categories follow the public CredibleMeds QTdrugs lists (crediblemeds.org); brand names
from the Polish (URPL) and Bulgarian (BDA) medicine registers; emergency numbers from the EU 112 pages and national
regulators; CPR guidance from ERC / AHA public guidelines; genotype triggers from Schwartz et al. (Circulation 2001)
and the HRS/EHRA/APHRS 2013 consensus. Box barcodes, product names, strengths, forms, availability categories and
leaflet links come from the public Polish medicines register export (Rejestr Produktów Leczniczych, URPL —
rejestrymedyczne.ezdrowie.gov.pl, snapshot date stored in `gtin_pl.json`); ATC group names from the WHO ATC index
(whocc.no); GS1 country prefixes from the public GS1 prefix list. The bundled list is a curated demo subset — not a medical device.
