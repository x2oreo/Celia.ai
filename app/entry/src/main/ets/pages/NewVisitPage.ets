// New doctor visit (DESIGN.md §10.1a "07 Doctor visits"): pick the kind of doctor, say why you are going, and see
// what the app makes of it while you type. The guess is fixed keyword rules on this phone (doctor/VisitPlan.ets),
// never a model. Creating the visit saves it and opens its page.

import { DoctorPrepParam, Routes, VisitParam } from '../common/Routes';
import { Specialty, SPECIALTIES, specialtyName } from '../doctor/DoctorPrep';
import { knownNames, PlanGroup, REASON_STARTERS, visitPlan } from '../doctor/VisitPlan';
import { DOCTOR_MAX_CHARS, DoctorVisit, REASON_MAX_CHARS, VisitStore } from '../doctor/VisitStore';
import { CapsLabel, PrimaryButton, RiskShape, ScreenHeader } from '../components/Common';
import { specialtyIcon } from '../components/VisitParts';
import { Motion } from '../common/Motion';
import { dayLabel } from '../common/Format';
import { dayKey } from '../reminders/DoseSchedule';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('NewVisitPage');

@ComponentV2
export struct NewVisitPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local specialty: Specialty = 'GP';
  @Local doctor: string = '';
  @Local reason: string = '';
  @Local date: string = dayKey(Date.now());   // YYYY-MM-DD of the appointment
  @Local worries: string = '';
  @Local saving: boolean = false;

  @Computed
  get plan(): PlanGroup[] {
    return visitPlan(this.reason, this.specialty);
  }

  private async create(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      const v: DoctorVisit = await VisitStore.add(this.specialty, this.doctor, this.reason, Date.now(), this.date,
        this.worries);
      this.navStack.replacePath({ name: Routes.DOCTOR_VISIT, param: new VisitParam(v.id) });
    } catch (e) {
      log.warn(`create visit: ${(e as Error).message}`);
      this.saving = false;
    }
  }

  private pickDate(): void {
    const now: Date = new Date();
    this.getUIContext().showDatePickerDialog({
      start: new Date(now.getFullYear() - 1, 0, 1),
      end: new Date(now.getFullYear() + 2, 11, 31),
      selected: new Date(`${this.date}T12:00:00`),
      onDateAccept: (d: Date) => {
        this.date = dayKey(d.getTime());
      }
    });
  }

  private addStarter(s: string): void {
    const now: string = this.reason.trim();
    if (now.toLowerCase().includes(s.toLowerCase())) {
      return;
    }
    this.reason = (now.length === 0 ? s : `${now}, ${s.toLowerCase()}`).slice(0, REASON_MAX_CHARS);
  }

  @Builder
  specialtyTile(s: Specialty) {
    Row({ space: 10 }) {
      Row() {
        Image(specialtyIcon(s)).width(18).height(18).fillColor($r('app.color.brand_accent'))
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('app.color.brand_accent_soft'))
      .borderRadius($r('app.float.radius_s'))
      Text(specialtyName(s))
        .fontSize($r('app.float.font_button'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .maxLines(2)
        .layoutWeight(1)
    }
    .width('100%')
    .height(64)
    .padding({ left: 12, right: 12 })
    .backgroundColor($r('app.color.surface'))
    .border({
      width: this.specialty === s ? 1.5 : 1,
      color: this.specialty === s ? $r('app.color.ink') : $r('app.color.border')
    })
    .borderRadius($r('app.float.radius_m'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .accessibilityGroup(true)
    .accessibilitySelected(this.specialty === s)
    .onClick(() => {
      this.specialty = s;
    })
  }

  // What the visit looks like to the app, updated as the reason changes.
  @Builder
  guess() {
    Column({ space: 10 }) {
      CapsLabel({ text: $r('app.string.dv_guess') })
      ForEach(this.plan, (g: PlanGroup) => {
        Row({ space: 10 }) {
          Column({ space: 2 }) {
            Text(g.title)
              .fontSize($r('app.float.font_button'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
            Text(g.fromReason ? g.likely : $r('app.string.dv_guess_usual'))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_3'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          if (g.fromReason) {
            Text($r('app.string.dv_guess_yours'))
              .fontSize($r('app.float.font_caption'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.brand_text'))
          }
        }
        .width('100%')
      }, (g: PlanGroup) => `${g.purpose}-${g.fromReason}`)
      if (knownNames(this.plan).length > 0) {
        Row({ space: 8 }) {
          RiskShape({ risk: 'KNOWN_RISK', dim: 20 })
            .accessibilityLevel('no-hide-descendants')
          Text($r('app.string.dv_guess_avoid', knownNames(this.plan).length))
            .fontSize($r('app.float.font_small'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.risk_known_text'))
            .layoutWeight(1)
        }
        .width('100%')
        .padding(10)
        .backgroundColor($r('app.color.risk_known_tint'))
        .borderRadius($r('app.float.radius_s'))
        .accessibilityGroup(true)
      }
      Text($r('app.string.dv_guess_caption'))
        .fontSize($r('app.float.font_micro'))
        .fontColor($r('app.color.ink_4'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface_alt'))
    .borderRadius($r('app.float.radius_ml'))
    .animation({ duration: Motion.reduced ? 0 : 180, curve: Curve.EaseOut })
  }

  build() {
    NavDestination() {
      Column() {
        ScreenHeader({ title: $r('app.string.dv_new_title'), settings: false })
        Scroll() {
          Column({ space: 10 }) {
            CapsLabel({ text: $r('app.string.dv_who') })
            GridRow({ columns: 2, gutter: 10 }) {
              ForEach(SPECIALTIES, (s: Specialty) => {
                GridCol() {
                  this.specialtyTile(s)
                }
              }, (s: Specialty) => s)
            }
            .width('100%')

            CapsLabel({ text: $r('app.string.dv_why') })
              .margin({ top: 10 })
            TextArea({ text: this.reason, placeholder: $r('app.string.dv_why_hint') })
              .height(96)
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1.5, color: $r('app.color.border_strong') })
              .borderRadius($r('app.float.radius_m'))
              .maxLength(REASON_MAX_CHARS)
              .onChange((v: string) => {
                this.reason = v;
              })
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(REASON_STARTERS, (s: string) => {
                Text(s)
                  .fontSize($r('app.float.font_small'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.ink'))
                  .height($r('app.float.chip_height'))
                  .padding({ left: 14, right: 14 })
                  .margin({ right: 8, bottom: 8 })
                  .backgroundColor($r('app.color.surface_alt'))
                  .borderRadius(22)
                  .onClick(() => {
                    this.addStarter(s);
                  })
              }, (s: string) => s)
            }
            .width('100%')

            this.guess()

            CapsLabel({ text: $r('app.string.dv_when') })
              .margin({ top: 10 })
            Row({ space: 8 }) {
              Text(dayLabel(new Date(`${this.date}T12:00:00`).getTime(), Date.now()))
                .fontSize($r('app.float.font_headline'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.ink'))
                .layoutWeight(1)
              Text($r('app.string.dv_change_date'))
                .fontSize($r('app.float.font_small'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.brand_text'))
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.border') })
            .borderRadius($r('app.float.radius_m'))
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
            .accessibilityGroup(true)
            .onClick(() => {
              this.pickDate();
            })

            CapsLabel({ text: $r('app.string.dv_worries') })
              .margin({ top: 10 })
            TextArea({ text: this.worries, placeholder: $r('app.string.dv_worries_hint') })
              .height(72)
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1.5, color: $r('app.color.border_strong') })
              .borderRadius($r('app.float.radius_m'))
              .maxLength(REASON_MAX_CHARS)
              .onChange((v: string) => {
                this.worries = v;
              })

            CapsLabel({ text: $r('app.string.dv_doctor_name') })
              .margin({ top: 10 })
            TextInput({ text: this.doctor, placeholder: $r('app.string.dv_doctor_hint') })
              .height(52)
              .fontColor($r('app.color.ink'))
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1, color: $r('app.color.border') })
              .borderRadius($r('app.float.radius_m'))
              .maxLength(DOCTOR_MAX_CHARS)
              .onChange((v: string) => {
                this.doctor = v;
              })
          }
          .alignItems(HorizontalAlign.Start)
          .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), bottom: 24 })
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)

        Row() {
          PrimaryButton({
            label: $r('app.string.dv_create'),
            active: !this.saving,
            onTap: () => {
              this.create();
            }
          })
        }
        .width('100%')
        .padding({ left: $r('app.float.space_m'), right: $r('app.float.space_m'), top: 10, bottom: 14 })
        .backgroundColor($r('app.color.bg'))
        .border({ width: { top: 1 }, color: $r('app.color.border') })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .onReady((ctx: NavDestinationContext) => {
      const p: DoctorPrepParam | undefined = ctx.pathInfo.param as DoctorPrepParam | undefined;
      const s: Specialty | undefined = SPECIALTIES.find((x: Specialty) => x === p?.specialty);
      if (s !== undefined) {
        this.specialty = s;
      }
    })
  }
}
