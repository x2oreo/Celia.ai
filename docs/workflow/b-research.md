# S7 research

## AI_WORKFLOW entry
### 2026-10-03 — Georgi + Claude Code: platform research for Push, Live View, phone ↔ watch, HUAWEI ID (branch `georgi/b-research`)
- Asked: research B12 (Push Kit), B13 (Live View + lock-screen medical ID), B17 (phone ↔ watch link), B18 (Account
  Kit) into `docs/research/*.md` so S4 / S1 can implement without re-researching; summarise the SOS voice path for
  B11 and ask for the Cardbeat reference before designing a conversational call. Docs only.
- Produced: `docs/research/push-kit.md`, `live-view.md`, `phone-watch-link.md`, `account-kit.md`,
  `sos-voice-call.md` (each: verdict,
  exact AGC steps, client and server sketches, emulator vs real phone, "Needs" list, sources). B11 summary below.
- How: Context7 was not connected in this session. Official pages came from developer.huawei.com through the site's
  own document JSON endpoint (the rendered pages time out for WebFetch), API names were checked against the local
  SDK typings (DevEco Studio 6.1.1 / API 24, `sdk/default/hms/ets/api/*.d.ts`), and Huawei's live OIDC discovery
  document and JWKS were fetched with curl. Supabase facts came from supabase.com docs/blog.
- Findings that change plans: Push Kit on phones, Live View Kit and Wear Engine on phones are **mainland-China only**.
  Push server auth is service-account JWT only ("HarmonyOS 5 and later versions no longer support OAuth 2.0"), so the
  brief's "OAuth client credentials" step is obsolete. No Live View scenario covers an SOS countdown (`TIMER` is for
  tool apps). `emergency/LiveStatus.ets` omits `clickAction` and `layoutData`, which the reference requires on
  creation. Account Kit works in Poland and on the emulator with no approval. Third-party lock-screen presence = a
  Form Kit widget with `renderingMode: autoColor/singleColor`; `setShowOnLockScreen` is a system API.
- Validated: every API name used in the code sketches was checked in the SDK typings (`pushService.getToken`,
  `liveViewManager` types and optional/required fields, `wearEngine` clients, `authentication` request/credential
  fields, `form_config` `renderingMode`). Huawei OIDC discovery and JWKS respond (2026-10-03).
- Validated in Deno (scratch, jose 5.10): the Push service-account JWT sketch (header/claims/signature) and the
  ID-token verification sketch (valid → UnionID; wrong nonce/aud/iss → rejected; live Huawei JWKS loads). This
  found a real bug in the first draft: Huawei's JWKS labels keys `RS256` while ID tokens default to PS256, so
  jose's `createRemoteJWKSet` would reject every token; `account-kit.md` now selects keys by `kid` and asks the
  client for RS256.
- Not validated: nothing ran on a device or emulator; no AGC project exists. Unverified points are flagged in each
  doc (push token on the emulator outside China, `idToken` presence in the sign-in response, lock-screen widget
  placement on the emulator, what a tap on a locked-screen widget does, Supabase `.invalid` email acceptance).

## README "How to verify" rows
None (no feature shipped). When S4 / S1 build from these docs, they add rows with "built, unverified" where a doc
says the device or approval is missing.

## ARCHITECTURE notes
Capability table updates for the coordinator, wording ready to paste:
- Push Kit (B12): "⚠️ phones: Chinese mainland only (Huawei docs). Token registration + sender built from
  `docs/research/push-kit.md`; watch SOS reaches contacts by the `sos` function and the open app by polling."
- Live View (F-35): "⚠️ Chinese mainland only, and an AGC scenario request (no scenario fits an SOS countdown);
  ongoing-notification fallback is what runs. See `docs/research/live-view.md`."
- Wear Engine: "❌ phones in the Chinese mainland only, no emulator support; cloud relay is the production path in
  Europe (`docs/research/phone-watch-link.md`)."
- Account Kit (B18): "available in Poland and on the emulator; bridge function design in `docs/research/account-kit.md`."

## For Workstream A (routes, functions, contracts)
Nothing new. If the lock-screen medical ID widget is built (`live-view.md` §2), it is a third form in
`form_config.json` reading the same snapshot as `AlertCard`; its look follows DESIGN.md with no colour-only meaning
(lock-screen widgets render single-colour).

## B11 notes: SOS voice call

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
