# Celia.ai - Product spec

> **Status (4 Oct 2026, final hackathon day):** this file describes the product **as built** in `app/` (phone),
> `watch/` (wearable) and `backend/` (Supabase). "Built, unverified" means the code is in place but needs a real
> phone, a watch or a platform approval to be seen working. How to check each feature:
> [README - How to verify each feature](../README.md#how-to-verify-each-feature-emulator).
>
> Related: [IDEA.md](IDEA.md) (why, user story, demo) · [ARCHITECTURE.md](ARCHITECTURE.md) (contracts, API,
> capability table) · [TASKS.md](TASKS.md) (task list with status) · [design/DESIGN.md](design/DESIGN.md) (UI).
> Change a contract → update `ARCHITECTURE.md` first.

## Contents

1. [Decisions](#1-decisions)
2. [One-liner and users](#2-one-liner-and-users)
3. [How it works](#3-how-it-works)
4. [Screens (v2 layout)](#4-screens-v2-layout)
5. [Outside the app: widgets, Celia intents, notifications, watch](#5-outside-the-app-widgets-celia-intents-notifications-watch)
6. [Feature catalogue with status](#6-feature-catalogue-with-status)
7. [Robustness and quality](#7-robustness-and-quality)
8. [Demo (3 min)](#8-demo-3-min)
9. [Not built / next](#9-not-built--next)

## 1. Decisions

| # | Decision | Source |
|---|---|---|
| D1 | **Native HarmonyOS only**: ArkTS + ArkUI, Stage model, DevEco Studio 6.x, hvigor / ohpm / hdc. System kits called directly from ArkTS. No cross-platform layer. | CLAUDE.md, ARCHITECTURE |
| D2 | **API 20** minimum and target (`6.0.0(20)`). Everything core runs on the **emulator**. Bundle `com.celiaai.app`, `deviceTypes: ["phone"]`. | task, `app/AppScope/app.json5`, `module.json5` |
| D3 | **Backend: Supabase, EU (Frankfurt).** Postgres + Edge Functions: `drug-check`, `agent`, `realtime-session`, `transcribe`, `speak`, `vision-extract`, `box-identify`, `med-info`, `doctor-summary`, `share`, `sos`. The OpenAI key lives only in function secrets; the app holds the public anon key. | `backend/supabase/functions/` |
| D4 | **Verdicts are deterministic** (curated LQTS drug list in `DrugDataset.ets`, `DrugChecker`, `ComboRules`). The LLM only explains and picks tools; text that contradicts the verdict or reassures about a risky drug is dropped. Unknown input → `UNKNOWN_DRUG`, never "safe". | ARCHITECTURE agent rules |
| D5 | **Offline first:** drug data and the Polish barcode register are bundled; `/drug-check` is an optional online path with fallback to the bundle. No network → the agent runs a deterministic offline mode; drug checks, card and SOS still work. | `drugs/`, `agent/OfflineAgent.ets` |
| D6 | **Optional account, offline core:** sign up once (Supabase Auth, email + password), then the app works from a cached session. Signed in, profile and medicines are backed up to the user's own `profiles` row (RLS by user) and restored on a new phone. Without an account they stay on the phone. Local data is in encrypted RDB. | `account/`, migration `20261004100000` |
| D7 | **LQTS only.** Brugada / CPVT not built. | IDEA scope rules |
| D8 | **Built fresh in this repo.** Third-party data and libraries are cited in README and `AI_WORKFLOW.md`. | Challenge Rules §4 |
| D9 | **Honest platform claims:** simulated data labelled `SIMULATED` on screen; each kit's status kept in ARCHITECTURE's capability table and the README table. | ARCHITECTURE |
| D10 | **Naming:** "Celia" = Huawei's system assistant (Intents Kit integration). Our in-app assistant is called **"the agent"** in the UI; the orb tab is labelled "Talk". | `resources/base/element/string.json` |

## 2. One-liner and users

An **agent-first heart-safety companion for people with Long QT syndrome** on HarmonyOS: an agent you talk to
about your condition, that checks every medicine before you take it, watches your heart rate through a watch app,
and takes over in an emergency. The safety core works fully offline; every request the phone makes is listed in an
on-phone ledger.

| User | Main surfaces |
|---|---|
| Person with LQTS (or parent of a child with LQTS) | Today, Medicines, agent, Health, reminders, widgets, watch |
| Pharmacist, ER staff, bystander | Emergency card, QR link, first-responder view, help guide, lock-screen medical ID |
| Doctor | Doctor-visit page and its encrypted web report |

Challenge areas: **Human-Centric** and **Intelligent Experiences** (primary); Spatial lightly (location in SOS,
travel banner, nearby help).

## 3. How it works

```
 voice / text / photo ─► Agent stage ─► AgentCore ─► SafetyGate (emergency words → SOS, no model)
                                          │
                                          ├─► /agent or /realtime-session (OpenAI via Edge Functions)
                                          │      tools run on the phone: check_drug, log_symptom, log_dose, ...
                                          ├─► ResponseValidator ── invalid / timeout ──► deterministic fallback
                                          └─► offline: OfflineAgent (deterministic)

 Medicines: text │ barcode (Scan Kit) │ box photo (Core Vision OCR, cloud vision fallback)
            ─► DrugChecker (bundled data │ /drug-check) ─► ComboRules (my medicines) ─► verdict card

 Watch app (wearable) ─► Supabase watch_* tables ─► WatchCloudSource ─┐
 SimulatedSource (emulator, labelled) ────────────────────────────────┴► VitalsService ─► AlarmRules
                                         ─► alert ─► SOS countdown (30 s) ─► call 112 / contacts / responder view
                                         ─► agent check-in · notification · event log (doctor brief)
```

Shared contracts (`Profile`, `Medication`, `DrugVerdict`, `VitalsSample`, `AgentReply`, ...) live in
`app/entry/src/main/ets/model/` and are described in [ARCHITECTURE.md](ARCHITECTURE.md).

## 4. Screens (v2 layout)

One page in `main_pages.json` (`pages/Index`) with a root `Navigation` + `NavPathStack`. Route names are in
`common/Routes.ets`; the tab bar is `components/MainTabs.ets`.

### First launch

| Screen | Content | File |
|---|---|---|
| Welcome | Create an account / I already have an account / Set up without an account | `pages/WelcomePage.ets` |
| Sign up / log in | Email + password (8+ chars); restores the profile when one exists | `pages/AuthPage.ets` |
| Onboarding (8 steps) | Welcome + "not a medical device" consent · account · about you (name, date of birth, genotype, ICD) · medicines (each checked) · emergency contacts · country + emergency details · permissions (notifications, microphone, location) · pair a watch. Steps 2 and 4-8 can be skipped. | `pages/OnboardingPage.ets`, `onboarding/OnboardingFlow.ets` |

### Tab bar: Today · Medicines · orb · Health · Emergency

| Tab | Content | File |
|---|---|---|
| **Today** | Agent's one-line brief, next dose, resting heart rate over 7 days, four quick actions (incl. doctor visit, log how I feel), medicines chip, genotype tip of the day, travel banner when abroad | `pages/HomePage.ets` |
| **Medicines** | Search-first check (type, Scan), today's doses row (taken / due / missed / later), recently checked, my medicines grid; tap a medicine → sheet with risk band, what it is for, interactions, brands, optional AI explanation | `pages/MedicinesPage.ets`, `components/MedicineDetailSheet.ets` |
| **Orb → agent stage** | Full-screen page: orb at the bottom (tap to talk, tap to mute, End), live captions, "Show conversation", "Aa" to type, camera button for a box photo, Chats and New chat in the header. Tools appear as steps and cards (verdicts, confirm cards, tiles that open screens). | `pages/AgentPage.ets`, `components/agent/*` |
| **Health** | Live heart-rate card, a card per metric (resting HR, HRV, oxygen, breathing, sleep, steps, stress) with mini chart and fixed-rule status, Today / 14 days / 30 days, alerts, demo controls; tap a card → metric page with range band | `pages/HeartPage.ets`, `pages/MetricPage.ets` |
| **Emergency** | Start SOS and call first; first-responder view; medical card (13 languages, read aloud, QR link, NFC write); contacts; pharmacy card; nearby help; help guide; Test SOS. Long-press the tab to start the SOS countdown. | `pages/EmergencyPage.ets` |

### Pushed pages

| Area | Pages |
|---|---|
| Medicines | Check result, Scan (camera / album, teach this barcode), Check history, Medicine reminders |
| Agent | Chats (rename / delete) |
| Health | Trends, Symptom log, Feeling diary ("How are you feeling?"), Pair watch (6-digit code, also from Settings) |
| Doctor visits | Gallery (latest on top), New visit (kind of doctor, reason, date, worries, preview), Visit page (please-don't-prescribe list, AI summary, full brief, Share) |
| Emergency | SOS (countdown, then call / share / contacts / responder), First responder, Help guide (bystander, CPR metronome 110/min), Pharmacy card, Card view (scanned QR) |
| Settings | Your profile, Emergency contacts, Emergency details (blood type, allergies, cardiologist, show on card), emergency number, Account (backup, SOS contacts consent, delete cloud data), watch pairing, Privacy (What left my phone, export), app lock, Test SOS, clear data |

Every screen has loading, error and empty states (no network, agent offline, no watch, unknown drug).

## 5. Outside the app: widgets, Celia intents, notifications, watch

| Surface | What | Status |
|---|---|---|
| Widgets (`widget/pages/`, `form_config.json`) | The agent (2×4), Next dose (2×2), Resting heart rate, Can I take this? (check a medicine), How are you feeling?, Medical alert (2×4, opens bystander / responder), Medical ID (lock screen) | Built; lock-screen placement unverified |
| Celia intents (`insight_intent.json`) | `CheckDrugSafety`, `ShowEmergencyCard`, `LogSymptom`, `TakeDose`, `ShowPharmacyCard`, `AddMedication`, `ReadEmergencyCard`; all call deterministic code, never the LLM | Built and compiled; routing from Celia unverified |
| Notifications | Separate categories per kind (emergency is loud); dose due with Taken / Open; SOS countdown | Built; action buttons unverified on screen (emulator does not draw them) |
| Live View | SOS countdown card on the lock screen / panel, "SOS cancelled" | Works on the emulator; real phone needs Live View approval |
| Push (watch SOS → phone) | Push Kit token + `sos` function sender | Built, unverified (needs AGC Push Kit setup) |
| Watch app (`watch/`) | Heart rate (sensor or demo scenario), genotype alarm rules with vibration, check-in, fall → "Are you OK?" → SOS, metrics upload, 6-digit pairing, verdict glance from `watch_context` | Runs on the wearable emulator; see [README: watch app](../README.md#2-watch-app) |

## 6. Feature catalogue with status

Legend: **Built** = in the code and seen on the emulator · **Built, unverified** = code in place, not seen working
(reason given) · **Fallback** = a labelled substitute instead of the original kit · **Not built**.

### Core (F-01..F-18)

| ID | Feature | Status |
|---|---|---|
| F-01 | Onboarding saves the profile | Built (8 steps, B3) |
| F-02 | Agent with tools (18 tools, incl. page tools and confirm-before-write dose logging) | Built; dose confirmation card unit-tested only |
| F-03 | Response validation + fallback | Built, unit-tested |
| F-04 | Emergency pre-filter (SafetyGate) | Built, unit-tested |
| F-05 | Drug check by name (brands, typos, dose suffix, PL / BG names) | Built |
| F-06 | Drug check by photo of the box (Core Vision OCR, cloud vision fallback) | Built; camera capture unverified |
| F-07 | Verdict card (colour + icon + text, "How we know") | Built |
| F-08 | Emergency card + SOS | Built |
| F-09 | Vitals: watch (cloud) or simulated scenarios, genotype alarm rules | Built; real watch rows unverified |
| F-10 | Proactive agent check-in on alerts | Built |
| F-11 | Celia intents `CheckDrugSafety`, `ShowEmergencyCard` | Built, unverified (needs Celia on a real phone) |
| F-12 | Home widgets | Built (7 widgets) |
| F-13 | Wrist alert via Wear Engine | Fallback: phone notification + haptic; Wear Engine not wired |
| F-14 | Doctor report | Built as doctor visits (F-31, B6) |
| F-15 | Voice in / out | Built (live voice, tap-to-talk, demo clips on the emulator); real microphone unverified |
| F-16 | A2A agent (Agent Framework Kit) | Not built |
| F-17 | Caregiver tablet | Not built |
| F-18 | Brugada / CPVT pack | Not built |

### Expansion (F-19..F-34) - tasks T1..T16 in [TASKS.md](TASKS.md)

| ID | Feature | Status |
|---|---|---|
| F-19 | Combo check vs my medicines (additive QT, CYP inhibition) | Built |
| F-20 | Safer alternatives | Built |
| F-21 | Lookup trace + confidence | Built |
| F-22 | Bulgarian + Polish brand names | Built |
| F-23 | Check history | Built |
| F-24 | Dashboard | Built as the Today tab |
| F-25 | Saved chats | Built |
| F-26 | Country emergency numbers | Built |
| F-27 | SOS escalation ("Are you OK?" 30 s, then SOS) | Built |
| F-28 | SOS to contacts, location, 10-min cooldown, Test SOS | Built (share sheet / calls from the phone; watch SOS via `sos` function, test mode until Twilio is set) |
| F-29 | Card in 13 languages | Built |
| F-30 | QR + encrypted, revocable share link | Built |
| F-31 | Doctor visits by kind of doctor | Built; gallery, share and web block not yet seen on screen |
| F-32 | Rich vitals (HRV, breathing, stress, sleep, irregular rhythm) | Built; HRV, oxygen, breathing simulated by the watch and labelled |
| F-33 | Watch notice on a risky check | Built via cloud (`watch_context` → watch glance); not Wear Engine |
| F-34 | Settings | Built |

### Creative wave (F-35..F-47) - tasks T18..T30

| ID | Feature | Status |
|---|---|---|
| F-35 | Live View for SOS | Built (SOS countdown); HR / verdict updates not built (scenario approval) |
| F-36 | Box barcode scan (EAN / GS1 DataMatrix, Polish register, teach a barcode) | Built |
| F-37 | Five more Celia intents | Built, unverified |
| F-38 | Medication reminders | Built; system reminders need an AGC quota, in-app fallback works |
| F-39 | Genotype trigger coach | Built (tip on Today) |
| F-40 | Travel banner + pharmacy card | Built |
| F-41 | Bystander help guide + CPR metronome | Built |
| F-42 | Read the card aloud (medical part only) | Built (on-device voice or cloud `/speak`) |
| F-43 | Nearby hospital / pharmacy / AED | Fallback: map search; in-app Map Kit needs a key |
| F-44 | Symptom log (screen and agent tool) | Built |
| F-45 | App lock, card always reachable | Built; needs a screen lock on the device |
| F-46 | Privacy ledger "What left my phone" | Built |
| F-47 | Accessible and calm UI (screen-reader text, reduced motion) | Built, unverified with the screen reader on |

### Workstream B (4 Oct) - details in [ARCHITECTURE.md](ARCHITECTURE.md#key-data-flows)

| ID | Feature | Status |
|---|---|---|
| B1, B2 | Accounts, profile backup and restore, delete cloud data | Built |
| B3 | 8-step onboarding | Built |
| B4, B5 | Emergency details, first-responder view | Built |
| B6, B15 | Doctor visits, feeling diary | Built |
| B7 | Notification categories, dose Taken from the notification | Built; buttons unverified on screen |
| B8 | Watch SOS page (no second countdown), honest SOS page | Built |
| B9, B10 | Watch data by account (RLS), SOS contacts with consent | Built; B10 unverified until its migrations are applied |
| B12 | Push: watch SOS to the phone | Built, unverified |
| B13 | SOS Live View, lock-screen medical ID | Built; real phone unverified |
| B14 | NFC card tag | Built, unverified (needs NFC hardware) |
| B16 | Watch internals split, accelerometer rate | Built |

## 7. Robustness and quality

- Verdicts come only from `DrugChecker` + `ComboRules`; every model reply is validated; emergency words bypass the
  model; every fallback is logged.
- Every network call has a timeout, an offline state and a deterministic fallback.
- Personal fields are blocked from outbound requests except the named exceptions (`ACCOUNT_AUTH`, `PROFILE_SYNC`,
  `SOS_CONTACTS`); every request appears in the privacy ledger.
- Unit tests, no device needed: phone `app/scripts/test.sh`, watch `hvigorw test` in `watch/`, backend
  `deno test`, accounts RLS `backend/supabase/tests/run-rls.sh`. Current counts are in the README.
- Strict ArkTS; only the permissions in use; no secrets in the repo (`LocalConfig.ets` is gitignored).

## 8. Demo (3 min)

1. Hook: "Hundreds of everyday drugs can stop the heart of 1 in 2,000 people."
2. Agent: "The dentist gave me this" → barcode or photo of the box (clarithromycin) → **Known risk** →
   explanation, alternatives, interaction with my medicines (F-02, F-05..07, F-19, F-36).
3. "Celia, can I take ondansetron?" → our intent answers (F-11; real phone only, otherwise shown as built).
4. Simulated LQT2 scenario on the watch → alert → "Are you OK?" countdown → SOS page, emergency card, responder
   view (F-08..10, F-27).
5. Robustness: model returns garbage or reassurance → deterministic answer (F-03, tests in repo).
6. Close: offline safety core, ledger of what leaves the phone, condition packs next.

## 9. Not built / next

| Item | Notes |
|---|---|
| A2A agent (HMAF `AgentExtensionAbility`) | Not built |
| Wear Engine (real Huawei watch) | Not wired; wrist alerts fall back to the phone |
| Caregiver tablet | Not built |
| Brugada / CPVT condition pack | Not built; the drug list is data |
| Live View heart-rate / verdict updates | Needs a Live View scenario approval |
| In-app map (Map Kit + Site Kit) | Needs a key; map search fallback in place |
| Real SMS / calls from `sos` | Needs Twilio secrets; test mode until then |
| Sick-day electrolyte guard, QTc log, family screening leaflet | Ideas only |
