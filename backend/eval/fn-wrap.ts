// Runs one Edge Function on FN_PORT instead of Deno.serve's default port 8000. Used by dev-backend.ts.
const port = Number(Deno.env.get('FN_PORT'));
const serve = Deno.serve.bind(Deno);
// deno-lint-ignore no-explicit-any
(Deno as any).serve = (handler: Deno.ServeHandler) => serve({ port, hostname: '127.0.0.1' }, handler);
await import(Deno.env.get('FN_PATH')!);
