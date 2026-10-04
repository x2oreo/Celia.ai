// The Next dose card's state (DESIGN.md §11 widgets v2). Pure - unit tested. Only DoseSchedule is imported, so the
// form extension can recompute it by the clock without loading the rest of the app.
// Times are absolute ("Due at 14:00"): the card refreshes every 30 min, so a countdown would go stale.

import { DoseLog, DoseReminder, DoseStatus, doseStatus, nextDoseToTake, scheduledTs, timeLabel } from '../reminders/DoseSchedule';

// DUE / MISSED show the Taken button; UPCOMING the next one; DONE after the last dose; NONE without reminders.
export type DoseCardState = 'DUE' | 'MISSED' | 'UPCOMING' | 'DONE' | 'NONE';

export class DoseCard {
  state: DoseCardState = 'NONE';
  name: string = '';
  time: string = '';   // "14:00"
  when: string = '';
  taken: number = 0;
  total: number = 0;
  dots: string = '';   // one char per dose today in time order: '1' taken, '0' not yet
}

function byTime(a: DoseReminder, b: DoseReminder): number {
  return (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute);
}

export function doseCard(reminders: DoseReminder[], logs: DoseLog[], now: number): DoseCard {
  const c: DoseCard = new DoseCard();
  if (reminders.length === 0) {
    return c;
  }
  const sorted: DoseReminder[] = reminders.slice().sort(byTime);
  const states: DoseStatus[] = sorted.map((r: DoseReminder) => doseStatus(r, logs, now));
  c.total = sorted.length;
  c.taken = states.filter((s: DoseStatus) => s === 'TAKEN').length;
  c.dots = states.map((s: DoseStatus) => s === 'TAKEN' ? '1' : '0').join('');
  // Same order as Today: a dose to take now (due, else missed), then the next one later today.
  const take: DoseReminder | undefined = nextDoseToTake(sorted, logs, now);
  if (take !== undefined) {
    const missed: boolean = doseStatus(take, logs, now) === 'MISSED';
    c.state = missed ? 'MISSED' : 'DUE';
    c.name = take.medName;
    c.time = timeLabel(take);
    c.when = `${missed ? 'Missed at' : 'Due at'} ${timeLabel(take)}`;
    return c;
  }
  const later: DoseReminder | undefined = sorted.find((r: DoseReminder) =>
    doseStatus(r, logs, now) === 'UPCOMING' && scheduledTs(r, now) > now);
  if (later !== undefined) {
    c.state = 'UPCOMING';
    c.name = later.medName;
    c.time = timeLabel(later);
    c.when = `Next at ${timeLabel(later)}`;
    return c;
  }
  c.state = 'DONE';
  return c;
}
