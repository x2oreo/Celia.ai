# AI features — Celia.ai

Celia.ai's agent is decision support for people with congenital Long QT syndrome (LQTS). It is **not a medical device**.
The app's main design rule is that **verdicts come from deterministic data and the AI only explains them.**

## 1. What the AI does

| Feature | AI involved | Deterministic part |
|---|---|---|
| Chat agent ("Can I take Klacid?") | OpenAI model chooses tools and writes the explanation | Verdict from `DrugChecker` (curated list) + `ComboRules` (interactions) |
| Emergency detection | **none** | `SafetyGate` regex (EN/PL) runs before any model call |
| Proactive heart-rate check-in | **none** | Vitals alert → fixed message → 60 s without answer → emergency countdown |
| Offline / failure mode | **none** | `OfflineAgent` pattern intents + templated verdict text |
| Medicine photo | On-device OCR (Core Vision); fallback `/vision-extract` reads **names only** (strict JSON schema, low-confidence dropped) | Every name → `DrugChecker`; user confirms the drug before any verdict |
| Push-to-talk voice | Core Speech ASR/TTS on device (en-US) or `/transcribe` + `/speak` (OpenAI) | Transcript goes through the same `SafetyGate` → agent → validator path as text |
| Hands-free voice | OpenAI Realtime (speech-to-speech) via a 2-minute client secret from `/realtime-session` | Same on-device tools; input transcripts pass `SafetyGate`; a streaming check of the model's words cancels any reassurance about a medicine and speaks the deterministic verdict instead |
| Celia system assistant | none | Intents `CheckDrugSafety` / `ShowEmergencyCard` call the deterministic paths directly |

## 2. Model and inference flow

- **Model:** OpenAI Responses API, called from a Supabase Edge Function in the EU region (`backend/supabase/functions/agent`).
  Models (all overridable via secrets):

  | Use | Model | Why |
  |---|---|---|
  | Agent (`/agent`) | `gpt-6.1-sol`, reasoning effort `low` | Sol is the middle tier. In our own benchmark (5 agent tasks, 2 runs) it routed tools correctly 9/10 times at about 2.1–2.4 s per step. Its explanations passed the validator, matching Astra at lower cost. |
  | Photo name reading (`/vision-extract`) | `gpt-6.1-sol` | Same model, with a strict JSON schema. |
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

**Voice and vision data:** with on-device Core Speech and Core Vision, audio and photos stay on the phone. In the
cloud fallbacks, audio (push-to-talk or a Realtime session) and a downscaled box photo go to OpenAI through our Edge
Functions or the Realtime WebSocket. They are not stored by us, and our logs record only sizes and timings.

## 3. Data that leaves the device

Only this de-identified context is sent to `/agent`:

- the condition (`LQTS`)
- the genotype
- the **ingredient names** of current medicines
- a one-line heart-rate summary
- the local emergency number
- the locale
- recent chat text

It never sends names, phone numbers, emergency contacts or device IDs. Request validation in `_shared/validate.ts`
rejects anything outside that shape.

The relay uses `previous_response_id` within a turn, so OpenAI keeps the response under its standard API retention.
Personal data (profile, medicines, contacts, events) stays in on-device storage.

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

Tests: `app/entry/src/test/AgentSafety.test.ets` and `AgentCore.test.ets` cover the interaction rules, the emergency
gate, the validator, offline intents, tool-schema parity with the backend, and the offline end-to-end path.

## 5. Limitations

- The interaction rules (`ComboRules`) are a simplified, hand-curated subset: additive QT, a few CYP inhibitor–substrate
  pairs, and three or more QT drugs. They are not a full clinical interaction checker.
- Verdict quality depends on the curated drug list (`DrugChecker`, owned by Mark). A drug that isn't in the list is
  reported as unknown, never as safe.
- Wrist heart rate is not an ECG. The app never interprets QT or rhythm.
- The emergency keyword gate is broad on purpose, so false alarms are possible; they cost one tap on Cancel.
- The model's explanations can still be imperfect. The validator catches contradictions, not every inaccuracy.
- In Realtime voice the model speaks before a full-text check is possible. The streaming check usually cuts a bad
  sentence before it plays, but a few words may already have been heard before the correction.
- Core Speech English support and Celia's routing of third-party intents are unverified on the emulator and outside
  China. Both have fallbacks: cloud speech, and the in-app agent.
