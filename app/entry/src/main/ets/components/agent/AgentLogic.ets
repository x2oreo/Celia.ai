// Pure rules of the agent screen, kept free of UI imports so they run in the local unit tests.

import { VerdictCardPayload } from '../../model/AgentTypes';
import { DrugVerdict, RiskLevel } from '../../model/DrugVerdict';
import { VoicePhase } from '../../voice/RealtimeSession';
import {
  DoseLog, DoseReminder, DoseStatus, doseStatus, nextDoseToTake, scheduledTs, timeLabel
} from '../../reminders/DoseSchedule';

// Same values as ConfirmState in components/AgentCards.
export type CardState = 'OPEN' | 'ACCEPTED' | 'DECLINED';

// A confirm card stays open until the user answers it; the answer is kept for as long as the page lives.
export function confirmStateOf(resolved: string[], accepted: string[], actionId: string): CardState {
  if (!resolved.includes(actionId)) {
    return 'OPEN';
  }
  return accepted.includes(actionId) ? 'ACCEPTED' : 'DECLINED';
}

// The card payload carries the deterministic verdict; the colour and word come from it, never from model text.
export function verdictOf(p: VerdictCardPayload): DrugVerdict {
  const brand: string = p.query.length > 0 ? p.query.charAt(0).toUpperCase() + p.query.slice(1) : p.query;
  const v: DrugVerdict = {
    query: brand,
    ingredient: p.ingredient,
    risk: p.combinedRisk as RiskLevel,
    reason: p.reason,
    source: p.source
  };
  return v;
}

// What the orb shows: the voice phase, or "thinking" while a typed or tapped turn is running.
export function stagePhase(busy: boolean, phase: VoicePhase): VoicePhase {
  if (busy && (phase === 'OFF' || phase === 'LISTENING')) {
    return 'THINKING';
  }
  return phase;
}

// The opening words of the agent's greeting. Night hours get a plain "Hi" (no "Morning" at 01:10).
export function dayGreeting(hour: number, name: string): string {
  let part: string = '';
  if (hour >= 5 && hour < 12) {
    part = 'Morning';
  } else if (hour >= 12 && hour < 18) {
    part = 'Afternoon';
  } else if (hour >= 18) {
    part = 'Evening';
  }
  if (part === '') {
    return name.length > 0 ? `Hi, ${name}.` : 'Hi.';
  }
  return name.length > 0 ? `${part}, ${name}.` : `Good ${part.toLowerCase()}.`;
}

// The Today title: "Good afternoon, Ola". Night hours get a plain "Hi, Ola".
export function dayHello(hour: number, name: string): string {
  let part: string = '';
  if (hour >= 5 && hour < 12) {
    part = 'Good morning';
  } else if (hour >= 12 && hour < 18) {
    part = 'Good afternoon';
  } else if (hour >= 18) {
    part = 'Good evening';
  }
  if (part === '') {
    return name.length > 0 ? `Hi, ${name}` : 'Hi';
  }
  return name.length > 0 ? `${part}, ${name}` : part;
}

const SOON_MS: number = 60 * 60 * 1000;

// The dose the Today screen and the agent line talk about: the one due now, else the earliest missed one, else the
// next one still to come today. Undefined when there is nothing left today.
export class DoseFocus {
  reminder: DoseReminder;
  status: DoseStatus;
  at: number;   // today's scheduled time

  constructor(reminder: DoseReminder, status: DoseStatus, at: number) {
    this.reminder = reminder;
    this.status = status;
    this.at = at;
  }
}

export function doseFocus(reminders: DoseReminder[], logs: DoseLog[], now: number): DoseFocus | undefined {
  const take: DoseReminder | undefined = nextDoseToTake(reminders, logs, now);
  if (take !== undefined) {
    return new DoseFocus(take, doseStatus(take, logs, now), scheduledTs(take, now));
  }
  const later: DoseReminder[] = reminders
    .filter((r: DoseReminder) => doseStatus(r, logs, now) === 'UPCOMING' && scheduledTs(r, now) > now)
    .sort((a: DoseReminder, b: DoseReminder) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
  return later.length > 0 ? new DoseFocus(later[0], 'UPCOMING', scheduledTs(later[0], now)) : undefined;
}

// "Due at 14:00 · in 10 min", "Due at 14:00 · 5 min ago", "Missed at 08:00".
export function doseWhen(f: DoseFocus, now: number): string {
  const at: string = timeLabel(f.reminder);
  if (f.status === 'MISSED') {
    return `Missed at ${at}`;
  }
  const min: number = Math.round(Math.abs(f.at - now) / 60000);
  if (min === 0) {
    return `Due at ${at} · now`;
  }
  const span: string = min >= 60 ? `${Math.floor(min / 60)} h ${min % 60} min` : `${min} min`;
  return f.at > now ? `Due at ${at} · in ${span}` : `Due at ${at} · ${span} ago`;
}

// True when the agent has something to say about a dose: due, missed, or coming up within the hour.
export function doseNeedsWord(f: DoseFocus | undefined, now: number): boolean {
  if (f === undefined) {
    return false;
  }
  return f.status === 'DUE' || f.status === 'MISSED' || f.at - now <= SOON_MS;
}

// The agent's one sentence on Today and on the empty stage. Deterministic data only; supportive, never blaming.
export function agentLine(hello: string, f: DoseFocus | undefined, now: number, interactions: number,
  known: number): string {
  if (f !== undefined && doseNeedsWord(f, now)) {
    const what: string = `${timeLabel(f.reminder)} ${f.reminder.medName.toLowerCase()}`;
    if (f.status === 'MISSED') {
      return `Your ${what} hasn't been logged. Want to log it with me now?`;
    }
    return `Your ${what} is due ${f.status === 'DUE' ? 'now' : 'soon'}. Want me to log it with you?`;
  }
  if (interactions > 0) {
    return `${hello} Two of your medicines may interact. Let's check that with your doctor.`;
  }
  if (known > 0) {
    return `${hello} One of your medicines is on the QT list. Let's go through it with your doctor.`;
  }
  return `${hello} Everything looks calm. Got a new prescription? I can check it in seconds.`;
}
