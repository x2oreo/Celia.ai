// POST /functions/v1/transcribe — push-to-talk speech-to-text fallback when on-device Core Speech
// cannot recognise English/Polish. Request: { audioBase64: <WAV 16 kHz mono PCM16>, language: 'en' | 'pl' | '' }
// Response: { text }. Audio is not stored or logged.

import { env, json, openaiFetch, decodeBase64 } from '../_shared/openai.ts';

const MAX_AUDIO_BYTES = 2_000_000; // ~60 s of 16 kHz mono PCM16
// Medicine names bias the recogniser toward words people actually say to Celia (gpt-transcribe "keywords").
const KEYWORDS = ['Klacid', 'clarithromycin', 'ondansetron', 'Zofran', 'azithromycin', 'Sumamed', 'ciprofloxacin',
  'domperidone', 'Motilium', 'escitalopram', 'citalopram', 'ibuprofen', 'Nurofen', 'Ibuprom', 'paracetamol', 'Apap',
  'nadolol', 'propranolol', 'Long QT', 'LQT1', 'LQT2', 'LQT3'];

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') return json(405, { error: 'POST only' });
  const started = Date.now();
  let audio: Uint8Array<ArrayBuffer>;
  let language = '';
  try {
    const body = await req.json() as { audioBase64?: unknown; language?: unknown };
    if (typeof body.audioBase64 !== 'string') throw new Error('audioBase64 must be a string');
    audio = decodeBase64(body.audioBase64);
    if (audio.length === 0 || audio.length > MAX_AUDIO_BYTES) throw new Error('audio size out of range');
    if (typeof body.language === 'string' && ['en', 'pl'].includes(body.language)) language = body.language;
  } catch (err) {
    return json(400, { error: `bad request: ${(err as Error).message}` });
  }

  const model = env('OPENAI_TRANSCRIBE_MODEL', 'gpt-transcribe');
  const form = new FormData();
  form.append('file', new Blob([audio], { type: 'audio/wav' }), 'speech.wav');
  form.append('model', model);
  if (language !== '') form.append('language', language);
  if (model === 'gpt-transcribe') {
    for (const k of KEYWORDS) form.append('keywords[]', k);
  }

  try {
    const res = await openaiFetch('/audio/transcriptions', { method: 'POST', body: form }, 15000);
    const data = await res.json() as { text?: string };
    const text = (data.text ?? '').trim().slice(0, 2000);
    console.log(JSON.stringify({ fn: 'transcribe', model, bytes: audio.length, chars: text.length, ms: Date.now() - started }));
    return json(200, { text });
  } catch (err) {
    console.error(JSON.stringify({ fn: 'transcribe', error: String(err), ms: Date.now() - started }));
    return json(502, { error: 'transcription failed' }); // upstream failures are never the app's fault
  }
});
