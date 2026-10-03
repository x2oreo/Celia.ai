# Architecture — big picture

Read this first. It defines **who owns what** and the **contracts between parts**, so we can build in parallel
without blocking each other. Change a contract → tell the team on Discord + update this file in the same commit.

## System diagram

```
 ┌──────────────── Huawei watch (GT5 Pro / GT6 Pro) ────────────────┐
 │  HR / PPG / ECG sensors · HR alarm · wear status · notifications  │
 └───────────────▲──────────────────────────────┬───────────────────┘
                 │ notify (alert on wrist)      │ sensor + monitor events
                 │                              ▼   (Wear Engine Kit, real device only)
 ┌──────────────────────────── HarmonyOS phone app (ArkTS / ArkUI, API 20+) ─────────────────────────┐
 │                                                                                                   │
 │  UI (Georgie)            Agent (Kaloyan)                 Vitals (Mark)          Data (Mark)       │
 │  ─────────────           ────────────────                ───────────────        ──────────────    │
 │  Chat / Home      ───►   AgentCore (runs the tool loop)  VitalsSource           LocalStore (RDB)  │
 │  Med check               ├─ SafetyGate (pre-LLM)         ├─ WearEngineSource    profile, meds,    │
 │  Emergency               ├─ ToolRegistry  ──calls──►     ├─ SimulatedSource     events, vitals,   │
 │  Vitals                  ├─ AgentClient (HTTP)           └─ AlarmRules ──event──► EventBus        │
 │                          ├─ ResponseValidator · OfflineAgent · ComboRules                         │
 │  Onboarding/Profile                                                                               │
 │  Widget (Form Kit)       DrugChecker (deterministic) ◄── used by tools, UI, intents               │
 │                          OcrService (Core Vision)                                                 │
 │                                                                                                   │
 │  System entry points (Kaloyan): InsightIntents (Celia) · AgentExtensionAbility (A2A, stretch)     │
 └───────────────────────────────────────────┬───────────────────────────────────────────────────────┘
                                             │ HTTPS (no secrets in the app)
 ┌───────────────────────────── Backend: Supabase, EU region (Mark: DB, Kaloyan: agent fn) ──────────┐
 │  Postgres: drugs, drug_aliases, drug_risk (curated LQTS list), agent_logs (de-identified)        │
 │  Edge Function  /drug-check   → deterministic lookup (name/alias/INN → risk)                     │
 │  Edge Function  /agent        → one OpenAI model step; tools run in the app (key lives here only) │
 └───────────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Data rule (sovereignty pitch):** personal data (profile, meds, ICE contacts, vitals, events) is stored **only in
on-device RDB**. Backend receives: drug names, and for `/agent` a minimal context (condition, genotype, med names,
latest vitals summary) — **no name, phone numbers, or IDs**. Write this into `AI_FEATURES.md`.

**Offline rule:** `DrugChecker` ships a **bundled copy** of the curated drug list (`rawfile/drugs.json`) and works
offline. `/drug-check` is the online/fresh path; app falls back to the bundle on error/timeout.

## Ownership

| Area | Owner | Folder |
|---|---|---|
| App shell, navigation, all screens, design, widget, onboarding | **Georgie** | `app/entry/src/main/ets/pages`, `components`, `widget` |
| Agent: AgentCore, tools, prompt, `/agent` function, Intents, A2A, voice, AI docs | **Kaloyan** | `app/.../agent`, `app/.../insightintents`, `backend/supabase/functions/agent` |
| Database, drug data, `/drug-check`, LocalStore, Wear Engine / vitals, alarm rules | **Mark** | `backend/supabase/migrations`, `data/`, `app/.../data`, `app/.../vitals` |
| Shared models (`model/`), README, AI_WORKFLOW.md, demo video | **All** (Kaloyan coordinates) | `app/.../model`, root |

## Repo layout (target)

```
Celia.ai/
├─ README.md                 # setup / build / install / launch (judges read this)
├─ AI_WORKFLOW.md            # REQUIRED: tools, prompts, workflow, validation, lessons
├─ AI_FEATURES.md            # REQUIRED for AI features: model, flow, data, limits, validation, privacy
├─ app/                      # DevEco Studio project (HarmonyOS, API 20+)
│  └─ entry/src/main/
│     ├─ ets/
│     │  ├─ entryability/EntryAbility.ets
│     │  ├─ pages/           # Georgie
│     │  ├─ components/      # Georgie
│     │  ├─ model/           # shared types (contracts below)
│     │  ├─ agent/           # Kaloyan: AgentCore, tools, client, validator
│     │  ├─ drugs/           # Mark+Kaloyan: DrugChecker, OcrService
│     │  ├─ vitals/          # Mark: VitalsSource, WearEngineSource, SimulatedSource, AlarmRules
│     │  ├─ data/            # Mark: LocalStore (RDB), migrations
│     │  ├─ common/          # EventBus, Logger, Config
│     │  ├─ insightintents/  # Kaloyan
│     │  ├─ emergency/       # SOS, Live View status, card speaker, nearby (F-27..F-43)
│     │  ├─ reminders/       # dose reminders (F-38)
│     │  ├─ bystander/       # bystander mode + CPR metronome (F-41)
│     │  ├─ privacy/         # privacy ledger (F-46)
│     │  └─ widget/          # Georgie (Form Kit)
│     ├─ resources/rawfile/drugs.json   # bundled drug list (generated from data/)
│     └─ module.json5
│  └─ entry/src/test/ + ohosTest/       # unit tests (DrugChecker, AlarmRules, ResponseValidator)
├─ backend/supabase/
│  ├─ migrations/            # Mark
│  ├─ seed.sql               # Mark (generated from data/)
│  └─ functions/{drug-check,agent}/
├─ data/                     # Mark: curated CSV + script → seed.sql + drugs.json
└─ docs/                     # this folder
```

## Shared contracts (put in `app/entry/src/main/ets/model/`, strict ArkTS — classes/interfaces, no `any`)

```ts
// model/Profile.ets
export type Genotype = 'LQT1' | 'LQT2' | 'LQT3' | 'UNKNOWN';
export interface Contact { name: string; phone: string; relation: string; }
export interface Profile {
  condition: 'LQTS';            // only LQTS in MVP; packs later
  genotype: Genotype;
  hasIcd: boolean;              // implanted defibrillator
  notes: string;                // free text for emergency card
  contacts: Contact[];
}

