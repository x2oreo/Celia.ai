import { describe, it, expect } from '@ohos/hypium';
import { daysToKeep, DayRow, mergeDays, MAX_CACHED_DAYS, parseCached } from '../main/ets/data/HistoryCache';

function d(day: string, simulated: boolean): DayRow {
  const r: DayRow = { day: day, simulated: simulated };
  return r;
}

export default function historyCacheTest() {
  describe('HistoryCache', () => {
    it('keeps cached real days the server no longer returns, newest first', 0, () => {
      const fresh: DayRow[] = [d('2026-10-04', false), d('2026-10-03', false)];
      const cached: DayRow[] = [d('2026-10-03', false), d('2026-10-01', false), d('2026-09-30', false)];
      const m: DayRow[] = mergeDays<DayRow>(fresh, cached, 10);
      expect(m.map((r: DayRow) => r.day).join(',')).assertEqual('2026-10-04,2026-10-03,2026-10-01,2026-09-30');
    });

    it('the server wins for a day it returns', 0, () => {
      const fresh: DayRow[] = [d('2026-10-03', true)];
      const cached: DayRow[] = [d('2026-10-03', false)];
      const m: DayRow[] = mergeDays<DayRow>(fresh, cached, 10);
      expect(m.length).assertEqual(1);
      expect(m[0].simulated).assertTrue();
    });

    it('never brings back simulated days from the cache, and respects the limit', 0, () => {
      const cached: DayRow[] = [d('2026-10-02', true), d('2026-10-01', false), d('2026-09-30', false)];
      const m: DayRow[] = mergeDays<DayRow>([], cached, 1);
      expect(m.length).assertEqual(1);
      expect(m[0].day).assertEqual('2026-10-01');
    });

    it('stores only real days with a valid date, capped', 0, () => {
      const rows: DayRow[] = [d('2026-10-04', true), d('2026-10-03', false), d('bad', false)];
      expect(daysToKeep<DayRow>(rows).map((r: DayRow) => r.day).join(',')).assertEqual('2026-10-03');
      const many: DayRow[] = [];
      for (let i = 0; i < MAX_CACHED_DAYS + 10; i++) {
        many.push(d(new Date(Date.UTC(2026, 0, 1) + i * 86400000).toISOString().substring(0, 10), false));
      }
      expect(daysToKeep<DayRow>(many).length).assertEqual(MAX_CACHED_DAYS);
    });

    it('reads stored JSON defensively', 0, () => {
      expect(parseCached<DayRow>('not json').length).assertEqual(0);
      expect(parseCached<DayRow>('{"day": "2026-10-01"}').length).assertEqual(0);
      const ok: DayRow[] = parseCached<DayRow>(
        '[{"day": "2026-10-01", "simulated": false}, {"day": "2026-10-02", "simulated": true}, null, {"day": 5}]');
      expect(ok.length).assertEqual(1);
      expect(ok[0].day).assertEqual('2026-10-01');
    });
  });
}
