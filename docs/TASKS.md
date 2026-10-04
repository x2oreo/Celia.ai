# Tasks - feature expansion (F-19..F-47)

> **Planning document from the hackathon; status as of 4 Oct 2026.** These are the tasks we wrote on 3 Oct for
> features **F-19..F-47** in [PRODUCT.md](PRODUCT.md). The status table below is checked against the code in
> `app/entry/src/main/ets/`; the task bodies further down are the original plan and were not rewritten, so their
> file names and acceptance checkboxes can differ from what was built (use the "Built in" column). How to verify
> each feature: [README](../README.md#how-to-verify-each-feature-emulator).

## Status summary

| Status | Tasks |
|---|---|
| Done | T1-T9, T11, T12, T14, T16, T17, T19, T22-T25, T27-T30 |
| Done with a limit | T10 (watch SOS texts in test mode until Twilio is set), T13 (parts not yet seen on screen), T15 (cloud path, not Wear Engine), T20 (Celia routing unverified), T21 (in-app fallback), T26 (map search fallback) |
| Partly done | T18 Live View (SOS countdown only) |
| Not built | F-16 A2A agent, F-17 caregiver tablet, F-18 Brugada / CPVT pack (core features, no task here) |

Unit tests and their current counts: README.

| Task | Feature | Status | Built in (`app/entry/src/main/ets/` unless noted) |
|---|---|---|---|
| T1 | F-19 Combo check vs my meds | Done | `safety/ComboRules.ets`, `drugs/DrugChecker.ets` |
| T2 | F-20 Safer alternatives | Done | `drugs/DrugDataset.ets`, `components/VerdictCard.ets` |
| T3 | F-21 Lookup trace + confidence | Done | `drugs/DrugChecker.ets`, `components/VerdictCard.ets` ("How we know") |
| T4 | F-22 BG + PL brand names | Done | `drugs/DrugDataset.ets` |
| T5 | F-23 Check history | Done | `pages/HistoryPage.ets`, `data/LocalStore.ets` |
| T6 | F-24 Dashboard | Done as the Today tab | `pages/HomePage.ets` |
| T7 | F-25 Saved chats | Done | `pages/ChatsPage.ets`, `agent/AgentCore.ets` |
| T8 | F-26 Country emergency numbers | Done | `safety/EmergencyNumbers.ets`, `common/EmergencyNumbers.ets` |
| T9 | F-27 SOS escalation | Done (30 s countdown, not 60 s) | `emergency/SosController.ets`, `pages/SosPage.ets` |
| T10 | F-28 SOS fan-out, location, cooldown, test SOS | Done with a limit: calls and share sheet from the phone; watch SOS texts / calls via `backend/supabase/functions/sos` (test mode until Twilio secrets are set) | `emergency/SosService.ets`, `emergency/SosMessage.ets` |
| T11 | F-29 Card in 13 languages | Done (AI-written strings, native review pending) | `common/CardStrings.ets`, `site/card/` |
| T12 | F-30 QR + share link | Done (encrypted, revocable) | `share/ShareService.ets`, `emergency/CardLink.ets` |
| T13 | F-31 Doctor prep by specialty | Done as doctor visits; gallery, share and web block not yet seen on screen | `doctor/*`, `pages/DoctorVisit*.ets`, `pages/NewVisitPage.ets` |
| T14 | F-32 Rich vitals | Done (HRV, oxygen, breathing simulated and labelled) | `vitals/Metrics.ets`, `vitals/AlarmRules.ets`, `pages/MetricPage.ets` |
| T15 | F-33 Watch notice on risky check | Done via cloud (`watch_context` → watch glance); Wear Engine not wired | `vitals/WatchContextSync.ets`, `vitals/WearNotifier.ets` |
| T16 | F-34 Settings | Done | `pages/SettingsPage.ets` and sub-pages |
| T17 | Brand palette | Done (v2 design) | `resources/base/element/color.json` and `resources/dark/element/color.json`, [design/DESIGN.md](design/DESIGN.md) |
| T18 | F-35 Live View | Partly: SOS countdown card; HR / verdict updates need a scenario approval | `emergency/LiveStatus.ets` |
| T19 | F-36 Box barcode scan | Done (Polish register, teach a barcode) | `drugs/BarcodeService.ets`, `drugs/Gs1.ets`, `drugs/GtinCatalog.ets`, `rawfile/gtin_pl.json` |
| T20 | F-37 More Celia intents | Built, unverified (5 more, 7 total) | `insightintents/*.ets`, `resources/base/profile/insight_intent.json` |
| T21 | F-38 Medication reminders | Done; system reminders need an AGC quota, in-app fallback | `reminders/*`, `pages/RemindersPage.ets` |
| T22 | F-39 Genotype trigger coach | Done (tip on Today) | `coach/Coach.ets` |
| T23 | F-40 Travel and pharmacy mode | Done (travel banner, localised pharmacy card) | `emergency/TravelService.ets`, `pages/PharmacyCardPage.ets` |
| T24 | F-41 Bystander mode | Done | `pages/BystanderPage.ets`, `bystander/Metronome.ets` |
| T25 | F-42 Read card aloud | Done (medical part only) | `emergency/CardSpeech.ets`, `voice/VoiceOutput.ets` |
| T26 | F-43 Nearby help | Fallback: map search; Map Kit needs a key | `emergency/NearbyHelp.ets` |
| T27 | F-44 Symptom diary | Done (screen + `log_symptom` tool) | `agent/tools/SymptomTools.ets`, `pages/SymptomLogPage.ets` |
| T28 | F-45 Locked data, open card | Done (needs a device screen lock) | `common/AppLock.ets`, `components/LockScreen.ets` |
| T29 | F-46 Privacy ledger | Done | `common/Net.ets`, `privacy/Ledger.ets`, `pages/PrivacyPage.ets` |
| T30 | F-47 Accessible and calm UI | Done; not checked with the screen reader on | `common/Motion.ets`, `accessibilityText` across components |

Added later (Workstream B, 4 Oct; not tasks in this file): accounts and profile backup, 8-step onboarding,
emergency details and first-responder view, doctor visits, feeling diary, notification categories, watch SOS page,
Live View, lock-screen medical ID, NFC card tag, watch pairing. See [PRODUCT.md](PRODUCT.md#6-feature-catalogue-with-status)
and [ARCHITECTURE.md](ARCHITECTURE.md).

## Feature map

| Feature | Task |
|---|---|
| Combination check against my meds (≥2 QT drugs, CYP450) | **T1** |
| Safer alternatives | **T2** |
| Lookup trace + confidence ("How we know") | **T3** |
| Bulgarian + Polish brand names | **T4** |
| Check history timeline | **T5** |
| Dashboard (meds by risk, recent checks, combo warnings, live HR) | **T6** |
| Saved chat conversations | **T7** |
| Country emergency numbers (ambulance + general) | **T8** |
| Escalation: alert → "I'm OK" countdown → else auto SOS | **T9** |
| SOS to all ICE contacts: GPS, meds, genotype, avoid list, cooldown, test SOS | **T10** |
| Emergency card in 13 languages | **T11** |
| QR on the card + opt-in share link | **T12** |
| Doctor Prep per specialty (extends F-14) | **T13** |
| Rich vitals: HRV, RR interval, stress, irregular rhythm, resting HR, sleep | **T14** |
| Watch buzz when a check flags a dangerous drug | **T15** |
| Settings | **T16** |
| Brand palette | **T17** |
| Live View for SOS + checks | **T18** |
| Box barcode scan | **T19** |
| More Celia intents | **T20** |
| Medication reminders | **T21** |
| Genotype trigger coach | **T22** |
| Travel & pharmacy mode | **T23** |
| Bystander mode with CPR metronome | **T24** |
| Read card aloud | **T25** |
| Nearest hospital / pharmacy / AED | **T26** |
| Symptom diary | **T27** |
| Locked data, open card | **T28** |
| Privacy ledger | **T29** |
| Accessible & calm UI | **T30** |

## Conventions for every task

- Strict ArkTS, load skills first (`arkts-language`, `arkui-development`, + the kit's skill); verify APIs in Context7.
- **Verdicts and safety decisions stay deterministic.** The LLM only explains; validate its output, fall back.
- Verify: unit tests `app/scripts/test.sh` · emulator `app/scripts/run.sh` (build → install → screenshot).
- Each task = one or a few small commits (`feat(drugs): …`). Update `AI_WORKFLOW.md` as you go.

---

## Phase A - Drug-safety core (fail fast)

### T1: Combination check against my meds  · F-19 · Mark + Kaloyan · M

**Description:** When a drug is checked, also check it against the user's current meds. Deterministic rules:
(a) new drug + ≥1 current med both on the QT list → combo risk; (b) CYP3A4 / CYP2D6 inhibitor + QT-risk substrate
(e.g. clarithromycin + any QT drug metabolised by CYP3A4) → combo risk with the enzyme named. Agent and verdict
card explain it; the LLM never decides it.

**Acceptance criteria:**
- [ ] `DrugChecker.checkCombo(verdict, meds)` returns `ComboVerdict` (`NONE / ADDITIVE_QT / CYP_INTERACTION`, involved drugs, reason)
- [ ] `drugs.json` / `drugs` table carry `cypSubstrate[]`, `cypInhibitor[]` per ingredient (curated, source cited)
- [ ] Verdict card shows a combo banner; agent tool `check_drug` returns it in context

**Verification:**
- [ ] Unit tests: escitalopram on list + ondansetron → `ADDITIVE_QT`; bisoprolol + amoxicillin → `NONE`; clarithromycin + QT substrate → `CYP_INTERACTION`
- [ ] Emulator: add 2 risky meds, check a third → banner visible (screenshot)

**Dependencies:** F-05 · **Files:** `drugs/DrugChecker.ets`, `model/DrugVerdict.ets`, `resources/rawfile/drugs.json`, `data/` script, `test/DrugChecker.test.ets`

### T2: Safer alternatives  · F-20 · Mark · S

**Description:** For risky ingredients, list curated alternatives from the same class that are `NOT_LISTED`
(cipro → amoxicillin; ondansetron → ask doctor about alternatives). Shown on the verdict card as "Ask your doctor
about:" - never generated by the LLM, never phrased as an instruction.

**Acceptance criteria:**
- [ ] Data field `alternatives[]` per risky ingredient; each alternative is itself `NOT_LISTED` (build-time check)
- [ ] Verdict card + "Ask your doctor" text include them

**Verification:** unit test that every alternative resolves to `NOT_LISTED`; emulator screenshot for ciprofloxacin.

**Dependencies:** F-05, F-07 · **Files:** `drugs.json`, data script, `DrugChecker.ets`, verdict card component

### T3: Lookup trace + confidence  · F-21 · Mark · M

**Description:** Make every verdict explain *how* it was found. Steps: bundled exact match → alias / fuzzy →
`/drug-check` online (server normalises with RxNorm, then curated list; optional OpenFDA torsades signal as
info only) → `UNKNOWN_DRUG`. External APIs are called only from the Edge Function.

**Acceptance criteria:**
- [ ] `DrugVerdict` gains `confidence: number` (0-1) and `trace: LookupStep[]`
- [ ] Verdict card has a collapsible "How we know" row listing the steps and the source
- [ ] Offline: trace ends at the bundled step, still correct

**Verification:** unit tests for exact (1.0), fuzzy/misspelling (< 1.0), unknown (`UNKNOWN_DRUG`, 0); airplane-mode check on emulator.

**Dependencies:** F-05 · **Files:** `model/DrugVerdict.ets`, `DrugChecker.ets`, `backend/supabase/functions/drug-check/`, verdict card

### T4: Bulgarian + Polish brand names  · F-22 · Mark · S

**Description:** Extend aliases with Bulgarian and Polish brand names, curated from the public national medicine registers
(BDA for Bulgaria, URPL for Poland) - cite them in README.

**Acceptance criteria:**
- [ ] ≥ 30 BG and ≥ 30 PL brand aliases map to ingredients in `drugs.json` and `drug_aliases`
- [ ] Cyrillic input works (e.g. "Ципрофлоксацин")

**Verification:** unit tests with Latin + Cyrillic brand names. **Dependencies:** F-05 · **Files:** `data/`, `drugs.json`, `seed.sql`

### Checkpoint A
- [x] `app/scripts/test.sh` green · combo banner + alternatives + "How we know" visible on emulator · works offline

---

## Phase B - History & dashboard

### T5: Scan history  · F-23 · Georgi (UI) + Mark (RDB) · M

**Description:** Log every check (chat, Medicines, photo, Celia intent) to RDB and show a timeline.

**Acceptance criteria:**
- [ ] `LocalStore.logScan(ScanRecord)` / `listScans(filter)`; RDB table `scans`
- [ ] History page: newest first, risk badge (colour + icon + text), filter by risk, tap → verdict card
- [ ] Empty state ("No checks yet - try 'Can I take ibuprofen?'")

**Verification:** emulator: 3 checks from different entry points → all listed; survives restart.

**Dependencies:** F-01 storage, F-07 · **Files:** `data/LocalStore.ets`, `model/ScanRecord.ets`, `pages/HistoryPage.ets`, `common/Routes.ets`

### T6: Dashboard  · F-24 · Georgi · M

**Description:** Overview at the top of the Heart tab (or Agent home header): my meds by risk, last 5 checks,
combo conflicts, compact live HR. Charts drawn with ArkUI `Shape` / `Canvas`, no web libs.

**Acceptance criteria:**
- [ ] Cards: meds-by-risk bar, recent checks, active combo warnings, HR now + source badge
- [ ] Quick actions: Check a medicine · Emergency card · Doctor prep
- [ ] Loading / empty / no-watch states

**Verification:** emulator screenshot light + dark. **Dependencies:** T1, T5, F-09 · **Files:** `pages/HeartPage.ets`, `components/dashboard/*.ets`

### T7: Chat conversation history  · F-25 · Kaloyan (store) + Georgi (UI) · M

**Description:** Persist chats on device; list, resume, start new. Only the current conversation's messages are
sent to `/agent` (de-identified context as today).

**Acceptance criteria:**
- [ ] RDB tables `conversations`, `messages`; title = first user message (truncated)
- [ ] Conversation list + "New chat"; resume restores messages and action cards
- [ ] Delete conversation

**Verification:** emulator: two chats, kill app, reopen → both resumable.

**Dependencies:** F-02 · **Files:** `data/LocalStore.ets`, `agent/AgentCore.ets`, `pages/AgentPage.ets`, `pages/ConversationsPage.ets`

### Checkpoint B
- [x] Fresh install → 3 checks → visible in history + dashboard; chats survive restart; no crashes

---

## Phase C - Emergency upgrade

### T8: Country emergency numbers  · F-26 · Georgi · S

**Description:** Bundled table ISO-3166 alpha-2 → `{ ambulance, general }` (e.g. PL 999/112, BG 150/112,
US 911). Country in profile (default from system locale). Emergency screen shows both when they differ.

**Acceptance criteria:**
- [ ] `common/EmergencyNumbers.ets` with ≥ 40 countries, sources cited; fallback 112
- [ ] Emergency "Call" button uses ambulance number; second button for general if different

**Verification:** unit test PL / BG / US / unknown. **Dependencies:** F-08 · **Files:** `common/EmergencyNumbers.ets`, `model/Profile.ets` (+`country`), `pages/EmergencyPage.ets`

### T9: SOS escalation chain  · F-27 · Kaloyan + Mark · M

**Description:** Critical `VitalsAlert` → notification + watch buzz + full-screen countdown (60 s) with a big
**"I'm OK"** button → no answer → SOS (T10). Also triggered by the emergency pre-filter (F-04) without countdown
if the user says "help".

**Acceptance criteria:**
- [ ] Pure state machine `SosController` (`IDLE → COUNTDOWN → ACKED | SOS_SENT | CANCELLED`), time injected for tests
- [ ] Countdown screen readable at a glance, vibrates; "I'm OK" logs the event
- [ ] Every transition logged via `LocalStore.logEvent`

**Verification:** unit tests ack / timeout / cancel / double-trigger; emulator: `runScenario('lqt2_startle_tachy')` → countdown → let it expire.

**Dependencies:** F-09, F-10, T14 · **Files:** `emergency/SosController.ets`, `pages/SosCountdownPage.ets`, `vitals/VitalsService.ets`, `test/SosController.test.ets`

### T10: SOS fan-out, GPS, cooldown  · F-28 · Mark + Georgi · M

**Description:** SOS sends to every ICE contact: location (Location Kit, map link), condition + genotype, meds,
drugs to avoid, ICD. Channels, in order of what works on API 20: open dialer to ambulance number (`call.makeCall`),
SMS (verify - `SEND_MESSAGES` is probably system-only → use SMS composer via Want, or backend SMS from an Edge
Function), email via Edge Function (provider key only in Supabase secrets). 10-minute cooldown; "Test SOS" sends
a clearly marked test.

**Acceptance criteria:**
- [ ] `SosService.send()` builds one message from profile + location; per-contact, per-channel result logged (`SosEvent`)
- [ ] Cooldown blocks repeat sends for 10 min (UI says so); test mode labelled "TEST"
- [ ] Location permission asked only at SOS setup; SOS still works without location

**Verification:** unit test message builder + cooldown; emulator test SOS (simulated location) with screenshots; document which channels are real vs simulated in ARCHITECTURE capability table.

**Dependencies:** T8, T9 · **Files:** `emergency/SosService.ets`, `module.json5` (permissions), `backend/supabase/functions/sos/`, `model/SosEvent.ets`

### T11: Emergency card in 13 languages  · F-29 · Georgi · M

**Description:** Pre-translated, reviewed card strings - EN, PL, BG, DE, FR, ES, IT, UK, RO, CS, NL, PT, TR. Static
resources, **no LLM at emergency time**. Language switcher on the card; user data (meds, notes) stays as entered.

**Acceptance criteria:**
- [ ] Card template strings for 13 locales; switcher with flags/codes
- [ ] Readable by a stranger: big type, high contrast, "avoid QT-prolonging drugs" line in each language

**Verification:** emulator screenshots EN / PL / BG; strings file lint (no missing keys).

**Dependencies:** F-08 · **Files:** `pages/EmergencyPage.ets`, `common/CardStrings.ets` or `resources/*/element/string.json`

### T12: QR + shareable emergency card  · F-30 · Georgi · M

**Description:** ArkUI `QRCode` with the card as compact text - works offline, scannable by any phone camera.
Optional public link (Edge Function stores a card under a random slug) **only with explicit opt-in**, revocable,
documented in `AI_FEATURES.md` because personal data leaves the device.

**Acceptance criteria:**
- [ ] QR on the card page and lock-screen-friendly full-screen view
- [ ] Opt-in share link: create / revoke; default off

**Verification:** scan QR with a second phone → readable text; revoke → link 404.

**Dependencies:** F-08, T11 · **Files:** `pages/EmergencyPage.ets`, `components/CardQr.ets`, `backend/supabase/functions/card/`

### Checkpoint C
- [x] Simulated LQT2 → countdown → no tap → SOS with country number + location · card in 3 languages · QR scans (scan from a second phone not recorded)

---

## Phase D - Doctor, watch, settings, look

### T13: Doctor Prep by specialty  · F-31 (extends F-14) · Kaloyan + Georgi · M

**Description:** Pick specialty (cardiologist, surgeon, dentist, anesthesiologist, GP, custom) + language →
safety brief. Deterministic sections: meds with risk, flagged checks (T5), drugs to avoid for this specialty
(e.g. anesthesiologist: anaesthetics/antiemetics; dentist: local anaesthetics with adrenaline, antibiotics),
genotype triggers, recent events. LLM writes only a short summary, validated (no drug may be called safe if the
list says otherwise). Share as text / PDF.

**Acceptance criteria:**
- [ ] Specialty → curated "watch-outs" table in data (cited)
- [ ] Brief renders offline without the LLM summary; with it when online
- [ ] Share sheet (text; PDF if feasible)

**Verification:** unit test the deterministic section builder; emulator screenshot per specialty.

**Dependencies:** T5, F-02 · **Files:** `doctor/DoctorPrep.ets`, `pages/DoctorPrepPage.ets`, `agent/` validator

### T14: Rich vitals  · F-32 · Mark · M

**Description:** Extend `VitalsSample` with optional `hrv`, `rrMs`, `restingHr`, `stress`, `asleep`,
`irregular`, `steps`. Wear Engine fills what it can; `SimulatedSource` fills all. `AlarmRules` gets genotype
context: LQT1 exertion spike, LQT2 startle at rest, LQT3 brady while asleep, irregular rhythm.

**Acceptance criteria:**
- [ ] Contract extended (optional fields, no breaking change); scenarios updated
- [ ] New `AlertKind`s: `IRREGULAR_RHYTHM`, `HRV_DROP` (+ severity for T9)

**Verification:** unit tests per scenario and genotype. **Dependencies:** F-09 · **Files:** `model/Vitals.ets`, `vitals/*.ets`, `test/AlarmRules.test.ets`

### T15: Watch buzz on risky check  · F-33 · Mark · S

**Description:** `KNOWN_RISK` or combo verdict → Wear Engine notify "Don't take X before asking your doctor".
Real device only; emulator logs to hilog.

**Acceptance criteria:** [ ] fires once per check · [ ] no-watch path silent and logged

**Verification:** real device buzz (video clip for demo). **Dependencies:** F-13, T1 · **Files:** `vitals/WearEngineSource.ets`, `drugs/` hook

### T16: Settings screen  · F-34 · Georgi · S

**Description:** Edit profile (genotype, ICD, notes, country), ICE contacts (name, phone, relation, optional email),
card language, test SOS, watch status / disconnect, clear all data (confirm).

**Acceptance criteria:** [ ] all fields persist via `LocalStore` · [ ] clear data returns to onboarding

**Verification:** emulator walk-through. **Dependencies:** F-01, T8, T10 · **Files:** `pages/SettingsPage.ets`, `model/Profile.ets` (`Contact.email`)

### T17: Brand palette  · Georgi · S

**Description:** Define the app palette in `resources/base/element/color.json` and `resources/dark/element/color.json` (one red accent for heart/emergency,
risk colours always paired with icon + text). Keep HarmonyOS system components.

**Verification:** light + dark screenshots of every tab. **Dependencies:** none · **Files:** `color.json` (base, dark)

### Checkpoint D (complete)
- [ ] Full demo flow on emulator, no crashes, every screen has loading / empty / error states
- [x] ARCHITECTURE capability table honest for Location, QR, SMS, email, Wear Engine
- [x] README "how to verify each feature" updated; `AI_WORKFLOW.md` updated

---

## Phase E - Creative wave (F-35..F-47)

Daily-companion and HarmonyOS-native features. Same rules: verdicts deterministic, data on device, every network
call recorded in the privacy ledger (T29), every ⚠️ kit has a labelled fallback. **Re-check each kit API in
Context7 before coding.** Suggested order (impact ÷ effort): T19, T21, T24, T27, T30, T28, T29, T23, T22, T18,
T20, T26, T25.

### T18: Live View for SOS and checks  · F-35 · Georgi + Kaloyan · M

**Description:** Show live state outside the app: SOS countdown with an "I'm OK" button (T9), live HR during an
alert, and the last med-check result, on the lock screen / status bar via Live View Kit. If Live View is not
available (scenario approval, emulator), fall back to an ongoing notification with action buttons.

**Acceptance criteria:**
- [ ] `LiveStatus` service: `startSos(secondsLeft)`, `updateHr(hr)`, `showVerdict(v)`, `end()`; picks Live View or notification fallback
- [ ] "I'm OK" from the lock screen acks the SOS state machine
- [ ] Fallback path logged and labelled in ARCHITECTURE capability table

**Verification:** emulator: simulated alert → countdown visible on lock screen (or notification) → tap "I'm OK" → state `ACKED`.

**Dependencies:** T9 · **Files:** `emergency/LiveStatus.ets`, `module.json5`, `pages/SosCountdownPage.ets`

### T19: Box barcode scan  · F-36 · Mark (data) + Georgi (UI) · M

**Description:** Scan the EAN-13 / GS1 DataMatrix on the medicine box → GTIN → curated `GtinEntry` table
(≈ 50 common PL/BG boxes for the demo, source cited) → ingredient → `DrugChecker`. Unknown GTIN → offer photo OCR
(F-06). Works from a photo on the emulator.

**Acceptance criteria:**
- [ ] Camera scan (Scan Kit) and decode-from-photo both return a GTIN
- [ ] GS1 parser extracts GTIN (AI 01) from DataMatrix payloads; known GTIN → verdict card
- [ ] Unknown GTIN → "We don't know this box yet - take a photo of the name" → OCR path

**Verification:** unit tests for GS1 parsing + lookup; emulator: decode sample box images → verdict (screenshot).

**Dependencies:** F-05, F-06 · **Files:** `drugs/BarcodeService.ets`, `drugs/Gs1.ets`, `resources/rawfile/gtin.json`, `pages/MedicinesPage.ets`, `test/Gs1.test.ets`

### T20: More Celia intents  · F-37 · Kaloyan · M

**Description:** Add intents beyond `CheckDrugSafety` / `ShowEmergencyCard`: `LogSymptom`, `AddMedication`,
`ShowPharmacyCard`, `ReadEmergencyCard`, `TakeDose`. Each runs deterministic code (store, pages, TTS), never the
LLM. Same verification caveat as F-11.

**Acceptance criteria:**
- [ ] Intents registered with parameters + English utterance examples
- [ ] Each intent maps to an existing service (T21, T23, T25, T27) and returns a short text result
- [ ] Documented "built, not verifiable here because …" if Celia is unavailable

**Verification:** intent unit calls from a test harness; real-device check if available.

**Dependencies:** F-11, T21, T23, T27 · **Files:** `insightintents/*.ets`, `module.json5`, `resources/base/profile/insight_intent.json`

### T21: Medication reminders  · F-38 · Georgi + Mark · M

**Description:** Per-med schedule (times/day). Reminders fire even when the app is closed (system reminder
agent), with "Taken" and "Snooze 10 min". Taken/missed doses are logged and appear in the doctor report (T13).
Reminder sound is soft (LQT2 rule from T22).

**Acceptance criteria:**
- [ ] `DoseReminder` stored per med; published via `reminderAgentManager`; edits re-publish
- [ ] Notification actions log `TAKEN` / `SNOOZED`; no action within 1 h → `MISSED`
- [ ] Today view: doses taken / due

**Verification:** emulator: reminder 1 min ahead → kill app → notification fires → tap Taken → logged.

**Dependencies:** F-01 · **Files:** `reminders/ReminderService.ets`, `model/DoseReminder.ets`, `data/LocalStore.ets`, `pages/MedicinesPage.ets`

### T22: Genotype trigger coach  · F-39 · Kaloyan (content) + Georgi (UI) · S

**Description:** Short, cited, genotype-specific guidance shown at the right moment: LQT1 - before exercise /
swimming, "swim with a buddy, don't swim alone"; LQT2 - avoid sudden loud sounds (gentle-wake alarm guidance,
the app itself only uses ramped tones + haptics); LQT3 - night monitoring emphasis, rest-time alerts. Static
content, no LLM.

**Acceptance criteria:**
- [ ] `coach.json` keyed by genotype, each tip with source; UNKNOWN shows general tips
- [ ] Tips appear on dashboard and in agent `explain_condition`
- [ ] App-wide sound policy: no sudden loud sounds when genotype = LQT2

**Verification:** unit test genotype → tip set; screenshots for LQT1/2/3.

**Dependencies:** F-01 · **Files:** `resources/rawfile/coach.json`, `components/CoachCard.ets`, `common/SoundPolicy.ets`

### T23: Travel & pharmacy mode  · F-40 · Georgi · M

**Description:** Location → country → auto-set emergency number (T8) and card language (T11), with a "You're in
Germany - emergency 112, card in German" banner. "Pharmacy card": full-screen message in the local language -
"I have Long QT syndrome. Please check the QT risk of any medicine before dispensing." + current meds.

**Acceptance criteria:**
- [ ] Country from location (reverse geocode), manual override in Settings
- [ ] Pharmacy card full-screen, brightness up, in local language + English
- [ ] No location → keeps profile country, no error

**Verification:** emulator with simulated location (DE, PL, BG) → number + language switch.

**Dependencies:** T8, T11 · **Files:** `common/CountryResolver.ets`, `pages/PharmacyCardPage.ets`, `pages/EmergencyPage.ets`

### T24: Bystander mode  · F-41 · Georgi · M

**Description:** "Help this person" screen for a stranger, reachable from the widget and emergency card without
unlocking app data: 1) call (country number, big button), 2) start hands-only CPR if not breathing normally,
3) use an AED. CPR metronome at 110/min (haptic + soft click). Note: "Has an ICD - still do CPR; an AED is safe
to use." Content from public resuscitation guidelines, cited.

