# Push Kit (B12): server-sent alerts to the phone

Research for brief task B12, written so stream S4 can implement without re-reading the Huawei docs. Researched
2026-10-03 against the official HarmonyOS guides (EN, pulled from developer.huawei.com) and the local SDK typings
(DevEco Studio 6.1.1, API 24, `hms/ets/api/@hms.core.push.pushService.d.ts`).

## Verdict

| Question | Answer |
|---|---|
| Can a phone in Poland receive our pushes? | **No.** Push Kit on phones, tablets and PCs is "available only in the Chinese mainland, and the data processing location is fixed to China" ([push-config-setting], [push-country]). |
| Does it run on the emulator? | Yes for notification, badge, widget and background messages. Not for live view, in-app call or text-to-speech messages ([push-kit-introduction] → Emulator Support). Whether the emulator gets a token outside China is unverified; one `getToken()` call answers it. |
| Watch? | Wearables are supported in ~190 countries **including Poland**, but "only when they are used independently with Internet access. They are not supported when they are connected to phones" ([push-kit-introduction] → Supported Devices). Our watch app already talks HTTPS by itself, so a cloud → watch push is the one Push path that fits our region. |
| Server auth | **JWT signed with a service-account key** (PS256). "HarmonyOS 5 and later versions no longer support OAuth 2.0-based authentication" ([push-scenariozed-api-request-struct]). The brief's "OAuth client credentials" step is out of date; do not build it. |
| `client_id` in `module.json5`? | **Not needed for Push Kit.** "Since HarmonyOS NEXT Developer Beta2, you no longer need to configure the public key fingerprint and client ID" ([push-config-setting]). Account Kit still needs it in some cases (see `account-kit.md`). |
| Approval needed | Push Kit itself: no review, just enable. For more than 2 messages per device per day in production: the "self-classification" permission (3 working days). Test messages (`testMessage: true`) skip that: 1000 per project per day. |

What this means for the demo: the watch SOS reaches contacts through the existing `sos` function (Twilio) and the
phone through polling `watch_metrics` every 2 s while the app is open (`vitals/WatchCloudSource.ets`, `POLL_MS`).
Push would wake a phone in the background, but only a Chinese-mainland phone. Build the client and server parts so
they work the moment a supported device and AGC project exist, label them "built, unverified", and say why.

## How it works

```
phone app ── pushService.getToken() ──► push token
          ── POST /rest/v1/push_tokens (user JWT, RLS) ──► Supabase

watch inserts watch_metrics{type:'sos'}
  → trigger → sos Edge Function (exists)
      ├─ Twilio SMS + call to contacts (exists)
      └─ NEW: look up the patient's push tokens → POST push-api.cloud.huawei.com/v3/<projectId>/messages:send
                                                   Authorization: Bearer <service-account JWT>
  → Push Kit → notification on the phone → tap opens the SOS page in "sent by watch" state
```

## AGC steps (one-time, a person with the AGC account does these)

1. AppGallery Connect → **Development and services** → create a project, add a HarmonyOS app with bundle name
   `com.celiaai.app` (from `app/AppScope/app.json5`). This gives the **project ID** (Project settings) and the
   **app ID / client ID** (General information).
2. **Grow → Push Kit → Enable now.** If asked for a data processing location: phones only work with China.
   "If the data processing location is different from your server location, or is different from the location of
   users that the app serves, push messages will fail to be sent" ([push-config-setting]).
3. Signing. Either:
   - DevEco Studio → File → Project Structure → Signing Configs → **Enable open capabilities** → tick Push Kit →
     automatic signing (DevEco 6.0.0 Beta5+); wait 5-10 min and check AGC → Project settings → Manage open
     capabilities shows Push Kit, or
   - manual: debug certificate, register the device, enable Push Kit, new debug profile, sign.
   The signing hunk in `app/build-profile.json5` stays out of git (`docs/REAL_DEVICE.md` §2).
