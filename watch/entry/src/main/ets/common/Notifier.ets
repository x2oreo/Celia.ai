import { notificationManager } from '@kit.NotificationKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from './Logger';

const BUNDLE = 'ai.celia.watch';
const ABILITY = 'EntryAbility';
/** Alert notifications reuse a few ids so the list shows the latest per kind instead of piling up. */
export const NOTIFY_HR = 1;
export const NOTIFY_VITALS = 2;
export const NOTIFY_FALL = 3;
export const NOTIFY_SOS = 4;

/**
 * Watch notifications (Notification Kit) for alerts, and system reminders (reminderAgentManager) for medication.
 * Reminders are fired by the system, so they work even while our app is frozen or closed.
 */
export class Notifier {
  private enabled: boolean = false;
  private openApp: WantAgent | undefined = undefined;

  /** Asks the user to allow notifications (once) and prepares "tap opens the app". */
  async init(ctx: common.UIAbilityContext): Promise<void> {
    try {
      this.enabled = await notificationManager.isNotificationEnabled();
      if (!this.enabled) {
        await notificationManager.requestEnableNotification(ctx);
        this.enabled = await notificationManager.isNotificationEnabled();
      }
    } catch (e) {
      Logger.warn(`notifications not enabled: ${(e as BusinessError).code}`);
    }
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: BUNDLE, abilityName: ABILITY }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      this.openApp = await wantAgent.getWantAgent(info);
    } catch (e) {
      Logger.warn(`want agent unavailable: ${(e as BusinessError).code}`);
    }
  }

  /** Posts (or replaces) an alert notification. Never throws: a missing notification must not break monitoring. */
  alert(id: number, title: string, text: string): void {
    if (!this.enabled) {
      return;
    }
    const request: notificationManager.NotificationRequest = {
      id: id,
      notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: { title: title, text: text }
      },
      wantAgent: this.openApp
    };
    notificationManager.publish(request).catch((err: BusinessError) => {
      Logger.warn(`notification failed: ${err.code}`);
    });
  }

  /** Daily medication reminder at HH:MM, replacing any previous one. Empty time = no reminder. */
  async scheduleDailyMedication(time: string, medication: string): Promise<void> {
    const m = new RegExp('^([01]?[0-9]|2[0-3]):([0-5][0-9])$').exec(time);
    try {
      await reminderAgentManager.cancelAllReminders();
      if (m === null) {
        return;
      }
      const alarm: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: Number(m[1]),
        minute: Number(m[2]),
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        title: `Time for ${medication}`,
        content: 'Take your beta-blocker. Missed doses raise the risk.',
        ringDuration: 5,
        snoozeTimes: 2,
        timeInterval: 10 * 60,
        actionButton: [
          { title: 'Done', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE },
          { title: 'Snooze', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_SNOOZE }
        ],
        wantAgent: { pkgName: BUNDLE, abilityName: ABILITY }
      };
      const id = await reminderAgentManager.publishReminder(alarm);
      Logger.info(`daily medication reminder ${time} scheduled (id ${id})`);
    } catch (e) {
      Logger.warn(`reminder failed: ${(e as BusinessError).code}`);
    }
  }

  /** Demo: a one-off medication reminder in `seconds`, fired by the system even if the app is closed. */
  async testReminder(seconds: number, medication: string): Promise<boolean> {
    try {
      const timer: reminderAgentManager.ReminderRequestTimer = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
        triggerTimeInSeconds: seconds,
        title: `Time for ${medication}`,
        content: 'Take your beta-blocker. Missed doses raise the risk.',
        actionButton: [
          { title: 'Done', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }
        ],
        wantAgent: { pkgName: BUNDLE, abilityName: ABILITY }
      };
      await reminderAgentManager.publishReminder(timer);
      return true;
    } catch (e) {
      Logger.warn(`test reminder failed: ${(e as BusinessError).code}`);
      return false;
    }
  }
}
