# Celia.ai — Product spec

> **What we build, in one place.** Derived from — and must stay consistent with — [`IDEA.md`](IDEA.md) (scope,
> priorities, demo), [`ARCHITECTURE.md`](ARCHITECTURE.md) (stack, contracts, API, ownership), [`PLAN.md`](PLAN.md)
> (checkpoints) and the per-person docs in [`team/`](team). If this file disagrees with those, they win — fix this
> file. Change a contract → update `ARCHITECTURE.md` first.

## 0. Decisions

| # | Decision | Source |
|---|---|---|
| D1 | **Stack: native HarmonyOS only** — ArkTS + ArkUI, Stage model, DevEco Studio 6.x, hvigor/ohpm/hdc. System kits called directly from ArkTS. No cross-platform layer (no React Native / RNOH, Flutter). | CLAUDE.md, ARCHITECTURE |
| D2 | **API 20** min and target (`compatibleSdkVersion` / `targetSdkVersion` = `6.0.0(20)`). Everything core runs on the **emulator**. Bundle **`com.celiaai.app`**. | task, ARCHITECTURE, `app/AppScope/app.json5` |
| D3 | **Backend: Supabase, EU region (Frankfurt).** Postgres (`drugs`, `drug_aliases`, `agent_logs`) + Edge Functions `/drug-check` (deterministic lookup) and `/agent` (one OpenAI model step; the tool loop runs in the app). The OpenAI key lives only in Edge Function secrets; the app holds just the public anon key (RLS read-only). | ARCHITECTURE, PLAN decisions log |
| D4 | **Verdicts are deterministic** (curated LQTS drug list, `DrugChecker`). The LLM only explains and picks tools; if its text contradicts the verdict, the text is dropped. Unknown input → `UNKNOWN_DRUG`, never "safe". | IDEA scope rules, ARCHITECTURE agent rules |
| D5 | **Offline:** `DrugChecker` uses the bundled `rawfile/drugs.json`; `/drug-check` is the online/fresh path with fallback to the bundle on error/timeout. No network → agent says it is offline, drug checks still work. | ARCHITECTURE, Kaloyan DoD |
| D6 | **Data on device:** profile, meds, ICE contacts, vitals, events live only in on-device ArkData RDB (no system backup). The backend gets drug names and, for `/agent`, a de-identified context (condition, genotype, med names, vitals summary). | ARCHITECTURE data rule |
| D7 | **LQTS only** for the build. Brugada/CPVT = one "condition packs" slide (drug list is data). | IDEA scope rules |
| D8 | **Built fresh in this repo.** Third-party data/libraries (CredibleMeds-derived categories, ohpm libs, DevEco templates) are cited in README + `AI_WORKFLOW.md`. | IDEA scope rules, Challenge Rules §4 |
| D9 | **Honest platform claims:** simulated vitals labelled `SIMULATED` on screen; each kit's emulator status kept in ARCHITECTURE's capability table. | ARCHITECTURE, IDEA |
| D10 | **Naming:** "Celia" = Huawei's system assistant we integrate with (Intents Kit). Our in-app agent needs its own persona name — **open, Kaloyan decides** (IDEA naming risk). UI calls it "the agent" until then. | IDEA |

## 1. One-liner

An **agent-first heart-safety companion for people with Long QT syndrome** on HarmonyOS: an AI agent you can talk
to about your syndrome, that checks every medicine before you take it, watches your heart through your Huawei watch,
and takes over in an emergency — with your health data staying on *your* devices.

Challenge areas: **Human-Centric** (primary) + **Intelligent Experiences** (primary); Spatial only lightly
(location sent with SOS).

Users: diagnosed LQTS patient (and parents of child patients) · secondary: pharmacist / ER staff reading the
emergency card · cardiologist reading the report.

## 2. How it works

```
 user text / photo of box ─► Agent chat ─► AgentCore ──► /agent (Supabase Edge Fn, OpenAI)
                                  │            │            tools run on-device: check_drug, add_med, …
                                  │            ▼
                                  │      ResponseValidator ── invalid / timeout 20 s ──► deterministic fallback
                                  ▼
 Medicines screen ─► OcrService (Core Vision, on-device) ─► DrugChecker (bundled drugs.json │ /drug-check)
                                                                  ▼
                                                            DrugVerdict ─► verdict card

 Watch (Wear Engine, real device) │ SimulatedSource (emulator) ─► VitalsService ─► AlarmRules ─► VitalsAlert
                                                                  ─► AgentCore.onProactive ─► check-in message
                                                                  ─► watch notification · LocalStore.logEvent

 Emergency keywords / SOS button ─► emergency mode (no LLM): card + Call 112 / ICE contact
```

