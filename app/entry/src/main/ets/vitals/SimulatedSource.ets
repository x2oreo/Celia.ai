// Simulated watch for the emulator and demos. Every sample is labelled SIMULATED on screen.
// Scenarios are pure functions of the elapsed second, so tests can sample them without timers.

import { VitalsSample } from '../model/Vitals';

export type ScenarioName = 'normal' | 'lqt1_exercise' | 'lqt2_startle_tachy' | 'lqt3_night_brady' |
  'irregular_rhythm' | 'watch_disconnect';

export const SCENARIOS: ScenarioName[] = ['normal', 'lqt1_exercise', 'lqt2_startle_tachy', 'lqt3_night_brady',
  'irregular_rhythm', 'watch_disconnect'];

// Deterministic jitter so tests are stable.
function wobble(t: number, amp: number): number {
  return Math.sin(t * 0.9) * amp + Math.sin(t * 2.3) * amp * 0.4;
}

function ramp(t: number, from: number, to: number, start: number, dur: number): number {
  if (t <= start) {
    return from;
  }
  if (t >= start + dur) {
    return to;
  }
  return from + (to - from) * ((t - start) / dur);
}

// Returns undefined when the simulated watch sends nothing (disconnect).
export function scenarioSample(name: ScenarioName, t: number, ts: number): VitalsSample | undefined {
  const s: VitalsSample = {
    ts: ts, hr: 72, source: 'SIMULATED', hrv: 48, restingHr: 64, asleep: false, irregular: false, steps: 0
  };
  switch (name) {
    case 'lqt1_exercise':
      s.steps = t < 5 ? 20 : 140;
      s.hr = ramp(t, 82, 178, 5, 25) + wobble(t, 2);
      s.hrv = ramp(t, 40, 18, 5, 25);
      break;
    case 'lqt2_startle_tachy':
      // Resting, then a sudden startle at t=8s: fast jump, slow recovery.
      s.hr = t < 8 ? 70 + wobble(t, 2) : (t < 40 ? 165 + wobble(t, 4) : ramp(t, 165, 80, 40, 30));
      s.hrv = t < 8 ? 50 : (t < 40 ? 10 : ramp(t, 10, 45, 40, 30));
      break;
    case 'lqt3_night_brady':
      s.asleep = true;
      s.hr = ramp(t, 58, 36, 4, 20) + wobble(t, 1);
      s.restingHr = 55;
      s.hrv = 62;
      break;
    case 'irregular_rhythm':
      s.hr = 96 + wobble(t, 18);
      s.irregular = t > 5;
      s.hrv = 85;
      break;
    case 'watch_disconnect':
      if (t >= 6) {
        return undefined;
      }
      s.hr = 74 + wobble(t, 2);
      break;
    default:
      s.hr = 72 + wobble(t, 3);
      break;
  }
  s.hr = Math.round(s.hr);
  return s;
}
