# AI workflow

How AI tools were used to build Celia.ai, as required by Challenge Rules §4. Append one entry per session.

## Tools

| Tool | Use |
|---|---|
| Claude Code (Claude Opus 5.5) | Research, architecture planning, code generation, tests, docs |
| Context7 MCP | Up-to-date HarmonyOS docs (`/websites/developer_huawei_consumer_cn_doc_harmonyos-guides`) and OpenAI API docs (`/websites/developers_openai_api`) |
| Project Agent Skills (`.claude/skills/`) | HarmonyOS/ArkTS rules, LQTS domain facts, Celia/HMAF integration, build loop |
| OpenAI API (in the product) | Agent model behind `/agent` — see `AI_FEATURES.md` |

## Pre-existing work

- **HeartBeat / QTShield** (`github.com/x2oreo/HeartBeat`) is our team's earlier LQTS web app. It was used as
  **design reference only**: Claude Code read it and summarised what worked and what didn't. No code, prompts or data
  were copied. Everything in this repo was written fresh during the challenge.
- DevEco Studio 6.1.1 project template (config files and default icons in `watch/`).
- `@ohos/hypium` 1.0.29, `@ohos/hamock` 1.0.0 (test framework, ohpm).
- `@supabase/supabase-js` 2.x (npm, in the `sos` Edge Function), `@std/assert` 1.x (jsr, Deno tests).
- Twilio Programmable Messaging + Voice REST API (external service for SOS SMS and calls; keys in Supabase secrets).

## Sessions

### 2026-10-03 — AI layer research, plan and first implementation (Kaloyan)

**Prompt (summary):** "Research how we built the AI in HeartBeat, brainstorm a voice-first agent at the centre of
the app that works with the tools (medicine check, emergency card…), then plan and build the AI layer."

**Workflow**
1. Two parallel read-only research agents covered the HeartBeat repo and this repo's docs/skills.
2. Context7 checks:
   - Core Speech Kit: the docs only show `zh-CN`, so English is unverified and voice needs a cloud fallback.
   - OpenAI Responses API function-calling format.
3. Four decisions were made with the developer:
   - the app runs the tool loop;
   - OpenAI as provider, starting with push-to-talk and moving to the Realtime API;
   - on-device OCR first, cloud vision as fallback;
   - write actions need confirm cards.
4. Implementation:
   - the `/agent` relay;
   - `ComboRules` and `SafetyGate`;
   - `AgentCore` with `ToolRegistry`, ten tools, `ResponseValidator` and `OfflineAgent`.

**Lessons from HeartBeat applied**
- The LLM no longer decides combination risk; `ComboRules` does.
- An unknown drug can never become green.
- Alternatives are re-verified against the drug list.
- The emergency number is not hardcoded.
- SOS has a confirm countdown.
- Tool results become UI cards.
- Tests exist.

**Validation**
- Every ArkTS file was compiled with `hvigorw assembleHap`, with strict ArkTS and no warnings.
- `app/scripts/test.sh` passes 37 of 37 tests.
- The Edge Function was type-checked with `deno check` and smoke-tested locally with curl: 400 on a bad request, 502 with no key.

**Issues caught in review**
- The first emergency regex matched "help me find an alternative" and "show my emergency card". It was narrowed and
  tests were added.
- JavaScript `\b` doesn't work next to Polish letters, so the Polish patterns now use substrings.
- The reassurance check would have replaced "your heart rate is fine". It is now scoped to medicine context.

### 2026-10-03 (cont.) — voice, photo, Realtime, Intents (Kaloyan)

**Prompt (summary):** continue the approved plan.

**What was built**
- `/transcribe`, `/speak`, `/vision-extract` and `/realtime-session` Edge Functions.
- VoiceInput/VoiceOutput, with Core Speech first and a cloud fallback.
- MedicineScanFlow: on-device OCR first, names-only vision fallback.
- RealtimeSession: WebSocket transport on the same tools.
- `CheckDrugSafety` and `ShowEmergencyCard` intents.

**Docs checked through Context7**
- OpenAI audio, vision, structured-output and Realtime client-secret and event APIs.
- HarmonyOS AudioCapturer/AudioRenderer, Core Vision `textRecognition`, ImageKit packing and `@InsightIntentEntry`.

**Validation**
- The build has no warnings and all 43 unit tests pass.
- Every Edge Function passes `deno check`.

**Issues caught**
- **hvigor skips unreferenced files.** New modules compiled "successfully" until they were imported. A temporary
  import from EntryAbility then surfaced real errors, including a wrong `PermissionRequestResult` import path.
- **Realtime race.** `response.done` can arrive while an on-device tool is still running, which would have ended the
  turn early. It is now fixed with pending-tool counting.
- **Intent decorator.** The decorator only accepts plain string literals; `'a' + 'b'` fails with
  InsightIntent compiler error 10110004.

**Not yet verified**
- Nothing has been tested on the emulator or a device yet: Core Speech English, Core Vision on the emulator, and
  Celia intent routing.
- No call has been made with a real OpenAI key yet; the backend needs to be deployed first.

### 2026-10-03 (cont.) — model selection and first live calls (Kaloyan)

**Prompt:** "Research latest OpenAI models, pick best quality/cost — thinking of gpt-6.1-sol."

**How the model was chosen**
1. Listed the models available to our key through `/v1/models`, and read the model guide and pricing through Context7.
2. Wrote a benchmark script (local scratch, not committed) that runs the real `prompt.ts` and `tools.ts` against
   `gpt-6-luna`, `gpt-6.1-sol` and `gpt-6-astra`. It covered 5 routing cases plus one explanation step, scored against
   the validator's rules.
3. Results:
   - All models chose the right tool in 9 or 10 of 10 cases. The only miss was a sensible "check before add".
   - Every explanation passed the validator.
   - Latency was about 1.6–2.4 s per step.
   - Sol and Astra reject `reasoning.effort=none`.
