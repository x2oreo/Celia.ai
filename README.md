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
| Onboarding (F-01) | Fresh install → 4 steps (genotype + ICD → medicines → contacts → country). Restart: data is still there (encrypted RDB). |
| Drug check (F-05, F-07, F-20, F-21) | Medicines → type `Klacid`, `Zofran 8 mg`, `Сумамед`, `ondansetrom` (typo) or `xyz` → verdict card; "How we know" shows each step. |
| Interactions (F-19) | Add `Cipralex` to my medicines, then check `ondansetron` (adds up) or `clarithromycin` (CYP3A4). |
| Barcode (F-36) | Medicines → Scan (camera or album). Any Polish box resolves from the bundled register (≈68k packs), e.g. type `5909990331710` (Klacid) or `5909990296026` (Apap) → verdict + "About this medicine" (substance, strength, form, pack, Rx/OTC, ATC group, holder, leaflet). Unknown boxes (e.g. Bulgarian) open "teach this barcode"; the next scan resolves instantly. Demo codes `2000000000015`… still work. Regenerate the register with `python3 data/export_gtins.py`. |
| History, dashboard (F-23, F-24) | Home shows meds by risk, interactions and recent checks; Medicines → Check history (filters). |
| Heart + alerts (F-09, F-32) | Heart → Simulation controls → `lqt2 startle tachy`, `lqt3 night brady`, `lqt1 exercise`, `irregular rhythm`, `watch disconnect`. |
| SOS (F-27, F-28, F-35) | A CRITICAL alert (e.g. `lqt2 startle tachy`) opens the 30 s "Are you OK?" countdown → "I'm OK" or let it run → call / share message / call contacts. Settings → Test SOS runs a 10 s test marked TEST. 10-min cooldown for automatic SOS. |
| Emergency card (F-08, F-26, F-29, F-30) | Emergency tab → Show card as QR code. With a backend, the card is encrypted on the phone and uploaded to the `share` function; the QR is a short link (`/card/#<id>.<key>`) that any phone camera opens as the formatted card in the reader's language (13 languages), with 112 first. "Remove this link" revokes it. Offline/no backend: the QR carries the whole card (legacy link). Celia's own scanner opens both kinds inside the app. |
| Help guide (F-41) | Emergency → Help guide: 3 steps + CPR metronome 110/min (haptic). Also reachable from the lock screen. |
| Pharmacy card, travel (F-40, T23) | Emergency → Pharmacy card: in the language of the country you're in, with English below. With location allowed, being in another country than Settings shows "You're in …" on Home (country found on the phone; nothing uploaded). |
| Doctor prep (F-31) | Home → Doctor visit prep → pick the specialist → **Send report link**: an encrypted web report (meds with risk badges, interactions, flagged checks, 30-day resting HR chart, alerts/SOS/symptoms timeline, doses, watch-outs, questions) that opens on any phone or computer and can be printed to PDF; the link stops working after 48 h. Share/copy as text still works. No AI: built from your own data. |
| Reminders (F-38) | Medicines → Medicine reminders. See ARCHITECTURE: system reminders need an AGC quota; the in-app fallback notifies while the app runs. |
| Symptom log (F-44, T27) | Home → More → Symptom log; fainting / chest pain shows an SOS button. Or tell the agent "I felt dizzy after the alarm" (backend): it calls `log_symptom`; red flags start the SOS countdown by rule, not by the model. Appears in the doctor brief. |
| Card language, read aloud (T11, T25) | Emergency → pick one of 13 card languages (saved) → **Read the card aloud**: only the medical part, never name or contacts (on-device English voice, cloud `/speak` otherwise; hidden with neither). |
| Nearby help (T26 fallback) | Emergency → Nearby help → Hospital / Pharmacy / Defibrillator: a map search around the phone (map app or browser; the app sends no location). The in-app map needs a Map Kit key. |
| Agent chat, saved chats (F-02, T7) | Agent → ask "Can I take Klacid?" (works offline with the deterministic agent). Header: Chats (history) and New chat. Chats → long press → Rename / Delete. "new chat" / "start over" work offline. |
| Agent reaches the screens (page tools) | Ask or say "Show me the symptoms I logged recently", "Open my medicine reminders", "How has my heart rate been?", "I'm seeing the dentist tomorrow" → a tool step, a sentence built from the phone's own data, and a tile that opens Symptom log, Reminders, Trends or Doctor prep. Symptom-log tile seen opening the page on the emulator; the reminders, trends and doctor-prep tiles were seen, not all tapped. The deployed backend needs the `agent` and `realtime-session` functions redeployed (prompt `2026-10-03.6`, 18 tools); until then only the local dev backend offers the new tools. |
| Agent logs a dose, with confirmation | Set a reminder for a time that has passed today, say "I just took my nadolol" → a card "Mark this dose as taken?" → Confirm → the reminder shows Taken. Nothing is written before the tap. **Unit tests only (6); the card has not been seen on screen.** |
| Follow-up chips after a verdict | Ask "Can I take ondansetron?" → chips under the verdict card, chosen by the risk level, not by the model. Seen on the emulator; not tapped. |
| Photo of a box from the agent | Agent → camera button: opens the system camera; when no camera can be opened it opens the gallery. On the emulator the gallery fallback was seen. **Camera capture is unverified (needs a real phone).** |
| Demo voice without a microphone | `DEMO_VOICE_INPUT = 'on'`: each new voice session plays the next bundled clip (ondansetron, dentist, doses, trends, symptoms, reminders, took a dose, dizzy, then a barge-in pair) with the `SIMULATED VOICE INPUT` badge. All nine run on the emulator; the audio output was not listened to. |
| One header, quick links | Medicines, Heart, History, Reminders, Symptom log, Trends, Chats, Check result and Scan have the same header (back on pushed pages, title, settings gear). Heart: chips under the ring for Log a symptom, Trends, Doctor prep. Medicines: chips under the search for Reminders, History. Seen on the emulator. |
| Trends from the cloud project | With `SHARE_ANON_KEY` set in `LocalConfig.ets`, Heart → Trends reads `watch_daily_summary` and `watch_insights` of the paired watch even while the AI backend is a local dev server; `SIMULATED` shows when a row is marked simulated, `WATCH` for real rows. Seen with the project's simulated rows, 14 and 30 days, and offline with "Try again". **Unverified with real watch rows: the demo watch has none.** |
| Screen-reader text | Verdicts are read by their word ("Known risk"), cards as one sentence, selected chips as selected. **In the code; not checked with the screen reader on.** |
| Reduced motion | API 23+: follows the system "reduce animations" setting; API 20-22 have no such setting, so an animation scale of 0 is used instead. **Read path runs without errors; never seen switched on.** |
| Medicine sheet, AI explanation | Medicines → tap a medicine: risk band, what it's for, interactions, brands. "Explain it in plain words" (backend only; hidden offline) shows an `AI SUMMARY`; replies that mention QT/arrhythmia/doses are dropped. |
| Doctor summary (T13) | Doctor visit prep → **Summarise for the doctor** (backend only): 2–3 sentences from the brief's medicines, risk words, interactions and counts — never name, notes or symptom notes. Reassurance or doses → dropped. |
| Celia intents (F-11, T20) | `CheckDrugSafety`, `ShowEmergencyCard`, `LogSymptom`, `TakeDose`, `ShowPharmacyCard`, `AddMedication`, `ReadEmergencyCard` (`insight_intent.json`). Built and compiled; routing from Celia needs a real device with Celia/Xiaoyi. |
| Widgets (F-12) | Home screen → add Celia "Check a medicine" (2×2) and "Medical alert" (2×4); Help this person opens the bystander guide. |
| Watch context (T15) | With the cloud backend, a risky check writes `watch_context` (genotype, ingredient, risk) and the Celia watch shows the verdict glance within 60 s. |
| Privacy, app lock (F-45, F-46) | Settings → What left my phone: every outbound request — drug check, agent, voice, vision, explanations, share links, live voice — with field names and size, never values; **Export the list**. App lock needs a screen lock (PIN) on the device. |

