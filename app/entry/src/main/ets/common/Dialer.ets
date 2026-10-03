// Opens the phone dialer with a number filled in. The user confirms the call — no CALL permission needed.

import { call } from '@kit.TelephonyKit';
import { Logger } from './Logger';

const log: Logger = new Logger('Dialer');

export async function dial(number: string): Promise<boolean> {
  const clean: string = number.replace(/[^0-9+]/g, '');
  if (clean.length === 0) {
    return false;
  }
  try {
    await call.makeCall(clean);
    return true;
  } catch (e) {
    log.error(`makeCall failed: ${JSON.stringify(e)}`);
    return false;
  }
}
