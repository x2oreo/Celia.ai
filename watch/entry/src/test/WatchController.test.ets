import { describe, it, expect } from '@ohos/hypium';
import { WatchController } from '../main/ets/controller/WatchController';

/**
 * Characterisation of the controller's public behaviour, written before it was split into units. A controller that
 * was never init()-ed has no Supabase clients, no stores and no permissions, so everything here runs offline.
 */
export default function watchControllerTest() {
  describe('WatchController', () => {
    it('needHelp starts one 10 s SOS countdown and cancel stops it', 0, () => {
      const c = new WatchController();
      c.needHelp();
      expect(c.sosCountdown).assertEqual(10);
      expect(c.alertKind).assertEqual('NONE');
      expect(c.pending).assertEqual(0);
      c.needHelp();
      expect(c.sosCountdown).assertEqual(10);
      c.cancelSos();
      expect(c.sosCountdown).assertEqual(0);
      expect(c.sosSent).assertFalse();
    });

    it('a fall answered with "I\'m OK" logs one row and opens the check-in', 0, () => {
      const c = new WatchController();
      c.simulateFall();
      expect(c.fallCountdown).assertEqual(30);
      expect(c.checkInOpen).assertFalse();
      c.simulateFall();
      expect(c.fallCountdown).assertEqual(30);
      c.imOk();
      expect(c.fallCountdown).assertEqual(0);
      expect(c.checkInOpen).assertTrue();
      expect(c.sosCountdown).assertEqual(0);
      expect(c.pending).assertEqual(1);
    });

    it('a fall answered with "Need help" logs the fall and starts SOS', 0, () => {
      const c = new WatchController();
      c.simulateFall();
      c.needHelp();
      expect(c.fallCountdown).assertEqual(0);
      expect(c.sosCountdown).assertEqual(10);
      expect(c.pending).assertEqual(1);
    });

    it('"I\'m OK" without a fall only opens the check-in', 0, () => {
      const c = new WatchController();
      c.imOk();
      expect(c.checkInOpen).assertTrue();
      expect(c.pending).assertEqual(0);
      c.checkIn('dizziness');
      expect(c.checkInOpen).assertFalse();
      expect(c.pending).assertEqual(1);
      c.imOk();
      c.closeCheckIn();
      expect(c.checkInOpen).assertFalse();
      expect(c.pending).assertEqual(1);
    });

    it('taking the watch off and on logs both and sets the status', 0, () => {
      const c = new WatchController();
      c.toggleWorn();
      expect(c.onWrist).assertFalse();
      expect(c.statusText).assertEqual('Watch not worn');
      expect(c.pending).assertEqual(1);
      c.toggleWorn();
      expect(c.onWrist).assertTrue();
      expect(c.statusText).assertEqual('');
      expect(c.pending).assertEqual(2);
    });

    it('a risky drug lowers the high limit and shows the verdict once', 0, () => {
      const c = new WatchController();
      expect(c.limitHigh).assertEqual(120);
      c.toggleRiskyDrug();
      expect(c.riskyDrug).assertEqual('Clarithromycin');
      expect(c.riskyDrugRisk).assertEqual('KNOWN_RISK');
      expect(c.riskyDrugAt > 0).assertTrue();
      expect(c.verdictDrug).assertEqual('Clarithromycin');
      expect(c.limitHigh).assertEqual(130);
      expect(c.limitReason).assertEqual('awake');
      c.dismissVerdict();
      expect(c.verdictDrug).assertEqual('');
      c.toggleRiskyDrug();
      expect(c.riskyDrug).assertEqual('');
      expect(c.riskyDrugAt).assertEqual(0);
      expect(c.limitHigh).assertEqual(140);
    });

    it('genotype and state overrides change the limits', 0, () => {
      const c = new WatchController();
      c.cycleGenotype();
      c.cycleGenotype();
      expect(c.genotype).assertEqual('LQT2');
      c.cycleActivityOverride();
      expect(c.activityOverride).assertEqual('REST');
      expect(c.activity).assertEqual('REST');
      expect(c.limitHigh).assertEqual(110);
      expect(c.limitReason).assertEqual('LQT2 at rest');
      c.cycleActivityOverride();
      c.cycleActivityOverride();
      expect(c.activity).assertEqual('ASLEEP');
      expect(c.limitHigh).assertEqual(100);
      expect(c.limitLow).assertEqual(40);
      c.cycleGenotype();
      expect(c.genotype).assertEqual('LQT3');
      expect(c.limitLow).assertEqual(45);
      c.cycleActivityOverride();
      expect(c.activityOverride).assertEqual('AUTO');
    });

    it('medication taken logs a row and closes the nudge', 0, () => {
      const c = new WatchController();
      c.showDoseNudgeNow();
      expect(c.doseNudgeOpen).assertTrue();
      expect(c.doseNudgeCanSnooze).assertTrue();
      c.doseTaken();
      expect(c.doseNudgeOpen).assertFalse();
      expect(c.pending).assertEqual(1);
      c.showDoseNudgeNow();
      c.doseNotYet();
      expect(c.doseNudgeOpen).assertFalse();
      expect(c.pending).assertEqual(1);
    });

    it('without Supabase settings sync is off and rows stay queued', 0, async () => {
      const c = new WatchController();
      c.logMedication();
      await c.syncNow();
      expect(c.syncState).assertEqual('OFF');
      expect(c.pending).assertEqual(1);
    });

    it('without Supabase settings pairing reports an error', 0, async () => {
      const c = new WatchController();
      await c.refreshPairState();
      expect(c.pairState).assertEqual('ERROR');
      const err = await c.startPairing();
      expect(err).assertEqual('Supabase is not configured (watch/.env)');
      expect(c.pairingOpen).assertTrue();
      expect(c.pairScreen).assertEqual('ERROR');
      c.closePairing();
      expect(c.pairingOpen).assertFalse();
    });

    it('demo controls cycle and the source stays on the sensor outside demo mode', 0, () => {
      const c = new WatchController();
      c.cycleSource();
      expect(c.sourceKind).assertEqual('SENSOR');
      expect(c.demoSpeed).assertEqual(4);
      c.cycleDemoSpeed();
      expect(c.demoSpeed).assertEqual(8);
      c.cycleDemoSpeed();
      expect(c.demoSpeed).assertEqual(1);
      const first = c.scenarioLabel;
      c.cycleScenario();
      expect(c.scenarioLabel === first).assertFalse();
    });

    it('pausing a stopped monitor records nothing', 0, () => {
      const c = new WatchController();
      c.pause();
      expect(c.running).assertFalse();
      expect(c.pending).assertEqual(0);
      c.dismissSosSent();
      expect(c.sosSent).assertFalse();
    });
  });
}