Unit tests: `app/scripts/test.sh` — **236 tests, 0 failures** (4 Oct 2026): drug data + checker, interactions,
agent safety gate + validator + tool registry, offline agent, saved chats, alarm rules, SOS state machine and message,
doctor brief + AI summary guard, report payload + share links, medicine info + AI reply guard, symptom tool, GS1,
emergency numbers, card text + read-aloud privacy, dose schedule, travel, privacy guard + ledger. Tests never call the
network (`Config.forceOffline`).
Backend: `npx -y deno test --no-lock backend/supabase/functions/` — **68 tests, 0 failures** (labels, RxNav/openFDA
tier 2, share, SOS message, box identify, med-info and doctor-summary output guards).

Optional online drug check: create a Supabase project, run `backend/supabase/migrations/0001_drugs.sql` and
`backend/supabase/seed.sql` (regenerate with `python3 data/export_seed.py`), deploy `functions/drug-check`, and put
the URL + anon key in `app/entry/src/main/ets/common/LocalConfig.ets`. Without it the app is fully offline.

## AI usage

How AI tools were used, and which pre-existing components are reused: [`AI_WORKFLOW.md`](AI_WORKFLOW.md).

**Pre-existing / third-party components (Challenge Rules §4):** DevEco Studio's Empty Ability template
(hvigor files, `EntryAbility` skeleton, Hypium test harness) and the `@ohos/hypium` / `@ohos/hamock` test libraries.
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

