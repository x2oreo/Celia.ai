// POST /functions/v1/realtime-session — mints a short-lived OpenAI Realtime client secret for speech-to-speech.
// The session gets the SAME instructions and tool schemas as /agent; tools still execute on the device.
// Request: { context }. Response: { clientSecret, expiresAt, model, promptVersion }.
// The client secret is single-purpose and expires in 2 minutes (only needed to open the WebSocket).

import { buildInstructions, PROMPT_VERSION } from '../_shared/prompt.ts';
import { TOOLS } from '../_shared/tools.ts';
import { env, json, openaiJson, UpstreamError } from '../_shared/openai.ts';
import { parseContext } from '../_shared/validate.ts';

const VOICE_RULES = `
VOICE MODE: you are speaking out loud. Keep every answer to one to three short sentences. Never read lists or
JSON aloud. While a tool runs, say a few words like "Let me check that." The verdict card appears on the user's
screen, so you can say "I've put the details on your screen."`.trim();

interface ClientSecretResponse {
  value: string;
  expires_at: number;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') return json(405, { error: 'POST only' });
  const started = Date.now();
  let instructions: string;
  try {
    const body = await req.json() as { context?: unknown };
    instructions = `${buildInstructions(parseContext(body.context))}\n\n${VOICE_RULES}`;
  } catch (err) {
    return json(400, { error: `bad request: ${(err as Error).message}` });
  }

  const model = env('OPENAI_REALTIME_MODEL', 'gpt-realtime');
  // Realtime function tools use the same JSON schemas; `strict` is a Responses-only field.
  const tools = TOOLS.map((t) => ({ type: t.type, name: t.name, description: t.description, parameters: t.parameters }));

  try {
    const res = await openaiJson<ClientSecretResponse>('/realtime/client_secrets', {
      expires_after: { anchor: 'created_at', seconds: 120 },
      session: {
        type: 'realtime',
        model,
        instructions,
        tools,
        tool_choice: 'auto',
        output_modalities: ['audio'],
        audio: {
          input: {
            format: { type: 'audio/pcm', rate: 24000 },
            // Transcripts feed the on-device SafetyGate and the chat history.
            transcription: { model: env('OPENAI_TRANSCRIBE_MODEL', 'gpt-transcribe') },
            noise_reduction: { type: 'near_field' },
            turn_detection: { type: 'server_vad', interrupt_response: true, silence_duration_ms: 600 },
          },
          output: {
            format: { type: 'audio/pcm', rate: 24000 },
            voice: env('OPENAI_TTS_VOICE', 'marin'),
          },
        },
      },
    }, 10000);
    console.log(JSON.stringify({ fn: 'realtime-session', model, promptVersion: PROMPT_VERSION, ms: Date.now() - started }));
    return json(200, { clientSecret: res.value, expiresAt: res.expires_at, model, promptVersion: PROMPT_VERSION });
  } catch (err) {
    console.error(JSON.stringify({ fn: 'realtime-session', error: String(err), ms: Date.now() - started }));
    const status = err instanceof UpstreamError && err.status < 500 ? err.status : 502;
    return json(status, { error: 'could not start a voice session' });
  }
});
