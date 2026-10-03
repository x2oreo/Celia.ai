// Live status outside the app (F-35): the SOS countdown on the lock screen / status bar.
// Uses Live View Kit when the system allows it for this app (needs a Live View scenario approved in AppGallery
// Connect); otherwise — e.g. on the emulator — an ongoing notification with the same text. Both open the app on
// tap, where "I'm OK" is one button.

import { liveViewManager } from '@kit.LiveViewKit';
import { cancelNotify, notify, NOTIFY_SOS } from '../common/Notify';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('LiveStatus');
const LIVE_ID: number = 7001;

export class LiveStatus {
  private static useLiveView: boolean = false;
  private static active: boolean = false;
  private static reason: string = '';

  private static view(seconds: number): liveViewManager.LiveView {
    const v: liveViewManager.LiveView = {
      id: LIVE_ID,
      event: 'TIMER',
      liveViewData: {
        primary: {
          title: `SOS in ${seconds} s — tap if you are OK`,
          content: [{ text: LiveStatus.reason.length > 0 ? LiveStatus.reason : 'Emergency contacts will be alerted' }],
          keepTime: 1
        }
      }
    };
    return v;
  }

  static async startSos(seconds: number, reason: string): Promise<void> {
    LiveStatus.active = true;
    LiveStatus.reason = reason;
    try {
      LiveStatus.useLiveView = await liveViewManager.isLiveViewEnabled();
      if (LiveStatus.useLiveView) {
        await liveViewManager.startLiveView(LiveStatus.view(seconds));
        return;
      }
    } catch (e) {
      log.info(`Live View not available, using notification: ${JSON.stringify(e)}`);
      LiveStatus.useLiveView = false;
    }
    await notify(NOTIFY_SOS, `SOS in ${seconds} s — open to say you are OK`, reason, true);
  }

  static async updateSos(seconds: number): Promise<void> {
    if (!LiveStatus.active) {
      return;
    }
    // The notification is refreshed every 5 s to keep it cheap; Live View every second.
    if (!LiveStatus.useLiveView && seconds % 5 !== 0) {
      return;
    }
    try {
      if (LiveStatus.useLiveView) {
        await liveViewManager.updateLiveView(LiveStatus.view(seconds));
      } else {
        await notify(NOTIFY_SOS, `SOS in ${seconds} s — open to say you are OK`, LiveStatus.reason, true);
      }
    } catch (e) {
      log.warn(`update failed: ${JSON.stringify(e)}`);
    }
  }

  static async end(): Promise<void> {
    if (!LiveStatus.active) {
      return;
    }
    LiveStatus.active = false;
    try {
      if (LiveStatus.useLiveView) {
        await liveViewManager.stopLiveView(LiveStatus.view(0));
      }
    } catch (e) {
      log.warn(`stop failed: ${JSON.stringify(e)}`);
    }
    await cancelNotify(NOTIFY_SOS);
  }
}
