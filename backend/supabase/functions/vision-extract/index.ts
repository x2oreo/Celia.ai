// POST /functions/v1/vision-extract — fallback when on-device OCR finds no known medicine on a box photo.
// The model ONLY reads medicine names off the image; it never judges risk. Every name it returns goes through
// DrugChecker on the device and the user confirms the drug before seeing a verdict.
// Request: { imageBase64: <JPEG> }. Response: { drugs: [{ name, strength, confidence }], imageQuality }.

import { env, json, openaiJson, outputText } from '../_shared/openai.ts';

const MAX_IMAGE_BYTES = 4_000_000;

const PROMPT = `You read medicine packaging for a pharmacy app.
List every medicine name printed on the package: the brand name and, if printed, the active ingredient (INN).
Include the strength if printed (e.g. "500 mg"). Do NOT guess names that are not visible. Do NOT judge safety.
confidence: HIGH = clearly legible, MEDIUM = partly legible, LOW = guess.
If this is not a medicine package or nothing is legible, return an empty list with imageQuality UNREADABLE.`;

const SCHEMA = {
  type: 'object',
  properties: {
    drugs: {
      type: 'array',
      maxItems: 5,
      items: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Brand or active ingredient exactly as printed' },
          strength: { type: ['string', 'null'] },
          confidence: { type: 'string', enum: ['HIGH', 'MEDIUM', 'LOW'] },
        },
        required: ['name', 'strength', 'confidence'],
        additionalProperties: false,
      },
    },
    imageQuality: { type: 'string', enum: ['CLEAR', 'PARTIAL', 'UNREADABLE'] },
  },
  required: ['drugs', 'imageQuality'],
  additionalProperties: false,
};

interface Extracted {
  drugs: { name: string; strength: string | null; confidence: string }[];
  imageQuality: string;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') return json(405, { error: 'POST only' });
  const started = Date.now();
  let image: string;
  try {
    const body = await req.json() as { imageBase64?: unknown };
    if (typeof body.imageBase64 !== 'string' || body.imageBase64.length === 0) throw new Error('imageBase64 required');
    if (body.imageBase64.length * 0.75 > MAX_IMAGE_BYTES) throw new Error('image too large');
    image = body.imageBase64;
  } catch (err) {
    return json(400, { error: `bad request: ${(err as Error).message}` });
  }

  try {
    const res = await openaiJson<{ output?: { type: string; content?: { type: string; text?: string }[] }[] }>(
      '/responses',
      {
        model: env('OPENAI_VISION_MODEL', env('OPENAI_MODEL', 'gpt-6.1-sol')),
        reasoning: { effort: 'low' },
        input: [{
          role: 'user',
          content: [
            { type: 'input_text', text: PROMPT },
            { type: 'input_image', image_url: `data:image/jpeg;base64,${image}` },
          ],
        }],
        text: { format: { type: 'json_schema', name: 'medicine_names', schema: SCHEMA, strict: true } },
        max_output_tokens: 400,
      },
      20000,
    );
    const parsed = JSON.parse(outputText(res)) as Extracted;
    // Drop guesses; the device re-validates names against the drug list anyway.
    const drugs = parsed.drugs
      .filter((d) => d.confidence !== 'LOW' && d.name.trim() !== '')
      .map((d) => ({ name: d.name.trim().slice(0, 80), strength: d.strength ?? '', confidence: d.confidence }));
    console.log(JSON.stringify({ fn: 'vision-extract', found: drugs.length, quality: parsed.imageQuality, ms: Date.now() - started }));
    return json(200, { drugs, imageQuality: parsed.imageQuality });
  } catch (err) {
    console.error(JSON.stringify({ fn: 'vision-extract', error: String(err), ms: Date.now() - started }));
    return json(502, { error: 'extraction failed' }); // upstream failures are never the app's fault
  }
});