4. Choice: `gpt-6.1-sol` at `low` effort. Quality is close to Astra at mid-tier cost.

**Live checks with the real key** (functions run locally with `deno run`)
- **`/agent`:** "Can I take Klacid?" returned a `check_drug` call. The device tool output then produced a correct
  KNOWN_RISK explanation that mentioned the escitalopram interaction (about 2.7 s per step).
- **`/transcribe`:** our own TTS audio was transcribed back word for word.
- **Realtime:** a `gpt-realtime-2.1` client secret was minted successfully.

**Security**
- The API key was pasted into the chat once. It is stored only in the gitignored `backend/supabase/functions/.env`
  and will be rotated after the event.

### 2026-10-03 (cont.) — live eval of the AI layer (Kaloyan, with a Claude Code test agent)

**Prompt:** `docs/agent-test-prompt` → "Verify everything on `kaloyan/ai-layer` works, measure it, report back; ≤ $3."

**What was tested** (harness in `backend/eval/`, functions run locally against the real OpenAI API)
- **Free checks.** `deno check` passed. Unit tests: 43/43. A clean HAP build had 0 ArkTS warnings (the HAP is
  unsigned). Request validation passed 25/25 (400/405) across all five functions.
- **Agent (`gpt-6.1-sol`, `low` effort).** 17 cases, with fixture tool outputs and a TypeScript port of
  `ResponseValidator`:
  - 15 PASS and 1 FAIL on the first run (2 harness false alarms re-scored after the fix).
  - Case 16 was flagged as "SAFE (caught)", but that was a validator false positive. It passed on the re-run.
  - The FAIL is case 15: the model writes the requested pizza poem. It did so again at `medium` effort.
  - Tool routing was 17/17. There was no "safe" wording, no invented alternatives, and the prompt injection failed.
  - Latency: p50 2.5 s per step, max 4.9 s.
- **Audio.** TTS → transcription round trip: 5/5 phrases came back word for word, including Polish. The SafetyGate
  port classified "I passed out at the pool" and "I can't breathe properly" as EMERGENCY.
- **Vision.** 4/4: the clear box returned Klacid and Clarithromycinum (HIGH). The blurred box and the grocery list
  came back UNREADABLE with no names. Both names on the two-product image were found. No risk wording appeared.
- **Realtime (`gpt-realtime-2.1`).** 2 sessions (text in, then TTS audio in). Every event name `RealtimeSession.ets`
  uses arrived with the exact spelling. The `check_drug` round trip worked and the answer said known risk.
- **Spend:** about $1.18 of the $3 cap (agent $0.71, audio $0.10, vision $0.10, realtime $0.27), priced at worst-case
  rates.

**Bugs found** (reported, not fixed by the test agent)
1. **Typographic apostrophes.**
   - `ResponseValidator`, `SafetyGate` and the Realtime streaming check only match ASCII `'`, but the model and the
     Realtime transcripts write `’`.
   - "It’s safe for you." passes the validator, "I can’t breathe" is not an emergency, and "isn’t harmless" is flagged.
   - Fix: normalise `[‘’]` → `'` before matching.
2. **Validator false positive.** "that does not mean the combination is safe" is treated as reassurance, because
   the negation window only covers 14 characters. In case 16 this replaced a good, contextual answer.
3. **English-only validator.** No Polish reassurance patterns, so "Apap jest bezpieczny" would pass.
4. **Off-topic requests.** The prompt has no off-topic rule, so the model writes poems (case 15).
5. **Status pass-through.** `/agent` passes upstream 4xx statuses (401, 404, 400) through instead of 502. All
   functions also log up to 500 characters of the upstream error body.

**Not tested:** device and emulator (`hdc list targets` was empty), Core Speech, and Celia intents on a device.

### 2026-10-03 (cont.) — fixing what the live eval found (Kaloyan, with Claude Code)

**Prompt:** "plan out how to fix all and fix them"

**Fixes** (one commit each, with unit tests, and the eval port in `backend/eval/lib.ts` kept in sync)
1. **Typographic apostrophes.** The new `common/Text.ets` `normalizeText()` runs before every safety regex in
   `SafetyGate`, `ResponseValidator` and the Realtime streaming check. "I can’t breathe" now triggers the emergency
   flow, and "It’s safe for you" is caught.
2. **Validator false positive.** Reassurance inside a denial ("does not mean … is safe", "nie oznacza, że …") is
   ignored up to the end of the sentence.
3. **Polish.** Added Polish reassurance patterns plus Polish risk, ask-a-doctor and medicine words. Without the
   latter, a correct Polish KNOWN_RISK answer would have been replaced; this was found while planning the fix.
4. **CONDITIONAL_RISK** answers must now mention the risk.
5. **Off-topic rule.** Prompt rule 8, `PROMPT_VERSION 2026-10-03.2`. The first wording's example ("is OK for your
   heart") tripped our own validator, which the eval caught, so the wording was changed.
6. **Backend errors.** Every upstream error returns 502, and logs keep only the status and OpenAI's error code.

**Verification**
- Unit tests: 49/49 (6 new).
- HAP build: 0 ArkTS warnings.
- Validation 25/25 and robustness 7/7.
- Agent eval on the new prompt: 17/17, with no validator false positives. Realtime smoke: pass.
- Total eval spend for the day: about $1.98 of the $3 cap.

### 2026-10-03 (cont.) — merging the app from main and wiring the AI into it (Kaloyan, with Claude Code)

**Prompt:** "wait for one of the agents to finish … push. Then … get what there is in main … make sure everything is
connected and is working correctly with the AI"

