// Onboarding flow (Workstream B3): the 8 steps, which ones can be skipped, when Continue is allowed, and the profile
// draft helpers. Pure functions only, so the whole flow is unit-tested (test/Onboarding.test.ets).

import { Contact, Genotype, Profile } from '../model/Profile';

export class OnbStep {
  static readonly WELCOME: number = 0;      // what the app is + "not a medical device" consent
  static readonly ACCOUNT: number = 1;      // sign up / log in (components/AuthForm.ets)
  static readonly ABOUT: number = 2;        // name, date of birth, genotype, ICD + model
  static readonly MEDS: number = 3;         // components/AddMedForm.ets, each one checked by DrugChecker
  static readonly CONTACTS: number = 4;     // emergency contacts
  static readonly DETAILS: number = 5;      // country + components/EmergencyDetailsForm.ets
  static readonly PERMISSIONS: number = 6;  // notifications, microphone, location
  static readonly WATCH: number = 7;        // pair a watch (route pairWatch)
}

export const STEP_COUNT: number = 8;

export const GENOTYPES: Genotype[] = ['LQT1', 'LQT2', 'LQT3', 'UNKNOWN'];

// Everything after the consent and "about you" can be skipped and done later in Settings.
export function isOptional(step: number): boolean {
  return step === OnbStep.ACCOUNT || step === OnbStep.MEDS || step === OnbStep.CONTACTS ||
    step === OnbStep.DETAILS || step === OnbStep.PERMISSIONS || step === OnbStep.WATCH;
}

export function canContinue(step: number, consented: boolean, profile: Profile): boolean {
  if (step === OnbStep.WELCOME) {
    return consented;
  }
  if (step === OnbStep.ABOUT) {
    const dob: string | undefined = profile.dateOfBirth;
    return dob === undefined || dob === '' || parseIsoDate(dob) !== undefined;
  }
  return true;
}

export function nextStep(step: number): number {
  return Math.min(step + 1, STEP_COUNT - 1);
}

export function prevStep(step: number): number {
  return Math.max(step - 1, 0);
}

export function isLastStep(step: number): boolean {
  return step === STEP_COUNT - 1;
}

// After AuthForm reports a sign-in: a profile restored from the account means the user already onboarded once,
// so the rest is skipped (B3 acceptance: "a returning user who signs in skips to the app").
export function shouldFinishAfterSignIn(signedIn: boolean, restored: Profile | undefined): boolean {
  return signedIn && restored !== undefined;
}

export function newProfile(country: string): Profile {
  const p: Profile = {
    condition: 'LQTS',
    genotype: 'UNKNOWN',
    hasIcd: false,
    notes: '',
    contacts: [],
    country: country,
    cardLanguage: 'en'
  };
  return p;
}

// A field-by-field copy (ArkTS has no object spread). Steps change the copy and hand it back with onChange, so the
// page re-renders and the single draft stays the only source of truth.
export function copyProfile(p: Profile): Profile {
  const c: Profile = {
    condition: p.condition,
    genotype: p.genotype,
    hasIcd: p.hasIcd,
    notes: p.notes,
    contacts: p.contacts.slice(),
    name: p.name,
    country: p.country,
    cardLanguage: p.cardLanguage,
    dateOfBirth: p.dateOfBirth,
    sex: p.sex,
    bloodType: p.bloodType,
    allergies: p.allergies === undefined ? undefined : p.allergies.slice(),
    icdModel: p.icdModel,
    cardiologistName: p.cardiologistName,
    cardiologistPhone: p.cardiologistPhone,
    hospital: p.hospital,
    extra: p.extra === undefined ? undefined : p.extra.slice(),
    hiddenOnCard: p.hiddenOnCard === undefined ? undefined : p.hiddenOnCard.slice(),
    updatedAt: p.updatedAt
  };
  return c;
}

export function validPhone(phone: string): boolean {
  return phone.replace(/[^0-9]/g, '').length >= 6;
}

export function validContact(name: string, phone: string): boolean {
  return name.trim().length > 0 && validPhone(phone);
}

export function withContact(p: Profile, name: string, phone: string, relation: string): Profile {
  const next: Profile = copyProfile(p);
  if (!validContact(name, phone)) {
    return next;
  }
  const c: Contact = { name: name.trim(), phone: phone.trim(), relation: relation.trim() };
  next.contacts = next.contacts.concat([c]);
  return next;
}

export function withoutContact(p: Profile, index: number): Profile {
  const next: Profile = copyProfile(p);
  next.contacts = next.contacts.filter((c: Contact, i: number) => i !== index);
  return next;
}

// Takes only the emergency-details fields (B4) from EmergencyDetailsForm's output, so that form can never change
// what the other steps own (genotype, contacts, country, ...).
export function withDetails(draft: Profile, fromForm: Profile): Profile {
  const next: Profile = copyProfile(draft);
  const f: Profile = copyProfile(fromForm);
  next.dateOfBirth = f.dateOfBirth;
  next.sex = f.sex;
  next.bloodType = f.bloodType;
  next.allergies = f.allergies;
  next.icdModel = f.icdModel;
  next.cardiologistName = f.cardiologistName;
  next.cardiologistPhone = f.cardiologistPhone;
  next.hospital = f.hospital;
  next.extra = f.extra;
  next.hiddenOnCard = f.hiddenOnCard;
  next.notes = f.notes;
  return next;
}

// 'YYYY-MM-DD' in local time, the format of Profile.dateOfBirth.
export function isoDate(d: Date): string {
  const m: number = d.getMonth() + 1;
  const day: number = d.getDate();
  return `${d.getFullYear()}-${m < 10 ? '0' : ''}${m}-${day < 10 ? '0' : ''}${day}`;
}

export function parseIsoDate(s: string): Date | undefined {
  const match: RegExpMatchArray | null = s.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (match === null) {
    return undefined;
  }
  const y: number = Number(match[1]);
  const m: number = Number(match[2]);
  const day: number = Number(match[3]);
  const d: Date = new Date(y, m - 1, day);
  if (d.getFullYear() !== y || d.getMonth() !== m - 1 || d.getDate() !== day) {
    return undefined; // e.g. 2001-02-30
  }
  return d.getTime() > Date.now() ? undefined : d;
}

// The profile that gets saved: trimmed text, empty strings dropped, no ICD model without an ICD.
export function finalProfile(draft: Profile): Profile {
  const p: Profile = copyProfile(draft);
  const name: string = (p.name ?? '').trim();
  p.name = name === '' ? undefined : name;
  p.notes = p.notes.trim();
  const model: string = (p.icdModel ?? '').trim();
  p.icdModel = p.hasIcd && model !== '' ? model : undefined;
  if (p.dateOfBirth !== undefined && parseIsoDate(p.dateOfBirth) === undefined) {
    p.dateOfBirth = undefined;
  }
  if (p.cardLanguage === undefined || p.cardLanguage === '') {
    p.cardLanguage = 'en';
  }
  return p;
}
