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

---

# Phase 2: B13 Live View + lock screen, B12 Push Kit (built from `docs/research/live-view.md` and `push-kit.md` on `georgi/b-research`)

## AI_WORKFLOW entry
### 2026-10-04 — Georgi + Claude Code: Live View, lock-screen medical ID and Push Kit (branch `georgi/b-notify-sos`)
- Asked: implement what S7's research says is possible without approvals; list the rest as blocked.
- Produced:
  - `emergency/LiveStatus.ets` + pure `emergency/SosLiveText.ets`: one `startLiveView` with a countdown `timer`
    the system ticks, a timer capsule (emergency colour from the `danger` resource), `clickAction` (the SOS tap
    WantAgent), a pickup layout with a picture (`rawfile/sos_live.png`, generated in this repo), `countdownPreset`
    text at zero, and an end card that says how the SOS ended. No per-second updates. The notification fallback
    stays and logs the kit's error code.
  - Lock-screen medical ID: `widget/pages/MedIdCard.ets` + pure `widget/MedIdData.ets`, a third form with
    `renderingMode: "autoColor"` (home screen and lock screen). Condition, AVOID line, ICD, medicines,
    allergies, blood type; respects `hiddenOnCard`; never contacts, phone numbers or notes. Same snapshot as the
    alert card, no network.
  - Push Kit client: `account/PushToken.ets` (token on each launch, stored on the phone, upserted to
    `push_tokens` once per user and token when signed in; `forget()` for sign-out), push tap →
    `EntryAbility.handlePushTap` → SOS page in the watch-sent state (also cold start). `module.json5` home skill
    also lists `ohos.want.action.home`.
  - Push Kit server: `sos/huaweiPush.ts` (service-account JWT PS256 with `jose`, test messages, fixed copy, no
    location), wired into `sos/index.ts` before the contacts step; result in `sos_dispatches.detail.push`, never
    changes the SOS status. Migration `20261004110000_push_tokens.sql` (owner-only RLS, nothing for anon).
- Validated:
  - Phone 239/239 (12 new), backend 72/72 (4 new: config parsing, JWT header/claims verified with a throwaway key,
    push message shape). `deno check` of `sos/index.ts` passes.
  - Emulator: **Live View runs on the emulator** (no AGC approval needed there): capsule/timer in the panel and on
    the lock screen counting down (`notify-sos-15/16`), end cards "SOS cancelled. Glad you are OK" and "Open Celia
    to call the ambulance and your contacts" (`17/18`). The emulator showed the kit validates the payload before the
    permission: the research's progress layout was rejected without `nodeIcons`, pickup without `descPic` (401);
    fixed. Push token on the emulator: `1000900010 Illegal application identity` (no AGC project), logged and
    ignored. Push tap (want with the push's `clickAction.data`) opens "Your watch sent an SOS" (`19`). Medical ID
    card in the widget picker and on the home screen with real data (`20/21`).
- Not validated: Live View on a real phone (needs an approved `TIMER` scenario and, per Huawei, a Chinese-mainland
  device); the medical ID **on the lock screen** (the emulator has no lock-screen editing; home-screen only);
  receiving a real push (no AGC project, no Chinese-mainland phone); the push send itself (no service-account key);
  token upload (S1's accounts and per-user JWT in `Net.ets` not merged yet).

## README "How to verify" rows
| SOS Live View (B13) | Start an SOS countdown, pull down the panel / lock the screen: a live card "SOS in 00:25" ticking, red capsule. "I'm OK" → card "SOS cancelled". Works on the emulator; on a real phone needs Live View approval (built, unverified there). |
| Lock-screen medical ID (B13) | Long-press the app icon → Widgets → "Medical ID (lock screen)". Shows condition, AVOID line, ICD, medicines; hidden card fields stay off; no contacts. Lock-screen placement: real phone only (built, unverified). |
| Push: watch SOS to the phone (B12) | Built, unverified: needs an AGC project with Push Kit, the service-account key in Supabase secrets, B9's watch↔account binding and a Chinese-mainland phone. Emulator check of the tap: `hdc shell aa start -a EntryAbility -b com.celiaai.app --ps route sos --ps source watch --ps loc 1` → "Your watch sent an SOS". `hilog | grep PushToken` shows why no token. |

## ARCHITECTURE notes
- Live View: one start, system timer, no update loop; `isLiveViewEnabled()` false or an error → ongoing
  notification every 5 s (B7 buttons). The payload is validated before the permission, so a wrong payload looks like
  "not available"; LiveStatus logs `code message`.
- Push: watch `sos` row → `sos` function → `watch_pairings.user_id` (B9) → `push_tokens` → Huawei Push
  (`push-api.cloud.huawei.com/v3/<project>/messages:send`, JWT) → notification id 1004 → tap → `parsePushTap` →
  `SosController.watchSent` → SOS page. Without the binding the function records `push.status:
  no_account_binding` and pushes nothing: it never guesses a recipient.
- Third-party: `npm:jose@5` (JWT signing in the `sos` function, and in its test). List in README + AI_WORKFLOW
  (Challenge Rules §4). `rawfile/sos_live.png` is generated by a script in this session (no third-party asset).

## Blocked, with the reason
| Item | Blocked by |
|---|---|
| Live View on a real phone | AGC Live View `TIMER` scenario approval (5 working days, scenario meant for tool apps) and, per Huawei, a Chinese-mainland device |
| Receiving pushes on a phone | Push Kit for phones is Chinese-mainland only; AGC project + Push Kit + signing profile |
| Sending pushes | Service-account key → secrets `HUAWEI_PUSH_PROJECT_ID`, `HUAWEI_PUSH_SA_KEY` |
| Knowing whose phone a watch belongs to | B9 (S1): `watch_pairings.user_id` |
| Token upload | S1: Session + per-user JWT in `common/Net.ets` (RLS on `push_tokens` needs `auth.uid()`) |
| Medical ID on the lock screen in the emulator | No lock-screen editing on the emulator |

## For the coordinator / other streams
- Coordinator (after Georgi's OK): apply `20261004110000_push_tokens.sql`; redeploy `sos` (`--no-verify-jwt`
  unchanged); later set `HUAWEI_PUSH_PROJECT_ID` / `HUAWEI_PUSH_SA_KEY`.
- S1: call `PushToken.forget()` before `Session.signOut()` (the row is deleted with the user's token); B9 should add
  `watch_pairings.user_id` — `sos/index.ts` `pushToPatient` already reads it.
- S2: the lock-screen card reuses `hiddenOnCard` and the widget snapshot (`WidgetData` got four `mid*` keys).
