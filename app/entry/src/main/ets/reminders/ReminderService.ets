// Medication reminders (F-38) via the system reminder agent — they fire even when the app is closed.
// Schedule and dose log live on-device (LocalStore settings).

import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { LocalStore } from '../data/LocalStore';
import { DoseLog, DoseReminder, dayKey, doseStatus } from './DoseSchedule';
import { notify } from '../common/Notify';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('Reminders');
const KEY_REMINDERS: string = 'reminders';
const KEY_DOSES: string = 'doseLog';
const BUNDLE: string = 'com.celiaai.app';

export class ReminderService {
  static async list(): Promise<DoseReminder[]> {
    return JSON.parse(await LocalStore.get().getSetting(KEY_REMINDERS, '[]')) as DoseReminder[];
  }

  static async doseLog(): Promise<DoseLog[]> {
    return JSON.parse(await LocalStore.get().getSetting(KEY_DOSES, '[]')) as DoseLog[];
  }

  static async add(medId: number, medName: string, hour: number, minute: number): Promise<DoseReminder> {
    const all: DoseReminder[] = await ReminderService.list();
    const r: DoseReminder = {
      id: Date.now(), medId: medId, medName: medName, hour: hour, minute: minute, reminderId: -1
    };
    r.reminderId = await ReminderService.publish(r);
    all.push(r);
    await LocalStore.get().setSetting(KEY_REMINDERS, JSON.stringify(all));
    return r;
  }

  static async remove(id: number): Promise<void> {
    const all: DoseReminder[] = await ReminderService.list();
    const r: DoseReminder | undefined = all.find((x: DoseReminder) => x.id === id);
    if (r !== undefined && r.reminderId >= 0) {
      try {
        await reminderAgentManager.cancelReminder(r.reminderId);
      } catch (e) {
        log.warn(`cancel failed: ${JSON.stringify(e)}`);
      }
    }
    await LocalStore.get().setSetting(KEY_REMINDERS, JSON.stringify(all.filter((x: DoseReminder) => x.id !== id)));
  }

  static async mark(r: DoseReminder, status: string): Promise<void> {
    const logs: DoseLog[] = await ReminderService.doseLog();
    const today: string = dayKey(Date.now());
    const kept: DoseLog[] = logs.filter((l: DoseLog) => !(l.reminderId === r.id && l.day === today)).slice(-500);
    kept.push({ reminderId: r.id, day: today, status: status, ts: Date.now() });
    await LocalStore.get().setSetting(KEY_DOSES, JSON.stringify(kept));
    const detail: DoseEventDetail = { med: r.medName, status: status };
    await LocalStore.get().logEvent('DOSE', JSON.stringify(detail));
  }

  // Fallback while the app runs (system reminders need an AppGallery Connect quota; without it the system
  // refuses them with 1700002): post a local notification once when a dose becomes due.
  private static notified: string[] = [];

  static async checkDue(now: number): Promise<void> {
    const all: DoseReminder[] = await ReminderService.list();
    if (all.length === 0) {
      return;
    }
    const logs: DoseLog[] = await ReminderService.doseLog();
    for (const r of all) {
      const key: string = `${r.id}-${dayKey(now)}`;
      if (doseStatus(r, logs, now) === 'DUE' && !ReminderService.notified.includes(key)) {
        ReminderService.notified.push(key);
        notify(2000 + (r.id % 1000), `Time for ${r.medName}`, 'Open Celia.ai to mark it as taken.', false);
      }
    }
  }

  // On launch: re-publish any reminder the system lost (reinstall, cleared reminders).
  static async handleLaunch(): Promise<void> {
    try {
      const all: DoseReminder[] = await ReminderService.list();
      if (all.length === 0) {
        return;
      }
      const valid: reminderAgentManager.ReminderRequest[] = await reminderAgentManager.getValidReminders();
      if (valid.length >= all.length) {
        return;
      }
      for (const r of all) {
        r.reminderId = await ReminderService.publish(r);
      }
      await LocalStore.get().setSetting(KEY_REMINDERS, JSON.stringify(all));
    } catch (e) {
      log.warn(`resync failed: ${JSON.stringify(e)}`);
    }
  }

  private static async publish(r: DoseReminder): Promise<number> {
    try {
      const req: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        hour: r.hour,
        minute: r.minute,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        title: `Time for ${r.medName}`,
        content: 'Open Celia.ai to mark it as taken.',
        actionButton: [
          { title: 'OK', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE },
          { title: 'Snooze 10 min', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_SNOOZE }
        ],
        wantAgent: { pkgName: BUNDLE, abilityName: 'EntryAbility' },
        snoozeTimes: 2,
        timeInterval: 600,
        ringDuration: 5
      };
      const valid: reminderAgentManager.ReminderRequest[] = await reminderAgentManager.getValidReminders();
      log.info(`valid reminders before publish: ${valid.length}`);
      try {
        const id: number = await reminderAgentManager.publishReminder(req);
        log.info(`published reminder ${id} for ${r.medName} at ${r.hour}:${r.minute}`);
        return id;
      } catch (first) {
        // Some system images reject repeating alarms with buttons; retry with the minimal request.
        log.warn(`full reminder rejected (${JSON.stringify(first)}), retrying minimal`);
        const minimal: reminderAgentManager.ReminderRequestAlarm = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
          hour: r.hour,
          minute: r.minute,
          title: `Time for ${r.medName}`,
          content: 'Open Celia.ai to mark it as taken.'
        };
        const id: number = await reminderAgentManager.publishReminder(minimal);
        log.info(`published minimal reminder ${id}`);
        return id;
      }
    } catch (e) {
      log.error(`publishReminder failed: ${JSON.stringify(e)}`);
      return -1;
    }
  }
}

interface DoseEventDetail {
  med: string;
  status: string;
}
