// Live status outside the app (F-35, B13): the SOS countdown on the lock screen and status bar.
//
// Live View Kit when the system allows it: one start call with a countdown timer the system ticks itself, a timer
// capsule, a tap action and a layout (docs/research/live-view.md). It needs a Live View scenario approved in
// AppGallery Connect and, today, a Chinese-mainland device; without approval startLiveView fails with 1003500005 and
// we fall back to an ongoing notification (refreshed every 5 s) with "I'm OK" / "Open" buttons. Built, unverified
// for the Live View path; the fallback is what runs on the emulator.

import { liveViewManager } from '@kit.LiveViewKit';
import { WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { cancelNotify, notify, notifyColor, notifyText, NOTIFY_SOS, NOTIFY_WATCH_SOS, tapAgent } from '../common/Notify';
import { Logger } from '../common/Logger';
import { argbHex, endTitleKey, liveContent, notificationTitle, SosEnd } from './SosLiveText';

const log: Logger = new Logger('LiveStatus');
const LIVE_ID: number = 7001;
const END_KEEP_S: number = 60;
const LIVE_ICON: string = 'sos_live.png';   // resources/rawfile   // how long the ended card stays on the lock screen

export class LiveStatus {
  private static useLiveView: boolean = false;
  private static active: boolean = false;
  private static reason: string = '';

  private static detail(): string {
    return liveContent(LiveStatus.reason, notifyText('ntf_sos_countdown_text'));
  }

  private static async view(seconds: number, title: string, line: string, keep: number):
    Promise<liveViewManager.LiveView> {
    const tap: WantAgent | undefined = await tapAgent(NOTIFY_SOS);
    const colour: number = notifyColor('danger');
    // Pickup layout: a title, one line and a picture (resources/rawfile). The kit checks the payload before the
    // permission and rejects missing pictures with 401 (seen on the emulator: progress needs nodeIcons, pickup
    // needs descPic).
    const layout: liveViewManager.PickupLayout = {
      layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PICKUP,
      title: 'SOS',
      content: line,
      descPic: LIVE_ICON
    };
    const primary: liveViewManager.PrimaryData = {
      title: title,
      content: [{ text: LiveStatus.detail() }],
      keepTime: keep,
      clickAction: tap,
      layoutData: layout
    };
    const capsule: liveViewManager.TimerCapsule = {
      type: liveViewManager.CapsuleType.CAPSULE_TYPE_TIMER,
      status: 1,
      icon: LIVE_ICON,
      content: 'SOS',
      time: seconds * 1000,
      isCountdown: true,
      isPaused: false
    };
    if (colour >= 0) {
      capsule.backgroundColor = argbHex(colour);
    }
    const v: liveViewManager.LiveView = {
      id: LIVE_ID,
      event: 'TIMER',
      isMute: false,
      timer: {
        time: seconds * 1000,
        isCountdown: true,
        isPaused: false,
        countdownPreset: { presetTitle: notifyText('ntf_live_zero') },
        capsuleCountdownPreset: { presetTitle: 'SOS' }
      },
      liveViewData: { primary: primary, capsule: capsule }
    };
    return v;
  }

  static async startSos(seconds: number, reason: string): Promise<void> {
    LiveStatus.active = true;
    LiveStatus.reason = reason;
    try {
      LiveStatus.useLiveView = await liveViewManager.isLiveViewEnabled();
      if (LiveStatus.useLiveView) {
        const view: liveViewManager.LiveView = await LiveStatus.view(seconds, notifyText('ntf_live_title'),
          notifyText('ntf_live_layout'), END_KEEP_S);
        await liveViewManager.startLiveView(view);
        log.info('Live View started');
        return;
      }
      log.info('Live View switched off for this app, using notification');
    } catch (e) {
      // 1003500005 = Live View right not granted (no AGC approval): the expected result on the emulator.
      const err: BusinessError = e as BusinessError;
      log.info(`Live View not available (${err.code} ${err.message}), using notification`);
      LiveStatus.useLiveView = false;
    }
    await LiveStatus.notifyCountdown(seconds);
  }

  private static async notifyCountdown(seconds: number): Promise<void> {
    await notify(NOTIFY_SOS, notificationTitle(notifyText('ntf_live_title'), seconds), LiveStatus.detail(), true);
  }

  // Live View ticks its own timer; only the notification fallback needs refreshing (every 5 s, to keep it cheap).
  static async updateSos(seconds: number): Promise<void> {
    if (!LiveStatus.active || LiveStatus.useLiveView || seconds % 5 !== 0) {
      return;
    }
    await LiveStatus.notifyCountdown(seconds);
  }

  static async end(how: SosEnd = 'CLOSED'): Promise<void> {
    if (!LiveStatus.active) {
      return;
    }
    LiveStatus.active = false;
    try {
      if (LiveStatus.useLiveView) {
        await liveViewManager.stopLiveView(await LiveStatus.view(0, notifyText(endTitleKey(how)),
          notifyText('ntf_live_layout_end'), END_KEEP_S));
      }
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      log.warn(`stop failed: ${err.code} ${err.message}`);
    }
    await cancelNotify(NOTIFY_SOS);
  }

  // The watch already sent its SOS (B8): no countdown, one loud notification that opens the SOS page.
  static async watchSos(): Promise<void> {
    await notify(NOTIFY_WATCH_SOS, notifyText('ntf_watch_sos_title'), notifyText('ntf_watch_sos_text'), false);
  }
}
