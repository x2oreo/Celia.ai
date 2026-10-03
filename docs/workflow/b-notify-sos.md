# S4 notify-sos

## Notification Kit — what was confirmed before coding (2026-10-03)

Sources: the SDK's own declaration files in DevEco Studio (`sdk/default/openharmony/ets/api`, SDK API 24, each
member carries `@since`), Context7 (`/websites/developer_huawei_consumer_cn_doc_harmonyos-guides` and
`-references`, queried over its HTTP API because the Context7 MCP was not connected), and the OpenHarmony guide
Markdown.

- Guides: [notification-slot](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/notification-slot),
  [notification-with-wantagent](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/notification-with-wantagent),
  [text-notification](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/text-notification),
  [notification-enable](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/notification-enable).
- Reference: `@ohos.notificationManager.d.ts`, `notification/notificationRequest.d.ts`,
  `notification/notificationActionButton.d.ts`, `@ohos.app.ability.wantAgent.d.ts`, `@ohos.reminderAgentManager.d.ts`.

| Question | Answer (API 20 safe) |
|---|---|
| Slot types a third-party app can use | `SOCIAL_COMMUNICATION` (1) and `SERVICE_INFORMATION` (2): panel, banner, lock screen, sound/vibration, status-bar icon, screen-on. `CONTENT_INFORMATION` (3) and `OTHER_TYPES`: panel only, silent. `LIVE_VIEW` (4): a third-party app cannot create it. `CUSTOMER_SERVICE` (5): user-initiated chats only. Since 9/12. |
| How a notification picks its slot | `NotificationRequest.notificationSlotType` (since 11; `slotType` is deprecated since 11). The slot is created automatically if missing; `addSlot` is not required. |
| Action buttons | `NotificationRequest.actionButtons: NotificationActionButton[]` (since 7), at most **two** by default. A button is `{ title: string, wantAgent: WantAgent, extras?, userInput? }`. The guide: with buttons, the first tap on the notification expands it to show them; tapping a button triggers that button's WantAgent. |
| What a WantAgent can do | `wantAgent.OperationType`: `START_ABILITY`, `START_ABILITIES`, `START_SERVICE` (FA model only since 12), `SEND_COMMON_EVENT`. There is **no** ServiceExtension option for a third-party app. |
| Acting without opening the app | Only `SEND_COMMON_EVENT`, which reaches a subscriber that is alive. Static subscribers (`StaticSubscriberExtensionAbility`) are not in the public SDK, so a closed app never hears the event and the action would be lost silently. |
| Reminder agent buttons | `reminderAgentManager.ActionButtonType`: only `CLOSE` and `SNOOZE` for third-party apps. `wantAgent.parameters` (since 12) can carry where to go on tap. |

**Decision:** every button opens the app (`START_ABILITY`) with `parameters.notifyAction` and the app acts on it
at once. A dose button that seems to work but loses the tap when the app was closed would be worse than one that
opens the app. So "Taken" opens Celia, records the dose, and lands on Reminders showing it as TAKEN.

Slots per kind (`common/NotifyAction.ets` `slotFor`):

| Kind | Slot | Buttons |
|---|---|---|
| Emergency (SOS countdown, watch SOS) | `SOCIAL_COMMUNICATION` (loud, lock screen, screen-on; switchable apart from the rest) | Countdown: `I'm OK` · `Open`. Watch SOS: tap opens the SOS page. |
| Heart alert | `SERVICE_INFORMATION` | `I'm OK` · `Open` (Heart tab) |
| Dose due | `SERVICE_INFORMATION` | `Taken` · `Open` (Reminders) |
| Risky check | `CONTENT_INFORMATION` (quiet; the user just saw the verdict in the app) | tap opens History |

Verified on the emulator (Pura 90, API 24 image, app built for API 20) through `getActiveNotifications()`: the
system keeps the slot and the buttons as published (dose `slot=2 buttons=Taken|Open`, heart alert
`slot=2 buttons=I'm OK|Open`, risky check `slot=3`, watch SOS `slot=1`). The emulator's notification panel does
**not draw action buttons** (tried tap and swipe-to-expand), so the buttons themselves are unverified on screen; on a
real phone the guide says the first tap on the notification shows them. An app cannot fire its own `START_ABILITY`
WantAgent to fake a tap (the system answers "caller unfocused / PERMISSION_DENIED"), so each button was checked by
delivering the exact Want its WantAgent carries (`aa start … --ps notifyAction … --pi notifyId …`).

