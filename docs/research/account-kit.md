# HUAWEI ID sign-in with Account Kit (B18)

Research for brief task B18: HUAWEI ID as a second sign-in method next to S1's Supabase email + password. Written so
S1 (owner of `account/*` and `AuthForm`) or S4 can implement it without re-researching. Researched 2026-10-03 against
the official HarmonyOS guides and references (EN), Huawei's live OIDC discovery document, and the local SDK typings
(DevEco Studio 6.1.1, API 24: `hms/ets/api/@hms.core.authentication.d.ts`, `@hms.core.account.LoginComponent.d.ets`).

## Verdict

| Question | Answer |
|---|---|
| Available in Poland? | **Yes.** Poland, Germany, the UK and ~85 other regions are listed ([account-appendix-support-regions]). Unlike Push, Live View and Wear Engine, it is not China-only. |
| Emulator? | **Yes, partly.** "The Emulator supports only the sign-in and authorization capabilities of the unified authentication service, as well as the HUAWEI ID sign-in button component" ([account-introduction]). That is all we need. The emulator must be signed in to a HUAWEI ID (Settings), otherwise we get error 1001502001. |
| Approval? | **None for plain sign-in.** Individual developers get "sign-in with a HUAWEI ID (mobile number not obtained)" and silent sign-in. One-tap sign-in with the phone number, phone number, address and age scopes are enterprise-only and reviewed ([account-config-permissions]). |
| Fingerprint? | **Not needed**: "if compatibleSdkVersion is 20 or later, configuration of the public key fingerprint is not required" ([account-sign-fingerprints]). Ours is `6.0.0(20)`. |
| `client_id` in `module.json5`? | Only if the AGC **client ID differs from the app ID** (AGC → General information). Then add `metadata: [{ "name": "client_id", "value": "<app's client ID>" }]` to the entry module ([account-client-id]). |
| Supabase native `signInWithIdToken`? | **Not for Huawei.** Supported ID-token providers are Google, Apple, Azure, Facebook (and Kakao). Supabase's Custom OIDC providers (Apr 2026) use the browser redirect flow with `custom:<name>` ids, not a native ID token, and Huawei only offers `response_mode=form_post`. So we bridge with our own Edge Function. |

Recommendation: build it as a "Continue with HUAWEI ID" button that sends the **ID token** to a new Edge Function
`huawei-signin`. The function verifies it against Huawei's JWKS, finds or creates the Supabase user, and returns a
normal Supabase session, so `Session.ets` stays unchanged. No client secret is needed on this path. It works on the
emulator once the AGC app exists and the emulator has a HUAWEI ID signed in.

## AGC steps

1. AppGallery Connect → Development and services → create the project and a **HarmonyOS app** with bundle
   `com.celiaai.app` (shared with Push Kit / Live View; see `push-kit.md`).
2. Note the **client ID** and **app ID** (General information → App information). If they differ, configure
   `client_id` (above). Copy the **client secret** too, but only if we choose the authorization-code path (below).
3. Signing: DevEco Studio → Project Structure → Signing Configs → automatic signing with the Huawei ID that owns the
   AGC app ("If the app runs on HarmonyOS 6.0.0(20) or later, all APIs support automatic signing"). Keep the signing
   hunk out of git (`docs/REAL_DEVICE.md` §2).
