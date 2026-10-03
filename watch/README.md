# Celia Watch (HarmonyOS wearable, ArkTS)

The watch half of Celia.ai: live heart rate, deterministic LQTS heart-rate alerts with vibration, one-tap
"I feel unwell" / "medication taken" logging, and upload of small computed metrics to Supabase, where the phone app
reads them.

```
 heart-rate source ──► AlarmRules ──► alert overlay + vibration
  (sensor | demo)  ─► SessionStats
                    ─► MetricOutbox (Preferences) ──► SupabaseUploader ──► watch_metrics ──► phone app
```

### Code map (`entry/src/main/ets/controller/`)

`WatchController` is the one object the screens read and call (unchanged API: fields + methods). It owns the
screen state (alerts, check-in, nudges, limits) and the 1 s tick, and delegates to five units:

| Unit | Does | Tested with |
|---|---|---|
| `SensorHub` | HR source (sensor or scenario), accelerometer → rest/active + falls, wear sensor, steps, accelerometer rate | `AccelRate`, `MotionAnalyzer` tests |
| `HeartRules` | per reading: resting HR, stress, simulated vitals and their alerts, recovery, limit alarm, `hr_live` / `vitals` / `hr_session` cadence; talks back through `RulesHost` | fake host, fixed random |
| `SosFlow` | fall "Are you OK?" 30 s → SOS 10 s → `sos` row → delivered | fake clock |
| `SyncEngine` | outbox → uploader, batches of 50, row-by-row after a 400, one storage write per sync | fake uploader |
| `PairingFlow` | 6-digit code, countdown, `pairing_status` every 2 s | fake `PairingApi` |

All Supabase calls go through one `sync/RestClient` (a reused Remote Communication Kit session).

## Why an ArkTS wearable app on the emulator

