// Minimal OpenAI client over fetch (no SDK — keeps the Edge Function small and the dependency list empty).
// The key is read from Supabase secrets: `supabase secrets set OPENAI_API_KEY=...`. It never reaches the app.

const OPENAI_BASE = 'https://api.openai.com/v1';

export function env(name: string, fallback?: string): string {
  const value = Deno.env.get(name) ?? fallback;
  if (value === undefined || value === '') {
    throw new Error(`Missing env ${name}`);
  }
  return value;
}

export class UpstreamError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

// POST JSON to OpenAI with a hard timeout. Throws UpstreamError on non-2xx or timeout.
export async function openaiJson<T>(path: string, body: unknown, timeoutMs: number): Promise<T> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(`${OPENAI_BASE}${path}`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env('OPENAI_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    if (!res.ok) {
      const detail = (await res.text()).slice(0, 500);
      throw new UpstreamError(res.status, `OpenAI ${path} ${res.status}: ${detail}`);
    }
    return (await res.json()) as T;
  } catch (err) {
    if (err instanceof UpstreamError) throw err;
    if (err instanceof DOMException && err.name === 'AbortError') {
      throw new UpstreamError(504, `OpenAI ${path} timed out after ${timeoutMs} ms`);
    }
    throw new UpstreamError(502, `OpenAI ${path} failed: ${String(err)}`);
  } finally {
    clearTimeout(timer);
  }
}

export function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
