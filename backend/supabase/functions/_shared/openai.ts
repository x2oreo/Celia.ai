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

// OpenAI error code from an error response ('invalid_api_key', 'model_not_found', …), or 'unknown'.
async function errorCode(res: Response): Promise<string> {
  try {
    const body = await res.json() as { error?: { code?: string | null; type?: string } };
    return body.error?.code ?? body.error?.type ?? 'unknown';
  } catch {
    return 'unknown';
  }
}

// Raw call to OpenAI with a hard timeout (JSON, multipart or binary). Throws UpstreamError on non-2xx or timeout.
export async function openaiFetch(path: string, init: RequestInit, timeoutMs: number): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const headers = new Headers(init.headers);
  headers.set('Authorization', `Bearer ${env('OPENAI_API_KEY')}`);
  try {
    const res = await fetch(`${OPENAI_BASE}${path}`, { ...init, headers, signal: controller.signal });
    if (!res.ok) {
      // Log only the status and OpenAI's error code. The body can echo request details (e.g. a masked key).
      throw new UpstreamError(res.status, `OpenAI ${path} ${res.status} ${await errorCode(res)}`);
    }
    // Read the body inside the timeout window.
    const body = await res.arrayBuffer();
    return new Response(body, { status: res.status, headers: res.headers });
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

// POST JSON to OpenAI and parse the JSON response.
export async function openaiJson<T>(path: string, body: unknown, timeoutMs: number): Promise<T> {
  const res = await openaiFetch(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  }, timeoutMs);
  return (await res.json()) as T;
}

// Concatenated output_text of a Responses API result.
export function outputText(res: { output?: { type: string; content?: { type: string; text?: string }[] }[] }): string {
  let text = '';
  for (const item of res.output ?? []) {
    if (item.type !== 'message') continue;
    for (const part of item.content ?? []) {
      if (part.type === 'output_text' && part.text) text += part.text;
    }
  }
  return text;
}

export function decodeBase64(b64: string): Uint8Array<ArrayBuffer> {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
