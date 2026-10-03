// Local notifications (NotificationKit). Tapping one opens the app. Never throws.

import { notificationManager } from '@kit.NotificationKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import { Logger } from './Logger';

const log: Logger = new Logger('Notify');
const BUNDLE: string = 'com.celiaai.app';

export const NOTIFY_SOS: number = 1001;
export const NOTIFY_ALERT: number = 1002;
export const NOTIFY_RISKY_CHECK: number = 1003;

let openApp: WantAgent | undefined = undefined;

async function openAppAgent(): Promise<WantAgent | undefined> {
  if (openApp !== undefined) {
    return openApp;
  }
  try {
    const info: wantAgent.WantAgentInfo = {
      wants: [{ bundleName: BUNDLE, abilityName: 'EntryAbility' }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    openApp = await wantAgent.getWantAgent(info);
  } catch (e) {
    log.warn(`wantAgent failed: ${JSON.stringify(e)}`);
  }
  return openApp;
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

export async function notify(id: number, title: string, text: string, ongoing: boolean): Promise<void> {
  try {
    const agent: WantAgent | undefined = await openAppAgent();
    const request: notificationManager.NotificationRequest = {
      id: id,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: { title: title, text: text }
      },
      isOngoing: ongoing,
      tapDismissed: !ongoing,
      wantAgent: agent
    };
    await notificationManager.publish(request);
  } catch (e) {
    log.warn(`publish failed: ${JSON.stringify(e)}`);
  }
}

export async function cancelNotify(id: number): Promise<void> {
  try {
    await notificationManager.cancel(id);
  } catch (e) {
    log.warn(`cancel failed: ${JSON.stringify(e)}`);
  }
}
