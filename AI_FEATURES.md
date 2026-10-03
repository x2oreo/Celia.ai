# AI features — Celia.ai

Celia.ai's agent is decision support for people with congenital Long QT syndrome (LQTS). It is **not a medical device**.
The app's main design rule is that **verdicts come from deterministic data and the AI only explains them.**

## 1. What the AI does

| Feature | AI involved | Deterministic part |
|---|---|---|
| Chat agent ("Can I take Klacid?"), Agent tab | OpenAI model chooses tools and writes the explanation | Verdict from `CheckService` (same path as the check screen: curated dataset, barcode, online fallback) + interactions from `ComboRules` ∪ `DrugChecker.checkCombo`; the chat renders the verdict card from this data, never from model text |
| Emergency detection | **none** | `SafetyGate` regex (EN/PL) runs before any model call |
| Proactive heart-rate check-in | **none** | Vitals alert → fixed message → 60 s without answer → SOS countdown screen. Critical alerts go straight to the SOS screen |
| Offline / failure mode | **none** | `OfflineAgent` pattern intents + templated verdict text |
| Unknown box barcode (any country) | Only when registries and product databases miss: OpenAI web search for the barcode (`/box-identify` deep stage, strict JSON, must cite a page it opened); and translation of foreign ingredient names to English INNs | Registries first (openFDA, AEMPS CIMA, UPCitemdb, Open Facts). Every ingredient must resolve in NLM RxNav or the check says UNKNOWN for it. The user confirms "Is this your box?"; the verdict then comes from `CheckService` (curated list → FDA label rule). AI finds are cached for others only after a user confirmed them |
| Medicine photo | On-device OCR (Core Vision); fallback `/vision-extract` reads **names only** (strict JSON schema, low-confidence dropped) | Every name → `DrugChecker`; user confirms the drug before any verdict |
| Medicine explanation ("Explain it in plain words" in the medicine sheet) | Optional `/med-info`: the model writes a plain summary, what's in it, what it's for and up to 3 everyday tips (strict JSON schema). It is told never to talk about QT/heart safety or doses | Curated facts (`drugs/DrugInfo.ets`) and the risk badge/interactions (`DrugDataset`, `DrugChecker`) are shown without AI and never change. The reply is validated twice (backend + `MedInfoClient.parseMedInfo`: types, lengths, banned words like QT/torsade/mg doses) and is shown under an `AI SUMMARY` badge; anything off is dropped and the sheet keeps the curated data. Cached on the phone |
| Push-to-talk voice | Core Speech ASR/TTS on device (en-US) or `/transcribe` + `/speak` (OpenAI) | Transcript goes through the same `SafetyGate` → agent → validator path as text |
| Hands-free voice | OpenAI Realtime (speech-to-speech) via a 2-minute client secret from `/realtime-session` | Same on-device tools; input transcripts pass `SafetyGate`; a streaming check of the model's words cancels any reassurance about a medicine and speaks the deterministic verdict instead |
| Celia system assistant | none | Intents `CheckDrugSafety`, `ShowEmergencyCard`, `LogSymptom`, `TakeDose`, `ShowPharmacyCard`, `AddMedication`, `ReadEmergencyCard` call the deterministic paths directly (no LLM) |
| Chat history and new chats | Optional: the model may call `start_new_chat` (with a name the user gave) | Chats are saved on the phone (encrypted RDB) message by message. Short commands ("new chat", "start over", "save this chat") are matched on device after `SafetyGate`, so they work offline. Reopened chats keep display cards only (verdict, medicines, alternatives, emergency card); confirm, quick-reply and SOS cards are dropped |
| Symptom logging in chat (T27) | Optional: the model may call `log_symptom` with an enum symptom, severity 1–5, activity and a few of the user's words | Symptom enum and severity are validated on the phone; the heart-rate window (±10 min) is attached on the phone; a red-flag symptom (fainting, chest pain, severe breathlessness) starts the SOS countdown by rule (`isRedFlag`), not by the model. Unknown symptom → error back to the model, nothing logged |
| Doctor brief summary (T13) | Optional `/doctor-summary`: 2–3 sentences atop the brief | The brief itself is deterministic and complete. The model gets only the brief's medicine lines with their risk words, interactions, flagged checks and counts — never the Patient section, notes, contacts or symptom notes. Output checked on server and phone: 20–420 chars, no "safe / harmless / no risk", no doses, no start/stop advice → otherwise dropped and the brief stands alone. Shown under `AI SUMMARY` |
| Read the emergency card aloud (T25) | Cloud `/speak` (TTS) for non-English cards or when no on-device voice exists | Text is the pre-translated card (`CardStrings`), built by `emergency/CardSpeech.ets`: medical part only, never name, contacts or notes |
| Emergency hand-off | **none** | Any agent emergency (typed, spoken, unanswered check-in) opens the app's SOS countdown; the agent quotes the same ambulance number and countdown that screen uses |

