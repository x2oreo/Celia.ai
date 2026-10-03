// Huawei Push Kit sender for the `sos` function (B12): tells the patient's own phone that the watch sent an SOS, so
// the app opens on the SOS page in its "sent by watch" state even when it was in the background.
// Research and sources: docs/research/push-kit.md. Plain fetch, no SDK, same style as twilio.ts.
//
// Limits we cannot change: Push Kit on phones works only in the Chinese mainland, server auth is a service-account
// JWT (PS256, HarmonyOS 5+ dropped OAuth), and without the self-classification right messages are sent as test
// messages. Without the secrets the caller records `push: { status: 'dry_run' }`.
import { importPKCS8, SignJWT } from 'npm:jose@5';

export const PUSH_AUD = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token';
export const PUSH_SUCCESS = '80000000';
const TIMEOUT_MS = 10_000;
const MAX_TOKENS = 10;          // test messages: at most 10 tokens per request
const WATCH_SOS_NOTIFY_ID = 1004; // NOTIFY_WATCH_SOS in app/entry/src/main/ets/common/NotifyAction.ets

export interface PushConfig {
  projectId: string;
  keyId: string;
  subAccount: string;
  privateKey: string;
}

export interface PushResult {
  status: 'sent' | 'failed' | 'dry_run' | 'no_tokens' | 'no_account_binding';
  detail: string;
}

/** Null when a secret is missing or the key JSON is incomplete. */
export function pushConfigFromEnv(get: (k: string) => string | undefined): PushConfig | null {
  const projectId = get('HUAWEI_PUSH_PROJECT_ID');
  const raw = get('HUAWEI_PUSH_SA_KEY');
  if (!projectId || !raw) {
    return null;
  }
  let k: { key_id?: unknown; sub_account?: unknown; private_key?: unknown };
  try {
    k = JSON.parse(raw);
  } catch {
    return null;
  }
  if (typeof k.key_id !== 'string' || typeof k.sub_account !== 'string' || typeof k.private_key !== 'string' ||
    !k.key_id || !k.sub_account || !k.private_key) {
    return null;
  }
  return { projectId, keyId: k.key_id, subAccount: k.sub_account, privateKey: k.private_key };
}

/** Service-account JWT, valid for one hour. */
export async function pushJwt(cfg: PushConfig): Promise<string> {
  const key = await importPKCS8(cfg.privateKey, 'PS256');
  return await new SignJWT({})
    .setProtectedHeader({ alg: 'PS256', kid: cfg.keyId, typ: 'JWT' })
    .setIssuer(cfg.subAccount)
    .setAudience(PUSH_AUD)
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);
}

/**
 * The notification message for a watch SOS. Fixed copy, no model text and no location (the app shows that).
 * `clickAction.data` arrives in the app's want parameters (EntryAbility → parsePushTap).
 */
export function watchSosPush(tokens: string[], hasLocation: boolean, at: string): Record<string, unknown> {
  return {
    payload: {
      notification: {
        category: 'MARKETING', // until the self-classification right is granted (push-kit.md, AGC step 5)
        title: 'SOS from your watch',
        body: 'Your watch asked for help. Open Celia to call the ambulance and your contacts.',
        clickAction: {
          actionType: 0,
          data: { route: 'sos', source: 'watch', loc: hasLocation ? '1' : '0', at },
        },
        foregroundShow: true,
        notifyId: WATCH_SOS_NOTIFY_ID,
      },
    },
    target: { token: tokens.slice(0, MAX_TOKENS) },
    pushOptions: { testMessage: true, ttl: 600 },
  };
}

export async function sendPush(cfg: PushConfig, message: Record<string, unknown>): Promise<PushResult> {
  try {
    const res = await fetch(`https://push-api.cloud.huawei.com/v3/${cfg.projectId}/messages:send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${await pushJwt(cfg)}`,
        'push-type': '0', // notification message
      },
      body: JSON.stringify(message),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    const body = await res.json().catch(() => ({})) as { code?: string; msg?: string };
    const ok = body.code === PUSH_SUCCESS;
    return { status: ok ? 'sent' : 'failed', detail: `${body.code ?? res.status} ${body.msg ?? ''}`.trim() };
  } catch (e) {
    return { status: 'failed', detail: e instanceof Error ? e.message : String(e) };
  }
}
