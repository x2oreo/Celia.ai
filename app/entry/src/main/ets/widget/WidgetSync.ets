// Keeps the Medical alert card in step with the profile and medicines: writes the snapshot the form extension
// reads, then pushes it to every card on the home screen.

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { LocalStore, StoreTopic } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { emergencyFor, systemCountry } from '../common/EmergencyNumbers';
import { medLine } from '../emergency/CardContent';
import { Logger } from '../common/Logger';
import { AlertCardData, readFormIds, WIDGET_PREFS } from './WidgetData';

const log: Logger = new Logger('WidgetSync');

export class WidgetSync {
  private static started: boolean = false;

  static start(ctx: common.Context): void {
    if (WidgetSync.started) {
      return;
    }
    WidgetSync.started = true;
    WidgetSync.refresh(ctx);
    LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'profile' || t === 'meds') {
        WidgetSync.refresh(ctx);
      }
    });
  }

  static build(profile: Profile | undefined, meds: Medication[]): AlertCardData {
    const d: AlertCardData = new AlertCardData();
    if (profile === undefined) {
      return d;
    }
    d.condition = profile.genotype === 'UNKNOWN' ? 'Long QT syndrome' :
      `Long QT syndrome, type ${profile.genotype.replace('LQT', '')}`;
    const icd: string = profile.hasIcd ? 'ICD' : 'No ICD';
    d.facts = meds.length === 0 ? icd : `${icd} · ${meds.slice(0, 2).map((m: Medication) => medLine(m)).join(', ')}`;
    d.number = emergencyFor(profile.country ?? systemCountry()).ambulance;
    d.ice = profile.contacts.length > 0 ? profile.contacts[0].name : '';
    return d;
  }

  private static async refresh(ctx: common.Context): Promise<void> {
    try {
      const d: AlertCardData = WidgetSync.build(await LocalStore.get().getProfile(), await LocalStore.get().listMeds());
      const p: preferences.Preferences = preferences.getPreferencesSync(ctx, { name: WIDGET_PREFS });
      p.putSync('condition', d.condition);
      p.putSync('facts', d.facts);
      p.putSync('number', d.number);
      p.putSync('ice', d.ice);
      await p.flush();
      for (const id of readFormIds(ctx)) {
        try {
          await formProvider.updateForm(id, formBindingData.createFormBindingData(d));
        } catch (e) {
          log.warn(`updateForm ${id} failed: ${JSON.stringify(e)}`);
        }
      }
    } catch (e) {
      log.warn(`widget refresh failed: ${JSON.stringify(e)}`);
    }
  }
}
