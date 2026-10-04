// POST /functions/v1/med-info - plain-language explanation of what a medicine is, for the medicine detail sheet.
// The model ONLY explains what the medicine is, what it contains and general patient-leaflet tips. It never judges
// heart / QT safety and never gives doses: the app's verdict comes from its own dataset and is shown separately.
// No personal data is sent - only the medicine name (and its active ingredient when the app knows it).
// Request: { medicine, ingredient }. Response: { recognised, summary, contains, usedFor, tips[], dropped? }.

import { env, json, openaiJson, outputText } from '../_shared/openai.ts';
import { cleanReply, MAX_TIPS, MedInfo } from './logic.ts';

const MAX_NAME = 80;

const PROMPT = `You explain medicines to patients in plain, short English, like a friendly pharmacist leaflet.
Given a medicine name (a brand or an active ingredient), return:
- summary: one or two sentences saying what kind of medicine this is.
- contains: the active ingredient(s) and, if typical, the usual forms (tablet, syrup...). No doses.
- usedFor: what it is commonly used for, as a short phrase.
- tips: up to 3 general everyday tips from patient leaflets (food, alcohol, drowsiness, timing, storage).
Hard rules: Do NOT say whether it is safe for the heart or for long QT, do NOT mention QT, torsades or arrhythmia
risk, do NOT give doses or tell the user to start or stop anything. If you do not recognise the name as a real
medicine, set recognised to false and leave the other fields empty. Never use em dashes (the long dash); use a normal
dash "-" instead.`;

const SCHEMA = {
  type: 'object',
  properties: {
    recognised: { type: 'boolean' },
    summary: { type: 'string' },
    contains: { type: 'string' },
    usedFor: { type: 'string' },
    tips: { type: 'array', maxItems: MAX_TIPS, items: { type: 'string' } },
  },
  required: ['recognised', 'summary', 'contains', 'usedFor', 'tips'],
  additionalProperties: false,
};

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') return json(405, { error: 'POST only' });
  const started = Date.now();
  let name: string;
  let ingredient: string;
  try {
    const body = await req.json() as { medicine?: unknown; ingredient?: unknown };
    if (typeof body.medicine !== 'string' || body.medicine.trim() === '') throw new Error('medicine required');
    if (body.medicine.length > MAX_NAME) throw new Error('medicine too long');
    if (body.ingredient !== undefined && typeof body.ingredient !== 'string') throw new Error('ingredient invalid');
    name = body.medicine.trim();
    ingredient = typeof body.ingredient === 'string' ? body.ingredient.trim().slice(0, MAX_NAME) : '';
  } catch (err) {
    return json(400, { error: `bad request: ${(err as Error).message}` });
  }

  try {
    const res = await openaiJson<{ output?: { type: string; content?: { type: string; text?: string }[] }[] }>(
      '/responses',
      {
        model: env('OPENAI_MODEL', 'gpt-6.1-sol'),
        reasoning: { effort: 'low' },
        input: [
          { role: 'system', content: PROMPT },
          { role: 'user', content: ingredient === '' ? `Medicine: ${name}` : `Medicine: ${name} (${ingredient})` },
        ],
        text: { format: { type: 'json_schema', name: 'medicine_info', schema: SCHEMA, strict: true } },
        max_output_tokens: 500,
      },
      20000,
    );
    const p = JSON.parse(outputText(res)) as Partial<MedInfo>;
    const out = cleanReply(p);
    if (out === undefined) {
      // dropped: the model recognised the medicine but the reply broke a safety rule (the app says so honestly).
      const dropped = p.recognised === true;
      console.log(JSON.stringify({ fn: 'med-info', recognised: p.recognised === true, dropped, ms: Date.now() - started }));
      return json(200, { recognised: false, dropped, summary: '', contains: '', usedFor: '', tips: [] });
    }
    console.log(JSON.stringify({ fn: 'med-info', recognised: true, ms: Date.now() - started }));
    return json(200, out);
  } catch (err) {
    console.error(JSON.stringify({ fn: 'med-info', error: String(err), ms: Date.now() - started }));
    return json(502, { error: 'explanation failed' });
  }
});
