import { describe, it, expect } from '@ohos/hypium';
import { MetricRow, WatchCloudSource } from '../main/ets/vitals/WatchCloudSource';
import { VitalsAlert, VitalsSample } from '../main/ets/model/Vitals';

function row(type: string, payload: Record<string, Object>, source: string): MetricRow {
  const r: MetricRow = { id: 1, type: type, payload: payload, recorded_at: '2026-10-03T12:00:00.000Z', source: source };
  return r;
}

export default function watchCloudSourceTest() {
  describe('WatchCloudSource', () => {
    it('hr_live from the watch sensor becomes a WATCH sample with extras', 0, () => {
      const p: Record<string, Object> = { 'bpm': 128, 'activity': 'REST', 'hrvMs': 18 };
      const s: VitalsSample | undefined = WatchCloudSource.toSample(row('hr_live', p, 'watch'), 40, 62, false);
      expect(s !== undefined).assertTrue();
      if (s !== undefined) {
        expect(s.source).assertEqual('WATCH');
        expect(s.hr).assertEqual(128);
        expect(s.hrv).assertEqual(18);
        expect(s.restingHr).assertEqual(62);
        expect(s.steps).assertEqual(0);
        expect(s.asleep).assertFalse();
        expect(s.ts).assertEqual(Date.parse('2026-10-03T12:00:00.000Z'));
      }
    });

    it('watch demo rows stay labelled SIMULATED; activity maps to steps / asleep', 0, () => {
      const active: Record<string, Object> = { 'bpm': 150, 'activity': 'ACTIVE' };
      const a: VitalsSample | undefined = WatchCloudSource.toSample(row('hr_live', active, 'simulated'),
        undefined, undefined, undefined);
      expect(a !== undefined && a.source === 'SIMULATED' && (a.steps ?? 0) > 60).assertTrue();
      const asleep: Record<string, Object> = { 'bpm': 38, 'activity': 'ASLEEP' };
      const b: VitalsSample | undefined = WatchCloudSource.toSample(row('hr_live', asleep, 'watch'),
        undefined, undefined, undefined);
      expect(b !== undefined && b.asleep === true).assertTrue();
    });

    it('ignores non-live rows and bad payloads as samples', 0, () => {
      const v: Record<string, Object> = { 'bpm': 70 };
      expect(WatchCloudSource.toSample(row('vitals', v, 'watch'), undefined, undefined, undefined) === undefined)
        .assertTrue();
      const bad: Record<string, Object> = { 'bpm': 'x' };
      expect(WatchCloudSource.toSample(row('hr_live', bad, 'watch'), undefined, undefined, undefined) === undefined)
        .assertTrue();
    });

    it('watch SOS is CRITICAL (starts the phone SOS flow); fall and slow recovery are WARN', 0, () => {
      const sos: Record<string, Object> = { 'reason': 'fall', 'bpm': 50, 'activity': 'REST' };
      const a: VitalsAlert | undefined = WatchCloudSource.toAlert(row('sos', sos, 'watch'));
      expect(a !== undefined && a.severity === 'CRITICAL' && a.kind === 'HR_ALARM_FROM_WATCH').assertTrue();
      const fall: Record<string, Object> = { 'bpm': 50, 'response': 'ok', 'responseSec': 3 };
      expect(WatchCloudSource.toAlert(row('fall_detected', fall, 'watch'))?.severity).assertEqual('WARN');
      const slow: Record<string, Object> = { 'peakBpm': 150, 'bpmAfter60s': 145, 'dropBpm': 5, 'slow': true };
      expect(WatchCloudSource.toAlert(row('hr_recovery', slow, 'watch'))?.severity).assertEqual('WARN');
      const ok: Record<string, Object> = { 'peakBpm': 150, 'bpmAfter60s': 110, 'dropBpm': 40, 'slow': false };
      expect(WatchCloudSource.toAlert(row('hr_recovery', ok, 'watch')) === undefined).assertTrue();
    });

    it('heart-rate alerts are left to the phone rules (no duplicates)', 0, () => {
      const hr: Record<string, Object> = { 'bpm': 165, 'limitBpm': 110, 'direction': 'high' };
      expect(WatchCloudSource.toAlert(row('hr_alert', hr, 'watch')) === undefined).assertTrue();
    });
  });
}
