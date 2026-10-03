// Medicines tab (design B4): header, search-first check, quick links (reminders, check history) seen without
// scrolling, recently checked chips, my medicines as a two-column grid.

import { AskParam, CheckParam, Routes } from '../common/Routes';
import { DrugChecker } from '../drugs/DrugChecker';
import { DrugEntry } from '../drugs/DrugDataset';
import { LocalStore, StoreTopic } from '../data/LocalStore';
import { Medication } from '../model/Medication';
import { ScanRecord } from '../model/ScanRecord';
import { RiskLevel } from '../model/DrugVerdict';
import { AddMedForm } from '../components/AddMedForm';
import { MedicineDetailSheet } from '../components/MedicineDetailSheet';
import { medSubtitle } from '../drugs/MedFacts';
import {
  EmptyCard, QuickReplyChip, resText, RiskBadge, ScreenHeader, SectionHeader, StatusChip
} from '../components/Common';
import { RiskUi } from '../common/RiskUi';

export function medRisk(m: Medication): RiskLevel {
  const e: DrugEntry | undefined = DrugChecker.get().entry(m.ingredient) ?? DrugChecker.get().resolve(m.name);
  return e === undefined ? 'UNKNOWN_DRUG' : e.risk;
}

const RECENT_MAX: number = 6;
const MED_CARD_HEIGHT: number = 164;

