// Symptom log (F-44, manual — no AI): what, how bad, what you were doing. The heart-rate range of the last
// minutes is attached automatically. Fainting / chest pain / breathlessness → offer SOS right away.

import { LocalStore } from '../data/LocalStore';
import { AppEvent } from '../model/AppEvent';
import { VitalsSample } from '../model/Vitals';
import { VitalsService } from '../vitals/VitalsService';
import { Routes, SosParam } from '../common/Routes';
import { dateTime } from '../common/Format';
import { toast } from '../common/Toast';
import { PrimaryButton, SectionHeader } from '../components/Common';

export type Symptom = 'DIZZINESS' | 'PALPITATIONS' | 'FAINTING' | 'CHEST_PAIN' | 'SHORTNESS_OF_BREATH' | 'OTHER';
const SYMPTOMS: Symptom[] = ['DIZZINESS', 'PALPITATIONS', 'FAINTING', 'CHEST_PAIN', 'SHORTNESS_OF_BREATH', 'OTHER'];
const ACTIVITIES: string[] = ['resting', 'sleeping', 'exercise', 'swimming', 'sudden noise / stress', 'other'];

export interface SymptomEntry {
  symptom: Symptom;
  severity: number;
  activity: string;
  note: string;
  hrMin: number;
  hrMax: number;
}

export function isRedFlag(s: Symptom, severity: number): boolean {
  return s === 'FAINTING' || s === 'CHEST_PAIN' || (s === 'SHORTNESS_OF_BREATH' && severity >= 4);
}

function label(s: Symptom): string {
  const t: string = s.toLowerCase().replace(/_/g, ' ');
  return t.charAt(0).toUpperCase() + t.substring(1);
}

@ComponentV2
export struct SymptomLogPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local symptom: Symptom = 'DIZZINESS';
  @Local severity: number = 2;
  @Local activity: string = 'resting';
  @Local note: string = '';
  @Local recent: AppEvent[] = [];

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const all: AppEvent[] = await LocalStore.get().listEvents();
    this.recent = all.filter((e: AppEvent) => e.kind === 'SYMPTOM').reverse().slice(0, 10);
  }

  private async save(): Promise<void> {
    const hrs: number[] = VitalsService.get().history().map((s: VitalsSample) => s.hr);
    const entry: SymptomEntry = {
      symptom: this.symptom,
      severity: this.severity,
      activity: this.activity,
      note: this.note.trim(),
      hrMin: hrs.length === 0 ? -1 : hrs.reduce((a: number, b: number) => Math.min(a, b), 999),
      hrMax: hrs.length === 0 ? -1 : hrs.reduce((a: number, b: number) => Math.max(a, b), 0)
    };
    await LocalStore.get().logEvent('SYMPTOM', JSON.stringify(entry));
    toast(this.getUIContext(), $r('app.string.sym_saved'));
    this.note = '';
    this.load();
  }

  // Builders read state through `this` so the highlight re-renders (builder arguments are passed by value).
  @Builder
  symptomChip(sym: Symptom) {
    Text(label(sym))
      .fontSize($r('app.float.font_small'))
      .fontColor(this.symptom === sym ? $r('app.color.chat_user_text') : $r('app.color.ink'))
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .margin({ right: 8, bottom: 8 })
      .backgroundColor(this.symptom === sym ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
      .border({ width: this.symptom === sym ? 0 : 1.5, color: $r('app.color.border_strong') })
      .borderRadius(100)
      .onClick(() => {
        this.symptom = sym;
      })
  }

  @Builder
  activityChip(a: string) {
    Text(a)
      .fontSize($r('app.float.font_small'))
      .fontColor(this.activity === a ? $r('app.color.chat_user_text') : $r('app.color.ink'))
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .margin({ right: 8, bottom: 8 })
      .backgroundColor(this.activity === a ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
      .border({ width: this.activity === a ? 0 : 1.5, color: $r('app.color.border_strong') })
      .borderRadius(100)
      .onClick(() => {
        this.activity = a;
      })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          SectionHeader({ title: $r('app.string.sym_what') })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(SYMPTOMS, (s: Symptom) => {
              this.symptomChip(s)
            }, (s: Symptom) => s)
          }
          .width('100%')

          if (isRedFlag(this.symptom, this.severity)) {
            Column({ space: 10 }) {
              Text($r('app.string.sym_red_flag'))
                .fontSize($r('app.float.font_body'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.risk_known'))
              PrimaryButton({
                label: $r('app.string.emergency_sos'),
                icon: $r('app.media.ic_bell'),
                danger: true,
                onTap: () => {
                  this.navStack.pushPathByName(Routes.SOS, new SosParam(false, label(this.symptom).toLowerCase()));
                }
              })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.risk_known_tint'))
            .borderRadius($r('app.float.radius_m'))
          }

          SectionHeader({ title: $r('app.string.sym_how_bad') })
          Column() {
            Slider({ value: this.severity, min: 1, max: 5, step: 1, style: SliderStyle.InSet })
              .showSteps(true)
              .selectedColor($r('app.color.brand_accent'))
              .onChange((v: number) => {
                this.severity = Math.round(v);
              })
            Text(`${this.severity} / 5`)
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink_3'))
          }
          .width('100%')
          .padding(12)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.border') })
          .borderRadius($r('app.float.radius_m'))

          SectionHeader({ title: $r('app.string.sym_doing') })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(ACTIVITIES, (a: string) => {
              this.activityChip(a)
            }, (a: string) => a)
          }
          .width('100%')

          TextArea({ text: this.note, placeholder: $r('app.string.sym_note_hint') })
            .height(80)
            .backgroundColor($r('app.color.surface_alt'))
            .onChange((v: string) => {
              this.note = v;
            })
          PrimaryButton({ label: $r('app.string.sym_save'), onTap: () => {
            this.save();
          } })

          if (this.recent.length > 0) {
            SectionHeader({ title: $r('app.string.sym_recent') })
            ForEach(this.recent, (e: AppEvent) => {
              Text(`${dateTime(e.ts, Date.now())} · ${this.describe(e)}`)
                .fontSize($r('app.float.font_small'))
                .fontColor($r('app.color.ink'))
                .width('100%')
                .padding(12)
                .backgroundColor($r('app.color.surface'))
                .border({ width: 1, color: $r('app.color.border') })
                .borderRadius($r('app.float.radius_s'))
            }, (e: AppEvent) => `${e.id}`)
          }
        }
        .padding({ left: 16, right: 16, bottom: 32 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title($r('app.string.sym_title'))
    .backgroundColor($r('app.color.bg'))
  }

  private describe(e: AppEvent): string {
    const s: SymptomEntry = JSON.parse(e.detail) as SymptomEntry;
    const hr: string = s.hrMax > 0 ? ` · HR ${s.hrMin}–${s.hrMax}` : '';
    return `${label(s.symptom)} ${s.severity}/5 · ${s.activity}${hr}`;
  }
}
