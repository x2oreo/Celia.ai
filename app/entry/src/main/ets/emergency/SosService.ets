// SOS side effects (F-28): location, the message for contacts, share sheet, logging.
//
// Direct SMS sending needs ohos.permission.SEND_MESSAGES, which is reserved for system apps, so the message is
// handed to the system share sheet (SMS, messengers, e-mail) and calls go through the dialer. Both work on any
// phone without special permissions. Location is optional: SOS works without it.

import { abilityAccessCtrl, bundleManager, common, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { LocalStore } from '../data/LocalStore';
import { GeoPoint, SosEvent } from './SosMessage';
import { Logger } from '../common/Logger';
import { shareText } from '../common/Share';

const log: Logger = new Logger('Sos');

const LOCATION_PERMISSIONS: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];

export class SosService {
  static locationGranted(): boolean {
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      return atManager.checkAccessTokenSync(info.appInfo.accessTokenId, 'ohos.permission.APPROXIMATELY_LOCATION') ===
        abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (e) {
      return false;
    }
  }

  // Asked once, at the end of onboarding. Returns true when at least approximate location is allowed.
  static async askLocationPermission(ctx: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(ctx, LOCATION_PERMISSIONS);
      return result.authResults.some((r: number) => r === 0);
    } catch (e) {
      log.warn(`permission request failed: ${JSON.stringify(e)}`);
      return false;
    }
  }

  // During SOS: no new dialogs - a decision already made returns at once; never asked → no location.
  static async requestLocation(ctx: common.UIAbilityContext): Promise<GeoPoint | undefined> {
    try {
      if (!SosService.locationGranted()) {
        log.info('location not granted - SOS continues without it');
        return undefined;
      }
      const request: geoLocationManager.SingleLocationRequest = {
        locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
        locatingTimeoutMs: 8000
      };
      const loc: geoLocationManager.Location = await geoLocationManager.getCurrentLocation(request);
      return new GeoPoint(loc.latitude, loc.longitude);
    } catch (e) {
      log.warn(`location unavailable: ${JSON.stringify(e)}`);
      return undefined;
    }
  }

  static async share(ctx: common.UIAbilityContext, text: string): Promise<boolean> {
    return shareText(ctx, 'SOS', text);
  }

  static async log(event: SosEvent): Promise<void> {
    await LocalStore.get().logEvent('SOS', JSON.stringify(event));
  }
}
