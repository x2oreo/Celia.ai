// Shared contract — see docs/ARCHITECTURE.md. Change it there first, then here, in the same commit.

export type Genotype = 'LQT1' | 'LQT2' | 'LQT3' | 'UNKNOWN';

export type Condition = 'LQTS';

export interface Contact {
  name: string;
  phone: string;
  relation: string;
}

export interface Profile {
  condition: Condition;   // only LQTS in MVP; condition packs later
  genotype: Genotype;
  hasIcd: boolean;        // implanted defibrillator
  notes: string;          // free text for the emergency card
  contacts: Contact[];
}
