// Privacy (F-45, F-46): app lock switch and "What left my phone" — the ledger of every outbound request.

import { Ledger, LedgerEntry } from '../privacy/Ledger';
import { AppLock } from '../common/AppLock';
import { dateTime } from '../common/Format';
import { SectionHeader } from '../components/Common';
import { toast } from '../common/Toast';

@ComponentV2
export struct PrivacyPage {
  @Local entries: LedgerEntry[] = [];
  @Local lockOn: boolean = false;
  @Local loaded: boolean = false;

  aboutToAppear(): void {
    this.lockOn = AppLock.isEnabled();
    this.load();
  }

  private async load(): Promise<void> {
    this.entries = await Ledger.list();
    this.loaded = true;
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 8 }) {
            Image($r('app.media.ic_lock')).width(32).height(32).fillColor($r('app.color.brand_accent'))
            Text($r('app.string.privacy_promise'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('sys.color.font_primary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius($r('app.float.radius_m'))

          Row() {
            Column({ space: 2 }) {
              Text($r('app.string.privacy_lock'))
                .fontSize($r('app.float.font_body'))
                .fontColor($r('sys.color.font_primary'))
              Text($r('app.string.privacy_lock_hint'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.lockOn })
              .selectedColor($r('app.color.brand_accent'))
              .onChange(async (on: boolean) => {
                const ok: boolean = await AppLock.setEnabled(on);
                this.lockOn = ok ? on : false;
                if (!ok) {
                  toast(this.getUIContext(), $r('app.string.privacy_lock_unavailable'));
                }
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius($r('app.float.radius_m'))

          SectionHeader({
            title: $r('app.string.privacy_title'),
            action: this.entries.length > 0 ? $r('app.string.privacy_clear') : '',
            onAction: async () => {
              await Ledger.clear();
              this.load();
            }
          })
          if (this.loaded && this.entries.length === 0) {
            Text($r('app.string.privacy_empty'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
              .padding(16)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius($r('app.float.radius_m'))
          }
          ForEach(this.entries, (e: LedgerEntry) => {
            Column({ space: 4 }) {
              Row() {
                Text(e.endpoint)
                  .fontSize($r('app.float.font_body'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                  .layoutWeight(1)
                Text(e.outcome)
                  .fontSize($r('app.float.font_caption'))
                  .fontColor(e.outcome === 'BLOCKED' ? $r('app.color.risk_known') : $r('sys.color.font_secondary'))
              }
              .width('100%')
              Text(`${dateTime(e.ts, Date.now())} · sent: ${e.fields.join(', ')} · ${e.bytes} B`)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(14)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius($r('app.float.radius_m'))
          }, (e: LedgerEntry) => `${e.ts}-${e.endpoint}`)
        }
        .padding({ left: 16, right: 16, bottom: 32 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title($r('app.string.privacy_nav'))
    .backgroundColor($r('app.color.page_bg'))
  }
}
