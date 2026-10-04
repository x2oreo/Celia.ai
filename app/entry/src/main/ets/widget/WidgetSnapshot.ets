// The flat snapshot every home-screen card reads (DESIGN.md §11 widgets v2). Field names are the @LocalStorageProp
// keys in widget/pages/*. Kept apart from WidgetModel so the form extension loads only this and DoseSchedule.

import { DoseLog, DoseReminder } from '../reminders/DoseSchedule';
import { DoseCard, doseCard } from './WidgetDose';

export class WidgetSnapshot {
  // Medical alert (B6) and Medical ID (B13).
  condition: string = 'Long QT syndrome';
  facts: string = '';
  number: string = '112';
  ice: string = '';
  midName: string = '';
  midIcd: string = '';
  midMeds: string = '';
  midOther: string = '';
  // The agent: agentLine is what the card shows; agentRest is the app's clock-free line (interactions, known-risk
  // medicines, else calm) used whenever no dose needs a word.
  agentLine: string = '';
  agentRest: string = '';
  // Next dose (WidgetDose).
  doseState: string = 'NONE';
  doseName: string = '';
  doseWhen: string = '';
  doseTaken: number = 0;
  doseTotal: number = 0;
  doseDots: string = '';
  // Resting heart rate, last 7 days. hd0..hd6: height of each day's dot in % of the plot (oldest first), -1 = no
  // reading that day. hbLo / hbHi: the usual range in % of the plot.
  hrAvg: number = 0;
  hrChange: string = '';
  hrSource: string = '';      // 'WATCH' | 'SIMULATED' | '' when there is no data
  hrLevel: string = 'NONE';   // Metrics StatusLevel of the latest day
  hrLast: string = '';        // "72 bpm · 4 Oct 14:05"
  hd0: number = -1;
  hd1: number = -1;
  hd2: number = -1;
  hd3: number = -1;
  hd4: number = -1;
  hd5: number = -1;
  hd6: number = -1;
  hbLo: number = 0;
  hbHi: number = 0;
  // Recently checked: name + risk code ('KNOWN' | 'POSSIBLE' | 'CONDITIONAL' | 'OK' | 'UNKNOWN', '' = empty slot).
  chk0Name: string = '';
  chk0Risk: string = '';
  chk1Name: string = '';
  chk1Risk: string = '';
  chk2Name: string = '';
  chk2Risk: string = '';
  // Feeling diary.
  feelLast: string = '';
  // Set per card by WidgetSync: the 2 × 4 layout.
  wide: boolean = false;
}

export function applyDose(s: WidgetSnapshot, reminders: DoseReminder[], logs: DoseLog[], now: number): void {
  const c: DoseCard = doseCard(reminders, logs, now);
  s.doseState = c.state;
  s.doseName = c.name;
  s.doseWhen = c.when;
  s.doseTaken = c.taken;
  s.doseTotal = c.total;
  s.doseDots = c.dots;
  s.agentLine = agentDoseLine(c) ?? s.agentRest;
}

// Same words as the agent's line on Today (AgentLogic.agentLine) for a dose that is due or missed.
export function agentDoseLine(c: DoseCard): string | undefined {
  const what: string = `${c.time} ${c.name.toLowerCase()}`;
  if (c.state === 'MISSED') {
    return `Your ${what} hasn't been logged. Want to log it with me now?`;
  }
  if (c.state === 'DUE') {
    return `Your ${what} is due now. Want me to log it with you?`;
  }
  return undefined;
}
