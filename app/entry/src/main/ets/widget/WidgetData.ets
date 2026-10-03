// Data shown on the Medical alert home-screen card (design B6). The app writes a snapshot to a small Preferences
// file whenever the profile or medicines change; the form extension reads it without opening the encrypted store.
// Keys match the @LocalStorageProp names in widget/pages/AlertCard.ets.

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export const WIDGET_PREFS: string = 'widget_snapshot';
export const KEY_FORM_IDS: string = 'formIds';

export class AlertCardData {
  condition: string = 'Long QT syndrome';
  facts: string = '';
  number: string = '112';
  ice: string = '';
}

export function readAlertCard(ctx: common.Context): AlertCardData {
  const d: AlertCardData = new AlertCardData();
  try {
    const p: preferences.Preferences = preferences.getPreferencesSync(ctx, { name: WIDGET_PREFS });
    d.condition = p.getSync('condition', d.condition) as string;
    d.facts = p.getSync('facts', d.facts) as string;
    d.number = p.getSync('number', d.number) as string;
    d.ice = p.getSync('ice', d.ice) as string;
  } catch (e) {
    // First run or unreadable file: the card shows the generic condition and 112.
  }
  return d;
}

export function readFormIds(ctx: common.Context): string[] {
  try {
    const p: preferences.Preferences = preferences.getPreferencesSync(ctx, { name: WIDGET_PREFS });
    return JSON.parse(p.getSync(KEY_FORM_IDS, '[]') as string) as string[];
  } catch (e) {
    return [];
  }
}

export function writeFormIds(ctx: common.Context, ids: string[]): void {
  try {
    const p: preferences.Preferences = preferences.getPreferencesSync(ctx, { name: WIDGET_PREFS });
    p.putSync(KEY_FORM_IDS, JSON.stringify(ids));
    p.flush();
  } catch (e) {
    // Losing an id only means that card refreshes on the next add.
  }
}
