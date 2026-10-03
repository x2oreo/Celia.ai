// Push Kit token (B12, docs/research/push-kit.md): fetched on every launch, stored on the phone, and uploaded to
// `push_tokens` under the signed-in account so the `sos` function can push "SOS from your watch" to this phone.
//
// Built, unverified: Push Kit on phones works only in the Chinese mainland and needs an AGC project with Push Kit
// enabled and a signing profile that carries it. Elsewhere getToken() fails (e.g. 1000900010 illegal app identity,
// 1000900013 cross-location), which is logged and ignored: the app keeps polling the watch while it is open.
// The token is a device identifier, not personal data; the upload goes through common/Net.ets and the ledger.

import { pushService } from '@kit.PushKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';
import { LocalStore } from '../data/LocalStore';
import { deleteJson, NetResult, shareTarget, upsertJson } from '../common/Net';
import { needsPushUpload, pushUploadKey } from '../common/NotifyAction';
import { Session } from './Session';

const log: Logger = new Logger('PushToken');
const KEY_TOKEN: string = 'push_token';
const KEY_UPLOADED: string = 'push_token_uploaded';   // "<userId>:<token>" last stored on the server
const TIMEOUT_MS: number = 8000;

export class PushToken {
  private static started: boolean = false;

  // Once per launch (after LocalStore.init). The docs ask not to request tokens more often than that.
  static start(): void {
    if (PushToken.started) {
      return;
    }
    PushToken.started = true;
    PushToken.sync();
    Session.onChange((signedIn: boolean) => {
      if (signedIn) {
        PushToken.sync();
      }
    });
  }

  static async fetch(): Promise<string> {
    try {
      return await pushService.getToken();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      log.info(`push token unavailable: ${err.code} ${err.message}`);
      return '';
    }
  }

  static async sync(): Promise<void> {
    const token: string = await PushToken.fetch();
    if (token === '') {
      return;
    }
    await LocalStore.get().setSetting(KEY_TOKEN, token);
    const uploaded: string = await LocalStore.get().getSetting(KEY_UPLOADED, '');
    if (!needsPushUpload(Session.isSignedIn(), Session.userId(), token, uploaded)) {
      return;
    }
    const fields: Record<string, string> = {};
    fields['user_id'] = Session.userId();
    fields['token'] = token;
    fields['platform'] = 'harmonyos';
    const res: NetResult = await upsertJson('/rest/v1/push_tokens', fields, TIMEOUT_MS, shareTarget());
    if (res.ok) {
      await LocalStore.get().setSetting(KEY_UPLOADED, pushUploadKey(Session.userId(), token));
      log.info('push token stored under the account');
    } else {
      log.warn(`push token upload failed: ${res.status}`);
    }
  }

  // Call before signing out (the row can only be deleted with the user's token). Keeps the token on the phone;
  // pushService.deleteToken() would also wipe Push Kit's data for the app, so it is not called here.
  static async forget(): Promise<void> {
    const token: string = await LocalStore.get().getSetting(KEY_TOKEN, '');
    if (token !== '' && Session.isSignedIn()) {
      await deleteJson(`/rest/v1/push_tokens?token=eq.${encodeURIComponent(token)}`, {}, TIMEOUT_MS, shareTarget());
    }
    await LocalStore.get().setSetting(KEY_UPLOADED, '');
  }
}
