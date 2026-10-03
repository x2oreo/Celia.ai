# Live View and lock-screen presence (B13)

Research for brief task B13, written so stream S4 can implement without re-reading the Huawei docs. Researched
2026-10-03 against the official HarmonyOS guides and references (EN) and the local SDK typings (DevEco Studio 6.1.1,
API 24: `hms/ets/api/@hms.core.liveview.*.d.ts`, `openharmony/ets/api/@ohos.window.d.ts`).

## Verdict

| Question | Answer |
|---|---|
| Can we get Live View for the SOS countdown? | **Very unlikely, and not in Europe.** "Currently, Live View Kit is available only in the Chinese mainland" and only on phones and tablets ([liveview-introduction]). Every scenario needs an AGC request that is reviewed (up to 5 working days), and **no listed scenario covers an emergency countdown** (details below). |
| Does it run on the emulator? | The kit "supports the Emulator", except location-based alerts, weather backgrounds and service buttons. But `startLiveView` still checks the app's permission, so without approval it fails (1003500005 "The right of liveView is not enabled") and `isLiveViewEnabled()` reflects the user switch. Our fallback (an ongoing notification) is what runs today. |
| Is `emergency/LiveStatus.ets` correct if approval ever arrives? | **Probably not.** The reference marks `primary.clickAction` (a `WantAgent`) and `primary.layoutData` as required "for live view creation". The SDK typings declare them optional, so the current code compiles but would likely be rejected at runtime even with approval. Fix below. |
| Lock-screen medical ID card from a third-party app? | **Yes, as a lock-screen widget (Form Kit).** Set `"renderingMode": "autoColor"` (home + lock screen) or `"singleColor"` (lock screen only) in `form_config.json`, API 15+. The user adds it to the lock screen themselves. It is **single-colour** (no hue: our red risk colour cannot show), and it is visible to anyone who picks up the phone. |
| Show our own window over the lock screen (like Android `showWhenLocked`)? | **No.** `WindowStage.setShowOnLockScreen` is not in the public SDK 6.1.1 typings (`@ohos.window.d.ts` has no such method; only a deprecated API-7 stub in `app/context.d.ts` that points to it). It is a system API. |

What to ship: keep the notification fallback, fix the Live View payload so the code is correct if a Chinese device
ever has approval (label it "built, unverified, needs AGC approval and a Chinese-mainland device"), and build a
lock-screen variant of the medical alert widget, the one lock-screen surface a third-party app gets in Europe.

## 1. Live View Kit

### Which scenario fits an SOS countdown

From the scenario table in [liveview-introduction] (event value → official scope):

| Event | Why it does or doesn't fit |
|---|---|
| `TIMER` (Timing) | Closest in shape: "a short-duration count-up timer or a countdown before a task begins … focused work sessions, Pomodoro timers, and ticket purchase countdowns". But: "**only applicable to tool apps**", "the corresponding live view can only be created and updated on the device side", and the exclusion list includes reminders of many kinds. A health app's emergency countdown is not a listed use. |
| `PROGRESS`, `QUEUE`, `WORKOUT`, … | Different purpose; using them for SOS would be misclassification, which the docs treat as a violation ([push-punishment-standards]). |

Eligibility rules that the SOS countdown does meet: it is triggered by the user's own device (a fall or "need
help"), has a start and end, lasts far less than 8 hours, and has no marketing purpose. Request `TIMER` and explain
the medical-safety case in the reason text. Expect a possible rejection, and keep the fallback either way.

Push-driven live views (creating one from the server) only support `FLIGHT, TAXI, TRAIN, DELIVERY, QUEUE, RENT,
EXPRESS, CHECK_IN, TRADE, SUBSCRIBE_TIMER`; `TIMER` is device-side only, so a watch SOS cannot start a Live View on a
backgrounded phone through Push Kit.

### Applying (AGC)

From [liveview-rights]:
1. Prerequisites: an AGC project and app for `com.celiaai.app` (see `push-kit.md` AGC steps 1-3). Live View
   messages also need **Push Kit enabled** on the project ([liveview-introduction] → General Restrictions).
