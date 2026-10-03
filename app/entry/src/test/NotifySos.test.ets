import { describe, it, expect } from '@ohos/hypium';
import {
  buttonsFor, doseNotifyId, kindForId, NOTIFY_ALERT, NOTIFY_RISKY_CHECK, NOTIFY_SOS, NOTIFY_WATCH_SOS, NotifyButton,
  NotifyTap, parseNotifyTap, requestCodeFor, slotFor, targetFor
} from '../main/ets/common/NotifyAction';
import { SosController } from '../main/ets/emergency/SosController';
import { DoseLog, DoseReminder, takeableFromNotification } from '../main/ets/reminders/DoseSchedule';
import { MetricRow, WatchCloudSource } from '../main/ets/vitals/WatchCloudSource';
import { VitalsAlert } from '../main/ets/model/Vitals';

function labels(id: number): string {
  return buttonsFor(id).map((b: NotifyButton) => `${b.action}:${b.label}`).join(',');
}

function params(action: string, kind: string, id: number, reminder: number): Record<string, Object> {
  const p: Record<string, Object> = {};
  p['notifyAction'] = action;
  p['notifyKind'] = kind;
  p['notifyId'] = id;
  p['reminderId'] = reminder;
  return p;
}

// A reminder at 08:00 created long before `now`.
function reminder(hour: number): DoseReminder {
  const r: DoseReminder = { id: 1, medId: 1, medName: 'Nadolol', hour: hour, minute: 0, reminderId: -1 };
  return r;
}

function at(hour: number, minute: number): number {
  const d: Date = new Date(2026, 9, 3, hour, minute, 0, 0);
  return d.getTime();
}