Shared contracts (`Profile`, `Medication`, `DrugVerdict`, `VitalsSample/Alert`, `AgentReply/UiAction`), service
signatures and the backend API are defined **only** in [`ARCHITECTURE.md`](ARCHITECTURE.md) and mirrored in
`app/entry/src/main/ets/model/`.

## 3. Screens

Root `Navigation` + `NavPathStack`; bottom tabs **Agent (home) · Medicines · Heart · Emergency**; Onboarding is
pushed first when no profile exists. (Implemented in `app/entry/src/main/ets/pages/` + `components/MainTabs.ets`.)

| Screen | Content | Kits | Owner |
|---|---|---|---|
| **Onboarding** | condition (LQTS) · genotype LQT1/2/3/unknown · ICD y/n · current meds · ICE contacts · notes → `LocalStore.saveProfile` | ArkData RDB | Georgi |
| **Agent** (home) | message list, input bar, mic (hidden until voice works), typing indicator; renders `AgentReply.actions` as cards (`SHOW_VERDICT` → verdict card, `START_EMERGENCY` → emergency mode); offline state | NetworkKit http | Georgi (UI) · Kaloyan (AgentCore) |
| **Medicines** | my meds list, add med, "Check a medicine" by text or camera/photo picker → `OcrService` → `DrugChecker` → verdict card + "Ask your doctor" text | Core Vision Kit, `cameraPicker` / `PhotoViewPicker` | Georgi · Mark · Kaloyan |
| **Heart** | live HR + small chart, source badge `WATCH` / `SIMULATED`, alert list, hidden demo panel (`runScenario`) | Wear Engine Kit | Georgi · Mark |
| **Emergency** | big readable card (diagnosis, "avoid QT-prolonging drugs", current meds, ICD, contacts) in English + Polish, large **Call 112**, call ICE contact | `call` (dialer), NotificationKit | Georgi |
| **Widget** (P1) | 2×2 emergency card / "Check a medicine" shortcut | Form Kit | Georgi |

Every screen has loading, error and empty states (no network, agent offline, no watch, unknown drug).

## 4. Features

Priorities from [`IDEA.md`](IDEA.md). **P0** must work in the demo · **P1** strong extras · **P2** only if ahead.

### P0

| ID | Feature | Owner | Done when |
|---|---|---|---|
| F-01 | **Onboarding** saves the profile to RDB (condition, genotype, ICD, meds, ICE contacts, notes) | Georgi · Mark | fresh install → onboarding → tabs; profile survives restart |
| F-02 | **Agent chat with tools** — server: `check_drug`, `explain_condition`; app-side: `get_my_meds`, `add_med`, `get_vitals_summary`, `show_emergency_card`, `start_emergency` (→ `UiAction` types in ARCHITECTURE) | Kaloyan · Georgi | chat → drug question → correct deterministic verdict + explanation on the emulator |
| F-03 | **Response validation + fallback**: schema check, unknown actions dropped, verdict-contradiction check, 20 s timeout → deterministic reply; every fallback logged to hilog | Kaloyan | unit tests: valid, malformed JSON, unknown action, verdict mismatch, timeout; broken reply shown being caught |
| F-04 | **Emergency pre-filter**: "faint", "chest pain", "passed out", "can't breathe" → `START_EMERGENCY` with no LLM call | Kaloyan | unit test |
| F-05 | **Drug check by name** (brand, misspelling, dose suffix, Polish brand names) → `KNOWN_RISK / POSSIBLE_RISK / CONDITIONAL_RISK / NOT_LISTED / UNKNOWN_DRUG`; worst risk wins on multi-drug input | Mark | `drug-check` and `DrugChecker` give the same verdicts on shared test cases; works in airplane mode |
| F-06 | **Drug check by photo of the box**: on-device OCR → tokens → `DrugChecker` (finds the ingredient inside noisy text) | Kaloyan · Mark | sample box images resolve on the emulator (or kit status documented) |
| F-07 | **Verdict card** (chat, Medicines, widget): risk badge by colour **and** icon + text, ingredient, reason, source, "Ask your doctor" copy/share | Georgi | shown for every verdict type |
| F-08 | **Emergency card + SOS**: card readable by a stranger, Call 112 / ICE contact, location with SOS | Georgi | reachable from tab, agent action and pre-filter |
| F-09 | **Vitals**: live HR from watch (real device) or `SimulatedSource` scenarios `normal`, `lqt2_startle_tachy`, `lqt3_night_brady`, `watch_disconnect`; `AlarmRules` per genotype, debounce ≥ 15 s → `VitalsAlert` → logged | Mark | unit tests per scenario; emulator demo runs on simulated data with zero code changes |
| F-10 | **Proactive agent**: `VitalsAlert` → check-in message in chat + notification ("Your heart rate jumped to 165 while resting — are you OK?") | Kaloyan | demo beat 4 |

