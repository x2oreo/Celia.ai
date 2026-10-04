// POST /functions/v1/speak - text-to-speech fallback when on-device Core Speech has no English/Polish voice.
// Request: { text }. Response: raw PCM, 24 kHz, 16-bit, mono, little-endian (application/octet-stream),
// which the app plays directly with AudioRenderer.

import { env, json, openaiFetch } from '../_shared/openai.ts';
import { aiRateLimit } from '../_shared/rateLimit.ts';

const MAX_CHARS = 1500;
const VOICE_STYLE = 'Calm, warm and clear, like a kind nurse. Steady pace. Never dramatic, even for warnings.';

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') return json(405, { error: 'POST only' });
  const limited = await aiRateLimit(req, { fn: 'speak', perCaller: 60, windowSec: 600 });
  if (limited) return limited;
  const started = Date.now();
  let text: string;
  try {
    const body = await req.json() as { text?: unknown };
    if (typeof body.text !== 'string' || body.text.trim() === '') throw new Error('text must be a non-empty string');
    text = body.text.trim().slice(0, MAX_CHARS);
  } catch (err) {
    return json(400, { error: `bad request: ${(err as Error).message}` });
  }

  try {
    const res = await openaiFetch('/audio/speech', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: env('OPENAI_TTS_MODEL', 'gpt-4o-mini-tts'),
        voice: env('OPENAI_TTS_VOICE', 'marin'),
        input: text,
        instructions: VOICE_STYLE,
        response_format: 'pcm',
      }),
    }, 20000);
    const audio = await res.arrayBuffer();
    console.log(JSON.stringify({ fn: 'speak', chars: text.length, bytes: audio.byteLength, ms: Date.now() - started }));
    return new Response(audio, { status: 200, headers: { 'Content-Type': 'application/octet-stream' } });
  } catch (err) {
    console.error(JSON.stringify({ fn: 'speak', error: String(err), ms: Date.now() - started }));
    return json(502, { error: 'speech failed' }); // upstream failures are never the app's fault
  }
});
