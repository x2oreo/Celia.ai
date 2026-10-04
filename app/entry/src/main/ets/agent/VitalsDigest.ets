// Keeps a short rolling window of vitals so the agent can summarise them (get_vitals_summary, context line)
// without touching VitalsService internals. Labels simulated data as simulated - never presents it as real.

import { VitalsAlert, VitalsSample } from '../model/Vitals';
import { VitalsService } from '../vitals/VitalsService';

const WINDOW_MS: number = 30 * 60 * 1000;
const MAX_SAMPLES: number = 600;

export class VitalsDigest {
  private static instance: VitalsDigest | undefined = undefined;

  private samples: VitalsSample[] = [];
  private alerts: VitalsAlert[] = [];
  private started: boolean = false;

  static get(): VitalsDigest {
    if (VitalsDigest.instance === undefined) {
      VitalsDigest.instance = new VitalsDigest();
    }
    return VitalsDigest.instance;
  }

  start(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    VitalsService.get().onSample((s: VitalsSample) => this.addSample(s));
    VitalsService.get().onAlert((a: VitalsAlert) => this.addAlert(a));
  }

  addSample(s: VitalsSample): void {
    this.samples.push(s);
    const cutoff: number = s.ts - WINDOW_MS;
    this.samples = this.samples.filter((x: VitalsSample) => x.ts >= cutoff).slice(-MAX_SAMPLES);
  }

  addAlert(a: VitalsAlert): void {
    this.alerts.push(a);
    this.alerts = this.alerts.slice(-20);
  }

  // One line, e.g. "Heart rate now 74 bpm, 30-min range 61-88 bpm (simulated). 1 alert: TACHY_AT_REST at 165 bpm."
  summary(now: number): string {
    const recent: VitalsSample[] = this.samples.filter((x: VitalsSample) => x.ts >= now - WINDOW_MS);
    if (recent.length === 0) {
      return 'No heart-rate data in the last 30 minutes (watch not connected).';
    }
    let min: number = recent[0].hr;
    let max: number = recent[0].hr;
    for (const s of recent) {
      min = Math.min(min, s.hr);
      max = Math.max(max, s.hr);
    }
    const last: VitalsSample = recent[recent.length - 1];
    const label: string = last.source === 'SIMULATED' ? ' (simulated)' : ' (watch)';
    let line: string = `Heart rate now ${Math.round(last.hr)} bpm, 30-min range ${Math.round(min)}-${Math.round(max)} bpm${label}.`;
    const recentAlerts: VitalsAlert[] = this.alerts.filter((a: VitalsAlert) => a.ts >= now - WINDOW_MS);
    if (recentAlerts.length === 0) {
      line += ' No alerts.';
    } else {
      const a: VitalsAlert = recentAlerts[recentAlerts.length - 1];
      line += ` ${recentAlerts.length} alert(s), latest: ${a.kind} at ${Math.round(a.hr)} bpm.`;
    }
    return line;
  }
}
