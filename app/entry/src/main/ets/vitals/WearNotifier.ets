// Wrist alerts (F-13, F-33). On a phone paired with a Huawei watch this is where Wear Engine's NotifyClient
// goes (needs Wear Engine access approved in AppGallery Connect and a real device). Until then - and always on
// the emulator - the alert is a phone notification + haptic pulse, and the attempt is logged.

import { CheckOutcome, CheckService } from '../drugs/CheckService';
import { VitalsAlert } from '../model/Vitals';
import { notify, NOTIFY_ALERT, NOTIFY_RISKY_CHECK } from '../common/Notify';
import { pulse } from '../common/Haptics';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('WearNotifier');

export class WearNotifier {
  private static started: boolean = false;

  static start(): void {
    if (WearNotifier.started) {
      return;
    }
    WearNotifier.started = true;
    CheckService.onRiskyCheck((o: CheckOutcome) => {
      WearNotifier.riskyCheck(o);
    });
  }

  static riskyCheck(o: CheckOutcome): void {
    const name: string = o.verdict.ingredient === '' ? o.verdict.query : o.verdict.ingredient;
    const text: string = o.combo.kind !== 'NONE' ? o.combo.reason :
      `${name} has a known risk for long QT. Don't take it before asking your doctor.`;
    log.info(`wrist alert (watch not connected - phone fallback): ${name}`);
    pulse(300);
    notify(NOTIFY_RISKY_CHECK, `Careful with ${name}`, text, false);
    // The watch is told only when the user confirms they took it ("I took it", drugs/DrugIntake.ets): checking a
    // medicine is not taking it, and a check alone must not tighten the watch's limits for 72 h.
  }

  static vitalsAlert(a: VitalsAlert): void {
    if (a.severity === 'INFO') {
      return; // shown on the Heart tab only - no buzz, no notification
    }
    log.info(`wrist alert (watch not connected - phone fallback): ${a.kind}`);
    pulse(a.severity === 'CRITICAL' ? 600 : 250);
    notify(NOTIFY_ALERT, a.severity === 'CRITICAL' ? 'Heart alert' : 'Heart notice', a.message, false);
  }
}
