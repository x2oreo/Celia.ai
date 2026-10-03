// Medicines tab: check a medicine by name, my medicines (with risk), add / remove, history.

import { CheckParam, Routes } from '../common/Routes';
import { DrugChecker } from '../drugs/DrugChecker';
import { DrugEntry } from '../drugs/DrugDataset';
import { LocalStore, StoreTopic } from '../data/LocalStore';
import { Medication } from '../model/Medication';
import { RiskLevel } from '../model/DrugVerdict';
import { AddMedForm } from '../components/AddMedForm';
import { NavRow, PageTitle, PrimaryButton, RiskBadge, SecondaryButton, SectionHeader } from '../components/Common';
import { BarcodeResult, scanBox } from '../drugs/BarcodeService';
import { toast } from '../common/Toast';

export function medRisk(m: Medication): RiskLevel {
  const e: DrugEntry | undefined = DrugChecker.get().entry(m.ingredient) ?? DrugChecker.get().resolve(m.name);
  return e === undefined ? 'UNKNOWN_DRUG' : e.risk;
}

@ComponentV2
export struct MedicinesPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local query: string = '';
  @Local meds: Medication[] = [];
  @Local showAdd: boolean = false;
  private unsubscribe: () => void = () => {
  };

  aboutToAppear(): void {
    this.reload();
    this.unsubscribe = LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'meds') {
        this.reload();
      }
    });
  }

  aboutToDisappear(): void {
    this.unsubscribe();
  }

  private async reload(): Promise<void> {
    this.meds = await LocalStore.get().listMeds();
  }

  private check(): void {
    const q: string = this.query.trim();
    if (q.length === 0) {
      return;
    }
    this.navStack.pushPathByName(Routes.CHECK_RESULT, new CheckParam(q, true));
  }

  private async scan(): Promise<void> {
    const r: BarcodeResult | undefined = await scanBox(this.getUIContext().getHostContext()!);
    if (r === undefined) {
      return;
    }
    if (r.entry !== undefined) {
      this.navStack.pushPathByName(Routes.CHECK_RESULT, new CheckParam(r.gtin, true, 'BARCODE'));
    } else if (r.gtin !== '') {
      toast(this.getUIContext(), $r('app.string.scan_unknown_box'));
    } else {
      // Not a product code (e.g. a QR with text): check the text itself.
      this.navStack.pushPathByName(Routes.CHECK_RESULT, new CheckParam(r.raw, true, 'BARCODE'));
    }
  }

  @Builder
  addSheet() {
    Column({ space: 16 }) {
      Text($r('app.string.meds_add_title'))
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      AddMedForm({
        onAdded: () => {
          this.showAdd = false;
        }
      })
    }
    .padding(20)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  medRow(m: Medication) {
    Row({ space: 12 }) {
      Image($r('app.media.ic_pill')).width(22).height(22).fillColor($r('app.color.brand_accent'))
      Column({ space: 2 }) {
        Text(m.name)
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(m.dose === '' ? (m.ingredient === '' ? '—' : m.ingredient) : `${m.ingredient} · ${m.dose}`)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      RiskBadge({ risk: medRisk(m), compact: true })
    }
    .width('100%')
    .padding({ top: 14, bottom: 14, left: 16, right: 16 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.radius_m'))
  }

  @Builder
  deleteAction(m: Medication) {
    Row() {
      Image($r('app.media.ic_delete')).width(22).height(22).fillColor($r('app.color.on_accent'))
    }
    .height('100%')
    .width(72)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.risk_known'))
    .borderRadius($r('app.float.radius_m'))
    .margin({ left: 8 })
    .accessibilityText($r('app.string.meds_remove'))
    .onClick(() => {
      LocalStore.get().removeMed(m.id);
    })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        PageTitle({ title: $r('app.string.medicines_title'), subtitle: $r('app.string.medicines_subtitle') })

        // Check a medicine
        Column({ space: 12 }) {
          Text($r('app.string.check_prompt'))
            .fontSize($r('app.float.font_subtitle'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Search({ value: this.query, placeholder: $r('app.string.check_hint') })
            .height(48)
            .onChange((v: string) => {
              this.query = v;
            })
            .onSubmit((v: string) => {
              this.query = v;
              this.check();
            })
          PrimaryButton({
            label: $r('app.string.check_button'),
            icon: $r('app.media.ic_search'),
            active: this.query.trim().length > 0,
            onTap: () => this.check()
          })
          SecondaryButton({
            label: $r('app.string.scan_button'),
            icon: $r('app.media.ic_scan'),
            onTap: () => {
              this.scan();
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius($r('app.float.radius_m'))

        SectionHeader({
          title: $r('app.string.meds_mine'),
          action: $r('app.string.meds_add_short'),
          onAction: () => {
            this.showAdd = true;
          }
        })
        if (this.meds.length === 0) {
          Column({ space: 8 }) {
            Text($r('app.string.meds_empty'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
            Text($r('app.string.meds_add'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.brand_accent'))
              .onClick(() => {
                this.showAdd = true;
              })
          }
          .width('100%')
          .padding(24)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius($r('app.float.radius_m'))
        } else {
          List({ space: 8 }) {
            ForEach(this.meds, (m: Medication) => {
              ListItem() {
                this.medRow(m)
              }
              .swipeAction({ end: this.deleteAction(m) })
            }, (m: Medication) => `${m.id}`)
          }
          .width('100%')
          .scrollBarWidth(0)
          .nestedScroll({ scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
          Text($r('app.string.meds_swipe_hint'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('sys.color.font_tertiary'))
        }

        NavRow({
          icon: $r('app.media.ic_bell'),
          title: $r('app.string.rem_title'),
          subtitle: $r('app.string.rem_subtitle'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.REMINDERS, null);
          }
        })
        NavRow({
          icon: $r('app.media.ic_history'),
          title: $r('app.string.history_title'),
          subtitle: $r('app.string.history_subtitle'),
          onTap: () => {
            this.navStack.pushPathByName(Routes.HISTORY, null);
          }
        })
      }
      .padding({ left: 16, right: 16, bottom: 24 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.page_bg'))
    .bindSheet(this.showAdd, this.addSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: true,
      onDisappear: () => {
        this.showAdd = false;
      }
    })
  }
}
