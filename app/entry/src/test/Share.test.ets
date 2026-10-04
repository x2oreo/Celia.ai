// Shareable links: link format, content fingerprint, report payload. (AES-GCM itself is checked end to end:
// the app seals, the browser's WebCrypto opens - see AI_WORKFLOW.md.)

import { describe, it, expect } from '@ohos/hypium';
import { contentHash, parseShareLink, viewerUrl } from '../main/ets/share/ShareService';
import { buildReport, doseAdherence, ReportDoses, ReportPayload } from '../main/ets/doctor/ReportPayload';
import { Profile } from '../main/ets/model/Profile';
import { Medication } from '../main/ets/model/Medication';
import { DailyResting } from '../main/ets/vitals/RestingTrend';
import { DoseLog, DoseReminder, dayKey } from '../main/ets/reminders/DoseSchedule';

const KEY: string = 'fxrmnew_59gbBKsO1qGwWbsomq_i8R8t7KXCZ0U12zY';

function med(id: number, name: string, ingredient: string): Medication {
  const m: Medication = { id: id, name: name, ingredient: ingredient, dose: '10 mg', addedAt: 0 };
  return m;
}

export default function shareTest() {
  describe('ShareLinks', () => {
    it('viewerUrlRoundTrips', 0, () => {
      const url: string = viewerUrl('report', 'IflDzJErw1hYaOoH', KEY);
      expect(url.endsWith(`/report/#IflDzJErw1hYaOoH.${KEY}`)).assertTrue();
      const parts: string[] | undefined = parseShareLink(url);
      expect(parts !== undefined && parts[0] === 'report' && parts[1] === 'IflDzJErw1hYaOoH' && parts[2] === KEY)
        .assertTrue();
    });

    it('rejectsForeignOrBrokenLinks', 0, () => {
      expect(parseShareLink('https://evil.example/card/#short.key') === undefined).assertTrue();
      expect(parseShareLink(`https://x.app/note/#IflDzJErw1hYaOoH.${KEY}`) === undefined).assertTrue();
      expect(parseShareLink(`https://x.app/card/#IflDzJErw1hYaOoH.${KEY}extra`) === undefined).assertTrue();
    });

    it('contentHashIsStableAndSensitive', 0, () => {
      expect(contentHash('{"a":1}')).assertEqual(contentHash('{"a":1}'));
      expect(contentHash('{"a":1}') !== contentHash('{"a":2}')).assertTrue();
    });
  });

  describe('ReportPayload', () => {
    it('summarisesRiskAndTrendDeterministically', 0, () => {
      const now: number = Date.UTC(2026, 9, 3, 12);
      const p: Profile = { condition: 'LQTS', genotype: 'LQT2', hasIcd: true, notes: '', contacts: [], name: 'Anna' };
      const meds: Medication[] = [med(1, 'Klacid', 'clarithromycin'), med(2, 'Nadolol', 'nadolol')];
      const resting: DailyResting[] = [];
      for (let i = 40; i >= 1; i--) {
        const d: DailyResting = { day: dayKey(now - i * 86400000), bpm: 58, restMinutes: 400, simulated: true };
        resting.push(d);
      }
      const r: ReportPayload = buildReport(p, meds, [], [], 'DENTIST', resting, [], [], now);
      expect(r.v).assertEqual(1);
      expect(r.summary.medsAtRisk).assertEqual(1);
      expect(r.meds[0].risk).assertEqual('KNOWN_RISK');
      expect(r.resting.length).assertEqual(30);
      expect(r.resting[0].day < r.resting[29].day).assertTrue();
      expect(r.restingSimulated).assertTrue();
      expect(r.doses.tracked).assertFalse();
      expect(r.watchOuts.length > 0 && r.questions.length > 0).assertTrue();
      expect(r.specialtyName).assertEqual('Dentist');
    });

    it('countsDosesInTheLastTwoWeeks', 0, () => {
      const now: number = Date.UTC(2026, 9, 3, 12);
      const rem: DoseReminder = { id: 7, medId: 2, medName: 'Nadolol', hour: 8, minute: 0, reminderId: -1 };
      const logs: DoseLog[] = [
        { reminderId: 7, day: dayKey(now), status: 'TAKEN', ts: now },
        { reminderId: 7, day: dayKey(now - 86400000), status: 'SKIPPED', ts: now },
        { reminderId: 7, day: dayKey(now - 30 * 86400000), status: 'TAKEN', ts: now },
        { reminderId: 99, day: dayKey(now), status: 'TAKEN', ts: now }
      ];
      const d: ReportDoses = doseAdherence([rem], logs, now);
      expect(d.tracked).assertTrue();
      expect(d.taken).assertEqual(1);
      expect(d.skipped).assertEqual(1);
      expect(d.scheduled).assertEqual(14);
    });
  });
}
