// Haptic pulses. Preferred over sounds: sudden loud sounds are a known LQT2 trigger (F-39, F-47).

import { vibrator } from '@kit.SensorServiceKit';
import { Logger } from './Logger';

const log: Logger = new Logger('Haptics');

export async function pulse(ms: number): Promise<void> {
  try {
    const effect: vibrator.VibrateTime = { type: 'time', duration: ms };
    const attr: vibrator.VibrateAttribute = { id: 0, usage: 'alarm' };
    await vibrator.startVibration(effect, attr);
  } catch (e) {
    log.warn(`vibration unavailable: ${JSON.stringify(e)}`);
  }
}

export async function stopPulse(): Promise<void> {
  try {
    await vibrator.stopVibration();
  } catch (e) {
    log.warn(`stopVibration failed: ${JSON.stringify(e)}`);
  }
}
