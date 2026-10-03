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
| **Watch sensor** (default; `sensor.SensorId.HEART_RATE`, needs READ_HEALTH_DATA) | real watch, or the emulator's virtual HR sensor; falls back to demo if there is no sensor/permission | `watch` |

### Driving the sensor on the emulator

Emulator toolbar → **⋯ (more)** → **Virtual sensors** → **Heart rate**: move the slider. The app reads it through the
same `sensor.on(HEART_RATE)` code as a real watch. Drag above 140 and hold for 10 s to trigger the high-HR alert,
below 45 for the low one. The last reading counts for 30 s (sensors may report only on change); after that the
watch shows "Waiting for heart rate…".

## Always-on monitoring

There is no Start button. Monitoring starts when the app opens and runs while it is on screen; leaving the app
pauses it, closes the current summary window and pushes the queue; coming back resumes it.

**How 24/7 tracking works on a real watch (pitch):** HarmonyOS freezes apps shortly after they leave the screen, and
none of the continuous-task types (data transfer, audio, location, Bluetooth, multi-device, VoIP, task keeping)
covers heart-rate monitoring. The system checks that a declared task is real, so faking one gets the app suspended.
The watch **system** already measures heart rate around the clock (Huawei Health continuous HR). The production
design is therefore:
1. **Health Service Kit** reads the system's continuous HR history (needs Huawei approval for health data).
2. The app syncs it **on open and on a schedule** (deferred background tasks), using the same outbox → Supabase path.
3. **Live alarms** come from the system's own HR alarm, which the phone app subscribes to via Wear Engine.

What the demo shows is the part we can run on the emulator: our own monitoring loop, alert rules and upload path.

## Metrics sent (`watch_metrics` table)

| `type` | When | `payload` |
|---|---|---|
| `hr_live` | every 5 s while monitoring | `{ bpm }` |
| `hr_alert` | HR outside limits for ≥ 10 s (60 s cooldown) | `{ bpm, limitBpm, direction, sustainedSec }` |
| `hr_session` | every 5 min, and when the app is left | `{ avgBpm, maxBpm, minBpm, durationSec, samples }` |
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
2. Fill in `watch/.env` (copy `watch/.env.example` if it's missing): `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
   optionally `WATCH_DEVICE_ID`. `.env` is git-ignored. Each build (`entry/hvigorfile.ts`) writes it into the bundled
   `rawfile/config.json` (also git-ignored), so **rebuild after editing `.env`**. Without it the app works offline
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
- On the emulator, heart rate is either the virtual sensor slider or scripted demo data. Never real physiology.
- Monitoring only runs while the app is on screen (see *Always-on monitoring*).
- Hackathon auth: shared anon key + device id. Production needs device tokens and per-user RLS.
