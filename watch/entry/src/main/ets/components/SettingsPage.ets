import { ArcList, ArcListAttribute, ArcListItem, ArcListItemAttribute, LengthMetrics } from '@kit.ArkUI';
import { WatchController } from '../controller/WatchController';
import { Icon } from './Parts';
import { ListTitle } from './VitalsPage';
import { Theme } from './Theme';

@ComponentV2
struct SettingRow {
  @Param @Require icon: Resource;
  @Param @Require label: string;
  @Param @Require value: string;
  @Param valueColor: string = Theme.TEXT;
  @Param tappable: boolean = false;
  @Event onTap: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      Stack() {
        Icon({ src: this.icon, color: Theme.BRAND, glyph: 16 })
      }
      .width(30)
      .height(30)
      .borderRadius(15)
      .backgroundColor(Theme.BUTTON)

      Column({ space: 1 }) {
        Text(this.label.toUpperCase())
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(0.8)
          .fontColor(Theme.TEXT_3)
          .maxLines(1)
        Text(this.value)
          .fontSize(Theme.BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.valueColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.tappable) {
        Text('›').fontSize(Theme.TITLE).fontColor(Theme.TEXT_3)
      }
    }
    .width(Theme.LIST_WIDTH)
    .height(Theme.ROW_HEIGHT)
    .padding({ left: 10, right: 12 })
    .borderRadius(Theme.ROW_HEIGHT / 2)
    .backgroundColor(Theme.SURFACE)
    .accessibilityGroup(true)
    .accessibilityText(`${this.label}: ${this.value}`)
    .onClick(() => {
      if (this.tappable) {
        this.onTap();
      }
    })
  }
}

/** Settings: the phone link, today's limits and where they come from. No demo controls (those are in Simulator). */
@ComponentV2
export struct SettingsPage {
  @Param @Require ctrl: WatchController;

  pairValue(): string {
    switch (this.ctrl.pairState) {
      case 'PAIRED':
        return 'Paired';
      case 'NOT_PAIRED':
        return 'Pair with phone';
      case 'ERROR':
        return 'Unavailable';
      default:
        return 'Checking…';
    }
  }

  pairColor(): string {
    switch (this.ctrl.pairState) {
      case 'PAIRED':
        return Theme.CALM;
      case 'ERROR':
        return Theme.ELEVATED;
      default:
        return Theme.TEXT;
    }
  }

  reminderValue(): string {
    const t = this.ctrl.medReminderTime;
    return t.length > 0 ? `${t} · ${this.ctrl.medicationName}` : 'Off';
  }

  pair(): void {
    this.ctrl.startPairing().then((err: string) => {
      if (err.length > 0) {
        try {
          this.getUIContext().getPromptAction().showToast({ message: err, duration: 2000 });
        } catch (e) {
          // Toast is cosmetic.
        }
      }
    });
  }

  build() {
    ArcList({ initialIndex: 1 }) {
      ArcListItem() {
        ListTitle({ title: 'Settings' })
      }
      ArcListItem() {
        SettingRow({ icon: $r('app.media.ic_phone_link'), label: 'Phone', value: this.pairValue(),
          valueColor: this.pairColor(), tappable: true, onTap: () => {
            this.pair();
          } })
      }
      ArcListItem() {
        SettingRow({ icon: $r('app.media.ic_heart_fill'), label: 'Limits now',
          value: `${this.ctrl.limitLow}-${this.ctrl.limitHigh} bpm` })
      }
      ArcListItem() {
        SettingRow({ icon: $r('app.media.ic_shield'), label: 'Why these limits',
          value: this.ctrl.limitReason.length > 0 ? this.ctrl.limitReason : 'Standard' })
      }
      ArcListItem() {
        SettingRow({ icon: $r('app.media.ic_rhythm'), label: 'Genotype',
          value: this.ctrl.genotype === 'UNKNOWN' ? 'Not set on phone' : this.ctrl.genotype })
      }
      ArcListItem() {
        SettingRow({ icon: $r('app.media.ic_bell'), label: 'Dose reminder', value: this.reminderValue() })
      }
      ArcListItem() {
        SettingRow({ icon: $r('app.media.ic_watch'), label: 'This watch', value: this.ctrl.deviceId.slice(0, 12) })
      }
      ArcListItem() {
        Text('Celia watch · Not a medical device. Heart rate only, never QT or an ECG.')
          .fontSize(Theme.MICRO)
          .fontColor(Theme.TEXT_3)
          .textAlign(TextAlign.Center)
          .width(170)
          .padding({ top: 6, bottom: 48 })
      }
    }
    .space(LengthMetrics.vp(6))
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }
}