// model/Medication.ets
export interface Medication { id: number; name: string; ingredient: string; dose: string; addedAt: number; }

// model/DrugVerdict.ets
export type RiskLevel = 'KNOWN_RISK' | 'POSSIBLE_RISK' | 'CONDITIONAL_RISK' | 'NOT_LISTED' | 'UNKNOWN_DRUG';
export interface DrugVerdict {
  query: string;                // what the user typed / OCR text
  ingredient: string;           // resolved INN, '' if unknown
  risk: RiskLevel;
  reason: string;               // short deterministic reason from the dataset
  source: string;               // e.g. 'Curated from CredibleMeds categories (cited)'
}

// model/Vitals.ets
export interface VitalsSample { ts: number; hr: number; source: 'WATCH' | 'SIMULATED'; }
export type AlertKind = 'TACHY_AT_REST' | 'BRADY' | 'HR_ALARM_FROM_WATCH' | 'WATCH_DISCONNECTED';
export interface VitalsAlert { ts: number; kind: AlertKind; hr: number; message: string; }

// model/AgentTypes.ets
export interface ChatMessage { role: 'user' | 'assistant'; text: string; ts: number; }
export type UiActionType = 'SHOW_VERDICT' | 'SHOW_EMERGENCY_CARD' | 'START_EMERGENCY' | 'OPEN_MED_SCAN' | 'ADD_MED'
  | 'SHARE_EMERGENCY_CARD' | 'QUICK_REPLIES';
export interface UiAction { type: UiActionType; payload: string; }   // payload = JSON string; payload interfaces
                                                                       // (VerdictCardPayload, AddMedPayload, …) in the file
export interface AgentReply { text: string; actions: UiAction[]; fallback: boolean; }
```

Services each owner exposes (stub them on day 1 so others can call them immediately):

```ts
// drugs/DrugChecker.ets            (Mark — Kaloyan's tools + Georgie's UI + intents call it)
check(query: string): Promise<DrugVerdict>
// drugs/OcrService.ets             (Kaloyan)
recognize(pixelMap: image.PixelMap): Promise<string>
// data/LocalStore.ets              (Mark)
getProfile / saveProfile / listMeds / addMed / removeMed / logEvent / listEvents
// vitals/VitalsService.ets         (Mark)
start(source: 'WATCH' | 'SIMULATED') / stop() / onSample(cb) / onAlert(cb) / runScenario(name: string)
// agent/AgentCore.ets              (Kaloyan — Georgie's chat UI calls it)
send(text: string): Promise<AgentReply>
onProactive(cb: (reply: AgentReply) => void)   // triggered by VitalsAlert
resolveAction(actionId: string, accepted: boolean): Promise<AgentReply>   // confirm-card tap (ADD_MED, SHARE_…)
emergencyCancelled(): void                     // user cancelled the START_EMERGENCY countdown
```

## Backend API

`POST /functions/v1/drug-check` → `{ "query": "clarithromycin" }` →
`{ "query": "...", "ingredient": "clarithromycin", "risk": "KNOWN_RISK", "reason": "...", "source": "..." }`

`POST /functions/v1/agent` — **one model step** (OpenAI Responses API). The tool loop runs **in the app**
(`AgentCore`): the function returns tool calls, the app executes them on-device and calls again with the outputs.
Full contract: `backend/supabase/functions/README.md`.
```json
{ "context": { "condition": "LQTS", "genotype": "LQT2", "meds": ["nadolol"], "vitals": "HR 72 at rest, no alerts (simulated)",
               "emergencyNumber": "112", "locale": "en-PL" },
  "messages": [{ "role": "user", "text": "Can I take Klacid?" }],
  "continuation": null }
