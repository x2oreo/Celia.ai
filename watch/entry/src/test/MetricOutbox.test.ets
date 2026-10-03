import { describe, it, expect } from '@ohos/hypium';
import { MemoryOutboxStore, MetricOutbox } from '../main/ets/sync/MetricOutbox';
import { HrLiveValues, MetricRow, SymptomValues, makeRow } from '../main/ets/model/WatchMetric';

function live(bpm: number): MetricRow {
  const v: HrLiveValues = { bpm: bpm };
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

    it('survives a restart via the store', 0, () => {
      const store = new MemoryOutboxStore();
      const a = new MetricOutbox(store, 10);
      a.enqueue(symptom());
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

    it('ignores corrupt stored data', 0, () => {
      const store = new MemoryOutboxStore();
      store.save('{not json');
      expect(new MetricOutbox(store, 10).size).assertEqual(0);
    });
  });
}
