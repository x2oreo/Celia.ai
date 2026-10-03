import { describe, it, expect } from '@ohos/hypium';
import { MemoryOutboxStore, MetricOutbox } from '../main/ets/sync/MetricOutbox';
import { HrLiveValues, MetricRow, SymptomValues, makeRow } from '../main/ets/model/WatchMetric';

class CountingStore extends MemoryOutboxStore {
  saves: number = 0;

  save(json: string): void {
    this.saves++;
    super.save(json);
  }
}

function live(bpm: number): MetricRow {
  const v: HrLiveValues = { bpm: bpm, activity: 'REST' };
  return makeRow('dev', 'hr_live', v, 0, 'simulated');
}

function symptom(): MetricRow {
  const v: SymptomValues = { kind: 'palpitations', bpm: 120 };
  return makeRow('dev', 'symptom', v, 0, 'simulated');
}

export default function metricOutboxTest() {
  describe('MetricOutbox', () => {
    it('keeps FIFO order and acks from the front', 0, () => {
      const box = new MetricOutbox(new MemoryOutboxStore(), 10);
      box.enqueue(live(1));
      box.enqueue(live(2));
      box.enqueue(live(3));
      expect(box.peek(2).length).assertEqual(2);
      box.ack(2);
      expect(box.size).assertEqual(1);
      expect((box.peek(1)[0].payload as HrLiveValues).bpm).assertEqual(3);
    });

    it('reports a waiting row type until it is acked', 0, () => {
      const box = new MetricOutbox(new MemoryOutboxStore(), 10);
      box.enqueue(live(1));
      box.enqueue(symptom());
      expect(box.has('symptom')).assertTrue();
      box.ack(1);
      expect(box.has('symptom')).assertTrue();
      box.ack(1);
      expect(box.has('symptom')).assertFalse();
    });

    it('survives a restart via the store', 0, () => {
      const store = new MemoryOutboxStore();
      const a = new MetricOutbox(store, 10);
      a.enqueue(symptom());
      a.flush();
      const b = new MetricOutbox(store, 10);
      expect(b.size).assertEqual(1);
      expect(b.peek(1)[0].type).assertEqual('symptom');
    });

    it('drops hr_live before important rows when full', 0, () => {
      const box = new MetricOutbox(new MemoryOutboxStore(), 2);
      box.enqueue(symptom());
      box.enqueue(live(1));
      box.enqueue(symptom());
      expect(box.size).assertEqual(2);
      expect(box.peek(2)[0].type).assertEqual('symptom');
      expect(box.peek(2)[1].type).assertEqual('symptom');
    });

    it('writes to the store only on flush, and only when changed', 0, () => {
      const store = new CountingStore();
      const box = new MetricOutbox(store, 10);
      box.enqueue(live(1));
      box.enqueue(live(2));
      box.enqueue(symptom());
      expect(store.saves).assertEqual(0);
      expect(box.flush()).assertTrue();
      expect(store.saves).assertEqual(1);
      expect(box.flush()).assertFalse();
      box.ack(1);
      expect(box.flush()).assertTrue();
      expect(store.saves).assertEqual(2);
      expect(new MetricOutbox(store, 10).size).assertEqual(2);
    });

    it('ignores corrupt stored data', 0, () => {
      const store = new MemoryOutboxStore();
      store.save('{not json');
      expect(new MetricOutbox(store, 10).size).assertEqual(0);
    });
  });
}
