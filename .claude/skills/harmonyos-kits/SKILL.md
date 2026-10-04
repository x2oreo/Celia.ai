---
name: harmonyos-kits
description: Catalog of HarmonyOS system kits (@kit.* imports) with minimal working patterns - networking (http, WebSocket), storage (Preferences, RDB, files), AI (Core Vision, Core Speech, Natural Language, MindSpore Lite, Agent Framework/HMAF, Intents), cross-device (continuation, distributed data object, device manager), Scan, Share, Location, Map, Notifications, Live View, widgets (Form Kit), sensors, Account. Use when picking or wiring a platform capability; always confirm signatures in Context7 before relying on them.
---

# HarmonyOS Kits

Import style: `import { module } from '@kit.XxxKit'`. Snippets below are patterns - confirm exact
signatures (Context7 `harmonyos-references`, see `harmonyos-docs`), especially for AI/agent kits that
change each release. Check each kit's "Constraints": many Huawei (closed) kits need a **real device**,
**AppGallery Connect project**, or **China region**. Open (OpenHarmony) kits work everywhere.

## Networking - `@kit.NetworkKit` (no fetch/axios by default)

```ts
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

interface ChatReq { prompt: string }
async function post(url: string, body: ChatReq): Promise<string> {
  const req = http.createHttp();
  try {
    const res = await req.request(url, {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json' },
      extraData: JSON.stringify(body),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000, readTimeout: 60000,
    });
    return res.result as string;            // res.responseCode for status
  } finally { req.destroy(); }
}
```
Needs `ohos.permission.INTERNET`. Streaming: `req.requestInStream` + `on('dataReceive')` (SSE for LLMs).
WebSocket: `webSocket.createWebSocket()`. Newer alternative: Remote Communication Kit `@kit.RemoteCommunicationKit` (`rcp`).
ohpm `@ohos/axios` exists if team prefers axios API.
**LLM calls**: never ship API keys in the HAP - call your own small backend (e.g. Vercel/Cloudflare
function) that holds the key. Emulator/device reaches internet normally.

## Storage - `@kit.ArkData`, `@kit.CoreFileKit`

```ts
import { preferences, relationalStore } from '@kit.ArkData';
const prefs = preferences.getPreferencesSync(ctx, { name: 'settings' });
prefs.putSync('onboarded', true); prefs.flush();
const store = await relationalStore.getRdbStore(ctx, { name: 'app.db', securityLevel: relationalStore.SecurityLevel.S1 });
await store.executeSql('CREATE TABLE IF NOT EXISTS note(id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT)');
```
Files: `fileIo` from `@kit.CoreFileKit`; app sandbox `ctx.filesDir`, `ctx.cacheDir`.
Pick user files without permissions: `photoAccessHelper.PhotoViewPicker` (`@kit.MediaLibraryKit`),
`picker.DocumentViewPicker` (`@kit.CoreFileKit`).

## On-device AI (strong demo material)

| Kit | Import | Capabilities |
|---|---|---|
| Core Vision Kit | `textRecognition`, `faceDetector`, `faceComparator`, `subjectSegmentation`, `skeletonDetection`, `objectDetection` from `@kit.CoreVisionKit` | OCR, faces, matting, pose, objects |
| Vision Kit (ready UI) | `@kit.VisionKit` | Document scanner, card/ID recognition, AI image interaction |
| Core Speech Kit | `speechRecognizer`, `textToSpeech` from `@kit.CoreSpeechKit` | Offline ASR + TTS (check language support - Chinese strongest; verify English/Polish) |
| Natural Language Kit | `textProcessing` from `@kit.NaturalLanguageKit` | Entity extraction, word segmentation |
| MindSpore Lite Kit | `mindSporeLite` from `@kit.MindSporeLiteKit` | Run your own .ms model (convert from TFLite/ONNX) on NPU/CPU |
| Neural Network Runtime | `@kit.NeuralNetworkRuntimeKit` (C API) | Low-level NPU |
| Scan Kit | `scanBarcode` from `@kit.ScanKit` | QR/barcode scan UI in one call |

