# Celia Watch (HarmonyOS wearable, ArkTS)

The watch half of Celia.ai: live heart rate, deterministic LQTS heart-rate alerts with vibration, one-tap
"I feel unwell" / "medication taken" logging, and upload of small computed metrics to Supabase, where the phone app
reads them.

```
 heart-rate source ──► AlarmRules ──► alert overlay + vibration
  (sensor | demo |  ─► SessionStats
   GT 6 Pro bridge)  ─► MetricOutbox (Preferences) ──► SupabaseUploader ──► watch_metrics ──► phone app
```

## Why this is an ArkTS wearable app, not a GT 6 Pro app

The Huawei Watch GT series runs *lite wearable* apps (JS). We checked the HarmonyOS 6.1.1 SDK: the lite wearable
device definition has **no network capability** (no NetStack syscap, no `fetch`/`http`), and the only way off the
watch is Wear Engine P2P to a companion phone app with Huawei approval. With iPhones only, a GT app can't reach our
server. So:

- The **watch app** is a full HarmonyOS **wearable** app (API 20+), running on the wearable emulator.
- **Real GT 6 Pro data** comes in through `tools/hr-bridge`: the GT 6 Pro broadcasts heart rate over standard BLE
  during a workout ("Share heart rate"), a Mac script reads it, and the emulator app polls it (source
  "GT 6 Pro (Mac)"). Latency is about 1–2 s.
- Without the watch, the **demo** source plays scripted LQTS scenarios. Demo data is always labelled.

## Heart-rate sources (Settings page, tap to cycle)

| Source | Where it runs | Metric `source` |
|---|---|---|
| Demo data (scenarios: Resting, LQT1 exercise, LQT2 startle, LQT3 night) | anywhere | `simulated` |
| Watch sensor (`sensor.SensorId.HEART_RATE`, needs READ_HEALTH_DATA) | real full-HarmonyOS watch; falls back to demo on the emulator | `watch` |
| GT 6 Pro (Mac) via `tools/hr-bridge` | emulator + Mac + GT 6 Pro in a workout | `bridge` |

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

## Real GT 6 Pro heart rate

```bash
cd tools/hr-bridge
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python hr_bridge.py          # or --fake to test without the watch
```
On the watch: start a workout with **Share heart rate** enabled (workout settings). In the app: Settings → Source →
"GT 6 Pro (Mac)". The emulator reaches the Mac at `http://10.0.2.2:8787`; if that fails, run
`hdc rport tcp:8787 tcp:8787` and set `"bridgeUrl": "http://127.0.0.1:8787"` in `config.json`.

## Limits (be honest in the demo)

- No QT/QTc and no ECG: PPG heart rate can't measure QT. Alerts are "heart rate outside your limits", not diagnosis.
- The emulator has no HR sensor; real data needs the bridge (workout running, Mac nearby).
- Hackathon auth: shared anon key + device id. Production needs device tokens and per-user RLS.
