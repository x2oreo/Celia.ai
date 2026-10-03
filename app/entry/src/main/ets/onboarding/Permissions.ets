// Runtime permissions asked in the onboarding permissions step (B3 step 7), one at a time, on tap.
// APIs checked against the API 20 SDK declarations: abilityAccessCtrl.checkAccessToken / requestPermissionsFromUser
// (since 11), notificationManager.isNotificationEnabled / requestEnableNotification(context) (since 12).
// requestPermissionOnSetting is API 21, so a refused permission is sent to the system Settings by text instead.

import { abilityAccessCtrl, bundleManager, common, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { askNotificationPermission } from '../common/Notify';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('OnbPermissions');

export type PermKind = 'NOTIFICATIONS' | 'MICROPHONE' | 'LOCATION';

// ASK = not granted yet (never asked, or the system cannot tell us), DENIED = the user said no in the dialog.
export type PermState = 'ASK' | 'GRANTED' | 'DENIED';

export const PERM_KINDS: PermKind[] = ['NOTIFICATIONS', 'MICROPHONE', 'LOCATION'];

// Location: approximate first, precise second (the system needs both in one request; approximate is enough for SOS).
function systemPermissions(kind: PermKind): Permissions[] {
  if (kind === 'MICROPHONE') {
    return ['ohos.permission.MICROPHONE'];
  }
  return ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
}

async function tokenId(): Promise<number> {
  const info: bundleManager.BundleInfo =
    await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
  return info.appInfo.accessTokenId;
}

export async function permissionState(kind: PermKind): Promise<PermState> {
  try {
    if (kind === 'NOTIFICATIONS') {
      return (await notificationManager.isNotificationEnabled()) ? 'GRANTED' : 'ASK';
    }
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const status: abilityAccessCtrl.GrantStatus =
      await atManager.checkAccessToken(await tokenId(), systemPermissions(kind)[0]);
    return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED ? 'GRANTED' : 'ASK';
  } catch (e) {
    log.warn(`check ${kind}: ${JSON.stringify(e)}`);
    return 'ASK';
  }
}

export async function requestPermission(ctx: common.UIAbilityContext, kind: PermKind): Promise<PermState> {
  try {
    if (kind === 'NOTIFICATIONS') {
      await askNotificationPermission(ctx);
      return (await notificationManager.isNotificationEnabled()) ? 'GRANTED' : 'DENIED';
    }
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(ctx, systemPermissions(kind));
    return result.authResults.length > 0 && result.authResults[0] === 0 ? 'GRANTED' : 'DENIED';
  } catch (e) {
    log.warn(`request ${kind}: ${JSON.stringify(e)}`);
    return 'DENIED';
  }
}
