// Shared contract - see docs/ARCHITECTURE.md.
// Verdicts are deterministic (curated dataset). The LLM may only explain them.

export type RiskLevel = 'KNOWN_RISK' | 'POSSIBLE_RISK' | 'CONDITIONAL_RISK' | 'NOT_LISTED' | 'UNKNOWN_DRUG';

// One step of how a verdict was found ("How we know" on the verdict card).
export type LookupStepKind = 'EXACT' | 'ALIAS' | 'TYPO' | 'NOT_FOUND' | 'ONLINE' | 'LABEL';   // LABEL: FDA label QT rule (server)

export interface LookupStep {
  kind: LookupStepKind;
  token: string;        // the word from the query this step is about
  detail: string;       // e.g. "Klacid → clarithromycin"
}

// Interaction with the user's current medicines. Deterministic rules only (DrugChecker.checkCombo).
export type ComboKind = 'NONE' | 'ADDITIVE_QT' | 'CYP_INTERACTION';

export interface ComboVerdict {
  kind: ComboKind;
  drugs: string[];      // ingredients involved, the checked one first
  enzyme: string;       // e.g. 'CYP3A4', '' for ADDITIVE_QT / NONE
  reason: string;
}

export interface DrugVerdict {
  query: string;        // what the user typed / scanned
  ingredient: string;   // resolved INN, '' if unknown
  risk: RiskLevel;
  reason: string;       // short deterministic reason from the dataset
  source: string;       // e.g. 'Curated from CredibleMeds categories (cited)'
  // Optional extras (F-20, F-21). Absent on verdicts built by older code.
  confidence?: number;  // 0..1 - 1 exact name, lower for typo matches, 0 for unknown
  trace?: LookupStep[];
  alternatives?: string[];   // curated NOT_LISTED ingredients to ask the doctor about
}