The Huawei Watch GT series runs *lite wearable* apps (JS). We checked the HarmonyOS 6.1.1 SDK: the lite wearable
device definition has **no network capability** (no NetStack syscap, no `fetch`/`http`), so a GT app can't reach our
server (and with iPhones only, Wear Engine P2P to a phone app isn't an option either). The watch app is therefore a
full HarmonyOS **wearable** app (API 20+, like Watch 5 / Watch Ultimate) that talks HTTPS to Supabase itself, and we
run it on the **wearable emulator**. The emulator has no heart-rate sensor, so the demo uses scripted scenarios,
always labelled as demo data.

## Heart-rate sources (Settings page, tap to switch)

| Source | Where it runs | Metric `source` |
|---|---|---|
| Demo data (scenarios: **Full demo**, Resting, Normal workout, LQT1 exercise, LQT2 startle, LQT3 night, Faint) | anywhere | `simulated` |
| **Watch sensor** (default; `sensor.SensorId.HEART_RATE`, needs READ_HEALTH_DATA) | real watch, or the emulator's virtual HR sensor; falls back to demo if there is no sensor/permission | `watch` |

### Fast demo (only with `DEMO_MODE=true`)

Scripted heart rate is **off by default** (`DEMO_MODE=false` in `watch/.env`): the watch uses the real sensor only,
Settings shows no source/scenario/speed, and there is no fallback to scripted data. Set `DEMO_MODE=true` and rebuild
to get it back. Then: Settings → Source: *Demo data* → Scenario: **Full demo** → Demo speed **4×** (default, `DEMO_SPEED` in `.env`).
It plays everything in ~75 s: high HR during exercise → slow recovery → startle at rest → low HR asleep →
irregular rhythm → fall. In demo mode the timing rules (10 s sustain, alert cooldowns, 1-min recovery) run on
scenario time so they speed up too; uploaded rows keep real timestamps.

### Driving the sensor on the emulator

Emulator toolbar → **⋯ (more)** → **Virtual sensors** → **Heart rate**: move the slider. The app reads it through the
same `sensor.on(HEART_RATE)` code as a real watch. Drag above 140 and hold for 10 s to trigger the high-HR alert,
below 45 for the low one. The last reading counts for 30 s (sensors may report only on change); after that the
watch shows "Waiting for heart rate…".

## Risk-model inputs from the watch

| Input | Status | How |
|---|---|---|
| Heart rate | ✅ real | `sensor.on(HEART_RATE)` (emulator: virtual HR sensor) |
| HR limits per state | ✅ real | `Limits.limitsFor()`: max at rest 120 / active 140 / asleep 100, low 45 (asleep 40); LQT1 −10 while active, LQT2 −10 at rest, LQT3 low +5; recent risky drug −10 on all highs |
| Resting heart rate | ✅ real (calculated) | lowest 1-min average at rest/asleep over 24 h (`RestingHr`); "est" until the first resting minute |
| HR recovery after exercise (LQT1) | ✅ real (calculated) | peak HR of a ≥ 20 s active bout vs. HR 60 s after it ends; drop < 12 bpm = slow → alert (`RecoveryTracker`) |
| Exercise / activity | ✅ real | accelerometer (`MotionAnalyzer`) + step counter (`PEDOMETER`) |
| Stress | ⚠️ partly real | HR > resting × 1.35 at rest, and HRV < 25 ms when HRV is available (`isStressed`) |
| Asleep | ⚠️ approximate | on wrist + still ≥ 10 min + HR ≤ resting + 10 + 22:00–07:00 (`SleepDetector`) |
| Genotype, recently scanned risky drug | ✅ real (server) | `watch_context` row written by the phone app; polled every 60 s |
| HRV | 🧪 simulated | Huawei watches measure it; watch apps can't read it yet |
| Irregular rhythm | 🧪 simulated | ditto; simulated as "very fast HR without exertion" (≥ 170 at rest) |
| Low HRV / low SpO2 alerts | 🧪 simulated input, real rule | HRV < 20 ms while not exercising, SpO2 < 92 % → `vitals_alert` + alert screen (`vitalAlertFor`) |
| SpO2, breathing rate | 🧪 simulated | ditto |

Simulated values are plausible for the current state and heart rate (`MockedVitals`), tagged **sim** on the watch
(Home shows HRV next to bpm). **Tap a sim tile** on the Vitals page (HRV, SpO2, Rhythm) to push that signal abnormal
and see its alert ~3 s later. Heart-rate alerts need the limit crossed for `ALERT_SUSTAIN_SEC` (default 5 s),
and listed in `payload.mocked` in the data. They show what the product does once Huawei opens these signals to
watch apps.

## Screens (Watch companion design W1–W7)

Swipe pages: **Home** (W1: status, bpm, genotype · phone link, ring = bpm between your min and max) → **Vitals**
(all inputs above) → **Check-in** (W4 + "Took nadolol") → **Settings** (source, demo scenario) → **Simulate**.

Full-screen flows, most urgent wins (SOS > fall/alert > check-in > drug verdict):

| Screen | When | Buttons |
|---|---|---|
| W2 heart rate high / W3 heart rate low | `hr_alert` for the current state's limit; low while asleep uses a gentle vibration | *I'm OK* → W4 check-in · *Need help* → W5 |
| Fall detected (W2 style, 30 s) | accelerometer / Faint scenario / Simulate | *I'm OK* → W4 · *Need help* or no answer → W5 |
| Irregular rhythm, slow recovery (W2 style) | `rhythm_alert` (simulated), slow `hr_recovery` | same as W2 |
| W4 How do you feel? | after *I'm OK*, and as a page | Fine / Dizzy / Racing → `symptom` |
| W5 SOS countdown (10 s) → SOS sent | *Need help* or unanswered fall | *Cancel*; at 0 an `sos` row is sent |
| W6 drug verdict glance | a new QT-risk drug arrives via `watch_context` (or Simulate) | *Got it* |
| W7 not on wrist | wear sensor / Simulate | — |

**The watch never dials 112 itself** (auto-dialling emergency services from a test build is unsafe). The `sos` row
is the trigger: the phone app / agent alerts emergency contacts and offers the 112 call.

## Alert rules (all deterministic, in code, configurable; demo heuristics, not clinical advice)

| Alert | Rule | Where |
|---|---|---|
| Heart rate high / low | HR above / below the **current limit** for `ALERT_SUSTAIN_SEC` (5 s); then 60 s cooldown per direction | `vitals/AlarmRules.ets` (timing), `vitals/Limits.ets` (limits) |
| Current limit | max: rest `REST_HIGH_BPM` 120 · active `HIGH_BPM` 140 · asleep `SLEEP_HIGH_BPM` 100; min: `LOW_BPM` 45 · asleep `SLEEP_LOW_BPM` 40. LQT1 −10 while active, LQT2 −10 at rest, LQT3 min +5, recent risky drug −10 on every max | `limitsFor()` in `vitals/Limits.ets`, values in `watch/.env` |
| Slow recovery | < 12 bpm drop in the 60 s after an exercise bout of ≥ 20 s | `vitals/RecoveryTracker.ets` |
| Low HRV (sim input) | HRV < 20 ms while not exercising, for the sustain time; 60 s cooldown | `vitalAlertFor()` in `vitals/MockedVitals.ets` |
| Low SpO2 (sim input) | SpO2 < 92 %, for the sustain time; 60 s cooldown | same |
| Irregular rhythm (sim input) | rhythm flag turns on (simulated: HR ≥ 170 without exertion, or the Rhythm tile) | `mockVitals()` / `applyAnomaly()` |
| Stress (shown, no alert) | HR > resting × 1.35 at rest, and HRV < 25 ms when known | `isStressed()` in `vitals/Limits.ets` |
| Fall | impact > 2.5 g, then still 1–4 s later → 30 s "Are you OK?" | `vitals/MotionAnalyzer.ets` |
| SOS | *Need help* or unanswered fall → 10 s countdown → `sos` row | `WatchController.startSos()` |

The sim-tile demo (Vitals page) drifts the signal over 2.5 s (refreshed every 250 ms), holds 10 s and recovers over
4 s (`anomalyProgress()`). A tapped anomaly uses a 1 s sustain (`ANOMALY_SUSTAIN_MS`) instead of 5 s, so the alert
lands under 4 s after the tap (measured: HRV 3.0 s, SpO2 2.8 s, rhythm 1.5 s).

## Notifications and reminders

- Every alert screen (heart rate high/low, rhythm, recovery, HRV, SpO2, fall, SOS sent) also posts a **watch
  notification** (Notification Kit), so it stays in the notification list after the screen is dismissed. Tapping
  it opens the app. The user allows notifications once, on first launch.
- **Daily medication reminder** at `MED_REMINDER_TIME` (default 08:00, empty = off) via `reminderAgentManager`. The
  **system** fires it with Done/Snooze buttons, so it works while the app is frozen or closed (verified on the
  emulator with the app force-stopped). Simulate → *Med reminder in 10 s* demonstrates it.

## Context: activity, falls, wear (beyond heart rate)

PPG heart rate can't show QT, so the watch adds context that matters for LQTS:

| Signal | Source | Used for |
|---|---|---|
| **Rest vs. active** | accelerometer (`MotionAnalyzer`: std-dev of \|a\| over 4 s); scenario; Simulate page | Stricter high limit **at rest** (default 120) than during activity (140): a racing heart without exertion is the LQT2 pattern, high HR while exercising is the LQT1 one |
| **Fall / faint** | accelerometer: impact > 2.5 g, then lying still 1–4 s later; *Faint* scenario; Simulate page | "Are you OK?" with a 30 s countdown and vibration. *I'm OK* → `fall_detected{response:"ok"}`. No answer → `fall_detected{response:"no_response"}` + SOS screen; the phone app/agent runs the emergency flow from that row |
| **Watch on wrist** | `WEAR_DETECTION` sensor (not on the emulator); Simulate page | No HR alarms while off the wrist; `wear_state` rows so the dashboard can tell "not worn" from "no data" |

The emulator has an accelerometer (rest/active works from it) but no wear sensor. **Simulate page** (4th page):
*Fall*, *Take watch off / Put watch on*, *State: auto → rest → active → asleep*, *Genotype*, *Risky drug on/off*
(stand-in for the phone app's drug scan), *Med reminder in 10 s*. The page scrolls vertically (crown or swipe).

## Always-on monitoring

There is no Start button. Monitoring starts when the app opens and runs while it is on screen; leaving the app
pauses it, closes the current summary window and pushes the queue; coming back resumes it.

### Energy (what the app does while it runs)

| Cost | Before | Now |
|---|---|---|
| Accelerometer | 25 Hz always | 25 Hz while moving; **10 Hz after 30 s at rest or asleep**; back to 25 Hz on the first sample > 0.3 g away from 1 g or when the state turns active (`vitals/AccelRate.ets`). A fall from standing starts with free fall, which 10 Hz still sees, so the impact is sampled at 25 Hz (unit test). Sensors clamp the interval to their own min/max sample period; a smaller interval costs more power [S1] |
| Outbox storage | Preferences rewritten + flushed on every row (≥ 1 per 5 s, more during alerts) | written **once per sync** (every 3 s while visible, on pause, right after an SOS row); at most the last 3 s of rows are lost if the process dies between syncs |
| HTTP | new Network Kit `HttpRequest` per call (single-use by design: "Each httpRequest corresponds to an HTTP request task and cannot be reused" [S2]) | **one Remote Communication Kit session** for uploads, context polls and RPCs: shared connection pool and TLS sessions (`rcp.createSession`, since API 11, `SystemCapability.Collaboration.RemoteCommunication` is in the SDK's `wearable-hmos.json` device definition) |
| Timers | 1 s tick, 3 s upload, 60 s context poll, only while visible | unchanged |

### Background monitoring on a real watch: research

**Question:** can a third-party wearable app keep reading heart rate and raising alarms after it leaves the screen,
and what would it need?

**Findings** (sources at the end of this section):

1. **Apps are suspended in the background.** "Typically, the application process is suspended after the application
   runs in the background for a while … After being suspended, the application process cannot use software resources
   (such as common events and timers) or hardware resources (such as CPU, network, GPS, and Bluetooth)." Only the
   constrained background task types keep it alive [B1].
2. **No continuous-task mode covers health monitoring.** The modes are `dataTransfer`, `audioPlayback`,
   `audioRecording`, `location`, `bluetoothInteraction`, `multiDeviceConnection`, `wifiInteraction` (system apps),
   `voip`, `taskKeeping`, and from API 22 `avPlaybackAndRecord` / `specialScenarioProcessing` (the latter phones,
   tablets and PCs only) [B2].
3. **Declaring a mode we don't use gets the app suspended.** "If an application requests a continuous task but does
   not carry out the relevant service, the system imposes restrictions … the application will be suspended when it
   returns to the background", and the same for a service that doesn't match the type [B2]. So "location" or
   "audioPlayback" as a keep-alive trick is not an option (and would fail store review).
4. **`taskKeeping`** ("computing tasks") is the only generic mode: from API 21 it works on non-PC devices only with the
   restricted ACL permission `ohos.permission.KEEP_BACKGROUND_RUNNING_SYSTEM`; on API 20 and earlier it is PC/2-in-1
   only [B2]. Our minimum is API 20, so it would also need a runtime guard (`backgroundTaskManager.isModeSupported`,
   API 21 [B3]). ACL permissions are granted by Huawei per app on request.
5. **A continuous task needs** `ohos.permission.KEEP_BACKGROUND_RUNNING`, the mode under `backgroundModes` in
   `module.json5`, and `startBackgroundRunning(context, mode, wantAgent)`; it shows a notification, and the user can
   end it by removing that notification. API 20 allows one task per UIAbility [B2].
6. **Deferred tasks** (`WorkSchedulerExtensionAbility`) can sync history on a schedule, not monitor: at most 10 tasks,
   minimum interval 2 h for an *active* app (up to 48 h, or never, for rarely used apps), 2 min per run [B4].
7. **Health Service Kit** (the system's own all-day heart-rate data) "provides a platform for ecosystem apps to access
   users' health and fitness data based on users' HUAWEI ID and authorization"; access is applied for in AppGallery
   Connect, restricted scopes such as heart rate and blood oxygen are **manually reviewed**, and the kit is
   "available only in the Chinese mainland" [H1][H2]. The HarmonyOS atomic-service page lists phones and tablets
   and says it is not supported on the emulator [H1]; the HMS page lists WATCH 3/4 on HarmonyOS 3.0+ [H2]. We could
   not load the current HarmonyOS-app guide page to confirm wearable support for API 20+ — **unverified**.
8. **Already works without approval:** system reminders (`reminderAgentManager`) fire while the app is frozen or
   closed (verified on the emulator, see *Notifications and reminders*); the sensor and alarm logic runs while the
   app is on screen.

**Recommended production design** (unchanged in spirit, now with the constraints):
1. Foreground: our own loop, rules and upload, as today (the energy changes above apply).
2. Background: the **system** keeps measuring HR all day; the app reads that history through **Health Service Kit**
   on open and from a deferred task (≥ 2 h), and uploads it through the same outbox.
3. Live alarms while the app is closed: the system's own HR alarms, forwarded to the phone by Wear Engine
   (to confirm in `docs/research/phone-watch-link.md`, stream S7).
4. Only if Huawei grants the ACL: a `taskKeeping` continuous task during an explicit "monitor me now" session
   (e.g. after a risky drug), shown as a notification, ended by the user.

**Needs:**
- AppGallery Connect project for `ai.celia.watch`, signed with a release profile.
- Health Service Kit application (developer qualifications, heart-rate / SpO2 scopes → manual review); account in
  the Chinese mainland region, or a decision to ship there first.
- Confirmation from Huawei that Health Service Kit reads all-day HR on HarmonyOS 6 wearables (API 20+).
- Optional: ACL `ohos.permission.KEEP_BACKGROUND_RUNNING_SYSTEM` request with a medical justification, a
  `backgroundModes: ["taskKeeping"]` declaration and `KEEP_BACKGROUND_RUNNING`.
- Wear Engine access (phone side) for live system alarms.
- A real HarmonyOS watch for every item above (the emulator has no HR sensor, wear sensor or Health app).

**Sources** (read 2026-10-04):
- [B1] OpenHarmony docs, *Background Tasks overview*,
  `en/application-dev/task-management/background-task-overview.md` (gitcode.com/openharmony/docs)
- [B2] same repo, *Continuous Task (ArkTS)*, `en/application-dev/task-management/continuous-task.md`
- [B3] same repo, `en/application-dev/reference/apis-backgroundtasks-kit/js-apis-resourceschedule-backgroundTaskManager.md`
- [B4] same repo, *Deferred Task*, `en/application-dev/task-management/work-scheduler.md`
- [S1] same repo, `en/application-dev/device/sensor/sensor-guidelines.md` and
  `reference/apis-sensor-service-kit/js-apis-sensor.md` (`Options.interval`)
- [S2] same repo, `en/application-dev/reference/apis-network-kit/js-apis-http.md`
- [H1] Huawei, *Health Service Kit — About This Kit* (atomic services),
  https://developer.huawei.com/consumer/en/doc/atomic-guides/health-service-kit-ability-as
- [H2] Huawei, *Introduction to Health Service Kit*,
  https://developer.huawei.com/consumer/en/doc/HMSCore-Guides/description-0000001558389985
- Remote Communication Kit: the DevEco SDK's `hms/ets/api/@hms.collaboration.rcp.d.ts` and
  `hms/ets/api/device-define/wearable-hmos.json`

## Metrics sent (`watch_metrics` table)

| `type` | When | `payload` |
|---|---|---|
| `hr_live` | every 5 s while monitoring | `{ bpm, activity }` |
| `hr_alert` | HR outside the current limit for ≥ 10 s (60 s cooldown) | `{ bpm, limitBpm, direction, sustainedSec, activity }` |
| `hr_session` | every 5 min, and when the app is left | `{ avgBpm, maxBpm, minBpm, durationSec, samples }` |
| `symptom` | check-in answer | `{ kind: "fine" \| "dizziness" \| "palpitations" \| …, bpm }` |
| `medication_taken` | "Took nadolol" | `{ name }` |
| `fall_detected` | after a fall, when answered or after 30 s | `{ bpm, response: "ok" \| "need_help" \| "no_response", responseSec }` |
| `wear_state` | watch put on / taken off | `{ onWrist }` |
| `vitals` | every 30 s | every input above: `{ bpm, restingBpm, activity, stress, steps, hrvMs, spo2, breathingRate, irregularRhythm, highLimitBpm, lowLimitBpm, genotype, riskyDrug, mocked[] }` |
| `hr_recovery` | 60 s after an exercise bout | `{ peakBpm, bpmAfter60s, dropBpm, slow }` |
| `rhythm_alert` | irregular rhythm starts (simulated) | `{ bpm, activity, mocked: true }` |
| `vitals_alert` | low HRV / low SpO2 (simulated input) | `{ signal: "hrv" \| "spo2", value, activity, mocked: true }` |
| `sos` | SOS countdown ran out | `{ reason: "need_help" \| "fall", bpm, activity, lat?, lon?, accuracyM? }`. Location (WGS84) is fetched when the countdown starts (8 s timeout) and omitted if denied/unavailable |

The watch also **reads** `watch_context` (`device_id`, `genotype`, `risky_drug`, `risky_drug_risk`, `risky_drug_at`).
The phone app upserts it after onboarding and after each drug check that returns a QT-risk verdict:
```
POST {SUPABASE_URL}/rest/v1/watch_context   Prefer: resolution=merge-duplicates
{ "device_id": "demo-watch-1", "genotype": "LQT2", "risky_drug": "clarithromycin",
  "risky_drug_risk": "KNOWN_RISK", "risky_drug_at": "2026-10-03T12:00:00Z" }
```

Contract: `entry/src/main/ets/model/WatchMetric.ets`. Table + RLS: `backend/supabase/migrations/` (run all files in order).

Phone app reads (anon key headers `apikey` + `Authorization: Bearer`):
```
GET {SUPABASE_URL}/rest/v1/watch_metrics_latest?device_id=eq.demo-watch-1
GET {SUPABASE_URL}/rest/v1/watch_metrics?device_id=eq.demo-watch-1&type=eq.hr_alert&order=recorded_at.desc&limit=20
```

## Setup

1. Supabase: run every file in `backend/supabase/migrations/` in order, in the SQL editor (or `supabase db push`).
   A row type the database doesn't know is rejected; the app then drops just that row so the queue keeps moving.
2. Fill in `watch/.env` (copy `watch/.env.example` if it's missing): `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   optionally `WATCH_DEVICE_ID`. `.env` is git-ignored. Each build (`entry/hvigorfile.ts`) writes it into the bundled
   `rawfile/config.json` (also git-ignored), so **rebuild after editing `.env`**. Without it the app works offline
   and keeps metrics in its outbox.
3. Emulator: the unsigned HAP installs as is (verified on the HarmonyOS 6.1.1 wearable emulator). Real device:
   DevEco → File → Project Structure → Signing Configs → *Automatically generate signature*.

## Build, test, run (terminal)

One command (build → install on the wearable → launch → screenshot; picks the wearable target by device type, so the
phone emulator can stay connected; `WATCH_TARGET=<serial>` to choose, `--no-build` to reinstall):
```bash
watch/scripts/run.sh [screenshot.jpeg]
```

By hand:
```bash
cd watch && source env.sh
ohpm install
hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon
hvigorw test -p module=entry -p coverage=false --no-daemon     # 87 local unit tests
cat entry/.test/default/intermediates/test/coverage_data/test_result.txt

# Wearable emulator (image: HarmonyOS 6.1.1 wearable)
EMU=/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator
$EMU -create CeliaWatch -deviceType wearable -osVersion "HarmonyOS 6.1.1(24)"   # once (the team machine uses Huawei_Wearable)
$EMU -start CeliaWatch
hdc install -r entry/build/default/outputs/default/entry-default-unsigned.hap   # -signed.hap once signing is set up
hdc shell aa start -a EntryAbility -b ai.celia.watch
hdc hilog | grep CeliaWatch
```

## Limits (be honest in the demo)

- No QT/QTc and no ECG: PPG heart rate can't measure QT. Alerts are "heart rate outside your limits", not diagnosis.
- On the emulator, heart rate is either the virtual sensor slider or scripted demo data. Never real physiology.
- Monitoring only runs while the app is on screen (see *Always-on monitoring*).
- Hackathon auth: shared anon key + device id. Production needs device tokens and per-user RLS.
