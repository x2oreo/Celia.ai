// Check history (F-23): every medicine check, newest first, filterable by risk. Tap to reopen the verdict.

import { CheckParam, Routes } from '../common/Routes';
import { dateTime } from '../common/Format';
import { LocalStore, StoreTopic } from '../data/LocalStore';
import { ScanRecord } from '../model/ScanRecord';
import { RiskBadge } from '../components/Common';

type HistoryFilter = 'ALL' | 'RISKY' | 'OK' | 'UNKNOWN';

class FilterSpec {
  key: HistoryFilter;
  label: Resource;

  constructor(key: HistoryFilter, label: Resource) {
    this.key = key;
    this.label = label;
  }
}

export function matchesFilter(s: ScanRecord, f: HistoryFilter): boolean {
  switch (f) {
    case 'RISKY':
      return s.risk === 'KNOWN_RISK' || s.risk === 'POSSIBLE_RISK' || s.risk === 'CONDITIONAL_RISK' ||
        s.combo !== 'NONE';
    case 'OK':
      return s.risk === 'NOT_LISTED' && s.combo === 'NONE';
    case 'UNKNOWN':
      return s.risk === 'UNKNOWN_DRUG';
    default:
      return true;
  }
}

@ComponentV2
export struct HistoryPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local scans: ScanRecord[] = [];
  @Local filter: HistoryFilter = 'ALL';
  @Local loaded: boolean = false;
  private unsubscribe: () => void = () => {
  };
  private filters: FilterSpec[] = [
    new FilterSpec('ALL', $r('app.string.history_all')),
    new FilterSpec('RISKY', $r('app.string.history_risky')),
    new FilterSpec('OK', $r('app.string.history_ok')),
    new FilterSpec('UNKNOWN', $r('app.string.history_unknown'))
  ];

  aboutToAppear(): void {
    this.reload();
    this.unsubscribe = LocalStore.get().onChange((t: StoreTopic) => {
      if (t === 'scans') {
        this.reload();
      }
    });
  }

  aboutToDisappear(): void {
    this.unsubscribe();
  }

  private async reload(): Promise<void> {
    this.scans = await LocalStore.get().listScans();
    this.loaded = true;
  }

  private visible(): ScanRecord[] {
    return this.scans.filter((s: ScanRecord) => matchesFilter(s, this.filter));
  }

  @Builder
  chip(f: FilterSpec) {
    Text(f.label)
      .fontSize($r('app.float.font_small'))
      .fontColor(this.filter === f.key ? $r('app.color.on_accent') : $r('sys.color.font_primary'))
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.filter === f.key ? $r('app.color.brand_accent') : $r('app.color.card_bg'))
      .borderRadius(100)
      .onClick(() => {
        this.filter = f.key;
      })
  }

  @Builder
  row(s: ScanRecord) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(s.ingredient === '' ? s.query : s.ingredient)
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(s.combo !== 'NONE' ? `${dateTime(s.ts, Date.now())} · interaction` : dateTime(s.ts, Date.now()))
          .fontSize($r('app.float.font_caption'))
          .fontColor(s.combo !== 'NONE' ? $r('app.color.risk_known') : $r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      RiskBadge({ risk: s.risk, compact: true })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius($r('app.float.radius_m'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
    .onClick(() => {
      this.navStack.pushPathByName(Routes.CHECK_RESULT, new CheckParam(s.query, false));
    })
  }

  build() {
    NavDestination() {
      Column({ space: 12 }) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.filters, (f: FilterSpec) => {
              this.chip(f)
            }, (f: FilterSpec) => f.key)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        if (this.loaded && this.visible().length === 0) {
          Column({ space: 8 }) {
            Image($r('app.media.ic_history')).width(48).height(48).fillColor($r('sys.color.icon_secondary'))
            Text(this.scans.length === 0 ? $r('app.string.history_empty') : $r('app.string.history_empty_filter'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding({ top: 64 })
        } else {
          List({ space: 8 }) {
            ForEach(this.visible(), (s: ScanRecord) => {
              ListItem() {
                this.row(s)
              }
            }, (s: ScanRecord) => `${s.id}`)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .padding({ left: 16, right: 16, top: 8 })
      .width('100%')
      .height('100%')
    }
    .title($r('app.string.history_title'))
    .backgroundColor($r('app.color.page_bg'))
  }
}
