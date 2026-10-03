// Medication reminders (F-38): today's doses (taken / due / missed) and the daily schedule per medicine.
// Reminders are soft (no sudden loud alarm — LQT2 rule), and fire even when the app is closed.

import { LocalStore } from '../data/LocalStore';
import { Medication } from '../model/Medication';
import { ReminderService } from '../reminders/ReminderService';
import { DoseLog, DoseReminder, DoseStatus, doseStatus, timeLabel } from '../reminders/DoseSchedule';
import { toast } from '../common/Toast';
import { PrimaryButton, SectionHeader } from '../components/Common';

@ComponentV2
export struct RemindersPage {
  @Local reminders: DoseReminder[] = [];
  @Local logs: DoseLog[] = [];
  @Local meds: Medication[] = [];
  @Local pickMed: number = 0;
  @Local time: Date = new Date(2026, 0, 1, 8, 0, 0);
  @Local now: number = Date.now();

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.meds = await LocalStore.get().listMeds();
    this.reminders = (await ReminderService.list()).sort((a: DoseReminder, b: DoseReminder) =>
      a.hour * 60 + a.minute - b.hour * 60 - b.minute);
    this.logs = await ReminderService.doseLog();
    this.now = Date.now();
  }

  private async add(): Promise<void> {
    if (this.meds.length === 0) {
      return;
    }
    const m: Medication = this.meds[Math.min(this.pickMed, this.meds.length - 1)];
    const r: DoseReminder = await ReminderService.add(m.id, m.name, this.time.getHours(), this.time.getMinutes());
    toast(this.getUIContext(), r.reminderId >= 0 ? $r('app.string.rem_added') : $r('app.string.rem_failed'));
    this.load();
  }

  private statusColor(s: DoseStatus): ResourceColor {
    switch (s) {
      case 'TAKEN':
        return $r('app.color.risk_not_listed');
      case 'MISSED':
        return $r('app.color.risk_known');
      case 'DUE':
        return $r('app.color.risk_possible');
      default:
        return $r('sys.color.font_secondary');
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          SectionHeader({ title: $r('app.string.rem_today') })
          if (this.reminders.length === 0) {
            Text($r('app.string.rem_empty'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
              .padding(16)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius($r('app.float.radius_m'))
          }
          ForEach(this.reminders, (r: DoseReminder) => {
            Row({ space: 12 }) {
              Text(timeLabel(r))
                .fontSize($r('app.float.font_subtitle'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
                .fontFeature('"tnum" on')
              Column({ space: 2 }) {
                Text(r.medName)
                  .fontSize($r('app.float.font_body'))
                  .fontColor($r('sys.color.font_primary'))
                Text(doseStatus(r, this.logs, this.now).toLowerCase())
                  .fontSize($r('app.float.font_caption'))
                  .fontColor(this.statusColor(doseStatus(r, this.logs, this.now)))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              if (doseStatus(r, this.logs, this.now) !== 'TAKEN') {
                Text($r('app.string.rem_taken'))
                  .fontSize($r('app.float.font_small'))
                  .fontColor($r('app.color.on_accent'))
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor($r('app.color.brand_accent'))
                  .borderRadius(100)
                  .onClick(async () => {
                    await ReminderService.mark(r, 'TAKEN');
                    this.load();
                  })
              }
              Image($r('app.media.ic_delete'))
                .width(20)
                .height(20)
                .fillColor($r('sys.color.icon_secondary'))
                .accessibilityText($r('app.string.a11y_delete'))
                .onClick(async () => {
                  await ReminderService.remove(r.id);
                  this.load();
                })
            }
            .width('100%')
            .padding(14)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius($r('app.float.radius_m'))
          }, (r: DoseReminder) => `${r.id}`)

          SectionHeader({ title: $r('app.string.rem_new') })
          if (this.meds.length === 0) {
            Text($r('app.string.rem_need_meds'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('sys.color.font_secondary'))
          } else {
            Column({ space: 12 }) {
              Select(this.meds.map((m: Medication) => {
                const o: SelectOption = { value: m.name };
                return o;
              }))
                .value(this.meds[Math.min(this.pickMed, this.meds.length - 1)].name)
                .width('100%')
                .onSelect((i: number) => {
                  this.pickMed = i;
                })
              TimePicker({ selected: this.time })
                .useMilitaryTime(true)
                .selectedTextStyle({ color: $r('app.color.brand_accent'), font: { size: 22, weight: FontWeight.Bold } })
                .height(140)
                .onChange((v: TimePickerResult) => {
                  this.time = new Date(2026, 0, 1, v.hour ?? 8, v.minute ?? 0, 0);
                })
              PrimaryButton({ label: $r('app.string.rem_add'), icon: $r('app.media.ic_bell'), onTap: () => {
                this.add();
              } })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius($r('app.float.radius_m'))
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
    .title($r('app.string.rem_title'))
    .backgroundColor($r('app.color.page_bg'))
  }
}
