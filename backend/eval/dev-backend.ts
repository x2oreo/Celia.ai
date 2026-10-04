// Local backend for testing the app on the emulator without deploying: starts the AI Edge Functions and serves
// them at http://127.0.0.1:8000/functions/v1/<name>, the same paths the app calls on Supabase.
// Calls go to the real OpenAI API and cost money. See the root README → "Run the backend locally for the emulator".
const FN_DIR = new URL('../supabase/functions/', import.meta.url).pathname;
const WRAP = new URL('./fn-wrap.ts', import.meta.url).pathname;
// drug-check and box-identify need the Supabase database (label/box caches), so they are not served here.
const names = ['agent', 'transcribe', 'speak', 'vision-extract', 'box-identify', 'drug-check', 'med-info', 'doctor-summary', 'realtime-session', 'share'];
const ports: Record<string, number> = {};
const children: Deno.ChildProcess[] = [];

names.forEach((name, i) => {
  ports[name] = 8101 + i;
  children.push(new Deno.Command(Deno.execPath(), {
    args: ['run', '--allow-net', '--allow-env', '--allow-read', WRAP],
    env: { ...Deno.env.toObject(), FN_PORT: String(ports[name]), FN_PATH: `${FN_DIR}${name}/index.ts` },
  }).spawn());
});

Deno.addSignalListener('SIGINT', () => {
  for (const c of children) {
    try {
      c.kill('SIGTERM');
    } catch { /* already gone */ }
  }
  Deno.exit(0);
});

Deno.serve({ port: 8000, hostname: '127.0.0.1' }, async (req) => {
  const m = new URL(req.url).pathname.match(/^\/functions\/v1\/([a-z-]+)$/);
  const port = m ? ports[m[1]] : undefined;
  if (port === undefined) return new Response('not found', { status: 404 });
  const t0 = Date.now();
  const res = await fetch(`http://127.0.0.1:${port}/${new URL(req.url).search}`, { method: req.method, headers: req.headers, body: req.body });
  console.log(`${m![1]} ${res.status} ${Date.now() - t0}ms`);
  return res;
});
