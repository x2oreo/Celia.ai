// Deterministic heart-rate alarm rules, tuned per LQTS genotype. Pure logic — unit tested, no timers.
// Thresholds are conservative demo values for decision support, not clinical alarm limits.

import { AlertKind, AlertSeverity, VitalsAlert, VitalsSample } from '../model/Vitals';
import { Genotype } from '../model/Profile';

export const DEBOUNCE_MS: number = 15000;
const EXERTION_STEPS: number = 60;

export class AlarmRules {
  private genotype: Genotype;
  private lastFired: Map<AlertKind, number> = new Map<AlertKind, number>();

  constructor(genotype: Genotype) {
    this.genotype = genotype;
  }

  setGenotype(genotype: Genotype): void {
    this.genotype = genotype;
  }

  reset(): void {
    this.lastFired.clear();
  }

  // Returns at most one alert per sample — the most severe rule that fires and is not debounced.
  evaluate(s: VitalsSample): VitalsAlert | undefined {
    const candidates: VitalsAlert[] = this.candidates(s);
    candidates.sort((a: VitalsAlert, b: VitalsAlert) => rank(b.severity) - rank(a.severity));
    for (const c of candidates) {
      const last: number | undefined = this.lastFired.get(c.kind);
      if (last !== undefined && s.ts - last < DEBOUNCE_MS) {
        continue;
      }
      this.lastFired.set(c.kind, s.ts);
      return c;
    }
    return undefined;
  }

  // Called by the service when no sample arrived for a while.
  disconnected(ts: number): VitalsAlert | undefined {
    const last: number | undefined = this.lastFired.get('WATCH_DISCONNECTED');
    if (last !== undefined && ts - last < DEBOUNCE_MS * 4) {
      return undefined;
    }
    this.lastFired.set('WATCH_DISCONNECTED', ts);
    return alert(ts, 'WATCH_DISCONNECTED', 0, 'INFO',
      'No heart-rate data from the watch. Heart monitoring is paused — check that the watch is on and connected.');
  }

  private candidates(s: VitalsSample): VitalsAlert[] {
    const out: VitalsAlert[] = [];
    const exertion: boolean = (s.steps ?? 0) > EXERTION_STEPS;
    const asleep: boolean = s.asleep ?? false;

    if (!exertion && s.hr >= 120) {
      const critical: boolean = s.hr >= 150 || (this.genotype === 'LQT2' && s.hr >= 135);
      const why: string = this.genotype === 'LQT2' ?
        ' Sudden stress or a startle (alarm clock, phone) is a typical LQT2 trigger.' : '';
      out.push(alert(s.ts, 'TACHY_AT_REST', s.hr, critical ? 'CRITICAL' : 'WARN',
        `Heart rate ${Math.round(s.hr)} while resting.${why} Sit or lie down. Are you OK?`));
    }

    const bradyLimit: number = asleep ? 40 : 45;
    if (s.hr > 0 && s.hr <= bradyLimit) {
      const critical: boolean = this.genotype === 'LQT3' || s.hr <= 35;
      const why: string = this.genotype === 'LQT3' ? ' LQT3 events often happen at rest or during sleep.' : '';
      out.push(alert(s.ts, 'BRADY', s.hr, critical ? 'CRITICAL' : 'WARN',
        `Heart rate dropped to ${Math.round(s.hr)}${asleep ? ' during sleep' : ''}.${why}`));
    }

    if (exertion && s.hr >= 170) {
      const why: string = this.genotype === 'LQT1' ?
        ' Exertion is the typical LQT1 trigger — slow down now and rest.' : ' Slow down and rest.';
      out.push(alert(s.ts, 'HIGH_HR_EXERTION', s.hr, this.genotype === 'LQT1' ? 'CRITICAL' : 'WARN',
        `Heart rate ${Math.round(s.hr)} during activity.${why}`));
    }

    if (s.irregular === true) {
      out.push(alert(s.ts, 'IRREGULAR_RHYTHM', s.hr, s.hr >= 150 || s.hr <= 40 ? 'CRITICAL' : 'WARN',
        'The watch detected an irregular rhythm. Sit down. If you feel faint or dizzy, get help.'));
    }

    if (s.hrv !== undefined && s.hrv < 12 && !exertion) {
      out.push(alert(s.ts, 'HRV_DROP', s.hr, 'INFO',
        'Heart-rate variability is unusually low — a sign of stress. Take a few slow breaths.'));
    }
    return out;
  }
}

function rank(sev: AlertSeverity | undefined): number {
  switch (sev) {
    case 'CRITICAL':
      return 3;
    case 'WARN':
      return 2;
    default:
      return 1;
  }
}

function alert(ts: number, kind: AlertKind, hr: number, severity: AlertSeverity, message: string): VitalsAlert {
  const a: VitalsAlert = { ts: ts, kind: kind, hr: hr, message: message, severity: severity };
  return a;
}
