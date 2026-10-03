// App lock (F-45): optional face / fingerprint / PIN gate over the app's private data (meds, history, events).
// The emergency card and bystander help stay reachable from the lock screen — they are meant for strangers.
// Data at rest is already encrypted (RDB encrypt: true, data/LocalStore.ets).

import { userAuth } from '@kit.UserAuthenticationKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { Listener, Listeners } from './Listeners';
import { LocalStore } from '../data/LocalStore';
import { Logger } from './Logger';

const log: Logger = new Logger('AppLock');
const SETTING_KEY: string = 'appLock';
export const RELOCK_AFTER_MS: number = 5 * 60 * 1000;

export type LockState = 'UNLOCKED' | 'LOCKED' | 'EMERGENCY_ONLY';

export class AppLock {
  private static enabled: boolean = false;
  private static state: LockState = 'UNLOCKED';
  private static backgroundSince: number = -1;
  private static listeners: Listeners<boolean> = new Listeners<boolean>();

  // Called at startup (EntryAbility.onCreate): lock immediately when the user turned the lock on.
  static async init(): Promise<void> {
    AppLock.enabled = (await LocalStore.get().getSetting(SETTING_KEY, 'off')) === 'on' && AppLock.available();
    AppLock.set(AppLock.enabled ? 'LOCKED' : 'UNLOCKED');
  }

  static isEnabled(): boolean {
    return AppLock.enabled;
  }

  static isLocked(): boolean {
    return AppLock.state === 'LOCKED';
  }

  static onLockChange(cb: Listener<boolean>): () => void {
    return AppLock.listeners.add(cb);
  }

  // True when the phone has a screen lock (PIN at least) that can verify the user.
  static available(): boolean {
    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.PIN, userAuth.AuthTrustLevel.ATL1);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Only offer methods the user actually set up (asking for an unenrolled face/fingerprint fails the request).
  private static availableTypes(): userAuth.UserAuthType[] {
    const all: userAuth.UserAuthType[] = [userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT,
      userAuth.UserAuthType.PIN];
    return all.filter((t: userAuth.UserAuthType) => {
      try {
        userAuth.getAvailableStatus(t, userAuth.AuthTrustLevel.ATL1);
        return true;
      } catch (e) {
        return false;
      }
    });
  }

  // Returns false (and stays off) when the phone has no screen lock to verify with.
  static async setEnabled(on: boolean): Promise<boolean> {
    if (on && !AppLock.available()) {
      return false;
    }
    AppLock.enabled = on;
    await LocalStore.get().setSetting(SETTING_KEY, on ? 'on' : 'off');
    return true;
  }

  static onBackground(now: number): void {
    AppLock.backgroundSince = now;
  }

  static onForeground(now: number): void {
    if (AppLock.enabled && AppLock.backgroundSince >= 0 && now - AppLock.backgroundSince >= RELOCK_AFTER_MS) {
      AppLock.set('LOCKED');
    }
    AppLock.backgroundSince = -1;
  }

  // Lock screen → "Help / emergency card": hide the lock while the emergency page is open.
  static allowEmergency(): void {
    if (AppLock.state === 'LOCKED') {
      AppLock.set('EMERGENCY_ONLY');
    }
  }

  // Emergency page closed → lock again if it was opened from the lock screen.
  static endEmergency(): void {
    if (AppLock.state === 'EMERGENCY_ONLY') {
      AppLock.set('LOCKED');
    }
  }

  static unlock(onDone: (ok: boolean) => void): void {
    if (!AppLock.available()) {
      // The screen lock was removed: never lock the user out of their own data.
      log.warn('no screen lock on the device — unlocking');
      AppLock.set('UNLOCKED');
      onDone(true);
      return;
    }
    try {
      const challenge: Uint8Array = cryptoFramework.createRandom().generateRandomSync(16).data;
      const authParam: userAuth.AuthParam = {
        challenge: challenge,
        authType: AppLock.availableTypes(),
        authTrustLevel: userAuth.AuthTrustLevel.ATL1
      };
      const widgetParam: userAuth.WidgetParam = { title: 'Unlock Celia.ai' };
      const auth: userAuth.UserAuthInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
      auth.on('result', {
        onResult: (result: userAuth.UserAuthResult) => {
          const ok: boolean = result.result === userAuth.UserAuthResultCode.SUCCESS;
          if (ok) {
            AppLock.set('UNLOCKED');
          }
          onDone(ok);
        }
      });
      auth.start();
    } catch (e) {
      // No screen lock / biometrics set up on the device: do not lock the user out of their own data.
      log.warn(`user auth unavailable: ${JSON.stringify(e)}`);
      AppLock.set('UNLOCKED');
      onDone(true);
    }
  }

  private static set(s: LockState): void {
    AppLock.state = s;
    AppLock.listeners.emit(s === 'LOCKED');
  }
}