4. No scope request is needed for UnionID/OpenID sign-in ("No additional scope or permission needs to be requested
   for the scenario described in this topic", [account-unionid-login-api]).

## Client (ArkTS)

Two UI options: the system **`LoginWithHuaweiIDButton`** component (`@kit.AccountKit`, supported on the emulator, follows
the HUAWEI ID design rules automatically) or our own button calling `authentication`. Our own button keeps
DESIGN.md control; it must follow the [HUAWEI ID button rules](https://developer.huawei.com/consumer/en/doc/design-guides/id-0000001880001344#section2624430102713).

`account/HuaweiIdSignIn.ets` (new):

```ts
import { authentication } from '@kit.AccountKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

export interface HuaweiIdResult {
  idToken: string;   // '' when not returned
  nonce: string;
  error: number;     // 0 on success, else the BusinessError code
}

// Codes from the guide's sample (account-unionid-login-api).
export const HWID_NOT_SIGNED_IN: number = 1001502001;
export const HWID_NETWORK: number = 1001502005;
export const HWID_USER_CANCEL: number = 1001502012;

/** Call from a page or component (the API "must be called within the lifecycle of a page or custom component"). */
export async function signInWithHuaweiId(ctx: common.Context): Promise<HuaweiIdResult> {
  const req: authentication.LoginWithHuaweiIDRequest = new authentication.HuaweiIDProvider().createLoginWithHuaweiIDRequest();
  req.forceLogin = true;                      // show sign-in/consent when needed
  req.state = util.generateRandomUUID();
  req.nonce = util.generateRandomUUID();      // matches ^[0-9a-zA-Z:/\.\-_]{1,255}$; ends up in the ID token
  try {
    const controller = new authentication.AuthenticationController(ctx);
    const resp = await controller.executeRequest(req) as authentication.LoginWithHuaweiIDResponse;
    if ((resp.state ?? '') !== (req.state ?? '')) {
      return { idToken: '', nonce: '', error: -1 };       // CSRF check failed
    }
    const token: string = resp.data?.idToken ?? '';
    return { idToken: token, nonce: req.nonce ?? '', error: 0 };
  } catch (e) {
    return { idToken: '', nonce: '', error: (e as BusinessError).code };
  }
}
```

- `LoginWithHuaweiIDCredential` has `authorizationCode?`, `idToken?`, `openID`, `unionID` (typings). The FAQ
  presents the ID token as the way to get user info without a server call, but the typings make it optional:
  **log whether it is present on the first emulator run.** If it is empty, use the authorization-code path.
- Pass `this.getUIContext().getHostContext()` from the component as `ctx`.
- Then `POST {SHARE_BACKEND_URL}/functions/v1/huawei-signin` with `{ idToken, nonce }` through `common/Net.ets`
  (anon key in `apikey`), and hand the returned `access_token`, `refresh_token`, `expires_in`, `user` to S1's
  existing session-store code, the same as after an email sign-in.
- UI errors: 1001502001 → "Sign in to your HUAWEI ID in Settings, or use email"; 1001502012 → silent (user
  cancelled); 1001502005 → network message. Never block the email path.
- Sign-out: S1's `Session.signOut()`; optionally `new authentication.HuaweiIDProvider().createCancelAuthorizationRequest()`
  (name checked in the SDK typings) passed to `executeRequest` when the user deletes their account.

## Server: `backend/supabase/functions/huawei-signin`

Huawei is a standard OIDC issuer (checked live 2026-10-03):

```
GET https://accounts.huawei.com/.well-known/openid-configuration
  issuer   https://accounts.huawei.com
  jwks_uri https://oauth-login.cloud.huawei.com/oauth2/v3/certs
  id_token_signing_alg_values_supported ["RS256","PS256"]
  subject_types_supported ["pairwise"]
```

ID token claims ([account-faq-12]): `iss` = `https://accounts.huawei.com`, `sub` = **UnionID**, `aud` = our client
ID, `azp`, `exp`, `iat`, `openid`, optional `nonce`, `display_name`/`nickname`/`picture` only with the `profile`
scope. The default sign-in algorithm is PS256.

```ts
import { createRemoteJWKSet, jwtVerify } from 'npm:jose@5';
import { createClient } from 'npm:@supabase/supabase-js@2';

const JWKS = createRemoteJWKSet(new URL('https://oauth-login.cloud.huawei.com/oauth2/v3/certs'));

Deno.serve(async (req) => {
  const body = await req.json().catch(() => null) as { idToken?: unknown; nonce?: unknown } | null;
  if (!body || typeof body.idToken !== 'string' || typeof body.nonce !== 'string') return json(400, { error: 'bad request' });
  let sub: string;
  try {
    const { payload } = await jwtVerify(body.idToken, JWKS, {
      issuer: 'https://accounts.huawei.com',
      audience: Deno.env.get('HUAWEI_CLIENT_ID')!,
      algorithms: ['PS256', 'RS256'],
    });
    if (payload.nonce !== body.nonce || typeof payload.sub !== 'string') return json(401, { error: 'invalid token' });
    sub = payload.sub;                                   // UnionID
  } catch { return json(401, { error: 'invalid token' }); }

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } });
  // Stable synthetic e-mail per UnionID: no real address is collected, and the user can't receive mail there.
  const email = `hw-${await sha256Hex(sub)}@users.celia.invalid`;
  await admin.auth.admin.createUser({ email, email_confirm: true, app_metadata: { provider: 'huawei' } })
    .catch(() => undefined);                             // already exists → fine
  const link = await admin.auth.admin.generateLink({ type: 'magiclink', email });
  if (link.error) return json(502, { error: 'session failed' });
  const anon = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!,
    { auth: { persistSession: false } });
  const { data, error } = await anon.auth.verifyOtp({ type: 'magiclink', token_hash: link.data.properties.hashed_token });
  if (error || !data.session) return json(502, { error: 'session failed' });
  return json(200, data.session);                        // access_token, refresh_token, expires_in, user
});
```

(`json` and `sha256Hex` are small helpers; `sos/index.ts` has the same `json`.)

Notes for whoever implements it:
- Deploy with `verify_jwt` **off** (the caller has no session yet); the ID token is the credential. Rate-limit by
  IP or by `sub` like the `sos` function's caps.
- `createUser` errors other than "already registered" must not be swallowed; check the error message or call
  `listUsers` with a filter first. Confirm that the project accepts the `.invalid` TLD for emails; if not, use a domain
  we control, e.g. `users.celia.example`. Verify both with a Deno test against the local stack or one manual call.
- The `generateLink` + `verifyOtp(token_hash)` pair is the documented admin way to mint a session for an existing
  user without a password. If the project's "magic link" rate limits bite, raise them or use a custom
  `auth.sessions` path; do not hand out the service role.
- **No account linking** in the first version: a HUAWEI ID user and an email user are two Supabase users. Linking
  (by verified email with the `email` scope) can come later.
- Unit tests (Deno, no network): request validation, nonce mismatch → 401, wrong `aud`/`iss` → 401 (sign test
  tokens with a local key pair and inject a local JWKS).
- Secrets: `HUAWEI_CLIENT_ID` (not really secret, but configuration). `SUPABASE_ANON_KEY` is provided by the
  platform. No Huawei client secret is needed on this path.
- `jose` is a third-party dependency: list it in README + `AI_WORKFLOW.md`.

### Alternative: authorization-code path

If `idToken` comes back empty: send `authorizationCode` instead; the function POSTs to
`https://oauth-login.cloud.huawei.com/oauth2/v3/token` (`grant_type=authorization_code`, `client_id`,
`client_secret`, `code`) ([account-api-obtain-user-token]). The response includes an `id_token` (OIDC) or the access
token goes to `getTokenInfo` (`https://oauth-api.cloud.huawei.com/rest.php?nsp_fmt=JSON&nsp_svc=huawei.oauth2.user.getTokenInfo`,
`open_id=OPENID&access_token=…`) → `union_id` ([account-api-get-token-info]). Needs `HUAWEI_CLIENT_SECRET` as a
function secret. The rest is the same.

## Privacy and docs

- What leaves the phone: the ID token (UnionID, OpenID, client ID) goes to our function; nothing else. The
  UnionID is hashed into the synthetic email. Add a row to README "What leaves the phone" when it ships (S1 owns that
  section).
- Ledger: log the `huawei-signin` request in `privacy/Ledger.ets` like every other request.
- AppGallery rule, for later: "If your app allows users to sign in using a third-party account, it must also provide
  the HUAWEI ID sign-in option" ([account-detailedrules]). Email + password is our own account system, so it is not
  required today, but adding Google/Apple would make it mandatory.

## Emulator vs real phone

| Step | Emulator | Real phone |
|---|---|---|
| `LoginWithHuaweiIDButton` / `executeRequest` | ✅ supported (emulator signed in to a HUAWEI ID) | ✅ |
| `idToken` present | to verify on first run | to verify |
| Edge Function + Supabase session | ✅ (network) | ✅ |
| Wearable | ❌ no wearable emulator support | wearables 5.1.0(18)+, not needed |

Test steps: Settings on the emulator → sign in with a HUAWEI ID → app → Welcome → "Continue with HUAWEI ID" → consent
→ lands signed in → kill the app, network off, reopen → still signed in (B1 acceptance applies unchanged) →
`select id, email, raw_app_meta_data from auth.users order by created_at desc limit 1` shows the `hw-…` user.

## Needs

- **AGC project + HarmonyOS app** for `com.celiaai.app` (client ID, app ID). Nothing else to approve.
- **A HUAWEI ID** signed in on the emulator or phone; the developer account behind AGC (overseas accounts need
  identity verification before signing works, `docs/REAL_DEVICE.md`).
- **Georgi's OK** to deploy a new function (`huawei-signin`, `verify_jwt: false`) and set `HUAWEI_CLIENT_ID`
  (coordinator action).
- S1's session store merged first (the function returns a standard Supabase session).

## Sources

- [account-introduction] About Account Kit (emulator support, devices) — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/account-introduction
- [account-appendix-support-regions] Supported Countries/Regions — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/account-appendix-support-regions
- [account-config-permissions] Requesting Scopes — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/account-config-permissions
- [account-sign-fingerprints] Signing information and fingerprint — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/account-sign-fingerprints
- [account-client-id] Configuring the Client ID — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/account-client-id
- [account-unionid-login-api] Sign-in with a custom button — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/account-unionid-login-api
- Sign-in with the HUAWEI ID button — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/account-unionid-login-button
- [account-faq-12] When and how to use the ID token (claims, JWKS, verification) — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/account-faq-12
- [account-api-obtain-user-token] Obtaining a user-level credential — https://developer.huawei.com/consumer/en/doc/harmonyos-references/account-api-obtain-user-token
- [account-api-get-token-info] Parsing a credential — https://developer.huawei.com/consumer/en/doc/harmonyos-references/account-api-get-token-info
- [account-detailedrules] Sign-in management rules — https://developer.huawei.com/consumer/en/doc/harmonyos-guides/account-detailedrules
- Huawei OIDC discovery — https://accounts.huawei.com/.well-known/openid-configuration
- Supabase `signInWithIdToken` (supported providers) — https://supabase.com/docs/reference/javascript/auth-signinwithidtoken
- Supabase Custom OIDC providers (2026-04-08) — https://supabase.com/blog/custom-oauth-oidc-providers
- Account Kit sample — https://gitcode.com/HarmonyOS_Samples/accountkit-samplecode-clientdemo-arkts
