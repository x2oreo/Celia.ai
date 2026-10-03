// Travel mode (T23, F-40): when the phone is in another country than the one in Settings, the app says so once
// and switches the pharmacy card language and emergency number. Only runs when location was already allowed
// (never asks); the position is turned into a country code on the device and nothing is uploaded or stored.

import { geoLocationManager } from '@kit.LocationKit';
import { Listener, Listeners } from '../common/Listeners';
import { Logger } from '../common/Logger';
import { SosService } from './SosService';

const log: Logger = new Logger('Travel');

// Pure: the country to announce, or '' when there is nothing to say. Exported for tests.
export function travelCountry(detected: string, home: string): string {
  const d: string = detected.trim().toUpperCase();
  const h: string = home.trim().toUpperCase();
  return d.length === 2 && h.length === 2 && d !== h ? d : '';
}

export class TravelService {
  private static detected: string = '';
  private static listeners: Listeners<string> = new Listeners<string>();

  // ISO 3166-1 alpha-2 of where the phone is now ('' when unknown).
  static current(): string {
    return TravelService.detected;
  }

  static onChange(cb: Listener<string>): () => void {
    return TravelService.listeners.add(cb);
  }

  static async detect(): Promise<void> {
    if (!SosService.locationGranted()) {
      return;
    }
    try {
      if (!geoLocationManager.isGeocoderAvailable()) {
        return;
      }
      const request: geoLocationManager.SingleLocationRequest = {
        locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
        locatingTimeoutMs: 8000
      };
      const loc: geoLocationManager.Location = await geoLocationManager.getCurrentLocation(request);
      const rev: geoLocationManager.ReverseGeoCodeRequest = {
        latitude: loc.latitude, longitude: loc.longitude, maxItems: 1
      };
      const found: geoLocationManager.GeoAddress[] = await geoLocationManager.getAddressesFromLocation(rev);
      const code: string = found.length > 0 ? (found[0].countryCode ?? '') : '';
      if (code.length === 2 && code.toUpperCase() !== TravelService.detected) {
        TravelService.detected = code.toUpperCase();
        TravelService.listeners.emit(TravelService.detected);
      }
    } catch (e) {
      log.info(`travel check skipped: ${JSON.stringify(e)}`);
    }
  }
}