@ComponentV2
export struct MedicinesPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local query: string = '';
  @Local meds: Medication[] = [];
  @Local recent: ScanRecord[] = [];
  @Local showAdd: boolean = false;
  @Local detail: Medication | undefined = undefined;
  @Local showDetail: boolean = false;
  private unsubscribe: () => void = () => {
  };

  aboutToAppear(): void {
    this.reload();
    this.unsubscribe = LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'meds' || t === 'scans') {
        this.reload();
      }
    });
  }

  aboutToDisappear(): void {
    this.unsubscribe();
  }

  private async reload(): Promise<void> {
    this.meds = await LocalStore.get().listMeds();
    // Latest check per medicine, newest first.
    const seen: string[] = [];
    const out: ScanRecord[] = [];
    for (const s of await LocalStore.get().listScans()) {
      const key: string = (s.ingredient === '' ? s.query : s.ingredient).toLowerCase();
      if (!seen.includes(key) && out.length < RECENT_MAX) {
        seen.push(key);
        out.push(s);
      }
    }
    this.recent = out;
  }

  private check(): void {
    const q: string = this.query.trim();
    if (q.length === 0) {
      return;
    }
    this.navStack.pushPathByName(Routes.CHECK_RESULT, new CheckParam(q, true));
  }

  private label(s: ScanRecord): string {
    const t: string = /^[0-9]{8,14}$/.test(s.query) && s.ingredient !== '' ? s.ingredient : s.query;
    return t.length > 0 ? t.charAt(0).toUpperCase() + t.slice(1) : t;
  }

  // "Cipralex. Known risk. Depression and anxiety. 10 mg": the verdict by its word.
  private spoken(m: Medication): string {
    const parts: string[] = [m.name, resText(this.getUIContext(), RiskUi.label(medRisk(m))), medSubtitle(m), m.dose];
    return parts.filter((p: string) => p !== '').join('. ');
  }

  @Builder
  addSheet() {
    Scroll() {
      Column({ space: 16 }) {
        Text($r('app.string.meds_add_title'))
          .fontSize($r('app.float.font_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
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
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }

  @Builder
  medMenu(m: Medication) {
    Menu() {
      MenuItem({ content: $r('app.string.meds_remove') })
        .onClick(() => {
          LocalStore.get().removeMed(m.id);
        })
    }
  }

  @Builder
  detailSheet() {
    MedicineDetailSheet({
      med: this.detail,
      meds: this.meds,
      onCheck: (m: Medication) => {
        this.showDetail = false;
        this.navStack.pushPathByName(Routes.CHECK_RESULT, new CheckParam(m.ingredient === '' ? m.name : m.ingredient,
          false));
      },
      onRemind: (m: Medication) => {
        this.showDetail = false;
        this.navStack.pushPathByName(Routes.REMINDERS, m.id);
      },
      onAsk: (m: Medication) => {
        this.showDetail = false;
        const ctx: Context | undefined = this.getUIContext().getHostContext();
        const label: string = m.name.length > 0 ? m.name.charAt(0).toUpperCase() + m.name.slice(1) : m.name;
        const q: string = ctx === undefined ? `Tell me about ${label}.` :
          ctx.resourceManager.getStringSync($r('app.string.med_ask_prompt').id, label);
        this.navStack.pushPathByName(Routes.AGENT_CHAT, new AskParam(q));
      }
    })
  }

  @Builder
  medCard(m: Medication) {
    Column() {
      RiskBadge({ risk: medRisk(m), compact: true })
      Blank()
      Text(m.name.length > 0 ? m.name.charAt(0).toUpperCase() + m.name.slice(1) : m.name)
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(medSubtitle(m) === '' ? (m.ingredient === '' ? '—' : m.ingredient) : medSubtitle(m))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
        .lineHeight(16)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 4 })
      if (m.dose !== '') {
        Text(m.dose)
          .fontSize($r('app.float.font_micro'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink_2'))
          .height(20)
          .padding({ left: 8, right: 8 })
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(10)
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .height(MED_CARD_HEIGHT)
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_ml'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .accessibilityGroup(true)
    .accessibilityText(this.spoken(m))
    .onClick(() => {
      this.detail = m;
      this.showDetail = true;
    })
    .bindContextMenu(this.medMenu(m), ResponseType.LongPress)
  }

  @Builder
  addTile() {
    Column({ space: 8 }) {
      Image($r('app.media.ic_plus')).width(20).height(20).fillColor($r('app.color.ink_3'))
      Text($r('app.string.meds_add_tile'))
        .fontSize($r('app.float.font_button'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink_3'))
    }
    .width('100%')
    .height(MED_CARD_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .border({ width: 2, color: $r('app.color.border_strong'), style: BorderStyle.Dashed })
    .borderRadius($r('app.float.radius_ml'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .accessibilityGroup(true)
    .onClick(() => {
      this.showAdd = true;
    })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        ScreenHeader({ title: $r('app.string.medicines_title'), back: false })

        // Search-first check + scan
        Row({ space: 10 }) {
          Row({ space: 10 }) {
            Image($r('app.media.ic_search')).width(20).height(20).fillColor($r('app.color.ink'))
            TextInput({ text: this.query, placeholder: $r('app.string.check_hint') })
              .layoutWeight(1)
              .height('100%')
              .padding(0)
              .backgroundColor(Color.Transparent)
              .borderRadius(0)
              .fontSize($r('app.float.font_headline'))
              .fontColor($r('app.color.ink'))
              .placeholderColor($r('app.color.ink_3'))
              .enterKeyType(EnterKeyType.Search)
              .onChange((v: string) => {
                this.query = v;
              })
              .onSubmit(() => {
                this.check();
              })
          }
          .layoutWeight(1)
          .height(56)
          .padding({ left: 16, right: 12 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1.5, color: $r('app.color.ink') })
          .borderRadius($r('app.float.radius_m'))

          Row() {
            Image($r('app.media.ic_camera')).width(24).height(24).fillColor($r('app.color.on_accent'))
          }
          .width(56)
          .height(56)
          .justifyContent(FlexAlign.Center)
          .backgroundColor($r('app.color.brand_accent'))
          .borderRadius($r('app.float.radius_m'))
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
          .accessibilityText($r('app.string.a11y_camera'))
          .onClick(() => {
            this.navStack.pushPathByName(Routes.SCAN, null);
          })
        }
        .width('100%')

        // Quick links: reminders used to sit under the grid.
        Row({ space: 8 }) {
          QuickReplyChip({
            label: $r('app.string.meds_link_reminders'),
            icon: $r('app.media.ic_bell'),
            onTap: () => {
              this.navStack.pushPathByName(Routes.REMINDERS, null);
            }
          })
          QuickReplyChip({
            label: $r('app.string.meds_link_history'),
            icon: $r('app.media.ic_history'),
            onTap: () => {
              this.navStack.pushPathByName(Routes.HISTORY, null);
            }
          })
        }
        .width('100%')

        if (this.recent.length > 0) {
          SectionHeader({
            title: $r('app.string.meds_recent'),
            action: $r('app.string.home_all'),
            onAction: () => {
              this.navStack.pushPathByName(Routes.HISTORY, null);
            }
          })
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.recent, (s: ScanRecord) => {
                StatusChip({
                  label: this.label(s),
                  risk: s.risk,
                  onTap: () => {
                    this.navStack.pushPathByName(Routes.CHECK_RESULT, new CheckParam(s.query, false));
                  }
                })
              }, (s: ScanRecord) => `${s.id}`)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .align(Alignment.Start)
        }

        SectionHeader({
          title: this.meds.length > 0 ? $r('app.string.meds_mine_count', this.meds.length) : $r('app.string.meds_mine')
        })
        if (this.meds.length === 0) {
          EmptyCard({
            message: $r('app.string.meds_empty'),
            action: $r('app.string.meds_add_tile'),
            onAction: () => {
              this.showAdd = true;
            }
          })
        } else {
          GridRow({ columns: 2, gutter: 12 }) {
            ForEach(this.meds, (m: Medication) => {
              GridCol() {
                this.medCard(m)
              }
            }, (m: Medication) => `${m.id}`)
            GridCol() {
              this.addTile()
            }
          }
          .width('100%')
        }

      }
      .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), bottom: 24 })
      .width('100%')
      .bindSheet(this.showDetail, this.detailSheet(), {
        detents: [SheetSize.LARGE, SheetSize.MEDIUM],
        showClose: true,
        backgroundColor: $r('app.color.bg'),
        onDisappear: () => {
          this.showDetail = false;
        }
      })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.bg'))
    .bindSheet(this.showAdd, this.addSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: true,
      backgroundColor: $r('app.color.bg'),
      onDisappear: () => {
        this.showAdd = false;
      }
    })
  }
}
