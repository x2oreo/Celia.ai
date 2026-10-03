// Phase 3 — /vision-extract on locally generated images (run make_images.py first). At most 4 paid calls.
// The relay returns no usage, so each call is billed at worst case: counted input tokens (free count endpoint,
// 2000 if unavailable) + the full 400-token output cap.
//
//   set -a; source backend/supabase/functions/.env; set +a
//   deno run -A backend/eval/vision-eval.ts

import { addSpend, assertBudget, OUT_DIR, pad, postJson, spent, startFn, textCost, usd } from './lib.ts';

const PHASE = 'vision';
const PHASE_CAP_USD = 0.2;
const MAX_OUTPUT_TOKENS = 400; // vision-extract/index.ts

interface Extracted {
  drugs: { name: string; strength: string; confidence: string }[];
  imageQuality: string;
}

interface VisionCase {
  file: string;
  label: string;
  judge(r: Extracted): string[];
}

const names = (r: Extracted) => r.drugs.map((d) => d.name.toLowerCase()).join(' | ');

const CASES: VisionCase[] = [
  {
    file: '1-klacid.jpg',
    label: 'clear Klacid box',
    judge(r) {
      const f: string[] = [];
      const hit = r.drugs.find((d) => /klacid|clarithromycin/i.test(d.name));
      if (!hit) f.push(`no Klacid/clarithromycin (${names(r)})`);
      else if (!['HIGH', 'MEDIUM'].includes(hit.confidence)) f.push(`confidence ${hit.confidence}`);
      if (r.imageQuality !== 'CLEAR') f.push(`imageQuality ${r.imageQuality}`);
      return f;
    },
  },
  {
    file: '2-klacid-blur.jpg',
    label: 'heavily blurred Klacid box',
    judge(r) {
      return r.imageQuality === 'CLEAR' && r.drugs.length > 0 ? [`CLEAR with names (${names(r)})`] : [];
    },
  },
  {
    file: '3-grocery.jpg',
    label: 'grocery list (not a medicine)',
    judge(r) {
      return r.drugs.length === 0 ? [] : [`returned names: ${names(r)}`];
    },
  },
  {
    file: '4-two-products.jpg',
    label: 'two products (Zofran + Apap)',
    judge(r) {
      const f: string[] = [];
      if (!/zofran|ondansetron/.test(names(r))) f.push('no Zofran');
      if (!/apap|paracetamol/.test(names(r))) f.push('no Apap');
      return f;
    },
  },
];

const RISK_TALK = /safe|risk|danger|avoid|qt|caution|warning/i;

async function countInputTokens(b64: string): Promise<number | undefined> {
  const key = Deno.env.get('OPENAI_API_KEY');
  if (!key) return undefined;
  try {
    const res = await fetch('https://api.openai.com/v1/responses/input_tokens', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: Deno.env.get('OPENAI_VISION_MODEL') ?? Deno.env.get('OPENAI_MODEL') ?? 'gpt-6.1-sol',
        input: [{ role: 'user', content: [{ type: 'input_text', text: 'x'.repeat(600) }, { type: 'input_image', image_url: `data:image/jpeg;base64,${b64}` }] }],
      }),
    });
    if (!res.ok) {
      await res.body?.cancel();
      return undefined;
    }
    return ((await res.json()) as { input_tokens?: number }).input_tokens;
  } catch {
    return undefined;
  }
}

function b64(bytes: Uint8Array): string {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

const limit = Number(Deno.args[0] ?? CASES.length);
console.log(`spend so far ${usd(spent())}\n`);
let failures = 0;
const fn = await startFn('vision-extract');
try {
  for (const c of CASES.slice(0, limit)) {
    assertBudget(PHASE, PHASE_CAP_USD);
    const img = b64(Deno.readFileSync(`${OUT_DIR}images/${c.file}`));
    const counted = await countInputTokens(img);
    const res = await postJson(fn.url, { imageBase64: img });
    const cost = textCost(counted ?? 2000, MAX_OUTPUT_TOKENS);
    addSpend(PHASE, `vision ${c.file}`, cost);
    let fails: string[];
    if (res.status !== 200) {
      fails = [`HTTP ${res.status} ${res.text.slice(0, 100)}`];
    } else {
      const r = JSON.parse(res.text) as Extracted;
      fails = c.judge(r);
      const keys = Object.keys(r).sort().join(',');
      if (keys !== 'drugs,imageQuality') fails.push(`unexpected keys ${keys}`);
      if (r.drugs.some((d) => RISK_TALK.test(`${d.name} ${d.strength}`))) fails.push('risk/safety words in output');
    }
    if (fails.length) failures++;
    console.log(`${fails.length ? 'FAIL' : 'PASS'}  ${pad(c.label, 32)} ${res.ms} ms in~${counted ?? '2000?'} tok ${usd(cost)}  ${res.text}${fails.length ? `  ← ${fails.join('; ')}` : ''}`);
  }
} finally {
  await fn.stop();
}
for (const l of fn.logs) console.log(`  log: ${l.slice(0, 200)}`);
console.log(`\n${failures === 0 ? 'ALL PASS' : `${failures} FAILURE(S)`}; total spend ${usd(spent())}`);
