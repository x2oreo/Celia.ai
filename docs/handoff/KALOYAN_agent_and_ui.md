# Workstream A - Agent experience and UI/UX redesign (Kaloyan)

You are an agent working in the Celia.ai repo. This file is your whole brief. Read it fully, then read `CLAUDE.md`
and `docs/design/DESIGN.md` before touching code. A second agent works in parallel on Workstream B
(`docs/handoff/GEORGI_account_and_emergency.md`): accounts, onboarding, emergency, notifications, platform
integrations. Do not do B's work; the contract between the two is in section 6.

## 1. Project in one paragraph

Celia.ai is a native HarmonyOS app (ArkTS + ArkUI, API 20+) for people with Long QT syndrome (LQTS): an AI agent you
talk to, a deterministic medicine check (type, scan, photograph a box), a watch app that monitors heart rate, an
emergency card and SOS flow, and a doctor-visit brief. Built for HackYeah 2026, Huawei task "Imagine What's Next".
Submission: **Sunday 4 October 2026, 11:00**. A real Huawei phone is available only from Sunday 08:00; until then
everything runs on emulators. Judging: Originality 20, Usefulness 20, Technical execution 20, Platform capabilities
20, Demo 10, Workflow transparency 10. False or misleading claims can disqualify the team.

## 2. Your mission

The owner's words: the design looks all right, but the UX is terrible and overcomplicated; features are nested; the
AI agent must be the centre of everything; talking to it should feel immersive, a glowing orb that is clearly
listening and clearly speaking.

You own: information architecture, the agent screen and orb, the visual and UX pass over every phone screen, agent
quality (prompt, tools, voice testing), the Trends page, and the watch UI look. You do not own: accounts,
onboarding content, emergency features, notifications, backend auth, watch internals.

## 3. Rules that always apply

- Load the relevant skill before writing HarmonyOS code: `arkts-language`, `arkui-development`, `celia-agent`,
  `harmonyos-build-deploy`, `harmonyos-kits`, `lqts-domain`. Verify any API you are unsure of in Context7
  (`/websites/developer_huawei_consumer_cn_doc_harmonyos-guides`, `..._harmonyos-references`). Training-data
  knowledge of HarmonyOS is stale.
- Before any UI decision, read `docs/design/DESIGN.md`. Use its tokens and the resource names in
  `app/entry/src/main/resources/base/element/*.json`. No hard-coded colours or sizes. If DESIGN.md does not cover
  something, extend DESIGN.md first, then build. You own DESIGN.md.
- Native ArkUI only. No blur, no shaders, no web views for UI.
- Strict ArkTS: no `any`, no untyped object literals, no destructuring, no index signatures.
- Medical safety: verdicts and medical content come from deterministic data. The LLM only explains. The UI never
  derives a verdict colour from model output. Never show QT values or ECG-like traces. Heart rate only.
- Everything in English. No secrets in the repo.
- Commit small and often, Conventional Commits, **no AI attribution** in commits or PRs.
- Other sessions edit the same tree. Stage explicit file paths only (never `git add -A` or a directory). Append to
  `string.json`, `color.json`, `float.json` with read-modify-write; never rewrite them from a stale copy.
- Keep `AI_WORKFLOW.md` updated: one entry per session (asked, produced, validated, not validated).
- Honesty: anything simulated carries a visible `SIMULATED` badge. Anything not verified on a device is listed as
  unverified in the README verify table. Never write a claim the code does not back.

## 4. Where things are

All phone paths are under `app/entry/src/main/ets/`.

