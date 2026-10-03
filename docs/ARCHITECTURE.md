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

**Data rule:** the deterministic core works offline and its data (profile, meds, ICE contacts, chats, events) is
stored only in the on-device encrypted RDB. Optional cloud paths, all listed in `AI_FEATURES.md` §3:

- Supabase: the watch app uploads `watch_metrics` rows keyed by a device id (heart rate, alerts, symptoms, doses
  taken, falls, wear state, simulated vitals, and an `sos` row with location when allowed). The phone writes
  `watch_context` (genotype, last risky medicine and time) and reads the metrics back.
- OpenAI, through our Edge Functions: `/agent` context and the last 12 chat messages, voice audio, a downscaled box
  photo. Live voice opens a WebSocket straight to OpenAI with a 2-minute secret.
- Never uploaded in the clear by either app: name, phone numbers, contacts, notes.

Known limit: watch rows are protected by a shared anon key plus the device id, not per-user auth (see README).

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
export interface ChatMessage { role: 'user' | 'assistant'; text: string; ts: number; actions?: UiAction[]; }
// model/Chat.ets — saved chats (LocalStore tables chats + chat_messages, schema v2)
export interface ChatSummary { id: number; title: string; createdAt: number; updatedAt: number; messageCount: number; }
export type UiActionType = 'SHOW_VERDICT' | 'SHOW_EMERGENCY_CARD' | 'START_EMERGENCY' | 'OPEN_MED_SCAN' | 'ADD_MED'
  | 'SHARE_EMERGENCY_CARD' | 'QUICK_REPLIES' | 'SHOW_MEDS' | 'SHOW_ALTERNATIVES';
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
listChats / createChat / listChatMessages / addChatMessage / renameChat / deleteChat   (≤ 50 chats × 200 messages)
// vitals/VitalsService.ets         (Mark)
start(source: 'WATCH' | 'SIMULATED') / stop() / onSample(cb) / onAlert(cb) / runScenario(name: string)
// agent/AgentCore.ets              (Kaloyan — Georgie's chat UI calls it)
send(text: string): Promise<AgentReply>
onProactive(cb: (reply: AgentReply) => void)   // triggered by VitalsAlert
resolveAction(actionId: string, accepted: boolean): Promise<AgentReply>   // confirm-card tap (ADD_MED, SHARE_…)
emergencyCancelled(): void                     // user cancelled the START_EMERGENCY countdown
newChat() / openChat(id) / deleteChat(id)      // chats; every message is saved to the open chat
currentChatId(): number / onChatChanged(cb)    // -1 = new chat without messages yet
```

## Backend API

`/functions/v1/share` — end-to-end encrypted links for the emergency card and the doctor report (deploy with
`--no-verify-jwt`). The phone encrypts the JSON with a fresh AES-256-GCM key (`share/ShareCrypto.ets`) and uploads only
ciphertext; blobs live in the private Storage bucket `shares`, readable only by the function's service key.
`POST {kind:'card'|'report', ciphertext}` → `{id, revokeToken, expiresAt}` (report: 48 h, card: until revoked; needs the
project's publishable key, fails closed) · blobs at `shares/card/<id>.json` and `shares/report/<id>.json`, expired
reports swept on every create ·
`GET ?id=` → `{kind, ciphertext, expiresAt}` (open: CORS `*`, 404 gone, 410 expired) · `DELETE {id, revokeToken}` (key + token).
Deployed: project `jxiggumhircfuhianmel`. `share` runs with JWT checking off (anonymous viewers); `agent`,
`transcribe`, `speak`, `vision-extract`, `realtime-session` run with JWT checking on (the app sends the anon JWT).
`OPENAI_API_KEY` is a Supabase secret. The app's `LocalConfig.ets` (gitignored) holds the URL and public keys.
Links: `https://<viewer>/card/#<id>.<key>` and `/report/#<id>.<key>`; the key after `#` never reaches a server.
Viewer pages are static (`site/`, Vercel) because Supabase rewrites HTML responses to `text/plain`.

