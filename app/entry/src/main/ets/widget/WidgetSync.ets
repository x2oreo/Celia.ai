// Keeps the home-screen cards in step with the app (DESIGN.md §11 widgets v2): rebuilds the snapshot when the user's
// records or the agent's line change, writes it for the form extension, and pushes it to every placed card. The
// watch trend is fetched at most every 15 minutes and the live reading taken at most every 5, so the cards never
// cost more than the screens that show the same numbers.

import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { LocalStore, StoreTopic } from '../data/LocalStore';
import { Profile } from '../model/Profile';
import { VitalsSample } from '../model/Vitals';
import { emergencyFor, systemCountry } from '../common/EmergencyNumbers';
import { Logger } from '../common/Logger';
import { Brief, HomeBrief } from '../components/agent/HomeBrief';
import { agentLine, dayGreeting } from '../components/agent/AgentLogic';
import { ReminderService } from '../reminders/ReminderService';
import { VitalsService } from '../vitals/VitalsService';
import { loadTrends, TrendData } from '../vitals/Trends';
import { buildSnapshot, WidgetInputs } from './WidgetModel';
import { WidgetSnapshot } from './WidgetSnapshot';
import { forCard, PlacedForm, readForms, writeSnapshot } from './WidgetData';

const log: Logger = new Logger('WidgetSync');

const DEBOUNCE_MS: number = 800;
const TREND_EVERY_MS: number = 15 * 60 * 1000;
const SAMPLE_EVERY_MS: number = 5 * 60 * 1000;
const TREND_SPAN: number = 14;

export class WidgetSync {
  private static started: boolean = false;
  private static ctx: common.Context | undefined = undefined;
  private static timer: number = -1;
  private static running: boolean = false;
  private static again: boolean = false;
  private static pushed: string = '';
  private static trend: TrendData | undefined = undefined;
  private static trendAt: number = 0;
  private static sample: VitalsSample | undefined = undefined;
  private static sampleAt: number = 0;

  static start(ctx: common.Context): void {
    if (WidgetSync.started) {
      return;
    }
    WidgetSync.started = true;
    WidgetSync.ctx = ctx;
    LocalStore.get().onChange((t: StoreTopic) => {
      if (t !== 'chats') {
        WidgetSync.schedule();
      }
    });
    // HomeBrief re-reads the dose schedule twice a minute, so a dose turning due reaches the cards too.
    HomeBrief.onChange((b: Brief) => WidgetSync.schedule());
    VitalsService.get().onSample((s: VitalsSample) => {
      if (s.ts - WidgetSync.sampleAt >= SAMPLE_EVERY_MS) {
        WidgetSync.sample = s;
        WidgetSync.sampleAt = s.ts;
        WidgetSync.schedule();
      }
    });
    WidgetSync.schedule();
  }

  private static schedule(): void {
    if (WidgetSync.timer >= 0) {
      clearTimeout(WidgetSync.timer);
    }
    WidgetSync.timer = setTimeout(() => {
      WidgetSync.timer = -1;
      WidgetSync.refresh();
    }, DEBOUNCE_MS);
  }

  private static async inputs(now: number): Promise<WidgetInputs> {
    const store: LocalStore = LocalStore.get();
    const i: WidgetInputs = new WidgetInputs();
    const profile: Profile | undefined = await store.getProfile();
    i.profile = profile;
    i.meds = await store.listMeds();
    i.ambulance = emergencyFor(profile?.country ?? systemCountry()).ambulance;
    i.reminders = await ReminderService.list();
    i.logs = await ReminderService.doseLog();
    i.scans = await store.listScans();
    i.events = await store.listEvents();
    if (WidgetSync.trend === undefined || now - WidgetSync.trendAt >= TREND_EVERY_MS) {
      WidgetSync.trend = await loadTrends(now, TREND_SPAN);
      WidgetSync.trendAt = now;
    }
    i.trend = WidgetSync.trend.days;
    i.trendSimulated = WidgetSync.trend.simulated;
    if (WidgetSync.sample === undefined) {
      WidgetSync.sample = VitalsService.get().latest();
    }
    i.sample = WidgetSync.sample;
    // The card's line without a dose: the dose part is added by the clock (WidgetSnapshot.applyDose), and the
    // greeting is the night one ("Hi, Ola.") so it is never wrong for the time of day.
    const b: Brief = HomeBrief.latest();
    const name: string = profile?.name ?? '';
    i.agentRest = agentLine(dayGreeting(0, name.length > 0 ? name.split(' ')[0] : ''), undefined, now,
      b.interactions.length, b.counts.known);
    return i;
  }

  private static async refresh(): Promise<void> {
    const ctx: common.Context | undefined = WidgetSync.ctx;
    if (ctx === undefined) {
      return;
    }
    if (WidgetSync.running) {
      WidgetSync.again = true;
      return;
    }
    WidgetSync.running = true;
    try {
      const now: number = Date.now();
      const i: WidgetInputs = await WidgetSync.inputs(now);
      const s: WidgetSnapshot = buildSnapshot(i, now);
      const json: string = JSON.stringify(s);
      if (json !== WidgetSync.pushed) {
        if (!await writeSnapshot(ctx, s, { reminders: i.reminders, logs: i.logs })) {
          log.warn('snapshot not saved; placed cards still get this push');
        }
        await WidgetSync.push(ctx, s);
        WidgetSync.pushed = json;
      }
    } catch (e) {
      log.warn(`widget refresh failed: ${JSON.stringify(e)}`);
    }
    WidgetSync.running = false;
    if (WidgetSync.again) {
      WidgetSync.again = false;
      WidgetSync.schedule();
    }
  }

  private static async push(ctx: common.Context, s: WidgetSnapshot): Promise<void> {
    for (const f of readForms(ctx)) {
      try {
        await formProvider.updateForm(f.id, formBindingData.createFormBindingData(forCard(s, f.wide)));
      } catch (e) {
        log.warn(`updateForm ${f.id} failed: ${JSON.stringify(e)}`);
      }
    }
  }
}
