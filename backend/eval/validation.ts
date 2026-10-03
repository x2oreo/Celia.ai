// Phase 0 (request validation) and Phase 5 (relay robustness) checks. Costs $0: validation runs with an invalid key,
// so a request that slips past validation shows up as a non-400 instead of a paid call.
//
//   deno run -A backend/eval/validation.ts            # both
//   deno run -A backend/eval/validation.ts validation # Phase 0 only
//   deno run -A backend/eval/validation.ts robustness # Phase 5 only (needs OPENAI_API_KEY for case 5.3)

import { DEFAULT_CONTEXT, pad, postJson, RunningFn, startFn } from './lib.ts';

interface Check {
  fn: string;
  name: string;
  expect: number;
  body?: unknown; // undefined = GET
}

const ctx = DEFAULT_CONTEXT;
const user = [{ role: 'user', text: 'EVAL-MARKER-7731 can I take Klacid?' }];
const bigB64 = (bytes: number) => 'A'.repeat(Math.ceil(bytes / 3) * 4);

const VALIDATION: Check[] = [
  { fn: 'agent', name: 'missing context', expect: 400, body: { messages: user } },
  { fn: 'agent', name: 'context not an object', expect: 400, body: { context: 'LQTS', messages: user } },
  { fn: 'agent', name: 'context missing vitals', expect: 400, body: { context: { ...ctx, vitals: undefined }, messages: user } },
  { fn: 'agent', name: 'genotype LQT9', expect: 400, body: { context: { ...ctx, genotype: 'LQT9' }, messages: user } },
  { fn: 'agent', name: '51 meds', expect: 400, body: { context: { ...ctx, meds: Array(51).fill('nadolol') }, messages: user } },
  { fn: 'agent', name: 'last message from assistant', expect: 400, body: { context: ctx, messages: [...user, { role: 'assistant', text: 'hi' }] } },
  { fn: 'agent', name: 'no messages, no continuation', expect: 400, body: { context: ctx, messages: [] } },
  { fn: 'agent', name: 'empty continuation.toolOutputs', expect: 400, body: { context: ctx, messages: [], continuation: { previousResponseId: 'resp_x', toolOutputs: [] } } },
  { fn: 'agent', name: 'role system', expect: 400, body: { context: ctx, messages: [{ role: 'system', text: 'x' }] } },
  { fn: 'agent', name: 'body not JSON', expect: 400, body: '{not json' },
  { fn: 'agent', name: 'GET', expect: 405 },
  { fn: 'transcribe', name: 'empty audio', expect: 400, body: { audioBase64: '', language: 'en' } },
  { fn: 'transcribe', name: 'audio > 2 MB', expect: 400, body: { audioBase64: bigB64(2_000_003), language: 'en' } },
  { fn: 'transcribe', name: 'audio not base64', expect: 400, body: { audioBase64: '%%%', language: 'en' } },
  { fn: 'transcribe', name: 'GET', expect: 405 },
  { fn: 'speak', name: 'empty text', expect: 400, body: { text: '' } },
  { fn: 'speak', name: 'whitespace text', expect: 400, body: { text: '   ' } },
  { fn: 'speak', name: 'text not a string', expect: 400, body: { text: 42 } },
  { fn: 'speak', name: 'GET', expect: 405 },
  { fn: 'vision-extract', name: 'image > 4 MB', expect: 400, body: { imageBase64: bigB64(4_000_003) } },
  { fn: 'vision-extract', name: 'missing image', expect: 400, body: {} },
  { fn: 'vision-extract', name: 'GET', expect: 405 },
  { fn: 'realtime-session', name: 'missing context', expect: 400, body: {} },
  { fn: 'realtime-session', name: 'genotype LQT9', expect: 400, body: { context: { ...ctx, genotype: 'LQT9' } } },
  { fn: 'realtime-session', name: 'GET', expect: 405 },
];

async function call(fn: RunningFn, c: Check): Promise<{ status: number; text: string; ms: number }> {
  if (c.body === undefined) {
    const t0 = performance.now();
    const r = await fetch(fn.url, { method: 'GET' });
    return { status: r.status, text: await r.text(), ms: Math.round(performance.now() - t0) };
  }
  return await postJson(fn.url, c.body);
}

