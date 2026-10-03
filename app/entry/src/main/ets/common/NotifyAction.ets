// What a notification is and what its buttons do (B7). Pure — unit tested. Publishing lives in common/Notify.ets,
// acting on a tap in entryability/EntryAbility.ets.
//
// Every button opens the app (WantAgent START_ABILITY) with `notifyAction` in the want parameters. A third-party app
// cannot act in the background from a button: the only other option, SEND_COMMON_EVENT, reaches a subscriber only
// while the app is alive, so a "Taken" tap on a closed app would be lost silently. Details and sources:
// docs/workflow/b-notify-sos.md.

export type NotifyKind = 'EMERGENCY' | 'HEART_ALERT' | 'DOSE_DUE' | 'RISKY_CHECK';
export type NotifyActionId = 'OPEN' | 'SOS_OK' | 'ALERT_OK' | 'DOSE_TAKEN';
// Slot names of notificationManager.SlotType (kept as names so this file needs no kit import).
export type SlotName = 'SOCIAL_COMMUNICATION' | 'SERVICE_INFORMATION' | 'CONTENT_INFORMATION';

export const NOTIFY_SOS: number = 1001;         // SOS countdown (ongoing)
export const NOTIFY_ALERT: number = 1002;       // heart alert
export const NOTIFY_RISKY_CHECK: number = 1003; // risky medicine check
export const NOTIFY_WATCH_SOS: number = 1004;   // the watch sent an SOS
export const NOTIFY_DOSE_BASE: number = 2000;   // 2000-2999: one per dose reminder

export const KEY_ACTION: string = 'notifyAction';
export const KEY_KIND: string = 'notifyKind';
export const KEY_ID: string = 'notifyId';
export const KEY_REMINDER: string = 'reminderId';

export class NotifyButton {
  action: NotifyActionId;
  label: string;   // resource name in string_notify.json

  constructor(action: NotifyActionId, label: string) {
    this.action = action;
    this.label = label;
  }
}

export class NotifyTap {
  action: NotifyActionId;
  kind: NotifyKind;
  notifyId: number;
  reminderId: number;   // DoseReminder.id, -1 when not a dose

  constructor(action: NotifyActionId, kind: NotifyKind, notifyId: number, reminderId: number) {
    this.action = action;
    this.kind = kind;
    this.notifyId = notifyId;
    this.reminderId = reminderId;
  }
}

export function doseNotifyId(reminderId: number): number {
  return NOTIFY_DOSE_BASE + (reminderId % 1000);
}

export function kindForId(id: number): NotifyKind {
  if (id === NOTIFY_SOS || id === NOTIFY_WATCH_SOS) {
    return 'EMERGENCY';
  }
  if (id === NOTIFY_ALERT) {
    return 'HEART_ALERT';
  }
  if (id >= NOTIFY_DOSE_BASE && id < NOTIFY_DOSE_BASE + 1000) {
    return 'DOSE_DUE';
  }
  return 'RISKY_CHECK';
}

// Emergencies get their own loud slot so a user who mutes reminders still hears an SOS.
export function slotFor(kind: NotifyKind): SlotName {
  if (kind === 'EMERGENCY') {
    return 'SOCIAL_COMMUNICATION';
  }
  if (kind === 'RISKY_CHECK') {
    return 'CONTENT_INFORMATION';   // quiet: the verdict was just shown in the app
  }
  return 'SERVICE_INFORMATION';
}

// At most two buttons (the system default limit).
export function buttonsFor(id: number): NotifyButton[] {
  if (id === NOTIFY_SOS) {
    return [new NotifyButton('SOS_OK', 'ntf_btn_im_ok'), new NotifyButton('OPEN', 'ntf_btn_open')];
  }
  const kind: NotifyKind = kindForId(id);
  if (kind === 'HEART_ALERT') {
    return [new NotifyButton('ALERT_OK', 'ntf_btn_im_ok'), new NotifyButton('OPEN', 'ntf_btn_open')];
  }
  if (kind === 'DOSE_DUE') {
    return [new NotifyButton('DOSE_TAKEN', 'ntf_btn_taken'), new NotifyButton('OPEN', 'ntf_btn_open')];
  }
  return [];
}

// Distinct per notification and action, so one WantAgent never overwrites another's parameters.
export function requestCodeFor(id: number, action: NotifyActionId): number {
  const index: number = action === 'OPEN' ? 0 : action === 'SOS_OK' ? 1 : action === 'ALERT_OK' ? 2 : 3;
  return id * 10 + index;
}

const ACTIONS: string[] = ['OPEN', 'SOS_OK', 'ALERT_OK', 'DOSE_TAKEN'];
const KINDS: string[] = ['EMERGENCY', 'HEART_ALERT', 'DOSE_DUE', 'RISKY_CHECK'];

// Want parameters → the tap, or undefined when the want did not come from one of our notifications.
export function parseNotifyTap(params: Record<string, Object> | undefined): NotifyTap | undefined {
  if (params === undefined) {
    return undefined;
  }
  const action: Object | undefined = params[KEY_ACTION];
  const kind: Object | undefined = params[KEY_KIND];
  if (typeof action !== 'string' || !ACTIONS.includes(action) || typeof kind !== 'string' || !KINDS.includes(kind)) {
    return undefined;
  }
  const id: Object | undefined = params[KEY_ID];
  const reminder: Object | undefined = params[KEY_REMINDER];
  return new NotifyTap(action as NotifyActionId, kind as NotifyKind, typeof id === 'number' ? id : -1,
    typeof reminder === 'number' ? reminder : -1);
}

// Where a tap lands. 'sos' = whatever SOS page is open (no page is pushed), 'heart' = Heart tab.
export type NotifyTarget = 'sos' | 'heart' | 'reminders' | 'history';

export function targetFor(tap: NotifyTap): NotifyTarget {
  if (tap.kind === 'EMERGENCY') {
    return 'sos';
  }
  if (tap.kind === 'HEART_ALERT') {
    return 'heart';
  }
  if (tap.kind === 'DOSE_DUE') {
    return 'reminders';
  }
  return 'history';
}

// A tap on the server-sent "SOS from your watch" push (B12, backend/supabase/functions/sos/huaweiPush.ts). Push Kit
// hands `clickAction.data` to the app as want parameters: route 'sos', source 'watch', loc '1' | '0', at (ISO time).
export class PushSosTap {
  at: number;
  withLocation: boolean;

  constructor(at: number, withLocation: boolean) {
    this.at = at;
    this.withLocation = withLocation;
  }
}

export function parsePushTap(params: Record<string, Object> | undefined, now: number): PushSosTap | undefined {
  if (params === undefined || params['route'] !== 'sos' || params['source'] !== 'watch') {
    return undefined;
  }
  const at: Object | undefined = params['at'];
  const ts: number = typeof at === 'string' ? Date.parse(at) : NaN;
  // A missing or future time is replaced by "now"; never trust it to move the cooldown forward.
  return new PushSosTap(Number.isNaN(ts) || ts > now ? now : ts, params['loc'] === '1');
}

// Upload the push token only when signed in and not already uploaded for this user and token.
export function pushUploadKey(userId: string, token: string): string {
  return userId === '' || token === '' ? '' : `${userId}:${token}`;
}

export function needsPushUpload(signedIn: boolean, userId: string, token: string, uploaded: string): boolean {
  const key: string = pushUploadKey(userId, token);
  return signedIn && key !== '' && key !== uploaded;
}