**What was done**
1. Confirmed with the parallel Claude Code sessions that the eval fixes were finished, then pushed `kaloyan/ai-layer`.
2. Merged `origin/main` (the full app: home, medicines, SOS, reminders, doctor prep, LocalStore, AppLock, Supabase drug
   dataset). Conflicts were resolved by hand. EntryAbility starts LocalStore/AppLock and the agent. Permissions are
   main's plus MICROPHONE. Main's strings get `mic_reason`, main's deletion of the `pl_PL` strings is kept, both test
   suites are registered, and the architecture table takes main's version with our OCR and voice rows.
3. **One drug-check path.** The agent's `checkDrugFull` now runs through main's `CheckService`, so the barcode, the
   offline dataset, the online fallback, scan history and the watch buzz are shared with the check screen.
   Interaction findings are the union of `ComboRules` and `DrugChecker.checkCombo`. This was a safety issue found
   during the merge: the two engines have different enzyme tables, so the chat and the check screen could have
   disagreed.
4. **One emergency number table.** `safety/EmergencyNumbers` is now a thin adapter over main's
   `common/EmergencyNumbers` and prefers the onboarding country. In Poland Celia now says 999, the number the SOS
   screen dials; before, it said 112.
5. **Agent tab.** `AgentPage` replaces the placeholder. It covers text, push-to-talk and live voice, renders the
   deterministic cards (verdict, confirm, quick replies, emergency, box scan via the photo picker) and shows an
   offline strip when there is no backend. New colour resources are documented in DESIGN.md §2.1a.
6. **Entry points.** "Ask Celia" on Home, plus "Ask Celia about this" on the check result (through `AgentPrompt` and
   the new `common/TabRequest`).
7. **Emergency hand-off.** Agent emergencies open main's SOS countdown, and the agent quotes its 30 s length.
   Critical vitals alerts no longer start a second agent check-in, and "I'm OK" on SOS tells the agent.
8. **Intent bug.** `ShowEmergencyCard` set an AppStorage key that nothing read. It now uses `TabRequest`.

**Verification**
- HAP build clean with 0 ArkTS warnings, and unit tests 101/101 (2 new).
- Backend `validation.ts` all pass. It is free, and the backend is unchanged.
- **Not verified:** the emulator, because no `hdc` target was connected; `LocalConfig.ets` has no backend URL, so the
  app runs in offline mode; and the Edge Functions are not yet redeployed with prompt `2026-10-03.2`.

### 2026-10-03 (cont.) — testing on the emulator, driven by Claude Code (Kaloyan)

**Prompt:** "i started emulator in deveco studio — think how you can come to use it yourself and test things out"

**How the agent drove the emulator**
- UI: `hdc install` of the unsigned HAP, which the emulator accepts, then `uitest uiInput` (tap, type, swipe),
  `uitest dumpLayout` to find elements by text, and `snapshot_display` screenshots that the model reads. This is
  now `app/scripts/ui.sh`.
- Live AI without deploying: the Edge Functions run locally under deno behind a small router
  (`backend/eval/dev-backend.ts`), `hdc rport tcp:8000 tcp:8000` forwards the port into the emulator, and the
  gitignored `LocalConfig.ets` points at `127.0.0.1:8000`.

**Verified on the emulator (API 24 image)**
- Onboarding, and Home with the Ask Celia tile.
- Offline chat: verdict card plus interaction findings, and the check appears in the scan history.
- Emergency phrase, including a curly apostrophe: SOS countdown, with the right number (911 for a US profile) and
  the 30 s length quoted.
- "I'm OK" on SOS confirms in the chat.
- Check result → "Ask Celia about this".
- **Live model:** `check_drug` runs on the device and returns a deterministic card with a validated explanation.
  `add_med` shows a confirm card and saves only after Confirm.
- Simulated heart alerts trigger a check-in with quick replies.

**Bugs found only by running it** (all fixed, with tests where the logic is pure)
1. Celia said "tap Cancel", but the SOS button reads "I'm OK". The Open SOS chip also stayed after cancelling.
2. The offline parser took "it" from "I was offered Zofran. Is it safe…" as the drug name, so a known-risk
   medicine came back as "not recognised". The failure was safe, but wrong.
3. Check-in text repeated the heart rate and "Are you OK?", because main's alarm rules already write both.
4. INFO-level alerts (e.g. HRV drop) started a check-in that would escalate to SOS after 60 s. They now only post
   a message.

**Not verified:** voice (no mic input on the emulator), box scan from a photo (no test image in the gallery),
Realtime, and Celia intents. A parallel Claude Code session is redesigning the UI on the same branch; the two
sessions coordinated file ownership by message.


### 2026-10-03 (cont.) — UI redesign to the design system (Kaloyan, with Claude Code)

**Goal.** The app was built before the design system existed. This session brought every phone screen in line
with `docs/design/DESIGN.md` and the three design screenshots (B1–B6), and built the two home-screen cards.

**How the model worked**
- Plan mode first: two read-only sub-agents inventoried the UI layer and the product docs, the model read the
  design screenshots itself, and a gap table and phased plan were approved before any edit.
- Six phases, one or two commits each, ordered by demo value so the app stayed shippable after every phase:
  tokens → shared components → navigation, home and chat → Medicines and scan → check-in, SOS, Heart and
  Emergency → secondary screens and widgets → cleanup.
- Every phase ran the terminal loop: `hvigorw assembleHap`, `hdc install` of the unsigned HAP, `uitest uiInput`
  taps and `snapshot_display` screenshots, which the model compared with the design screenshots.
- Form Kit was checked in Context7 (FormExtensionAbility, `form_config.json`, `postCardAction`, `updateForm`)
  before the widget code was written.

**What changed**
- Tokens: warm palette, ink scale, risk tint/text/border, full type scale, light and dark. The old colour names
  were remapped first so nothing broke mid-migration, then removed.