| Area | Files |
|---|---|
| Root, routing | `pages/Index.ets` (Navigation + `routeMap`), `common/Routes.ets`, `common/TabRequest.ets`, `common/RouteRequest.ets` |
| Tabs | `components/MainTabs.ets`: Agent (renders `HomePage`), Medicines, Heart, Emergency (red SOS pill) |
| Home dashboard | `pages/HomePage.ets` (391 lines): greeting, HR ring, 2 chips, agent card (Scan / Ask), tip, travel banner |
| Agent conversation | `pages/AgentPage.ets` (about 1,100 lines), pushed route `agentChat`; voice and chat modes |
| Orb | `components/VoiceOrb.ets` (163), `components/AgentAvatar.ets` (54); tokens `orb_light`, `orb_mid`, `orb_dark`, `orb_sheen`, `orb_sheen_clear`, `orb_glow` |
| Agent cards | `components/AgentCards.ets`: `ToolStepRow`, `ConfirmCard`, `MedsCard`, `AlternativesCard`, `EmergencyNotice`, `ActionTile`, `ToolUi` labels |
| Live voice | `voice/RealtimeSession.ets` (OpenAI Realtime over WebSocket; `onPhase`, `onLevel`, `onUserPartial`, `onAgentPartial`), `voice/VoiceInput.ets`, `voice/VoiceOutput.ets`, `voice/PcmStreamPlayer.ets` |
| Voice without a mic | `voice/DemoVoice.ets`, clips in `resources/rawfile/voice/*.pcm` |
| Agent core | `agent/AgentCore.ets`, `agent/ToolRegistry.ets`, `agent/tools/*.ets`, `agent/ResponseValidator.ets`, `agent/OfflineAgent.ets`, `safety/SafetyGate.ets` |
| Prompt and tool schemas | `backend/supabase/functions/_shared/prompt.ts` (`PROMPT_VERSION`), `_shared/tools.ts`, `realtime-session/index.ts` (`VOICE_RULES`) |
| Shared UI | `components/Common.ets` (549 lines, 19 structs: `Card`, `NavRow`, `SourceBadge`, buttons, chips) |
| Trends | `pages/TrendsPage.ets`, `components/TrendChart.ets`, `vitals/Trends.ets` |
| Other pages | `MedicinesPage`, `HeartPage`, `ScanPage`, `CheckResultPage`, `HistoryPage`, `RemindersPage`, `SymptomLogPage`, `ChatsPage` |
| Watch UI | `watch/entry/src/main/ets/components/*.ets`, `pages/Index.ets`, colours in `components/Theme.ets` |

### What already works (branch `kaloyan/final-pass`, verified on the phone emulator)

- 15 agent tools. The newest three are read-only: `prepare_doctor_visit(specialty)`, `get_dose_status`,
  `get_trends(days)`. They push an `OPEN_PAGE` action that renders as a tile opening doctor prep (on that
  specialty), reminders or Trends.
- Voice without a microphone: set `DEMO_VOICE_INPUT = 'on'` in the gitignored `common/LocalConfig.ets`. Each new live
  session plays the next clip (ondansetron question, dentist visit, dizzy). Server VAD, transcription, the safety
  gate and the tools run for real. The screen shows a `SIMULATED VOICE INPUT` badge.
- Trends page under Heart → Trends, with labelled demo data when there is no cloud backend.
- Tests: 211 phone, 43 watch, 68 backend, all passing.

### Known UX problems (taps from Home today)

| Feature | Taps | Problem |
|---|---|---|
| Talk to the agent | 2 | The "Agent" tab is a dashboard, not the agent |
| Doctor visit prep | 2 + scroll | Only entry point is the bottom of the Heart tab |
| Symptom log | 2 + scroll | Same |
| Reminders | 2 + scroll | Bottom of Medicines |
| Settings | 1 | Gear exists only on Home |
| Full emergency card | 1 + scroll | Below call button, contacts, three rows and nearby help |
| SOS | 2 | The tab's "SOS" pill only opens the tab |

## 5. Tasks

### Phase 1 - must work and be verified on the emulator before the deadline

**A1. Agent is home.**
Tab 0 becomes the agent itself, not a dashboard that links to it.
- Layout, top to bottom: slim status strip (heart-rate chip with source badge, "N to review" chip, settings gear),
  the orb with its state label, the current thread or the welcome with starter chips, a quick-action row (Scan a
  box, Log how I feel, Doctor prep, Trends), then the dock (camera, mic, keyboard).
- Greeting, tip of the day and travel banner become agent-voiced lines or a single collapsible strip. Nothing from
  the old Home may become unreachable.
