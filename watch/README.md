# Celia Watch (HarmonyOS wearable, ArkTS)

The watch half of Celia.ai: live heart rate, deterministic LQTS heart-rate alerts with vibration, one-tap
"I feel unwell" / "medication taken" logging, and upload of small computed metrics to Supabase, where the phone app
reads them.

```
 heart-rate source ──► AlarmRules ──► alert overlay + vibration
  (sensor | demo)  ─► SessionStats
                    ─► MetricOutbox (Preferences) ──► SupabaseUploader ──► watch_metrics ──► phone app
```

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
| Demo data (scenarios: Resting, LQT1 exercise, LQT2 startle, LQT3 night) | anywhere | `simulated` |
| Watch sensor (`sensor.SensorId.HEART_RATE`, needs READ_HEALTH_DATA) | real full-HarmonyOS watch; falls back to demo on the emulator | `watch` |

## Metrics sent (`watch_metrics` table)

| `type` | When | `payload` |
|---|---|---|
| `hr_live` | every 5 s while a session runs | `{ bpm }` |
| `hr_alert` | HR outside limits for ≥ 10 s (60 s cooldown) | `{ bpm, limitBpm, direction, sustainedSec }` |
| `hr_session` | on Stop | `{ avgBpm, maxBpm, minBpm, durationSec, samples }` |
| `symptom` | "I feel unwell" buttons | `{ kind, bpm }` |
| `medication_taken` | "Took nadolol" | `{ name }` |

Contract: `entry/src/main/ets/model/WatchMetric.ets`. Table + RLS: `backend/supabase/migrations/*_watch_metrics.sql`.

Phone app reads (anon key headers `apikey` + `Authorization: Bearer`):
```
GET {SUPABASE_URL}/rest/v1/watch_metrics_latest?device_id=eq.demo-watch-1
GET {SUPABASE_URL}/rest/v1/watch_metrics?device_id=eq.demo-watch-1&type=eq.hr_alert&order=recorded_at.desc&limit=20
```

## Setup

1. Supabase: run the migration in the SQL editor (or `supabase db push`).
2. `cp entry/src/main/resources/rawfile/config.example.json entry/src/main/resources/rawfile/config.json` and fill
   in `supabaseUrl`, `supabaseAnonKey`, `deviceId`. `config.json` is git-ignored. Without it the app works offline
   and keeps metrics in its outbox.
3. Emulator: the unsigned HAP installs as is (verified on the HarmonyOS 6.1.1 wearable emulator). Real device:
   DevEco → File → Project Structure → Signing Configs → *Automatically generate signature*.

## Build, test, run (terminal)

```bash
cd watch && source env.sh
ohpm install
hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon
hvigorw test -p module=entry -p coverage=false --no-daemon     # 16 local unit tests
cat entry/.test/default/intermediates/test/coverage_data/test_result.txt

# Wearable emulator (image: HarmonyOS 6.1.1 wearable)
EMU=/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator
$EMU -create CeliaWatch -deviceType wearable -osVersion "HarmonyOS 6.1.1(24)"   # once
$EMU -start CeliaWatch
hdc install -r entry/build/default/outputs/default/entry-default-unsigned.hap   # -signed.hap once signing is set up
hdc shell aa start -a EntryAbility -b ai.celia.watch
hdc hilog | grep CeliaWatch
```

## Limits (be honest in the demo)

- No QT/QTc and no ECG: PPG heart rate can't measure QT. Alerts are "heart rate outside your limits", not diagnosis.
- The emulator has no HR sensor: heart rate on the emulator is scripted demo data.
- Hackathon auth: shared anon key + device id. Production needs device tokens and per-user RLS.
