// Local notifications (NotificationKit). One slot per kind and action buttons where they help (B7); what each kind
// and button means is in common/NotifyAction.ets. Every tap opens the app, which acts on it (EntryAbility). Never
// throws.

import { notificationManager } from '@kit.NotificationKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from './Logger';
import {
  buttonsFor, KEY_ACTION, KEY_ID, KEY_KIND, KEY_REMINDER, kindForId, NotifyActionId, NotifyButton, NotifyKind,
  requestCodeFor, SlotName, slotFor
} from './NotifyAction';

export { NOTIFY_ALERT, NOTIFY_RISKY_CHECK, NOTIFY_SOS, NOTIFY_WATCH_SOS, doseNotifyId } from './NotifyAction';

const log: Logger = new Logger('Notify');
const BUNDLE: string = 'com.celiaai.app';

// English fallbacks for the button labels when resources cannot be read (string_notify.json is the source).
const FALLBACK: Map<string, string> = new Map<string, string>([
  ['ntf_btn_im_ok', 'I\'m OK'], ['ntf_btn_open', 'Open'], ['ntf_btn_taken', 'Taken']
]);

let appCtx: common.Context | undefined = undefined;
const agents: Map<number, WantAgent> = new Map<number, WantAgent>();

// Called once from EntryAbility.onCreate so labels come from resources.
export function initNotify(ctx: common.Context): void {
  appCtx = ctx;
}

export function notifyText(name: string): string {
  try {
    if (appCtx !== undefined) {
      return appCtx.resourceManager.getStringByNameSync(name);
    }
  } catch (e) {
    log.warn(`string ${name}: ${JSON.stringify(e)}`);
  }
  return FALLBACK.get(name) ?? name;
}

// A colour resource as an ARGB number (Live View wants colours as strings); -1 when unavailable.
export function notifyColor(name: string): number {
  try {
    if (appCtx !== undefined) {
      return appCtx.resourceManager.getColorByNameSync(name);
    }
  } catch (e) {
    log.warn(`colour ${name}: ${JSON.stringify(e)}`);
  }
  return -1;
}

// The "open the app" WantAgent of a notification id, for surfaces that share its tap (the SOS Live View).
export async function tapAgent(id: number): Promise<WantAgent | undefined> {
  return agentFor(id, kindForId(id), 'OPEN', -1);
}

function slotType(name: SlotName): notificationManager.SlotType {
  if (name === 'SOCIAL_COMMUNICATION') {
    return notificationManager.SlotType.SOCIAL_COMMUNICATION;
  }
  if (name === 'SERVICE_INFORMATION') {
    return notificationManager.SlotType.SERVICE_INFORMATION;
  }
  return notificationManager.SlotType.CONTENT_INFORMATION;
}

async function agentFor(id: number, kind: NotifyKind, action: NotifyActionId, reminderId: number):
  Promise<WantAgent | undefined> {
  const code: number = requestCodeFor(id, action);
  const cached: WantAgent | undefined = agents.get(code);
  if (cached !== undefined) {
    return cached;
  }
  try {
    const params: Record<string, Object> = {};
    params[KEY_ACTION] = action;
    params[KEY_KIND] = kind;
    params[KEY_ID] = id;
    params[KEY_REMINDER] = reminderId;
    const info: wantAgent.WantAgentInfo = {
      wants: [{ bundleName: BUNDLE, abilityName: 'EntryAbility', parameters: params }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: code,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    const agent: WantAgent = await wantAgent.getWantAgent(info);
    agents.set(code, agent);
    return agent;
  } catch (e) {
    log.warn(`wantAgent failed: ${JSON.stringify(e)}`);
    return undefined;
  }
}

// Ask once (system dialog) so alerts can reach the lock screen.
export async function askNotificationPermission(ctx: common.UIAbilityContext): Promise<void> {
  try {
    if (!(await notificationManager.isNotificationEnabled())) {
      await notificationManager.requestEnableNotification(ctx);
    }
  } catch (e) {
    log.warn(`notification permission: ${JSON.stringify(e)}`);
  }
}

// The kind (slot, buttons) follows from the id; reminderId is set for dose notifications only.
export async function notify(id: number, title: string, text: string, ongoing: boolean,
  reminderId: number = -1): Promise<void> {
  try {
    const kind: NotifyKind = kindForId(id);
    const tap: WantAgent | undefined = await agentFor(id, kind, 'OPEN', reminderId);
    const buttons: notificationManager.NotificationActionButton[] = [];
    for (const b of buttonsFor(id)) {
      const button: NotifyButton = b;
      const agent: WantAgent | undefined = await agentFor(id, kind, button.action, reminderId);
      if (agent !== undefined) {
        buttons.push({ title: notifyText(button.label), wantAgent: agent });
      }
    }
    const request: notificationManager.NotificationRequest = {
      id: id,
      notificationSlotType: slotType(slotFor(kind)),
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: { title: title, text: text.length > 0 ? text : title }   // empty text is rejected (401)
      },
      isOngoing: ongoing,
      tapDismissed: !ongoing,
      // The countdown is refreshed every few seconds; sound and banner only the first time.
      isAlertOnce: ongoing,
      wantAgent: tap,
      actionButtons: buttons
    };
    await notificationManager.publish(request);
  } catch (e) {
    const err: BusinessError = e as BusinessError;
    log.warn(`publish ${id} failed: ${err.code} ${err.message}`);
  }
}

export async function cancelNotify(id: number): Promise<void> {
  try {
    await notificationManager.cancel(id);
  } catch (e) {
    log.warn(`cancel failed: ${JSON.stringify(e)}`);
  }
}
