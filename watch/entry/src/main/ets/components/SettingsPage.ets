import { ArcList, ArcListAttribute, ArcListItem, ArcListItemAttribute, LengthMetrics } from '@kit.ArkUI';
import { WatchController } from '../controller/WatchController';
import { limitsWhy } from '../vitals/WatchStatus';
import { Icon } from './Parts';
import { ListTitle } from './VitalsPage';
import { Theme } from './Theme';

/** Label, big value (optional check), one explaining line, divider. Rows that act are tappable as a whole. */
@ComponentV2
struct SettingRow {
  @Param @Require label: string;
  @Param @Require value: string;
  @Param sub: string = '';
  @Param valueColor: string = Theme.TEXT;
  @Param check: boolean = false;
  @Param tappable: boolean = false;
  @Param divider: boolean = true;
  @Event onTap: () => void = () => {};

  build() {
    Column({ space: 1 }) {
      Text(this.label).fontSize(Theme.SMALL).fontColor(Theme.TEXT_2).maxLines(1)
      Row({ space: 4 }) {
        if (this.check) {
          Icon({ src: $r('app.media.ic_check'), color: this.valueColor, glyph: 16 })
        }
        Text(this.value)
          .fontSize(Theme.TITLE + 1)
          .fontWeight(FontWeight.Bolder)
          .fontColor(this.valueColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (this.sub.length > 0) {
        Text(this.sub).fontSize(Theme.SMALL).fontColor(Theme.TEXT_2).maxLines(2)
      }
      if (this.divider) {
        Divider().color(Theme.BORDER).strokeWidth(1).margin({ top: 6 })
      }
    }
    .width(Theme.LIST_WIDTH)
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 2, bottom: 2 })
    .accessibilityGroup(true)
    .accessibilityText(`${this.label}: ${this.value}. ${this.sub}`)
    .onClick(() => {
      if (this.tappable) {
        this.onTap();
      }
    })
  }
}

/** 05 Settings: the phone link, today's limits and why, genotype, reminder, watch id. Demo controls live elsewhere. */
@ComponentV2
export struct SettingsPage {
  @Param @Require ctrl: WatchController;

  paired(): boolean {
    return this.ctrl.pairState === 'PAIRED';
  }

  pairValue(): string {
    switch (this.ctrl.pairState) {
      case 'PAIRED':
        return 'Paired';
      case 'NOT_PAIRED':
        return 'Pair with phone';
      case 'ERROR':
        return 'Unavailable';
      default:
        return 'Checking...';
    }
  }

  pairSub(): string {
    switch (this.ctrl.pairState) {
      case 'PAIRED':
        return this.ctrl.syncState === 'OK' ? 'Your phone · synced' :
          this.ctrl.syncState === 'PENDING' ? 'Your phone · syncing...' : 'Your phone · offline';
      case 'NOT_PAIRED':
        return 'Opens pairing';
      case 'ERROR':
        return "Can't reach Celia. Tap to try pairing.";
      default:
        return '';
    }
  }

  pairColor(): string {
    switch (this.ctrl.pairState) {
      case 'NOT_PAIRED':
        return Theme.BRAND;
      case 'ERROR':
        return Theme.ELEVATED;
      default:
        return Theme.TEXT;
    }
  }

  medName(): string {
    const n = this.ctrl.medicationName;
    return `${n.charAt(0).toUpperCase()}${n.substring(1)}`;
  }

  pair(): void {
    this.ctrl.startPairing().then((err: string) => {
      if (err.length > 0) {
        try {
          this.getUIContext().getPromptAction().showToast({ message: err, duration: 2000 });
        } catch (e) {
          // Toast is cosmetic; the pairing screen shows the error too.
        }
      }
    });
  }

  build() {
    ArcList({ initialIndex: 1 }) {
      ArcListItem() {
        ListTitle({ title: 'Settings' })
      }
      .autoScale(false)
      ArcListItem() {
        SettingRow({ label: 'Phone', value: this.pairValue(), sub: this.pairSub(), valueColor: this.pairColor(),
          check: this.paired(), tappable: !this.paired(), onTap: () => {
            this.pair();
          } })
      }
      .autoScale(false)
      ArcListItem() {
        SettingRow({ label: 'Limits now', value: `${this.ctrl.limitLow}-${this.ctrl.limitHigh} bpm`,
          sub: limitsWhy(this.ctrl.genotype, this.ctrl.activity, this.ctrl.riskyDrug) })
      }
      .autoScale(false)
      ArcListItem() {
        SettingRow({ label: 'Genotype',
          value: this.ctrl.genotype === 'UNKNOWN' ? 'Not set on phone' : this.ctrl.genotype,
          sub: this.ctrl.genotype === 'UNKNOWN' ? '' : 'From your phone' })
      }
      .autoScale(false)
      ArcListItem() {
        SettingRow({ label: 'Dose reminder',
          value: this.ctrl.medReminderTime.length > 0 ? `${this.ctrl.medReminderTime} · ${this.medName()}` : 'Off',
          sub: this.ctrl.medReminderTime.length > 0 ? 'Daily, from your phone' : 'Set it on your phone' })
      }
      .autoScale(false)
      ArcListItem() {
        SettingRow({ label: 'Watch ID', value: this.ctrl.deviceId.length > 0 ? this.ctrl.deviceId.toUpperCase() : '-',
          divider: false })
      }
      .autoScale(false)
      ArcListItem() {
        Text('Not a medical device. Heart rate only, never QT or an ECG.')
          .fontSize(Theme.SMALL)
          .fontColor(Theme.TEXT_2)
          .textAlign(TextAlign.Center)
          .width(170)
          .padding({ top: 8, bottom: 48 })
      }
      .autoScale(false)
    }
    .space(LengthMetrics.vp(8))
    .scrollBar(BarState.Auto)
    .width('100%')
    .height('100%')
  }
}
