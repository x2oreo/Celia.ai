// Pure rules of the agent screen, kept free of UI imports so they run in the local unit tests.

import { VerdictCardPayload } from '../../model/AgentTypes';
import { DrugVerdict, RiskLevel } from '../../model/DrugVerdict';
import { VoicePhase } from '../../voice/RealtimeSession';

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
