// Motion switches (DESIGN.md §8). When `reduced` is true, looping animations drop to static.
//
// Where the flag comes from:
// - API 23+: the system "reduce animations" accessibility setting (accessibility.isAnimationReduceEnabledSync and
//   its change callback).
// - API 20-22 (our minimum is 20): no reduce-motion query exists. The closest setting is the animation duration
//   scale (settings.display.ANIMATOR_DURATION_SCALE); 0 means "animations off" and is treated as reduced.
// Motion.start() is called once from the agent home; until then the flag is false.

import { common } from '@kit.AbilityKit';
import { accessibility } from '@kit.AccessibilityKit';
import { deviceInfo, settings } from '@kit.BasicServicesKit';
import { Listener, Listeners } from './Listeners';
import { Logger } from './Logger';

const log: Logger = new Logger('Motion');
const REDUCE_API: number = 23;

export class Motion {
  static reduced: boolean = false;
  static readonly BREATH_MS: number = 2000;   // one half of the 4 s breathing cycle
  static readonly REVEAL_MS: number = 240;
  static readonly BEAT_MS: number = 1100;
  private static started: boolean = false;
  private static listeners: Listeners<boolean> = new Listeners<boolean>();

  // Reads the system setting and keeps `reduced` in step with it. Safe to call more than once.
  static start(ctx: common.UIAbilityContext): void {
    if (Motion.started) {
      return;
    }
    Motion.started = true;
    if (deviceInfo.sdkApiVersion >= REDUCE_API) {
      try {
        Motion.set(accessibility.isAnimationReduceEnabledSync());
        accessibility.onAnimationReduceStateChange((on: boolean) => {
          Motion.set(on);
        });
        return;
      } catch (e) {
        log.warn(`reduce-animation setting unavailable: ${JSON.stringify(e)}`);
      }
    }
    try {
      Motion.set(Motion.scaleIsZero(ctx));
      settings.registerKeyObserver(ctx, settings.display.ANIMATOR_DURATION_SCALE, settings.domainName.DEVICE_SHARED,
        () => {
          Motion.set(Motion.scaleIsZero(ctx));
        });
    } catch (e) {
      log.warn(`animation scale unavailable: ${JSON.stringify(e)}`);
    }
  }

  // Components with loops listen here so they go static when the setting changes while they are on screen.
  static onChange(cb: Listener<boolean>): () => void {
    return Motion.listeners.add(cb);
  }

  private static scaleIsZero(ctx: common.UIAbilityContext): boolean {
    const raw: string = settings.getValueSync(ctx, settings.display.ANIMATOR_DURATION_SCALE, '1');
    const scale: number = Number.parseFloat(raw);
    return !Number.isNaN(scale) && scale === 0;
  }

  private static set(reduced: boolean): void {
    if (Motion.reduced !== reduced) {
      Motion.reduced = reduced;
      log.info(`reduced motion: ${reduced}`);
      Motion.listeners.emit(reduced);
    }
  }
}
