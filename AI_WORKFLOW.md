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