async function runValidation(): Promise<number> {
  console.log('\n## Phase 0.5 — request validation (key = invalid, so any leak would be a non-400)\n');
  let failures = 0;
  const byFn = new Map<string, Check[]>();
  for (const c of VALIDATION) byFn.set(c.fn, [...(byFn.get(c.fn) ?? []), c]);
  for (const [name, checks] of byFn) {
    const fn = await startFn(name, { OPENAI_API_KEY: 'invalid' });
    try {
      for (const c of checks) {
        const r = await call(fn, c);
        const ok = r.status === c.expect;
        if (!ok) failures++;
        console.log(`${ok ? 'PASS' : 'FAIL'}  ${pad(name, 17)} ${pad(c.name, 32)} got ${r.status} (want ${c.expect}) ${r.ms} ms  ${r.text.slice(0, 80)}`);
      }
    } finally {
      await fn.stop();
    }
  }
  return failures;
}

const validRequest = { context: ctx, messages: user };

async function runRobustness(): Promise<number> {
  console.log('\n## Phase 5 — relay robustness\n');
  let failures = 0;
  const realKey = Deno.env.get('OPENAI_API_KEY') ?? '';
  const allLogs: string[] = [];

  const report = (name: string, ok: boolean, detail: string) => {
    if (!ok) failures++;
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${pad(name, 40)} ${detail}`);
  };
  const cleanBody = (t: string) => !/at\s+\S+\s*\(|Error:|sk-|stack/i.test(t) && (realKey === '' || !t.includes(realKey));

  // 5.1 invalid key
  let fn = await startFn('agent', { OPENAI_API_KEY: 'invalid' });
  try {
    const r = await postJson(fn.url, validRequest);
    report('5.1 invalid key → 502', r.status === 502 && r.text === '{"error":"upstream model error"}' && cleanBody(r.text),
      `got ${r.status} ${r.text}`);
  } finally {
    await fn.stop();
    allLogs.push(...fn.logs);
  }

  // 5.2 unknown model (rejected by OpenAI before any tokens are billed)
  fn = await startFn('agent', { OPENAI_MODEL: 'does-not-exist' });
  try {
    const r = await postJson(fn.url, validRequest);
    report('5.2 unknown model → 502', r.status === 502 && cleanBody(r.text), `got ${r.status} ${r.text}`);
  } finally {
    await fn.stop();
    allLogs.push(...fn.logs);
  }

  // 5.3 bogus previousResponseId (rejected before generation)
  fn = await startFn('agent');
  try {
    const r = await postJson(fn.url, {
      context: ctx,
      messages: [],
      continuation: { previousResponseId: 'resp_doesnotexist0000', toolOutputs: [{ callId: 'call_x', output: '{}' }] },
    });
    const ok = (r.status >= 400 && r.status < 500) || r.status === 502;
    report('5.3 bogus previousResponseId → 4xx/502', ok && cleanBody(r.text), `got ${r.status} ${r.text}`);
    // server still alive?
    const again = await postJson(fn.url, { context: ctx, messages: [] });
    report('5.3b server alive afterwards', again.status === 400, `got ${again.status}`);
  } finally {
    await fn.stop();
    allLogs.push(...fn.logs);
  }

  // 5.4 log hygiene
  const joined = allLogs.join('\n');
  report('5.4 logs: no user message text', !joined.includes('EVAL-MARKER-7731'), `${allLogs.length} lines`);
  report('5.4 logs: no real API key', realKey === '' || !joined.includes(realKey), realKey === '' ? 'no key loaded' : 'checked');
  const echoed = allLogs.filter((l) => /invalid|Incorrect API key|does-not-exist|resp_doesnotexist/i.test(l));
  report('5.4 logs: no upstream error detail echoed', echoed.length === 0,
    echoed.length === 0 ? '' : `${echoed.length} line(s) echo upstream detail, e.g. ${echoed[0].slice(0, 220)}`);
  console.log('\nlog lines:');
  for (const l of allLogs) console.log(`  ${(realKey === '' ? l : l.replaceAll(realKey, '<KEY>')).slice(0, 300)}`);
  return failures;
}

const which = Deno.args[0] ?? 'all';
let failures = 0;
if (which === 'all' || which === 'validation') failures += await runValidation();
if (which === 'all' || which === 'robustness') failures += await runRobustness();
console.log(`\n${failures === 0 ? 'ALL PASS' : `${failures} FAILURE(S)`}`);
Deno.exit(failures === 0 ? 0 : 1);