4. Server key: [HUAWEI Developers API Console](https://developer.huawei.com/consumer/en/console/api/myApi) → select
   the project → create a **service account key** → download the JSON (`project_id`, `key_id`, `private_key`,
   `sub_account`, …). `project_id` must equal the AGC project ID. This file is a secret: never commit it.
5. Optional, production only: Grow → Push Kit → Settings → **Self-classification → Apply** (3 working days). None of
   the categories is "emergency". The closest are `DEVICE_REMINDER` ("Notifications sent from IoT devices to inform
   users of the device status, information, warnings, alarms") and `HEALTH` ("health data that users proactively
   request measurement", fitness/health apps only). Without it, messages count as `MARKETING`: 2 per device per day
   for "Health & fitness" ([push-apply-right]). For the hackathon, send `testMessage: true`.

## Client (phone) — what S4 writes

No `module.json5` metadata is needed. Notification permission must be granted first (S3's onboarding asks; the
existing `notificationManager.requestEnableNotification` path in `common/Notify.ets` also works).

`account/PushToken.ets` (new, S4):

```ts
import { pushService } from '@kit.PushKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('PushToken');

/** Returns the push token, or '' when Push Kit is unavailable (emulator outside China, no AGC config, …). */
export async function fetchPushToken(): Promise<string> {
  try {
    return await pushService.getToken();
  } catch (e) {
    const err: BusinessError = e as BusinessError;
    // 1000900010 = app authentication failed: Push Kit not enabled / app not signed with an AGC profile.
    log.info(`push token unavailable: ${err.code} ${err.message}`);
    return '';
  }
}
```

- Call it in `EntryAbility.onCreate` (docs' recommendation: on every launch, "Do not request push tokens frequently")
  and after sign-in. If it differs from the stored value (`LocalStore` setting `push_token`), upsert it to the server.
- The token can change on reinstall, factory reset, `deleteToken`, or region change. `pushService.on('tokenUpdate',
  this, cb)` exists, but on phones only from 6.1.0(23); our minimum is API 20, so guard it with
  `canIUse('SystemCapability.Push.PushService')` plus an API-level check, or skip it and rely on the launch check.
- On sign-out: delete the row on the server. Do not call `pushService.deleteToken()` unless the user deletes their
  data ("all historical Push Kit data of the app will also be deleted").
- Do not validate the token length ("it is variable") and do not use the token as a user identifier.
- Ledger: the upload is a request like any other; log it in `privacy/Ledger.ets` (the token is a device identifier,
  not a name/phone, so it passes `FORBIDDEN_FIELDS`).

Tapping the notification. `clickAction.actionType: 0` opens the home ability. Our `EntryAbility` skill uses
`"action.system.home"`; the push doc notes this "is for versions earlier than API 19 and has been discarded" and
shows `"ohos.want.action.home"`. Keep both actions in that skill (the doc also says the home skill must have no
`uris`, or "devices will fail to receive messages"). To open the SOS page directly, send `actionType: 0` with
`clickAction.data: {"route":"sos","source":"watch"}`. The data arrives in `want.parameters` in
`onCreate`/`onNewWant`, so `EntryAbility.ets` can route it the same way as `handleCardTap`. `actionType: 1` with a
custom action needs a second skill object; not worth it here.

## Storing the token under the account

Migration (S4's range, `2026100411xxxx`):

```sql
create table public.push_tokens (
  user_id    uuid not null references auth.users on delete cascade,
  token      text not null check (char_length(token) between 16 and 512),
  platform   text not null default 'harmonyos',
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);
alter table public.push_tokens enable row level security;
create policy "own tokens select" on public.push_tokens for select to authenticated using (auth.uid() = user_id);
create policy "own tokens insert" on public.push_tokens for insert to authenticated with check (auth.uid() = user_id);
create policy "own tokens update" on public.push_tokens for update to authenticated using (auth.uid() = user_id);
create policy "own tokens delete" on public.push_tokens for delete to authenticated using (auth.uid() = user_id);
```

The phone upserts with `POST /rest/v1/push_tokens` and the headers `Prefer: resolution=merge-duplicates` and
`Authorization: Bearer <access token>` (S1's `Session.accessToken()` via `common/Net.ets`). The `sos` function
reads it with the service role. **Dependency:** the `sos` function knows a `device_id`, not a user. Mapping watch →
user needs B9's device ↔ account binding (`watch_pairings` + `auth.uid()`). Until B9 lands, there is no safe way
to find whose phone to push to. Do not add an anon-writable token table keyed by device id: it repeats the RLS hole.

## Server — sending from an Edge Function

Secrets (set by the coordinator, never in git): `HUAWEI_PUSH_PROJECT_ID`, `HUAWEI_PUSH_SA_KEY` (the whole
service-account JSON as one string).

`backend/supabase/functions/sos/huaweiPush.ts` (new, next to `twilio.ts`, same style: plain fetch, no SDK):

```ts
import { importPKCS8, SignJWT } from 'npm:jose@5';

const AUD = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token';
const TIMEOUT_MS = 10_000;

export interface PushConfig { projectId: string; keyId: string; subAccount: string; privateKey: string }

/** Null when either secret is missing: the caller then records "push: dry_run". */
export function pushConfigFromEnv(get: (k: string) => string | undefined): PushConfig | null {
  const projectId = get('HUAWEI_PUSH_PROJECT_ID');
  const raw = get('HUAWEI_PUSH_SA_KEY');
  if (!projectId || !raw) return null;
  const k = JSON.parse(raw) as { key_id?: string; sub_account?: string; private_key?: string };
  if (!k.key_id || !k.sub_account || !k.private_key) return null;
  return { projectId, keyId: k.key_id, subAccount: k.sub_account, privateKey: k.private_key };
}

/** Service-account JWT, valid 1 h ("a JWT can be reused" within that time). */
export async function pushJwt(cfg: PushConfig): Promise<string> {
  const key = await importPKCS8(cfg.privateKey, 'PS256');
  return await new SignJWT({})
    .setProtectedHeader({ alg: 'PS256', kid: cfg.keyId, typ: 'JWT' })
    .setIssuer(cfg.subAccount)
    .setAudience(AUD)
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);
}

export async function sendPush(cfg: PushConfig, tokens: string[], title: string, body: string):
    Promise<{ ok: boolean; detail: string }> {
  const message = {
    payload: {
      notification: {
        category: 'MARKETING',              // until self-classification is approved; see AGC step 5
        title, body,
        clickAction: { actionType: 0, data: { route: 'sos', source: 'watch' } },
        foregroundShow: true,
        notifyId: 1001,                     // same id as NOTIFY_SOS so a newer alert replaces the older one
      },
    },
    target: { token: tokens.slice(0, 10) }, // max 10 tokens per request for test messages
    pushOptions: { testMessage: true, ttl: 600 },
  };
  try {
    const res = await fetch(`https://push-api.cloud.huawei.com/v3/${cfg.projectId}/messages:send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${await pushJwt(cfg)}`,
        'push-type': '0',                   // 0 = notification (alert) message
      },
      body: JSON.stringify(message),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    const json = await res.json().catch(() => ({})) as { code?: string; msg?: string };
    return { ok: json.code === '80000000', detail: `${json.code ?? res.status} ${json.msg ?? ''}` };
  } catch (e) {
    return { ok: false, detail: e instanceof Error ? e.message : String(e) };
  }
}
```

- Tested in Deno with jose 5.10 (2026-10-03, scratch copy of this block): config returns null on missing/empty
  key JSON; the JWT header is `{alg:'PS256', kid, typ:'JWT'}`, `iss` = `sub_account`, `aud` = the token URL,
  `exp - iat = 3600`, and it verifies with the matching public key. Not sent to Huawei (no key).
- Success is response code `80000000`. `80300007` = all tokens invalid (delete them). `80300008` = body over 4096
  bytes. Full list: [push-scenariozed-api-response].
- `title`/`body` come from the deterministic `buildSosMessage` (no LLM), shortened: e.g. title "Celia SOS from your
  watch", body = `message.sms` cut to fit. No location link in the push; the app shows it.
- Wire it in `sos/index.ts` after the Twilio step and record `push: {ok, detail}` in the `sos_dispatches.detail`
  JSON. A push failure never changes the SOS status.
- Deno test (no network): `pushConfigFromEnv` returns null on missing or bad JSON; `pushJwt` with a throwaway RSA
  key produces a JWT whose header is `{alg:'PS256', kid, typ:'JWT'}` and whose payload has `iss`, `aud`, `iat`,
  `exp = iat + 3600`.
- `jose` is a third-party dependency: list it in README + `AI_WORKFLOW.md` (Challenge Rules §4).

## Emulator vs real phone

| Step | Emulator (`127.0.0.1:5555`) | Real phone |
|---|---|---|
| `getToken()` | Supported by the kit; needs the app signed with an AGC profile that has Push Kit. Outside China, unverified | Chinese-mainland phone + HUAWEI ID only |
| Notification message | Supported | Supported (China) |
| Live view / in-app call / text-to-speech message | **Not supported** | China, plus each permission |
| Cloud-hosted real devices | Not supported for Push Kit | — |
| Firewall | Device must reach ports 5223 and 443 | same |

Test steps once a token exists: launch the app → `hdc shell hilog -x | grep PushToken` shows no error → row in
`push_tokens` → insert a simulated `sos` row (`backend/supabase/functions/sos/README.md` "Manual end-to-end") →
notification appears, tap opens the SOS page → `sos_dispatches.detail.push.ok = true`.

## Possible alternative for the watch (Poland)

Push Kit supports standalone wearables in Poland (5.1.0(18)+, `getToken` and notification messages). A server →
watch push ("Your contacts were alerted", or a risky drug just scanned on the phone) would replace polling on the
watch. Needs the same AGC project, a real network-connected watch (Push Kit on the wearable emulator is
untested), and S6's watch app signed with that profile. Not started; noted for S6.

## Needs

- **AGC account** with a project for `com.celiaai.app` (none exists in the repo; no `agconnect-services.json`).
- **Push Kit enabled** on that project with data location China (phones), or any listed region (wearables).
- **Service-account key JSON** from the API Console → Supabase secrets `HUAWEI_PUSH_PROJECT_ID`,
  `HUAWEI_PUSH_SA_KEY`.
- **A Chinese-mainland HarmonyOS phone** signed in with a HUAWEI ID to receive phone pushes. The event phone
  (Sunday 08:00) is the only chance to check its region.
- **B9 device ↔ account binding**, to know whose tokens belong to a watch.
- Optional: self-classification approval (3 working days) for production volumes.

## Sources

- [push-config-setting] Enabling Push Kit — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/push-config-setting
- [push-kit-introduction] About This Kit (regions, devices, emulator, limits) — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/push-kit-introduction
- [push-country] Supported Countries/Regions — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/push-country
- [push-get-token] Obtaining a Push Token — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/push-get-token
- [push-send-alert] Sending a Notification Message — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/push-send-alert
- [push-apply-right] Scenario-Specific Message Permissions, categories, frequency limits — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/push-apply-right
- [push-jwt-token] Generating a JWT Based on a Service Account — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/push-jwt-token
- [push-scenariozed-api-request-struct] Request structure (JWT only) — https://developer.huawei.com/consumer/en/doc/harmonyos-references/push-scenariozed-api-request-struct
- [push-scenariozed-api-response] Response codes — https://developer.huawei.com/consumer/en/doc/harmonyos-references/push-scenariozed-api-response
- `pushService` reference — https://developer.huawei.com/consumer/en/doc/harmonyos-references/push-pushservice
- Sample — https://gitcode.com/harmonyos_samples/push-kit-sample-code-clientdemo-arkts
