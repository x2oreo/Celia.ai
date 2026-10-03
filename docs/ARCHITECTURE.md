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
 │  Chat / Home      ───►   AgentCore                       VitalsSource           LocalStore (RDB)  │
 │  Med check               ├─ ToolRegistry  ──calls──►     ├─ WearEngineSource    profile, meds,    │
 │  Emergency               ├─ AgentClient (HTTP/SSE)       ├─ SimulatedSource     events, vitals,   │
 │  Vitals                  └─ ResponseValidator            └─ AlarmRules ──event──► EventBus        │
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
 │  Edge Function  /agent        → LLM tool-calling loop (Claude API key lives here only)           │
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
export type UiActionType = 'SHOW_VERDICT' | 'SHOW_EMERGENCY_CARD' | 'START_EMERGENCY' | 'OPEN_MED_SCAN' | 'ADD_MED';
export interface UiAction { type: UiActionType; payload: string; }   // payload = JSON string, parsed per type
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
```

## Backend API

`POST /functions/v1/drug-check` → `{ "query": "clarithromycin" }` →
`{ "query": "...", "ingredient": "clarithromycin", "risk": "KNOWN_RISK", "reason": "...", "source": "..." }`

`POST /functions/v1/agent` → request:
```json
{ "messages": [{ "role": "user", "text": "Can I take this?" }],
  "context": { "condition": "LQTS", "genotype": "LQT2", "meds": ["bisoprolol"], "vitals": "HR 72 resting, no alerts 24h" } }
```
response (validated in app by `ResponseValidator`; anything invalid → `fallback: true` deterministic reply):
```json
{ "text": "Clarithromycin is on the known-risk list…", "actions": [{ "type": "SHOW_VERDICT", "payload": "{...DrugVerdict}" }] }
```
Server-side tools in the loop: `check_drug` (DB lookup), `explain_condition` (static, curated text). Client context
is sent with each request, so the server never stores personal data. Auth: Supabase anon key + RLS (read-only on
drug tables); the LLM key is an Edge Function secret. Timeouts: app 20 s → fallback.

## Agent design rules (Kaloyan, applies everywhere)

1. Verdict = `DrugChecker` result. Model may only *explain* it. If model text contradicts verdict → drop model text.
2. Validate every reply against `AgentReply` schema; unknown action types dropped; parse error → fallback.
3. Emergency keywords ("faint", "chest pain", "passed out", "can't breathe") → deterministic emergency path
   **before** calling the LLM.
4. Log (hilog) every fallback with reason — we show it in the demo and in tests.

## Platform capabilities we claim (keep this list honest — judges check the code)

| Capability | Kit | Where | Runs on emulator? |
|---|---|---|---|
| Watch HR / alarms / notifications | `@kit.WearEngine` | `vitals/WearEngineSource.ets` | ❌ real phone + watch (SimulatedSource on emulator) |
| On-device OCR of medicine boxes | `@kit.CoreVisionKit` | `drugs/OcrService.ets` | ⚠️ verify early |
| System assistant entry | Intents Kit (`@kit.AbilityKit`) | `insightintents/` | ⚠️ verify early |
| Agent-to-agent (stretch) | `@kit.AgentFrameworkKit` | `agentextability/` | ⚠️ ask mentors |
| Home widget | Form Kit | `widget/` | ✅ |
| Local DB | `@kit.ArkData` RDB | `data/` | ✅ |
| Notifications / call | `@kit.NotificationKit`, `call` | emergency | ✅ / partial |
| Voice (stretch) | `@kit.CoreSpeechKit` | agent | ⚠️ check English support |
| SOS location (F-28) | `@kit.LocationKit` | `emergency/` | ⚠️ simulated location on emulator |
| Card QR (F-30) | ArkUI `QRCode` | emergency | ✅ |
| SOS SMS (F-28) | Telephony `sms` / SMS composer Want | `emergency/` | ⚠️ verify — direct send likely system-only |

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
```

## Conventions

- **Strict ArkTS** (see `.claude/skills/arkts-language`): no `any`, no untyped object literals, no destructuring.
- Min/target **API 20** in `build-profile.json5` (task requirement).
- Branches: `kaloyan/*`, `georgie/*`, `mark/*` → merge to `main` often (≥ every 2–3 h). `main` must always build.
- Commits small and frequent (judges read history), Conventional Commits: `feat(agent): …`, `fix(vitals): …`.
- No secrets in repo: `.env` in `.gitignore`, backend URL + Supabase anon key in the gitignored `app/entry/src/main/ets/common/LocalConfig.ets`, created from
  `LocalConfig.example.ets` on first build — the anon key is public by design, LLM key never leaves Supabase secrets.
- Every AI-tool session: append prompt + outcome to `AI_WORKFLOW.md` (one line is fine).
