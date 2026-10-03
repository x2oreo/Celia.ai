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

**Data rule:** the deterministic core works offline and its data (profile, meds, ICE contacts, chats, events) lives
in the on-device encrypted RDB, which the UI always reads. Optional cloud paths, all listed in `AI_FEATURES.md` §3:

- Accounts (Supabase Auth, email + password over HTTPS, `account/AuthClient.ets`). The session is stored in the
  encrypted RDB (`account/Session.ets`); with a stored session the app opens signed in with no network, even with an
  expired token, and refreshes when it can. Only the server rejecting the refresh token signs out.
- Account backup: profile + medicines as one JSON document in `public.profiles` (one row per user, RLS
  `auth.uid() = user_id` for select/insert/update/delete, nothing for anon). Last-write-wins on the document time
  (newer of `Profile.updatedAt` and the last medicine change), pushed/pulled at sign-in, at launch and after edits
  (`account/ProfileSync.ets`). Medicines ride in the same document as the profile: one round trip, one policy set,
  one timestamp. Deleted from Settings → Account (row only; the auth user stays). Requests carrying personal fields
  must name a `PersonalDataException` (`privacy/Ledger.ets`): only `ACCOUNT_AUTH` and `PROFILE_SYNC` exist.

- Supabase: the watch app uploads `watch_metrics` rows keyed by a device id (heart rate, alerts, symptoms, doses
  taken, falls, wear state, simulated vitals, and an `sos` row with location when allowed). The phone writes
  `watch_context` (genotype, last risky medicine and time) and reads the metrics back.
- OpenAI, through our Edge Functions: `/agent` context and the last 12 chat messages, voice audio, a downscaled box
  photo. Live voice opens a WebSocket straight to OpenAI with a 2-minute secret.
