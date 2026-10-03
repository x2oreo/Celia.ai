import { describe, it, expect } from '@ohos/hypium';
import {
  parseDailySummary, parseDoses, parseInsights, parseStatus, parseSymptoms
} from '../main/ets/data/WatchDataClient';
import {
  WatchDaySummary, WatchDose, WatchInsight, WatchStatus, WatchSymptom
} from '../main/ets/model/WatchData';

// Bodies shaped like real PostgREST responses from the watch views.
const STATUS: string = '[{"status":"OFF_WRIST","on_wrist":false,"last_sync":"2026-10-03T15:16:59.548+00:00",' +
  '"wear_changed_at":"2026-10-03T15:10:00+00:00"},{"status":"BROKEN","on_wrist":true,"last_sync":"x"}]';
const DOSES: string = '[{"id":2266,"name":"nadolol","taken_at":"2026-10-03T06:02:00+00:00","day":"2026-10-03",' +
  '"simulated":false},{"id":1,"name":"","taken_at":"2026-10-03T06:02:00+00:00","day":"2026-10-03"},' +
  '{"id":2,"name":"nadolol","taken_at":"2026-10-03T06:02:00+00:00","day":"03.10.2026"}]';
const SYMPTOMS: string = '[{"id":5,"kind":"dizziness","bpm":142,"recorded_at":"2026-10-03T15:58:00+00:00",' +
  '"simulated":true},{"id":6,"kind":"hacked","bpm":1,"recorded_at":"2026-10-03T15:58:00+00:00"},' +
  '{"id":7,"kind":"fine","bpm":-3,"recorded_at":"2026-10-03T16:00:00+00:00","simulated":false}]';
const SUMMARY: string = '[{"day":"2026-10-03","doses_taken":1,"first_dose_at":"2026-10-03T06:02:00+00:00",' +
  '"symptoms":6,"symptom_kinds":["dizziness","palpitations","bogus"],"fine_check_ins":2,"alerts":64,"falls":0,' +
  '"sos":1,"resting_bpm":49,"simulated":true},{"day":"2026-10-02","doses_taken":0,"first_dose_at":null,' +
  '"symptoms":0,"symptom_kinds":null,"fine_check_ins":0,"alerts":0,"falls":0,"sos":0,"resting_bpm":null,' +
  '"simulated":false}]';
const INSIGHTS: string = '[{"kind":"NO_DOSE_LOGGED","severity":"INFO","ts":"2026-10-03T16:00:00+00:00",' +
  '"message":"No nadolol dose logged.","simulated":false},' +
  '{"kind":"REPEATED_SYMPTOMS","severity":"WARN","ts":"2026-10-03T15:00:00+00:00","message":"Twice.",' +
  '"simulated":false},{"kind":"FAINTING_REPORTED","severity":"CRITICAL","ts":"2026-10-03T14:00:00+00:00",' +
  '"message":"Fainting.","simulated":true},{"kind":"MADE_UP","severity":"CRITICAL","ts":"x","message":"no"}]';

export default function watchDataClientTest() {
  describe('WatchDataClient', () => {
    it('parsesStatusAndDropsUnknown', 0, () => {
      const s: WatchStatus[] | undefined = parseStatus(STATUS);
      expect(s?.length).assertEqual(1);
      expect(s?.[0].status).assertEqual('OFF_WRIST');
      expect(s?.[0].onWrist).assertFalse();
      expect(s?.[0].lastSync).assertEqual(Date.parse('2026-10-03T15:16:59.548+00:00'));
    });

    it('parsesDosesAndDropsEmptyNamesAndBadDays', 0, () => {
      const d: WatchDose[] | undefined = parseDoses(DOSES);
      expect(d?.length).assertEqual(1);
      expect(d?.[0].name).assertEqual('nadolol');
      expect(d?.[0].day).assertEqual('2026-10-03');
    });

    it('parsesSymptomsAndClampsBpm', 0, () => {
      const s: WatchSymptom[] | undefined = parseSymptoms(SYMPTOMS);
      expect(s?.length).assertEqual(2);
      expect(s?.[0].kind).assertEqual('dizziness');
      expect(s?.[0].simulated).assertTrue();
      expect(s?.[1].kind).assertEqual('fine');
      expect(s?.[1].bpm).assertEqual(0);
    });

    it('parsesDailySummaryWithNulls', 0, () => {
      const d: WatchDaySummary[] | undefined = parseDailySummary(SUMMARY);
      expect(d?.length).assertEqual(2);
      expect(d?.[0].alerts).assertEqual(64);
      expect(d?.[0].symptomKinds.length).assertEqual(2);
      expect(d?.[1].firstDoseAt).assertEqual(0);
      expect(d?.[1].restingBpm).assertEqual(0);
      expect(d?.[1].symptomKinds.length).assertEqual(0);
    });

    it('sortsInsightsCriticalFirstAndDropsUnknownKinds', 0, () => {
      const i: WatchInsight[] | undefined = parseInsights(INSIGHTS);
      expect(i?.length).assertEqual(3);
      expect(i?.[0].kind).assertEqual('FAINTING_REPORTED');
      expect(i?.[1].severity).assertEqual('WARN');
      expect(i?.[2].kind).assertEqual('NO_DOSE_LOGGED');
    });

    it('failedOrMalformedBodyIsUndefinedNotEmpty', 0, () => {
      expect(parseDoses('not json') === undefined).assertTrue();
      expect(parseDoses('{"message":"error"}') === undefined).assertTrue();
      expect(parseDoses('[]')?.length).assertEqual(0);
    });
  });
}
