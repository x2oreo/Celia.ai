// Runs the missed beta-blocker check (RestingTrend) at launch and every few hours. Asks at most once per day.
// The finding becomes a WARN vitals alert (Heart tab, notification, event log) and a proactive agent message.

import { AgentCore } from '../agent/AgentCore';
import { AgentReply } from '../model/AgentTypes';
import { Medication } from '../model/Medication';
import { VitalsAlert } from '../model/Vitals';
import { LocalStore } from '../data/LocalStore';
import { Logger } from '../common/Logger';
import { DoseLog, DoseReminder, dayKey } from '../reminders/DoseSchedule';
import { ReminderService } from '../reminders/ReminderService';
import { BetaBlockerFinding, checkBetaBlocker, DailyResting } from './RestingTrend';
import { loadRestingHistory } from './RestingHistory';
import { VitalsService } from './VitalsService';

const log: Logger = new Logger('BetaBlockerWatch');
const CHECK_EVERY_MS: number = 6 * 3600 * 1000;
const KEY_LAST_ASKED: string = 'betaBlockerAskedDay';

export class BetaBlockerWatch {
  private static timer: number = -1;

  static start(): void {
    if (BetaBlockerWatch.timer >= 0) {
      return;
    }
    BetaBlockerWatch.check(Date.now());
    BetaBlockerWatch.timer = setInterval(() => {
      BetaBlockerWatch.check(Date.now());
    }, CHECK_EVERY_MS);
  }

  static async check(now: number): Promise<BetaBlockerFinding | undefined> {
    try {
      const today: string = dayKey(now);
      if ((await LocalStore.get().getSetting(KEY_LAST_ASKED, '')) === today) {
        return undefined;
      }
      const meds: Medication[] = await LocalStore.get().listMeds();
      const reminders: DoseReminder[] = await ReminderService.list();
      const logs: DoseLog[] = await ReminderService.doseLog();
      const history: DailyResting[] = await loadRestingHistory(now);
      const f: BetaBlockerFinding | undefined = checkBetaBlocker(history, meds, reminders, logs, now);
      if (f === undefined) {
        return undefined;
      }
      await LocalStore.get().setSetting(KEY_LAST_ASKED, today);
      const label: string = f.simulated ? ' (demo data)' : '';
      const alert: VitalsAlert = {
        ts: now,
        kind: 'RESTING_HR_RISE',
        hr: f.recent[0].bpm,
        message: `${f.message}${label}`,
        severity: 'WARN'
      };
      VitalsService.get().report(alert);
      const reply: AgentReply = { text: alert.message, actions: [], fallback: false };
      AgentCore.get().pushProactive(reply);
      log.info(`asked about ${f.med.name}: baseline ${f.baselineBpm}, evidence ${f.evidence}${label}`);
      return f;
    } catch (e) {
      log.warn(`check failed: ${JSON.stringify(e)}`);
      return undefined;
    }
  }
}
