# AI workflow

How AI tools were used to build Celia.ai, as required by Challenge Rules §4 (deliverable 6). The top of this file is
a summary; the [session log](#sessions) below it is append-only, one entry per working session, written as we went.
The AI features that ship inside the product (models, inference flow, validation, privacy) are described separately
in [`AI_FEATURES.md`](AI_FEATURES.md).

## Contents

1. [Summary](#summary)
2. [Tools, models and MCP servers](#tools-models-and-mcp-servers)
3. [Reusable instructions: CLAUDE.md and Agent Skills](#reusable-instructions-claudemd-and-agent-skills)
4. [How we worked: ideation to debugging](#how-we-worked-ideation-to-debugging)
5. [How AI output was reviewed and tested](#how-ai-output-was-reviewed-and-tested)
6. [Limitations, failed approaches and lessons](#limitations-failed-approaches-and-lessons)
7. [Pre-existing work and third-party components](#pre-existing-work-and-third-party-components)
8. [Session log index](#session-log-index)
9. [Sessions](#sessions) (the full log)

## Summary

- **One coding agent, many sessions.** Every line of code, data and docs in this repo was written during the
  challenge by three team members (Kaloyan, Mark, Georgi), each working with **Claude Code** (Claude Opus 5.5).
  Larger pieces ran as several Claude Code sessions in parallel (git worktrees, one integrator session that merges).
- **Thin platform knowledge, fixed by grounding.** HarmonyOS / ArkTS is badly covered in model training data, so the
  agent was made to check APIs before writing them: **Context7 MCP** for the HarmonyOS guides and API references
  (and the OpenAI API docs), the SDK's own `.d.ts` files when Context7 was missing, and nine project **Agent Skills**
  in `.claude/skills/`.
- **`CLAUDE.md` is the main reusable instruction.** It sets the platform (API 20 minimum, emulator), strict ArkTS,
  the design-system rule, the safety rule ("verdicts come from deterministic data; the LLM only explains"), no
  secrets, no em dashes, and no AI attribution in commits.
- **Humans decide, the agent proposes.** Plans, design choices and every medical rule were approved by the developer
  in the session; commits are made by the team members themselves.
- **Verified by running it.** Strict ArkTS builds with no warnings, Hypium unit tests (418 phone and 99 watch at
  the last README count), 75 Deno tests for the Edge Functions, a paid live eval of the AI layer
  (`backend/eval/`), and the agent driving the emulator itself (`hdc`, `uitest`, screenshots it reads back).
- **In the product,** the AI is OpenAI (Responses API, Realtime, transcription, TTS) behind Supabase Edge Functions;
  see [`AI_FEATURES.md`](AI_FEATURES.md).

## Tools, models and MCP servers

| Tool / model | Where | What it was used for |
|---|---|---|
| **Claude Code** with **Claude Opus 5.5** | Development (all team members) | Research, planning, architecture, ArkTS / TypeScript / SQL code, tests, emulator testing, docs, landing page, deck, film |
| Claude Code sub-agents and parallel sessions | Development | Read-only research agents, a test agent for the live eval, three parallel track sessions plus one integrator (separate git worktrees) |
| **Context7 MCP** | Development | Current docs: HarmonyOS guides and references (`/websites/developer_huawei_consumer_cn_doc_harmonyos-guides`, `..._harmonyos-references`) and the OpenAI API (`/websites/developers_openai_api`). When it was not connected, the agent read developer.huawei.com, the OpenHarmony docs repo and the SDK `.d.ts` files instead (noted in those sessions) |
| **Supabase MCP** | Development | Deploying an Edge Function (`med-info`, with the JWT check on) in one session |
| Playwright / headless Chrome | Development only | Rendering and checking the web pages (share viewer, landing page) and the slide deck, printing the deck to PDF |
| Claude Design | Design (owner) | The v2 visual design of the app screens and the "Dawn" silk orb, applied in code by Claude Code sessions |
| Agent Skills (`.claude/skills/`) | Development | Project knowledge loaded on demand, see the next section |
| **OpenAI API** (`gpt-6.1-sol`, `gpt-realtime-2.1`, `gpt-transcribe`, `gpt-4o-mini-tts`) | **In the product** | The in-app agent and its helpers, behind our Edge Functions. Model choice and validation: [`AI_FEATURES.md`](AI_FEATURES.md) |
| Kokoro-82M (`kokoro-onnx`), OpenAI Whisper | Launch film only, run locally | Voices for the film; Whisper only checks that every spoken line is intelligible. Not shipped in the app |

## Reusable instructions: CLAUDE.md and Agent Skills

**`CLAUDE.md`** (repo root) is loaded into every Claude Code session. It holds the project idea, the platform and
stack, and the rules every agent follows: verify HarmonyOS APIs via Context7 before writing them, read
`docs/design/DESIGN.md` before any UI work and use its tokens, write strict ArkTS, do not port React/Android
patterns, build through the terminal loop, English only, no em dashes, no secrets, small commits without AI
attribution, deterministic medical verdicts with validated model output, and keep this file updated.

**Agent Skills** (`.claude/skills/<name>/SKILL.md`), written for this project at the start of the challenge:

| Skill | One line |
|---|---|
| `harmonyos-docs` | Where to get authoritative HarmonyOS / ArkTS docs (Context7 ids, official pages); the router to the other skills |
| `hackyeah-huawei` | The task text, Challenge Rules, hard requirements (API 20+, emulator, `.hap`), the 7 deliverables and judging |
| `celia-agent` | Making the app agent-native: Agent Framework Kit, A2A, Intents Kit (`@InsightIntentEntry`), in-app agent, AI safety rules |
| `lqts-domain` | LQTS medical knowledge: genotypes and triggers, CredibleMeds risk categories, emergency facts, safety design |
| `arkts-language` | Strict ArkTS rules and the fix for each `arkts-no-*` compiler error |
| `arkui-development` | ArkUI components, V1/V2 state management, Navigation, resources, dialogs, animation |
| `harmonyos-app-model` | Stage model project config: `app.json5`, `module.json5`, abilities, permissions, HAP/HAR/HSP |
| `harmonyos-build-deploy` | The terminal loop: `hvigorw` build, signing, `hdc` install / launch / logs / screenshots, emulator |
| `harmonyos-kits` | Catalog of `@kit.*` system kits with minimal patterns (network, storage, AI, speech, vision, scan, widgets...) |

Other reusable instructions in the repo: `docs/design/DESIGN.md` (design tokens, risk language, voice and copy
rules, read before any UI change), the track briefs in `docs/handoff/` (used to split work across parallel
sessions), and the in-product prompts in `backend/supabase/functions/_shared/prompt.ts` (versioned, see
`AI_FEATURES.md`).

## How we worked: ideation to debugging

1. **Ideation.** Ideas were brainstormed with Claude Code against the official task text, the Challenge Rules (both
   in the `hackyeah-huawei` skill and `docs/hackathon/`) and our team's earlier LQTS web app (design reference only,
   see below). The team chose the idea ("an agent you talk to, verdicts from fixed data"); `docs/IDEA.md` and
   `docs/PRODUCT.md` were written and kept current with the agent's help.
2. **Architecture.** The agent proposed options and the developer picked them in the session: the tool loop runs on
   the phone and the backend is a stateless relay; OpenAI as provider; on-device OCR and speech first with cloud
   fallbacks; write actions need a confirm card; a red-flag gate runs before any model call. See
   `docs/ARCHITECTURE.md`.
3. **Implementation.** Feature by feature, each session in its own branch: AI layer (Kaloyan), watch app and SOS
   backend (Mark), app features and platform kits (Georgi). Bigger workstreams were split into parallel Claude Code
   sessions with a written brief per track, a list of owned files, an emulator lock (`app/scripts/emu.sh`) and one
   integrator who merges.
4. **Testing.** Unit tests are written with the code (Hypium for ArkTS, Deno for the Edge Functions). A paid live eval
   harness (`backend/eval/`) runs the real functions against the real OpenAI API with device-identical tool outputs.
   Claude Code drives the emulator itself: unsigned `hdc install`, `uitest uiInput` taps, `uitest dumpLayout`, and
   screenshots it reads back (`app/scripts/ui.sh`).
5. **Debugging.** hilog filtered on the `CeliaAI` domain, the SDK's `.d.ts` files as ground truth for API shapes,
   clean-worktree builds before every push, and a fix-then-re-run loop on every eval failure. Each session entry
   records what was validated and, just as important, what was not.

## How AI output was reviewed and tested

- **Every session ends with a written check.** Each log entry has "Validated" and "Not validated" lines, so claims
  that were not tested stay visible.
- **Builds and tests.** `hvigorw assembleHap` with strict ArkTS and zero warnings; `app/scripts/test.sh` (Hypium);
  `deno check` and `deno test` for the backend; RLS checks (`backend/supabase/tests/run-rls.sh`).
- **Live AI eval.** `backend/eval/agent-eval.ts` (24 agent cases with PASS / SAFE (caught) / FAIL outcomes and a
  false-positive count), `audio-eval.ts`, `vision-eval.ts`, `realtime-smoke.ts`, and free request-validation checks.
  The eval found real bugs (typographic apostrophes, Polish reassurance, off-topic answers, status pass-through)
  that were fixed and re-tested; see the 2026-10-03 eval entries.
- **On the emulator.** Flows were walked through by the agent with screenshots, and by the team by hand.
- **Human review.** The developer approved plans and medical rules, read the diffs, and committed. Medical facts
  were checked against the `lqts-domain` skill and its sources; model output in the product is never trusted
  without the validator.

## Limitations, failed approaches and lessons

**Limitations of the AI workflow**
- HarmonyOS knowledge in the model is thin and often from the old Java / FA-model era; without Context7 or the SDK
  `.d.ts` files the agent guessed wrong import paths and APIs.
- Several sessions in one working tree could see each other's uncommitted files; one emulator shared by many
  sessions needed a lock.
- Some things could not be verified by the agent: a real Huawei phone and watch, Celia's routing of third-party
  intents outside China, Core Speech English, camera capture, and how the film sounds to a human ear.

**Failed approaches and things we changed course on**
- hvigor skipped unreferenced files, so new modules "compiled" until they were imported and then failed.
- The first emergency regex matched "help me find an alternative"; JavaScript `\b` does not work next to Polish
  letters. Both were narrowed and covered by tests.
- The response validator first missed typographic apostrophes (`it’s safe`), had no Polish patterns, and flagged a
  correct "that does not mean it is safe" as reassurance. Found by the live eval, then fixed.
- The model happily wrote a pizza poem until the prompt got an off-topic rule.
- Hosting the share pages on Supabase failed (Edge Functions and Storage serve HTML as plain text); they moved to
  static pages on Vercel with the data encrypted on the phone.
- `@Builder` arguments are passed by value, so screens showed stale values; this bit three times in one night.
- A commit carried another session's imports and did not build on its own; from then on every push was built and
  tested in a clean worktree first.

**Lessons**
- Ground the agent in docs and the SDK before it writes platform code; skills plus Context7 paid for themselves.
- Keep medical decisions out of the model and test the guard rails with a paid eval, not by reading prompts.
- Parallel agent sessions work when each owns a list of files and only one session merges.
- Write the log as you go: "not validated" lines are what kept the README and demo honest.

## Pre-existing work and third-party components

Everything not listed here was written in this repo during the challenge. The README's "Pre-existing / third-party
components" paragraph lists the same items.

**Earlier work and templates**
- **HeartBeat / QTShield** (`github.com/x2oreo/HeartBeat`) is our team's earlier LQTS web app. It was used as
  **design reference only**: Claude Code read it and summarised what worked and what didn't. No code, prompts or data
  were copied. Everything in this repo was written fresh during the challenge.
- DevEco Studio 6.1.1 project template (Empty Ability: hvigor files, `EntryAbility` skeleton, Hypium test harness,
  default icons) for both `app/` and `watch/`.

**Libraries**
- `@ohos/hypium` (1.0.24 in `app/`, 1.0.29 in `watch/`) and `@ohos/hamock` 1.0.0 (test framework, ohpm).
- Lucide icons (`lucide-static` 1.51.0, ISC licence): the phone app's `ic_*.svg` glyphs, strokes outlined to fills
  with `oslllo-svg-fixer` so ArkUI `fillColor` can tint them. The risk shapes (`ic_risk_*`) are our own.
- `@supabase/supabase-js` 2.x (in the `sos`, `drug-check` and `box-identify` Edge Functions), `@std/assert` 1.x (jsr,
  Deno tests).
- `npm:jose@5` (npm, in the `sos` Edge Function and its test): signs the service-account JWT (PS256) for Huawei Push
  Kit.

**External services and public APIs**
- OpenAI API (the in-product AI, see `AI_FEATURES.md`). Hosting: Supabase (Edge Functions, Postgres, Storage) and
  Vercel (static viewer pages in `site/`, which hold no data).
- Twilio Programmable Messaging + Voice REST API (external service for SOS SMS and calls; keys in Supabase secrets).
- Huawei Push Kit server API (external service for the watch-SOS push to the patient's phone; service-account
  key goes in Supabase secrets, not set yet). `rawfile/sos_live.png` (Live View picture) was generated by a script in
  this repo, not a third-party asset.
- Public medicine APIs called by `/drug-check` and `/box-identify`: NLM RxNav, openFDA drug labels, AEMPS CIMA,
  UPCitemdb (free trial API) and Open Food / Products / Beauty Facts (ODbL). Only a medicine name or a barcode is
  sent.
- Google Maps search URLs for "nearby help" (no key, no location sent by the app).

**Data sources** (curated into our own files; the list is a demo subset, not a medical device)
- Drug risk categories from the public CredibleMeds QTdrugs lists; brand names from the Polish (URPL) and Bulgarian
  (BDA) medicine registers; box barcodes and product data from the Polish medicines register export; WHO ATC
  index; GS1 country prefixes; emergency numbers from the EU 112 pages; CPR guidance from ERC / AHA; genotype
  triggers from Schwartz et al. (2001) and the HRS/EHRA/APHRS 2013 consensus. Details in README "Data sources".

**Media and web**
- The three demo voice clips in `app/entry/src/main/resources/rawfile/voice/` were made with the macOS system voice
  (`say`); they stand in for the microphone on the emulator when `DEMO_VOICE_INPUT` is on.
- Figtree variable font (SIL OFL 1.1, Fontsource build), self-hosted in `site/assets/fonts/` for the landing page
  (and copied to `deck/assets/` for the deck; also used in the film).
- GSAP 3.13 + ScrollTrigger (GSAP standard no-charge licence) and Lenis 1.3 (MIT), self-hosted in
  `site/assets/vendor/` for the landing page's scroll animations and smooth scrolling.
- Lucide icons (ISC, `lucide-static` 0.544.0) inlined as an SVG sprite in the landing page; licence in
  `site/assets/vendor/LUCIDE-LICENSE.txt`.
- Remotion 4.0 (`remotion`, `@remotion/cli`, `@remotion/bundler`, `@remotion/renderer`, `@remotion/google-fonts`;
  Remotion licence, free for teams of up to 3), React 19 and JetBrains Mono (SIL OFL 1.1, Google Fonts, fetched at
  render time) for the launch film in `video/`.
- Film sound, in `video/`: Kokoro-82M voice model (Apache-2.0 weights) run locally with `kokoro-onnx` (MIT) for the
  voiceover and the in-app voices; OpenAI Whisper (MIT) run locally only to check that every spoken line is
  intelligible in the final mix (not shipped). The score and effects are synthesized from code
  (`video/scripts/audio/`, with numpy, scipy and soundfile), with no samples or stock music.
- Deck tooling (not shipped): headless Chrome via Playwright for screenshots and PDF printing, `pypdf` to embed the
  demo video in the PDF.

## Session log index

Entries are in the order they were appended, not strictly by time (several people and sessions worked in parallel).

**AI layer, voice and agent UI (Kaloyan)**

| # | Date | Session |
|---|---|---|
| 1 | 2026-10-03 | [AI layer research, plan and first implementation](#2026-10-03---ai-layer-research-plan-and-first-implementation-kaloyan) |
| 2 | 2026-10-03 | [Voice, photo, Realtime, Intents](#2026-10-03-cont---voice-photo-realtime-intents-kaloyan) |
| 3 | 2026-10-03 | [Model selection and first live calls](#2026-10-03-cont---model-selection-and-first-live-calls-kaloyan) |
| 4 | 2026-10-03 | [Live eval of the AI layer](#2026-10-03-cont---live-eval-of-the-ai-layer-kaloyan-with-a-claude-code-test-agent) |
| 5 | 2026-10-03 | [Fixing what the live eval found](#2026-10-03-cont---fixing-what-the-live-eval-found-kaloyan-with-claude-code) |
| 6 | 2026-10-03 | [Merging the app from main and wiring the AI into it](#2026-10-03-cont---merging-the-app-from-main-and-wiring-the-ai-into-it-kaloyan-with-claude-code) |
| 7 | 2026-10-03 | [Testing on the emulator, driven by Claude Code](#2026-10-03-cont---testing-on-the-emulator-driven-by-claude-code-kaloyan) |
| 8 | 2026-10-03 | [UI redesign to the design system](#2026-10-03-cont---ui-redesign-to-the-design-system-kaloyan-with-claude-code) |
| 9 | 2026-10-03 | [Voice-first conversation with the agent](#2026-10-03-cont---voice-first-conversation-with-the-agent-kaloyan-with-claude-code) |

**Watch app, SOS backend and watch data (Mark)**

| # | Date | Session |
|---|---|---|
| 10 | 2026-10-03 | [Watch app](#2026-10-03---mark--claude-code-watch-app) |
| 11 | 2026-10-03 | [SOS backend (parallel session, branch `sos-backend`)](#2026-10-03---mark--claude-code-sos-backend-parallel-session-branch-sos-backend) |
| 12 | 2026-10-03 | [Missed beta-blocker check](#2026-10-03---mark--claude-code-missed-beta-blocker-check-branch-beta-blocker-check) |
| 13 | 2026-10-03 | [Watch data the phone was ignoring](#2026-10-03---mark--claude-code-watch-data-the-phone-was-ignoring) |
| 14 | 2026-10-03 | [Using watch doses and "How do you feel?" answers](#2026-10-03---mark--claude-code-using-watch-doses-and-how-do-you-feel-answers) |

**App features on `app_development` (Georgi)**

| # | Date | Session |
|---|---|---|
| 15 | 2026-10-03 | [Emergency-card link fallbacks and branch merges](#2026-10-03---georgi--claude-code-emergency-card-link-fallbacks-and-branch-merges-branch-app_development) |
| 16 | 2026-10-03 | [Chat history and new chats for the agent](#2026-10-03---georgi--claude-code-chat-history-and-new-chats-for-the-agent-branch-app_development) |
| 17 | 2026-10-03 | [Medicine info and a redesigned reminders page](#2026-10-03---georgi--claude-code-medicine-info-and-a-redesigned-reminders-page-branch-app_development) |
| 18 | 2026-10-03 | [Encrypted share links for the emergency card and doctor report](#2026-10-03---georgi--claude-code-encrypted-share-links-for-the-emergency-card-and-doctor-report-branch-app_development) |
| 19 | 2026-10-03 | [Online check for any medicine, step 1](#2026-10-03---georgi--claude-code-online-check-for-any-medicine-step-1-branch-app_development) |
| 20 | 2026-10-03 | [Everything on Supabase, so links work from any device](#2026-10-03---georgi--claude-code-everything-on-supabase-so-links-work-from-any-device-branch-app_development) |
| 21 | 2026-10-03 | [Identify any medicine box by barcode, online](#2026-10-03---georgi--claude-code-identify-any-medicine-box-by-barcode-online-branch-app_development) |
| 22 | 2026-10-04 | [Scanning a box showed nothing](#2026-10-04---georgi--claude-code-scanning-a-box-showed-nothing-branch-app_development) |
| 23 | 2026-10-03 | [Finish what the docs still promised, then a regression pass](#2026-10-03---georgi--claude-code-finish-what-the-docs-still-promised-then-a-regression-pass-branch-app_development) |

**Phone app integration, v2 design and Health tab (Kaloyan)**

| # | Date | Session |
|---|---|---|
| 24 | 2026-10-03 | [Get the phone app ready for a real Huawei device](#2026-10-03---kaloyan--claude-code-get-the-phone-app-ready-for-a-real-huawei-device-branch-main) |
| 25 | 2026-10-03 (evening) | [Final-pass plan, honesty fixes, voice without a mic, Trends](#2026-10-03-evening---kaloyan--claude-code-final-pass-plan-honesty-fixes-voice-without-a-mic-trends-branch-kaloyanfinal-pass) |
| 26 | 2026-10-03 (night) | [Workstream A in three parallel agent sessions and one integrator](#2026-10-03-night---kaloyan--claude-code-workstream-a-in-three-parallel-agent-sessions-and-one-integrator-branch-kaloyanagent-home) |
| 27 | 2026-10-03 (night) | [Interactions everywhere a medicine is handled](#2026-10-03-night---kaloyan--claude-code-interactions-everywhere-a-medicine-is-handled-branch-kaloyanagent-home) |
| 28 | 2026-10-04 (early) | [Doctor visits as a history of pages](#2026-10-04-early---kaloyan--claude-code-doctor-visits-as-a-history-of-pages-branch-kaloyanagent-home) |
| 29 | 2026-10-04 (early morning) | [The owner's v2 design applied; integrator re-check](#2026-10-04-early-morning---kaloyan--claude-code-the-owners-v2-design-applied-integrator-re-check-branch-kaloyanagent-home) |
| 30 | 2026-10-04 (morning) | [Health tab with every watch metric and one chart system](#2026-10-04-morning---kaloyan--claude-code-health-tab-with-every-watch-metric-and-one-chart-system-branch-kaloyanagent-home) |
| 31 | 2026-10-04 (morning) | [Real watch data on the phone, with a Watch / Simulated switch](#2026-10-04-morning---kaloyan--claude-code-real-watch-data-on-the-phone-with-a-watch--simulated-switch-branch-kaloyanagent-home) |
| 43 | 2026-10-04 (night) | [Workstream B merged into the v2 app, live backend deployed](#2026-10-04-night---kaloyan--claude-code-workstream-b-merged-into-the-v2-app-live-backend-deployed-branch-kaloyanagent-home) |
| 44 | 2026-10-04 | [60 days of simulated watch history](#2026-10-04---kaloyan--claude-code-60-days-of-simulated-watch-history-branch-kaloyanagent-home) |
| 45 | 2026-10-04 | [Watch readings per account, kept on the phone](#2026-10-04---kaloyan--claude-code-watch-readings-per-account-kept-on-the-phone-branch-kaloyanagent-home) |
| 46 | 2026-10-04 | [Settings rebuilt as a grouped index](#2026-10-04---kaloyan--claude-code-settings-rebuilt-as-a-grouped-index-branch-kaloyanagent-home) |
| 47 | 2026-10-04 | [Layered emergency card with more about LQTS](#2026-10-04---kaloyan--claude-code-layered-emergency-card-with-more-about-lqts-branch-kaloyanagent-home) |
| 48 | 2026-10-04 | [Profile photo for the emergency card](#2026-10-04---kaloyan--claude-code-profile-photo-for-the-emergency-card-branch-kaloyanagent-home) |
| 49 | 2026-10-04 | [`main` merged into `kaloyan/agent-home`, then to `main`](#2026-10-04---kaloyan--claude-code-main-merged-into-kaloyanagent-home-then-to-main) |

**Workstream B: platform kits, accounts, emergency, onboarding (Georgi)**

| # | Date | Session |
|---|---|---|
| 32 | 2026-10-03 | [Platform research for Push, Live View, phone ↔ watch, HUAWEI ID](#2026-10-03---georgi--claude-code-platform-research-for-push-live-view-phone--watch-huawei-id-branch-georgib-research) |
| 33 | 2026-10-04 | [Watch internals, energy, background research](#2026-10-04---georgi--claude-code-watch-internals-energy-background-research-branch-georgib-watch) |
| 34 | 2026-10-03 | [Doctor visits with questions (B6) and feeling diary (B15)](#2026-10-03---georgi--claude-code-doctor-visits-with-questions-b6-and-feeling-diary-b15-branch-georgib-doctor) |
| 35 | 2026-10-03 | [Actionable notifications and an honest watch SOS](#2026-10-03---georgi--claude-code-actionable-notifications-and-an-honest-watch-sos-branch-georgib-notify-sos) |
| 36 | 2026-10-04 | [Live View, lock-screen medical ID and Push Kit](#2026-10-04---georgi--claude-code-live-view-lock-screen-medical-id-and-push-kit-branch-georgib-notify-sos) |
| 37 | 2026-10-04 | [Accounts and profile backup](#2026-10-04---georgi--claude-code-accounts-and-profile-backup-branch-georgib-accounts) |
| 38 | 2026-10-04 | [SOS contacts under the account and RLS by account (B10, B9)](#2026-10-04---georgi--claude-code-sos-contacts-under-the-account-and-rls-by-account-b10-b9-branch-georgib-accounts) |
| 39 | 2026-10-04 | [Configurable emergency profile and first-responder view](#2026-10-04---georgi--claude-code-configurable-emergency-profile-and-first-responder-view-branch-georgib-emergency) |
| 40 | 2026-10-04 | [NFC handover of the emergency card, B14](#2026-10-04---georgi--claude-code-nfc-handover-of-the-emergency-card-b14-branch-georgib-emergency) |
| 41 | 2026-10-03 | [8-step onboarding](#2026-10-03---georgi--claude-code-8-step-onboarding-branch-georgib-onboarding) |
| 42 | 2026-10-04 | [Merging Workstream B into georgi/integration](#2026-10-04---georgi--claude-code-merging-workstream-b-into-georgiintegration) |

**Widgets, launch film and decks (Georgi)**

| # | Date | Session |
|---|---|---|
| 50 | 2026-10-04 | [Home-screen widgets v2](#2026-10-04---georgi--claude-code-home-screen-widgets-v2-branch-georgib-widgets-from-kaloyanagent-home) |
| 51 | 2026-10-04 | [Launch film as code (`video/`)](#2026-10-04---georgi--claude-code-launch-film-as-code-video) |
| 52 | 2026-10-04 | [Launch film on the v2 design, with sound](#2026-10-04---georgi--claude-code-launch-film-on-the-v2-design-with-sound) |
| 53 | 2026-10-04 | [Submission deck (`deck/`)](#2026-10-04---georgi--claude-code-submission-deck-deck) |
| 54 | 2026-10-04 | [Sport & Healthcare deck (`deck/sport-health.html`)](#2026-10-04---georgi--claude-code-sport--healthcare-deck-decksport-healthhtml) |

**Submission hardening and documentation (Georgi)**

| # | Date | Session |
|---|---|---|
| 55 | 2026-10-04 | [Whole-repo security and quality review](#2026-10-04---georgi--claude-code-whole-repo-security-and-quality-review-high-and-medium-fixes) |
| 56 | 2026-10-04 | [Documentation audit and one README](#2026-10-04---georgi--claude-code-documentation-audit-and-one-readme) |

## Sessions

### 2026-10-03 - AI layer research, plan and first implementation (Kaloyan)

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

### 2026-10-03 (cont.) - voice, photo, Realtime, Intents (Kaloyan)

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

### 2026-10-03 (cont.) - model selection and first live calls (Kaloyan)

**Prompt:** "Research latest OpenAI models, pick best quality/cost - thinking of gpt-6.1-sol."

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

### 2026-10-03 (cont.) - live eval of the AI layer (Kaloyan, with a Claude Code test agent)

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

### 2026-10-03 (cont.) - fixing what the live eval found (Kaloyan, with Claude Code)

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

### 2026-10-03 (cont.) - merging the app from main and wiring the AI into it (Kaloyan, with Claude Code)

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

### 2026-10-03 (cont.) - testing on the emulator, driven by Claude Code (Kaloyan)

**Prompt:** "i started emulator in deveco studio - think how you can come to use it yourself and test things out"

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


### 2026-10-03 (cont.) - UI redesign to the design system (Kaloyan, with Claude Code)

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

### 2026-10-03 (cont.) - voice-first conversation with the agent (Kaloyan, with Claude Code)

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

### 2026-10-03 - Mark + Claude Code: watch app
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

### 2026-10-03 - Mark + Claude Code: SOS backend (parallel session, branch `sos-backend`)
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

### 2026-10-03 - Mark + Claude Code: missed beta-blocker check (branch `beta-blocker-check`)
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

### 2026-10-03 - Mark + Claude Code: watch data the phone was ignoring
- **Asked:** check what the watch sends that the phone doesn't use yet.
- **Found (AI, from the code on main):** the phone's `WatchCloudSource` uses `vitals`, `sos`, `fall_detected`,
  `hr_recovery` and `vitals_alert`, but ignores `medication_taken`, `symptom` and `wear_state`.
- **Produced:** migration `…240000_watch_phone_views.sql` with three read-only views for the phone team:
  `watch_status` (ON_WRIST / OFF_WRIST / OFFLINE), `watch_doses` (doses confirmed on the watch) and
  `watch_symptoms`. Phone code was left to the phone team (newer app on `app_development`).
- **Validated:** all migrations applied in order on a local Postgres 17 (except `pg_net`, which is Supabase-only);
  the views were checked with test rows: wear state, offline detection, empty names and unknown symptom kinds
  filtered out, simulated rows labelled.

### 2026-10-03 - Mark + Claude Code: using watch doses and "How do you feel?" answers
- **Asked:** make the watch's "Took nadolol" taps and symptom answers useful beyond a log.
- **Produced:** migration `…250000_watch_insights.sql`: `watch_daily_summary` (per-day doses, symptoms, alerts,
  resting HR) and `watch_insights` (fixed rules with fixed texts: symptom within 24 h of a QT-risk drug, fainting,
  repeated symptoms, no dose logged in 26 h). The `sos` function now adds the last watch dose and any symptom from
  the last hour to the SMS and call. `docs/team/watch-data-for-phone.md` hands the phone/agent wiring to Georgi
  and Kaloyan; the missed-dose nudge was handed to the watch session as a spec.
- **Validated:** all migrations on a local Postgres 17 with test rows (each insight fires once, `fine` answers and
  old symptoms are ignored, wording checked); 10 Deno tests for the SOS message pass (3 new) and `deno check` passes.
- **Not yet validated:** the new SOS text over real Twilio; the views on Supabase (migration not pushed yet).

### 2026-10-03 - Georgi + Claude Code: emergency-card link fallbacks and branch merges (branch `app_development`)
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

### 2026-10-03 - Georgi + Claude Code: chat history and new chats for the agent (branch `app_development`)
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

### 2026-10-03 - Georgi + Claude Code: medicine info and a redesigned reminders page (branch `app_development`)
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


### 2026-10-03 - Georgi + Claude Code: encrypted share links for the emergency card and doctor report (branch `app_development`)
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

### 2026-10-03 - Georgi + Claude Code: online check for any medicine, step 1 (branch `app_development`)
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

### 2026-10-03 - Georgi + Claude Code: everything on Supabase, so links work from any device (branch `app_development`)
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

### 2026-10-03 - Georgi + Claude Code: identify any medicine box by barcode, online (branch `app_development`)
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
    | Spanish Depakine | valproate (via INN translation) | - |
    | Any repeat lookup | from cache | ~0.35 s |
    | `1234` | rejected (400) | - |
- **Bugs found and fixed:**
  - "sodium valproate" was checked as the word "sodium". Salts now map to the base ingredient, and a phrase RxNav
    knows is never split into words.
  - A colour token (`brand` → `brand_accent`) that broke the HAP build; a parallel session caught it.
- **Not done:** the box-photo fallback from the scan screen (the agent's photo scan still exists). Unknown boxes fall
  back to the teach form.

### 2026-10-04 - Georgi + Claude Code: scanning a box showed nothing (branch `app_development`)
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


### 2026-10-03 - Georgi + Claude Code: finish what the docs still promised, then a regression pass (branch `app_development`)
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
- **Not validated / lessons:** the rest of the emulator walk was stopped because the emulator was in use by hand -
  several sessions sharing one emulator needs a lock. Could not verify a Petal Maps link format (docs page body did
  not load), so nearby help uses the documented Google Maps URL instead of guessing. Translations written by AI need a
  native-speaker check.

### 2026-10-03 - Kaloyan + Claude Code: get the phone app ready for a real Huawei device (branch `main`)
- **Asked:** put everything needed to run the app on a real phone into one file, check that it should work, push.
- **Produced:** `docs/REAL_DEVICE.md` (phone requirements, signing, backend config, install, what to test on
  hardware, install errors); `app/scripts/device.sh` (preflight for phone / API level / signing / backend, then build
  → install → launch → screenshot, with `-t <serial>` so phone and emulator can be attached together);
  `entry/hvigorfile.ts` now adds template fields missing from an older gitignored `LocalConfig.ets`.
- **Validated:** 206 Hypium + 68 Deno tests green; strict ArkTS build; install + launch on the emulator (API 24);
  all deployed edge functions respond and `drug-check` answers with the publishable key; `device.sh check` refuses
  correctly with no phone, no signing and a laptop-only backend.
- **Not validated / lessons:** no phone and no signing identity were available, so the signed build and everything
  hardware-only (camera, microphone, biometrics, Celia intents) is untested - listed in REAL_DEVICE.md §4. Found by
  running instead of assuming: the build was broken on this laptop because `LocalConfig.ets` predated four template
  fields, and its backend pointed at `127.0.0.1`, which a phone cannot reach.

### 2026-10-03 (evening) - Kaloyan + Claude Code: final-pass plan, honesty fixes, voice without a mic, Trends (branch `kaloyan/final-pass`)
- **Asked:** a long wish list for the last night (redesign around the agent, immersive orb, test voice with no
  microphone, watch-data history, emergency responder view, auth, push, Live View, calling contacts, RLS...) -
  research deeply, prioritise, split between Kaloyan and Georgi, then start.
- **Plan (AI, approved by Kaloyan):** three read-only sweeps (phone app, watch + backend, docs/rules), then four
  questions (deadline Sun 11:00, two builders, real phone only at 08:00, no Twilio). Ranked by judging weight with
  "misleading information" first. Cut to a slide: accounts, Push Kit, real Live View, SMS/calls to contacts, NFC,
  direct phone-watch link, A2A. Kaloyan: agent, voice, backend, watch, Trends, docs. Georgi: pages, orb, emergency,
  onboarding, release, video.
- **Produced:**
  - Honesty: the agent no longer says the phone "calls and alerts the emergency contacts" (it shows one-tap
    buttons); `scan_medicine` no longer says "camera" (it is a photo picker); the watch shows "SOS SENT" only after
    the row is uploaded, "SOS SAVED" until then. Privacy claims rewritten in README, IDEA, PRODUCT (D6),
    ARCHITECTURE, AI_FEATURES, TASKS with a table of every cloud path and the known auth limit.
  - `voice/DemoVoice.ets`: with `DEMO_VOICE_INPUT = 'on'` a live session streams a bundled 24 kHz clip (macOS
    system voice) into the Realtime input buffer instead of opening the microphone; `SIMULATED VOICE INPUT` badge.
  - Agent tools `prepare_doctor_visit`, `get_dose_status`, `get_trends` (read-only, fixed content) and an
    `OPEN_PAGE` tile; doctor prep opens on the specialty the agent picked.
  - Trends page (`vitals/Trends.ets`, `components/TrendChart.ets`, `pages/TrendsPage.ets`) from the watch daily
    summary and insights that no screen used; DESIGN.md spec added first.
  - Watch: manual SOS on the check-in page, Simulate page only in `DEMO_MODE`, upload timer stops while hidden,
    screen-reader text on Home and the feel buttons.
- **Validated:** 211 phone + 43 watch Hypium tests and 68 Deno tests green; strict ArkTS builds of both apps. On the
  phone emulator against the local backend: clip "Can I take ondansetron?" → server VAD and transcription →
  `check_drug` → Known-risk card; clip "I am seeing the dentist tomorrow" → `prepare_doctor_visit` → reply and tile →
  brief opens; Trends page renders the labelled demo history.
- **Not validated / lessons:** the watch changes were built and unit-tested but not seen on the watch emulator (it
  was not running). `get_dose_status` and `get_trends` were not exercised by voice. Trends with real watch rows was
  not seen because the laptop's backend is the local proxy, which has no database. The first voice test failed with
  "no voice session from backend" - the local proxy was simply not running; reading the log beat guessing. The new
  tool schemas only reach users after the `agent` and `realtime-session` functions are redeployed.

### 2026-10-03 (night) - Kaloyan + Claude Code: Workstream A in three parallel agent sessions and one integrator (branch `kaloyan/agent-home`)
- **Asked:** read the handoff brief (`docs/handoff/KALOYAN_agent_and_ui.md`), plan it as parallel agent work, run
  it, then a full sweep. The visual look was taken out of scope by the owner (done separately in Claude Design).
- **How the work was split (AI plan, owner picked the options):** one integrator session wrote a brief per track
  (`docs/handoff/tracks/`), created three git worktrees with their own branches so one agent's half-done edit could
  not break another's build, and added `app/scripts/emu.sh` (a lock for the single phone emulator). The owner
  started three Claude Code sessions, one per worktree. Rules that carried the weight: each track owns a list of
  files; `string.json` keys are inserted next to related keys, not at the end; tracks write a log file instead of
  editing `AI_WORKFLOW.md` and `README.md`; nobody but the integrator merges.
- **Produced:**
  - T1 (agent home): `pages/AgentPage.ets` split from 1,110 lines into `components/agent/*`; the conversation made
    tab 0 with a status strip, a notes strip and quick actions; live voice ends when the tab is left; full-height
    voice stage; `Motion.reduced` now follows the system setting; two orb animation bugs fixed.
  - T2 (agent brain): tools `open_symptom_log`, `open_reminders`, `log_dose` (confirmed write: the model proposes,
    the phone picks the dose, the user confirms on a card); offline answers for the same requests; quick replies
    after a verdict chosen by risk level; five new demo clips and a barge-in session; eval cases 18-24; prompt
    `2026-10-03.6`, 18 tools.
  - T3 (screens): one `ScreenHeader` on nine pages, buried links moved up as chips, a way forward from every empty
    and error state, screen-reader text across pages and cards, 37 strings moved to resources, Trends reading the
    cloud project while the AI backend is local. Three stale-value bugs found and fixed (`@Builder` arguments are
    passed by value).
  - Integrator: merges, the tiles and confirm card T2 could not add before the split was merged, camera-first box
    photo with a gallery fallback, `docs/research/celia-assistant.md`.
- **Validated:** 236 phone tests, 68 backend tests, HAP builds on the merged branch. On the emulator after the
  merge: cold start, a typed question → `open_symptom_log` → tile → Symptom log page and back; the camera button
  falls back to the gallery (the emulator has no camera to open); Medicines, Heart and Emergency tabs render with
  the new header and chips. Per track, with screenshots in `docs/handoff/tracks/shots/`: the six voice states, nine
  demo-voice sessions against the real Realtime model, mute, barge-in, the tap-to-talk fallback, Trends on 14 and
  30 days from the project's rows. Agent eval: 21 pass, 1 unsafe sentence caught by the device validator, 0 fail
  on prompt `.5`; 9 of 9 on the cases re-run on `.6`.
- **Not validated:** the `log_dose` confirm card on screen (unit tests only: the emulator profile has no dose due);
  camera capture (needs a real phone); anything with the screen reader on; reduced motion switched on; Trends with
  non-simulated watch rows (the demo watch has none); eval cases 3, 4, 6, 8-17, 19, 22 on prompt `.6`; emulator
  audio was never listened to; the watch app was not touched or re-run this session. The new tools are not deployed:
  `agent` and `realtime-session` must be redeployed by the owner.
- **Lessons:** T2 finished its unblocked work before the integrator had merged T1's split, so its last step sat
  blocked; merging the split the minute it was green would have saved a hand-over. A second session merged the
  tracks into the same checkout while the integrator was mid-merge; asking it by message which files it owned
  settled it in one exchange. The tab-0 agent layout from T1 is being replaced by the owner's v2 design in another
  session, so the navigation rows in the README wait for that.

### 2026-10-03 (night) - Kaloyan + Claude Code: interactions everywhere a medicine is handled (branch `kaloyan/agent-home`)

- **Goal:** the owner asked whether a medicine that is "not listed" on its own is still caught when it raises the
  level of a QT drug the user takes (enzyme inhibition), and wanted it on every medicine surface.
- **What the AI found:** the rules existed, but twice: `ComboRules` (chat) had its own enzyme table and
  `DrugChecker.checkCombo` (screens) read the dataset. They disagreed (omeprazole → citalopram and grapefruit only
  in chat). The check screen showed the first interaction only and kept a green header next to an interaction row,
  while the chat raised the verdict. Adding a medicine (form and agent `add_med`) ran no interaction check.
- **What changed:** one enzyme table (`DrugDataset`; fluconazole/omeprazole/esomeprazole CYP2C19 and a grapefruit
  entry moved in), `checkCombos` returns every interaction, `CheckOutcome` carries `combos` + `combinedRisk`, the
  verdict sheet raises its header by the same one-level rule as the chat, the add form and the agent confirm card
  show interactions before the tap. DESIGN.md §6.4 and §6.9 extended first.
- **Validated:** 241 phone tests green (5 new in `DrugChecker.test.ets`), strict ArkTS HAP build.
- **Not validated:** nothing was looked at on the emulator (it was in use by parallel sessions). The enzyme data is
  a curated subset from public tables and still needs a pharmacist's check.

### 2026-10-04 (early) - Kaloyan + Claude Code: doctor visits as a history of pages (branch `kaloyan/agent-home`)

- **Goal:** the owner described the doctor screen he wanted instead of the single brief with specialty chips: a
  gallery of the doctors you have seen, one page each; a new visit asks for the kind of doctor and why you are
  going, guesses what the visit is about, and the page tells the doctor what not to prescribe, summary first,
  depth below, Share at the top.
- **What the AI did:** read DESIGN.md and the v2 screens first, then split the work into fixed logic and screens.
  `doctor/VisitPlan.ets` (new, pure): the reason is matched against keyword lists (13 purposes), each purpose maps
  to drug classes, and the medicines and their risk level come from the bundled QT dataset. No model takes part in
  the guess or in the avoid list. `doctor/VisitStore.ets` keeps the visits on the phone (validated on read).
  Three pages replace `DoctorPrepPage`: `DoctorVisitsPage` (gallery), `NewVisitPage` (live guess while typing),
  `DoctorVisitPage` (at a glance → don't prescribe → AI summary → folded brief). The encrypted web report
  (`site/report`) shows the reason and the same avoid card at the top. The AI summary now also gets the plan's
  purpose titles and known-risk names, never the reason the user typed. DESIGN.md §10.1a "07" rewritten first.
- **Human decisions:** the page layout and order came from the owner's description. The AI chose to keep the guess
  rule-based instead of asking the model (works offline, testable, nothing typed leaves the phone) and to put Share
  in the header as the one exception to the pinned-action rule.
- **Validated:** 248 phone tests green (7 new in `DoctorPrep.test.ets`: guess, plan, text, stored visits, summary
  fields, report), 3 `doctor-summary` backend tests, HAP build. On the emulator: the empty gallery, the new-visit
  form with the dentist tile and a starter chip ("Toothache" → Pain, Procedure, Infection, 13 flagged), the visit
  page down to the AI summary (returned by the deployed backend).
- **Not validated:** the folded "In depth" rows, the gallery with saved cards, delete, Share and Copy link on the
  new page, and the web report's new block in a browser (script syntax-checked only): the shared emulator was
  taken by another session's voice test. The `doctor-summary` function is not redeployed, so the deployed one
  ignores the two new fields. The keyword lists and class mapping are the AI's draft and need a clinician's
  read, like the dataset. `pages/DoctorPrepPage.ets` is no longer routed but was left in the tree because another
  session had uncommitted edits in it.
- **Lessons:** the first draft passed the visit into `@Builder` functions as an argument; the summary would never
  have appeared after loading (arguments are passed by value, the lesson T3 wrote down yesterday). Reading the
  workflow log before writing the page caught it before the first build.


### 2026-10-04 (early morning) - Kaloyan + Claude Code: the owner's v2 design applied; integrator re-check (branch `kaloyan/agent-home`)
- **Asked:** apply the owner's Claude Design v2 screens, the "Dawn" silk orb, Lucide icons, and move the orb to the
  bottom of the agent stage. A second session (the integrator) re-checks the result.
- **Produced (design session, commits `985cc79..6588a02`):** tab bar Today · Medicines · orb · Health · Emergency;
  Today is a dashboard again and the agent is a full-screen pushed stage (the tab-0 agent from the night before is
  replaced); orb dock with tap to talk, tap again to mute, End, and "Aa" for typing; live captions with "Show
  conversation"; Trends inline on Health; a Today's doses row on Medicines; Emergency reordered; Lucide icons (ISC,
  listed under pre-existing components). Voice still ends when the stage is closed or covered, and the microphone
  opens only on a tap.
- **Validated:** from a clean checkout of `6588a02`: 240 phone tests, 68 backend tests, HAP builds. The design
  session looked at Today, the stage (empty, speaking with a verdict card, muted), Health, Medicines and Emergency on
  the emulator.
- **Not validated:** those emulator screenshots came from the shared working tree, which held other sessions'
  uncommitted files, not from a clean build of the commits. Dark mode, a real phone, reduced motion, the frame rate
  of the Canvas orb on real hardware, and "Taken" on a dose with real reminders were not checked. The integrator's
  own emulator pass on the v2 build was cut short: another session reinstalled the app while it ran.
- **Lessons:** the integrator's clean-checkout build caught that `d9ed08d` did not compile on its own: a commit of
  `pages/Index.ets` had carried another session's imports of pages that were never committed, and the reported
  "252 tests" counted that session's uncommitted tests. A shared working tree hides this, because everyone's build
  sees everyone's files. Rule from here: before any push, build and test the commit in a clean worktree. Several
  sessions also drove the one emulator without the lock, so a tap could land on another session's fresh install.
  In one typed turn the agent answered a symptom-log question and also re-opened the dentist brief from earlier in
  the chat; that needs an eval case before the prompt is called stable.

### 2026-10-04 (morning) - Kaloyan + Claude Code: Health tab with every watch metric and one chart system (branch `kaloyan/agent-home`)

- **Goal:** the owner wanted the Health tab to show all the useful watch data, not only heart rate, each graph
  opening a page with more detail and a small box that says in plain words whether the number is up or down and
  good, okay or bad; and a chart designed for health data.
- **What the AI decided and why:** it read what the watch really uploads (`vitals` snapshots: heart rate, resting
  rate, activity, stress flag, steps, and simulated HRV / SpO2 / breathing). There is no ECG signal anywhere in the
  data and a wrist app cannot get one, so no ECG trace was drawn: a made-up trace in a Long QT app would read as the
  user's own. The status is a fixed rule (own baseline for heart rate, resting rate and HRV; reference ranges for
  oxygen, breathing, sleep, stress time; steps never judged past Okay), never model output, and never red.
- **What changed:** `vitals/Metrics.ets` (kinds, usual range, status, change, scale, monotone smoothing, touch
  lookup), `vitals/MetricHistory.ets` (loader + labelled demo history), `components/MetricChart.ets` (line / range
  capsules / bars over a usual-range band, readout that follows the finger, dose and symptom rows),
  `components/MetricParts.ets`, `common/MetricUi.ets`, `pages/MetricPage.ets`, `pages/HeartPage.ets` rewritten,
  `Routes.METRIC`. `HrChart.ets` removed. New read-only view `watch_vitals_daily` (migration written, **not
  deployed**) and its client parser. DESIGN.md §6.10 and §10.1a 04 / 04a written first; the principle "Heart rate
  only" became "Never QT, never an ECG".
- **Validated:** 268 phone tests green (16 new in `Metrics.test.ets`), strict ArkTS HAP build, and on the emulator
  with demo data: Health tab, resting heart rate page, heart rate Now / 14 / 30 days, stress page, dragging on the
  plot.
- **Not validated:** real watch rows (the view is not deployed; until then a real watch shows resting heart rate
  only and "No readings" for the rest), dark mode, the screen reader, sleep / steps / HRV / oxygen / breathing pages
  one by one, the "Ask the agent" button. The reference ranges are demo heuristics and need a clinician's check.
- **Bugs found:** component members named `scale`, `key` and `direction` collide with built-in ArkUI attributes
  (compile error). The first install landed in the middle of two other sessions' emulator runs; the fix was the
  `scripts/emu.sh` lock and tapping only elements found by their text.


### 2026-10-04 (morning) - Kaloyan + Claude Code: real watch data on the phone, with a Watch / Simulated switch (branch `kaloyan/agent-home`)

- **Goal:** the owner saw only simulated numbers on the phone and wanted the real watch data, already uploaded to
  Supabase, pulled in and charted, with a way to switch between the two.
- **What the AI found:** the views, the client and the charts were there. The dev phone talks to a local AI backend
  (`127.0.0.1`) that has no watch tables, and had no key for the deployed project, so every watch read fell back to
  the demo. Live polling, pairing and the resting history only worked when the app backend itself was Supabase.
- **What changed:** new `vitals/WatchSource.ets`: one place that says which project holds the watch tables (app
  backend, or the deployed project while the AI backend is local) and which source the user picked (kept in
  settings, Watch by default). `WatchCloudSource`, `WatchDataClient`, `RestingHistory`, `Trends`, `MetricHistory`,
  `WatchPairing` and `WatchContextSync` read through it; `VitalsService.restart()` switches the live source. Health
  tab → Demo controls has a "Data source" pair of chips; scenarios only show for the simulated source (DESIGN.md
  §10.1a 04 extended first).
- **Validated:** 268 phone tests green, HAP build, and on the emulator against the deployed project: Watch shows the
  watch's resting heart rate and its fixed-rule finding; Simulated brings back the live demo line, the demo history
  and the scenarios; switching back clears them.
- **Not validated:** a watch uploading live during the test (the shared demo watch was offline, so the live line
  stayed empty and the app raised its "no data from the watch" alert, as designed); pairing a real watch from a
  phone on the local backend. `watch_vitals_daily` is still not deployed, so HRV, oxygen, breathing, sleep, steps and
  stress show "No data" in Watch mode.

### 2026-10-03 - Georgi + Claude Code: platform research for Push, Live View, phone ↔ watch, HUAWEI ID (branch `georgi/b-research`)
- **Asked:** research B12 (Push Kit), B13 (Live View + lock-screen medical ID), B17 (phone ↔ watch link), B18 (Account
  Kit) into `docs/research/*.md` so S4 / S1 can implement without re-researching; summarise the SOS voice path for
  B11 and ask for the Cardbeat reference before designing a conversational call. Docs only.
- **Produced:** `docs/research/push-kit.md`, `live-view.md`, `phone-watch-link.md`, `account-kit.md`,
  `sos-voice-call.md` (each: verdict, exact AGC steps, client and server sketches, emulator vs real phone, "Needs"
  list, sources). B11 summary in `sos-voice-call.md` and `docs/workflow/b-research.md`.
- **How:** Context7 was not connected in this session. Official pages came from developer.huawei.com through the site's
  own document JSON endpoint (the rendered pages time out for WebFetch), API names were checked against the local
  SDK typings (DevEco Studio 6.1.1 / API 24, `sdk/default/hms/ets/api/*.d.ts`), and Huawei's live OIDC discovery
  document and JWKS were fetched with curl. Supabase facts came from supabase.com docs/blog.
- **Findings that change plans:** Push Kit on phones, Live View Kit and Wear Engine on phones are **mainland-China only**.
  Push server auth is service-account JWT only ("HarmonyOS 5 and later versions no longer support OAuth 2.0"), so the
  brief's "OAuth client credentials" step is obsolete. No Live View scenario covers an SOS countdown (`TIMER` is for
  tool apps). `emergency/LiveStatus.ets` omits `clickAction` and `layoutData`, which the reference requires on
  creation. Account Kit works in Poland and on the emulator with no approval. Third-party lock-screen presence = a
  Form Kit widget with `renderingMode: autoColor/singleColor`; `setShowOnLockScreen` is a system API.
- **Validated:** every API name used in the code sketches was checked in the SDK typings (`pushService.getToken`,
  `liveViewManager` types and optional/required fields, `wearEngine` clients, `authentication` request/credential
  fields, `form_config` `renderingMode`). Huawei OIDC discovery and JWKS respond (2026-10-03).
- **Validated in Deno (scratch, jose 5.10):** the Push service-account JWT sketch (header/claims/signature) and the
  ID-token verification sketch (valid → UnionID; wrong nonce/aud/iss → rejected; live Huawei JWKS loads). This
  found a real bug in the first draft: Huawei's JWKS labels keys `RS256` while ID tokens default to PS256, so
  jose's `createRemoteJWKSet` would reject every token; `account-kit.md` now selects keys by `kid` and asks the
  client for RS256.
- **Not validated:** nothing ran on a device or emulator; no AGC project exists. Unverified points are flagged in each
  doc (push token on the emulator outside China, `idToken` presence in the sign-in response, lock-screen widget
  placement on the emulator, what a tap on a locked-screen widget does, Supabase `.invalid` email acceptance).

### 2026-10-04 - Georgi + Claude Code: watch internals, energy, background research (branch `georgi/b-watch`)
- **Asked:** brief B16 - a build-and-install script for the watch, split `WatchController` (sensors, rules, SOS, sync,
  pairing) without behaviour change, energy (slower accelerometer at rest, outbox written once per sync, one reused
  HTTP client), background-monitoring research into `watch/README.md` with sources and a needs list.
- **Produced:**
  - `watch/scripts/run.sh`: build → install on the wearable target (found by device type, phone emulator can stay
    connected) → launch → screenshot.
  - 12 characterisation tests over the controller's public API, written before the split.
  - `controller/SensorHub`, `HeartRules`, `SosFlow`, `SyncEngine`, `PairingFlow`; `WatchController` 1212 → 918
    lines, same fields and methods for the screens (getters over the units). `PairingApi`, `MetricUploader` and
    `RulesHost` interfaces so each unit is tested with fakes; clock and randomness injected.
  - `vitals/AccelRate`: 25 Hz → 10 Hz after 30 s at rest/asleep, back on the first moving sample (> 0.3 g off 1 g).
  - `MetricOutbox.flush()`: enqueue/ack mark dirty; `SyncEngine` writes once per sync (also offline).
  - `sync/RestClient`: one Remote Communication Kit session for every Supabase call (Network Kit `HttpRequest` is
    single-use by design).
  - README: code map, energy table, background research with sources and needs.
- **Validated:**
  - Watch unit tests 47 → 87, all passing after every commit; HAP builds (strict ArkTS) after every commit.
  - Wearable emulator (HarmonyOS 6.1.1, API 24): before/after screenshots of all four pages are identical
    (`docs/screenshots/b/watch-before-*.jpeg`, `watch-after-*.jpeg`); SOS from the check-in page counts down and ends
    in "SOS saved" offline (`watch-after-sos-*.jpeg`); hilog shows `accelerometer every 100 ms` ~33 s after start at
    rest.
  - With a temporary `.env` and device id `b-watch-s6-test`: a check-in row reached `watch_metrics` through the new
    rcp session (checked with read-only SQL) and `pairing_start` returned a code. `.env` removed afterwards.
- **Not validated:**
  - Accelerometer rate and fall detection on a real watch (the emulator accelerometer reports on change only; the
    10 Hz fall case is covered by a unit test, not by hardware).
  - Upload on a real watch; the context GET path on a device with a `watch_context` row (code path unchanged apart
    from the transport).
  - Health Service Kit support on HarmonyOS 6 wearables (the current guide page did not load; see README).
- **Docs sources:** Context7 was not connected in this session; APIs were checked in the OpenHarmony docs repo
  (gitcode.com/openharmony/docs), the DevEco SDK declarations (`@hms.collaboration.rcp.d.ts`,
  `device-define/wearable-hmos.json`) and Huawei's Health Service Kit pages. All listed in `watch/README.md`.

### 2026-10-03 - Georgi + Claude Code: doctor visits with questions (B6) and feeling diary (B15) (branch `georgi/b-doctor`)
- **Asked:** saved doctor visits (specialty, date, reason, worries → deterministic brief → AI summary), names and
  contacts stripped from free text before it leaves the phone, request validation in `/doctor-summary` extended
  with the banned-word / dose rejection kept, agent tile still opening prep on a specialty; a "How are you feeling?"
  diary stored as an `AppEvent` and a pure per-day count for Trends.
- **Produced:**
  - `doctor/Visit.ets` (model, clip, date check, upsert/remove/sort, tolerant parse), `doctor/VisitStore.ets`
    (setting `doctor_visits`), `doctor/Redact.ets` (`personalTerms(profile)`, `redactPersonal(text, terms)`).
  - `doctor/DoctorPrep.ets`: `buildBrief(..., visit?)` adds "This visit" and "What worries me"; diary moods as
    counts ("How I felt"); `visitDay()`. `doctor/DoctorSummary.ets`: `summaryFields(..., visit?, personal)` sends
    `reason` and `worries` redacted.
  - `pages/VisitsPage.ets` (list, upcoming first, add form, delete with confirm), `pages/DoctorPrepPage.ets` (opens a
    visit by id, specialty fixed, summary kept with the visit and re-checked on reopen, "My visits" row).
  - `diary/Diary.ets`, `diary/DailyCounts.ets` (`dailyCounts`), `diary/DiaryStore.ets`, `pages/FeelingPage.ets`,
    `widget/pages/FeelingCard.ets` (2×2 card → Feeling page).
  - `backend/supabase/functions/doctor-summary`: `reason` / `worries` optional strings (other types → 400),
    clipped to 300, e-mails / links / phones scrubbed again, `<` `>` removed, quoted to the model inside
    `<patient_words>` as data only. Reply checks unchanged.
- **Validated:** phone unit tests 227/227 (16 new: Redact, Visit, VisitBrief, Diary, DailyCounts), backend Deno 71/71
  (3 new), `deno check` of the function, phone build. Emulator (phone `127.0.0.1:5555`, 2026-10-04 05:51-05:55):
  Heart → Doctor visit prep shows the "My visits" row (`doctor-prep.jpeg`); empty list (`doctor-visits-empty`);
  add form with Dentist, date changed with the system picker to 7 Oct, reason and worries
  (`doctor-datepicker`, `doctor-visit-form`); Save opens "Dentist · 7 Oct 2026" with "This visit" and "What
  worries me" (`doctor-visit-brief`); "Summarise for the doctor" returned a summary that passed the checks and
  was saved with the visit (`doctor-visit-summary`); the list shows it under UPCOMING with "AI summary saved"
  (`doctor-visits-list`), reopening shows the saved summary (`doctor-visit-reopen`), delete asks first and empties
  the list (`doctor-visit-delete`). Privacy ledger shows the request with field names only, including `reason`,
  `worries` (`doctor-ledger`). Feeling page opened through the widget's want (`params {"target":"feeling"}`),
  Low shows "Log a symptom", saved entry listed under RECENT (`doctor-feeling-low`, `doctor-feeling-saved`).
  All in `docs/screenshots/b/`.
- **Not validated:** the summary came from the currently deployed `/doctor-summary`, which predates this branch and
  ignores `reason` / `worries`; using them in the text needs the deploy (coordinator). The widget itself was not
  placed on the emulator home screen (its tap target was exercised through the same want). Redaction is
  unit-tested; the emulator run shows field names in the ledger, not values.
- **Note for the coordinator:** with the watch emulator also attached (`127.0.0.1:5557`), `app/scripts/run.sh` and
  `ui.sh` call `hdc` without `-t` and fail; I used `hdc -t 127.0.0.1:5555`. The worktree also has no signing
  config, so the unsigned HAP is refused over another stream's signed install (9568332); I built once with the
  main checkout's local `build-profile.json5` and restored the file afterwards (not committed).

### 2026-10-03 - Georgi + Claude Code: actionable notifications and an honest watch SOS (branch `georgi/b-notify-sos`)
- **Asked:** B7 (notification slots per kind, action buttons, taps open the right page) and B8 (a watch SOS must not
  start a second countdown; the SOS page says what was sent, to whom, and what still needs a tap; a "For first
  responders" button once the countdown ends).
- **Produced:** `common/NotifyAction.ets` (pure: kinds, slots, buttons, request codes, tap parsing, targets),
  `common/Notify.ets` (slot + buttons + one WantAgent per button), tap handling in `EntryAbility.handleNotifyTap`,
  `ReminderService.takeFromNotification` + `DoseSchedule.takeableFromNotification`, `HeartOkRequest`;
  `SosController.watchSent` (state SENT, `sentBy` WATCH, cooldown), `VitalsAlert.watchSos` set by
  `WatchCloudSource` on `sos` rows, `Index.onWatchSos`, the SOS page status card and responder button,
  `LiveStatus.watchSos`. Fixed an existing bug: a manual SOS has no reason, the countdown notification had empty
  text and the system rejected it (401), so it never showed.
- **Validated:** 227/227 phone unit tests (16 new: notification kinds/slots/buttons/request codes/tap parsing, dose
  "Taken" only when due or missed, controller watch states, watch `sos` row mapping). Emulator: countdown page and
  its notification, phone sent state, responder route, all four notification kinds published with the right slot
  and buttons, "Taken" recorded the dose and landed on Reminders, "I'm OK" closed a running countdown, heart alert
  Open → Heart tab, risky check → History, watch SOS → page in sent state with no countdown and its notification.
  Screenshots `docs/screenshots/b/notify-sos-*.jpeg`.
- **Not validated:** action buttons drawn on screen (the emulator panel does not render them); a watch SOS from a real
  watch row end to end (the sent state was opened with a temporary, uncommitted hook calling the same controller and
  page path; the row → alert mapping is unit tested); notification taps from a cold start.

### 2026-10-04 - Georgi + Claude Code: Live View, lock-screen medical ID and Push Kit (branch `georgi/b-notify-sos`)
- **Asked:** implement what S7's research says is possible without approvals; list the rest as blocked.
- **Produced:**
  - `emergency/LiveStatus.ets` + pure `emergency/SosLiveText.ets`: one `startLiveView` with a countdown `timer`
    the system ticks, a timer capsule (emergency colour from the `danger` resource), `clickAction` (the SOS tap
    WantAgent), a pickup layout with a picture (`rawfile/sos_live.png`, generated in this repo), `countdownPreset`
    text at zero, and an end card that says how the SOS ended. No per-second updates. The notification fallback
    stays and logs the kit's error code.
  - Lock-screen medical ID: `widget/pages/MedIdCard.ets` + pure `widget/MedIdData.ets`, a third form with
    `renderingMode: "autoColor"` (home screen and lock screen). Condition, AVOID line, ICD, medicines,
    allergies, blood type; respects `hiddenOnCard`; never contacts, phone numbers or notes. Same snapshot as the
    alert card, no network.
  - Push Kit client: `account/PushToken.ets` (token on each launch, stored on the phone, upserted to
    `push_tokens` once per user and token when signed in; `forget()` for sign-out), push tap →
    `EntryAbility.handlePushTap` → SOS page in the watch-sent state (also cold start). `module.json5` home skill
    also lists `ohos.want.action.home`.
  - Push Kit server: `sos/huaweiPush.ts` (service-account JWT PS256 with `jose`, test messages, fixed copy, no
    location), wired into `sos/index.ts` before the contacts step; result in `sos_dispatches.detail.push`, never
    changes the SOS status. Migration `20261004110000_push_tokens.sql` (owner-only RLS, nothing for anon).
- **Validated:**
  - Phone 239/239 (12 new), backend 72/72 (4 new: config parsing, JWT header/claims verified with a throwaway key,
    push message shape). `deno check` of `sos/index.ts` passes.
  - Emulator: **Live View runs on the emulator** (no AGC approval needed there): capsule/timer in the panel and on
    the lock screen counting down (`notify-sos-15/16`), end cards "SOS cancelled. Glad you are OK" and "Open Celia
    to call the ambulance and your contacts" (`17/18`). The emulator showed the kit validates the payload before the
    permission: the research's progress layout was rejected without `nodeIcons`, pickup without `descPic` (401);
    fixed. Push token on the emulator: `1000900010 Illegal application identity` (no AGC project), logged and
    ignored. Push tap (want with the push's `clickAction.data`) opens "Your watch sent an SOS" (`19`). Medical ID
    card in the widget picker and on the home screen with real data (`20/21`).
- **Not validated:** Live View on a real phone (needs an approved `TIMER` scenario and, per Huawei, a Chinese-mainland
  device); the medical ID **on the lock screen** (the emulator has no lock-screen editing; home-screen only);
  receiving a real push (no AGC project, no Chinese-mainland phone); the push send itself (no service-account key);
  token upload (S1's accounts and per-user JWT in `Net.ets` not merged yet).

### 2026-10-04 - Georgi + Claude Code: accounts and profile backup (branch `georgi/b-accounts`)
- **Asked:** brief B1 (sign up, log in, stay signed in offline) and B2 (profile saved under the account), plus the §8
  privacy docs. Supabase Auth over plain HTTPS, no supabase-js.
- **Produced:**
  - Migration `20261004100000_profiles_auth.sql`: drops the leftover `on_auth_user_created` trigger and
    `handle_new_user()` (they inserted into a `profiles(id, display_name)` table that never existed, so every sign-up
    failed with "Database error saving new user"); creates `public.profiles (user_id, data jsonb, updated_at)` with RLS
    on, four `(select auth.uid()) = user_id` policies for `authenticated`, explicit `revoke all … from anon` (the
    project's default privileges grant anon full table rights), a JSON-object check and a 64 KB size cap.
  - `account/AuthClient.ets`: signup, password grant, refresh grant, logout. Endpoints checked against the Supabase
    Auth API reference; errors parsed in both the current `{code, error_code, msg}` and the older
    `{error, error_description}` shape (codes from the Supabase Auth error-code list). Sign-up with no session in the
    reply → "check your email" (in case "Confirm email" stays on).
  - `account/Session.ets`: the contract API (`isSignedIn`, `userId`, `userName`, `email`, `accessToken`, `signOut`,
    `onChange`) plus `load`, `start`, `freshToken`, `refreshNow`. Session stored in the encrypted RDB (`kv` setting
    `session`). Refresh 5 min before expiry, retry every 60 s while it fails. Only `SESSION_REVOKED` signs out;
    offline / 5xx / 429 keep the session, so an expired token offline still opens the app signed in.
  - `account/ProfileSync.ets`: last-write-wins on the document time (newer of `Profile.updatedAt` and the last
    medicine change), at sign-in, at launch and 3 s after a local edit; every run reads the account copy first.
  - `common/Net.ets`: `NetTarget.bearer` and `authHeaders()` - the one place that puts the user's JWT in
    `Authorization` (the anon key stays in `apikey`); `accountTarget()`; `requestJson()` for nested JSON bodies.
  - `privacy/Ledger.ets`: `PersonalDataException` with exactly two named entries, `ACCOUNT_AUTH` (`/auth/v1/`,
    `email`) and `PROFILE_SYNC` (`/rest/v1/profiles`, the profile's personal fields). `FORBIDDEN_FIELDS` is unchanged;
    an exception only applies on its own endpoint prefix. Ledger entries carry the exception id; the export shows it.
  - `LocalStore.saveProfile(profile, stamp = true)` stamps `updatedAt`.
  - Screens: `WelcomePage`, `AuthPage` + `components/AuthForm.ets`, `AccountPage`, Settings → Account row, launch
    routing in `pages/Index.ets` (`showOnboardingIfNeeded`). Strings in `string_accounts.json` (`acc_`).
  - Docs (brief §8): README "What leaves the phone", `AI_FEATURES.md` §3, `docs/ARCHITECTURE.md` data rule,
    `docs/PRODUCT.md` D6, `docs/TASKS.md`, `docs/IDEA.md`.
- **Validated:** phone unit tests 238/238 (27 new in `test/Account.test.ets`: response parsing for both error shapes,
  confirm-email sign-up, session storage round trip and corruption, refresh margin and scheduling, refresh decision,
  offline-with-expired-stored-session, launch route, last-write-wins incl. "never push another account's data",
  remote document parsing and versioning, personal-field naming, ledger exception scoping). `assembleHap` builds.
  Emulator (phone `127.0.0.1:5555`): fresh install opens on Welcome (`docs/screenshots/b/accounts-welcome.jpeg`);
  Sign up form (`accounts-signup.jpeg`); a real log-in against the live project with a wrong password comes back as
  `invalid_credentials` and shows the amber strip with the fields kept (`accounts-login-error.jpeg`). This emulator
  pass found and fixed two form bugs: the button kept the sign-up label after switching to log-in, and both inputs
  were cleared after an error (both caused by values passed by value into `@Builder` functions).
- Not validated (needs the migration applied and "Confirm email" off): real sign-up from the emulator, profile push /
  pull against the live table, the B1 acceptance run (sign up → kill → network off → reopen signed in). Context7 was
  not available in this session; the encrypted RDB and `@kit.NetworkKit` http calls reuse the patterns already in
  `data/LocalStore.ets` and `common/Net.ets`.

### 2026-10-04 - Georgi + Claude Code: SOS contacts under the account and RLS by account (B10, B9; branch `georgi/b-accounts`)
- **Asked:** B10 (contacts and first name reach the server with consent; show the dispatch status) and B9 (close the
  open RLS on watch data through the device ↔ account binding; give the watch its own secret).
- **Produced:**
  - `20261004100100_sos_contacts_account.sql`: `watch_pairings.user_id` (pairing_claim records `auth.uid()`,
    `pairing_bind(token)` binds older pairings), `emergency_contacts.user_id`, `sos_profile` (first name, no API
    access), `device_owned()`, `sync_sos_contacts()` (owner only, E.164, ≤ 5, empty = delete), `sos_status()`. Anon
    insert on `emergency_contacts` removed. A new owner never inherits the previous owner's contacts. The `sos`
    function reads the name from `sos_profile`.
  - `20261004100200_watch_rls_by_account.sql` (B9 part 1): anon reads only the demo watch; signed-in owners read
    their watch (`watch_metrics`, views, `watch_context`, `resting_day_sim`); phone writes to `watch_context`,
    `set_watch_genotype`, `ack_watch_alert` (from Workstream A's 20261004050000) need the owner. Names are wiped
    from `watch_context`.
  - `20261004100300_watch_secret.sql` (B9 part 2): `pairing_start` hands out a watch secret once (hash stored);
    `x-watch-secret` header unlocks the watch's context read, uploads (once it has a secret), `pairing_start` and the
    demo RPC. The open anon read on `watch_context` is gone.
  - `backend/supabase/tests/run-rls.sh` + `accounts_rls.sql` + `supabase-shim.sql`: every migration applied to a
    throw-away local Postgres 15 with Supabase stand-ins, then ~49 behaviour checks (profiles, watch data by owner,
    contacts RPCs, binding, account deletion, watch secret).
  - Phone: `common/Net.ets` adds the user's JWT to database paths (`/rest/v1/`) on the accounts project only; AI
    calls (`/functions/v1/`) stay anonymous because the token names the user. Expired tokens are not sent (the
    request falls back to the public key, which still reads the demo watch). `data/WatchPairing.ets`: claim binds,
    `bindToAccount()` after sign-in. `PairWatchPage` asks to sign in first. `account/SosContacts.ets`: consent
    switch, E.164 normalisation from the profile country (ITU-T calling codes), first name only, `SOS_CONTACTS`
    ledger exception, status line (incl. "test mode, no text or call was sent" for `dry_run`). README updated in the
    same commit.
  - Watch (B9 part 2): `docs/workflow/b-accounts-watch-secret.patch`, made on a detached copy of `georgi/b-watch`
    (S6's RestClient): RestClient sends `x-watch-secret`, PairingClient stores the secret from `pairing_start`,
    DeviceIdStore keeps it, WatchController wires it (3 lines). Watch build OK, watch tests 88/88 there.
- **Validated:** phone tests 248/248; backend Deno 68/68; RLS checks pass on local Postgres; watch patch builds and
  passes 88/88 on top of `georgi/b-watch`. Emulator: Settings → Account row, Account page signed out
  (`accounts-account-signed-out.jpeg`), Pair watch asks to sign in (`accounts-pair-sign-in.jpeg`).
- **Not validated:** nothing of B9/B10 against the live project (migrations not applied); the consent switch and SOS
  status signed in; a real SOS reaching contacts (no Twilio credentials: the server records `dry_run`).

### 2026-10-04 - Georgi + Claude Code: configurable emergency profile and first-responder view (branch `georgi/b-emergency`)
- **Asked:** brief B4 (configurable emergency profile, card, versioned share payload) and B5 (first-responder view with
  "do not give", "use instead", care notes, reachable from the Emergency tab, lock screen, alert widget and SOS).
- **Produced:**
  - `LocalStore.parseStoredProfile`: defaults applied when a stored profile is read, so profiles saved before B4
    still load (lists default to `[]`, missing text stays absent, corrupt values fall back).
  - `emergency/Responder.ets` (pure): `doNotGive` (every Known-risk drug by class plus the avoid-in-congenital list;
    antiemetics first, then "Stimulants and catecholamines - avoid unless life-saving"), `useInstead` (dataset
    `alternatives[]` grouped by the option set, with the drugs and classes they replace), `careNotes` (lqts-domain
    emergency facts; ICD, beta-blocker and genotype trigger follow the profile), `ageYears`, `medRows`,
    `recentRiskyIntake` (72 h watch window).
  - `emergency/EmergencyDetails.ets` (pure): fixed card order, `detailRows`, `cloneProfile`, show-on-card helpers,
    list and birth-date parsing. `CardStrings.cardLabels`: English labels for the new fields, every other language
    falls back to English (no invented translations).
  - `components/EmergencyDetailsForm.ets` (contract kept: `@Param profile`, `@Event onChange`, never saves),
    `pages/EmergencyProfilePage.ets` (debounced save), one Settings row.
  - Emergency card renders the details between treatment and medicines; empty fields hidden; `hiddenOnCard`
    respected for name, contacts, notes and every detail field.
  - Card payload v2 (`emergency/CardLink.ets`): optional short fields `d s b a k r h e`. App, scanned-card page and
    `site/card/index.html` read v1 and v2. Hidden fields never enter the payload. QR fallback limit unchanged
    (900 chars); trimming drops the least urgent fields first and keeps genotype, ICD, blood type, first allergies.
  - `pages/ResponderPage.ets`: always light (`card_fixed_*`), large type, order of the brief, call buttons. Entry
    points: top of the Emergency tab, app lock screen, tap on the facts of the 2×4 alert widget.
- **Validated:** phone unit tests 233/233 (new suites StoredProfile, EmergencyDetails, Responder, CardPayloadV2).
  Emulator (Pura 90, API 20), screenshots in `docs/screenshots/b/`:
  - an existing profile saved by the old code opened with defaults (no crash, card intact);
  - Settings → Emergency details: date of birth, sex, blood type, allergies, cardiologist, hospital and two extra
    fields entered and kept across an app restart (`emergency-details-edit.jpeg`, `-extra.jpeg`);
  - Emergency tab: "For first responders" row at the top (`emergency-tab-responder-row.jpeg`), the card shows the
    details in order (`emergency-card-details.jpeg`);
  - responder page top to bottom (`emergency-responder-top.jpeg`, `-scroll.jpeg`, `-bottom.jpeg`); hilog showed no
    app network activity while it opened;
  - widget target: a cold start with the alert-card want `{"target":"responder"}` lands on the responder page;
  - web viewer in a browser with a v1 and a v2 link (`emergency-web-card-v1.png`, `-v2.png`).
  - Two refresh bugs found and fixed on the emulator (chips and text fields in the form were @Builder by-value).
- **Not validated:** the physical tap on the alert widget from a home screen (the want it sends was replayed instead);
  the lock-screen button with the app lock on (the emulator has no screen lock to enable it); "show on card"
  switches on the emulator (unit-tested only).

### 2026-10-04 - Georgi + Claude Code: NFC handover of the emergency card, B14 (branch `georgi/b-emergency`)
- **Asked:** brief B14, write the card link as an NDEF URI record to a tag from a "Write to NFC tag" action next to the
  QR; guard on NFC availability; mark built, unverified.
- **Produced:** `emergency/NfcCard.ets` (foreground `tag.on('readerMode')` for NDEF and NDEF-formatable tags, one
  `makeUriRecord` message, `writeNdef` or `format` for blank tags; pure `ndefUriBytes`, `smallestTagFor`,
  `resultForError`), the action in the Emergency tab's QR panel, `ohos.permission.NFC_TAG` in `module.json5`.
  APIs checked against the API 20 SDK declarations in DevEco (`@ohos.nfc.tag.d.ts`, `tag/nfctech.d.ts`,
  `@ohos.nfc.controller.d.ts`); the Context7 MCP was not connected in this session.
  The tag gets the same link as the QR: the encrypted short link (97 bytes, fits an NTAG213) when sharing is on,
  else the in-link card (NTAG215/216, or refused when too long).
- **Validated:** 4 unit tests (NDEF size layout, tag fit, error mapping). Emulator: the action is hidden because the
  emulator reports no `SystemCapability.Communication.NFC.Tag` (`emergency-nfc-guard-emulator.jpeg`).
- **Not validated:** **built, unverified** - no real tag written, reader mode and the write path never ran. Known limit:
  editing the card replaces the encrypted link, so a written tag must be written again (the UI says so).

### 2026-10-03 - Georgi + Claude Code: 8-step onboarding (branch `georgi/b-onboarding`)
- **Asked:** brief B3 - a simple onboarding that still gathers everything: welcome + consent, account, about you,
  medicines, emergency contacts, emergency details, permissions, watch. Progress shown, Skip on optional steps,
  nothing lost when going back, under 2 minutes; move the launch-time notification ask into the permissions step.
- **Produced:** `onboarding/OnboardingFlow.ets` (pure step rules and profile-draft helpers), `onboarding/Permissions.ets`
  (check/request notifications, microphone, location), `components/onboarding/` (`OnbParts`, `StepAbout`,
  `StepContacts`, `StepPermissions`), rewritten `pages/OnboardingPage.ets`, `string_onboarding.json`,
  `test/Onboarding.test.ets` (11 tests). `pages/Index.ets` no longer asks for notifications on every launch.
- **Validated:** phone unit tests 222/222. Emulator (phone, API 20 image, fresh install each time):
  - Continue stays inactive until consent is ticked; one tap on the checkbox ticks it once.
  - Every step shown with progress and "Step N of 8"; Skip on steps 2 and 4-8; the date picker fills date of birth;
    ICD model field appears with the switch.
  - A saved contact and a half-typed second name both survive Back → Continue.
  - Permissions: no notification prompt at launch any more; each Allow opens its system dialog only on tap;
    granted shows "Allowed", a denied microphone shows the Settings hint.
  - Pair a watch opens the Pair watch page and Back returns to step 8; Finish lands on Home ("Hi Ola", LQT2 chip);
    relaunch goes straight to Home.
  - Timing: a scripted fresh-install run entering name, birth date, genotype, ICD + model, one medicine, one contact
    and all three permission dialogs took **27 s** (app log: "onboarding took 29 s"). That is tap speed, not human
    reading speed; with reading and typing by hand it is still well under the 2-minute target (14 inputs, 3 system
    dialogs, nothing required beyond the consent tick).
  - Screenshots: `docs/screenshots/b/onboarding-1-welcome.jpeg` … `onboarding-9-home.jpeg`
    (+ `onboarding-7a-notification-dialog.jpeg`).
- **Found and fixed while testing:** the last step still said "Continue". `components/Common.ets` `PrimaryButton`
  passes its label to a by-value `@Builder`, which does not re-render when the label changes; the page now uses two
  button instances. Every other caller of `PrimaryButton` with a changing label has the same bug (not fixed here -
  Common.ets is Workstream A's; fix: pass `$$`-style by-reference params or rebuild the label in the struct).
- **Not validated:** the account step and the emergency-details step run against S1's `AuthForm` and S2's
  `EmergencyDetailsForm` stubs; the real forms arrive at merge. The returning-user skip
  (`shouldFinishAfterSignIn`) is unit-tested, not run end to end (needs S1's ProfileSync).
- HarmonyOS APIs were checked against the API 20 SDK `.d.ts` files in DevEco (Context7 was not connected in this
  session): `abilityAccessCtrl.checkAccessToken` / `requestPermissionsFromUser` (since 11),
  `notificationManager.isNotificationEnabled` / `requestEnableNotification(context)` (since 12),
  `UIContext.showDatePickerDialog` (since 11). `requestPermissionOnSetting` is API 21, so it is not used.

### 2026-10-04 - Georgi + Claude Code: merging Workstream B into georgi/integration
- **Asked:** act as the Workstream B coordinator (`docs/handoff/B_PLAN.md` §1, §6): merge the seven streams, run the
  test suites and an emulator smoke test, fold the stream notes (`docs/workflow/b-*.md`) into the real docs.
- **Produced:** seven streams merged in plan order (research, watch, doctor, notify-sos, accounts, emergency,
  onboarding). Conflicts were only additive: test list registrations in `app/entry/src/test/List.test.ets`, widget
  entries in `form_config.json` (feeling + medid both kept), `EntryAbility` card-tap targets (feeling + responder),
  `SettingsPage` imports. Applied `docs/workflow/b-accounts-watch-secret.patch` to the watch. Wired
  `PushToken.forget()` before `Session.signOut()` in `AccountPage` (requested by the notify-sos notes). Stream notes
  folded into this file, README, DESIGN.md and ARCHITECTURE.md; pending deploy steps in `docs/handoff/B_DEPLOY.md`.
- **Validated:** phone unit tests 329/329, watch 88/88, backend Deno 75/75, accounts RLS checks pass on local
  Postgres, phone HAP and watch HAP build. Emulator: Welcome → 8-step onboarding without an account → Home; Emergency
  tab → responder view; SOS countdown + I'm OK; a watch-sent SOS deep link shows "Your watch sent an SOS" with the
  For first responders button; feeling diary card target; responder card target. The watch app installs and matches
  its pre-merge screenshot.
- **Not validated:** anything needing the live migrations (sign up / log in against Supabase, B9/B10, push tokens):
  migrations `20261004100000`..`20261004100300` and `20261004110000` are not applied yet, and the `sos` and
  `doctor-summary` functions are not redeployed.

### 2026-10-04 (night) - Kaloyan + Claude Code: Workstream B merged into the v2 app, live backend deployed (branch `kaloyan/agent-home`)

- **Asked:** sort four sessions' uncommitted work into clean commits, merge Georgi's `georgi/integration`, make his
  screens fit the v2 design and UX, fix the open issues his notes listed, and run his live Supabase checklist.
- **What the AI did:** split the uncommitted tree into five commits (watch alert ack migration, interactions,
  doctor visits, watch source, health metrics), each built and tested on its own in a clean worktree (245, 252, 252,
  268 tests). Merged `georgi/integration` (12 conflicts). Both branches had built doctor visits; the owner chose ours
  plus his extras, so his `VisitsPage` and `DoctorPrepPage` went and our visit gained his date and "what worries
  me". `doctor-summary` accepts both field sets. The Emergency tab kept the v2 layout with his NFC and card details
  ported in; the responder tile now opens his first-responder view and a Help guide row keeps the bystander steps.
- **Fixed from the open issues:** the watch SOS page shows the server's real dispatch status (being alerted, sent,
  partly, failed, test mode, no contacts, too soon, or "not confirmed" after a minute) instead of a fixed "not
  alerted"; the emergency details form has "Notes for paramedics" and the responder view lists them; the SOS copy
  no longer says contacts are alerted when nothing is sent; `PrimaryButton` labels re-render (a component instead of
  a by-value `@Builder`).
- **Found while testing on both emulators:** the onboarding account chips never switched the form to log-in (no
  `@Monitor`); two coral buttons on the account, medicine and contact steps; date of birth asked twice; the welcome
  orb clipped; a watch built with the demo id could not count as paired, so consent and SOS status stayed off; the
  SOS status row never updated (by-value `@Builder` again) and asked before the session was read at cold start;
  "1 contacts ready". All fixed and seen on the emulator.
- **Live backend:** migrations `20261004100000`, `100100`, `110000`, `100200` and `100300` applied one by one after
  `backend/supabase/tests/run-rls.sh` passed locally (history repaired per file, never `db push`); `watch_vitals_daily`
  granted to `authenticated`; `sos` and `doctor-summary` redeployed. The model wrote "no visit reason was given" when
  the reason was empty, so empty patient words are now left out of its prompt.
- **Validated:** 389 phone tests, 88 watch tests, 75 backend tests, HAP builds. Emulators against the live project:
  sign-up (Georgi had turned off "Confirm email"), 8-step onboarding signed in, profile backup, pairing the watch
  (bound to the account), the watch receiving its secret and still uploading after `100300`, the consent switch
  putting one contact on the server, a watch SOS reaching the phone page, the Health tab reading the watch's rows.
- **Not validated:** contacts actually being texted (the database webhook secrets and Twilio are not set, so no
  dispatch is recorded and the page says so); owner-only reads for a watch with its own id (the emulator watch uses
  the public demo id); Push Kit; the feeling diary is reachable only from its widget. The phone started once on the
  simulated source without the user picking it; not reproduced.
- **Lessons:** another session's staged files rode along in one plain `git commit`; it was undone and redone with
  `git commit -- <paths>`. Builder arguments by value bit three times in one night.

### 2026-10-04 - Kaloyan + Claude Code: 60 days of simulated watch history (branch `kaloyan/agent-home`)

- **Asked:** two months of believable test data for everything the Health tab shows (resting heart rate, heart rate,
  HRV, oxygen, breathing, sleep, steps, stress), ending today, with no UI changes.
- **What the AI did:** planned first; the owner approved, minus a 60-day chart option. `data/demo_history.py` (seeded,
  deterministic) is the single source. It writes `vitals/DemoHistoryData.ets` for the phone's built-in demo and
  migration `20261004120000_demo_history.sql` for the backend, so both paths show the same story. Days are stored as
  "days ago", so the history always ends today, and there is one variant per weekday of today, so weekend habits fall
  on real weekends. Smooth day-to-day noise; short nights lower HRV and raise resting heart rate the next day; a cold
  (days 38-33), a two-day trip, three days with no watch, one missed dose, and the existing two missed nadolol doses
  at the end, so the missed beta-blocker question still fires. The three old demo generators (Trends,
  RestingHistory, MetricHistory) now read it.
- **Backend:** demo days come from a template table joined to `demo_history_on` (demo-watch-1 starts on;
  `seed_demo_history` turns it on or off for a watch with its secret). `watch_vitals_daily`, `watch_resting_daily`
  and `watch_daily_summary` now include those days, which take the place of real rows on the same date; today stays live.
  No 170k raw rows, and the watch's 7-day insert window is untouched.
- **Validated:** 394 phone tests (5 new in `DemoHistory.test.ets`, including the missed-dose question on every
  weekday); all migrations applied to a throwaway Postgres with `tests/run-rls.sh` passing; queried the views as
  anon: 56 demo days plus today's live row, on/off works, other devices refused without the secret.
- **Live backend:** the migration was applied to the live project in one transaction and recorded with
  `supabase migration repair` (the owner ran both; Claude Code's permission check blocked the production write).
  The demo watch now serves 57 days from 6 Aug, and the phone's Health tab shows full 14-day lines, marked SIM.

### 2026-10-04 - Kaloyan + Claude Code: watch readings per account, kept on the phone (branch `kaloyan/agent-home`)

- **Asked:** check the watch ↔ phone link end to end, explain pairing and data transfer, fix the gaps found, and stop
  the app from starting empty when there is no test data.
- **Found:** reads were gated on the watch's *current* owner, so a watch that changed hands showed the new owner the
  previous owner's history (`accounts_rls.sql` even asserted it); unpairing was phone-only, so the old account kept
  reading the watch; history was tied to the device id; the live chart skipped every existing row at start.
- **What the AI did:** migration `20261004130000_watch_metrics_owner.sql`: a trigger stamps `user_id` on every
  upload from the pairing (clients cannot set it), reads go by `user_id = auth.uid()`, an ownership period
  (`owned_from`) keeps late uploads from the previous period out, rows uploaded while unbound go to the account that
  binds that pairing, `pairing_unbind(token)` ends a pairing on the server, deleting an account deletes its readings.
  Phone: `WatchPairing.unpair()` calls it; `WatchCloudSource` backfills the last 5 minutes of `hr_live` into the
  chart history (no alerts replayed); `data/HistoryCache.ets` saves real days from the daily summary and daily vitals
  per account in the encrypted store and merges them into later fetches (server wins per day, simulated days never
  cached, demo watch never cached).
- **Validated:** `tests/run-rls.sh` passes with 13 new checks (previous owner, late upload, unbind, first owner keeps
  pre-pairing rows, account delete); 407 phone tests (6 new); phone HAP builds.
- **Live backend:** applied by Claude Code with `supabase db push --linked` after a dry run showed it was the only
  pending file. Checked through the API: the demo watch still reads and its new rows carry its owner (the trigger
  stamps live uploads), other devices return nothing to anon, `pairing_unbind` refuses an unknown token, anon cannot
  call `pairing_bind`.
- **Not validated:** not run on the emulators (live chart backfill, local history, unpair from Settings).

### 2026-10-04 - Kaloyan + Claude Code: Settings rebuilt as a grouped index (branch `kaloyan/agent-home`)

- **Asked:** a cleaner Settings UI/UX, moving things where they belong.
- **Found:** Settings mixed edit forms with navigation; name and notes needed a Save button while everything else
  saved on change; notes duplicated Emergency details; contacts were deleted on one tap; the watch-SOS consent
  switch (it sends the contacts to the server) was buried in Account; headers repeated their row titles.
- **What the AI did:** proposed a new layout and asked two placement questions (the owner chose: contacts get their own page,
  Test SOS stays, notes go). DESIGN.md 6.11 + 10.2 first, then `SettingsList.ets` (group, row, divider), Settings as
  a profile card plus SAFETY / DEVICES / ACCOUNT AND PRIVACY groups with the state in words, a searchable
  emergency-number sheet, `HeartProfilePage` (reuses the onboarding About step, saves on change),
  `ContactsPage` (delete asks first, add sheet) with the consent card moved there as `SosAlertsCard`. Lucide `user`
  icon added.
- **Validated:** phone HAP builds; 407 phone tests pass; on the emulator: Settings, Your profile, Emergency
  contacts, the add sheet, and number search + pick (saved, shown on the row).
- **Not validated:** adding and removing a contact end to end on the emulator; the signed-out consent card.

### 2026-10-04 - Kaloyan + Claude Code: layered emergency card with more about LQTS (branch `kaloyan/agent-home`)

- **Asked:** a better design and UX for the emergency card, more data about LQTS, looking at how HeartBeat (our earlier
  web app, design reference only) does its card.
- **Found:** three surfaces with two content sets (a flat Emergency tab card, a richer English responder view, the web
  card), no "about LQTS" anywhere, and a 17-group "Do not give" list that pushed contacts three screens down.
  HeartBeat's order (patient header, critical info, clinician protocol, condition reference) worked well, but it had
  the model write the card, and two of its claims are wrong for congenital long QT (isoproterenol as a bridge in
  torsades; "avoid lidocaine").
- **What the AI did:** proposed a layered card (glance, critical, for clinicians, about long QT); the owner chose drug
  names only (no doses) and an initial avatar. DESIGN.md §11 first, then `emergency/LqtsFacts.ets` (fixed, sourced:
  protocol steps, torsades list, do-not-use lines, genotype facts with gene, share, triggers, ECG pattern, treatment
  and emergency notes, general precautions), `components/EmergencyCardParts.ets` shared by the Emergency tab and the
  responder view, cardiologist first in contacts, a "takes a QT-prolonging medicine" notice, first 4 drug groups with
  "Show all". The owner found the first pass too decorated (coloured bands, side rule); it was redone in plain
  design-system shapes (caps labels, 1 vp cards, the Known-risk notice with shape + word).
- **Validated:** 407 phone tests (7 new: every genotype complete, genes match the domain table, no em dash and no
  doses, local emergency number in the protocol, no lidocaine or congenital isoproterenol advice); HAP builds from a
  clean checkout; on the emulator: Emergency tab card, full card scrolled end to end, Show all, About opened.
- **Follow-ups:** the web card (`site/card/`) got the same layers; `data/export_card_site.py` now also exports
  `LqtsFacts.ets`, so app and web show the same facts (checked in headless Chrome with a legacy in-link card). The
  profile photo from the Settings session shows on the card when the user allows it (phone only, never in the QR).
- **Not validated:** layers 3 and 4 in other languages (English by design until a checked translation exists); the
  web card on a real phone.

### 2026-10-04 - Kaloyan + Claude Code: profile photo for the emergency card (branch `kaloyan/agent-home`)

- **Asked:** let the user add a profile picture that the emergency card can use.
- **What the AI did:** `data/ProfilePhoto.ets` (system photo picker, no permission; centre-crop to a 512 px square
  JPEG in `filesDir`; a new file name per save so images reload; deleted by `LocalStore.clearAll`). It is not a
  `Profile` field, so it is never synced and never in the card QR or web card. `CardField.PHOTO` lets the user hide
  it from the card. `components/ProfileAvatar.ets` shows photo, initial or glyph; used in Settings and on Your
  profile (photo block with Add / Change / Remove and the "Show on emergency card" switch). The emergency card hook
  (`CardIdentity`) is left to the session redesigning the card, by agreement, to avoid editing the same files.
- **Validated:** phone HAP builds; on the emulator: picked a gallery image, saw it on Your profile and in Settings,
  restarted the app (photo kept), removed it (file deleted) and added it again.
- **Card (after the card session's 25011ee):** on the emulator the medical alert card showed the photo; with
  "Show on emergency card" off it showed the initial; the switch state survived an app restart.

### 2026-10-04 - Kaloyan + Claude Code: `main` merged into `kaloyan/agent-home`, then to `main`

- **Asked:** merge the branch to main.
- **What the AI did:** main had five commits the branch lacked (phone "I'm fine" closes the watch alert, symptom
  after a risky drug warning, watch Medical ID page, a tappable heart-rate demo, the landing page). Ten files
  conflicted because the branch had rebuilt the watch (v2 screens, controller split into rules / sync / SOS / pairing)
  and the phone Health page. Main's features were ported onto the branch's structure, not pasted over it: the
  heart-rate demo drift lives in `HeartRules.hrWithAnomaly` and is a "High heart rate" chip in the Simulator (the
  Vitals list has no tappable tiles any more); the drug warning fires from `logSymptom`, so both the check-in and
  the Log page raise it; `fetchAlertAck` uses the shared `RestClient` (so it sends the watch secret);
  `WatchContextSync.ackAlert` follows `WatchSource.target()`; Medical ID and the drug warning were redrawn on the
  v2 watch tokens; Home shows an "Answered on phone" chip for 5 s. The phone Health page keeps the branch's
  redesign (main's `StatTile` fix was for the screen it replaced). DESIGN.md §7 lists the new page and moment.
- **Validated:** phone and watch HAPs build after the merge; phone and watch unit tests run with 0 failures (two
  watch expectations for the limit reason still had the pre-v2 copy and were updated in a separate commit).
- **Not validated:** the phone-to-watch "I'm fine" round trip and the two new watch screens on the emulator after
  the merge; whether migration `20261004050000_watch_alert_ack` is applied on the live project.

- **Not validated:** the charts on the emulator (another session's watch alarm scenario held the shared phone
  emulator); the migration is not applied to the live project yet.

### 2026-10-04 - Georgi + Claude Code: home-screen widgets v2 (branch `georgi/b-widgets`, from `kaloyan/agent-home`)

- **Asked:** redesign the home-screen widgets and add four or five genuinely useful ones; plan first, then build, in
  an isolated git worktree so parallel agent sessions are not disturbed.
- **What the AI did:** wrote the spec into DESIGN.md (§11 "Home-screen widgets v2") and the plan into
  `docs/workflow/b-widgets.md` before any code. Three new Form Kit cards: **The agent** (2×2/2×4, default: the
  HomeBrief sentence + Talk / Scan / How I feel), **Next dose** (2×2: dose to take, today's dots, one-tap Taken) and
  **Resting heart rate** (2×2/2×4: 7-day average, change, dot plot on the usual range, status pill). Redesigned
  **Can I take this?** (2×4 adds the last three checks with risk shape + word) and **How are you feeling?** (2×4:
  one-tap moods that open the diary with the mood picked; saving stays the user's tap). Medical alert and Medical ID
  unchanged. A pure `WidgetModel` builds one flat snapshot; `WidgetDose` / `WidgetSnapshot` let the form extension
  move the dose card and the agent's dose sentence on by the clock every 30 min while the app is closed.
- **Safety:** nothing on a card comes from a model. Risk words/shapes come from the logged deterministic verdicts;
  heart status from the fixed `Metrics` rules (never red); dose styling stays neutral; "Taken" logs only a due or
  missed dose (same rule as the notification button).
- **Bug found on the emulator:** the app and the form extension run in separate processes and Preferences caches per
  process, so pushes never reached placed cards. Fixed with one writer per file (snapshot: app; registry: extension)
  and a cache drop before cross-process reads.
- **Validated:** 404 phone tests (10 new in `Widgets.test.ets`); HAP builds; on the phone emulator every card renders
  with the demo profile's data, Talk opens the agent stage, the dose card's button opens Reminders, adding and
  deleting a reminder updates the placed dose card live, a mood chip opens the diary with that mood picked
  (`docs/screenshots/b/widgets-*.jpeg`). Fixed from screenshots: heart 2×2 badge overflow, clipped "latest reading"
  line, missing orb on the 2×2 check card.
- **Not validated:** the DUE / MISSED dose card and its Taken tap on the emulator (a reminder created after its time
  starts tomorrow, so a due dose cannot be set up from the UI; covered by unit tests); the 30-minute `onUpdateForm`
  tick; the recent-checks rows with real checks (the demo profile has none); dark mode.

### 2026-10-04 - Georgi + Claude Code: launch film as code (`video/`)

- **Asked:** a 60–75 s 16:9 product film for the landing page plus a 25–30 s 9:16 social cut, built as code from the
  design system, with no screenshots and no Huawei marks; honest about simulated data and "heart rate only".
- **Produced:** a Remotion project in `video/`. `theme/tokens.ts` copies `color.json`, `float.json` and DESIGN.md
  (the only hex values in the project); `theme/motion.ts` turns DESIGN §8 into frame functions (heartbeat keyframes,
  4 s breathing, 240 ms verdict reveal, 280 ms sheet). The real screens are rebuilt as React components (voice orb,
  live words, tool step, verdict card, HR ring, check-in sheet, watch W1/W2, SOS ring, QR card, Polish web card,
  privacy ledger, box scan). The UI copy comes from the app (`DrugChecker.reasonFor`, `string.json`,
  `gtin_pl.json`, `card/data.js`). There are 9 scenes, shared by both cuts with `wide`/`tall` layouts. VO lines are
  slots in `copy/script.ts`; `public/vo.mp3` / `music.mp3` are mixed when present (music ducks −12 dB).
- **Decisions:** the high-HR watch alert is amber (W2) and red appears first on the SOS ring; the bystander card is
  in Polish; the patient (Ola Nowak) is fictional; the box is a generic carton; the end card has no URL yet.
- **Validated:** `tsc --noEmit` passes under strict mode. Each scene was checked as a contact-sheet still against
  `docs/design/*.png` and fixed (verdict scroll, scan box hidden by the sheet, Polish chips overflowing). Renders:
  `site/media/demo.mp4` (72.0 s, 1920×1080, H.264, 12 MB), `site/media/demo-poster.jpg`, and
  `video/out/celia-vertical.mp4` (27.4 s, 1080×1920, 5.5 MB). ffmpeg `blackdetect` found no black frames.
- **Not validated:** the cuts are silent because there is no VO or music yet. The film has not been watched on the
  deployed landing page.

### 2026-10-04 - Georgi + Claude Code: launch film on the v2 design, with sound

- **Asked:** "go to main and pull the latest design … make the video" from the real designs, and "we need really
  good sound for the video too".
- **Found:** `main` already matched our branch; the newest design (DESIGN.md v2, `docs/design/v2/`,
  `docs/design/v2-watches/`) lived on `origin/kaloyan/agent-home`. It was read from there with `git archive` into a
  scratch folder, leaving the working tree (with uncommitted landing work) untouched.
- **Produced (picture):** the film follows v2: the silk orb ("Dawn" palette, bands, blobs, halo) ported from
  `site/assets/silk-orb.js` as a frame-pure canvas (state integrated from frame 0, so any frame renders alone);
  Today (01) on the reveal; the agent stage (02 → 03) with "You:" captions, the agent's sentence in title-2 with
  unspoken words at 30 %, tool pill, compact Known-risk card and the floating orb dock; Details → full verdict sheet;
  watch v2 (gauge home with DEMO DATA, "Near / Above your max", heart-rate-high alert with the limit line);
  Emergency tab v2 (Start SOS, Call 112, responder view) into the countdown and QR; the bystander card as the v3
  glance layer in Polish. Icons are the app's Lucide fills. Copy follows §9 (no em dashes); card languages match
  `site/card/data.js` (Türkçe, not Svenska).
- **Produced (sound):** `scripts/audio/vo.py` speaks `src/copy/vo.json` with Kokoro (narrator `af_heart`, the agent
  `af_bella`, Ola `bf_emma`) and writes word timings plus a per-frame loudness envelope, so the captions and the
  orb follow the real voice. `score.py` synthesizes a D-major score from `src/copy/timeline.json` (pads, felt piano,
  kalimba arpeggio, sub, bell blooms, risers, convolution reverb; soft thumps on the hook ripples; the bed thins at
  the watch alert). `sfx.py` makes taps, orb wake, tool done, card, sheet, scan lock, watch haptic and alert tone,
  SOS ticks, chime and ledger ticks. `audio/Soundtrack.tsx` places voices and effects on the exact scene frames that
  cause them and ducks the music −12 dB under every voice; `scripts/loudnorm.mjs` brings each render to −16 LUFS.
- **Decisions:** the watch alert is now red, as drawn in v2-watches 7 (this replaces the earlier "amber alert"
  choice); scene lengths follow the voice (hero 72.5 s, vertical 29.9 s); the vertical cut has its own shorter
  narrator lines.
- **Validated:** `tsc --noEmit` passes. Contact sheets of both cuts checked against the v2 drawings. Whisper
  transcribes every line of both final mixes correctly and in order ("Klacid" heard as "Clacid"). Both cuts measure
  −16.0 LUFS with peaks at −1.4 / −1.5 dBFS; `blackdetect` finds no black frames. `site/media/demo.mp4` 72.6 s,
  16 MB; `video/out/celia-vertical.mp4` 29.9 s, 7.3 MB.
- **Not validated:** nobody has listened to the mix yet; the score's taste and the TTS voices need a human ear.
  Not watched on the deployed landing page.

### 2026-10-04 - Georgi + Claude Code: submission deck (`deck/`)

- **Asked:** a clean pitch deck in the style of an earlier pitch (cream, big type, mono eyebrows) but on our design
  system: title, problem, solution/ecosystem, demo video, tech stack, team, wiring diagram, plus whatever the Huawei
  criteria still need. Read-alone submission, HTML, Figtree only, real screens; later "use the newest designs".
- **Plan (AI, approved step by step):** brainstorm mapped to the six judging criteria → 20 slides: a four-slide
  problem arc from Georgi's earlier pitch (1 in 2,000, what QT is, three triggers, Torsades, medicines as the hidden
  trigger), then answer, ecosystem, "the list decides, the AI explains", demo, app, watch, platform kits with honest
  status, architecture, failure handling, evidence, AI workflow, roadmap, team, close.
- **Produced:** `deck/index.html`, `deck.css`, `deck.js` (no dependencies): 1920 × 1080 slides scaled to the window,
  keyboard/click/swipe, print to PDF one slide per page. Generated visuals: 2,000-dot field, ECG QT illustration,
  Torsades trace, drug strip from real dataset entries, heartbeat field on the title. First pass used crops of the
  v2 design mock-ups; after review every phone and watch image was swapped for real emulator captures of the built
  apps from `main` (`docs/screenshots/b`, `docs/handoff/tracks/shots`), since the shipped UI (Agent / Medicines /
  Heart / Emergency tabs, the real watch faces) had moved on from the mock-ups. DESIGN.md §10.2c added.
- **Validated:** every slide rendered in headless Chrome at 1920 × 1080 and checked by eye; overlaps fixed and
  re-rendered; print-to-PDF gives 20 pages. Medical numbers checked against the `lqts-domain` skill (prevalence
  1 : 2,000 instead of 1 : 2,500) and carry source lines; kit statuses taken from ARCHITECTURE.md; test and commit
  counts from the newest README (`kaloyan/agent-home`).
- **Not validated / open:** the team photo is a placeholder until `deck/media/team.jpg` exists; the PDF needs the public video URL in `deck.js`. Mortality figures from the earlier
  pitch were reworded to what the cited sources say (≈50 % of untreated symptomatic patients within 10 years).
- **Revision (same day):** the deck had to be **10 slides**. Problem slides 2-7 merged into one (1 in 2,000 dot field,
  drug strip, four facts), app tour and safety diagram into one agent slide, kits into the wiring diagram, evidence
  and AI workflow into one, team and close into one; roadmap cut. All devices re-shot from the landing page
  (`site/index.html`, the newest design: new Today / Talk tabs, silk orb, agent voice screen) with Playwright at 3×
  in reduced-motion state, so every screen is the settled final frame; the title and close use the live silk orb.
  Validated: all 10 slides rendered and checked, print gives 10 pages. The landing lists Wear Engine for the watch;
  the deck keeps the ARCHITECTURE.md status (Sensor Service Kit, sync via Supabase).
- **Revision 2:** the deck is submitted as a PDF, so every moving part was removed: entrance animations, line draws,
  the scrolling drug strip and the live orb (now a still render of the same silk-orb code). The video became its
  poster with a "Watch the demo" link. `deck/Celia-ai-deck.pdf` printed from headless Chrome, 10 pages, checked page
  by page.
- **Revision 3:** the demo has to play. The HTML deck plays `deck/media/demo.mp4` again (print shows the poster). The
  PDF gets the MP4 embedded (pypdf): a Screen annotation with a Rendition action over the video frame (plays inline
  in Adobe Acrobat / Reader), the same file as a FileAttachment on the "Click to play" button and in the attachments
  panel (opens in the system player in most desktop viewers). Browsers and macOS Preview cannot play video inside a
  PDF. Verified the embedded file is byte-identical to the MP4.

### 2026-10-04 - Georgi + Claude Code: Sport & Healthcare deck (`deck/sport-health.html`)

- **Asked:** we also enter the HackYeah "Sport & Healthcare" competition (max 10-slide PDF; judged on Idea &
  Innovation 30 %, Relation to Category 20 %, Practical Applicability 20 %, Design 20 %, Completeness 10 %). Copy the
  Huawei deck into a new file and adapt it to the category, keeping the design.
- **Produced:** `deck/sport-health.html` + `deck/sport.css` (same `deck.css`, `deck.js`, media and tokens; no new
  colours). Title, problem, solution, medicine check, watch and emergency slides reframed for an active life. New
  slide 4 "Sport, without the fear": an SVG run chart showing the watch's state-aware limit (120 at rest, 130 active
  for LQT1), an over-limit alert and a slow-recovery flag, plus the rules behind it and the genotype coach tips. The
  wiring and evidence slides became one "Practical value + evidence" slide (patient, family, coach, cardiologist;
  tests, commits, medicines, languages). Kit-bag medicines on the check slide come from `DrugDataset.ets`.
  `deck/Celia-ai-deck-sport-health.pdf`: headless Chrome print, 10 pages, demo MP4 embedded on page 6 with the same
  pypdf method as the main deck.
- **Validated:** every claim on the sport slide traced to code: `Limits.ets` (base 140/120/100, LQT1 active -10, LQT2
  rest -10, LQT3 low +5, risky drug -10), `RecoveryTracker.ets` (peak vs 60 s later, < 12 bpm = slow, 20 s minimum
  bout), `MotionAnalyzer.ets` (rest / active / fall), `WatchController.ets` (30 s fall countdown then SOS),
  `Coach.ets` (tips). Drug categories checked in the dataset (salbutamol, pseudoephedrine, loperamide conditional;
  ibuprofen not listed). All 10 pages rendered and checked by eye; overlaps fixed; embedded video byte-identical.
- **Not validated / open:** the run chart is an illustration of the rules, not a recorded session. The ESC 2020
  sports-cardiology point is cited from the guideline title, not quoted. Team photo is still the placeholder.
- **Revision (same day): business side.** Asked to add market fit and the business case and keep 10 slides. Watch
  and emergency merged into one dark slide (watch steps, three emergency points, a bad-day line). The practical-value
  slide became two: **Market + fit** (rings: ~4M worldwide, ~225k EU, ~19k Poland from prevalence 1 : 2,000 ×
  population, labelled as estimates; families and other channelopathies as expansion; a gap table against QT drug
  lists, ECG wearables, smartwatch health and pill reminders; why now) and **Business model + go-to-market** (free
  safety core, Celia+ for families (€4.99 a month), clinic and club licence (€2 per person a month); pilot in Poland → CE marking under EU MDR → EU and
  clubs; build stats). Prices are marked as proposals and the competitor table as our qualitative reading, not a
  survey. PDF re-printed (10 pages) and the demo re-embedded on page 6.

### 2026-10-04 - Georgi + Claude Code: whole-repo security and quality review, high and medium fixes

- **Asked:** review the whole app (not only the current diff) for code quality and security, then fix the high and
  medium findings.
- **Review (AI):** Claude Code read the backend functions, every RLS migration, the phone app's network, lock,
  drug-check and pairing code, the watch sync and the site viewers. 10 findings: 3 critical (watch SOS delivery: a
  401/403 row blocks the outbox, the SOS cap is shared by the project, a lost watch secret has no reset path), 4 high,
  3 medium. The critical ones are left for a separate decision.
- **Fixed:**
  - App lock: an auth call that throws no longer unlocks (a screen lock exists, so it counts as a failed attempt);
    a second tap while the auth widget is up is ignored. Private pages (notification taps, cards, "ask the agent")
    no longer open while the app is locked or showing only the emergency card from the lock screen; they open after
    unlock. Only SOS, bystander and first-responder pages are allowed from the lock screen.
  - Pairing: failed code guesses are counted per caller (account, else a hashed client address), 10 per 5 minutes,
    with a project ceiling of 300, so one script can no longer block pairing for everyone
    (`20261004140000_rate_limits.sql`).
  - OpenAI cost: `agent`, `realtime-session`, `speak`, `transcribe`, `vision-extract` and the box-identify deep
    search now go through `_shared/rateLimit.ts`: a per-caller limit plus a project daily cap (`AI_DAILY_CAP`,
    default 5000), counted in Postgres (`ai_rate_take`, service role only) with an in-memory fallback. The app
    already treats a non-200 answer as a fallback.
  - Box cache: an AI row past the 30-day TTL no longer blocks a new answer (`aiWrite` treats stale rows as absent);
    test added.
  - Logs: medicine names, risk levels, heart rates, genotype and reminder medicine names removed from hilog lines
    (the Logger logs everything as public); the rule is written in `Logger.ets`.
  - Repo size: the deck reads the demo video and poster from `site/media/` (duplicate copies removed);
    `deck/*.pdf` ignored in git (attach the PDFs to a release).
- **Validated:** phone app builds (`assembleHap`); backend `deno check` on all functions and `deno test` (75
  passed). Not validated: the new migration is not yet applied to the hosted project, and the lock flows were not
  re-tested on the emulator.

### 2026-10-04 - Georgi + Claude Code: documentation audit and one README

- **Asked:** check every Markdown file against the app so it is current, well structured and understandable; make
  the README the best possible; then remove every README outside the root and put everything in one README,
  including how to run each part yourself.
- **Produced:** Claude Code split the audit across five parallel sub-agents (architecture; AI docs; product and
  planning docs; component READMEs; hackathon working notes), each told to verify claims against the code, edit only
  its own files, and report what in the root README contradicted the code. Results:
  - `docs/ARCHITECTURE.md`, `AI_FEATURES.md`, `docs/IDEA.md`, `docs/PRODUCT.md` rewritten around what is built;
    `PLAN.md`, `TASKS.md`, `REGRESSION.md`, `REAL_DEVICE.md` given status headers and done / not-done tables; every
    hackathon working note given a one-line status; this file given a summary and a session index.
  - Root `README.md` rebuilt: problem, features, safety diagram, HarmonyOS kits and permissions, architecture
    diagram, "Run it yourself" for all four parts (phone, watch, backend, web pages) with versions, configuration
    keys, signing, helper scripts and secrets, five-minute demo, the feature verification table grouped by area,
    "How each part works" (Edge Functions and agent contract, Celia intents, watch rules and data, SOS pipeline,
    film, decks), tests and the AI eval harness, privacy, repo layout, one documentation map, third-party list, team.
  - The 14 READMEs outside the root were merged into it and deleted. Content that is research, not reference, moved
    to its own doc: the watch's background-monitoring research to
    `docs/research/watch-background-monitoring.md`; the Workstream A track rules to `docs/handoff/tracks/TRACKS.md`.
    Links and code comments that pointed at the old files now point to the root README sections.
  - README screenshots copied from the deck's emulator captures into `docs/media/`.
- **Validated:** test counts re-run before quoting them (phone 418, watch 99, backend 75, all passing); a script
  checked every relative Markdown link and heading anchor in the repo (no broken ones) and that no file contains an
  em dash. Sub-agent findings fixed in the README: stale test counts, prompt version (`2026-10-04.1`), widget count
  and names (7), demo voice clip count (8), watch data access (owner-only plus watch secret, no longer "shared key"),
  SOS contact migrations (applied).
- **Not validated / open:** the README's demo-video link points to the file in the repo until a public URL exists;
  mermaid diagrams were checked by reading, not rendered; older session entries above still mention
  `watch/README.md` and other removed READMEs, as a record of what was written at the time.