- Never uploaded in the clear by either app without an account: name, phone numbers, contacts, notes. With an
  account they go only to the user's own `profiles` row (above).

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
`start_emergency`, `share_emergency_card`, `start_new_chat`, `log_symptom`, `prepare_doctor_visit`, `get_dose_status`, `get_trends`
(the last three are read-only and return fixed content from `doctor/DoctorPrep.ets`, `reminders/DoseSchedule.ets` and
`vitals/Trends.ets`). Write tools only create confirm cards (`log_symptom` writes the on-device symptom log directly; red flags start SOS by rule). Responses are validated in the app
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
| Watch HR / alarms / notifications | `@kit.WearEngine` (not wired: needs AGC approval) → instead the Celia watch app via Supabase | `vitals/WatchCloudSource.ets`, `vitals/WearNotifier.ets`, `vitals/WatchContextSync.ets` | ⚠️ Wear Engine not wired. With the cloud backend the phone reads `watch_metrics_latest` and writes `watch_context` (genotype + risky drug → watch verdict glance); otherwise `SimulatedSource` (labelled SIMULATED) and phone notification + haptic. Wear Engine: ❌ phones in the Chinese mainland only, no emulator support; cloud relay is the production path in Europe (`docs/research/phone-watch-link.md`) |
| On-device OCR of medicine boxes | `@kit.CoreVisionKit` (+ `/vision-extract` names-only fallback) | `drugs/OcrService.ets`, `agent/MedicineScanFlow.ets` | ⚠️ verify early |
| System assistant entry | Intents Kit (`@kit.AbilityKit` `@InsightIntentEntry`) | `insightintents/` (7 intents: CheckDrugSafety, ShowEmergencyCard, LogSymptom, TakeDose, ShowPharmacyCard, AddMedication, ReadEmergencyCard) | ⚠️ built and compiled; Celia routing needs a real device with Celia/Xiaoyi |
| Agent-to-agent (stretch) | `@kit.AgentFrameworkKit` | `agentextability/` | ⚠️ ask mentors |
| Home widgets | Form Kit | `widget/`, `entryformability/` | ✅ built — four cards: check (2×2), alert (2×4), "How are you feeling?" (2×2, opens the diary), medical ID (`renderingMode: "autoColor"`, home and lock screen; lock-screen placement unverified: no lock-screen editing on the emulator) |
| Online drug check (optional) | `@kit.NetworkKit` → Supabase `/drug-check` | `drugs/DrugCheckClient.ets`, `common/Net.ets`, `backend/supabase/` | ✅ offline-first; only for names the bundle does not know, logged in the privacy ledger. Tier 2 (RxNav + openFDA label QT rule) covers medicines outside the curated list |
| Local DB | `@kit.ArkData` RDB (`encrypt: true`) | `data/LocalStore.ets` | ✅ verified |
| Notifications / call | `@kit.NotificationKit`, `call.makeCall` (dialer) | `common/Notify.ets`, `common/Dialer.ets` | ✅ verified |
| Voice (push-to-talk) | `@kit.CoreSpeechKit` + `@kit.AudioKit` (cloud STT/TTS fallback) | `voice/` | ⚠️ Core Speech en-US unverified; cloud path works anywhere with network |
| Voice (hands-free) | OpenAI Realtime over `@kit.NetworkKit` WebSocket + AudioKit | `voice/RealtimeSession.ets` | ✅ needs network + mic |
| SOS location (F-28) | `@kit.LocationKit` | `emergency/SosService.ets` | ⚠️ permission flow verified; emulator has no fix → message says "location unknown" |
| Card QR (F-30) | ArkUI `QRCode` → short encrypted link (`/card/#<id>.<key>`, Supabase `share` + Vercel viewer); offline/no backend → legacy link with the card in the `#fragment` (GitHub Pages viewer kept for old QRs) | `emergency/CardLink.ets`, `share/`, `pages/EmergencyPage.ets`, `pages/CardViewPage.ets`, `site/card/` | ✅ both kinds open in the app's scanner and on any phone camera (13 languages, incl. call/footer wording) |
| SOS message (F-28) | `@kit.ShareKit` system share sheet | `common/Share.ets` | ✅ — direct SMS needs `SEND_MESSAGES` (system apps only), so the user sends via SMS/messenger/e-mail |
| Live View (F-35, B13) | `@kit.LiveViewKit` | `emergency/LiveStatus.ets`, `emergency/SosLiveText.ets` | ⚠️ runs on the emulator (system timer, capsule, end card). Real phone: Chinese mainland only, and an AGC scenario request (no scenario fits an SOS countdown; `TIMER` is for tool apps). Falls back to an ongoing notification. See `docs/research/live-view.md` |
| Box barcode (F-36) | `@kit.ScanKit` (system scan UI, album allowed) | `drugs/BarcodeService.ets`, `drugs/Gs1.ets`, `drugs/GtinCatalog.ets`, `rawfile/gtin_pl.json` | ✅ real Polish boxes offline (URPL register, ≈68k packs, loads in ~80 ms); other countries via online `/box-identify` (registries first, AI web search last, user confirms) or on-device "teach this barcode"; demo GTINs (prefix 200) kept |
| Dose reminders (F-38) | `@kit.BackgroundTasksKit` reminderAgentManager | `reminders/ReminderService.ets` | ⚠️ system refuses with 1700002 until the agent-reminder quota is granted in AGC; fallback: in-app notification while the app runs + Today view |
| Read card aloud (F-42) | `@kit.CoreSpeechKit` textToSpeech (en) + cloud `/speak` (other languages) | `emergency/CardSpeech.ets`, `voice/VoiceOutput.ets` (`say`), `pages/EmergencyPage.ets` | ⚠️ cloud path works with network; on-device en-US voice unverified on the emulator; button hidden when neither works. Medical part only, never name/contacts |
| Nearby ER / AED (F-43) | Fallback: map search link (`openLink`, Google Maps URLs, no key) — full Map Kit + Site Kit needs an AGC Map key | `emergency/NearbyHelp.ets`, Emergency → Nearby help | ✅ fallback; the app sends no location (the map app/browser uses its own) |
| Travel mode (F-40) | `@kit.LocationKit` reverse geocoding (only when location is already allowed) | `emergency/TravelService.ets`, Home banner, `pages/PharmacyCardPage.ets` | ⚠️ emulator has no location fix → no banner; logic unit-tested |
| App lock (F-45) | `@kit.UserAuthenticationKit` | `common/AppLock.ets`, `components/LockScreen.ets` | ⚠️ needs a screen lock on the device; without one the switch stays off (no lock-out) |
| Push (B12) | Push Kit (`pushService.getToken`) + Huawei Push server API (service-account JWT) | `account/PushToken.ets`, `EntryAbility.handlePushTap`, `backend/supabase/functions/sos/huaweiPush.ts` | ⚠️ phones: Chinese mainland only (Huawei docs). Token registration + sender built from `docs/research/push-kit.md`; the emulator gets no token (`1000900010 Illegal application identity`, no AGC project); watch SOS reaches contacts by the `sos` function and the open app by polling |
| NFC card tag (B14) | `@ohos.nfc.tag` (reader mode, NDEF write) | `emergency/NfcCard.ets` | ⚠️ built, unverified; the action is hidden on the emulator (no `SystemCapability.Communication.NFC.Tag`) |
| Accounts (B1, B2) | Supabase Auth over `@kit.NetworkKit` (no supabase-js) | `account/`, `common/Net.ets` | ⚠️ built; live sign-up needs migration `20261004100000` and "Confirm email" off. HUAWEI ID (Account Kit, B18) is available in Poland and on the emulator but not built; bridge function design in `docs/research/account-kit.md` |

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