**Acceptance criteria:**
- [ ] 3-step screen, huge text, works without unlock (T28) and offline
- [ ] Metronome 110 bpm, start/stop, keeps screen on
- [ ] ICD note shown only if `hasIcd`

**Verification:** unit test metronome interval; emulator screenshots; open from widget.

**Dependencies:** T8, F-12 · **Files:** `bystander/BystanderPage.ets`, `bystander/Metronome.ets`, `widget/`

### T25: Read card aloud  · F-42 · Kaloyan · S · P2

**Description:** TTS reads the emergency card in the selected card language for a paramedic. Language not
supported by the engine → button hidden, text stays.

**Acceptance criteria:** [ ] play / stop on card page · [ ] unsupported language hides the button, logged

**Verification:** emulator/real device: English read-out; unsupported language case.

**Dependencies:** T11 · **Files:** `emergency/CardSpeaker.ets`, `pages/EmergencyPage.ets`

### T26: Nearest hospital / pharmacy / AED  · F-43 · Mark · M · P2

**Description:** Nearby search for emergency department, pharmacy, AED; list with distance + "Route" (opens map).
Shown in SOS screen and travel mode. Offline / no key → only the country number, no error.

**Acceptance criteria:** [ ] top 3 results per type · [ ] offline fallback · [ ] location not stored, query recorded in ledger (T29)

