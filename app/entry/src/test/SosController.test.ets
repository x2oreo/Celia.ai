import { describe, it, expect } from '@ohos/hypium';
import { COOLDOWN_MS, SosController } from '../main/ets/emergency/SosController';
import { GeoPoint, sosMessage } from '../main/ets/emergency/SosMessage';
import { Profile } from '../main/ets/model/Profile';
import { Medication } from '../main/ets/model/Medication';

function profile(): Profile {
  const p: Profile = {
    condition: 'LQTS', genotype: 'LQT2', hasIcd: true, notes: '', name: 'Anna',
    contacts: [{ name: 'Mum', phone: '+48 600 100 200', relation: 'mother' }]
  };
  return p;
}

export default function sosControllerTest() {
  describe('SosController', () => {
    it('ackStopsCountdown', 0, () => {
      const c: SosController = new SosController();
      c.start(0, 30, false);
      c.ack();
      expect(c.tick(60000)).assertEqual('ACKED');
      expect(c.inCooldown(60000)).assertFalse();
    });

    it('timeoutSends', 0, () => {
      const c: SosController = new SosController();
      c.start(0, 30, false);
      expect(c.tick(29000)).assertEqual('COUNTDOWN');
      expect(c.remainingSeconds(29000)).assertEqual(1);
      expect(c.tick(30000)).assertEqual('SENT');
    });

    it('cooldownBlocksAutoStartOnly', 0, () => {
      const c: SosController = new SosController();
      c.start(0, 30, false);
      c.sendNow(1000);
      c.reset();
      expect(c.canAutoStart(2000)).assertFalse();
      expect(c.canAutoStart(1000 + COOLDOWN_MS)).assertTrue();
    });

    it('testSosHasNoCooldown', 0, () => {
      const c: SosController = new SosController();
      c.start(0, 10, true);
      c.tick(10000);
      c.reset();
      expect(c.canAutoStart(11000)).assertTrue();
    });

    it('cancelOnlyDuringCountdown', 0, () => {
      const c: SosController = new SosController();
      c.cancel();
      expect(c.state).assertEqual('IDLE');
      c.start(0, 30, false);
      c.cancel();
      expect(c.state).assertEqual('CANCELLED');
    });

    it('autoStartNeverInterruptsCountdown', 0, () => {
      const c: SosController = new SosController();
      c.start(0, 30, false);
      expect(c.canAutoStart(1000)).assertFalse();
    });
  });

  describe('SosMessage', () => {
    it('containsEssentials', 0, () => {
      const meds: Medication[] = [{ id: 1, name: 'Nadolol', ingredient: 'nadolol', dose: '40 mg', addedAt: 0 }];
      const m: string = sosMessage(profile(), meds, new GeoPoint(52.2297, 21.0122), 'heart rate 165 at rest', false);
      expect(m.includes('Anna')).assertTrue();
      expect(m.includes('LQT2')).assertTrue();
      expect(m.includes('ICD: yes')).assertTrue();
      expect(m.includes('52.22970,21.01220')).assertTrue();
      expect(m.includes('Nadolol')).assertTrue();
      expect(m.includes('TEST')).assertFalse();
    });

    it('testMessageIsMarked', 0, () => {
      const m: string = sosMessage(profile(), [], undefined, '', true);
      expect(m.startsWith('*** TEST')).assertTrue();
      expect(m.includes('Location: unknown')).assertTrue();
    });
  });
}
