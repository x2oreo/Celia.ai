// Text normalisation for the safety regexes (SafetyGate, ResponseValidator, the realtime streaming check).
// Models, Realtime transcripts and phone keyboards write typographic apostrophes ("it’s", "can’t"); the patterns
// are written with ASCII ones. Without this, "It’s safe for you" and "I can’t breathe" slip past the checks.

const TYPOGRAPHIC_APOSTROPHES: RegExp = /[‘’ʼ′]/g;

export function normalizeText(text: string): string {
  return text.toLowerCase().replace(TYPOGRAPHIC_APOSTROPHES, '\'');
}

// Our copy never uses em dashes (docs/design/DESIGN.md, Voice); the model sometimes writes them anyway.
const EM_DASH: RegExp = /\u2014/g;

export function plainDashes(text: string): string {
  return text.replace(EM_DASH, '-');
}
