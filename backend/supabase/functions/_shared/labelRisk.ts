// Deterministic QT-risk rule over an openFDA drug label (api.fda.gov/drug/label.json). No AI.
// Used by /drug-check only for ingredients that are NOT in the curated QT list - the curated list always wins.
// Conservative by design: any QT / torsades wording in a warnings section flags the drug; the label can raise a
// warning but never call a drug "safe" (no wording → NOT_LISTED, which the app shows with lower confidence).

export type LabelRisk = 'KNOWN_RISK' | 'POSSIBLE_RISK' | 'CONDITIONAL_RISK' | 'NOT_LISTED';

export interface FdaLabel {
  set_id?: string;
  boxed_warning?: string[];
  warnings_and_cautions?: string[];
  warnings?: string[];
  precautions?: string[];
  contraindications?: string[];
  adverse_reactions?: string[];
  drug_interactions?: string[];
  overdosage?: string[];
  clinical_pharmacology?: string[];
}

export interface LabelVerdict {
  risk: LabelRisk;
  section: string;   // label section that decided the risk ('' when none)
  snippet: string;   // the matching sentence, ≤ 240 chars ('' when none)
}

type SectionKey = 'boxed_warning' | 'warnings_and_cautions' | 'warnings' | 'precautions' | 'contraindications' |
  'adverse_reactions' | 'drug_interactions' | 'overdosage';

// Checked in this order; the first section with QT wording decides. clinical_pharmacology is deliberately absent:
// "thorough QT study" text there usually reports *no* effect.
const RULES: Array<[SectionKey, LabelRisk]> = [
  ['boxed_warning', 'KNOWN_RISK'],
  ['warnings_and_cautions', 'POSSIBLE_RISK'],
  ['warnings', 'POSSIBLE_RISK'],
  ['precautions', 'POSSIBLE_RISK'],
  ['contraindications', 'POSSIBLE_RISK'],
  ['adverse_reactions', 'CONDITIONAL_RISK'],
  ['drug_interactions', 'CONDITIONAL_RISK'],
  ['overdosage', 'CONDITIONAL_RISK'],
];

const QT_TERMS =
  /\bqtc?\b[\s-]*(interval\s+)?prolong|prolong\w*\s+(the\s+)?qtc?\b|torsades?\s+de\s+pointes|long\s+qt\b/i;
const SNIPPET_MAX = 240;

function snippetAround(text: string, at: number): string {
  // Sentence that contains the match: back to the previous ". " (or a section heading number), forward to the next.
  // Long run-on "sentences" (headings, lists) start at the match itself so the QT wording is always visible.
  const before = text.lastIndexOf('. ', at);
  const sentenceStart = before < 0 ? 0 : before + 2;
  const start = at - sentenceStart > 80 ? at : sentenceStart;
  const after = text.indexOf('. ', at);
  const end = after < 0 ? text.length : after + 1;
  const s = text.slice(start, end).replace(/\s+/g, ' ').trim();
  return s.length > SNIPPET_MAX ? s.slice(0, SNIPPET_MAX).trimEnd() + '…' : s;
}

export function classifyLabel(label: FdaLabel): LabelVerdict {
  for (const [key, risk] of RULES) {
    const text = (label[key] ?? []).join(' ');
    const m = QT_TERMS.exec(text);
    if (m) {
      return { risk, section: key, snippet: snippetAround(text, m.index) };
    }
  }
  return { risk: 'NOT_LISTED', section: '', snippet: '' };
}

const SEVERITY: Record<LabelRisk, number> = { KNOWN_RISK: 3, POSSIBLE_RISK: 2, CONDITIONAL_RISK: 1, NOT_LISTED: 0 };

// One ingredient usually has many labels (brands, generics, OTC). Worst one wins; ties keep the first.
export function worstLabel(labels: FdaLabel[]): LabelVerdict & { setId: string } {
  let best: LabelVerdict & { setId: string } = { risk: 'NOT_LISTED', section: '', snippet: '', setId: '' };
  for (const l of labels) {
    const v = classifyLabel(l);
    if (best.setId === '' || SEVERITY[v.risk] > SEVERITY[best.risk]) {
      best = { ...v, setId: l.set_id ?? '' };
    }
  }
  return best;
}