## 2. Model and inference flow

- **Model:** OpenAI Responses API, called from a Supabase Edge Function in the EU region (`backend/supabase/functions/agent`).
  Models (all overridable via secrets):

  | Use | Model | Why |
  |---|---|---|
  | Agent (`/agent`) | `gpt-6.1-sol`, reasoning effort `low` | Sol is the middle tier. In our own benchmark (5 agent tasks, 2 runs) it routed tools correctly 9/10 times at about 2.1–2.4 s per step. Its explanations passed the validator, matching Astra at lower cost. |
  | Photo name reading (`/vision-extract`) | `gpt-6.1-sol` | Same model, with a strict JSON schema. |
  | Medicine explanation (`/med-info`) | `gpt-6.1-sol`, reasoning `low` | Short structured text; the same model keeps the stack to one family. |
  | Doctor brief summary (`/doctor-summary`) | `gpt-6.1-sol`, reasoning `low` | 2–3 sentences in a strict JSON schema; same family as the agent. |
  | Speech-to-text (`/transcribe`) | `gpt-transcribe` | Supports `keywords`, which biases recognition toward medicine names (Klacid, ondansetron…). |
  | Text-to-speech (`/speak`) | `gpt-4o-mini-tts`, voice `marin` | Outputs PCM directly; the voice style can be set with instructions. |
  | Hands-free voice | `gpt-realtime-2.1` | The newest Realtime reasoning model, with better tool precision and alphanumeric recognition. `gpt-realtime-2.1-mini` is the cost switch. | The prompt is versioned (`PROMPT_VERSION` in
  `_shared/prompt.ts`) and the version is logged with every call.
- **Agent loop runs on the phone.** The Edge Function is a stateless relay that does one model step per call. The app
  (`AgentCore`) executes each tool call locally, then sends the result back. The loop is capped at 5 steps per turn.

```
user ─► SafetyGate ──(red flag)──────────────────────────────► emergency countdown (no AI)
          │
          └─► /agent step ─► tool calls ─► ToolRegistry on device ─► /agent step … ─► final text
                                │                                                     │
                     DrugChecker + ComboRules                                  ResponseValidator
                     LocalStore · VitalsDigest                     ok ─► reply   │   invalid ─► deterministic text
                     confirm cards for writes                                   │
any network error / timeout (20 s) / malformed response ─────────────────────► OfflineAgent fallback
```

**Voice on the emulator:** the emulator has no microphone. With `DEMO_VOICE_INPUT = 'on'` (`LocalConfig.ets`) a live
session streams a bundled clip into the same audio buffer the microphone feeds (`voice/DemoVoice.ets`), so voice
detection, transcription, the safety gate and the tools run for real; only the sound source is simulated, and the
screen says `SIMULATED VOICE INPUT`. Verified on the emulator with "Can I take ondansetron?" → Known-risk card.

**Voice and vision data:** with on-device Core Speech and Core Vision, audio and photos stay on the phone. In the
cloud fallbacks, audio (push-to-talk or a Realtime session) and a downscaled box photo go to OpenAI through our Edge
Functions or the Realtime WebSocket. They are not stored by us, and our logs record only sizes and timings.

## 3. Data that leaves the device

Only this context is sent to `/agent` (no name, contacts or notes; it does include health facts such as the
genotype):

- the condition (`LQTS`)
- the genotype
- the **ingredient names** of current medicines
- a one-line heart-rate summary
- the local emergency number
- the locale
- recent chat text (the last 12 messages of the open chat only — other saved chats are never sent)

`/med-info` receives only a medicine name and its active ingredient, through the privacy-ledger path
(`common/Net.ets`), and only when the user taps "Explain it in plain words".

`/doctor-summary` receives only the specialty, genotype, the brief's medicine lines with risk words, interactions,
flagged checks (date + medicine) and two counts, and only when the user taps "Summarise for the doctor".
`/speak` for the card receives only the card's medical text (no name, contacts or notes).

