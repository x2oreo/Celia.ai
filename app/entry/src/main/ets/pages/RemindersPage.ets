// Medication reminders (F-38, DESIGN.md §10.2 "Reminders"): today's progress, a timeline of doses (taken / due /
// missed / later) with what each medicine is for, and a quick "new reminder" card — pick a medicine, pick a time.
// Reminders are soft (no sudden loud alarm — LQT2 rule), and fire even when the app is closed.
// Dose status colours are neutral/brand/amber, never risk red: a missed dose is not a QT verdict.

import { LocalStore } from '../data/LocalStore';
import { Medication } from '../model/Medication';
import { RiskLevel } from '../model/DrugVerdict';
import { ReminderService } from '../reminders/ReminderService';
import { DoseLog, DoseReminder, DoseStatus, doseStatus, timeLabel } from '../reminders/DoseSchedule';
import { medClass, medFirstTip, medSubtitle } from '../drugs/MedFacts';
import { medRisk } from './MedicinesPage';
import { toast } from '../common/Toast';
import { pulse } from '../common/Haptics';
import { Motion } from '../common/Motion';
import { PrimaryButton, RiskShape } from '../components/Common';

class TimePreset {
  label: Resource;
  hour: number;
  minute: number;

  constructor(label: Resource, hour: number, minute: number) {
    this.label = label;
    this.hour = hour;
    this.minute = minute;
  }
}

const PRESETS: TimePreset[] = [
  new TimePreset($r('app.string.rem_morning'), 8, 0),
  new TimePreset($r('app.string.rem_noon'), 13, 0),
  new TimePreset($r('app.string.rem_evening'), 20, 0),
  new TimePreset($r('app.string.rem_night'), 22, 0)
];
const CUSTOM: number = -1;

function hhmm(hour: number, minute: number): string {
  return `${hour < 10 ? '0' : ''}${hour}:${minute < 10 ? '0' : ''}${minute}`;
}