`POST /functions/v1/drug-check` → `{ "query": "clarithromycin" }` →
`{ "query": "...", "ingredient": "clarithromycin", "risk": "KNOWN_RISK", "reason": "...", "source": "...",
"method": "LIST" | "FDA_LABEL" | "NONE", "confidence": 0..1, "snippet": "..." }`. Deterministic, no AI:
- **Tier 1** — each word against the curated `drugs` / `drug_aliases` tables (same data as the app bundle).
- **Tier 2** — words tier 1 does not know: NLM RxNav name → ingredient(s) (exact match; fuzzy only when the name
  starts with what was typed) → curated list again (via aliases, so US names like `acetaminophen` hit `paracetamol`)
  → otherwise the openFDA label QT rule (`_shared/labelRisk.ts`): QT/torsades wording in the boxed warning →
  KNOWN_RISK, in warnings/precautions → POSSIBLE_RISK, only in side effects/interactions → CONDITIONAL_RISK, label
  without it → NOT_LISTED at confidence 0.6. Worst of up to 5 labels wins; combination products take their worst
  ingredient. The label never says "safe". Results are cached in `label_cache` for 30 days (service-role writes,
  public read); upstream errors are never cached and leave the verdict UNKNOWN_DRUG.
- The app (`drugs/DrugCheckClient.ets`) shows the label sentence as a `LABEL` step in "How we know" and caps online
  confidence at 0.9, below the curated list.
- Multi-word names go to RxNav as one phrase first ("ascorbic acid", "sodium valproate" → valproate); salts map to the
  base ingredient. A 4.3 s budget answers UNKNOWN_DRUG in time for the app's 5 s timeout and finishes the lookup in
  the background so the next check hits `label_cache`.

`POST /functions/v1/box-identify` — a barcode the phone does not know (any country) → brand + English ingredients.
Never a verdict: after the user confirms, the app runs the usual `CheckService` check on the ingredients.
- `{gtin, stage:'fast'}` → `box_cache` (~0.3 s) → in parallel, awaited in trust order: openFDA label by UPC (US),
  AEMPS CIMA by Código Nacional (Spain, `847000…`), UPCitemdb, Open Food/Products/Beauty Facts. Ingredients are
  normalised through RxNav; foreign INN text ("VALPROATO SODIO") is translated by the LLM and kept only if RxNav
  resolves it. Names nothing resolves are passed on (listed in `unresolved`), so the check says UNKNOWN for them.
- `{gtin, stage:'deep', hint}` (only after a fast miss) → OpenAI web search, strict JSON, must cite an https page
  among its own search citations, LOW confidence dropped, ingredients RxNav-validated. Skipped without an API key.
- `{gtin, action:'confirm', brand}` → counts a user confirmation. AI_WEB rows are served from the cache only after
  one; registry rows at once.
- → `{found, candidate?:{gtin, brand, ingredients[], unresolved[], strength, form, country,
  method:'CACHE'|'REGISTRY'|'PRODUCT_DB'|'AI_WEB', source, sourceUrl, confirmations}, hint?, ms}`.
