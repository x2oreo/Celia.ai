// What the agent has to say right now (DESIGN.md §10.1a): one sentence and whether the tab-bar orb shows its dot.
// Built from the user's own records only (reminders, dose log, medicines), never from the model. Today, the agent
// stage and the tab bar all read the same brief, so they always agree.

import { LocalStore, StoreTopic } from '../../data/LocalStore';
import { Medication } from '../../model/Medication';
import { Profile } from '../../model/Profile';
import { ComboVerdict } from '../../model/DrugVerdict';
import { medsInteractions, riskCounts, RiskCounts } from '../../drugs/MedsReview';
import { ReminderService } from '../../reminders/ReminderService';
import { DoseLog, DoseReminder } from '../../reminders/DoseSchedule';
import { Listener, Listeners } from '../../common/Listeners';
import { agentLine, dayGreeting, DoseFocus, doseFocus, doseNeedsWord } from './AgentLogic';

const REFRESH_MS: number = 30000;

export class Brief {
  line: string = '';
  nudge: boolean = false;                    // the agent has something to say about a dose
  focus: DoseFocus | undefined = undefined;  // the dose Today shows
  reminders: DoseReminder[] = [];
  logs: DoseLog[] = [];
  meds: Medication[] = [];
  profile: Profile | undefined = undefined;
  counts: RiskCounts = new RiskCounts();
  interactions: ComboVerdict[] = [];
}

export class HomeBrief {
  private static current: Brief = new Brief();
  private static listeners: Listeners<Brief> = new Listeners<Brief>();
  private static started: boolean = false;
  private static seq: number = 0;

  static latest(): Brief {
    return HomeBrief.current;
  }

  // Subscribes and makes sure the brief is kept fresh: on every store change and twice a minute (a dose becomes
  // due by the clock, not by a store change).
  static onChange(cb: Listener<Brief>): () => void {
    if (!HomeBrief.started) {
      HomeBrief.started = true;
      LocalStore.get().onChange((t: StoreTopic) => {
        HomeBrief.refresh();
      });
      setInterval((): void => {
        HomeBrief.refresh();
      }, REFRESH_MS);
    }
    HomeBrief.refresh();
    return HomeBrief.listeners.add(cb);
  }

  static async refresh(): Promise<void> {
    const seq: number = ++HomeBrief.seq;
    const now: number = Date.now();
    const b: Brief = new Brief();
    b.profile = await LocalStore.get().getProfile();
    b.meds = await LocalStore.get().listMeds();
    b.reminders = await ReminderService.list();
    b.logs = await ReminderService.doseLog();
    if (seq !== HomeBrief.seq) {
      return;   // a newer refresh is on its way
    }
    b.counts = riskCounts(b.meds);
    b.interactions = medsInteractions(b.meds);
    b.focus = doseFocus(b.reminders, b.logs, now);
    b.nudge = doseNeedsWord(b.focus, now);
    const name: string = b.profile?.name ?? '';
    b.line = agentLine(dayGreeting(new Date(now).getHours(), name.length > 0 ? name.split(' ')[0] : ''), b.focus, now,
      b.interactions.length, b.counts.known);
    HomeBrief.current = b;
    HomeBrief.listeners.emit(b);
  }
}
