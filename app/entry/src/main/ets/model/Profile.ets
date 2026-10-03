// Shared contract — see docs/ARCHITECTURE.md. Change it there first, then here, in the same commit.

export type Genotype = 'LQT1' | 'LQT2' | 'LQT3' | 'UNKNOWN';

export type Condition = 'LQTS';

export interface Contact {
  name: string;
  phone: string;
  relation: string;
  email?: string;         // optional (F-34)
}

export interface Profile {
  condition: Condition;   // only LQTS in MVP; condition packs later
  genotype: Genotype;
  hasIcd: boolean;        // implanted defibrillator
  notes: string;          // free text for the emergency card
  contacts: Contact[];
  // Optional extras (F-26, F-29, F-34). Absent on profiles saved by older code.
  name?: string;          // shown on the emergency card
  country?: string;       // ISO 3166-1 alpha-2, e.g. 'PL' — picks the emergency number
  cardLanguage?: string;  // language code of the emergency card, e.g. 'en', 'pl', 'bg'
}
