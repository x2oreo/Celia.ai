// Home-screen card storage (DESIGN.md §11 widgets v2). The app writes the snapshot (widget/WidgetSnapshot.ets) to a
// small Preferences file whenever the user's records change; the form extension reads it without opening the
// encrypted store. The raw reminders and dose log sit next to it so the extension can move the Next dose card on by
// the clock. The form registry remembers each placed card's id and whether it is 2 × 4.
//
// The app and the form extension run in different processes and Preferences caches a file per process, so each file
// has one writer (snapshot: the app; registry: the extension) and the other side drops its cache before reading.

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { DoseLog, DoseReminder } from '../reminders/DoseSchedule';
import { WidgetSnapshot } from './WidgetSnapshot';

const SNAPSHOT_FILE: string = 'widget_snapshot';
const FORMS_FILE: string = 'widget_forms';
const KEY_SNAPSHOT: string = 'snapshot';
const KEY_DOSES: string = 'doses';
const KEY_FORMS: string = 'forms';
const KEY_FORM_IDS: string = 'formIds';   // v1 registry (ids only, in the snapshot file), read until replaced

export interface PlacedForm {
  id: string;
  wide: boolean;
}

export interface DoseInputs {
  reminders: DoseReminder[];
  logs: DoseLog[];
}

// Throws when the file cannot be opened; every caller catches.
function open(ctx: common.Context, name: string): preferences.Preferences {
  return preferences.getPreferencesSync(ctx, { name: name });
}

// The other process may have written since this one loaded the file.
function openFresh(ctx: common.Context, name: string): preferences.Preferences {
  preferences.removePreferencesFromCacheSync(ctx, { name: name });
  return open(ctx, name);
}

// ---- snapshot: written by the app, read by the extension -----------------------------------------------------------

export function readSnapshot(ctx: common.Context): WidgetSnapshot {
  try {
    const raw: string = openFresh(ctx, SNAPSHOT_FILE).getSync(KEY_SNAPSHOT, '') as string;
    if (raw !== '') {
      return JSON.parse(raw) as WidgetSnapshot;
    }
  } catch (e) {
    // Unreadable file: the cards fall back to their defaults (generic condition, 112, empty states).
  }
  return new WidgetSnapshot();
}

export function readDoseInputs(ctx: common.Context): DoseInputs {
  try {
    return JSON.parse(openFresh(ctx, SNAPSHOT_FILE).getSync(KEY_DOSES, '{"reminders":[],"logs":[]}') as string) as
      DoseInputs;
  } catch (e) {
    const none: DoseInputs = { reminders: [], logs: [] };
    return none;
  }
}

// Returns false when the file could not be written; the cards then keep their last data until the next change.
export async function writeSnapshot(ctx: common.Context, s: WidgetSnapshot, doses: DoseInputs): Promise<boolean> {
  try {
    const p: preferences.Preferences = open(ctx, SNAPSHOT_FILE);
    p.putSync(KEY_SNAPSHOT, JSON.stringify(s));
    p.putSync(KEY_DOSES, JSON.stringify(doses));
    await p.flush();
    return true;
  } catch (e) {
    return false;
  }
}

// ---- form registry: written by the extension, read by the app ------------------------------------------------------

export function readForms(ctx: common.Context): PlacedForm[] {
  try {
    const forms: PlacedForm[] = JSON.parse(openFresh(ctx, FORMS_FILE).getSync(KEY_FORMS, '[]') as string) as
      PlacedForm[];
    if (forms.length > 0) {
      return forms;
    }
    const ids: string[] = JSON.parse(openFresh(ctx, SNAPSHOT_FILE).getSync(KEY_FORM_IDS, '[]') as string) as string[];
    return ids.map((id: string) => {
      const f: PlacedForm = { id: id, wide: false };
      return f;
    });
  } catch (e) {
    return [];
  }
}

function writeForms(ctx: common.Context, forms: PlacedForm[]): void {
  try {
    const p: preferences.Preferences = openFresh(ctx, FORMS_FILE);
    p.putSync(KEY_FORMS, JSON.stringify(forms));
    p.flushSync();
  } catch (e) {
    // Losing an entry only means that card refreshes on its next 30-minute update.
  }
}

export function placeForm(ctx: common.Context, id: string, wide: boolean): void {
  const forms: PlacedForm[] = readForms(ctx).filter((f: PlacedForm) => f.id !== id);
  const f: PlacedForm = { id: id, wide: wide };
  forms.push(f);
  writeForms(ctx, forms);
}

export function removeForm(ctx: common.Context, id: string): void {
  writeForms(ctx, readForms(ctx).filter((f: PlacedForm) => f.id !== id));
}

export function isWide(ctx: common.Context, id: string): boolean {
  const f: PlacedForm | undefined = readForms(ctx).find((x: PlacedForm) => x.id === id);
  return f !== undefined && f.wide;
}

// The snapshot as one card should see it.
export function forCard(s: WidgetSnapshot, wide: boolean): WidgetSnapshot {
  const c: WidgetSnapshot = JSON.parse(JSON.stringify(s)) as WidgetSnapshot;
  c.wide = wide;
  return c;
}
