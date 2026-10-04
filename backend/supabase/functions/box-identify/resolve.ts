// Raw source hit → candidate with English ingredient names RxNav knows. Deterministic except the optional LLM
// translation of foreign INN text ("VALPROATO SODIO" → "valproate sodium"), whose output is only kept when RxNav
// resolves it. A name nobody can resolve is passed on unchanged, so /drug-check answers UNKNOWN_DRUG for it -
// an unidentified ingredient can never silently disappear from the check.

import type { RawHit } from './sources.ts';

export type Method = 'CACHE' | 'REGISTRY' | 'PRODUCT_DB' | 'AI_WEB';

export interface Candidate {
  gtin: string;
  brand: string;
  ingredients: string[];   // English INNs (lower case); unresolved names kept as printed
  unresolved: string[];    // subset of ingredients RxNav could not confirm
  strength: string;
  form: string;
  country: string;
  method: Method;
  source: string;
  sourceUrl: string;
  confirmations: number;
}

export interface ResolveDeps {
  normalise(name: string): Promise<string[]>;                 // RxNav: name → ingredients ([] = unknown)
  translate: ((names: string[]) => Promise<string[]>) | null;  // LLM INN translation, null when no AI key
}

async function resolveOne(raw: string, english: boolean, deps: ResolveDeps): Promise<string[] | null> {
  const direct = await deps.normalise(raw);
  if (direct.length > 0) {
    return direct;
  }
  if (!english && deps.translate) {
    const [t] = await deps.translate([raw]);
    if (t) {
      const viaTranslation = await deps.normalise(t);
      if (viaTranslation.length > 0) {
        return viaTranslation;
      }
    }
  }
  return null;
}

// null when the hit cannot give us any ingredient at all (then the caller tries the next stage).
export async function resolveHit(hit: RawHit, gtin: string, country: string, deps: ResolveDeps):
  Promise<Candidate | null> {
  let ingredients: string[] = [];
  const unresolved: string[] = [];
  if (hit.ingredients.length > 0) {
    const results = await Promise.all(hit.ingredients.map((r) => resolveOne(r, hit.english, deps)));
    results.forEach((names, i) => {
      if (names) {
        ingredients.push(...names);
      } else {
        const raw = hit.ingredients[i].toLowerCase();
        ingredients.push(raw);
        unresolved.push(raw);
      }
    });
  } else {
    // Name-only source (e.g. Open Food Facts): the brand itself must resolve, e.g. "Tylenol extra strength".
    ingredients = await deps.normalise(hit.brand);
    if (ingredients.length === 0) {
      return null;
    }
  }
  if (unresolved.length === ingredients.length) {
    return null;   // nothing confirmed - not worth asking the user about
  }
  return {
    gtin, brand: hit.brand, ingredients: [...new Set(ingredients)], unresolved, strength: hit.strength,
    form: hit.form, country, method: hit.method, source: hit.source, sourceUrl: hit.sourceUrl, confirmations: 0,
  };
}
