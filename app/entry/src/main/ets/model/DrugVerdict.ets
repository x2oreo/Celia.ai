// Shared contract — see docs/ARCHITECTURE.md.
// Verdicts are deterministic (curated dataset). The LLM may only explain them.

export type RiskLevel = 'KNOWN_RISK' | 'POSSIBLE_RISK' | 'CONDITIONAL_RISK' | 'NOT_LISTED' | 'UNKNOWN_DRUG';

export interface DrugVerdict {
  query: string;        // what the user typed / OCR text
  ingredient: string;   // resolved INN, '' if unknown
  risk: RiskLevel;
  reason: string;       // short deterministic reason from the dataset
  source: string;       // e.g. 'Curated from CredibleMeds categories (cited)'
}
