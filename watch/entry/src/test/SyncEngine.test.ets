import { describe, it, expect } from '@ohos/hypium';
import { SyncEngine } from '../main/ets/controller/SyncEngine';
import { MemoryOutboxStore, MetricOutbox } from '../main/ets/sync/MetricOutbox';
import { MetricUploader, UploadResult } from '../main/ets/sync/SupabaseUploader';
import { MetricRow, MetricType, SymptomValues, makeRow } from '../main/ets/model/WatchMetric';

/** Answers with the next scripted status (200 when the script is empty) and remembers batch sizes. */
class FakeUploader implements MetricUploader {
  statuses: number[] = [];
  batches: number[] = [];
  sentTypes: MetricType[] = [];

  async upload(rows: MetricRow[]): Promise<UploadResult> {
    this.batches.push(rows.length);
    const status = this.statuses.length > 0 ? this.statuses.shift() as number : 200;
    const ok = status >= 200 && status < 300;
    if (ok) {
      rows.forEach((r: MetricRow) => {
        this.sentTypes.push(r.type);
      });
    }
    const res: UploadResult = { ok: ok, status: status, message: `HTTP ${status}` };
    return res;
  }
}

function row(type: MetricType): MetricRow {
  const v: SymptomValues = { kind: 'fine', bpm: 70 };
  return makeRow('dev', type, v, 0, 'watch');
}

function engine(up: FakeUploader | undefined): SyncEngine {
  const e = new SyncEngine();
  e.configure(new MetricOutbox(new MemoryOutboxStore(), 500), up);
  return e;
}

export default function syncEngineTest() {
  describe('SyncEngine', () => {
    it('without an uploader rows stay queued and the state is OFF', 0, async () => {
      const e = engine(undefined);
      e.record(row('symptom'));
      expect(await e.syncNow()).assertFalse();
      expect(e.syncState).assertEqual('OFF');
      expect(e.pending).assertEqual(1);
    });

    it('starts PENDING when a restored queue is not empty', 0, () => {
      const box = new MetricOutbox(new MemoryOutboxStore(), 500);
      box.enqueue(row('symptom'));
      const e = new SyncEngine();
      e.configure(box, new FakeUploader());
      expect(e.pending).assertEqual(1);
      expect(e.syncState).assertEqual('PENDING');
    });

    it('uploads in batches of 50 until the queue is empty', 0, async () => {
      const up = new FakeUploader();
      const e = engine(up);
      expect(e.syncState).assertEqual('OK');
      for (let i = 0; i < 60; i++) {
        e.record(row('hr_live'));
      }
      expect(e.syncState).assertEqual('PENDING');
      expect(await e.syncNow()).assertTrue();
      expect(e.pending).assertEqual(10);
      expect(e.syncState).assertEqual('PENDING');
      await e.syncNow();
      expect(e.pending).assertEqual(0);
      expect(e.syncState).assertEqual('OK');
      expect(up.batches.join(',')).assertEqual('50,10');
      expect(await e.syncNow()).assertFalse();
    });

    it('a rejected batch is retried row by row and only the bad row is dropped', 0, async () => {
      const up = new FakeUploader();
      const e = engine(up);
      e.record(row('rhythm_alert'));
      e.record(row('symptom'));
      up.statuses = [400, 400];
      expect(await e.syncNow()).assertFalse();
      expect(e.pending).assertEqual(2);
      await e.syncNow();
      expect(e.pending).assertEqual(1);
      await e.syncNow();
      expect(e.pending).assertEqual(0);
      expect(up.batches.join(',')).assertEqual('2,1,1');
      expect(up.sentTypes.join(',')).assertEqual('symptom');
    });

    it('persists the queue once per sync, online or not', 0, async () => {
      const store = new MemoryOutboxStore();
      const e = new SyncEngine();
      e.configure(new MetricOutbox(store, 500), undefined);
      e.record(row('symptom'));
      e.record(row('sos'));
      expect(new MetricOutbox(store, 500).size).assertEqual(0);
      await e.syncNow();
      expect(new MetricOutbox(store, 500).size).assertEqual(2);
      const up = new FakeUploader();
      const online = new SyncEngine();
      online.configure(new MetricOutbox(store, 500), up);
      await online.syncNow();
      expect(new MetricOutbox(store, 500).size).assertEqual(0);
    });

    it('a network error keeps the rows and says ERROR', 0, async () => {
      const up = new FakeUploader();
      const e = engine(up);
      e.record(row('sos'));
      up.statuses = [0];
      expect(await e.syncNow()).assertFalse();
      expect(e.syncState).assertEqual('ERROR');
      expect(e.has('sos')).assertTrue();
      await e.syncNow();
      expect(e.has('sos')).assertFalse();
      expect(e.syncState).assertEqual('OK');
    });
  });
}
