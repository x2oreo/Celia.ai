// Doctor visits (DESIGN.md §10.1a "07 Doctor visits"): the gallery. One page per doctor the user has seen or is
// about to see; the latest across the full width, the earlier ones in a two-column grid. Tap opens the visit page,
// long press deletes it. Visits live on this phone only (doctor/VisitStore.ets).

import { promptAction } from '@kit.ArkUI';
import { LocalStore, StoreTopic } from '../data/LocalStore';
import { DoctorVisit, VisitStore } from '../doctor/VisitStore';
import { Specialty, SPECIALTIES } from '../doctor/DoctorPrep';
import { DoctorPrepParam, Routes, VisitParam } from '../common/Routes';
import { CapsLabel, PrimaryButton, resText, ScreenHeader } from '../components/Common';
import { SpecialtyWell, VisitCard } from '../components/VisitParts';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('DoctorVisitsPage');

@ComponentV2
export struct DoctorVisitsPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local visits: DoctorVisit[] = [];
  @Local loaded: boolean = false;
  private unsubscribe: () => void = () => {
  };

  aboutToAppear(): void {
    this.reload();
    this.unsubscribe = LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'settings') {
        this.reload();
      }
    });
  }

  aboutToDisappear(): void {
    this.unsubscribe();
  }

  private async reload(): Promise<void> {
    this.visits = await VisitStore.list();
    this.loaded = true;
  }

  private open(v: DoctorVisit): void {
    this.navStack.pushPathByName(Routes.DOCTOR_VISIT, new VisitParam(v.id));
  }

  private newVisit(specialty: string): void {
    this.navStack.pushPathByName(Routes.DOCTOR_VISIT_NEW, specialty === '' ? null : new DoctorPrepParam(specialty));
  }

  private confirmDelete(v: DoctorVisit): void {
    const ui: UIContext = this.getUIContext();
    ui.getPromptAction().showDialog({
      title: resText(ui, $r('app.string.dv_delete_title')),
      message: resText(ui, $r('app.string.dv_delete_body')),
      buttons: [
        { text: resText(ui, $r('app.string.agent_cancel')), color: $r('app.color.ink_2') },
        { text: resText(ui, $r('app.string.chats_delete')), color: $r('app.color.danger') }
      ]
    }).then((r: promptAction.ShowDialogSuccessResponse) => {
      if (r.index === 1) {
        VisitStore.remove(v.id).catch((e: Error) => log.warn(`delete visit: ${e.message}`));
      }
    }).catch((e: Error) => log.warn(`delete dialog: ${e.message}`));
  }

  @Builder
  cardMenu(v: DoctorVisit) {
    Menu() {
      MenuItem({ content: $r('app.string.dv_delete') })
        .contentFontColor($r('app.color.danger'))
        .onClick(() => {
          this.confirmDelete(v);
        })
    }
  }

  // First run: what this is, and one tap per kind of doctor.
  @Builder
  empty() {
    Column({ space: 12 }) {
      SpecialtyWell({ specialty: 'GP', dim: 56 })
      Text($r('app.string.dv_empty_title'))
        .fontSize($r('app.float.font_title_3'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      Text($r('app.string.dv_empty_body'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_3'))
        .lineHeight(20)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 28, bottom: 28 })
    .border({ width: 2, color: $r('app.color.border_strong'), style: BorderStyle.Dashed })
    .borderRadius($r('app.float.radius_l'))
  }

  @Builder
  newTile() {
    Column({ space: 8 }) {
      Image($r('app.media.ic_plus')).width(24).height(24).fillColor($r('app.color.ink_3'))
      Text($r('app.string.dv_new'))
        .fontSize($r('app.float.font_button'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink_3'))
    }
    .width('100%')
    .height(172)
    .justifyContent(FlexAlign.Center)
    .border({ width: 2, color: $r('app.color.border_strong'), style: BorderStyle.Dashed })
    .borderRadius($r('app.float.radius_l'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .accessibilityGroup(true)
    .onClick(() => {
      this.newVisit('');
    })
  }

  build() {
    NavDestination() {
      Column() {
        ScreenHeader({ title: $r('app.string.dv_title') })
        Scroll() {
          Column({ space: 12 }) {
            Text($r('app.string.dv_intro'))
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink_3'))
              .lineHeight(20)
              .width('100%')
            if (this.loaded && this.visits.length === 0) {
              this.empty()
            } else if (this.visits.length > 0) {
              CapsLabel({ text: $r('app.string.dv_latest') })
                .margin({ top: 4 })
              VisitCard({
                visit: this.visits[0],
                wide: true,
                onTap: () => {
                  this.open(this.visits[0]);
                }
              })
                .bindContextMenu(this.cardMenu(this.visits[0]), ResponseType.LongPress)
              CapsLabel({ text: $r('app.string.dv_earlier', this.visits.length - 1) })
                .margin({ top: 8 })
              GridRow({ columns: 2, gutter: 12 }) {
                ForEach(this.visits.slice(1), (v: DoctorVisit) => {
                  GridCol() {
                    VisitCard({
                      visit: v,
                      onTap: () => {
                        this.open(v);
                      }
                    })
                      .bindContextMenu(this.cardMenu(v), ResponseType.LongPress)
                  }
                }, (v: DoctorVisit) => `${v.id}-${v.sharedAt}`)
                GridCol() {
                  this.newTile()
                }
              }
              .width('100%')
            }
            Text($r('app.string.dv_privacy'))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.ink_4'))
              .width('100%')
              .margin({ top: 4 })
          }
          .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), bottom: 24 })
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)

        Row() {
          PrimaryButton({
            label: $r('app.string.dv_new'),
            icon: $r('app.media.ic_plus'),
            onTap: () => {
              this.newVisit('');
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
      // Opened by the agent's tile for one kind of doctor: go straight to a new visit for it.
      const p: DoctorPrepParam | undefined = ctx.pathInfo.param as DoctorPrepParam | undefined;
      const s: Specialty | undefined = SPECIALTIES.find((x: Specialty) => x === p?.specialty);
      if (s !== undefined) {
        this.navStack.pushPathByName(Routes.DOCTOR_VISIT_NEW, new DoctorPrepParam(s), false);
      }
    })
  }
}