**Verification:** real device or emulator with simulated location; offline case.

**Dependencies:** T23, T29 · **Files:** `emergency/NearbyService.ets`, `components/NearbyList.ets`

### T27: Symptom diary (text or voice)  · F-44 · Kaloyan + Georgi · M

**Description:** "Felt dizzy after climbing stairs" → emergency pre-filter first (F-04) → else `/agent` tool
`log_symptom` returns a `SymptomEntry` (time, symptom enum, activity, severity 1-5, free note) → validated
(enum check, ranges; invalid → save raw text only) → HR window ±10 min attached from vitals → diary list +
doctor report section.

**Acceptance criteria:**
- [ ] Validator rejects unknown symptom / severity; fallback stores raw text
- [ ] Red-flag text never lands only in the diary - goes to emergency path
- [ ] Diary list + included in T13 report

**Verification:** unit tests: valid, malformed, red-flag; emulator: log by text, see in diary.

**Dependencies:** T7, F-04, F-09 · **Files:** `agent/` (tool + validator), `model/SymptomEntry.ets`, `data/LocalStore.ets`, `pages/DiaryPage.ets`

### T28: Locked data, open card  · F-45 · Mark + Georgi · M

**Description:** Biometric / PIN unlock protects meds, diary, chat, history. Emergency card, bystander mode and
pharmacy card stay readable without unlock. RDB opened encrypted.