OCR pattern:
```ts
import { textRecognition } from '@kit.CoreVisionKit';
const visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };     // pixelMap from image.createImageSource(...).createPixelMap()
const config: textRecognition.TextRecognitionConfiguration = { isDirectionDetectionSupported: true };
const result = await textRecognition.recognizeText(visionInfo, config);
// result.value = full text
```

## AI agents & system integration (HarmonyOS 6 headline features - Huawei loves these)

- **Agent Framework Kit / HMAF** (`@kit.AgentFrameworkKit`) + **Intents Kit** (`@InsightIntentEntry` in
  `@kit.AbilityKit`): this project's centrepiece - Celia (= Xiaoyi/小艺) calling our app. Full verified patterns,
  config files, availability risks and fallback architecture live in the **`celia-agent`** skill. Use it.
- **Form Kit** - service widgets (cards) on home screen: `FormExtensionAbility` + `@Entry` widget page
  + `form_config.json`. **Live View Kit** (`liveViewManager`) - lock-screen/capsule live status
  (may need AGC approval).

## Cross-device ("super device") - HarmonyOS's unique pitch

- **App continuation**: `"continuable": true` in module.json5; implement `onContinue(wantParam)` on the
  source UIAbility (put state into `wantParam`, return `AbilityConstant.OnContinueResult.AGREE`) and
  restore in `onCreate`/`onNewWant` when `launchParam.launchReason === LaunchReason.CONTINUATION`,
  then `this.context.restoreWindowStage(...)`. Large state → `distributedDataObject` (`@kit.ArkData`)
  with `setSessionId` + `save(targetDevice)`.
- **Distributed data object / KV store**: live sync of objects between same-app instances on trusted
  devices (`ohos.permission.DISTRIBUTED_DATASYNC`, user_grant).
- **Device discovery**: `distributedDeviceManager` from `@kit.DistributedServiceKit`.
- Cross-device camera/scan/pick ("service collaboration") exists - verify kit name and support in docs.
- Requires 2+ real devices logged into same HUAWEI ID - demo risk; confirm hardware with Huawei booth.

## Device & system

| Need | Import |
|---|---|
| Location | `geoLocationManager` from `@kit.LocationKit` (perms: APPROXIMATELY_LOCATION + LOCATION) or `LocationButton` |
| Map | `MapComponent`, `mapCommon`, `map` from `@kit.MapKit` (AGC + signing fingerprint config) |
| Camera | `camera` from `@kit.CameraKit`; simplest: `cameraPicker.pick(...)` |
| Sensors | `sensor` from `@kit.SensorServiceKit` (accelerometer, heart rate on wearables) |
| Notifications | `notificationManager` from `@kit.NotificationKit` (request enable first) |
| Reminders / background | `reminderAgentManager`, `backgroundTaskManager` from `@kit.BackgroundTasksKit` |
| Share sheet | `systemShare` from `@kit.ShareKit` |
| Login | `authentication` from `@kit.AccountKit` (HUAWEI ID; AGC config) |
| Push | `pushService` from `@kit.PushKit` (AGC) |
| Calendar | `calendarManager` from `@kit.CalendarKit` |
| Web content | `Web` component + `webview` from `@kit.ArkWeb` (`javaScriptProxy` bridge) |
| Haptics | `vibrator` from `@kit.SensorServiceKit` |
| Health/sports | Health Service Kit (`@kit.HealthServiceKit`, AGC + review) - verify availability |
| Watch ↔ phone | Wear Engine (Huawei console permission request; real devices only). See `docs/hackathon/conditions-research.md` §3 for what GT 5/6 Pro expose (HR yes, raw ECG/HRV no) |
| Phone call / SMS | Telephony Kit `call.makeCall` / SMS compose - verify names + permissions in Context7 before use |

## Choosing for a 24h hackathon

Low-risk, works on emulator: ArkUI, NetworkKit, ArkData, pickers, Scan, Share, Notifications, Web, Form widgets.
Medium (real device likely): Core Vision/Speech, Location, Camera, Sensors, continuation.
High (account/AGC/region): Map, Push, Account, Payment, Agent Framework, Live View, Health.
Pick one "wow" HarmonyOS-native capability (agent/intents, cross-device, on-device AI, widgets)
and build the rest on low-risk kits.
