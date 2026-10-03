# AI workflow

Required deliverable (Challenge Rules). Every AI-assisted session appends one entry: tool/model, what it was asked,
what it produced, how we validated it.

## Tools

- Claude Code (Claude Opus 5.5) in the terminal, with the repo skills in `.claude/skills/` and Context7 MCP for
  HarmonyOS docs (`/websites/developer_huawei_consumer_cn_doc_harmonyos-guides`).

## Pre-existing / third-party components

- DevEco Studio 6.1.1 project template (config files and default icons in `watch/`).
- `@ohos/hypium` 1.0.29, `@ohos/hamock` 1.0.0 (test framework, ohpm).
- `@supabase/supabase-js` 2.x (npm, in the `sos` Edge Function), `@std/assert` 1.x (jsr, Deno tests).
- Twilio Programmable Messaging + Voice REST API (external service for SOS SMS and calls; keys in Supabase secrets).

## Log

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
