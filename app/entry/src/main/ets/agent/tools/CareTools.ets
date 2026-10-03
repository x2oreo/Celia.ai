// prepare_doctor_visit, get_dose_status, get_trends — features that used to be several taps away, one sentence away.
// Both are read-only and deterministic: the content comes from doctor/DoctorPrep.ets and reminders/DoseSchedule.ets.

import { AgentTool, TurnState, action, toolError } from '../ToolTypes';
import { argString } from '../ResponseValidator';
import { OpenPagePayload } from '../../model/AgentTypes';
import { LocalStore } from '../../data/LocalStore';
import {
  flaggedChecks, questions, Specialty, SPECIALTIES, specialtyName, watchOuts
} from '../../doctor/DoctorPrep';
import { ReminderService } from '../../reminders/ReminderService';
import { DoseLog, DoseReminder, doseStatus, timeLabel } from '../../reminders/DoseSchedule';
import { WatchInsight } from '../../model/WatchData';
import { loadTrends, TrendData, TrendStats, trendStats } from '../../vitals/Trends';

const FLAGGED_WINDOW_MS: number = 90 * 24 * 60 * 60 * 1000;

interface VisitOutput {
  specialty: string;
  watchOuts: string[];
  questionsToAsk: string[];
  note: string;
}

export class PrepareDoctorVisitTool implements AgentTool {
  name: string = 'prepare_doctor_visit';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const raw: string = argString(args, 'specialty', 24);
    const s: Specialty | undefined = SPECIALTIES.find((x: Specialty) => x === raw);
    if (s === undefined) {
      return toolError(`specialty must be one of ${SPECIALTIES.join(', ')}`);
    }
    const now: number = Date.now();
    const flagged: boolean = flaggedChecks(await LocalStore.get().listScans(), now - FLAGGED_WINDOW_MS).length > 0;
    const payload: OpenPagePayload = { page: 'DOCTOR_PREP', specialty: s };
    turn.actions.push(action('OPEN_PAGE', payload));
    const out: VisitOutput = {
      specialty: specialtyName(s),
      watchOuts: watchOuts(s),
      questionsToAsk: questions(s, flagged),
      note: 'These points are the app\'s fixed list for this kind of visit; quote them, do not add medical advice ' +
        'of your own. A button that opens the full brief (medicines, flagged checks, heart events) is on screen.'
    };
    return JSON.stringify(out);
  }
}

interface DoseLine {
  medicine: string;
  time: string;
  status: string;   // TAKEN | SKIPPED | DUE | UPCOMING | MISSED
}

interface DoseOutput {
  doses: DoseLine[];
  note: string;
}

export class GetDoseStatusTool implements AgentTool {
  name: string = 'get_dose_status';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const reminders: DoseReminder[] = await ReminderService.list();
    const logs: DoseLog[] = await ReminderService.doseLog();
    const now: number = Date.now();
    const doses: DoseLine[] = reminders.map((r: DoseReminder) => {
      const line: DoseLine = { medicine: r.medName, time: timeLabel(r), status: doseStatus(r, logs, now) };
      return line;
    });
    const payload: OpenPagePayload = { page: 'REMINDERS', specialty: '' };
    turn.actions.push(action('OPEN_PAGE', payload));
    const out: DoseOutput = {
      doses: doses,
      note: doses.length === 0
        ? 'No reminders are set. A button to open reminders is on screen.'
        : 'Today\'s doses from the reminder log on this phone. Do not advise on a missed dose beyond "follow your ' +
          'doctor\'s instructions". Nothing was changed; the user marks doses on the reminders screen.'
    };
    return JSON.stringify(out);
  }
}

interface TrendsOutput {
  days: number;
  source: string;            // WATCH | DEMO (simulated) | OFFLINE
  averageRestingBpm: number;
  changeLast7DaysBpm: number | null;   // last 7 days minus the days before; null = not enough days
  daysWithDoseLogged: number;
  daysWithSymptom: number;
  findings: string[];        // fixed-rule texts; quote as is
  note: string;
}

const TREND_SPANS: number[] = [14, 30];

export class GetTrendsTool implements AgentTool {
  name: string = 'get_trends';

  async execute(args: Record<string, Object>, turn: TurnState): Promise<string> {
    const asked: Object | undefined = args['days'];
    const span: number = typeof asked === 'number' && TREND_SPANS.includes(asked) ? asked : 14;
    const data: TrendData = await loadTrends(Date.now(), span);
    const s: TrendStats = trendStats(data.days);
    const payload: OpenPagePayload = { page: 'TRENDS', specialty: '' };
    turn.actions.push(action('OPEN_PAGE', payload));
    const out: TrendsOutput = {
      days: span,
      source: data.source,
      averageRestingBpm: s.avgResting,
      changeLast7DaysBpm: s.hasChange ? s.change : null,
      daysWithDoseLogged: s.doseDays,
      daysWithSymptom: s.symptomDays,
      findings: data.insights.map((i: WatchInsight) => i.message),
      note: (data.simulated ? 'This is SIMULATED demo data: say so. ' : '') +
        'Wrist resting heart rate only, not an ECG. Report the numbers; do not interpret them medically or say ' +
        'they are good or bad. A button to open the trends chart is on screen.'
    };
    return JSON.stringify(out);
  }
}
