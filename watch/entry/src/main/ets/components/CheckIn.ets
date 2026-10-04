import { WatchController } from '../controller/WatchController';
import { SymptomKind } from '../model/WatchMetric';
import { Bezel, Icon, PillButton } from './Parts';
import { Theme } from './Theme';

/** One answer to "How do you feel?". */
export class Feeling {
  kind: SymptomKind = 'fine';
  label: string = '';
  color: string = '';
  tint: string = '';

  constructor(kind: SymptomKind, label: string, color: string, tint: string) {
    this.kind = kind;
    this.label = label;
    this.color = color;
    this.tint = tint;
  }
}

/** Fine / Dizzy / Racing (Racing = palpitations). */
export const FEELINGS: Feeling[] = [
  new Feeling('fine', 'Fine', Theme.CALM, Theme.CALM_TINT),
  new Feeling('dizziness', 'Dizzy', Theme.ELEVATED, Theme.ELEVATED_TINT),
  new Feeling('palpitations', 'Racing', Theme.ALERT, Theme.ALERT_TINT)
];

export function feelingLabel(kind: SymptomKind): string {
  for (const f of FEELINGS) {
    if (f.kind === kind) {
      return f.label;
    }
  }
  return '';
}

/** A 52 vp feel circle: tint fill + ring; `chosen` = solid fill, `dimmed` = faded after another one was picked. */
@ComponentV2
export struct FeelButton {
  @Param @Require feeling: Feeling;
  @Param chosen: boolean = false;
  @Param dimmed: boolean = false;
  @Event onTap: () => void = () => {};

  @Builder
  glyph(color: string) {
    if (this.feeling.kind === 'fine') {
      Icon({ src: $r('app.media.ic_check'), color: color, glyph: 15 })
    } else if (this.feeling.kind === 'palpitations') {
      Icon({ src: $r('app.media.ic_heart_fill'), color: color, glyph: 14 })
    } else {
      Text('≈').fontSize(16).fontWeight(FontWeight.Bolder).fontColor(color).height(15)
    }
  }

  build() {
    Column({ space: 1 }) {
      this.glyph(Theme.TEXT)
      Text(this.feeling.label).fontSize(Theme.SMALL).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT)
    }
    .width(52)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .borderRadius(26)
    .border({ width: 1.5, color: this.feeling.color })
    .backgroundColor(this.chosen ? this.feeling.color : this.feeling.tint)
    .opacity(this.dimmed ? 0.4 : 1)
    .accessibilityGroup(true)
    .accessibilityText(this.feeling.kind === 'palpitations' ? 'Racing heart' : this.feeling.label)
    .onClick(() => this.onTap())
  }
}

/** The three feel circles in a row. */
@ComponentV2
export struct Feelings {
  @Param chosen: SymptomKind | undefined = undefined;
  @Event onPick: (kind: SymptomKind) => void = (kind: SymptomKind) => {};

  build() {
    Row({ space: 7 }) {
      ForEach(FEELINGS, (f: Feeling) => {
        FeelButton({ feeling: f, chosen: this.chosen === f.kind,
          dimmed: this.chosen !== undefined && this.chosen !== f.kind, onTap: () => this.onPick(f.kind) })
      }, (f: Feeling) => f.kind)
    }
  }
}

/**
 * 11 Check-in after "I'm OK": a coral ring (Celia asking, not an alarm). Fine closes it; Dizzy or Racing logs it and
 * then offers Need help next to Done.
 */
@ComponentV2
export struct CheckIn {
  @Param @Require ctrl: WatchController;
  @Local logged: SymptomKind | undefined = undefined;

  pick(kind: SymptomKind): void {
    if (kind === 'fine') {
      this.ctrl.checkIn(kind);
      return;
    }
    this.ctrl.logSymptom(kind);
    if (this.ctrl.drugWarning.length > 0) {
      // Within 24 h of a risky medicine: the drug warning (OK / Need help) replaces "Logged".
      this.ctrl.closeCheckIn();
      return;
    }
    this.logged = kind;
  }

  build() {
    Stack() {
      Bezel({ mode: 'RING', color: Theme.BRAND })
      Column({ space: 8 }) {
        Text(this.logged === undefined ? 'How do you feel?' : `Logged: ${feelingLabel(this.logged)}`)
          .fontSize(Theme.TITLE + 2)
          .fontWeight(FontWeight.Bolder)
          .fontColor(Theme.TEXT)
        Feelings({ chosen: this.logged, onPick: (k: SymptomKind) => this.pick(k) })
        if (this.logged === undefined) {
          Text('Racing = palpitations').fontSize(Theme.SMALL).fontColor(Theme.TEXT_2)
          PillButton({ label: 'Not now', pillWidth: 96, onTap: () => {
            this.ctrl.closeCheckIn();
          } })
        } else {
          Text('Sit down. Sent to your phone.').fontSize(Theme.SMALL).fontColor(Theme.TEXT_2)
          Row({ space: 8 }) {
            PillButton({ label: 'Done', pillWidth: 72, onTap: () => {
              this.ctrl.closeCheckIn();
            } })
            PillButton({ label: 'Need help', bg: Theme.ALERT, pillWidth: 94, onTap: () => {
              this.ctrl.closeCheckIn();
              this.ctrl.needHelp();
            } })
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
