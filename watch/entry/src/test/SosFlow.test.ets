import { describe, it, expect } from '@ohos/hypium';
import { FallRecord, SosFlow } from '../main/ets/controller/SosFlow';
import { SosValues } from '../main/ets/model/WatchMetric';
import { Fix } from '../main/ets/sync/SosLocation';

const T0 = 1000000;

export default function sosFlowTest() {
  describe('SosFlow', () => {
    it('fall countdown runs 30 s, vibrates every 5 s and then times out', 0, () => {
      const f = new SosFlow();
      expect(f.startFall(88, T0)).assertTrue();
      expect(f.startFall(90, T0 + 1000)).assertFalse();
      expect(f.tickFall(T0 + 1000)).assertEqual('NONE');
      expect(f.fallCountdown).assertEqual(29);
      expect(f.tickFall(T0 + 5000)).assertEqual('VIBRATE');
      expect(f.fallCountdown).assertEqual(25);
      expect(f.tickFall(T0 + 29999)).assertEqual('NONE');
      expect(f.fallCountdown).assertEqual(1);
      expect(f.tickFall(T0 + 30000)).assertEqual('TIMED_OUT');
    });

    it('finishing a fall returns the row stamped at the fall', 0, () => {
      const f = new SosFlow();
      f.startFall(88, T0);
      const r: FallRecord = f.finishFall('no_response', T0 + 30400);
      expect(r.atMs).assertEqual(T0);
      expect(r.values.bpm).assertEqual(88);
      expect(r.values.response).assertEqual('no_response');
      expect(r.values.responseSec).assertEqual(30);
      expect(f.fallCountdown).assertEqual(0);
      expect(f.tickFall(T0 + 31000)).assertEqual('NONE');
    });

    it('SOS counts down 10 s and then yields the row once', 0, () => {
      const f = new SosFlow();
      expect(f.startSos('fall', T0)).assertTrue();
      expect(f.startSos('need_help', T0 + 500)).assertFalse();
      expect(f.tickSos(T0 + 3000, 100, 'REST')).assertUndefined();
      expect(f.sosCountdown).assertEqual(7);
      const v: SosValues | undefined = f.tickSos(T0 + 10000, 101, 'REST');
      expect(v !== undefined).assertTrue();
      expect((v as SosValues).reason).assertEqual('fall');
      expect((v as SosValues).bpm).assertEqual(101);
      expect((v as SosValues).lat).assertUndefined();
      expect(f.sosCountdown).assertEqual(0);
      expect(f.sosSent).assertTrue();
      expect(f.sosDelivered).assertFalse();
      expect(f.tickSos(T0 + 11000, 101, 'REST')).assertUndefined();
    });

    it('adds the location fix and forgets it on the next SOS', 0, () => {
      const f = new SosFlow();
      f.startSos('need_help', T0);
      const fix: Fix = { lat: 50.06, lon: 19.94, accuracyM: 12 };
      f.setFix(fix);
      const v = f.tickSos(T0 + 10000, 90, 'ACTIVE') as SosValues;
      expect(v.lat).assertEqual(50.06);
      expect(v.accuracyM).assertEqual(12);
      f.startSos('need_help', T0 + 20000);
      const w = f.tickSos(T0 + 30000, 90, 'ACTIVE') as SosValues;
      expect(w.lat).assertUndefined();
    });

    it('cancel stops the countdown without a row', 0, () => {
      const f = new SosFlow();
      f.startSos('need_help', T0);
      f.cancelSos();
      expect(f.tickSos(T0 + 10000, 90, 'REST')).assertUndefined();
      expect(f.sosSent).assertFalse();
    });

    it('delivery is confirmed once, only after the row left the queue', 0, () => {
      const f = new SosFlow();
      expect(f.confirmDelivery(false)).assertFalse();
      f.startSos('need_help', T0);
      f.tickSos(T0 + 10000, 90, 'REST');
      expect(f.confirmDelivery(true)).assertFalse();
      expect(f.confirmDelivery(false)).assertTrue();
      expect(f.sosDelivered).assertTrue();
      expect(f.confirmDelivery(false)).assertFalse();
      f.dismissSent();
      expect(f.sosSent).assertFalse();
    });
  });
}
