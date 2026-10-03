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