Every AI call (`/agent`, `/transcribe`, `/speak`, `/vision-extract`, `/realtime-session`, `/med-info`,
`/doctor-summary`) and the opening of a live-voice socket appear in the privacy ledger ("What left my phone") with
field names and size, never values; a request with a personal top-level field (name, phone, email, contacts, notes,
address, location) is blocked before it is sent (`BackendClient` / `Net`).

The AI paths never send names, phone numbers, emergency contacts or device IDs. (Separately, and only when the user taps
"Send report link" or opens the card QR, the card/report is uploaded **encrypted on the phone** to `/share`; the server
stores ciphertext only and the key stays in the link — no AI is involved in that path.) Request validation in `_shared/validate.ts`
rejects anything outside that shape.

The relay uses `previous_response_id` within a turn, so OpenAI keeps the response under its standard API retention.
The profile, contacts, notes and saved chats stay in on-device storage (beyond the fields listed above).

**Not AI, but also leaves the devices:** when a watch is linked, the watch app uploads its readings to our Supabase
project as `watch_metrics` rows keyed by a device id (heart rate, alerts, symptoms, doses taken, falls, wear state,
simulated vitals, and an `sos` row with location when allowed). The phone writes `watch_context` (genotype, last
risky medicine and time) so the watch can tighten its limits, and reads the metrics back. The phone's requests show
in the ledger; the watch app has no ledger of its own. These rows are guarded by a shared anon key plus the device
id, not per-user auth — a known limit of this build.

## 4. Validation of model output (`app/.../agent/ResponseValidator.ets`)

1. **Schema:** the relay response must match `{responseId, text, toolCalls[]}`. Otherwise the app uses the fallback.
2. **Tools:** unknown tool names are dropped twice, on the server and on the device. Arguments must be a JSON
   object. Executor errors go back to the model as `{error}` and never crash the turn.
3. **Verdict consistency:** after a verdict, the final text is replaced with deterministic wording when it:
   - reassures about a medicine ("is safe", "fine to take", "no risk", "jest bezpieczny"), whether or not a verdict
     was produced. Negations ("is not safe") and denials ("that does not mean it is safe") don't count;
   - leaves out the risk for a KNOWN, POSSIBLE or CONDITIONAL verdict;
   - fails to send the user to a pharmacist for an unknown drug.

   Text is normalised before matching (lower case, typographic apostrophes → `'`), because the model and phone
   keyboards write "it’s" and "can’t". The same normalisation runs in `SafetyGate`. The checks cover English and Polish.
4. **The verdict card is the source of truth.** Every `check_drug` call attaches a `SHOW_VERDICT` card that is built
   from the deterministic result, whatever the text says.
5. **Writes need a tap.** `add_med` and `share_emergency_card` only create confirm cards, and nothing is saved without
   the user. `start_emergency` shows a cancellable 10 s countdown.
6. **Logging:** every fallback is logged to hilog (`CeliaAI/AgentCore`) and as an `AGENT_FALLBACK` event.
7. **Demo switch:** `AgentClient.forceGarbage` corrupts the model response so the fallback can be shown live.

Tests: `app/entry/src/test/AgentSafety.test.ets` (incl. `LogSymptom`), `DoctorPrep.test.ets` (`DoctorSummary`), `MedInfo.test.ets` and `AgentCore.test.ets` cover the interaction rules, the emergency
gate, the validator, offline intents, tool-schema parity with the backend, and the offline end-to-end path.

## 5. Limitations

- The interaction rules (`ComboRules` and `DrugChecker.checkCombos`, both reading the one enzyme table in
  `DrugDataset`) are a simplified, hand-curated subset: additive QT, CYP inhibitor–substrate pairs (3A4, 2D6,
  2C19), and three or more QT drugs. Medicines resolved online have no enzyme data, so only additive QT applies. They are not a full clinical interaction checker.
- Verdict quality depends on the curated drug list (`DrugChecker`, owned by Mark). A drug that isn't in the list is
  reported as unknown, never as safe.
- Wrist heart rate is not an ECG. The app never interprets QT or rhythm.
- The emergency keyword gate is broad on purpose, so false alarms are possible; they cost one tap on Cancel.
- The model's explanations can still be imperfect. The validator catches contradictions, not every inaccuracy.
- In Realtime voice the model speaks before a full-text check is possible. The streaming check usually cuts a bad
  sentence before it plays, but a few words may already have been heard before the correction.
- Core Speech English support and Celia's routing of third-party intents are unverified on the emulator and outside
  China. Both have fallbacks: cloud speech, and the in-app agent.
