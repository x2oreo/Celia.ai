// Pure rules for the shared box_cache (unit-tested in cache.test.ts). The cache feeds ingredients into the
// deterministic QT check for every user, so what may be served, overwritten or confirmed is decided here.

export const CACHE_TTL_MS = 30 * 24 * 3600 * 1000;   // like label_cache: sources change, so rows are re-checked
export const AI_CONFIRMATIONS_NEEDED = 2;            // distinct devices before an AI web answer is shared

export interface CacheRow {
  method: string;   // 'REGISTRY' | 'PRODUCT_DB' | 'AI_WEB'
  brand: string;
  ingredients: string[];
  confirmations: number;
  updated_at?: string;
}

export function isFresh(row: CacheRow, now: number): boolean {
  const t = Date.parse(row.updated_at ?? '');
  return Number.isFinite(t) && now - t < CACHE_TTL_MS;
}

// Serve to everyone: deterministic sources while fresh; AI answers only after enough distinct confirmations.
export function servable(row: CacheRow, now: number): boolean {
  if (!isFresh(row, now)) return false;
  return row.method !== 'AI_WEB' || row.confirmations >= AI_CONFIRMATIONS_NEEDED;
}

function sameAnswer(a: CacheRow, b: { brand: string; ingredients: string[] }): boolean {
  const norm = (l: string[]) => l.map((s) => s.trim().toLowerCase()).sort().join('|');
  return a.brand.trim().toLowerCase() === b.brand.trim().toLowerCase() && norm(a.ingredients) === norm(b.ingredients);
}

// What a new AI answer may do to the existing row: never replace a deterministic or a confirmed row; a different
// unconfirmed answer replaces it with its confirmations reset to 0.
export function aiWrite(row: CacheRow | null, next: { brand: string; ingredients: string[] }):
  { write: boolean; confirmations: number } {
  if (row === null) return { write: true, confirmations: 0 };
  if (row.method !== 'AI_WEB' || row.confirmations > 0) return { write: false, confirmations: row.confirmations };
  return { write: true, confirmations: sameAnswer(row, next) ? row.confirmations : 0 };
}

// The client's product-database name, made safe to show the model as quoted data: letters, digits, spaces and
// . - / % only, at most 80 characters.
export function cleanHint(raw: unknown): string {
  return String(raw ?? '').normalize('NFKC').replace(/[^\p{L}\p{N} .\-/%]/gu, '').replace(/\s+/g, ' ').trim()
    .slice(0, 80);
}