- App: `drugs/BoxIdentifyClient.ets` (validated parse), `components/BoxCandidateSheet.ets` ("Is this your box?"),
  `pages/ScanPage.ets` (fast → deep → teach form), confirmed boxes stored on the phone as `BoxSource 'ONLINE'`.

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
`start_emergency`, `share_emergency_card`, `start_new_chat`, `log_symptom`, `prepare_doctor_visit`, `get_dose_status`
(the last two are read-only and return fixed content from `doctor/DoctorPrep.ets` and `reminders/DoseSchedule.ets`). Write tools only create confirm cards (`log_symptom` writes the on-device symptom log directly; red flags start SOS by rule). Responses are validated in the app
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
| Watch HR / alarms / notifications | `@kit.WearEngine` (not wired: needs AGC approval) → instead the Celia watch app via Supabase | `vitals/WatchCloudSource.ets`, `vitals/WearNotifier.ets`, `vitals/WatchContextSync.ets` | ⚠️ Wear Engine not wired. With the cloud backend the phone reads `watch_metrics_latest` and writes `watch_context` (genotype + risky drug → watch verdict glance); otherwise `SimulatedSource` (labelled SIMULATED) and phone notification + haptic |
| On-device OCR of medicine boxes | `@kit.CoreVisionKit` (+ `/vision-extract` names-only fallback) | `drugs/OcrService.ets`, `agent/MedicineScanFlow.ets` | ⚠️ verify early |
| System assistant entry | Intents Kit (`@kit.AbilityKit` `@InsightIntentEntry`) | `insightintents/` (7 intents: CheckDrugSafety, ShowEmergencyCard, LogSymptom, TakeDose, ShowPharmacyCard, AddMedication, ReadEmergencyCard) | ⚠️ built and compiled; Celia routing needs a real device with Celia/Xiaoyi |
| Agent-to-agent (stretch) | `@kit.AgentFrameworkKit` | `agentextability/` | ⚠️ ask mentors |
| Home widgets | Form Kit | `widget/`, `entryformability/` | ✅ built — two cards: check (2×2) and alert (2×4) |
| Online drug check (optional) | `@kit.NetworkKit` → Supabase `/drug-check` | `drugs/DrugCheckClient.ets`, `common/Net.ets`, `backend/supabase/` | ✅ offline-first; only for names the bundle does not know, logged in the privacy ledger. Tier 2 (RxNav + openFDA label QT rule) covers medicines outside the curated list |
| Local DB | `@kit.ArkData` RDB (`encrypt: true`) | `data/LocalStore.ets` | ✅ verified |
| Notifications / call | `@kit.NotificationKit`, `call.makeCall` (dialer) | `common/Notify.ets`, `common/Dialer.ets` | ✅ verified |
| Voice (push-to-talk) | `@kit.CoreSpeechKit` + `@kit.AudioKit` (cloud STT/TTS fallback) | `voice/` | ⚠️ Core Speech en-US unverified; cloud path works anywhere with network |
| Voice (hands-free) | OpenAI Realtime over `@kit.NetworkKit` WebSocket + AudioKit | `voice/RealtimeSession.ets` | ✅ needs network + mic |
| SOS location (F-28) | `@kit.LocationKit` | `emergency/SosService.ets` | ⚠️ permission flow verified; emulator has no fix → message says "location unknown" |
| Card QR (F-30) | ArkUI `QRCode` → short encrypted link (`/card/#<id>.<key>`, Supabase `share` + Vercel viewer); offline/no backend → legacy link with the card in the `#fragment` (GitHub Pages viewer kept for old QRs) | `emergency/CardLink.ets`, `share/`, `pages/EmergencyPage.ets`, `pages/CardViewPage.ets`, `site/card/` | ✅ both kinds open in the app's scanner and on any phone camera (13 languages, incl. call/footer wording) |
| SOS message (F-28) | `@kit.ShareKit` system share sheet | `common/Share.ets` | ✅ — direct SMS needs `SEND_MESSAGES` (system apps only), so the user sends via SMS/messenger/e-mail |
| Live View (F-35) | `@kit.LiveViewKit` | `emergency/LiveStatus.ets` | ⚠️ needs scenario approval in AGC; falls back to an ongoing notification (used on the emulator) |
| Box barcode (F-36) | `@kit.ScanKit` (system scan UI, album allowed) | `drugs/BarcodeService.ets`, `drugs/Gs1.ets`, `drugs/GtinCatalog.ets`, `rawfile/gtin_pl.json` | ✅ real Polish boxes offline (URPL register, ≈68k packs, loads in ~80 ms); other countries via online `/box-identify` (registries first, AI web search last, user confirms) or on-device "teach this barcode"; demo GTINs (prefix 200) kept |
| Dose reminders (F-38) | `@kit.BackgroundTasksKit` reminderAgentManager | `reminders/ReminderService.ets` | ⚠️ system refuses with 1700002 until the agent-reminder quota is granted in AGC; fallback: in-app notification while the app runs + Today view |
| Read card aloud (F-42) | `@kit.CoreSpeechKit` textToSpeech (en) + cloud `/speak` (other languages) | `emergency/CardSpeech.ets`, `voice/VoiceOutput.ets` (`say`), `pages/EmergencyPage.ets` | ⚠️ cloud path works with network; on-device en-US voice unverified on the emulator; button hidden when neither works. Medical part only, never name/contacts |
| Nearby ER / AED (F-43) | Fallback: map search link (`openLink`, Google Maps URLs, no key) — full Map Kit + Site Kit needs an AGC Map key | `emergency/NearbyHelp.ets`, Emergency → Nearby help | ✅ fallback; the app sends no location (the map app/browser uses its own) |
| Travel mode (F-40) | `@kit.LocationKit` reverse geocoding (only when location is already allowed) | `emergency/TravelService.ets`, Home banner, `pages/PharmacyCardPage.ets` | ⚠️ emulator has no location fix → no banner; logic unit-tested |
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
// AlertKind gains: 'IRREGULAR_RHYTHM' | 'HRV_DROP' | 'HIGH_HR_EXERTION' | 'RESTING_HR_RISE' (multi-day, BetaBlockerWatch); VitalsAlert gains severity: 'INFO' | 'WARN' | 'CRITICAL'

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