**Acceptance criteria:**
- [ ] `userAuth` (face/fingerprint, PIN fallback) gate on private tabs; lock after 5 min in background
- [ ] Emergency / bystander / pharmacy routes bypass the gate
- [ ] RDB `encrypt: true`; migration from unencrypted store tested

**Verification:** emulator with PIN: private tab asks, emergency card does not.

**Dependencies:** F-01 · **Files:** `common/AuthGate.ets`, `data/LocalStore.ets`, `components/MainTabs.ets`

### T29: Privacy ledger  · F-46 · Kaloyan · S

**Description:** Single HTTP wrapper records every outbound request: time, endpoint, field *names* sent (never
values), size. "What left my phone" screen: list, filter, export, clear. Backs the digital-sovereignty pitch.

**Acceptance criteria:**
- [ ] All network calls go through `common/Net.ets` (lint rule / review check)
- [ ] `LedgerEntry` stored locally; screen in Settings
- [ ] Unit test: request with name/phone fields is rejected before sending (D6 guard)

**Verification:** unit tests; emulator: agent chat → entries appear.

**Dependencies:** none (do before new network features) · **Files:** `common/Net.ets`, `privacy/Ledger.ets`, `pages/PrivacyPage.ets`

### T30: Accessible & calm UI  · F-47 · Georgi · S

