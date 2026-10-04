// Smoke test for the DEPLOYED backend: calls every Edge Function and the public REST tables the app uses, over HTTPS,
// with the same public key the app ships. Cheap (about $0.05 of OpenAI calls). Nothing is written except one share
// object, which is revoked at the end.
//
//   CELIA_KEY=<public publishable/anon key> npx -y deno@2 run -A backend/eval/remote-smoke.ts
//   CELIA_URL defaults to the team project.

const URL_BASE = Deno.env.get('CELIA_URL') ?? 'https://jxiggumhircfuhianmel.supabase.co';
const KEY = Deno.env.get('CELIA_KEY') ?? '';
if (KEY === '') {
  console.error('Set CELIA_KEY to the public client key (the one in LocalConfig.ets).');
  Deno.exit(2);
}

const CONTEXT = {
  condition: 'LQTS', genotype: 'LQT2', meds: ['nadolol'], vitals: 'HR 72 at rest, no alerts (simulated)',
  emergencyNumber: '112', locale: 'en-GB',
};

type Check = (status: number, body: string) => string | null;

let failed = 0;

async function call(name: string, path: string, init: RequestInit, check: Check): Promise<string> {
  const headers = new Headers(init.headers);
  headers.set('apikey', KEY);
  headers.set('Authorization', `Bearer ${KEY}`);
  if (init.body !== undefined && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json');
  const started = Date.now();
  let status = 0;
  let body = '';
  try {
    const res = await fetch(`${URL_BASE}${path}`, { ...init, headers, signal: AbortSignal.timeout(60_000) });
    status = res.status;
    const buf = new Uint8Array(await res.arrayBuffer());
    body = (res.headers.get('Content-Type') ?? '').includes('json') || buf.length < 4096
      ? new TextDecoder().decode(buf) : `<${buf.length} bytes>`;
  } catch (e) {
    body = String(e);
  }
  const problem = check(status, body);
  const ms = Date.now() - started;
  if (problem === null) {
    console.log(`PASS ${name} (${status}, ${ms} ms)`);
  } else {
    failed++;
    console.log(`FAIL ${name} (${status}, ${ms} ms): ${problem}\n     ${body.slice(0, 300)}`);
  }
  return body;
}

const ok200 = (must: string[]): Check => (s, b) => {
  if (s !== 200) return `expected 200`;
  for (const m of must) if (!b.includes(m)) return `missing ${m}`;
  return null;
};

const post = (body: unknown): RequestInit => ({ method: 'POST', body: JSON.stringify(body) });

// 16 kHz mono 16-bit WAV, 0.5 s of a quiet tone: enough for the transcriber to accept the file.
function tinyWav(): string {
  const n = 8000;
  const buf = new DataView(new ArrayBuffer(44 + n * 2));
  const w = (o: number, s: string) => [...s].forEach((c, i) => buf.setUint8(o + i, c.charCodeAt(0)));
  w(0, 'RIFF'); buf.setUint32(4, 36 + n * 2, true); w(8, 'WAVE'); w(12, 'fmt ');
  buf.setUint32(16, 16, true); buf.setUint16(20, 1, true); buf.setUint16(22, 1, true);
  buf.setUint32(24, 16000, true); buf.setUint32(28, 32000, true); buf.setUint16(32, 2, true); buf.setUint16(34, 16, true);
  w(36, 'data'); buf.setUint32(40, n * 2, true);
  for (let i = 0; i < n; i++) buf.setInt16(44 + i * 2, Math.round(800 * Math.sin(i / 8)), true);
  let bin = '';
  new Uint8Array(buf.buffer).forEach((b) => bin += String.fromCharCode(b));
  return btoa(bin);
}

async function boxImage(): Promise<string> {
  const path = new URL('./out/images/1-klacid.jpg', import.meta.url).pathname;
  try {
    const bytes = await Deno.readFile(path);
    let bin = '';
    bytes.forEach((b) => bin += String.fromCharCode(b));
    return btoa(bin);
  } catch {
    return '';
  }
}

// --- Database (REST) ---
await call('rest drugs', '/rest/v1/drugs?select=ingredient,risk&limit=1', { method: 'GET' }, ok200(['risk']));
await call('rest watch_metrics (demo watch)', '/rest/v1/watch_metrics?select=type&device_id=eq.demo-watch-1&limit=1',
  { method: 'GET' }, (s) => s === 200 ? null : 'expected 200');

// --- Deterministic ---
await call('drug-check list hit', '/functions/v1/drug-check', post({ query: 'Klacid' }), ok200(['KNOWN_RISK']));
await call('drug-check unlisted', '/functions/v1/drug-check', post({ query: 'ibuprofen' }), ok200(['"risk"']));
await call('box-identify fast', '/functions/v1/box-identify', post({ gtin: '5909990733828', stage: 'fast' }),
  (s) => s === 200 ? null : 'expected 200');

// --- AI ---
await call('agent step', '/functions/v1/agent',
  post({ context: CONTEXT, messages: [{ role: 'user', text: 'Can I take Klacid?' }] }), ok200(['promptVersion']));
await call('agent rejects bad body', '/functions/v1/agent', post({}), (s) => s === 400 ? null : 'expected 400');
await call('med-info', '/functions/v1/med-info', post({ medicine: 'Nurofen', ingredient: 'ibuprofen' }),
  ok200(['summary']));
await call('doctor-summary', '/functions/v1/doctor-summary', post({
  specialty: 'Cardiology', genotype: 'LQT2', medicines: 'Nadolol 40 mg - on your plan', interactions: '',
  flagged: '', heartAlerts: '', symptoms: '', visitFor: '', avoid: '', reason: '', worries: '',
}), ok200(['summary']));
await call('speak', '/functions/v1/speak', post({ text: 'Hello from Celia.' }), (s, b) =>
  s === 200 && b.startsWith('<') ? null : 'expected 200 audio');
await call('transcribe', '/functions/v1/transcribe', post({ audioBase64: tinyWav(), language: 'en' }),
  ok200(['text']));
const img = await boxImage();
if (img !== '') {
  await call('vision-extract', '/functions/v1/vision-extract', post({ imageBase64: img }), ok200(['drugs']));
} else {
  console.log('SKIP vision-extract (run backend/eval/make_images.py first)');
}
await call('realtime-session', '/functions/v1/realtime-session', post({ context: CONTEXT }), ok200(['"']));

// --- Share links (create, read, revoke) ---
const ct = btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(64))))
  .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const created = await call('share create', '/functions/v1/share', post({ kind: 'card', ciphertext: ct }),
  ok200(['revokeToken']));
try {
  const c = JSON.parse(created) as { id: string; revokeToken: string };
  await call('share read', `/functions/v1/share?id=${c.id}`, { method: 'GET' }, ok200([ct.slice(0, 20)]));
  await call('share revoke', '/functions/v1/share', post({ action: 'revoke', id: c.id, revokeToken: c.revokeToken }),
    ok200(['revoked']));
} catch {
  console.log('SKIP share read/revoke (create failed)');
}

// --- SOS webhook must refuse callers without the shared secret ---
await call('sos refuses no secret', '/functions/v1/sos', post({ record: {} }),
  (s) => s === 401 || s === 403 ? null : 'expected 401/403');

console.log(failed === 0 ? '\nALL PASS' : `\n${failed} FAILED`);
Deno.exit(failed === 0 ? 0 : 1);