The safety core (drug verdicts, emergency card, profile, medicines, reminders) works with no network. Everything
below is optional and the phone lists each request in Settings → Privacy → "What left my phone".

| Goes to | What | When |
|---|---|---|
| Supabase (our project) | Watch readings keyed by a device id: heart rate, alerts, symptoms, doses taken, falls, wear state, simulated vitals, `sos` row with location if allowed | A linked watch app is running |
| Supabase (our project) | `watch_context`: genotype, last risky medicine and time | You tap "I took it" on a risky medicine, or change genotype while paired |
| OpenAI, via our Edge Functions | Condition, genotype, medicine ingredients, one-line heart summary, last 12 chat messages; for the optional summaries, a medicine name or the doctor brief's medicine lines | You talk or type to the agent online, or tap "Explain it in plain words" / "Summarise for the doctor" |
| OpenAI, via our Edge Functions or a direct WebSocket | Voice audio; a downscaled box photo | Live voice, cloud tap-to-talk, or a photo scan the on-device reader could not handle |
| Supabase Storage | Card or doctor report, encrypted on the phone; the key stays in the link | You create a share link or card QR |
| Never uploaded in the clear | Name, phone numbers, contacts, notes | — |

Known limits of this build: watch rows are guarded by a shared anon key plus the device id rather than per-user
auth; the watch app has no ledger of its own.

**Data sources:** drug risk categories follow the public CredibleMeds QTdrugs lists (crediblemeds.org); brand names
from the Polish (URPL) and Bulgarian (BDA) medicine registers; emergency numbers from the EU 112 pages and national
regulators; CPR guidance from ERC / AHA public guidelines; genotype triggers from Schwartz et al. (Circulation 2001)
and the HRS/EHRA/APHRS 2013 consensus. Box barcodes, product names, strengths, forms, availability categories and
leaflet links come from the public Polish medicines register export (Rejestr Produktów Leczniczych, URPL —
rejestrymedyczne.ezdrowie.gov.pl, snapshot date stored in `gtin_pl.json`); ATC group names from the WHO ATC index
(whocc.no); GS1 country prefixes from the public GS1 prefix list. The bundled list is a curated demo subset — not a medical device.
