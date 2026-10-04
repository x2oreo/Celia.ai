// Rate limit for the OpenAI-backed functions. The anon key ships in the app, so without this anyone could spend the
// project's OpenAI budget in a loop. Two buckets per call: the caller (salted hash of the client address) and the
// whole project per day (a hard cost ceiling). Counted in Postgres (ai_rate_take) so every function instance shares
// them; if the database cannot be reached, an in-memory limit per instance still applies.

import { clientIp } from './clientIp.ts';
import { json } from './openai.ts';

export interface AiLimit {
  fn: string;          // bucket name, e.g. 'agent'
  perCaller: number;   // calls per caller per window
  windowSec: number;
}

const DAY_SEC = 24 * 3600;

class MemoryLimiter {
  private hits = new Map<string, { start: number; count: number }>();

  allow(key: string, max: number, windowMs: number, now: number): boolean {
    const h = this.hits.get(key);
    if (h === undefined || now - h.start >= windowMs) {
      if (this.hits.size > 10_000) this.hits.clear();   // bounded memory
      this.hits.set(key, { start: now, count: 1 });
      return true;
    }
    h.count++;
    return h.count <= max;
  }
}

const memory = new MemoryLimiter();

async function callerHash(req: Request): Promise<string> {
  const salt = Deno.env.get('RATE_LIMIT_SALT') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const bytes = new TextEncoder().encode(`${salt}|${clientIp(req.headers)}`);
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
  return Array.from(digest.slice(0, 16), (b) => b.toString(16).padStart(2, '0')).join('');
}

async function take(bucket: string, max: number, windowSec: number): Promise<boolean> {
  const url = Deno.env.get('SUPABASE_URL') ?? '';
  // Hosted functions get SUPABASE_SERVICE_ROLE_KEY injected; the local dev backend's .env names it SUPABASE_SECRET_KEY.
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY') ?? '';
  if (url !== '' && key !== '') {
    try {
      const res = await fetch(`${url}/rest/v1/rpc/ai_rate_take`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: key, Authorization: `Bearer ${key}` },
        body: JSON.stringify({ p_bucket: bucket, p_max: max, p_window_seconds: windowSec }),
        signal: AbortSignal.timeout(2000),
      });
      if (res.ok) return (await res.json()) === true;
      console.error(JSON.stringify({ fn: 'rateLimit', status: res.status }));
    } catch (err) {
      console.error(JSON.stringify({ fn: 'rateLimit', error: String(err) }));
    }
  }
  return memory.allow(bucket, max, windowSec * 1000, Date.now());
}

// Returns a 429 response when the caller or the project is over its limit, else null (go ahead).
export async function aiRateLimit(req: Request, limit: AiLimit): Promise<Response | null> {
  const caller = await callerHash(req);
  if (!await take(`${limit.fn}:${caller}`, limit.perCaller, limit.windowSec)) {
    return json(429, { error: 'too many requests, try again later' });
  }
  const daily = Number(Deno.env.get('AI_DAILY_CAP') ?? '5000');
  if (!await take('ai:project', Number.isFinite(daily) && daily > 0 ? daily : 5000, DAY_SEC)) {
    return json(429, { error: 'AI is busy, try again later' });
  }
  return null;
}
