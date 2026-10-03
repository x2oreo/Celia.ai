// Phase 2 — audio round trip: /speak (TTS → raw PCM 24 kHz) → WAV wrap → /transcribe → SafetyGate port.
//
//   set -a; source backend/supabase/functions/.env; set +a
//   deno run -A backend/eval/audio-eval.ts

import { addSpend, assertBudget, classifyGate, GateResult, pad, postJson, PRICE, spent, startFn, usd } from './lib.ts';

const PHASE = 'audio';
const PHASE_CAP_USD = 0.2;

interface Phrase {
  text: string;
  language: 'en' | 'pl';
  mustContain: RegExp[];
  gate: GateResult;
}

const PHRASES: Phrase[] = [
  { text: 'Klacid is on the known-risk list. Please ask your pharmacist.', language: 'en', mustContain: [/klacid/i, /pharmacist/i], gate: 'NONE' },
  { text: 'Can I take ondansetron?', language: 'en', mustContain: [/ondansetron/i], gate: 'NONE' },
  { text: 'I passed out at the pool', language: 'en', mustContain: [/passed out/i, /pool/i], gate: 'EMERGENCY' },
  { text: 'Czy mogę wziąć Zofran?', language: 'pl', mustContain: [/zofran/i, /wzi[ąa][ćc]/i], gate: 'NONE' },
  // Extra: does the transcript use a typographic apostrophe, and does the gate still catch it?
  { text: "I can't breathe properly", language: 'en', mustContain: [/breathe/i], gate: 'EMERGENCY' },
];

// 44-byte RIFF header for PCM16 mono (mirrors app/.../voice/Wav.ets).
function wav(pcm: Uint8Array, rate: number): Uint8Array {
  const out = new Uint8Array(44 + pcm.length);
  const v = new DataView(out.buffer);
  const ascii = (o: number, s: string) => [...s].forEach((ch, i) => v.setUint8(o + i, ch.charCodeAt(0)));
  ascii(0, 'RIFF');
  v.setUint32(4, 36 + pcm.length, true);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  v.setUint32(16, 16, true);
  v.setUint16(20, 1, true); // PCM
  v.setUint16(22, 1, true); // mono
  v.setUint32(24, rate, true);
  v.setUint32(28, rate * 2, true);
  v.setUint16(32, 2, true);
  v.setUint16(34, 16, true);
  ascii(36, 'data');
  v.setUint32(40, pcm.length, true);
  out.set(pcm, 44);
  return out;
}

function b64(bytes: Uint8Array): string {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

let failures = 0;
const report = (ok: boolean, label: string, detail: string) => {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${pad(label, 46)} ${detail}`);
};

console.log(`spend so far ${usd(spent())}\n## speak\n`);
const audio: Uint8Array[] = [];
let fn = await startFn('speak');
try {
  for (const p of PHRASES) {
    assertBudget(PHASE, PHASE_CAP_USD);
    const t0 = performance.now();
    const res = await fetch(fn.url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ text: p.text }) });
    const bytes = new Uint8Array(await res.arrayBuffer());
    const ms = Math.round(performance.now() - t0);
    addSpend(PHASE, `speak "${p.text.slice(0, 24)}"`, PRICE.audioCall);
    audio.push(bytes);
    const secs = bytes.length / 48000;
    const ct = res.headers.get('content-type') ?? '';
    report(res.status === 200 && ct === 'application/octet-stream' && bytes.length % 2 === 0 && secs >= 1 && secs <= 10,
      `speak "${p.text.slice(0, 36)}"`, `${res.status} ${ct} ${bytes.length} B = ${secs.toFixed(2)} s, ${ms} ms`);
  }
  report(audio[0].length / 48000 >= 2, 'speak phrase 1 duration 2–10 s', `${(audio[0].length / 48000).toFixed(2)} s`);
} finally {
  await fn.stop();
}
for (const l of fn.logs) console.log(`  log: ${l.slice(0, 200)}`);

console.log('\n## transcribe → SafetyGate\n');
fn = await startFn('transcribe');
try {
  for (let i = 0; i < PHRASES.length; i++) {
    const p = PHRASES[i];
    if (audio[i] === undefined || audio[i].length === 0) continue;
    assertBudget(PHASE, PHASE_CAP_USD);
    const res = await postJson(fn.url, { audioBase64: b64(wav(audio[i], 24000)), language: p.language });
    addSpend(PHASE, `transcribe "${p.text.slice(0, 24)}"`, PRICE.audioCall);
    const text = res.status === 200 ? (JSON.parse(res.text) as { text: string }).text : '';
    const gate = classifyGate(text, false);
    const missing = p.mustContain.filter((r) => !r.test(text)).map((r) => r.source);
    const curly = /[‘’]/.test(text);
    report(res.status === 200 && missing.length === 0, `transcribe (${p.language}) "${p.text.slice(0, 28)}"`,
      `${res.status} ${res.ms} ms → ${JSON.stringify(text)}${missing.length ? ` missing ${missing.join(',')}` : ''}${curly ? ' [curly apostrophe]' : ''}`);
    report(gate === p.gate, `  SafetyGate.classify → ${p.gate}`, `got ${gate}`);
  }
} finally {
  await fn.stop();
}
for (const l of fn.logs) console.log(`  log: ${l.slice(0, 200)}`);

console.log(`\n${failures === 0 ? 'ALL PASS' : `${failures} FAILURE(S)`}; total spend ${usd(spent())}`);
