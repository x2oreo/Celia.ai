import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';

export interface Fix {
  lat: number;
  lon: number;
  accuracyM: number;
}

/** Must finish inside the 10 s SOS countdown. */
const TIMEOUT_MS = 8000;

/**
 * One-shot position for an SOS row. Resolves undefined on denial, timeout or no location service, so the SOS is
 * never delayed or blocked by location.
 */
export async function currentFix(): Promise<Fix | undefined> {
  try {
    const request: geoLocationManager.SingleLocationRequest = {
      locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
      locatingTimeoutMs: TIMEOUT_MS
    };
    const loc = await geoLocationManager.getCurrentLocation(request);
    const fix: Fix = { lat: loc.latitude, lon: loc.longitude, accuracyM: Math.round(loc.accuracy) };
    return fix;
  } catch (e) {
    Logger.warn(`SOS location unavailable: ${(e as BusinessError).code}`);
    return undefined;
  }
}
