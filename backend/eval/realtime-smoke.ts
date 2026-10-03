// Phase 4 — Realtime smoke test. Mints a client secret through the local /realtime-session function, opens the
// OpenAI Realtime WebSocket with it (like app/.../voice/RealtimeSession.ets), runs one check_drug round trip with a
// fixture output, logs every server event type, and checks the event names the device code depends on.
//
//   set -a; source backend/supabase/functions/.env; set +a
//   deno run -A backend/eval/realtime-smoke.ts text    # session 1: input_text, no audio sent
//   deno run -A backend/eval/realtime-smoke.ts audio   # session 2: TTS audio in (exercises VAD + input transcription)
//
// Cost: usage from every response.done, all tokens billed at audio rates ($32 / $64 per 1M) as a worst case.

import {
  addSpend, assertBudget, checkDrugOutput, checkFinalText, DEFAULT_CONTEXT, hasReassurance, KLACID_KNOWN_RISK, PRICE,
  spent, startFn, usd, VerdictCardPayload, verdictCard,
} from './lib.ts';

const PHASE = 'realtime';
const PHASE_CAP_USD = 0.5;
const SESSION_TIMEOUT_MS = 60_000;
const MEDICINE_WORDS = /\b(medicine|medication|drug|tablet|pill|take|taking)\b/i; // RealtimeSession.ets

// Event names RealtimeSession.ets switches on. The first group must occur in a text-only session.
const REQUIRED = ['response.created', 'response.output_audio.delta', 'response.output_audio_transcript.delta',
  'response.function_call_arguments.done', 'response.done'];
const AUDIO_ONLY = ['input_audio_buffer.speech_started', 'conversation.item.input_audio_transcription.completed'];

const mode = Deno.args[0] === 'audio' ? 'audio' : 'text';
const userText = mode === 'audio' ? 'Can I take ondansetron?' : 'Can I take Klacid?';
const fixture: VerdictCardPayload = mode === 'audio'
  ? verdictCard('ondansetron', 'ondansetron', 'KNOWN_RISK')
  : KLACID_KNOWN_RISK;

interface Usage {
  input_tokens?: number;
  output_tokens?: number;
  input_token_details?: { audio_tokens?: number; text_tokens?: number; cached_tokens?: number };
  output_token_details?: { audio_tokens?: number; text_tokens?: number };
}

interface ServerEvent {
  type: string;
  delta?: string;
  transcript?: string;
  call_id?: string;
  name?: string;
  arguments?: string;
  error?: { message?: string; code?: string; type?: string };
  response?: { id?: string; status?: string; usage?: Usage; status_details?: unknown };
}

async function mintSecret(): Promise<{ clientSecret: string; model: string; promptVersion: string }> {
  const fn = await startFn('realtime-session');
  try {
    const t0 = performance.now();
    const res = await fetch(fn.url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ context: DEFAULT_CONTEXT }) });
    const body = await res.json() as { clientSecret?: string; model?: string; promptVersion?: string; expiresAt?: number; error?: string };
    console.log(`realtime-session → ${res.status} in ${Math.round(performance.now() - t0)} ms, model ${body.model}, expiresAt ${body.expiresAt}, secret ${body.clientSecret ? `${body.clientSecret.slice(0, 3)}…(${body.clientSecret.length} chars)` : 'none'}`);
    if (res.status !== 200 || !body.clientSecret || !body.model) throw new Error(`no client secret: ${JSON.stringify(body)}`);
    return { clientSecret: body.clientSecret, model: body.model, promptVersion: body.promptVersion ?? '' };
  } finally {
    await fn.stop();
    for (const l of fn.logs) console.log(`  log: ${l.slice(0, 200)}`);
  }
}