- Saved chats stay one tap away. The SOS pill on the tab bar stays always tinted.
- Decide and document in DESIGN.md whether the tab bar stays at four tabs. Do not remove Emergency.
- Write the layout into DESIGN.md (new subsection under §10) before building.
- Acceptance: cold start lands on the orb; one tap starts talking; every feature in the table above is reachable in
  at most 2 taps or one sentence to the agent.

**A2. Immersive orb.**
- Full-height voice stage while a session is live; the orb is the hero. It steps back to compact when a thread
  exists (current behaviour: 168 vp → 84 vp).
- "Glowing" within the rules: layered radial gradients, soft shadow in `orb_glow`, halos. DESIGN.md §6.6a locks the
  gradient (`#FFC2BE → #E5484D → #C7353A`), the seven states and their text labels: neutral (ink) halos mean the
  user is speaking, coral means the agent. Keep that meaning.
- Listening must be felt: halos follow `RealtimeSession.onLevel` (emitted every 70 ms, 0..1). Speaking uses the
  playback level. Thinking and connecting use the orbit arc.
- Every state keeps a text label (never colour or motion alone). "The microphone never opens by itself."
- Reduced motion: `common/Motion.ets` has `Motion.reduced` hard-coded `false`. Read the system setting and drop
  loops to static when it is on.
- No pulse-line or waveform that could read as an ECG.
- Acceptance: on the emulator with `DEMO_VOICE_INPUT`, a session visibly passes through connecting → listening →
  hearing → thinking → speaking → listening, with screenshots of each.

**A3. Split `AgentPage.ets`.**
Move the voice stage, the thread renderer, the chat bar and the action-card switch into `components/agent/`.
Behaviour must not change: `onMic()` order (live session → tap-to-talk), `OPEN_PAGE` tiles, the demo badge, the
"type instead" strip, restored chats keeping only display cards (`model/Chat.ets` `keepOnRestore`).

**A4. Test and improve the agent.**
- Loop: start the local backend, forward the port, run the app with demo voice (commands in section 7).
- Not yet exercised: `get_dose_status` and `get_trends` by voice, barge-in, mute, tap-to-talk fallback. Add clips
  for them. Make a clip with:
  `say -v Daniel -o x.aiff "text" && afconvert -f WAVE -d LEI16@24000 -c 1 x.aiff x.wav`, strip the WAV header to
  raw PCM16 mono 24 kHz, save as `resources/rawfile/voice/<name>.pcm`, add the name to `CLIPS` in
  `voice/DemoVoice.ets`.
- Run `backend/eval/agent-eval.ts` after any prompt or tool change. Bump `PROMPT_VERSION` when the prompt changes.
- The agent page's camera button opens the gallery (`PhotoViewPicker`). Either open a real camera capture (verify
  the API) or change the icon and label to match.
- More tools so the agent reaches everything: open symptom log, open reminders, open the emergency responder view
  (route supplied by Workstream B). A write tool must use the confirm-card pattern (`PendingKind` in
  `agent/ToolTypes.ets`, `AgentCore.resolveAction`); never write on the model's say-so.
- Tool names must match in three places: `agent/ToolRegistry.ets`, `_shared/tools.ts`, and `BACKEND_TOOLS` in
  `app/entry/src/test/AgentSafety.test.ets`. Add step labels in `components/AgentCards.ets` (`ToolUi`).
- New tool schemas reach users only after `agent` and `realtime-session` are redeployed. Ask the owner to deploy;
  do not deploy yourself.

**A5. UX pass over every screen you own.**
Medicines, Heart, Scan, Check result, History, Reminders, Symptom log, Chats, Trends. For each: one primary action,
no dead ends, buried links moved up or turned into quick actions, consistent header with a way back and to
settings. Fix on the way: `accessibilityText` on every control (files with none: `HeartPage`, `CheckResultPage`,
`HistoryPage`, `SymptomLogPage`, `ChatsPage`, `MainTabs`, `VerdictCard`, `HrRing`, `HrChart`, `VoiceOrb`,
`AgentCards`, `MedicineDetailSheet`, `IntakeCard`), the greeting that says "Morning" at 01:10, 9 numeric
`.fontSize(n)` calls, 23 hard-coded UI strings.
Pages owned by Workstream B (Onboarding, Emergency, Responder, Settings, Privacy, Doctor prep, SOS, Bystander,
Pharmacy card, Pair watch): give B the layout rules through DESIGN.md; restyle them yourself only after B says the
feature is merged.

