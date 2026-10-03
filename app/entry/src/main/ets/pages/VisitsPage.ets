// Doctor visits (B6): saved visits (upcoming first) and "Add a visit" — which doctor, when, why, what worries you.
// Saving opens the deterministic brief for that visit (DoctorPrepPage), where the optional AI summary is made.
// Everything stays on this phone (doctor/VisitStore.ets); only the summary request leaves it, redacted.

import { promptAction } from '@kit.ArkUI';
import { DoctorPrepParam, Routes } from '../common/Routes';
import { toast } from '../common/Toast';
import { dayKey } from '../reminders/DoseSchedule';
import { Specialty, SPECIALTIES, specialtyName, visitDay } from '../doctor/DoctorPrep';
import { DoctorVisit, newVisit, nextVisitId, sortVisits, VISIT_TEXT_MAX } from '../doctor/Visit';
import { VisitStore } from '../doctor/VisitStore';
import { EmptyCard, PrimaryButton, QuietButton, SectionHeader } from '../components/Common';

@ComponentV2
export struct VisitsPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local visits: DoctorVisit[] = [];
  @Local today: string = dayKey(Date.now());
  @Local loaded: boolean = false;
  @Local adding: boolean = false;
  @Local specialty: Specialty = 'GP';
  @Local date: string = dayKey(Date.now());
  @Local reason: string = '';
  @Local worries: string = '';
  private saving: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.today = dayKey(Date.now());
    this.visits = sortVisits(await VisitStore.list(), this.today);
    this.loaded = true;
  }

  private startAdding(): void {
    this.specialty = 'GP';
    this.date = dayKey(Date.now());
    this.reason = '';
    this.worries = '';
    this.adding = true;
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

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      const v: DoctorVisit = newVisit(nextVisitId(await VisitStore.list()), this.specialty, this.date, this.reason,
        this.worries, Date.now());
      await VisitStore.save(v);
      this.adding = false;
      await this.load();
      this.navStack.pushPathByName(Routes.DOCTOR_PREP, new DoctorPrepParam(v.specialty, v.id));
    } finally {
      this.saving = false;
    }
  }

  private async confirmDelete(v: DoctorVisit): Promise<void> {
    try {
      const r: promptAction.ShowDialogSuccessResponse = await this.getUIContext().getPromptAction().showDialog({
        title: $r('app.string.doc_delete_title'),
        message: $r('app.string.doc_delete_msg'),
        buttons: [
          { text: $r('app.string.doc_cancel'), color: $r('app.color.ink') },
          { text: $r('app.string.doc_delete'), color: $r('app.color.danger') }
        ]
      });
      if (r.index !== 1) {
        return;
      }
    } catch (e) {
      return;   // dismissed
    }
    await VisitStore.remove(v.id);
    toast(this.getUIContext(), $r('app.string.doc_deleted'));
    this.load();
  }

  private isPastHeader(i: number): boolean {
    const v: DoctorVisit = this.visits[i];
    return v.date < this.today && (i === 0 || this.visits[i - 1].date >= this.today);
  }

  @Builder
  specialtyChip(s: Specialty) {
    Text(specialtyName(s))
      .fontSize($r('app.float.font_small'))
      .fontColor(this.specialty === s ? $r('app.color.chat_user_text') : $r('app.color.ink'))
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .margin({ right: 8, bottom: 8 })
      .backgroundColor(this.specialty === s ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
      .border({ width: this.specialty === s ? 0 : 1.5, color: $r('app.color.border_strong') })
      .borderRadius(100)
      .onClick(() => {
        this.specialty = s;
      })
  }

  @Builder
  form() {
    Column({ space: 12 }) {
      Text($r('app.string.doc_new_visit'))
        .fontSize($r('app.float.font_title_3'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      SectionHeader({ title: $r('app.string.doc_which_doctor') })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(SPECIALTIES, (s: Specialty) => {
          this.specialtyChip(s)
        }, (s: Specialty) => s)
      }
      .width('100%')

      SectionHeader({ title: $r('app.string.doc_when') })
      Row({ space: 12 }) {
        Text(visitDay(this.date))
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)
        Text($r('app.string.doc_change_date'))
          .fontSize($r('app.float.font_small'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_text'))
      }
      .width('100%')
      .constraintSize({ minHeight: $r('app.float.touch_min') })
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border') })
      .borderRadius($r('app.float.radius_m'))
      .accessibilityGroup(true)
      .onClick(() => this.pickDate())

      SectionHeader({ title: $r('app.string.doc_reason') })
      TextInput({ text: this.reason, placeholder: $r('app.string.doc_reason_hint') })
        .maxLength(VISIT_TEXT_MAX)
        .height($r('app.float.button_height'))
        .backgroundColor($r('app.color.surface_alt'))
        .onChange((v: string) => {
          this.reason = v;
        })

      SectionHeader({ title: $r('app.string.doc_worries') })
      TextArea({ text: this.worries, placeholder: $r('app.string.doc_worries_hint') })
        .maxLength(VISIT_TEXT_MAX)
        .height(110)
        .backgroundColor($r('app.color.surface_alt'))
        .onChange((v: string) => {
          this.worries = v;
        })
      Text($r('app.string.doc_privacy_caption'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
        .width('100%')

      PrimaryButton({
        label: $r('app.string.doc_save_visit'), onTap: () => {
          this.save();
        }
      })
      QuietButton({
        label: $r('app.string.doc_cancel'), onTap: () => {
          this.adding = false;
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  visitCard(v: DoctorVisit) {
    Row({ space: 8 }) {
      Column({ space: 4 }) {
        Text(specialtyName(v.specialty))
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(visitDay(v.date))
          .fontSize($r('app.float.font_small'))
          .fontColor(v.date >= this.today ? $r('app.color.brand_text') : $r('app.color.ink_3'))
        if (v.reason !== '') {
          Text(v.reason)
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_2'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (v.summary !== '') {
          Text($r('app.string.doc_has_summary'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_3'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Row() {
        Image($r('app.media.ic_delete')).width(20).height(20).fillColor($r('app.color.ink_3'))
      }
      .width($r('app.float.touch_min'))
      .height($r('app.float.touch_min'))
      .justifyContent(FlexAlign.Center)
      .accessibilityText($r('app.string.doc_delete'))
      .onClick(() => {
        this.confirmDelete(v);
      })
    }
    .width('100%')
    .padding({ left: 14, top: 14, bottom: 14, right: 4 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_m'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .onClick(() => {
      this.navStack.pushPathByName(Routes.DOCTOR_PREP, new DoctorPrepParam(v.specialty, v.id));
    })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          if (this.adding) {
            this.form()
          } else {
            Text($r('app.string.doc_visits_intro'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.ink_3'))
              .width('100%')
            if (this.loaded && this.visits.length === 0) {
              EmptyCard({
                message: $r('app.string.doc_visits_empty'),
                action: $r('app.string.doc_add_visit'),
                onAction: () => this.startAdding()
              })
            } else if (this.visits.length > 0) {
              PrimaryButton({
                label: $r('app.string.doc_add_visit'), icon: $r('app.media.ic_plus'), onTap: () => {
                  this.startAdding();
                }
              })
              ForEach(this.visits, (v: DoctorVisit, i: number) => {
                Column({ space: 8 }) {
                  if (i === 0 && v.date >= this.today) {
                    SectionHeader({ title: $r('app.string.doc_upcoming') })
                  } else if (this.isPastHeader(i)) {
                    SectionHeader({ title: $r('app.string.doc_past') })
                  }
                  this.visitCard(v)
                }
                .width('100%')
              }, (v: DoctorVisit, i: number) => `${i}-${v.id}-${v.date}-${v.summaryAt}-${this.today}`)
            }
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
    .title($r('app.string.doc_visits_title'))
    .backgroundColor($r('app.color.bg'))
    .onShown(() => {
      this.load();
    })
    .onBackPressed(() => {
      if (this.adding) {
        this.adding = false;
        return true;
      }
      return false;
    })
  }
}
