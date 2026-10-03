// Pure SOS text and types (unit tested). Side effects live in SosService.

import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { medLine } from './CardContent';

export class GeoPoint {
  lat: number;
  lon: number;

  constructor(lat: number, lon: number) {
    this.lat = lat;
    this.lon = lon;
  }
}

export interface SosEvent {
  ts: number;
  trigger: string;      // 'VITALS' | 'BUTTON' | 'TEST' + reason
  test: boolean;
  lat: number;          // NaN when unknown
  lon: number;
  outcome: string;      // 'SENT' | 'ACKED' | 'CANCELLED'
}

// Pure: the text sent to emergency contacts.
export function sosMessage(p: Profile, meds: Medication[], where: GeoPoint | undefined, reason: string,
  test: boolean): string {
  const lines: string[] = [];
  if (test) {
    lines.push('*** TEST — NOT A REAL EMERGENCY ***');
  }
  const who: string = p.name !== undefined && p.name.length > 0 ? p.name : 'I';
  lines.push(`SOS: ${who} may be having a heart rhythm emergency${reason.length > 0 ? ` (${reason})` : ''}.`);
  const gt: string = p.genotype === 'UNKNOWN' ? '' : ` ${p.genotype}`;
  lines.push(`Condition: Long QT syndrome${gt}. ICD: ${p.hasIcd ? 'yes' : 'no'}.`);
  if (where !== undefined) {
    lines.push(`Location: https://maps.google.com/?q=${where.lat.toFixed(5)},${where.lon.toFixed(5)}`);
  } else {
    lines.push('Location: unknown');
  }
  lines.push(`Medicines: ${meds.length === 0 ? 'none' : meds.map((m: Medication) => medLine(m)).join(', ')}`);
  lines.push('Paramedics must AVOID QT-prolonging drugs (e.g. ondansetron, macrolide/quinolone antibiotics, ' +
    'haloperidol). Torsades: IV magnesium.');
  lines.push('Call the ambulance if you cannot reach me.');
  return lines.join('\n');
}