→ { "promptVersion": "…", "responseId": "resp_…", "toolCalls": [{ "callId": "…", "name": "check_drug", "arguments": "{…}" }], "text": "" }
```
Tools (schemas in `_shared/tools.ts`, executors in `app/.../agent/tools/`): `check_drug`, `get_my_meds`,
`get_vitals_summary`, `explain_condition`, `suggest_alternatives`, `scan_medicine`, `add_med`, `show_emergency_card`,
`start_emergency`, `share_emergency_card`. Write tools only create confirm cards. Responses are validated in the app
(`ResponseValidator`); anything invalid → `fallback: true` deterministic reply. Auth: Supabase anon key; the OpenAI
key is an Edge Function secret. Timeouts: app 20 s per step → fallback.

## Agent design rules (Kaloyan, applies everywhere)

1. Verdict = `DrugChecker` result. Model may only *explain* it. If model text contradicts verdict → drop model text.
2. Validate every reply against `AgentReply` schema; unknown action types dropped; parse error → fallback.
3. Emergency keywords ("faint", "chest pain", "passed out", "can't breathe") → deterministic emergency path
   **before** calling the LLM.
4. Log (hilog) every fallback with reason — we show it in the demo and in tests.

## Platform capabilities we claim (keep this list honest — judges check the code)

| Capability | Kit | Where | Runs on emulator? |
|---|---|---|---|
| Watch HR / alarms / notifications | `@kit.WearEngine` | `vitals/VitalsService.ets`, `vitals/WearNotifier.ets` | ❌ not wired yet — `SimulatedSource` (labelled SIMULATED); wrist alerts fall back to phone notification + haptic |
| On-device OCR of medicine boxes | `@kit.CoreVisionKit` (+ `/vision-extract` names-only fallback) | `drugs/OcrService.ets`, `agent/MedicineScanFlow.ets` | ⚠️ verify early |
| System assistant entry | Intents Kit (`@kit.AbilityKit`) | `insightintents/` | ⚠️ verify early |
| Agent-to-agent (stretch) | `@kit.AgentFrameworkKit` | `agentextability/` | ⚠️ ask mentors |
| Home widget | Form Kit | `widget/` | ⏸ not built yet |
| Online drug check (optional) | `@kit.NetworkKit` → Supabase `/drug-check` | `drugs/DrugCheckClient.ets`, `common/Net.ets`, `backend/supabase/` | ✅ offline-first; only for names the bundle does not know, logged in the privacy ledger |
| Local DB | `@kit.ArkData` RDB (`encrypt: true`) | `data/LocalStore.ets` | ✅ verified |
| Notifications / call | `@kit.NotificationKit`, `call.makeCall` (dialer) | `common/Notify.ets`, `common/Dialer.ets` | ✅ verified |
| Voice (push-to-talk) | `@kit.CoreSpeechKit` + `@kit.AudioKit` (cloud STT/TTS fallback) | `voice/` | ⚠️ Core Speech en-US unverified; cloud path works anywhere with network |
| Voice (hands-free) | OpenAI Realtime over `@kit.NetworkKit` WebSocket + AudioKit | `voice/RealtimeSession.ets` | ✅ needs network + mic |
| SOS location (F-28) | `@kit.LocationKit` | `emergency/SosService.ets` | ⚠️ permission flow verified; emulator has no fix → message says "location unknown" |
| Card QR (F-30) | ArkUI `QRCode` | `pages/EmergencyPage.ets` | ✅ |
| SOS message (F-28) | `@kit.ShareKit` system share sheet | `common/Share.ets` | ✅ — direct SMS needs `SEND_MESSAGES` (system apps only), so the user sends via SMS/messenger/e-mail |
| Live View (F-35) | `@kit.LiveViewKit` | `emergency/LiveStatus.ets` | ⚠️ needs scenario approval in AGC; falls back to an ongoing notification (used on the emulator) |
| Box barcode (F-36) | `@kit.ScanKit` (system scan UI, album allowed) | `drugs/BarcodeService.ets`, `drugs/Gs1.ets` | ✅ parsing + demo GTINs (GS1 prefix 200, not real products); typing the number also works |
| Dose reminders (F-38) | `@kit.BackgroundTasksKit` reminderAgentManager | `reminders/ReminderService.ets` | ⚠️ system refuses with 1700002 until the agent-reminder quota is granted in AGC; fallback: in-app notification while the app runs + Today view |
| Read card aloud (F-42) | `@kit.CoreSpeechKit` textToSpeech | — | ⏸ deferred (AI/voice — out of scope for the non-AI build) |
| Nearby ER / AED (F-43) | `@kit.MapKit` + Site Kit | — | ⏸ deferred (needs an AGC Map key) |
| App lock (F-45) | `@kit.UserAuthenticationKit` | `common/AppLock.ets`, `components/LockScreen.ets` | ⚠️ needs a screen lock on the device; without one the switch stays off (no lock-out) |

## Proposed contracts — feature expansion (F-19..F-34)

**Proposed, not final** — confirm with the owner, then move into "Shared contracts" and `model/`. Tasks:
[`TASKS.md`](TASKS.md).

```ts
// model/DrugVerdict.ets (additions, Mark)
export type ComboKind = 'NONE' | 'ADDITIVE_QT' | 'CYP_INTERACTION';
export interface ComboVerdict { kind: ComboKind; drugs: string[]; enzyme: string; reason: string; }
export interface LookupStep { step: string; matched: boolean; detail: string; }  // 'BUNDLED_EXACT' | 'ALIAS' | 'ONLINE' ...
// DrugVerdict gains: confidence: number; trace: LookupStep[]; alternatives: string[]; combo?: ComboVerdict