- Components: ink / secondary / quiet / danger buttons, risk shape and badge (Unknown is a dashed circle with
  "?"), orb avatar, heart-rate ring, chips, strips, typing dots, verdict card with the risk header band.
- Structure: four tabs (Agent = home, Medicines, Heart, Emergency). The chat is a pushed page. A WARN heart alert
  opens the agent's check-in as a bottom sheet.
- Widgets: "Can I take this?" (2×2) and Medical alert (2×4), fed by a snapshot the app writes.

**Safety decisions kept from before**
- Verdict colour and word still come only from the deterministic verdict; the chat card is built from the tool
  payload, not from model text.
- A CRITICAL heart alert still goes straight to the SOS countdown. Only WARN alerts use the check-in sheet. The
  design shows the sheet for a 165 bpm reading; changing that escalation path is a medical-safety decision and
  was left to the team.

**Verified on the emulator:** home, chat with an inline verdict, Medicines, check result, Heart, Emergency,
Settings, Bystander, the check-in sheet, the SOS countdown, and a card tap opening the scanner. 104 unit tests pass.

**Not verified:** how the two cards render on the home screen (they are registered, but adding one needs a manual
long-press), dark mode on a device, and the largest font size.

**Two sessions, one branch.** A second Claude Code session was rebuilding the voice chat at the same time. The
sessions agreed file ownership by message and staged explicit paths only. One commit of this session still
picked up the other session's new strings from the shared `string.json`; nothing was lost.

### 2026-10-03 (cont.) — voice-first conversation with the agent (Kaloyan, with Claude Code)

**Prompt (summary).** "Rework how the AI works in the UI. It should be a voice AI you talk to, with the chatbot as
an option. Redesign the orb, show my message being written as I speak, and design all the tools beautifully in
our design system."

**What the model did**
- Read `docs/design/DESIGN.md`, the chat page and the whole voice layer first, then extended the design system
  before building (new 6.6a voice orb, 6.8 tool steps and agent cards, revised B2 in 10.1, two motion rows).
- Voice engine (`voice/RealtimeSession.ets`): reports a conversation phase (connecting, listening, hearing,
  thinking, speaking), the user's and the agent's words as they arrive, and the loudness of whoever is talking
  (`pcmLevel` in `Wav.ets`, unit-tested). A reply now waits up to 1.5 s for the user's transcript so the thread
  stays in order. Typed text and tapped chips go into the live session and are answered out loud, through the same
  SafetyGate.
- `AgentCore.runTool` announces every tool call, so both the text loop and live voice show what the agent is
  doing ("Checking Klacid against the QT list" → "Checked …").
- New UI: `components/VoiceOrb.ets` (halos follow the voice, neutral for the user and coral for the agent),
  `components/AgentCards.ets` (tool step, confirm card, medicines card, options card, emergency notice, action
  tile) and a rewritten `pages/AgentPage.ets` with a voice mode (orb, live thread, mic dock) and a chat mode.
- Two new deterministic cards: `SHOW_MEDS` (from `get_my_meds`) and `SHOW_ALTERNATIVES` (from
  `suggest_alternatives`, only options re-checked as Not listed on the device).

**Decisions made by the human / kept from the rules**
- Verdict colours and words still come only from the deterministic payloads. A finished tool step is neutral ink,
  never a risk colour, so "done" cannot be read as "safe".
- The microphone never opens by itself: one tap starts the conversation, and leaving the page ends it.

**Verified on the emulator**
- Offline: idle voice screen, starter → verdict card, "Check my current medicines" → medicines card, chat mode,
  and the "can't use the microphone" strip (the emulator has no English on-device speech engine).
- Live, against the local backend (one short Realtime session): connecting → listening → speaking, the agent's
  words appearing while it speaks, the `check_drug` step and the verdict card.

**Bug found by running it.** The offline parser read "Check my current medicines" as a medicine called "my
current medicines". Fixed, with a test.

**Not verified:** real speech into the microphone (nobody can talk to the emulator from the terminal), so the
live user transcript, the voice-level halos while the user speaks, barge-in and mute are untested on a device.
The tap-to-talk fallback is also untested end to end.

### 2026-10-03 — Mark + Claude Code: watch app
- **Asked:** build the watch part. Our GT 6 Pro should send metrics via the iPhone to a server that the phone app
  (DevEco Previewer) reads.
- **Research (AI, verified against the installed SDK):** the lite wearable device definition
  (`sdk/default/hms/js/api/device-define/liteWearable.json`) has no NetStack syscap, so a GT app can't make HTTP
  calls; `WearEngineLite` (API 24) only exposes connection state. Decision: ArkTS wearable app on the wearable
  emulator with scripted heart-rate scenarios. (A Mac BLE bridge for real GT 6 Pro heart rate was built, then
  dropped by the team to keep the demo emulator-only.)
- **Produced:** `watch/` (HR sources, deterministic `AlarmRules`, session stats, persistent outbox, Supabase uploader,
  round UI), `backend/supabase/migrations/*_watch_metrics.sql`.
- **Validated:** strict ArkTS build with no warnings; 16 local unit tests pass (`hvigorw test`); installed on the
  HarmonyOS 6.1.1 wearable emulator and checked by screenshot: live HR, LQT2 startle → high-HR alert after 10 s,
  symptom logging, outbox persists across restarts.
- **Not yet validated:** upload to a real Supabase project.
- **Lessons:** HarmonyOS training data is stale. The SDK's own `.d.ts` and device-define files were the fastest
  ground truth. Emulator screens are ~233 vp wide, so the first UI was 2× too big; screenshots caught it.

### 2026-10-03 — Mark + Claude Code: SOS backend (parallel session, branch `sos-backend`)
- **Asked:** when the watch's SOS countdown runs out, actually call and text the emergency contacts.
- **Research (AI, verified in Context7 HarmonyOS guides):** `call.makeCall` only opens the dialer, and
  `sms.sendShortMessage` needs `SEND_MESSAGES`, which only system apps can get. So an app can't dial or text
  silently. Decision: the server does it, triggered by the watch's `sos` row.
