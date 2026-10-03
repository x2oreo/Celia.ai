// Builds the plain-text emergency card used by the QR code (F-30) and SOS messages (F-28). English, compact.

import { Profile, Contact } from '../model/Profile';
import { Medication } from '../model/Medication';

export function medLine(m: Medication): string {
  const name: string = m.ingredient !== '' && m.ingredient !== m.name.toLowerCase() ? `${m.name} (${m.ingredient})` :
    m.name;
  return m.dose === '' ? name : `${name} ${m.dose}`;
}

export function cardPlainText(p: Profile, meds: Medication[]): string {
  const lines: string[] = [];
  lines.push('MEDICAL ALERT');
  if (p.name !== undefined && p.name.length > 0) {
    lines.push(`Name: ${p.name}`);
  }
  const gt: string = p.genotype === 'UNKNOWN' ? 'genotype unknown' : p.genotype;
  lines.push(`Long QT syndrome (${gt}). ICD: ${p.hasIcd ? 'YES' : 'no'}.`);
  lines.push('AVOID QT-prolonging drugs — check crediblemeds.org. Torsades: IV magnesium.');
  lines.push(`Meds: ${meds.length === 0 ? 'none' : meds.map((m: Medication) => medLine(m)).join(', ')}`);
  if (p.contacts.length > 0) {
    lines.push(`ICE: ${p.contacts.map((c: Contact) => `${c.name} ${c.phone}`).join(', ')}`);
  }
  if (p.notes.length > 0) {
    lines.push(`Notes: ${p.notes}`);
  }
  return lines.join('\n');
}