2. AppGallery Connect → Development and services → project → app → **Project settings → Manage open capabilities →
   Request** next to Live View Kit.
3. Fill in scenarios (`TIMER`), the scenario description, and an attachment following the "Request reason" template.
   Huawei suggests designing the nodes with the
   [LiveViewDevelopmentAssistant](https://gitcode.com/HarmonyOS_Samples/live-view-kit_-sample-code_-clientdemo_-arkts/blob/master/LiveViewDevelopmentAssistantGuide.md)
   and attaching the export. Design rules: [liveview-design-formula].
4. Result within **5 working days**, in the AGC interaction center.
5. After approval: Certificates, app IDs, and profiles → Profiles → Add → new profile → download → sign with it
   (manual signing). The approval lives in the profile, so the app has to be re-signed.

### What the capsule and lock-screen card can show

A live view has a **widget** (notification panel and lock screen: `liveViewData.primary`) and an optional
**capsule** (status bar and lock screen: `liveViewData.capsule`). From [liveview-liveviewmanager]:

- `primary.title` (< 1024 chars), `primary.content: RichText[]` (one text colour for all parts), `primary.keepTime`
  (seconds it stays after the end, 0-3600), `primary.clickAction: WantAgent` (required on create per the reference; optional in the typings),
  `primary.layoutData` (same: `ProgressLayout | PickupLayout | FlightLayout | ScoreLayout |
  NavigationLayout`), `primary.extensionData` (auxiliary area with its own `clickAction`).
- `capsule`: `CAPSULE_TYPE_TEXT` (title + content), `CAPSULE_TYPE_TIMER` (`time` in ms, `isCountdown`,
  `isPaused`, `content`), `CAPSULE_TYPE_PROGRESS`. Each has `status`, `icon` (rawfile name or `PixelMap`),
  `backgroundColor`.
- `timer: LiveViewTimer` on the live view (`time`, `isCountdown`, `isPaused`): the system ticks it every second and
  substitutes `${placeholder.timer}` in `primary.title`/`content`. So **one start call is enough, with no update
  every second**. Since 6.0.0(20), `capsuleCountdownPreset` / `countdownPreset` set the text that appears at zero
  ("Contacts alerted").
- `liveViewLockScreenPicture` / `liveViewLockScreenAbilityName` (5.0.0(12)): an immersive lock-screen view rendered
  by a `LiveViewLockScreenExtensionAbility`. It needs the same Live View approval.
- `sequence` must increase on every update and end, otherwise 1003500011; if omitted, the kit manages it.
- `isMute` defaults to silent. Set `false` for SOS.
- Limits: lifecycle at most 8 h; not updated for 2 h → capsule disappears; 4 h → removed; per app 10 creates and 20
  updates per second.

Error codes worth logging distinctly ([liveview-error-code]): 1003500004 Live View disabled (user switch),
1003500005 permission not granted (no AGC approval), 1003500006 already exists, 1003500008 rate limit.

### Fix for `emergency/LiveStatus.ets` (S4)

Today's `view()` sends only `primary.title`, `primary.content` and `keepTime`, and updates every second. Replace it
with one start that carries a countdown timer, a timer capsule, `clickAction` and a layout:

```ts
import { liveViewManager } from '@kit.LiveViewKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';

private static async build(seconds: number, reason: string): Promise<liveViewManager.LiveView> {
  const info: wantAgent.WantAgentInfo = {
    wants: [{ bundleName: 'com.celiaai.app', abilityName: 'EntryAbility', parameters: { route: 'sos' } }],
    actionType: wantAgent.OperationType.START_ABILITIES,
    requestCode: 0,
    actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
  };
  const tap: WantAgent = await wantAgent.getWantAgent(info);
  const v: liveViewManager.LiveView = {
    id: LIVE_ID,
    event: 'TIMER',
    isMute: false,
    timer: { time: seconds * 1000, isCountdown: true, isPaused: false },
    liveViewData: {
      primary: {
        title: 'SOS in ${placeholder.timer} — tap if you are OK',
        content: [{ text: reason.length > 0 ? reason : 'Emergency contacts will be alerted' }],
        keepTime: 60,
        clickAction: tap,
        layoutData: {
          layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
          progress: 0
        }
      },
      capsule: {
        type: liveViewManager.CapsuleType.CAPSULE_TYPE_TIMER,
        status: 1,
        icon: 'sos_capsule.png',          // file in resources/rawfile; add one (monochrome, small)
        backgroundColor: '#FFC62828',      // must come from a DESIGN.md token; read the resource, do not hard-code
        content: 'SOS',
        time: seconds * 1000,
        isCountdown: true,
        isPaused: false
      }
    }
  };
  return v;
}
```

- Check every field name against `@hms.core.liveview.liveViewManager.d.ts` at compile time. Strict ArkTS needs
  the typed `wantAgent.WantAgentInfo` and `liveViewManager.LiveView` declarations shown here. The colour above is a
  placeholder: take it from the colour resource DESIGN.md names for emergency (no new hard-coded colours).
- `updateSos` then has nothing to do for Live View (the system ticks the timer); keep the 5 s refresh only for the
  notification fallback. `end()` calls `stopLiveView` with a view whose `primary.title` says "Contacts alerted" or
  "Cancelled", `keepTime` as above.
- Keep the `try/catch` and fallback exactly as now. Log the error code so the hilog shows 1003500005 on the emulator
  ("not approved"), which is the honest evidence for the README.
- Unit-testable part: a pure `sosLiveViewText(seconds, reason)` returning title/content strings. The `LiveView`
  object itself needs a context, so it is not unit-testable.

### Test on a real phone (only if approved and the phone is a Chinese-mainland device)

1. Settings → Notifications & status bar → **Live view**: the app's switch must be on (`isLiveViewEnabled()`).
2. Sign the HAP with the profile generated after approval; `app/scripts/device.sh`.
3. Start a test SOS (Settings → Test SOS). Expected: capsule with a 30 s countdown in the status bar; lock the phone
   → lock-screen card with the same countdown; tap → app opens on the SOS page; "I'm OK" → view ends.
4. `hdc shell hilog -x | grep LiveStatus` must show no `Live View not available` line.
5. Without approval (expected for us): the same steps show the ongoing notification instead; the log shows
   1003500005. Record that.

## 2. Lock-screen medical ID card

### Options checked

| Option | Third-party app? | Notes |
|---|---|---|
| Lock-screen **widget** (Form Kit) | **Yes** | `renderingMode` in `form_config.json`, since API 15. `autoColor`: "can be added to the home screen or lock screen"; `singleColor`: "can be added to the lock screen"; `fullColor` (default): home screen only ([arkts-ui-widget-configuration]). Sizes on phones: `1*2`, `2*2`, `2*4`, `4*4`, plus `1*1` lock-screen only. |
| Live View lock-screen card / immersive view | Only with Live View approval (China) | §1 |
| Window over the lock screen | **No** | `setShowOnLockScreen` is a system API, absent from the public SDK |
| System "Emergency information" / medical info in Settings | No API found | No public module in SDK 6.1.1 writes to it (searched `openharmony` and `hms` API folders for medical/emergency/SOS). Users can fill it in themselves; onboarding can suggest it as a tip without claiming integration |
| Notification on the lock screen | Yes, already | A persistent notification can show text on the lock screen, depending on the user's lock-screen notification setting; not a card |

### What a lock-screen widget can and cannot do

- The user adds it: the docs only describe adding widgets from the home screen (touch and hold the app icon →
  widget). Lock-screen editing is a system UI (touch and hold or pinch on the lock screen to edit, per user guides).
  The app cannot place it.
- `singleColor` "uses transparency and blur to distinguish elements without using any hue", and the widget user
  may change colours. So the card cannot rely on our red/amber risk colours; use weight, size and an icon, never
  colour alone (DESIGN.md risk language already requires a label).
- Anyone holding the locked phone can read it. That is the point of a medical ID, but it must be opt-in and show only
  what the user picked: reuse S2's "show on card" switches (`hiddenOnCard[]`), and default to name + "Long QT
  syndrome" + "Do not give QT-prolonging drugs" + "Has ICD" if set. Contacts' phone numbers should stay off it by
  default.
- A tap on a lock-screen widget asks the user to unlock before the app opens (assumed from the system, not
  stated in the Form Kit pages we read: **verify on the real phone**). The responder page therefore cannot be relied
  on behind the lock; the widget itself has to carry the key facts.
- Data comes from the same snapshot as the existing `AlertCard` (`widget/WidgetData.ets`, written by
  `widget/WidgetSync.ets`), so no new data flow and no network.

### Build steps (S2 owns `widget/pages/AlertCard.ets`; coordinate, or S4 adds a separate card)

1. `form_config.json`: add a third form, keep the existing two unchanged:
   ```json
   {
     "name": "medid",
     "displayName": "$string:widget_medid_name",
     "description": "$string:widget_medid_desc",
     "src": "./ets/widget/pages/MedIdCard.ets",
     "uiSyntax": "arkts",
     "window": { "designWidth": 720, "autoDesignWidth": true },
     "colorMode": "auto",
     "renderingMode": "autoColor",
     "isDefault": false,
     "updateEnabled": false,
     "defaultDimension": "2*4",
     "supportDimensions": ["2*2", "2*4"],
     "isDynamic": true
   }
   ```
   `autoColor` lets the same card sit on the home screen in colour and on the lock screen in single-colour. If the
   lock-screen picker does not offer it on the device, try `singleColor` (lock screen only) as a separate form.
2. `MedIdCard.ets`: reads the same `LocalStorageProp` keys as `AlertCard`; large text; no colour-only meaning.
3. `EntryFormAbility.onAddForm` already returns `readAlertCard(...)`, so the new card gets data with no change.
   `WidgetSync` must also refresh it (its form ids are stored in the same list).
4. Strings in `string_<stream>.json`, English.

### Test steps

- Emulator: build, install, then try adding the widget to the lock screen (lock the emulator → touch and hold or
  pinch the lock screen → edit → widgets). If the emulator has no lock-screen editing, note "lock-screen placement
  verified only on a real phone" and screenshot the home-screen variant.
- Real phone: same, plus check that the card is legible in single-colour mode in light and dark wallpaper, and
  what a tap does while locked.

## Needs

- **AGC project + app** for `com.celiaai.app` with **Push Kit enabled** (prerequisite for Live View).
- **Live View Kit request approved** for scenario `TIMER` (5 working days, outcome uncertain: the scenario is meant for
  tool apps).
- **A Chinese-mainland HarmonyOS phone** to see a Live View at all; re-signing with the post-approval profile.
- For the lock-screen widget: nothing beyond the code. Placement on the lock screen needs a real phone or an emulator
  that supports lock-screen editing (unverified).

## Sources

- [liveview-introduction] About Live View Kit (regions, scenarios, limits, emulator) — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/liveview-introduction
- [liveview-rights] Enabling Live View Kit — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/liveview-rights
- [liveview-create-locally] Creating a Local Live View (capsule, timer, tap action) — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/liveview-create-locally
- [liveview-design-formula] Live View Design Specifications — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/liveview-design-formula
- [liveview-liveviewmanager] `liveViewManager` reference — https://developer.huawei.com/consumer/en/doc/harmonyos-references/liveview-liveviewmanager
- [liveview-error-code] Live View error codes — https://developer.huawei.com/consumer/en/doc/harmonyos-references/liveview-error-code
- `LiveViewLockScreenExtensionAbility` — https://developer.huawei.com/consumer/en/doc/harmonyos-references/liveview-lock-screen-ability
- [push-punishment-standards] Violation penalty criteria — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/push-punishment-standards
- [arkts-ui-widget-configuration] Widget configuration (`renderingMode`, sizes) — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkts-ui-widget-configuration
- Form Kit overview ("home screen and system apps such as the lock screen") — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/formkit-overview
- Live View sample — https://gitcode.com/HarmonyOS_Samples/live-view-kit_-sample-code_-clientdemo_-arkts