// model/ScanRecord.ets (Mark + Georgi)
export interface ScanRecord { id: number; ts: number; via: 'CHAT' | 'TEXT' | 'PHOTO' | 'INTENT'; verdict: DrugVerdict; }

// model/Vitals.ets (additions, Mark) — all optional, SimulatedSource fills all
// VitalsSample gains: hrv?, rrMs?, restingHr?, stress?, asleep?, irregular?, steps?
// AlertKind gains: 'IRREGULAR_RHYTHM' | 'HRV_DROP'; VitalsAlert gains severity: 'INFO' | 'WARN' | 'CRITICAL'

// model/SosEvent.ets (Kaloyan + Mark)
export interface SosEvent { ts: number; trigger: 'VITALS' | 'BUTTON' | 'KEYWORD'; test: boolean;
  lat: number; lon: number; results: string; }   // results = JSON per contact/channel

// model/Profile.ets (additions) — Profile.country: string (ISO2); Contact.email: string ('' if none)

// model/GtinEntry.ets (F-36, Mark)
export interface GtinEntry { gtin: string; product: string; ingredient: string; country: string; source: string; }

// model/DoseReminder.ets (F-38)
export type DoseStatus = 'DUE' | 'TAKEN' | 'SNOOZED' | 'MISSED';
export interface DoseReminder { id: number; medId: number; hour: number; minute: number; reminderId: number; }
export interface DoseLog { ts: number; medId: number; status: DoseStatus; }

// model/SymptomEntry.ets (F-44) — produced by the LLM, validated; invalid → raw text only
export type Symptom = 'DIZZINESS' | 'PALPITATIONS' | 'FAINTING' | 'CHEST_PAIN' | 'SHORTNESS_OF_BREATH' | 'OTHER';
export interface SymptomEntry { ts: number; symptom: Symptom; activity: string; severity: number; note: string;
  hrMin: number; hrMax: number; }   // severity 1..5; HR window ±10 min, -1 if no data

// model/LedgerEntry.ets (F-46) — field NAMES only, never values
export interface LedgerEntry { ts: number; endpoint: string; fields: string[]; bytes: number; }
```

## Conventions

- **Strict ArkTS** (see `.claude/skills/arkts-language`): no `any`, no untyped object literals, no destructuring.
- Min/target **API 20** in `build-profile.json5` (task requirement).
- Branches: `kaloyan/*`, `georgie/*`, `mark/*` → merge to `main` often (≥ every 2–3 h). `main` must always build.
- Commits small and frequent (judges read history), Conventional Commits: `feat(agent): …`, `fix(vitals): …`.
- No secrets in repo: `.env` in `.gitignore`, backend URL + Supabase anon key in the gitignored `app/entry/src/main/ets/common/LocalConfig.ets`, created from
  `LocalConfig.example.ets` on first build — the anon key is public by design, LLM key never leaves Supabase secrets.
- Every AI-tool session: append prompt + outcome to `AI_WORKFLOW.md` (one line is fine).
