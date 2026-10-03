# AI workflow

Required deliverable (Challenge Rules). Every AI-assisted session appends one entry: tool/model, what it was asked,
what it produced, how we validated it.

## Tools

- Claude Code (Claude Opus 5.5) in the terminal, with the repo skills in `.claude/skills/` and Context7 MCP for
  HarmonyOS docs (`/websites/developer_huawei_consumer_cn_doc_harmonyos-guides`).

## Pre-existing / third-party components

- DevEco Studio 6.1.1 project template (config files and default icons in `watch/`).
- `@ohos/hypium` 1.0.29, `@ohos/hamock` 1.0.0 (test framework, ohpm).
- `bleak` (Python BLE library, `tools/hr-bridge`).

## Log

### 2026-10-03 — Mark + Claude Code: watch app
- **Asked:** build the watch part. Our GT 6 Pro should send metrics via the iPhone to a server that the phone app
  (DevEco Previewer) reads.
- **Research (AI, verified against the installed SDK):** the lite wearable device definition
  (`sdk/default/hms/js/api/device-define/liteWearable.json`) has no NetStack syscap, so a GT app can't make HTTP
  calls; `WearEngineLite` (API 24) only exposes connection state. Decision: ArkTS wearable app on the wearable
  emulator, and real GT 6 Pro heart rate via the watch's BLE heart-rate broadcast → Mac bridge.
- **Produced:** `watch/` (HR sources, deterministic `AlarmRules`, session stats, persistent outbox, Supabase uploader,
  round UI), `backend/supabase/migrations/*_watch_metrics.sql`, `tools/hr-bridge/hr_bridge.py`.
- **Validated:** strict ArkTS build with no warnings; 16 local unit tests pass (`hvigorw test`); installed on the
  HarmonyOS 6.1.1 wearable emulator and checked by screenshot: live HR, LQT2 startle → high-HR alert after 10 s,
  symptom logging, outbox persists across restarts, bridge source reads the Mac at `10.0.2.2:8787` (fake mode).
- **Not yet validated:** upload to a real Supabase project; BLE broadcast from the actual GT 6 Pro.
- **Lessons:** HarmonyOS training data is stale. The SDK's own `.d.ts` and device-define files were the fastest
  ground truth. Emulator screens are ~233 vp wide, so the first UI was 2× too big; screenshots caught it.
