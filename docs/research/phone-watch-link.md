# Phone ↔ watch link in production (B17)

Research for brief task B17. It compares Wear Engine, distributed data objects, Push Kit to the watch, and the
cloud relay we run today, then recommends one. Researched 2026-10-03 against the official HarmonyOS guides (EN) and
the local SDK typings (DevEco Studio 6.1.1, API 24: `hms/ets/api/@hms.health.wearEngine.d.ts`,
`openharmony/ets/api/@ohos.data.distributedDataObject.d.ts`). No code changes; the other docs here cover the parts
we can build.

## Summary

| Path | Works in Poland | Emulator | Approval | Fit for Celia |
|---|---|---|---|---|
| **Cloud relay (today)**: watch → Supabase REST → phone polls | Yes | Yes (both emulators) | None | Works now; phone sees data only while it polls (foreground) |
| **Wear Engine** P2P messages + notifications + HR alarm | **No**: "This kit for phones, tablets devices is supported only in the Chinese mainland" | **No**: "This kit does not support emulators" | AGC request, 1-2 weeks; HR alarm (`USER_STATUS`) enterprise only; HR sensor research institutions only | Best UX on Chinese devices; not usable for us |
| **Distributed data object** | Unclear for watches | No (needs two real trusted devices) | None, but `DISTRIBUTED_DATASYNC` user grant | Officially limited to cross-device migration and multi-device collaboration; not a background channel |
| **Push Kit to the watch** (standalone watch) | **Yes**: wearables are supported in Poland, "only when they are used independently with Internet access" | Untested on the wearable emulator | Push Kit enabled in AGC | Good for server → watch (e.g. "contacts alerted"); not watch → phone |
| **Push Kit to the phone** | No (China only) | Notification messages yes | Push Kit enabled | See `push-kit.md` |

**Recommendation:** keep the cloud relay as the production path in Europe and harden it (B9 RLS binding, B16 energy
work), add Push Kit to the standalone watch for server → watch messages when an AGC project exists, and put Wear
Engine behind a capability check as a China-only adapter later. Reasons: it is the only path that works in our region
and on the emulator, it already carries every message type we need (`watch/README.md` table), and the server-side
SOS dispatch (`sos` function) has to exist anyway, because neither device can text or call by itself.

## 1. The cloud relay we run today

```
watch app ── HTTPS (anon key) ──► watch_metrics, RPCs (pairing_*, watch_context reads)
phone app ── polls watch_metrics_latest every 2 s while open (vitals/WatchCloudSource.ets, POLL_MS = 2000)
          ── writes watch_context (genotype, risky drug) ◄── watch reads it (PatientContextClient)
watch_metrics{type:'sos'} ── trigger ──► sos Edge Function ──► Twilio SMS + call (dry run without secrets)
```

- Pairing: 6-digit code, RPCs `pairing_start/claim/status/device` (`20261003260000_watch_pairing.sql`), phone side
  `data/WatchPairing.ets`, watch side `sync/PairingClient.ets`.
- Weak points: (1) **RLS is open** (`watch_metrics` anon select, `watch_context` anon insert/update): anyone with
  the anon key can read every device's heart data; B9 fixes it with a device ↔ `auth.uid()` binding and a per-watch
  secret. (2) **The phone only sees the watch while the app is in the foreground**: HarmonyOS freezes backgrounded
  apps, so a watch SOS while the phone app is closed reaches the contacts (server) but not the phone. Push Kit is the
  cure but China-only on phones. (3) Both devices need internet; a watch without Wi-Fi or eSIM, connected only to the
  phone over Bluetooth, is offline for us.
- What makes it production-worthy: B9 (auth binding), B16 (outbox written once per sync, one HTTP client, lower
  sensor rate), retry with backoff already in `MetricOutbox`, and server-side dispatch that never depends on the
  phone.

## 2. Wear Engine Kit

What it offers (`@hms.health.wearEngine.d.ts`, `wearEngine.*`):

| Client | Calls | Permission (Wear Engine, not `module.json5`) | Who can get it |
|---|---|---|---|
| `getDeviceClient` | `getConnectedDevices()`, device capability checks | Basic device information | Individuals and enterprises |
| `getP2pClient` | `sendMessage` (≤ 4096 bytes), `transferFile` (≤ 100 MB), `registerMessageReceiver`, `startRemoteApp`, `isRemoteAppInstalled` | Basic device information | Individuals and enterprises |
| `getNotifyClient` | `notify()` template notifications with 0-3 buttons, button feedback | Message notification | Individuals and enterprises |
| `getMonitorClient` | `subscribeEvent(EVENT_HEART_RATE_ALARM / wearStatus / connectionStatus / lowPower …)` | `USER_STATUS` | **Enterprise** only |
| `getSensorClient` | `subscribeSensor(HEART_RATE / PPG / ECG / ACC …)` | `HEALTH_SENSOR`, `MOTION_SENSOR` | HEALTH: "qualified research institutions" only; MOTION: enterprise |
| `getAuthClient` | `requestAuthorization({permissions})` (user consent screen) | — | — |

