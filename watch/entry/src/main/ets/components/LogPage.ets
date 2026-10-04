import { WatchController } from '../controller/WatchController';
import { SymptomKind } from '../model/WatchMetric';
import { Feelings, feelingLabel } from './CheckIn';
import { Caps, Icon } from './Parts';
import { Theme } from './Theme';

/** How long "Logged: Dizzy" replaces the title. */
const CONFIRM_MS: number = 3000;

function hhmm(ms: number): string {
  const d = new Date(ms);
  const h = d.getHours();
  const m = d.getMinutes();
  return `${h < 10 ? '0' : ''}${h}:${m < 10 ? '0' : ''}${m}`;
}

/**
 * 04 Log: how you feel, today's dose and SOS. A feeling replaces the title with a confirmation for 3 s; the dose
 * button becomes a done state until midnight. SOS opens the same cancellable countdown an alert's Need help starts.
 */
@ComponentV2
export struct LogPage {
  @Param @Require ctrl: WatchController;
  @Local logged: SymptomKind | undefined = undefined;
  @Local loggedAt: number = 0;
  private timer: number = -1;

  aboutToDisappear(): void {
    clearTimeout(this.timer);
  }

  medName(): string {
    const n = this.ctrl.medicationName;
    return `${n.charAt(0).toUpperCase()}${n.substring(1)}`;
  }

  pick(kind: SymptomKind): void {
    this.ctrl.logSymptom(kind);
    this.logged = kind;
    this.loggedAt = Date.now();
    clearTimeout(this.timer);
    this.timer = setTimeout(() => {
      this.logged = undefined;
    }, CONFIRM_MS);
  }

  /** Today's dose time, or 0. Re-checked against the date so it resets at midnight. */
  doseAt(): number {
    const at = this.ctrl.doseTakenAt;
    return at > 0 && new Date(at).toDateString() === new Date().toDateString() ? at : 0;
  }

  @Builder
  doseButton() {
    if (this.doseAt() > 0) {
      Row({ space: 5 }) {
        Icon({ src: $r('app.media.ic_check'), color: Theme.CALM, glyph: 14 })
        Text(`${this.medName()} taken ${hhmm(this.doseAt())}`)
          .fontSize(Theme.BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.CALM)
          .maxLines(1)
      }
      .height(Theme.PILL_HEIGHT)
      .padding({ left: 14, right: 14 })
      .borderRadius(Theme.PILL_HEIGHT / 2)
      .backgroundColor(Theme.SURFACE)
      .accessibilityGroup(true)
      .accessibilityText(`${this.medName()} taken at ${hhmm(this.doseAt())}`)
    } else {
      Button(`Took ${this.medName()}`, { type: ButtonType.Capsule, stateEffect: true })
        .width(148)
        .height(Theme.PILL_HEIGHT)
        .fontSize(Theme.BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .backgroundColor(Theme.BRAND)
        .accessibilityText(`Log ${this.ctrl.medicationName} as taken`)
        .onClick(() => {
          this.ctrl.logMedication();
        })
    }
  }

  build() {
    Column({ space: 7 }) {
      Caps({ text: 'LOG' })
      Text(this.logged === undefined ? 'How do you feel?' : `Logged: ${feelingLabel(this.logged)}`)
        .fontSize(Theme.TITLE + 1)
        .fontWeight(FontWeight.Bolder)
        .fontColor(Theme.TEXT)
        .margin({ top: -3 })
      Feelings({ chosen: this.logged, onPick: (k: SymptomKind) => this.pick(k) })
      if (this.logged !== undefined) {
        Text(`${hhmm(this.loggedAt)} · sent to your phone`).fontSize(Theme.SMALL).fontColor(Theme.TEXT)
      }
      this.doseButton()
      Button('SOS', { type: ButtonType.Capsule, stateEffect: true })
        .width(84)
        .height(32)
        .fontSize(Theme.BODY)
        .fontWeight(FontWeight.Bolder)
        .fontColor(Theme.ALERT)
        .backgroundColor(Theme.ALERT_TINT)
        .border({ width: 1.5, color: Theme.ALERT })
        .accessibilityText('Start S O S countdown')
        .onClick(() => {
          this.ctrl.needHelp();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ bottom: 10 })
    .backgroundColor(Theme.BG)
  }
}