## Workstream B (accounts, emergency, onboarding, notifications/SOS, doctor visits, watch, research)

From the stream notes in `docs/workflow/b-*.md`. Pending migrations and deploys: `docs/handoff/B_DEPLOY.md`.

### Accounts, SOS contacts, RLS by account (S1: B1, B2, B10, B9)

- Decision: medicines ride in the same `profiles.data` document as the profile (`{v: 1, profile, meds[]}`): one
  round trip, one RLS policy set, one timestamp. A newer `v` than the app knows is ignored, never half-applied.
- Last-write-wins is decided on the phone after reading the account copy; `updated_at` is the local edit time, not
  the upload time. Two phones editing offline at once: the later edit wins on both.
- Local data that was last synced with another account (setting `sync_owner`) is never pushed: the account copy is
  pulled if one exists, otherwise nothing is uploaded. Known limit: in that case the new user's edits stay local until
  they wipe the phone data (Account → Sign out and delete) or their account has a copy.
- Sign-out keeps local data unless "Sign out and delete" is chosen. "Delete my data from my account" deletes the
  `profiles` row and signs out (so the next edit does not upload it again); the `auth.users` row stays (no safe
  self-delete RPC yet).
- Settings → "Clear all data" (existing, not this stream's) wipes the stored session too; the in-memory session lives
  until the app restarts.
- "Set up without an account" exists because sign-up needs a network and the card must work from the first launch.

- Phase 2 deviation: I could not merge `georgi/b-watch` into this branch (blocked), so the watch half of B9 is a
  patch file instead of commits (applied to the watch at the integration merge).
- B9 trade-off: a watch that never paired can still upload under its random id with the public key (nobody can read
  those rows back); once it has a secret, uploads need it. The demo watch stays public on purpose.
- Pairing a watch now needs an account: an unbound watch's data could not be read by anyone.

Deploy order for B9 (migrations `20261004100000`..`100300`): `docs/handoff/B_DEPLOY.md`.

### Emergency profile, first-responder view, NFC (S2: B4, B5, B14)

- Profile read path: `LocalStore.loadAll` → `parseStoredProfile` (defaults). Every screen that edits a profile must
  copy it with `cloneProfile` (keeps all fields). `SettingsPage.save` now starts from the stored profile.
  **S3:** the onboarding rewrite must not build a fresh `Profile` that drops the B4 fields.
- Card payload versions: v1 and v2 readable forever (`READABLE_VERSIONS`). New fields go in a new version.
- The responder view and the card honour `hiddenOnCard` everywhere they can be seen without unlocking.
- Responder opens with no network request: it reads only `LocalStore`, the bundled dataset and `DrugChecker`.

### Onboarding (S3: B3)

- **One draft, steps kept alive.** `OnboardingPage` holds a single `Profile` draft (`@Local`) plus the consent flag.
  Step components take `@Param profile` and hand back a new copy with `@Event onChange` (the same contract as
  `EmergencyDetailsForm`). All eight steps are built once and hidden with `visibility(None)` except the current one,
  so half-typed fields (a contact, the AuthForm email) survive Back. Saved once, on Finish (`finalProfile` trims
  text, drops an ICD model without an ICD and an invalid birth date). Medicines are saved by `AddMedForm` as they are
  added, as before.
- `withDetails(draft, fromForm)` takes only the B4 fields (+ `notes`) from `EmergencyDetailsForm`'s output, so the
  form can never overwrite genotype, contacts or country.
- Finish and the returning-user path call `navStack.clear()` (lands on the tabs, also when the Welcome page sits
  under onboarding). Back on step 1 pops only when the page below is `Routes.WELCOME`; otherwise it is swallowed so
  the app is never entered without a profile.
- Returning user: after `AuthForm` reports `onDone(true)`, the page reads `LocalStore.getProfile()`; a profile there
  (restored by S1's ProfileSync) ends onboarding. S1 must restore **before** calling `onDone(true)`.
- `validPhone` moved to `onboarding/OnboardingFlow.ets`; `OnboardingPage` re-exports it so `SettingsPage` is
  unchanged.
- The old final step's free-text "notes for paramedics" field is gone from onboarding; it belongs to the
  emergency-details editor (S2). If S2's form has no notes field, the coordinator should add it there.
- Location is no longer asked silently after Finish (old behaviour); it is asked in step 7 with its reason.

### Notifications, SOS, Live View, Push (S4: B7, B8, B13, B12)

- Notification buttons always open the app (`START_ABILITY` WantAgent with `notifyAction`, `notifyKind`,
  `notifyId`, `reminderId` in the want parameters); `EntryAbility.handleNotifyTap` acts, then routes through
  `RouteRequest` / `TabRequest` (works on cold start). Background actions are not possible for a third-party app
  (no static common-event subscribers in the public SDK).
- Watch SOS: watch countdown → `sos` row → `WatchCloudSource.toAlert` sets `watchSos` → `Index.onAlert` →
  `SosController.watchSent` (no phone countdown, starts the 10-min cooldown) → SOS page in sent state. A phone
  countdown still running for the same event turns into the watch-sent state.
- Contacts are not alerted by the server today (no synced contacts, no Twilio secrets: `sos` function runs dry).
  When B10 lands, replace the static "TO WHOM" text with the `sos_dispatches` status.

- Live View: one start, system timer, no update loop; `isLiveViewEnabled()` false or an error → ongoing
  notification every 5 s (B7 buttons). The payload is validated before the permission, so a wrong payload looks like
  "not available"; LiveStatus logs `code message`.
- Push: watch `sos` row → `sos` function → `watch_pairings.user_id` (B9) → `push_tokens` → Huawei Push
  (`push-api.cloud.huawei.com/v3/<project>/messages:send`, JWT) → notification id 1004 → tap → `parsePushTap` →
  `SosController.watchSent` → SOS page. Without the binding the function records `push.status:
  no_account_binding` and pushes nothing: it never guesses a recipient.
- Third-party: `npm:jose@5` (JWT signing in the `sos` function, and in its test). List in README + AI_WORKFLOW
  (Challenge Rules §4). `rawfile/sos_live.png` is generated by a script in this session (no third-party asset).

### Doctor visits and feeling diary (S5: B6, B15)

- Visits: JSON list under the encrypted RDB setting `doctor_visits`; no schema change. A checked AI summary is
  stored with its visit and re-checked with `parseSummary` before display.
- What leaves the phone for a visit summary: the same fields as before plus `reason` and `worries`, after
  `redactPersonal` (patterns + the profile's own names, numbers, e-mails, hospital as literal strings, whole-word,
  any script). The server scrubs patterns again. Free-text names of people not in the profile (e.g. "my aunt Ewa")
  are not detectable by rules and can still pass; the caption on the form says what is removed. Field names pass
  `FORBIDDEN_FIELDS` and show in the ledger.
- Diary: `AppEvent` kind `FEELING`, detail `{mood, note}`; notes never leave the phone and are not in the brief
  (only mood counts).

### Watch internals and energy (S6: B16)

- Watch controller = façade + five units (`watch/README.md` → *Code map*). The screens only read
  `WatchController` fields and call its methods; the units are `@ObservedV2` where the screens read their state
  (`SosFlow`, `PairingFlow`, `SyncEngine`, `HeartRules`) and plain classes otherwise (`SensorHub`).
- Energy: accelerometer 25/10 Hz policy, one outbox write per sync (≤ 3 s of rows at risk on a crash), one rcp
  session for the app's lifetime.
- Background monitoring: not possible for a third-party watch app without approvals; see `watch/README.md` *Background
  monitoring on a real watch* (production design + needs list).

### Platform research (S7: B12, B13, B17, B18, B11)

Capability-table wording from the research (applied to the table above; the Live View row also reflects S4, which
later ran Live View on the emulator):
- Push Kit (B12): "⚠️ phones: Chinese mainland only (Huawei docs). Token registration + sender built from
  `docs/research/push-kit.md`; watch SOS reaches contacts by the `sos` function and the open app by polling."
- Live View (F-35): "⚠️ Chinese mainland only, and an AGC scenario request (no scenario fits an SOS countdown);
  ongoing-notification fallback is what runs. See `docs/research/live-view.md`."
- Wear Engine: "❌ phones in the Chinese mainland only, no emulator support; cloud relay is the production path in
  Europe (`docs/research/phone-watch-link.md`)."
- Account Kit (B18): "available in Poland and on the emulator; bridge function design in `docs/research/account-kit.md`."

#### B11: SOS voice call today

What `backend/supabase/functions/sos/twilio.ts` does today:
- Plain-fetch Twilio REST client, no SDK, 10 s timeout, Basic auth from `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN`,
  sender `TWILIO_FROM_NUMBER`; returns `null` config → the function records `dry_run` and sends nothing.
- `sendSms(to, body)`: one SMS (`Messages.json`) with the deterministic text from `message.ts` (who, what, LQTS +
  genotype, HR, recent symptom, last dose or missed dose, risky drug in the last 24 h, Google Maps link or "Location
  unknown", "Call 112 now. Tell paramedics: Long QT, avoid QT-prolonging drugs.").
- `placeCall(to, text)`: one outbound call (`Calls.json`) with inline TwiML: `<Say voice="alice" language="en-GB">`
  the voice text, `<Pause length="1"/>`, the same `<Say>` again. The voice text has no URLs and ends "Details and
  location were sent to you by text message."
- `index.ts` sends SMS + call to every contact (max 5, E.164 only) **in parallel**, with a 10 min per-device cooldown
  and a project-wide cap per hour (`SOS_GLOBAL_MAX_PER_HOUR`, default 10), and audits to `sos_dispatches` without
  phone numbers.

What it lacks:
1. **No delivery or answer tracking.** `ok` means Twilio accepted the request (got a SID), not that the SMS was
   delivered or the call answered. No `StatusCallback`, so `status = 'sent'` overstates what happened.
2. **No acknowledgement and no escalation.** Nobody can say "I'm on it" (no `<Gather>` / DTMF "press 1"); all
   contacts are rung at once; no retry or move to the next contact when a call is unanswered or busy.
3. **No answering-machine handling.** A voicemail picks up and records part of the message; no `MachineDetection`.
4. **One-way and fixed.** English (en-GB) only, no per-contact language, no way for the contact to ask anything
   (where, which hospital, what not to give). That is the gap a conversational agent would fill.
5. **Inert today.** No Twilio secrets, no `SOS_WEBHOOK_SECRET` / Vault secrets (`sos_function_url`,
   `sos_webhook_secret`), and nothing writes `emergency_contacts` or `watch_context.patient_name` (B10). A Twilio
   trial account also only reaches verified numbers.
6. **Abuse surface remains** until B9: contacts are keyed by `device_id` with an anon insert policy; the global cap
   limits cost, not targeting.

Reference received: the brief's "Cardbeat" is **Heartbeat / QTShield** (`x2oreo/heartbeat`, reviewed at `fc7d4b8`).
Its call is also one-way TwiML `<Say>`, so there is nothing conversational to port. Its spoken address, spoken
country ambulance number and voice-script ordering are worth re-implementing fresh. The design is in
`docs/research/sos-voice-call.md`: stage 1 honest one-way call (script, geocoded address, AMD, status callbacks),
stage 2 press-1 acknowledgement + escalation, stage 3 optional ConversationRelay with a closed intent set and
deterministic answers. Twilio attribute names were checked against Twilio's docs (2026-10-03).

### Contracts for Workstream A

#### Accounts, SOS contacts, RLS by account

- Routes: `welcome`, `auth` (param `AuthParam('SIGN_UP' | 'LOG_IN')`), `account`.
- `Session`: `isSignedIn()`, `userId()`, `userName()`, `email()`, `accessToken()` (may be expired offline),
  `signOut()`, `onChange(cb)`; new and safe to call: `Session.freshToken()` (refreshes first when due).
- `AuthForm`: `@Param mode`, `@Event onDone(signedIn)`, new optional `@Event onModeChange(mode)`.
- Requests made as the user: `accountTarget(await Session.freshToken())` from `common/Net.ets`.

#### Emergency profile, first-responder view, NFC

- Route `responder` (`Routes.RESPONDER`), no param. Use it for the agent tile and home quick action.
- **S4:** on the SOS page after the countdown, push `Routes.RESPONDER` with `null`. Nothing else needed.
- `EmergencyDetailsForm({ profile, onChange })` for onboarding (S3); it never saves.

#### Onboarding

- No new routes. Onboarding stays at `Routes.ONBOARDING`.
- For S1 (launch routing): Welcome → onboarding should push `Routes.ONBOARDING`; the account step is inside
  onboarding, so Welcome's "Get started" does not need its own sign-up page. A user who already signed in on
  `AuthPage` sees "Signed in as …" on step 2.

#### Notifications, SOS, Live View, Push

- No new routes. The SOS page pushes `Routes.RESPONDER` (S2's page).
- `notify(id, title, text, ongoing, reminderId?)` keeps its old signature; the id picks the kind
  (`common/NotifyAction.kindForId`). New ids: `NOTIFY_WATCH_SOS` 1004, doses `2000 + reminderId % 1000`.
- `SosParam` has a fourth argument `sentBy` ('PHONE' default | 'WATCH').

#### Doctor visits and feeling diary

- Routes: `visits` (saved visits), `feeling` (diary entry). `doctorPrep` with `new DoctorPrepParam(specialty)`
  works as before; `new DoctorPrepParam(specialty, visitId)` opens a saved visit.
- Trends: `DiaryStore.dailyCounts(days: number): Promise<DiaryDay[]>` (or pure
  `dailyCounts(events: AppEvent[], now: number, days: number): DiaryDay[]` from `diary/DailyCounts.ets`),
  `DiaryDay { day: 'YYYY-MM-DD'; feelings: number; lowFeelings: number; symptoms: number }`, one row per day,
  oldest first, same day key as `TrendDay.day`.

#### Watch internals and energy

- No route, screen, string or token changed. `WatchController`'s public fields and methods are the same, so screen
  restyling (Phase 2) can keep using `ctrl.<field>`.
- `AlertKind` now lives in `controller/HeartRules.ets`, `PairState` / `PairScreen` in `controller/PairingFlow.ets`,
  `SyncState` in `controller/SyncEngine.ets` (nothing imported them from `WatchController` at the time of the split).

#### Platform research

Nothing new. If the lock-screen medical ID widget is built (`live-view.md` §2), it is a third form in
`form_config.json` reading the same snapshot as `AlertCard`; its look follows DESIGN.md with no colour-only meaning
(lock-screen widgets render single-colour).

## Conventions

- **Strict ArkTS** (see `.claude/skills/arkts-language`): no `any`, no untyped object literals, no destructuring.
- Min/target **API 20** in `build-profile.json5` (task requirement).
- Branches: `kaloyan/*`, `georgie/*`, `mark/*` → merge to `main` often (≥ every 2–3 h). `main` must always build.
- Commits small and frequent (judges read history), Conventional Commits: `feat(agent): …`, `fix(vitals): …`.
- No secrets in repo: `.env` in `.gitignore`, backend URL + Supabase anon key in the gitignored `app/entry/src/main/ets/common/LocalConfig.ets`, created from
  `LocalConfig.example.ets` on first build — the anon key is public by design, LLM key never leaves Supabase secrets.
- Every AI-tool session: append prompt + outcome to `AI_WORKFLOW.md` (one line is fine).