Constraints ([we-business_introduction]): phones and tablets, wearables since 5.1.0(18); **phones only in the
Chinese mainland**; **no emulator**. Testing needs Huawei Health installed on the phone, signed in with a HUAWEI ID,
the watch paired in Health, and both apps installed and launched ([wearengine_verification]). Both ends must be
running for P2P ("Both the app on the peer device and that on the wearable must be launched").

How to apply ([wearengine_apply]):
1. AGC → project → app → Project settings → Manage open capabilities → **Manage** next to Wear Engine.
2. HUAWEI Developers → Console → Application service → **Wear Engine** card → Applying for the Wear Engine Service →
   accept the agreement.
3. Select *HarmonyOS App*, the product, and permissions. As individual developers we can only request *basic device
   information* and *message notification*.
4. Upload the data permission and usage description and the user authorization path description (screenshots of the
   consent screen; Huawei's .xlsx templates are linked from the page).
5. Wait **1-2 weeks**. The region is part of the review ("availability based on the regulatory requirements of the
   app's release region").

What it would give Celia on a Chinese device: phone → watch verdict glance without the cloud (P2P message), template
notification "Don't take X" with an "OK" button, and, with enterprise approval, the system's own heart-rate alarm
on the phone even when our watch app is closed (`EVENT_HEART_RATE_ALARM`). That last one is the production answer to
"monitoring is foreground-only" (`watch/README.md` "Always-on monitoring").

Adapter shape if ever enabled: a `WearEngineSource implements` the phone's existing vitals source interface, chosen
at runtime when `getConnectedDevices()` returns a watch and authorization is granted, else the cloud source.
ARCHITECTURE already names `WearEngineSource`.

## 3. Distributed data objects (ArkData)

From [data-sync-of-distributed-data-object]:
- "Currently, distributed data objects can be used only in cross-device migration scenarios and multi-device
  collaboration scenarios implemented through cross-device calls." For third parties, "only the distributed migration
  scenario opens the call invocation permission" ([uiability-cross-device-interaction]).
- Same app, same `sessionId`, devices on a trusted network (same HUAWEI ID); at most 3 devices, 16 objects, 150 KB
  (migration) or 500 KB (collaboration); `ohos.permission.DISTRIBUTED_DATASYNC` (user_grant).
- Not a messaging channel: it syncs while both sides hold the object open. It does not wake a closed app or survive
  the phone being away.

Fit: a nice "continue on phone" for the doctor brief or the card (app continuation), not for vitals or SOS.
Watch support for migration is not stated in the pages we read; treat it as unverified. Emulators cannot form a
trusted network (the brief's facts: "The two emulators cannot see each other over Bluetooth").

## 4. Push Kit to a standalone watch

Covered in `push-kit.md` ("Possible alternative for the watch"). Key facts: wearables 5.1.0(18)+, Poland listed,
only when the watch has its own internet; notification messages. It would carry server → watch events (dispatch
result, a risky drug scanned on the phone) instead of the watch polling `watch_context`. Needs an AGC project with Push
Kit and S6's watch app signed with that profile.

## Emulator vs real devices

| Path | Phone emulator + wearable emulator | Real phone + real watch (Europe) |
|---|---|---|
| Cloud relay | ✅ verified (both emulators, demo) | ✅ expected (both need internet) |
| Wear Engine | ❌ not supported | ❌ region (China only) |
| Distributed data object | ❌ no trusted network | ⚠️ migration scenarios only, same HUAWEI ID |
| Push to watch | ⚠️ untested | ✅ expected with AGC setup |

## Needs

- Nothing for the recommended path beyond B9 (device ↔ account binding, Georgi's go-ahead) and B16.
- Wear Engine: AGC project + app, a Wear Engine service application (1-2 weeks), an **enterprise** developer account
  for the heart-rate alarm, a **Chinese-mainland phone** with Huawei Health and a paired HarmonyOS watch.
- Push to watch: AGC project with Push Kit, a real HarmonyOS watch with its own internet (Wi-Fi or eSIM).

## Sources

- [we-business_introduction] Wear Engine: About the Service (capabilities, regions, emulator) — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/we-business_introduction
- [wearengine_apply] Applying for Wear Engine — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/wearengine_apply
- [wearengine_verification] Debugging and Verification — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/wearengine_verification
- Watch-side P2P — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/watch_p2p_communication
- Wear Engine API reference — https://developer.huawei.com/consumer/en/doc/harmonyos-references/wearengine_api
- [data-sync-of-distributed-data-object] Cross-Device Sync of Distributed Data Objects — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/data-sync-of-distributed-data-object
- [uiability-cross-device-interaction] Cross-device call invocation — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/uiability-cross-device-interaction
- Push Kit regions and wearables — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/push-kit-introduction
- Repo: `watch/README.md`, `vitals/WatchCloudSource.ets`, `backend/supabase/functions/sos/`, `docs/hackathon/conditions-research.md` §3
