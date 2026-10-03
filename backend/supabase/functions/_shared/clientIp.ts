// Client address for rate limits and anonymous vote counting. cf-connecting-ip is set by the edge; otherwise the
// LAST x-forwarded-for hop (the first one is client-supplied and spoofable). Unknown callers share one bucket, so a
// missing header never fails open.
export function clientIp(h: Headers): string {
  const cf = (h.get('cf-connecting-ip') ?? '').trim();
  if (cf !== '') return cf;
  const hops = (h.get('x-forwarded-for') ?? '').split(',').map((s) => s.trim()).filter((s) => s !== '');
  return hops.length > 0 ? hops[hops.length - 1] : 'unknown';
}