**Description:** Large-text mode (respects system font scale, then +1 step), high-contrast risk colours,
`accessibilityText` on every control, haptics instead of sudden sounds, primary actions in the bottom third
(one-hand), reduced motion option.

**Acceptance criteria:** [ ] screen reader reads every control on all tabs · [ ] layout survives max font scale · [ ] no autoplaying sound anywhere

**Verification:** emulator with max font size + screen reader: screenshots of every tab.

**Dependencies:** T17 · **Files:** `components/*`, `pages/*`, `resources/base/element/float.json`

### Checkpoint E
- [ ] Barcode → verdict, reminder fires with app closed, bystander mode from widget, symptom diary entry - all on emulator (all except the closed-app reminder, which needs an AGC quota)
- [x] Every ⚠️ kit either works or has its fallback shown and documented
- [x] Privacy ledger shows every request made during the demo

---

## Parallel work

| Lane | Tasks |
|---|---|
| Mark | T1 → T2 → T3 → T4 · T14 → T15 · T19 (data) · T28 · T26 |
| Georgi | T17 · T5 → T6 · T8 → T11 → T12 · T16 · T30 · T24 · T21 · T23 · T18 |
| Kaloyan | T7 · T9 (after T14) · T13 (after T5) · T29 (early) · T27 · T22 · T20 · T25 |
| Shared | T10 (after T8 + T9) |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| SMS send API restricted to system apps | Med | SMS composer via Want, or backend SMS; say so honestly |
| Scope vs 24 h | High | P0 first; these are P1/P2, pulled after freeze-check |
| Location / Wear Engine not on emulator | Med | Simulated, labelled `SIMULATED` (D9) |
| Personal data leaving device (share link, SOS email) | High | Opt-in, minimal, documented in `AI_FEATURES.md` |
| Wrong medical data in combo / alternatives / translations | High | Curated + cited sources, unit tests, "ask your doctor" wording |
| Live View / Map / Site / TTS need approval or don't run on emulator | Med | Notification / text fallback, documented in capability table |
| GTIN table too small for real boxes | Med | Honest "demo set", OCR fallback, add boxes as found |
| Bystander CPR guidance wrong or outdated | High | Text from current public resuscitation guidelines, cited, no improvisation |
