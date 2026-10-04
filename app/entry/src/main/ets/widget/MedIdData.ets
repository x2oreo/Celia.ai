// Lock-screen medical ID card (B13, docs/research/live-view.md §2). Pure - unit tested. Anyone holding the locked
// phone can read this card, so it carries only what a paramedic needs and what the user has not hidden from the
// shared card (Profile.hiddenOnCard). Never contacts' phone numbers, notes or extras. Facts come from the profile
// and medicine list; the "do not give" line is fixed copy (string em_avoid), not model text.

import { CardField, Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { medLine } from '../emergency/CardContent';

export class MedIdLines {
  name: string = '';        // '' when hidden or unknown
  condition: string = 'Long QT syndrome';
  icd: string = '';         // 'ICD' / 'ICD · <model>' / ''
  meds: string = '';        // first three medicines
  other: string = '';       // allergies and blood type when shown
}

function shown(p: Profile, field: string): boolean {
  return !(p.hiddenOnCard ?? []).includes(field);
}

export function medIdLines(p: Profile | undefined, meds: Medication[]): MedIdLines {
  const l: MedIdLines = new MedIdLines();
  if (p === undefined) {
    return l;
  }
  if (shown(p, CardField.NAME) && p.name !== undefined) {
    l.name = p.name.trim();
  }
  l.condition = p.genotype === 'UNKNOWN' ? 'Long QT syndrome' :
    `Long QT syndrome, type ${p.genotype.replace('LQT', '')}`;
  if (p.hasIcd) {
    const model: string = shown(p, CardField.ICD_MODEL) ? (p.icdModel ?? '').trim() : '';
    l.icd = model.length > 0 ? `Has an ICD · ${model}` : 'Has an ICD';
  }
  if (meds.length > 0) {
    l.meds = `Takes ${meds.slice(0, 3).map((m: Medication) => medLine(m)).join(', ')}`;
  }
  const other: string[] = [];
  const allergies: string[] = p.allergies ?? [];
  if (shown(p, CardField.ALLERGIES) && allergies.length > 0) {
    other.push(`Allergies: ${allergies.join(', ')}`);
  }
  if (shown(p, CardField.BLOOD_TYPE) && p.bloodType !== undefined && p.bloodType.length > 0) {
    other.push(`Blood ${p.bloodType}`);
  }
  l.other = other.join(' · ');
  return l;
}
