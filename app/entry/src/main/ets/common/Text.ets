// Text normalisation for the safety regexes (SafetyGate, ResponseValidator, the realtime streaming check).
// Models, Realtime transcripts and phone keyboards write typographic apostrophes ("it’s", "can’t"); the patterns
// are written with ASCII ones. Without this, "It’s safe for you" and "I can’t breathe" slip past the checks.

const TYPOGRAPHIC_APOSTROPHES: RegExp = /[‘’ʼ′]/g;

export function normalizeText(text: string): string {
  return text.toLowerCase().replace(TYPOGRAPHIC_APOSTROPHES, '\'');
}