- **Produced:** migration `20261003200000_sos_dispatch.sql` (`emergency_contacts`, `sos_dispatches` audit and
  cooldown, pg_net trigger with URL and secret in Vault), Edge Function `backend/supabase/functions/sos/`
  (deterministic message, Twilio SMS + voice call, 10 min cooldown, dry-run without Twilio keys).
- **Validated:** 7 Deno unit tests pass (payload validation, message content, no URLs in voice text, TwiML
  escaping, E.164); `deno check` passes; local run checked: wrong secret → 401, bad payload → 400.
- **Not yet validated:** deployed to a real Supabase project; real Twilio delivery.
- **Worked in parallel** with the watch-app session in a separate git worktree (new files only), so neither
  session overwrote the other's work.

### 2026-10-03 — Mark + Claude Code: missed beta-blocker check (branch `beta-blocker-check`)
- **Asked:** detect possibly missed beta-blocker doses from the watch's resting heart rate, plus a watch Simulate
  button to demo it.
- **Design (AI, reviewed by Mark):** a fixed rule, no LLM. Baseline = median of up to 14 earlier days (at least 5);
  ask when each of the last 2 complete days is ≥ 10 bpm above it. Only for people on a beta-blocker, and always
  phrased as a question. The dose log picks the wording (missed / all taken / not tracked) and mentions fever and
  illness as other causes.
