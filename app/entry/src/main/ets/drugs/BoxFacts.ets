// Plain facts about a scanned box (F-36) for the "About this medicine" card. Pure — unit tested.

import { BoxInfo } from '../model/BoxInfo';
import { DrugChecker } from './DrugChecker';
import { DrugEntry } from './DrugDataset';
import { atcGroup } from './Atc';
import { emergencyFor } from '../common/EmergencyNumbers';

export class InfoRow {
  label: string;
  value: string;

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

// Polish availability categories (Prawo farmaceutyczne art. 23a).
export function rxLabel(category: string): string {
  switch (category.trim()) {
    case 'OTC':
      return 'Over the counter (no prescription)';
    case 'Rp':
      return 'Prescription only';
    case 'Rpz':
      return 'Prescription only, restricted use';
    case 'Rpw':
      return 'Prescription only, controlled substance';
    case 'Lz':
      return 'Hospital use only';
    default:
      return category.trim();
  }
}

// "What it is" in one line: curated class for drugs in our dataset, else the WHO ATC group.
export function kindOf(box: BoxInfo): string {
  const names: string[] = box.ingredients.split('+').map((s: string) => s.trim()).filter((s: string) => s.length > 0);
  const classes: string[] = [];
  for (const n of names) {
    const e: DrugEntry | undefined = DrugChecker.get().entry(n);
    if (e !== undefined && !classes.includes(e.drugClass)) {
      classes.push(e.drugClass);
    }
  }
  if (classes.length > 0 && classes.length === names.length) {
    return classes.join(' + ');
  }
  const group: string = atcGroup(box.atc);
  return group.length > 0 ? group : (classes.length > 0 ? classes.join(' + ') : '');
}

export function describeBox(box: BoxInfo): string {
  const kind: string = kindOf(box);
  const parts: string[] = [];
  let first: string = box.brand;
  if (kind.length > 0) {
    first += ` is ${/^[aeiou]/i.test(kind) ? 'an' : 'a'} ${kind.toLowerCase()} medicine`;
  }
  if (box.ingredients.length > 0 && box.ingredients.toLowerCase() !== box.brand.toLowerCase()) {
    first += ` containing ${box.ingredients}`;
  }
  parts.push(first + '.');
  const how: string[] = [];
  if (box.form.length > 0) {
    how.push(box.form.toLowerCase());
  }
  if (box.strength.length > 0) {
    how.push(box.strength);
  }
  if (how.length > 0) {
    parts.push(`Comes as ${how.join(', ')}.`);
  }
  if (box.rxCategory.length > 0) {
    parts.push(`${rxLabel(box.rxCategory)} in Poland.`);
  }
  return parts.join(' ');
}

export function infoRows(box: BoxInfo): InfoRow[] {
  const rows: InfoRow[] = [];
  const add = (label: string, value: string): void => {
    if (value.trim().length > 0) {
      rows.push(new InfoRow(label, value.trim()));
    }
  };
  add('Active substance', box.substance === box.ingredients ? box.ingredients :
    `${box.ingredients} (${box.substance})`);
  add('Strength', box.strength);
  add('Form', box.form);
  add('Pack', box.pack);
  add('Availability', rxLabel(box.rxCategory));
  add('ATC code', box.atc.length > 0 ? `${box.atc} · ${atcGroup(box.atc)}` : '');
  add('Marketing holder', box.holder);
  add('Box from', box.country.length > 0 ? emergencyFor(box.country).name : '');
  add('Barcode (GTIN)', box.gtin);
  return rows;
}

export function sourceLine(box: BoxInfo): string {
  switch (box.source) {
    case 'PL_REGISTER':
      return `Polish medicines register (URPL), snapshot ${box.sourceDate}`;
    case 'LEARNED':
      return `Added by you on ${box.sourceDate} — stored only on this phone`;
    default:
      return 'Demo barcode (not a real product)';
  }
}