**A6. Trends with real data.**
Point `LocalConfig` at the deployed Supabase project (not `127.0.0.1`) and confirm the page with real watch rows:
14 and 30 days, gaps, insights list, offline empty state.

### Phase 2 - more. Build after Phase 1 is merged; may ship unverified if labelled so

- **A7. Watch UI redesign** (look only; internals belong to B): colours from resources instead of `Theme.ets` hex
  strings, minimum 11 fp text, one action per screen, crown rotation and Arc components (`ArcButton`, `ArcList`;
  verify in Context7), DESIGN.md §7.
- **A8. Dark mode** for the phone (DESIGN.md §2.2 is a proposal, not drawn).
- **A9. Celia / system assistant.** 7 intents exist in `insightintents/` and `resources/base/profile/
  insight_intent.json`; whether Celia routes to third-party intents is unverified. Test on the real phone at 08:00
  ("Celia, can I take ondansetron?"). Research the A2A agent path (`AgentExtensionAbility`, agent card; needs an
  agent id from the Xiaoyi Open Platform) and write down exactly what access is needed.
- **A10. `log_dose` as a confirmed write tool**, and richer quick replies after a verdict.
- **A11. Agent persona name** (open decision D10 in `docs/PRODUCT.md`): propose, do not decide.

## 6. Contract with Workstream B

| Thing | Owner | Rule |
|---|---|---|
| `model/Profile.ets`, `data/LocalStore.ets` profile methods | B | You read; ask B for new fields |
| `account/Session.ets` (new: `Session.isSignedIn()`, `Session.userName()`) | B | You only call it (greeting, settings entry) |
| Routes | Each adds their own constants to `common/Routes.ets` and their own branch in `pages/Index.ets` `routeMap` | B adds `responder`, `account`, `welcome`; you already added `trends` |
| Quick actions on the agent home | You | B gives you a route name; you place the tile |
| `OPEN_PAGE` pages | You | Add a `page` value in `model/AgentTypes.ets` and a tile in the agent thread |
| DESIGN.md | You | B may append a subsection for a new screen using existing tokens |
| `string.json` and other resource files | Both | Append-only |
| `watch/` | UI look: you (Phase 2). Controller, sync, sensors, energy: B | |
| `backend/` | Prompt, tools, AI functions: you. Auth, tables, RLS, SOS, push: B | |

Merge to `main` at least every 2-3 hours. `main` must always build. If you must touch a file B owns, keep it to a
small addition and say so in the commit body.

## 7. Build, run, test

```bash
# phone
app/scripts/test.sh                       # 211 unit tests, no device needed
app/scripts/run.sh [screenshot.jpeg]      # build → install → launch → screenshot (emulator 127.0.0.1:5555)
app/scripts/ui.sh list | tapt "text" | tap X Y | swipe X1 Y1 X2 Y2 | back | shot [file]

# local AI backend for the emulator (paid OpenAI calls)
set -a; source backend/supabase/functions/.env; set +a
npx -y deno@2 run -A backend/eval/dev-backend.ts &
source app/env.sh && hdc rport tcp:8000 tcp:8000
# LocalConfig.ets: BACKEND_URL = 'http://127.0.0.1:8000', SUPABASE_ANON_KEY = 'local-dev', DEMO_VOICE_INPUT = 'on'

# backend and watch
npx -y deno test --no-lock backend/supabase/functions/           # 68 tests
cd watch && source env.sh && hvigorw test -p module=entry -p coverage=false --no-daemon   # 43 tests

# logs
hdc shell hilog -x | grep CeliaAI
```

If the emulator drops off hdc: `/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator -hvd "Pura 90"`.
Set `DEMO_VOICE_INPUT` back to `''` before a real-phone build: while it is on, the microphone never opens.

## 8. Done means

- All three test suites pass and both apps build.
- Each Phase 1 task has a screenshot from the emulator and a line in `AI_WORKFLOW.md` saying what was and was not
  validated.
- README "How to verify each feature" has a row for every new or moved feature.
- DESIGN.md describes what was built.