- **Produced:** `app/.../vitals/RestingTrend.ets` (rule), `RestingHistory.ets`, `BetaBlockerWatch.ets`,
  `Net.getJson`, `AgentCore.pushProactive`, alert kind `RESTING_HR_RISE`; migrations `…220000_watch_resting_daily`
  (daily resting HR view over watch `vitals` rows) and `…230000_resting_day_sim` (labelled simulated days via the
  `simulate_missed_beta_blocker` RPC, called by the watch's Simulate toggle).
- **Validated:** 13 new unit tests (70 total pass); migrations applied in order on a local Postgres 17, including
  RPC on/off, simulated days replacing real ones and anon unable to write the table directly.
- **Not yet validated:** end to end on Supabase with the emulator (migrations not applied there yet). The proactive
  agent message has no chat listener yet (`onProactive`).
- **Worked in parallel** with the watch session: the watch button was handed over as a written spec instead of
  editing the same files, to avoid merge conflicts.

### 2026-10-03 — Mark + Claude Code: watch data the phone was ignoring
- **Asked:** check what the watch sends that the phone doesn't use yet.
- **Found (AI, from the code on main):** the phone's `WatchCloudSource` uses `vitals`, `sos`, `fall_detected`,
  `hr_recovery` and `vitals_alert`, but ignores `medication_taken`, `symptom` and `wear_state`.
- **Produced:** migration `…240000_watch_phone_views.sql` with three read-only views for the phone team:
  `watch_status` (ON_WRIST / OFF_WRIST / OFFLINE), `watch_doses` (doses confirmed on the watch) and
  `watch_symptoms`. Phone code was left to the phone team (newer app on `app_development`).
- **Validated:** all migrations applied in order on a local Postgres 17 (except `pg_net`, which is Supabase-only);
  the views were checked with test rows: wear state, offline detection, empty names and unknown symptom kinds
  filtered out, simulated rows labelled.

### 2026-10-03 — Mark + Claude Code: using watch doses and "How do you feel?" answers
- **Asked:** make the watch's "Took nadolol" taps and symptom answers useful beyond a log.
- **Produced:** migration `…250000_watch_insights.sql`: `watch_daily_summary` (per-day doses, symptoms, alerts,
  resting HR) and `watch_insights` (fixed rules with fixed texts: symptom within 24 h of a QT-risk drug, fainting,
  repeated symptoms, no dose logged in 26 h). The `sos` function now adds the last watch dose and any symptom from
  the last hour to the SMS and call. `docs/team/watch-data-for-phone.md` hands the phone/agent wiring to Georgi
  and Kaloyan; the missed-dose nudge was handed to the watch session as a spec.
- **Validated:** all migrations on a local Postgres 17 with test rows (each insight fires once, `fine` answers and
  old symptoms are ignored, wording checked); 10 Deno tests for the SOS message pass (3 new) and `deno check` passes.
- **Not yet validated:** the new SOS text over real Twilio; the views on Supabase (migration not pushed yet).

### 2026-10-03 — Georgi + Claude Code: emergency-card link fallbacks and branch merges (branch `app_development`)
- **Asked:** the card QR only opened on the laptop. Fix it for phone scans, add a visible link under the QR, make
  112 the main number on the card page, then merge `main` and `kaloyan/ai-layer` into the branch.
- **Found (AI):** the QR pointed at the GitHub Pages viewer, which wasn't deployed yet (404).
- **Produced:**
  - "Open card in browser" / "Copy card link" under the QR (`EmergencyPage.ets`).
  - `LocalConfig.CARD_VIEWER_URL` override and `app/scripts/serve-card.sh`, which serves `site/` from the laptop
    for phones on the same Wi-Fi.
  - The viewer's main button is now the general number (112), with the direct ambulance line underneath.
  - Merge conflicts resolved by keeping both sides: `AgentCore.pushProactive` (used by `BetaBlockerWatch`) next
    to the AI layer, both start-up hooks in `EntryAbility`/`Index`, and all string resources.
  - Second merge, after the ai-layer UI redesign: took the redesigned screens and re-applied our features on top.
    Box info card, add-from-box and "teach this box" now live in the new `ScanPage` and `CheckResultPage`. Scanning
    a Celia card QR opens `CardViewPage`. The card link and its open/copy buttons are back under the QR on the new
    `EmergencyPage`.
- **Validated:** `hvigorw assembleHap` after each change and merge; installed on the emulator; the card page
  opened from the local server in the emulator browser.
- **Not yet validated:** a real phone on the same Wi-Fi; the public viewer (needs Pages enabled on `main`).

### 2026-10-03 — Georgi + Claude Code: chat history and new chats for the agent (branch `app_development`)
- **Asked:** save conversations with the agent, start a new chat with a button, switch between chats from the agent
  screen and Home, and let the user say "save this chat and start a new one".
- **Plan (AI, approved by Georgi):** written with the planning skill before any code, in six tasks with checkpoints.
  Decisions: every chat saves automatically, titles come from the first user message (no model), and the model only
  ever sees the open chat.
- **Produced:**
  - `chats` and `chat_messages` tables (schema v2) in the encrypted `LocalStore`, limited to 50 chats × 200 messages.
  - `AgentCore` saves each message to the open chat and has `newChat` / `openChat` / `deleteChat`; the last chat is
    restored at start.
  - `ChatCommands` matches short "new chat" commands on device, after `SafetyGate`. The `start_new_chat` tool is
    defined on device and backend, with prompt `2026-10-03.3`.
  - `ChatsPage` (list, open, rename, delete), New chat and Chats buttons in the agent header, and a Chats link on
    Home. The screen spec was added to DESIGN.md first.
- **Safety:** reopened chats keep display cards only. Confirm, quick-reply and SOS cards are dropped, so an old chat
  can never add a medicine or start an SOS.
- **Validated:**
  - 9 new unit tests (143 total pass).
  - The live model chose `start_new_chat` with the name the user gave.
  - On the emulator: asked about Klacid, saved the chat by asking in plain words, saw both chats in the list,
    reopened the old one with its verdict card, and it was still there after an app restart.
- **Not yet validated:** the live-voice path for "new chat" (the realtime session keeps its own memory until it is
  restarted).

### 2026-10-03 — Georgi + Claude Code: medicine info and a redesigned reminders page (branch `app_development`)
- **Asked:** make the Medicine reminders page look better within the current colours and structure. Load info about
  each medicine (what it is, what's in it, what to know) so the cards say more than a name, and allow an OpenAI
  explanation on demand.
- **Plan (AI, approved by Georgi):** written with the planning skill before any code. Georgi picked curated offline
  data + an optional AI explanation, on the reminders page, a new medicine detail sheet and the medicines grid.
  DESIGN.md was extended first (§6.9, Reminders in §10.2).
- **Produced:**
  - `drugs/DrugInfo.ets`: what it's for, how it works and up to 3 everyday tips for all 137 dataset medicines,
    written by the AI from general patient-leaflet knowledge. **Needs review by the team before the demo.**
  - `drugs/MedFacts.ets` merges class, brands, risk reason, interactions with my other medicines and DrugInfo.
  - `/med-info` Edge Function + `drugs/MedInfoClient.ets`: strict schema, banned-word filter on both sides, cached
    on the phone, sent through the privacy ledger. AI text never sets a badge or colour.
  - `MedicineDetailSheet`, richer cards in the Medicines grid, and a rebuilt `RemindersPage` (progress summary,
    timeline with status words, medicine chips and time presets instead of the dropdown).
- **Validated:** strict ArkTS build with no new warnings; `deno check` on `med-info`; 9 new unit tests (DrugInfo
  coverage and lengths, MedFacts, reply validation), all passing. Other failures in the run (agent verdict card,
  chat history, card link) come from parallel work in the same working tree, not from this change.
- **Completed in a second pass:** "Ask the agent" in the medicine sheet (opens the chat with an `AskParam` question
  that goes through the normal SafetyGate → agent → validator path), a live info preview in the add-medicine form,
  `med-info` registered in `backend/eval/dev-backend.ts`, and the function deployed to the Supabase project with the
  Supabase MCP (version 1, JWT check on).
- **Validated live:** `med-info` run locally with the real key: Zofran → correct plain summary and leaflet tips, a
  made-up name → `recognised: false`, an empty body → 400. The hosted function answers 502 until the
  `OPENAI_API_KEY` secret is set in that project (logs: "Missing env OPENAI_API_KEY").
- **Not yet validated:** emulator screenshots (skipped on purpose in this pass).


### 2026-10-03 — Georgi + Claude Code: encrypted share links for the emergency card and doctor report (branch `app_development`)
- **Asked:** put the card QR and the doctor report on Supabase so both open from a link on any device, redesigned
  to the new design system.
- **Research (AI, from Supabase docs):** Edge Functions rewrite `text/html` to `text/plain` and Storage serves
  HTML as plain text, so Supabase cannot host the pages. Decision (with Georgi): Supabase stores and serves
  the data; Vercel hosts two static viewer pages.
- **Design (AI, approved by Georgi):**
  - End-to-end encryption: the phone seals JSON with AES-256-GCM and keeps the key in the link's `#`, so Supabase
    and Vercel only ever see ciphertext.
  - Report links expire after 48 h. Card links last until the card changes or the user revokes them.
  - The QR shrank from about 900 to about 90 characters.
- **Produced:**
  - Backend: the `share` Edge Function (POST/GET/DELETE, private Storage bucket, revoke tokens stored as SHA-256)
    with Deno tests.
  - App: `ShareCrypto`, `ShareService`, `ReportPayload` (structured report: resting-HR trend, doses), wired into
    the Emergency and Doctor prep screens. Celia's scanner opens short card links in the app.
  - Web: `site/assets` (tokens, crypto helper), a rebuilt `site/card`, a new `site/report` (print-ready, dark
    mode), and `vercel.json` (CSP limited to the Supabase URL, `no-referrer`, `noindex`).
  - DESIGN.md §10.2a spec written before building.
- **Validated:**
  - 5 Deno tests.
  - Real round trip against Supabase Storage via the local backend: create, get, wrong revoke token → 403,
    revoke → 404.
  - Sample shares sealed with WebCrypto opened in Playwright: card at 390 px, report at 390 px and 1280 px, dark
    mode.
  - 157 ArkTS unit tests pass.
- **Bugs found:** the local proxy dropped query strings (fixed in `dev-backend.ts`). The chart labels were
  unreadable at phone width (now drawn at the real width).

### 2026-10-03 — Georgi + Claude Code: online check for any medicine, step 1 (branch `app_development`)
- **Asked:** plan how scanning can recognise medicines outside our dataset online with AI, then build it.
- **Plan (AI, choices made by Georgi):** a 10-task plan. Verdicts for medicines outside the curated list come from
  the FDA drug label using a fixed keyword rule, not from the LLM. Unknown barcodes go through a cache, then a public
  register, then AI web search that must cite a source, then a box photo; the user always confirms. Built so far:
  the risk part (tasks 1–3).
- **Research (AI, against the live APIs):**
  - RxNav fuzzy search matches junk ("table" → table sugar), so it is used only when the match starts with the typed
    name.
  - RxNorm marks discontinued brands (Zofran, Atarax) obsolete, so ingredients come from `historystatus`.
  - One label per drug can miss a warning (loperamide), so the worst of 5 labels counts.
  - RxNav returns US names (acetaminophen), so tier 2 checks the curated list through its aliases.
- **Produced:**
  - Backend: `_shared/labelRisk.ts`, `_shared/rxnav.ts`, `_shared/openfda.ts`, `drug-check/tier2.ts`; `drug-check`
    rewritten as tier 1 + tier 2; `label_cache` migration.
  - App: `DrugCheckClient.parseOnlineVerdict` (validated, label quote shown in "How we know", confidence capped at 0.9),
    `LABEL` trace step.
- **Deployed (Supabase MCP):** `label_cache` migration; `seed.sql`, which the cloud database never had (137 drugs,
  495 aliases); `drug-check` v1 (first deploy, JWT required).
- **Validated:**
  - 17 Deno tests (label rule + tier 2 with fake dependencies).
  - 5 new Hypium tests. The full suite ran 162 tests: 160 passed; `unknownDrugIsNeverReportedSafe` timed out and
    `drugQuestionGetsDeterministicVerdictCard` failed. Neither runs the changed code.
  - Live calls: Tasigna / Caprelsa → KNOWN_RISK (boxed warning), Fanapt → POSSIBLE_RISK, Keppra → NOT_LISTED 0.6,
    Lexapro / Zofran → curated KNOWN_RISK, junk → UNKNOWN_DRUG. Uncached 1.2–3.1 s.
- **Rejected:** raising the app timeout to 9 s. Unit tests that hit the unreachable local backend timed out
  (3 extra failures), and the live path fits within 5 s.

### 2026-10-03 — Georgi + Claude Code: everything on Supabase, so links work from any device (branch `app_development`)
- **Asked:** make sharing and the AI work from any phone without the laptop, secure and working.
- **Plan (AI, approved by Georgi):**
  - Sharing always goes to the deployed project (`Config.SHARE_BACKEND_URL`), independent of the AI backend.
  - The AI functions are deployed and the app points at Supabase.
  - Then a security review.
- **Produced:**
  - `share` v3: creating and revoking need the project's publishable key and fail closed; blobs live in `card/` and
    `report/` folders; expired reports are swept on create.
  - `agent`, `transcribe`, `speak`, `vision-extract` and `realtime-session` deployed with JWT checking on.
  - `Net.ets` gained request targets (`NetTarget`).
  - `ShareService` keeps the revoke token until the server confirms and retries pending revokes (bug found by the
    parallel docs session).
- **Validated (live):**
  - Every AI function returns 401 without a key.
  - With the app key: `agent` called `check_drug` for Klacid, `speak` returned audio, `realtime-session` issued a
    client secret, `transcribe` answered.
  - `share`: 401 without or with a wrong key; view, revoke and 404 work with the key.
  - The `shares` bucket is private and was emptied of test data.
  - A card and a report sealed like the app opened on celia-share.vercel.app.
  - No secrets in tracked files; 170 unit tests pass.
- **Found (not changed, teammates' database):**
  - Advisors flag `handle_new_user` and `simulate_missed_beta_blocker` as callable by `anon`.
  - `pg_net` is in the public schema.
  - Leaked-password protection is off.

### 2026-10-03 — Georgi + Claude Code: identify any medicine box by barcode, online (branch `app_development`)
- **Asked:** finish the feature so that any medicine box can be identified, not only Polish ones, and make it as fast
  as possible.
- **Research (AI, against the live APIs, timed):**
  - openFDA labels can be searched by barcode (`openfda.upc`, ~0.8 s), so no NDC splitting is needed.
  - Spanish barcodes carry the national code, which the AEMPS CIMA register answers in ~0.3 s.
  - UPCitemdb (~0.5 s) and Open Food Facts (~0.13 s) cover retail and OTC products.
  - German and Polish codes are in no open database (Polish ones are already bundled in the app).
  - RxClass returns nothing for ATC codes, so the idea of using ATC was dropped.
  - The cloud project had no `OPENAI_API_KEY` at first, so the AI stages are built to skip cleanly.
- **Design (AI, approved by Georgi earlier):**
  - Two calls, so the screen never waits on AI: `fast` (cache plus all deterministic sources in parallel, awaited in
    trust order) and `deep` (AI web search, only after a fast miss).
  - Every ingredient must resolve in RxNav; ones that do not are passed on, so the check says UNKNOWN for them.
  - The user always confirms the box. AI finds are cached for others only after a user confirmed them.
- **Produced:**
  - Backend: `_shared/gtin.ts`; `box-identify/{sources,resolve,ai,index}.ts` with Deno tests; the `box_cache`
    migration.
  - `drug-check`: phrase-first checking ("ascorbic acid"), salts mapped to the base ingredient, a 4.3 s budget with
    a background finish, and an RxNav memo.
  - App: `BoxIdentifyClient.ets` (validated parse), `BoxCandidateSheet.ets`, the ScanPage flow (fast → web search →
    teach form) and `BoxSource 'ONLINE'`.
  - DESIGN.md §10.2 spec written before building.
- **Deployed (Supabase MCP):** `box_cache` migration; `box-identify` v3; `drug-check` v5.
- **Validated:**
  - 56 Deno tests and 175 Hypium tests pass; `assembleHap` builds.
  - Live calls:

    | Barcode | Result | Time |
    |---|---|---|
    | US Tylenol, US Loratadine | identified (registry) | 2–3 s on first sight |
    | Spanish Aspirina C | aspirin + ascorbic acid | ~1.5 s |
    | Spanish Depakine | valproate (via INN translation) | — |
    | Any repeat lookup | from cache | ~0.35 s |
    | `1234` | rejected (400) | — |
- **Bugs found and fixed:**
  - "sodium valproate" was checked as the word "sodium". Salts now map to the base ingredient, and a phrase RxNav
    knows is never split into words.
  - A colour token (`brand` → `brand_accent`) that broke the HAP build; a parallel session caught it.
- **Not done:** the box-photo fallback from the scan screen (the agent's photo scan still exists). Unknown boxes fall
  back to the teach form.

### 2026-10-04 — Georgi + Claude Code: scanning a box showed nothing (branch `app_development`)
- **Reported:** scanning a Nurofen box gave a click and no result.
- **Found (hilog + code + backend logs):** the barcode was read (`Barcode: scanned 8`), but nothing appeared because
  1. `ScanPage` chained three `.bindSheet()` calls on one node. Only the last (teach) sheet was bound, so the
     verdict sheet and the online-lookup sheet never opened. Nurofen is in the bundled Polish register, so its
     verdict sheet was the one that was lost;
  2. `/box-identify` was not in the local dev backend, so the online lookup returned 404;
  3. the emulator had no `hdc rport tcp:8000`, so no online call reached the backend;
  4. locally `box-identify` crashed creating the DB client (`.env` has `SUPABASE_SECRET_KEY`, the function only read
     `SUPABASE_SERVICE_ROLE_KEY`).
- **Fixed:** one sheet per node in `ScanPage`, the key fallbacks (also in `drug-check`, which read the same keys),
  `box-identify` and `drug-check` in `dev-backend.ts`, the port forward. The other session that owns `/box-identify`
  was told; it keeps the fixes. Locally `drug-check` now answers (`nurofen` → ibuprofen, NOT_LISTED).
- **Validated:** clean ArkTS build; local `box-identify` fast stage answers (cache hit for a US Tylenol code returns
  brand, ingredients and source) and the deep stage runs; fixed build installed on the emulator for the user to
  rescan. UI not driven by the AI, at the user's request.


### 2026-10-03 — Georgi + Claude Code: finish what the docs still promised, then a regression pass (branch `app_development`)
- **Asked:** find everything the md docs specify that is not built, build it, then test that nothing else broke and
  report back.
- **Plan (AI, approved by Georgi):** three read-only audits (app features, backend/site, docs vs code) → one plan
  with batched questions. Georgi chose: everything without external approvals; report links stay at one; deploys,
  `.hap` release and video are his; A2A, caregiver tablet and Brugada/CPVT stay out. Three other Claude sessions were
  editing the same tree, so file ownership was agreed over cross-session messages before each edit.
- **Produced:**
  - Tests: `Config.forceOffline` seam so unit tests never call the developer's backend (157 → 188 tests, all green).
  - Safety: med-info banned-words filter fixed (`\b` after stems missed "arrhythmias", "torsades", "QTc"), cached AI
    text re-validated and expired after 30 days, rejected vs unknown vs unreachable told apart; `med-info/logic.ts`.
  - Privacy ledger now covers every AI call (`BackendClient`) and live-voice sockets; ledger export.
  - Saved chats hardened (corrupt rows, id reuse after a partial load, title limit, busy guard, 50-chat test).
  - Genotype tip of the day on Home + coach tips in `explain_condition`; `log_symptom` agent tool (red flags → SOS
    by rule); 5 more Celia intents; card language picker + read aloud (medical part only); nearby help (map search
    link, no location sent); travel banner + localised pharmacy card; phone → `watch_context`; doctor-brief AI summary
    (`/doctor-summary`, no name/notes sent, reassurance/doses dropped); accessibility groups and states; bystander
    button on the alert widget; Remove-link confirmation; report links scanned in the app open in the browser.
  - Web: card viewer wording in 13 languages; GitHub Pages publishes only the card viewer.
  - Docs: DESIGN.md (coach card, travel banner, card language/read aloud/nearby, Taken pill 44 vp), README verify
    table + test counts, ARCHITECTURE capability table, AI_FEATURES, functions README, TASKS status,
    `docs/REGRESSION.md`.
- **Validated:** 188 Hypium + 59 Deno tests green, all functions type-check, strict ArkTS build clean; emulator
  screenshots of Home, medicine sheet, Emergency (found and fixed two bugs: stale card labels after a language switch,
  wrong "nothing is uploaded" hint); Playwright on the card viewer in pl/bg/de, light/dark.
- **Not validated / lessons:** the rest of the emulator walk was stopped because the emulator was in use by hand —
  several sessions sharing one emulator needs a lock. Could not verify a Petal Maps link format (docs page body did
  not load), so nearby help uses the documented Google Maps URL instead of guessing. Translations written by AI need a
  native-speaker check.