## AI_WORKFLOW entry
### 2026-10-03 — Georgi + Claude Code: actionable notifications and an honest watch SOS (branch `georgi/b-notify-sos`)
- Asked: B7 (notification slots per kind, action buttons, taps open the right page) and B8 (a watch SOS must not
  start a second countdown; the SOS page says what was sent, to whom, and what still needs a tap; a "For first
  responders" button once the countdown ends).
- Produced: `common/NotifyAction.ets` (pure: kinds, slots, buttons, request codes, tap parsing, targets),
  `common/Notify.ets` (slot + buttons + one WantAgent per button), tap handling in `EntryAbility.handleNotifyTap`,
  `ReminderService.takeFromNotification` + `DoseSchedule.takeableFromNotification`, `HeartOkRequest`;
  `SosController.watchSent` (state SENT, `sentBy` WATCH, cooldown), `VitalsAlert.watchSos` set by
  `WatchCloudSource` on `sos` rows, `Index.onWatchSos`, the SOS page status card and responder button,
  `LiveStatus.watchSos`. Fixed an existing bug: a manual SOS has no reason, the countdown notification had empty
  text and the system rejected it (401), so it never showed.
- Validated: 227/227 phone unit tests (16 new: notification kinds/slots/buttons/request codes/tap parsing, dose
  "Taken" only when due or missed, controller watch states, watch `sos` row mapping). Emulator: countdown page and
  its notification, phone sent state, responder route, all four notification kinds published with the right slot
  and buttons, "Taken" recorded the dose and landed on Reminders, "I'm OK" closed a running countdown, heart alert
  Open → Heart tab, risky check → History, watch SOS → page in sent state with no countdown and its notification.
  Screenshots `docs/screenshots/b/notify-sos-*.jpeg`.
- Not validated: action buttons drawn on screen (the emulator panel does not render them); a watch SOS from a real
  watch row end to end (the sent state was opened with a temporary, uncommitted hook calling the same controller and
  page path; the row → alert mapping is unit tested); notification taps from a cold start.

## README "How to verify" rows
| Notifications per kind (B7) | Settings → notifications for Celia.ai: emergency is a separate loud category. Start an SOS countdown and pull down the panel: "SOS in N s" notification. Real phone: tap it to show I'm OK / Open (built, unverified on screen: emulator does not draw buttons). |
| Dose "Taken" from the notification (B7) | Add a reminder; when it is due the notification has Taken / Open. Taken opens Celia on Reminders with the dose TAKEN. Emulator check: `hdc shell aa start -a EntryAbility -b com.celiaai.app --ps notifyAction DOSE_TAKEN --ps notifyKind DOSE_DUE --pi notifyId <2000+id%1000> --pi reminderId <id>` |
| Watch SOS without a second countdown (B8) | Press SOS on the paired watch. The phone opens "Your watch sent an SOS" directly (no countdown): what was sent, to whom, what still needs a tap, plus For first responders. |
| SOS page honesty (B8) | Let a phone SOS countdown run out: "Nothing has been sent yet … Nobody yet", then the call / share / contact / responder buttons. |

## DESIGN.md subsection (new screens only)
**SOS sent state** (extends 10.2 "Emergency (active / SOS)"): after the countdown (or straight away for a watch SOS)
the page shows the title (`title-1`; "Your watch sent an SOS" when the watch sent it, else "Get help now"), the
subtitle in `ink_3`, then a **status card**: `surface`, 1 vp `border`, `radius_m`, padding `space_m`, three rows
separated by `divider` — caps label (`font_caption`, bold, `ink_3`: WHAT WAS SENT · TO WHOM · STILL NEEDS A TAP) over
`font_small` `ink_2` text. Never a risk colour on the card: it is a report, not a verdict. Below it: danger "Call
ambulance", secondary "Send SOS message", one secondary "Call {name}" per contact, secondary **For first
responders** (doctor icon), the location line and the message preview.

## ARCHITECTURE notes
- Notification buttons always open the app (`START_ABILITY` WantAgent with `notifyAction`, `notifyKind`,
  `notifyId`, `reminderId` in the want parameters); `EntryAbility.handleNotifyTap` acts, then routes through
  `RouteRequest` / `TabRequest` (works on cold start). Background actions are not possible for a third-party app
  (no static common-event subscribers in the public SDK).
- Watch SOS: watch countdown → `sos` row → `WatchCloudSource.toAlert` sets `watchSos` → `Index.onAlert` →
  `SosController.watchSent` (no phone countdown, starts the 10-min cooldown) → SOS page in sent state. A phone
  countdown still running for the same event turns into the watch-sent state.
- Contacts are not alerted by the server today (no synced contacts, no Twilio secrets: `sos` function runs dry).
  When B10 lands, replace the static "TO WHOM" text with the `sos_dispatches` status.

## For Workstream A (routes, functions, contracts)
- No new routes. The SOS page pushes `Routes.RESPONDER` (S2's page).
- `notify(id, title, text, ongoing, reminderId?)` keeps its old signature; the id picks the kind
  (`common/NotifyAction.kindForId`). New ids: `NOTIFY_WATCH_SOS` 1004, doses `2000 + reminderId % 1000`.
- `SosParam` has a fourth argument `sentBy` ('PHONE' default | 'WATCH').

## Found, not mine to fix
- Emergency tab row "Start SOS countdown — Alerts your contacts if you don't answer" and the countdown text "…call the
  ambulance and alert your contacts" overstate what happens (nothing is sent automatically). Strings in `string.json`
  / `EmergencyPage.ets` (S2). Suggest "Opens the call and message buttons if you don't answer."
