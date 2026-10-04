// Shared contract - see docs/ARCHITECTURE.md. Change it there first, then here, in the same commit.

export type Genotype = 'LQT1' | 'LQT2' | 'LQT3' | 'UNKNOWN';

export type Condition = 'LQTS';

export type Sex = 'FEMALE' | 'MALE' | 'OTHER';

// Anything else the user wants a first responder to know, e.g. { label: 'Pacemaker', value: 'none' }.
export interface ExtraField {
  label: string;
  value: string;
}

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
  country?: string;       // ISO 3166-1 alpha-2, e.g. 'PL' - picks the emergency number
  cardLanguage?: string;  // language code of the emergency card, e.g. 'en', 'pl', 'bg'
  // Emergency details (Workstream B4). All optional: profiles saved before them still load.
  dateOfBirth?: string;        // ISO date 'YYYY-MM-DD'
  sex?: Sex;
  bloodType?: string;          // one of BLOOD_TYPES
  allergies?: string[];
  icdModel?: string;           // only meaningful when hasIcd
  cardiologistName?: string;
  cardiologistPhone?: string;
  hospital?: string;
  extra?: ExtraField[];
  hiddenOnCard?: string[];     // CardField ids the user switched off for the shared card
  updatedAt?: number;          // ms epoch of the last local edit; profile sync is last-write-wins on it
}

export const BLOOD_TYPES: string[] = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'];

// Ids of the emergency-card fields the user can hide from the shared card (Profile.hiddenOnCard).
export class CardField {
  static readonly NAME: string = 'name';
  static readonly DATE_OF_BIRTH: string = 'dob';
  static readonly SEX: string = 'sex';
  static readonly BLOOD_TYPE: string = 'blood';
  static readonly ALLERGIES: string = 'allergies';
  static readonly ICD_MODEL: string = 'icdModel';
  static readonly CARDIOLOGIST: string = 'cardiologist';
  static readonly HOSPITAL: string = 'hospital';
  static readonly CONTACTS: string = 'contacts';
  static readonly NOTES: string = 'notes';
  static readonly EXTRA: string = 'extra';
}
