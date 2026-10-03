// Read the emergency card aloud (T25) in the card's language, for a paramedic or bystander who can't read it.
// Pure: built from the pre-translated CardStrings and the user's medicines. Name, contacts and notes are left out
// on purpose — in languages other than English the text goes to cloud /speak, and personal data never leaves the
// phone (docs/ARCHITECTURE.md D6). The screen shows the full card anyway.

import { CardText } from '../common/CardStrings';
import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { medLine } from './CardContent';

export function cardSpeech(t: CardText, p: Profile, meds: Medication[]): string {
  const parts: string[] = [t.title + '.', t.condition + '.'];
  if (p.genotype !== 'UNKNOWN') {
    parts.push(`${t.genotype}: ${p.genotype.replace('LQT', 'L Q T ')}.`);
  }
  parts.push((p.hasIcd ? t.icdYes : t.icdNo) + '.');
  parts.push(t.avoid);
  parts.push(t.treatment);
  parts.push(`${t.meds}: ${meds.length === 0 ? t.noMeds : meds.map((m: Medication) => medLine(m)).join(', ')}.`);
  return parts.map((s: string) => s.trim().replace(/\.\.$/, '.')).join(' ');
}
