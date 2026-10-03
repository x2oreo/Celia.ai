// Run: npx -y deno test --no-lock backend/supabase/functions/sos/
// No network: the JWT is signed with a throwaway key and checked locally.
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { decodeProtectedHeader, exportPKCS8, exportSPKI, generateKeyPair, importSPKI, jwtVerify } from 'npm:jose@5';
import { PUSH_AUD, pushConfigFromEnv, pushJwt, watchSosPush } from './huaweiPush.ts';

function env(map: Record<string, string>): (k: string) => string | undefined {
  return (k: string) => map[k];
}

Deno.test('push config: null without secrets or with a bad key file', () => {
  assertEquals(pushConfigFromEnv(env({})), null);
  assertEquals(pushConfigFromEnv(env({ HUAWEI_PUSH_PROJECT_ID: 'p' })), null);
  assertEquals(pushConfigFromEnv(env({ HUAWEI_PUSH_PROJECT_ID: 'p', HUAWEI_PUSH_SA_KEY: 'not json' })), null);
  assertEquals(pushConfigFromEnv(env({ HUAWEI_PUSH_PROJECT_ID: 'p', HUAWEI_PUSH_SA_KEY: '{"key_id":"k"}' })), null);
});

Deno.test('push config: reads the service-account key fields', () => {
  const key = JSON.stringify({ key_id: 'kid1', sub_account: 'sub1', private_key: 'PEM' });
  assertEquals(pushConfigFromEnv(env({ HUAWEI_PUSH_PROJECT_ID: 'p1', HUAWEI_PUSH_SA_KEY: key })),
    { projectId: 'p1', keyId: 'kid1', subAccount: 'sub1', privateKey: 'PEM' });
});

Deno.test('push JWT: PS256, kid, issuer, audience and one-hour lifetime', async () => {
  const pair = await generateKeyPair('PS256', { extractable: true });
  const cfg = { projectId: 'p', keyId: 'kid1', subAccount: 'sub1', privateKey: await exportPKCS8(pair.privateKey) };
  const jwt = await pushJwt(cfg);
  assertEquals(decodeProtectedHeader(jwt), { alg: 'PS256', kid: 'kid1', typ: 'JWT' });
  const pub = await importSPKI(await exportSPKI(pair.publicKey), 'PS256');
  const { payload } = await jwtVerify(jwt, pub, { issuer: 'sub1', audience: PUSH_AUD });
  assertEquals((payload.exp ?? 0) - (payload.iat ?? 0), 3600);
});

Deno.test('watch SOS push: fixed copy, SOS route data, ten tokens at most', () => {
  const tokens = Array.from({ length: 12 }, (_, i) => `token-${i}-abcdefghijklmnop`);
  const m = watchSosPush(tokens, true, '2026-10-04T08:00:00.000Z') as {
    payload: { notification: { title: string; body: string; notifyId: number; clickAction: { data: Record<string, string> } } };
    target: { token: string[] };
    pushOptions: { testMessage: boolean };
  };
  assertEquals(m.target.token.length, 10);
  assertEquals(m.payload.notification.notifyId, 1004);
  assertEquals(m.payload.notification.clickAction.data,
    { route: 'sos', source: 'watch', loc: '1', at: '2026-10-04T08:00:00.000Z' });
  assert(m.pushOptions.testMessage);
  assert(!m.payload.notification.body.includes('http'), 'no location link in the push');
});
