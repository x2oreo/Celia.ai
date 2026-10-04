# SOS voice call to emergency contacts (B11)

> Status (4 Oct 2026): stage 1 is built (`sos/twilio.ts` places a one-way call that reads the alert). Stages 2 and 3 are not built. Without Twilio secrets the `sos` function records a dry run.

Design for brief task B11, after reviewing the team's earlier project **Heartbeat / QTShield**
([x2oreo/heartbeat](https://github.com/x2oreo/heartbeat), commit `fc7d4b8`), which the brief calls "Cardbeat". Written
so whoever owns `backend/supabase/functions/sos/` (S4) can implement it stage by stage. Researched 2026-10-03 against
Twilio's docs (ConversationRelay, `<Gather>`, Answering Machine Detection, Call resource) and Supabase's Edge Function
docs. Nothing is copied from Heartbeat. If code from it is ever reused, list it in README + `AI_WORKFLOW.md`
(Challenge Rules §4).

## What exists

**Celia today** (`backend/supabase/functions/sos/twilio.ts`, `message.ts`, `index.ts`): Twilio SMS + one outbound
call per contact (max 5, all in parallel). The call is inline TwiML reading a fixed English message twice
(`<Say voice="alice" language="en-GB">`). There is a 10 min per-device cooldown and a project-wide cap per hour,
an audit row in `sos_dispatches`, and a dry run without secrets. Gaps (also in `docs/workflow/b-research.md`):
no delivery or answer tracking, no acknowledgement, no escalation, no voicemail handling, English only, no address
in the call, and it does nothing until the secrets and B10 contacts exist.

**Heartbeat** (`src/services/sos-notifier.ts`, `src/services/notifications/voice.ts`): the call is **also one-way**:
`<Say voice="alice">` twice with a 2 s pause, through the Twilio Node SDK, fired in parallel with SMS and email
(`Promise.allSettled` per contact). So there is no conversational agent to port. What Heartbeat does better and is
worth re-implementing fresh:

| Heartbeat idea | Where | Celia today |
|---|---|---|
| Voice script ordered "WHO → WHAT → HOW BAD → WHERE → MEDICAL CONTEXT", "first 10 seconds must convey the critical info", critical part repeated at the end | `composeVoiceMessage` | Message read twice in full |
| **Spoken address**: reverse geocoding with Nominatim (no key, 4 s timeout, "Geocoding failure must NEVER break SOS delivery") so the contact hears where to go without opening the SMS | `notifications/geocoding.ts` | Voice says "location was sent by text" |
| **Country-specific ambulance number** from the geocoded country (e.g. PL ambulance `999`, general `112`), spoken digit by digit ("1 1 2") so text-to-speech doesn't read "one hundred twelve" | `data/country-emergency-numbers.ts`, `spokenDigits` | Fixed "112", read as a number |
| Current QT-relevant medicines named in the call (top 3) | `composeVoiceMessage` | Only a risky drug from the last 24 h |
| Email channel (Resend) next to SMS and voice | `notifications/email.ts` | none |
| Test SOS endpoint that returns the composed SMS, voice and email text plus per-channel results | `triggerTestSOS` | dry-run row only |

Facts to re-check before copying any of them: emergency numbers must come from an official source cited in our
code (the EU's 112 page or national regulators), not from Heartbeat's table. Nominatim's usage policy requires a
descriptive User-Agent and at most 1 request per second.

## Design, in three stages

Each stage ships on its own and keeps the previous behaviour as the fallback. Facts spoken or sent always come from
deterministic code (`message.ts`, the profile, `drugs/DrugDataset.ets`-derived data). No LLM writes medical content.

### Stage 1: honest one-way call (small, no new services)

1. **Script** (`message.ts`, pure, unit-tested): reorder to who → what → where → what to do → medical context, then
   repeat who + where + number. Add the spoken address when geocoding succeeds, the ambulance number for the
   location's country digit by digit (with 112 as the EU default), and up to 3 current QT-relevant medicines.
   Keep the SMS unchanged plus the address line.
2. **Reverse geocoding** (`sos/geocode.ts`): Nominatim reverse, 4 s timeout, returns `null` on any error, never
   blocks the alert. The SOS is the only caller.
3. **Answering machine detection** on `Calls.json`: `MachineDetection=DetectMessageEnd` so a voicemail gets the full
   message after the beep instead of a cut-off one. `AnsweredBy` arrives in the status callback.
4. **Status callback**: `StatusCallback=<sos-status function URL>`, `StatusCallbackEvent=initiated ringing answered
   completed`. The handler checks Twilio's request signature (`X-Twilio-Signature`, HMAC-SHA1 of URL + sorted params
   with the auth token) and writes per-contact `call_status` (`answered`, `no-answer`, `busy`, `failed`) and
   `answered_by` into a new `sos_attempts` table. `sos_dispatches.status = 'sent'` then means "every call was answered
   or every SMS delivered", not "Twilio accepted the request". Add `StatusCallback` on SMS too
   (`delivered` / `undelivered`).
5. **Show it on the phone** (B10's RPC reading `sos_dispatches`): "Anna: call answered 12:04. Marek: no answer, SMS
   delivered."

### Stage 2: acknowledgement and escalation (still no AI)

1. Wrap the message in `<Gather input="dtmf speech" numDigits="1" action="<sos-ack URL>" timeout="6">`: "Press 1 or
   say *yes* if you are going to help." The `sos-ack` handler (signature-checked) marks the contact as acknowledged
   and answers with TwiML: "Thank you. Location and details are in your text message. Call 999 now if you are not
   with them." No digit → repeat once, then hang up.
2. **Escalation instead of ringing everyone at once:** call contacts in priority order; when a call ends without an
   acknowledgement (`no-answer`, `busy`, machine, no digit), call the next one; send SMS to everyone at the start as
   today. Stop when someone presses 1. A full round with nobody acknowledging → one more round after 2 min, then
   stop and record `unacknowledged`. The state machine lives in the status-callback handler (one row per attempt),
   so no long-running function is needed.
3. Push the acknowledgement to the watch/phone over the existing relay (`watch_context` or a new status row):
   "Anna is on her way".

Pure, unit-testable pieces: the escalation decision (`nextContact(attempts, contacts, now)`), the script builder,
the TwiML builders (escaping, as `escapeXml` does today), and Twilio signature validation with a fixed test vector.

### Stage 3: conversational call (optional, after 1 and 2 work)

Goal: the contact can ask "Where is she?", "What hospital?", "What shouldn't they give her?" and hear correct
answers, in their language.

Mechanism: Twilio **ConversationRelay**. The call's TwiML is
`<Connect action="<sos-ack URL>"><ConversationRelay url="wss://…/sos-voice" welcomeGreeting="<stage-1 opening>"
transcriptionLanguage="multi" dtmfDetection="true"><Parameter name="dispatch" value="<id>"/></ConversationRelay></Connect>`.
Twilio does speech-to-text and text-to-speech and exchanges JSON over the WebSocket: incoming `setup` (with
`customParameters`), `prompt` (`voicePrompt`, `lang`, `last`), `dtmf`, `interrupt`, `error`; outgoing `text`
(`token`, `last`, `interruptible`), `language`, `end` (with `handoffData` back to the `action` URL).

The brain is a **closed set of intents**, not free generation:
- The LLM (same OpenAI setup as `/agent`, temperature 0) only classifies the contact's utterance into one of:
  `where`, `what_happened`, `what_to_do`, `what_not_to_give`, `medicines`, `hospital_or_cardiologist`,
  `acknowledge`, `repeat`, `other`. It may also return a language tag.
- The answer text comes from a deterministic table filled from the dispatch: address and map link (SMS), heart rate
  and reason, "Call 999 / 112", do-not-give drug classes from `DrugDataset` (the same source as B5's responder
  view), current medicines, cardiologist and hospital from the profile (B4 fields, only those the user marked as
  shareable).
- `other` or any classifier failure → "I can only give you the emergency details. Call 112 now." and a repeat of
  where and the number. Validate the classifier output against the enum and fall back on anything else (AI-safety
  rule: the model never writes medical facts).
- Translations: only languages for which we have reviewed strings (`common/CardStrings.ets` has 13 for the card);
  otherwise English. Do not machine-translate medical lines at runtime.

Hosting: a Supabase Edge Function can serve the WebSocket (`Deno.upgradeWebSocket`), but the **wall-clock limit is
150 s on the free plan and 400 s on paid**. Keep the socket's lifecycle inside `EdgeRuntime.waitUntil()` or the
worker may be retired around half the limit (Supabase troubleshooting guide). A 2-3 minute call fits on paid. On
free, either end the session with `end` before ~140 s (hand back to `<Gather>` TwiML through the `<Connect action>`)
or host the socket elsewhere. Verify `X-Twilio-Signature` on the WebSocket upgrade.

Costs and access: ConversationRelay is billed per minute on top of the call; the LLM classifier is one small call
per utterance.

## Needs

- **Twilio account** with a voice-capable number (`TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM_NUMBER`). A
  trial account calls verified numbers only and prefixes a trial message; check whether a number that can call Polish
  mobiles needs a regulatory bundle.
- **`SOS_WEBHOOK_SECRET`** and the Vault secrets `sos_function_url`, `sos_webhook_secret` (coordinator, after
  Georgi's OK).
- **B10** (contacts + first name reach the server under the account) and **B9** (RLS binding) before real numbers
  are used.
- New functions to deploy: `sos-status`, `sos-ack` (both public URLs, auth = Twilio signature, `verify_jwt` off);
  stage 3 also `sos-voice` (WebSocket) and an `OPENAI_API_KEY` that already exists for `/agent`.
- Stage 3 on the free plan: accept the 150 s cap, or upgrade.

## Sources

- Heartbeat / QTShield reference - https://github.com/x2oreo/heartbeat (`src/services/sos-notifier.ts`,
  `src/services/notifications/voice.ts`, `geocoding.ts`, `src/data/country-emergency-numbers.ts`)
- Twilio ConversationRelay TwiML - https://www.twilio.com/docs/voice/twiml/connect/conversationrelay
- Twilio ConversationRelay WebSocket messages - https://www.twilio.com/docs/voice/conversationrelay/websocket-messages
- Twilio `<Gather>` - https://www.twilio.com/docs/voice/twiml/gather
- Twilio Answering Machine Detection - https://www.twilio.com/docs/voice/answering-machine-detection
- Twilio Call resource (StatusCallback, statuses) - https://www.twilio.com/docs/voice/api/call-resource
- Twilio webhook security - https://www.twilio.com/docs/usage/webhooks/webhooks-security
- Supabase Edge Function WebSockets - https://supabase.com/docs/guides/functions/websockets
- Supabase worker timeouts and WebSocket drops - https://supabase.com/docs/guides/troubleshooting/edge-functions-worker-timeouts-and-websocket-drops
- Nominatim usage policy - https://operations.osmfoundation.org/policies/nominatim/
