// Emergency details (Workstream B4): pure helpers shared by the editor, the emergency card, the share payload and
// the first-responder view. The card shows the fields in one fixed order, hides empty ones, and leaves out the
// ones the user switched off (Profile.hiddenOnCard, ids from CardField).

import { CardField, Contact, ExtraField, Profile } from '../model/Profile';
import { CardLabels } from '../common/CardStrings';
import { ageYears } from './Responder';

export interface CardRow {
  id: string;      // CardField id
  label: string;
  value: string;
}

// The order every surface uses (card in the app, web card, responder view). Name, contacts and notes keep their own
// places on the card; this is the list of the B4 detail fields.
export const DETAIL_ORDER: string[] = [
  CardField.DATE_OF_BIRTH, CardField.SEX, CardField.BLOOD_TYPE, CardField.ALLERGIES, CardField.ICD_MODEL,
  CardField.CARDIOLOGIST, CardField.HOSPITAL, CardField.EXTRA
];

export const MAX_ALLERGIES: number = 12;
export const MAX_EXTRA: number = 8;

/** Deep copy, so a screen can edit without touching the stored object. Keeps every field, old and new. */
export function cloneProfile(p: Profile): Profile {
  const copy: Profile = {
    condition: p.condition,
    genotype: p.genotype,
    hasIcd: p.hasIcd,
    notes: p.notes,
    contacts: p.contacts.map((c: Contact): Contact => {
      const x: Contact = { name: c.name, phone: c.phone, relation: c.relation, email: c.email };
      return x;
    }),
    name: p.name,
    country: p.country,
    cardLanguage: p.cardLanguage,
    dateOfBirth: p.dateOfBirth,
    sex: p.sex,
    bloodType: p.bloodType,
    allergies: (p.allergies ?? []).slice(),
    icdModel: p.icdModel,
    cardiologistName: p.cardiologistName,
    cardiologistPhone: p.cardiologistPhone,
    hospital: p.hospital,
    extra: (p.extra ?? []).map((e: ExtraField): ExtraField => {
      const x: ExtraField = { label: e.label, value: e.value };
      return x;
    }),
    hiddenOnCard: (p.hiddenOnCard ?? []).slice(),
    updatedAt: p.updatedAt
  };
  return copy;
}

export function shownOnCard(p: Profile, field: string): boolean {
  return !(p.hiddenOnCard ?? []).includes(field);
}

/** New hiddenOnCard list with `field` switched on or off. */
export function withShown(hidden: string[] | undefined, field: string, show: boolean): string[] {
  const rest: string[] = (hidden ?? []).filter((f: string) => f !== field);
  if (!show) {
    rest.push(field);
  }
  return rest;
}

/** "penicillin, latex\nnuts" → ['penicillin', 'latex', 'nuts']: trimmed, no empties or duplicates, capped. */
export function parseList(text: string, max: number = MAX_ALLERGIES): string[] {
  const out: string[] = [];
  text.split(/[,;\n]/).forEach((s: string) => {
    const v: string = s.trim();
    if (v.length > 0 && !out.some((o: string) => o.toLowerCase() === v.toLowerCase()) && out.length < max) {
      out.push(v);
    }
  });
  return out;
}

/** '' is valid (field cleared); otherwise a real calendar date 'YYYY-MM-DD' not in the future. */
export function validBirthDate(text: string, now: number): boolean {
  const t: string = text.trim();
  if (t.length === 0) {
    return true;
  }
  const m: RegExpMatchArray | null = t.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (m === null) {
    return false;
  }
  const d: Date = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  const real: boolean = d.getFullYear() === Number(m[1]) && d.getMonth() === Number(m[2]) - 1 &&
    d.getDate() === Number(m[3]);
  return real && ageYears(t, now) !== undefined;
}

function text(v: string | undefined): string {
  return (v ?? '').trim();
}

function sexLabel(p: Profile, l: CardLabels): string {
  switch (p.sex) {
    case 'FEMALE':
      return l.female;
    case 'MALE':
      return l.male;
    case 'OTHER':
      return l.other;
    default:
      return '';
  }
}

/**
 * The detail rows of the card in DETAIL_ORDER: empty fields are left out, and so are the hidden ones unless
 * `includeHidden` (the editor's preview). The ICD model only shows when the profile says there is an ICD.
 */
export function detailRows(p: Profile, l: CardLabels, now: number, includeHidden: boolean = false): CardRow[] {
  const rows: CardRow[] = [];
  const add = (id: string, label: string, value: string): void => {
    if (value.length > 0 && (includeHidden || shownOnCard(p, id))) {
      const r: CardRow = { id: id, label: label, value: value };
      rows.push(r);
    }
  };
  for (const id of DETAIL_ORDER) {
    if (id === CardField.DATE_OF_BIRTH) {
      const age: number | undefined = ageYears(p.dateOfBirth, now);
      add(id, l.dateOfBirth, age === undefined ? '' : `${text(p.dateOfBirth)} (${l.age} ${age})`);
    } else if (id === CardField.SEX) {
      add(id, l.sex, sexLabel(p, l));
    } else if (id === CardField.BLOOD_TYPE) {
      add(id, l.bloodType, text(p.bloodType));
    } else if (id === CardField.ALLERGIES) {
      add(id, l.allergies, (p.allergies ?? []).map((a: string) => a.trim()).filter((a: string) => a.length > 0)
        .join(', '));
    } else if (id === CardField.ICD_MODEL) {
      add(id, l.icdModel, p.hasIcd ? text(p.icdModel) : '');
    } else if (id === CardField.CARDIOLOGIST) {
      add(id, l.cardiologist, [text(p.cardiologistName), text(p.cardiologistPhone)]
        .filter((s: string) => s.length > 0).join(' · '));
    } else if (id === CardField.HOSPITAL) {
      add(id, l.hospital, text(p.hospital));
    } else if (id === CardField.EXTRA) {
      (p.extra ?? []).forEach((e: ExtraField) => {
        if (text(e.label).length > 0 && text(e.value).length > 0) {
          add(id, text(e.label), text(e.value));
        }
      });
    }
  }
  return rows;
}
