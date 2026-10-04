# S6 watch

> Status (4 Oct 2026): working log of stream S6; merged into `main`, entry folded into `AI_WORKFLOW.md`. `watch/.env` and `watch/build/` are local files, not in git.

## AI_WORKFLOW entry
### 2026-10-04 - Georgi + Claude Code: watch internals, energy, background research (branch `georgi/b-watch`)
- Asked: brief B16 - a build-and-install script for the watch, split `WatchController` (sensors, rules, SOS, sync,
  pairing) without behaviour change, energy (slower accelerometer at rest, outbox written once per sync, one reused
  HTTP client), background-monitoring research into `watch/README.md` with sources and a needs list.
- Produced:
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
- Validated:
  - Watch unit tests 47 → 87, all passing after every commit; HAP builds (strict ArkTS) after every commit.
  - Wearable emulator (HarmonyOS 6.1.1, API 24): before/after screenshots of all four pages are identical
    (`docs/screenshots/b/watch-before-*.jpeg`, `watch-after-*.jpeg`); SOS from the check-in page counts down and ends
    in "SOS saved" offline (`watch-after-sos-*.jpeg`); hilog shows `accelerometer every 100 ms` ~33 s after start at
    rest.
  - With a temporary `.env` and device id `b-watch-s6-test`: a check-in row reached `watch_metrics` through the new
    rcp session (checked with read-only SQL) and `pairing_start` returned a code. `.env` removed afterwards.
- Not validated:
  - Accelerometer rate and fall detection on a real watch (the emulator accelerometer reports on change only; the
    10 Hz fall case is covered by a unit test, not by hardware).
  - Upload on a real watch; the context GET path on a device with a `watch_context` row (code path unchanged apart
    from the transport).
  - Health Service Kit support on HarmonyOS 6 wearables (the current guide page did not load; see README).
- Docs sources: Context7 was not connected in this session; APIs were checked in the OpenHarmony docs repo
  (gitcode.com/openharmony/docs), the DevEco SDK declarations (`@hms.collaboration.rcp.d.ts`,
  `device-define/wearable-hmos.json`) and Huawei's Health Service Kit pages. All listed in `watch/README.md`.

## README "How to verify" rows
| Watch build + install | `watch/scripts/run.sh` with the `Huawei_Wearable` emulator running → screenshot in `watch/build/screenshot.jpeg` |
| Watch internals split | `cd watch && source env.sh && hvigorw test -p module=entry -p coverage=false --no-daemon` → 87/87 |
| Accelerometer slows at rest | run the watch app, keep the emulator still 30 s, `hdc -t <watch> hilog \| grep CeliaWatch` → `accelerometer every 100 ms` |
| Shared HTTP session | with `watch/.env` filled, tap *Fine* on the check-in page → row in `watch_metrics` for the device id |

## DESIGN.md subsection (new screens only)
None. No screen changed.

## ARCHITECTURE notes
- Watch controller = façade + five units (`watch/README.md` → *Code map*). The screens only read
  `WatchController` fields and call its methods; the units are `@ObservedV2` where the screens read their state
  (`SosFlow`, `PairingFlow`, `SyncEngine`, `HeartRules`) and plain classes otherwise (`SensorHub`).
- Energy: accelerometer 25/10 Hz policy, one outbox write per sync (≤ 3 s of rows at risk on a crash), one rcp
  session for the app's lifetime.
- Background monitoring: not possible for a third-party watch app without approvals; see README *Background
  monitoring on a real watch* (production design + needs list).

## For Workstream A (routes, functions, contracts)
- No route, screen, string or token changed. `WatchController`'s public fields and methods are the same, so screen
  restyling (Phase 2) can keep using `ctrl.<field>`.
- `AlertKind` now lives in `controller/HeartRules.ets`, `PairState` / `PairScreen` in `controller/PairingFlow.ets`,
  `SyncState` in `controller/SyncEngine.ets` (nothing imported them from `WatchController` at the time of the split).

## Coordinator notes
- Test count for README / AI_WORKFLOW: watch 87 (was 47 on `georgi/integration`; the brief's "43" was older).
- The `Huawei_Wearable` emulator runs on its own hdc target (`127.0.0.1:5557` here when the phone emulator is on
  5555); `run.sh` finds it by device type. If the watch starts first it takes 5555, and phone scripts without `-t`
  would hit the watch.
