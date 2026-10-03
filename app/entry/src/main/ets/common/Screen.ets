// Keep the screen on while an emergency screen is open (SOS, bystander, pharmacy card).

import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Logger } from './Logger';

const log: Logger = new Logger('Screen');

export async function keepScreenOn(ctx: common.Context, on: boolean): Promise<void> {
  try {
    const win: window.Window = await window.getLastWindow(ctx);
    await win.setWindowKeepScreenOn(on);
  } catch (e) {
    log.warn(`keepScreenOn(${on}) failed: ${JSON.stringify(e)}`);
  }
}

export async function setBrightness(ctx: common.Context, level: number): Promise<void> {
  try {
    const win: window.Window = await window.getLastWindow(ctx);
    await win.setWindowBrightness(level);   // -1 = follow system
  } catch (e) {
    log.warn(`setBrightness failed: ${JSON.stringify(e)}`);
  }
}