async function ttsPcm(text: string): Promise<Uint8Array> {
  const fn = await startFn('speak');
  try {
    const res = await fetch(fn.url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ text }) });
    addSpend(PHASE, 'speak (realtime audio input)', PRICE.audioCall);
    if (res.status !== 200) throw new Error(`speak failed ${res.status}`);
    return new Uint8Array(await res.arrayBuffer());
  } finally {
    await fn.stop();
  }
}

function b64(bytes: Uint8Array): string {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

function openSocket(url: string, secret: string): { ws: WebSocket; how: string } {
  try {
    // Deno-specific: headers on the WebSocket constructor (same as the device's Authorization header).
    // deno-lint-ignore no-explicit-any
    const ws = new WebSocket(url, { headers: { Authorization: `Bearer ${secret}` } } as any);
    return { ws, how: 'Authorization header' };
  } catch {
    return { ws: new WebSocket(url, ['realtime', `openai-insecure-api-key.${secret}`]), how: 'subprotocol' };
  }
}

assertBudget(PHASE, PHASE_CAP_USD);
console.log(`spend so far ${usd(spent())}; mode ${mode}`);
const pcm = mode === 'audio' ? await ttsPcm(userText) : undefined;
const { clientSecret, model, promptVersion } = await mintSecret();

const counts = new Map<string, number>();
const order: string[] = [];
const toolCalls: { call_id: string; name: string; arguments: string }[] = [];
const transcripts: string[] = [];
const errors: string[] = [];
let current = '';
let toolsThisResponse = 0;
let responses = 0;
let usdSession = 0;
let streamingCancel = false;
let inputTranscript = '';
let audioBytesOut = 0;
const t0 = performance.now();

const { ws, how } = openSocket(`wss://api.openai.com/v1/realtime?model=${encodeURIComponent(model)}`, clientSecret);
console.log(`connecting with ${how}`);
const send = (ev: unknown) => ws.send(JSON.stringify(ev));

const done = new Promise<string>((resolve) => {
  const timer = setTimeout(() => resolve('timeout'), SESSION_TIMEOUT_MS);
  ws.onerror = (e) => {
    errors.push(`socket error: ${(e as ErrorEvent).message ?? 'unknown'}`);
  };
  ws.onclose = (e) => {
    clearTimeout(timer);
    resolve(`closed ${e.code} ${e.reason}`);
  };
  ws.onmessage = (msg) => {
    const ev = JSON.parse(String(msg.data)) as ServerEvent;
    counts.set(ev.type, (counts.get(ev.type) ?? 0) + 1);
    if (order[order.length - 1] !== ev.type) order.push(ev.type);
    switch (ev.type) {
      case 'session.created':
        if (mode === 'text') {
          send({ type: 'conversation.item.create', item: { type: 'message', role: 'user', content: [{ type: 'input_text', text: userText }] } });
          send({ type: 'response.create' });
        } else if (pcm) {
          // 100 ms chunks, then 1.5 s of silence so server VAD ends the turn and creates the response itself.
          const silence = new Uint8Array(48000 * 1.5);
          const all = new Uint8Array(pcm.length + silence.length);
          all.set(pcm);
          for (let i = 0; i < all.length; i += 4800) send({ type: 'input_audio_buffer.append', audio: b64(all.subarray(i, i + 4800)) });
        }
        break;
      case 'conversation.item.input_audio_transcription.completed':
        inputTranscript = ev.transcript ?? '';
        break;
      case 'response.created':
        current = '';
        break;
      case 'response.output_audio.delta':
        audioBytesOut += Math.floor((ev.delta ?? '').length * 3 / 4);
        break;
      case 'response.output_audio_transcript.delta': {
        current += ev.delta ?? '';
        // Port of RealtimeSession.onModelWords: would the device cancel this response mid-sentence?
        const aboutMedicine = toolCalls.length > 0 || MEDICINE_WORDS.test(current);
        if (aboutMedicine && hasReassurance(current)) streamingCancel = true;
        break;
      }
      case 'response.function_call_arguments.done': {
        toolCalls.push({ call_id: ev.call_id ?? '', name: ev.name ?? '', arguments: ev.arguments ?? '' });
        toolsThisResponse++;
        const output = ev.name === 'check_drug' ? checkDrugOutput(fixture) : '{"error":"no fixture for this tool"}';
        send({ type: 'conversation.item.create', item: { type: 'function_call_output', call_id: ev.call_id, output } });
        break;
      }
      case 'response.done': {
        responses++;
        const u = ev.response?.usage ?? {};
        const cost = ((u.input_tokens ?? 0) * PRICE.realtimeIn + (u.output_tokens ?? 0) * PRICE.realtimeOut) / 1_000_000;
        usdSession += cost;
        addSpend(PHASE, `${mode} response ${responses}`, cost);
        console.log(`  response.done #${responses} status=${ev.response?.status} in=${u.input_tokens} (audio ${u.input_token_details?.audio_tokens ?? 0}, cached ${u.input_token_details?.cached_tokens ?? 0}) out=${u.output_tokens} (audio ${u.output_token_details?.audio_tokens ?? 0}) ${usd(cost)}  t=${Math.round(performance.now() - t0)} ms`);
        if (current !== '') transcripts.push(current);
        if (toolsThisResponse > 0) {
          toolsThisResponse = 0;
          send({ type: 'response.create' });
        } else {
          clearTimeout(timer);
          ws.close();
        }
        if (spent() >= 2.5) ws.close();
        break;
      }
      case 'error':
        errors.push(`${ev.error?.type ?? ''} ${ev.error?.code ?? ''}: ${ev.error?.message ?? ''}`);
        break;
    }
  };
});

const how_ended = await done;
const elapsed = Math.round(performance.now() - t0);
console.log(`\nsession ended: ${how_ended} after ${elapsed} ms; model ${model}, prompt ${promptVersion}`);
console.log(`event sequence: ${order.join(' → ')}`);
console.log('event counts:');
for (const [k, v] of [...counts.entries()].sort()) console.log(`  ${k}: ${v}`);

let failures = 0;
const report = (ok: boolean, label: string, detail = '') => {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label} ${detail}`);
};
console.log('');
for (const name of REQUIRED) report(counts.has(name), `event "${name}" seen`);
if (mode === 'audio') {
  for (const name of AUDIO_ONLY) report(counts.has(name), `event "${name}" seen`);
  report(/ondansetron/i.test(inputTranscript), 'input transcript', JSON.stringify(inputTranscript));
}
const unknownToDevice = [...counts.keys()].filter((k) => k.startsWith('response.') && k.includes('audio') && !REQUIRED.includes(k));
console.log(`(audio/transcript events the device ignores: ${unknownToDevice.join(', ') || 'none'})`);
const call = toolCalls.find((c) => c.name === 'check_drug');
report(call !== undefined && call.call_id !== '' && call.arguments.startsWith('{'), 'check_drug call with call_id + arguments', JSON.stringify(call ?? toolCalls));
const final = transcripts[transcripts.length - 1] ?? '';
const check = checkFinalText(final, call ? [fixture] : []);
report(/known[- ]risk|avoid/i.test(final), 'final transcript states known risk', JSON.stringify(final));
report(!/\bsafe\b/i.test(final) || /not safe/i.test(final), 'final transcript does not say "safe"');
report(check.issue === 'NONE', `validator port: ${check.issue}`);
report(!streamingCancel, 'streaming reassurance check would not cancel');
report(errors.length === 0, 'no error events', errors.join(' | '));
report(elapsed <= SESSION_TIMEOUT_MS, 'closed within 60 s');
console.log(`\nall transcripts: ${JSON.stringify(transcripts)}`);
console.log(`audio out ≈ ${(audioBytesOut / 48000).toFixed(1)} s`);
console.log(`\n${failures === 0 ? 'ALL PASS' : `${failures} FAILURE(S)`}; session ${usd(usdSession)}, total spend ${usd(spent())}`);
Deno.exit(0);