@ComponentV2
export struct RemindersPage {
  @Local reminders: DoseReminder[] = [];
  @Local logs: DoseLog[] = [];
  @Local meds: Medication[] = [];
  @Local pickMedId: number = -1;
  @Local preset: number = 0;           // index in PRESETS, or CUSTOM
  @Local hour: number = 8;
  @Local minute: number = 0;
  @Local now: number = Date.now();
  private wantMedId: number = -1;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.meds = await LocalStore.get().listMeds();
    this.reminders = (await ReminderService.list()).sort((a: DoseReminder, b: DoseReminder) =>
      a.hour * 60 + a.minute - b.hour * 60 - b.minute);
    this.logs = await ReminderService.doseLog();
    this.now = Date.now();
    const want: number = this.wantMedId >= 0 ? this.wantMedId : this.pickMedId;
    const found: boolean = this.meds.some((m: Medication) => m.id === want);
    this.pickMedId = found ? want : (this.meds.length > 0 ? this.meds[0].id : -1);
  }

  private pickedMed(): Medication | undefined {
    return this.meds.find((m: Medication) => m.id === this.pickMedId);
  }

  private async add(): Promise<void> {
    const m: Medication | undefined = this.pickedMed();
    if (m === undefined) {
      return;
    }
    const r: DoseReminder = await ReminderService.add(m.id, m.name, this.hour, this.minute);
    toast(this.getUIContext(), r.reminderId >= 0 ? $r('app.string.rem_added') : $r('app.string.rem_failed'));
    this.load();
  }

  private async markTaken(r: DoseReminder): Promise<void> {
    pulse(15);
    await ReminderService.mark(r, 'TAKEN');
    this.load();
  }

  private statusOf(r: DoseReminder): DoseStatus {
    return doseStatus(r, this.logs, this.now);
  }

  private takenCount(): number {
    return this.reminders.filter((r: DoseReminder) => this.statusOf(r) === 'TAKEN').length;
  }

  private nextDose(): DoseReminder | undefined {
    return this.reminders.find((r: DoseReminder) => {
      const s: DoseStatus = this.statusOf(r);
      return s === 'DUE' || s === 'UPCOMING';
    });
  }

  private medFor(r: DoseReminder): Medication | undefined {
    return this.meds.find((m: Medication) => m.id === r.medId);
  }

  private riskFor(r: DoseReminder): RiskLevel {
    const m: Medication | undefined = this.medFor(r);
    return m === undefined ? 'UNKNOWN_DRUG' : medRisk(m);
  }

  private statusWord(s: DoseStatus): Resource {
    switch (s) {
      case 'TAKEN':
        return $r('app.string.rem_status_taken');
      case 'DUE':
        return $r('app.string.rem_status_due');
      case 'MISSED':
        return $r('app.string.rem_status_missed');
      case 'SKIPPED':
        return $r('app.string.rem_status_skipped');
      default:
        return $r('app.string.rem_status_upcoming');
    }
  }

  private statusColor(s: DoseStatus): ResourceColor {
    switch (s) {
      case 'TAKEN':
        return $r('app.color.ink');
      case 'DUE':
        return $r('app.color.brand_accent');
      case 'MISSED':
        return $r('app.color.risk_possible');
      default:
        return $r('app.color.border_strong');
    }
  }

  private statusText(s: DoseStatus): ResourceColor {
    switch (s) {
      case 'DUE':
        return $r('app.color.brand_text');
      case 'MISSED':
        return $r('app.color.risk_possible_text');
      default:
        return $r('app.color.ink_3');
    }
  }

  private segmentColor(s: DoseStatus): ResourceColor {
    switch (s) {
      case 'TAKEN':
        return $r('app.color.brand_accent');
      case 'MISSED':
        return $r('app.color.risk_possible');
      default:
        return $r('app.color.border');
    }
  }

  // ── Today summary ──────────────────────────────────────────────────────────────────────────
  @Builder
  summary() {
    Column({ space: 14 }) {
      Row({ space: 14 }) {
        Row() {
          Image($r('app.media.ic_bell')).width(22).height(22).fillColor($r('app.color.brand_accent'))
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.brand_accent_soft'))
        .borderRadius($r('app.float.radius_m'))
        Column({ space: 2 }) {
          Text(this.reminders.length === 0 ? $r('app.string.rem_none_today') :
            this.takenCount() === this.reminders.length ? $r('app.string.rem_all_done') :
              $r('app.string.rem_progress', this.takenCount(), this.reminders.length))
            .fontSize($r('app.float.font_title_3'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          if (this.nextDose() !== undefined) {
            Text($r('app.string.rem_next', this.nextDose()?.medName ?? '', timeLabel(this.nextDose() as DoseReminder)))
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink_3'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      if (this.reminders.length > 0) {
        Row({ space: 4 }) {
          ForEach(this.reminders, (r: DoseReminder) => {
            Row()
              .layoutWeight(1)
              .height(6)
              .borderRadius(3)
              .backgroundColor(this.segmentColor(this.statusOf(r)))
              .animation({ duration: 200, curve: Curve.EaseOut })
          }, (r: DoseReminder) => `${r.id}-${this.statusOf(r)}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
  }

  // ── Timeline ───────────────────────────────────────────────────────────────────────────────
  @Builder
  statusDot(s: DoseStatus) {
    if (s === 'TAKEN') {
      Row() {
        Image($r('app.media.ic_check')).width(12).height(12).fillColor($r('app.color.on_accent'))
      }
      .width(20)
      .height(20)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.statusColor(s))
      .borderRadius(10)
    } else {
      Circle()
        .width(s === 'DUE' ? 14 : 12)
        .height(s === 'DUE' ? 14 : 12)
        .fill(s === 'DUE' ? this.statusColor(s) : $r('app.color.bg'))
        .stroke(this.statusColor(s))
        .strokeWidth(s === 'DUE' ? 0 : 2.5)
        .margin({ top: 4, bottom: 4 })
    }
  }

  @Builder
  deleteMenu(r: DoseReminder) {
    Menu() {
      MenuItem({ content: $r('app.string.rem_delete') })
        .onClick(async () => {
          await ReminderService.remove(r.id);
          this.load();
        })
    }
  }

  @Builder
  doseRow(r: DoseReminder, last: boolean) {
    Row({ space: 12 }) {
      // Time column
      Text(timeLabel(r))
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor(this.statusOf(r) === 'TAKEN' ? $r('app.color.ink_3') : $r('app.color.ink'))
        .fontFeature('"tnum" on')
        .width(48)
        .margin({ top: 14 })

      // Rail
      Column() {
        Column() {
          this.statusDot(this.statusOf(r))
        }
        .height(20)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 15 })
        if (!last) {
          Column()
            .width(2)
            .layoutWeight(1)
            .backgroundColor($r('app.color.border'))
            .margin({ top: 4 })
        }
      }
      .width(20)
      .height('100%')

      // Card
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          RiskShape({ risk: this.riskFor(r), dim: 16 })
          Text(r.medName.length > 0 ? r.medName.charAt(0).toUpperCase() + r.medName.slice(1) : r.medName)
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.statusWord(this.statusOf(r)))
            .fontSize($r('app.float.font_micro'))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.statusText(this.statusOf(r)))
            .letterSpacing(0.4)
            .textCase(TextCase.UpperCase)
        }
        .width('100%')
        if (this.medFor(r) !== undefined && medSubtitle(this.medFor(r) as Medication) !== '') {
          Text(medSubtitle(this.medFor(r) as Medication))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_3'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (this.statusOf(r) !== 'TAKEN' && medFirstTip(r.medId, this.meds) !== '') {
          Row({ space: 6 }) {
            Image($r('app.media.ic_check')).width(12).height(12).fillColor($r('app.color.ink_4'))
            Text(medFirstTip(r.medId, this.meds))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_3'))
              .lineHeight(16)
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({ top: 2 })
        }
        if (this.statusOf(r) === 'DUE' || this.statusOf(r) === 'MISSED' || this.statusOf(r) === 'UPCOMING') {
          Row({ space: 6 }) {
            Image($r('app.media.ic_check')).width(16).height(16)
              .fillColor(this.statusOf(r) === 'UPCOMING' ? $r('app.color.ink') : $r('app.color.on_accent'))
            Text($r('app.string.rem_taken'))
              .fontSize($r('app.float.font_small'))
              .fontWeight(FontWeight.Bold)
              .fontColor(this.statusOf(r) === 'UPCOMING' ? $r('app.color.ink') : $r('app.color.on_accent'))
          }
          .height($r('app.float.chip_height'))   // 44 vp: a dose is logged with one thumb, never a missed tap
          .padding({ left: 14, right: 16 })
          .margin({ top: 4 })
          .backgroundColor(this.statusOf(r) === 'UPCOMING' ? $r('app.color.surface_alt') :
            $r('app.color.brand_accent'))
          .borderRadius(22)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
          .accessibilityText($r('app.string.rem_taken'))
          .onClick(() => {
            this.markTaken(r);
          })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .margin({ bottom: last ? 0 : 10 })
      .backgroundColor($r('app.color.surface'))
      .border({
        width: this.statusOf(r) === 'DUE' ? 1.5 : 1,
        color: this.statusOf(r) === 'DUE' ? $r('app.color.brand_accent') : $r('app.color.border')
      })
      .borderRadius($r('app.float.radius_m'))
      .opacity(this.statusOf(r) === 'TAKEN' ? 0.72 : 1)
      .animation({ duration: 200, curve: Curve.EaseOut })
      .bindContextMenu(this.deleteMenu(r), ResponseType.LongPress)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 8 }))
      .animation({ duration: Motion.REVEAL_MS, curve: Curve.EaseOut }))
  }

  @Builder
  emptyTimeline() {
    Column({ space: 10 }) {
      Image($r('app.media.ic_bell')).width(28).height(28).fillColor($r('app.color.ink_4'))
      Text($r('app.string.rem_empty'))
        .fontSize($r('app.float.font_badge'))
        .fontColor($r('app.color.ink_3'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(24)
    .border({ width: 2, color: $r('app.color.border_strong'), style: BorderStyle.Dashed })
    .borderRadius($r('app.float.radius_m'))
  }

  // ── New reminder ───────────────────────────────────────────────────────────────────────────
  @Builder
  fieldLabel(text: Resource) {
    Text(text)
      .fontSize($r('app.float.font_badge'))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.ink_3'))
      .letterSpacing(0.6)
      .textCase(TextCase.UpperCase)
  }

  @Builder
  medChoice(m: Medication) {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        RiskShape({ risk: medRisk(m), dim: 16 })
        Text(m.name.length > 0 ? m.name.charAt(0).toUpperCase() + m.name.slice(1) : m.name)
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      Text(medClass(m) === '' ? (m.dose === '' ? '—' : m.dose) : medClass(m))
        .fontSize($r('app.float.font_micro'))
        .fontColor($r('app.color.ink_3'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(148)
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.pickMedId === m.id ? $r('app.color.surface') : $r('app.color.surface_alt'))
    .border({
      width: 1.5,
      color: this.pickMedId === m.id ? $r('app.color.ink') : Color.Transparent
    })
    .borderRadius($r('app.float.radius_s'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .accessibilityText(m.name)
    .onClick(() => {
      this.pickMedId = m.id;
    })
  }

  @Builder
  timeChip(label: Resource, sub: string, selected: boolean, onTap: () => void) {
    Column({ space: 1 }) {
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Bold)
        .fontColor(selected ? $r('app.color.chat_user_text') : $r('app.color.ink'))
      if (sub !== '') {
        Text(sub)
          .fontSize($r('app.float.font_micro'))
          .fontColor(selected ? $r('app.color.chat_user_text') : $r('app.color.ink_3'))
          .fontFeature('"tnum" on')
          .opacity(selected ? 0.8 : 1)
      }
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(selected ? $r('app.color.chat_user_bg') : $r('app.color.surface_alt'))
    .borderRadius($r('app.float.radius_s'))
    .animation({ duration: 150, curve: Curve.EaseOut })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
    .onClick(onTap)
  }

  @Builder
  newReminder() {
    Column({ space: 14 }) {
      this.fieldLabel($r('app.string.rem_pick_med'))
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.meds, (m: Medication) => {
            this.medChoice(m)
          }, (m: Medication) => `${m.id}-${this.pickMedId === m.id}`)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .align(Alignment.Start)

      this.fieldLabel($r('app.string.rem_pick_time'))
      Row({ space: 6 }) {
        ForEach(PRESETS, (p: TimePreset, i: number) => {
          this.timeChip(p.label, hhmm(p.hour, p.minute), this.preset === i, () => {
            this.preset = i;
            this.hour = p.hour;
            this.minute = p.minute;
          })
        }, (p: TimePreset, i: number) => `${i}-${this.preset === i}`)
        this.timeChip($r('app.string.rem_custom'), this.preset === CUSTOM ? hhmm(this.hour, this.minute) : '',
          this.preset === CUSTOM, () => {
            this.preset = CUSTOM;
          })
      }
      .width('100%')
      if (this.preset === CUSTOM) {
        TimePicker({ selected: new Date(2026, 0, 1, this.hour, this.minute, 0) })
          .useMilitaryTime(true)
          .selectedTextStyle({ color: $r('app.color.ink'), font: { size: 22, weight: FontWeight.Bold } })
          .height(132)
          .width('100%')
          .onChange((v: TimePickerResult) => {
            this.hour = v.hour ?? 8;
            this.minute = v.minute ?? 0;
          })
          .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
      }
      PrimaryButton({
        label: $r('app.string.rem_add_at', hhmm(this.hour, this.minute)),
        icon: $r('app.media.ic_bell'),
        active: this.pickedMed() !== undefined,
        onTap: () => {
          this.add();
        }
      })
      Text($r('app.string.rem_gentle'))
        .fontSize($r('app.float.font_micro'))
        .fontColor($r('app.color.ink_4'))
        .lineHeight(15)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
  }

  @Builder
  sectionLabel(text: Resource) {
    Text(text)
      .fontSize($r('app.float.font_badge'))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.ink_3'))
      .letterSpacing(0.6)
      .textCase(TextCase.UpperCase)
      .width('100%')
      .padding({ top: 8 })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          this.summary()

          this.sectionLabel($r('app.string.rem_today'))
          if (this.reminders.length === 0) {
            this.emptyTimeline()
          } else {
            Column() {
              ForEach(this.reminders, (r: DoseReminder, i: number) => {
                this.doseRow(r, i === this.reminders.length - 1)
              }, (r: DoseReminder, i: number) =>
                `${r.id}-${this.statusOf(r)}-${i === this.reminders.length - 1}-${this.meds.length}`)
            }
            .width('100%')
          }

          this.sectionLabel($r('app.string.rem_new'))
          if (this.meds.length === 0) {
            Text($r('app.string.rem_need_meds'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink_3'))
          } else {
            this.newReminder()
          }
        }
        .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m'), top: 4, bottom: 32 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .title($r('app.string.rem_title'))
    .backgroundColor($r('app.color.bg'))
    .onReady((ctx: NavDestinationContext) => {
      const p: Object | undefined = ctx.pathInfo.param as Object | undefined;
      if (typeof p === 'number') {
        this.wantMedId = p as number;
        this.pickMedId = p as number;
      }
    })
  }
}