### P1

| ID | Feature | Owner | Done when |
|---|---|---|---|
| F-11 | **Intents Kit**: `CheckDrugSafety` (background, verdict text) + `ShowEmergencyCard` (foreground) — call `DrugChecker` / pages, never the LLM | Kaloyan | works in demo, or documented "built, not verifiable here because …" |
| F-12 | **Home widget** (Form Kit) | Georgi | on emulator home screen |
| F-13 | **Watch notification** via Wear Engine on alarm ("Heart rate high — open the app") | Mark | buzzes on paired real device |
| F-14 | **Doctor report**: event log + meds + flagged drugs as a shareable page/PDF | Kaloyan · Georgi | |
| F-15 | Voice in/out (Core Speech Kit, if English works) | Kaloyan | spoken question → answer |

### P2

| ID | Feature | Owner |
|---|---|---|
| F-16 | A2A `AgentExtensionAbility` so Celia can converse with our agent (Agent Framework Kit) | Kaloyan |
| F-17 | Caregiver tablet: distributed alert / app continuation | Georgi |
| F-18 | Brugada/CPVT condition pack (data + 1 rule) | Mark |

## 5. Robustness & quality (scored under "Technical execution")

- Agent rules from ARCHITECTURE: verdict = `DrugChecker`; validate every reply; emergency keywords bypass the LLM;
  log every fallback.
- Every network call: timeout, offline state, deterministic fallback.
- Unit tests (Hypium, `app/scripts/test.sh`, no device): `DrugChecker`, `AlarmRules`, `ResponseValidator`,
  emergency pre-filter. Results shown in README.
- Strict ArkTS; only the permissions actually used; no secrets in the repo (backend URL/key in gitignored
  `LocalConfig.ets`).

## 6. Demo (3 min) — from IDEA

1. Hook: "Hundreds of everyday drugs can stop the heart of 1 in 2,000 people."
2. Agent: "I've got a sinus infection, the doctor gave me this" → photo of box (clarithromycin) → 🔴 known risk →
   explanation + question for the doctor (F-02, F-05..07).
3. "Celia, can I take ondansetron?" → our intent answers without opening the app (F-11).
4. Watch / simulated LQT2 scenario spikes → watch buzzes → agent checks in → "I feel dizzy" → emergency mode
   (F-08..10, F-13).
5. Robustness: model returns garbage → deterministic fallback (F-03, tests in repo).
6. Close: on-device data, open platform, condition packs next.

## 7. Build order

Follows the checkpoints in [`PLAN.md`](PLAN.md): T+2h skeleton on emulator + Supabase + agent "hello" → T+6h
vertical slice (chat → `check_drug` → verdict card; simulated alert) → T+10h OCR, emergency, RDB onboarding, watch
decision → T+14h intents, proactive agent, tests green → T+16h feature freeze → T+18h video + `.hap` release →
T+20h docs (`AI_WORKFLOW.md`, `AI_FEATURES.md`) + submission.

## 8. Backlog — ideas not in the plan

Collected during brainstorming; **not planned**. Pull one in only after the P0 freeze-check, and add it to IDEA /
ARCHITECTURE first.

Barcode scan (Scan Kit) · combo check vs my meds (≥2 QT drugs, CYP3A4 inhibitors) · SOS countdown with "I'm OK" ·
bystander mode with CPR metronome · AED finder · local emergency number by country · offline QR on the card ·
sick-day / travel modes · beta-blocker reminders · QTc log · genotype-specific tips · privacy ledger ·
family screening leaflet.