export default function notifySosTest() {
  describe('NotifyAction', () => {
    it('kindFollowsTheId', 0, () => {
      expect(kindForId(NOTIFY_SOS)).assertEqual('EMERGENCY');
      expect(kindForId(NOTIFY_WATCH_SOS)).assertEqual('EMERGENCY');
      expect(kindForId(NOTIFY_ALERT)).assertEqual('HEART_ALERT');
      expect(kindForId(doseNotifyId(1759471200123))).assertEqual('DOSE_DUE');
      expect(kindForId(NOTIFY_RISKY_CHECK)).assertEqual('RISKY_CHECK');
    });

    it('emergencyHasItsOwnLoudSlot', 0, () => {
      expect(slotFor('EMERGENCY')).assertEqual('SOCIAL_COMMUNICATION');
      expect(slotFor('HEART_ALERT')).assertEqual('SERVICE_INFORMATION');
      expect(slotFor('DOSE_DUE')).assertEqual('SERVICE_INFORMATION');
      expect(slotFor('RISKY_CHECK')).assertEqual('CONTENT_INFORMATION');
    });

    it('buttonsPerKindAtMostTwo', 0, () => {
      expect(labels(NOTIFY_SOS)).assertEqual('SOS_OK:ntf_btn_im_ok,OPEN:ntf_btn_open');
      expect(labels(NOTIFY_ALERT)).assertEqual('ALERT_OK:ntf_btn_im_ok,OPEN:ntf_btn_open');
      expect(labels(doseNotifyId(5))).assertEqual('DOSE_TAKEN:ntf_btn_taken,OPEN:ntf_btn_open');
      expect(buttonsFor(NOTIFY_WATCH_SOS).length).assertEqual(0);
      expect(buttonsFor(NOTIFY_RISKY_CHECK).length).assertEqual(0);
    });

    it('requestCodesNeverCollide', 0, () => {
      const codes: number[] = [requestCodeFor(NOTIFY_SOS, 'OPEN'), requestCodeFor(NOTIFY_SOS, 'SOS_OK'),
        requestCodeFor(NOTIFY_ALERT, 'OPEN'), requestCodeFor(NOTIFY_ALERT, 'ALERT_OK'),
        requestCodeFor(doseNotifyId(1), 'DOSE_TAKEN'), requestCodeFor(doseNotifyId(2), 'DOSE_TAKEN')];
      expect(new Set<number>(codes).size).assertEqual(codes.length);
    });

    it('parsesOurTapsOnly', 0, () => {
      const t: NotifyTap | undefined = parseNotifyTap(params('DOSE_TAKEN', 'DOSE_DUE', 2005, 42));
      expect(t?.action).assertEqual('DOSE_TAKEN');
      expect(t?.reminderId).assertEqual(42);
      expect(t === undefined ? '' : targetFor(t)).assertEqual('reminders');
      expect(parseNotifyTap(undefined)).assertUndefined();
      expect(parseNotifyTap(params('DELETE_ALL', 'DOSE_DUE', 1, 1))).assertUndefined();
      const widget: Record<string, Object> = {};
      widget['params'] = '{"target":"scan"}';
      expect(parseNotifyTap(widget)).assertUndefined();
    });

    it('targets', 0, () => {
      expect(targetFor(new NotifyTap('ALERT_OK', 'HEART_ALERT', NOTIFY_ALERT, -1))).assertEqual('heart');
      expect(targetFor(new NotifyTap('SOS_OK', 'EMERGENCY', NOTIFY_SOS, -1))).assertEqual('sos');
      expect(targetFor(new NotifyTap('OPEN', 'RISKY_CHECK', NOTIFY_RISKY_CHECK, -1))).assertEqual('history');
    });
  });

  describe('DoseFromNotification', () => {
    it('takesDueOrMissedOnly', 0, () => {
      const none: DoseLog[] = [];
      expect(takeableFromNotification(reminder(8), none, at(8, 10))).assertTrue();    // due
      expect(takeableFromNotification(reminder(8), none, at(11, 0))).assertTrue();    // missed today
      expect(takeableFromNotification(reminder(20), none, at(8, 10))).assertFalse();  // upcoming
    });

    it('neverTwice', 0, () => {
      const taken: DoseLog[] = [{ reminderId: 1, day: '2026-10-03', status: 'TAKEN', ts: at(8, 5) }];
      expect(takeableFromNotification(reminder(8), taken, at(8, 10))).assertFalse();
    });
  });

  describe('SosControllerWatch', () => {
    it('watchSosOpensSentWithoutCountdown', 0, () => {
      const c: SosController = new SosController();
      c.watchSent(5000, true);
      expect(c.state).assertEqual('SENT');
      expect(c.sentBy).assertEqual('WATCH');
      expect(c.sentAt).assertEqual(5000);
      expect(c.watchLocation).assertTrue();
      expect(c.remainingSeconds(5000)).assertEqual(0);
      expect(c.tick(60000)).assertEqual('SENT');
    });

    it('watchSosReplacesARunningPhoneCountdown', 0, () => {
      const c: SosController = new SosController();
      c.start(0, 30, false);
      c.watchSent(4000, false);
      expect(c.tick(5000)).assertEqual('SENT');
      expect(c.sentBy).assertEqual('WATCH');
      // The watch's SOS starts the cooldown, so a vitals alert right after does not open another countdown.
      expect(c.canAutoStart(6000)).assertFalse();
    });

    it('watchSosIsNeverATest', 0, () => {
      const c: SosController = new SosController();
      c.start(0, 10, true);
      c.watchSent(1000, false);
      expect(c.test).assertFalse();
    });

    it('phoneTimeoutIsSentByPhone', 0, () => {
      const c: SosController = new SosController();
      c.start(0, 30, false);
      c.tick(30000);
      expect(c.sentBy).assertEqual('PHONE');
      expect(c.sentAt).assertEqual(30000);
    });

    it('notificationAckDuringCountdown', 0, () => {
      const c: SosController = new SosController();
      c.start(0, 30, false);
      c.ack();
      expect(c.tick(40000)).assertEqual('ACKED');
    });

    it('resetClearsSender', 0, () => {
      const c: SosController = new SosController();
      c.watchSent(1000, true);
      c.reset();
      expect(c.state).assertEqual('IDLE');
      expect(c.sentBy).assertEqual('PHONE');
      expect(c.watchLocation).assertFalse();
      expect(c.inCooldown(2000)).assertTrue();
    });
  });

  describe('WatchSosAlert', () => {
    it('sosRowIsMarkedAsAWatchSos', 0, () => {
      const p: Record<string, Object> = { 'reason': 'fall', 'bpm': 40, 'lat': 52.2, 'lon': 21.0 };
      const r: MetricRow = { id: 7, type: 'sos', payload: p, recorded_at: '2026-10-03T12:00:00.000Z', source: 'watch' };
      const a: VitalsAlert | undefined = WatchCloudSource.toAlert(r);
      expect(a?.severity).assertEqual('CRITICAL');
      expect(a?.watchSos?.reason).assertEqual('fall');
      expect(a?.watchSos?.withLocation).assertTrue();
    });

    it('otherCriticalAlertsAreNot', 0, () => {
      const p: Record<string, Object> = { 'bpm': 165 };
      const r: MetricRow = {
        id: 8, type: 'rhythm_alert', payload: p, recorded_at: '2026-10-03T12:00:00.000Z', source: 'watch'
      };
      expect(WatchCloudSource.toAlert(r)?.watchSos).assertUndefined();
    });
  });
}
