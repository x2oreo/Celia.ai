import {
  ArcButton,
  ArcButtonOptions,
  ArcButtonPosition,
  ArcButtonStyleMode,
  ColorMetrics,
  LengthMetrics
} from '@kit.ArkUI';
import { Level, levelWord, Zone } from '../vitals/WatchStatus';
import { Theme } from './Theme';

/** Bezel ring: arc from 12 o'clock clockwise, `percent` of the circle, over a dim track. */
@ComponentV2
export struct Ring {
  @Param percent: number = 100;
  @Param color: string = Theme.CALM;
  @Param strokeWidth: number = Theme.RING_STROKE;
  @Param track: boolean = true;

  build() {
    Progress({ value: Math.max(0, Math.min(100, this.percent)), total: 100, type: ProgressType.Ring })
      .width('100%')
      .height('100%')
      .padding(4)
      .color(this.color)
      .backgroundColor(this.track ? Theme.RING_TRACK : Theme.TRANSPARENT)
      .style({ strokeWidth: this.strokeWidth, shadow: false })
      .accessibilityLevel('no')
  }
}

/** Dashed bezel: "no reading" (not on the wrist, waiting). Never looks like a calm ring. */
@ComponentV2
export struct DashedRing {
  @Param color: string = Theme.BORDER;

  build() {
    Circle()
      .width('100%')
      .height('100%')
      .padding(8)
      .fill(Theme.TRANSPARENT)
      .stroke(this.color)
      .strokeWidth(Theme.RING_STROKE / 2)
      .strokeDashArray([12, 10])
      .accessibilityLevel('no')
  }
}

/** A Lucide glyph tinted with a token (icons are outlined fills, see DESIGN.md §6.6b). */
@ComponentV2
export struct Icon {
  @Param @Require src: Resource;
  @Param color: string = Theme.TEXT;
  @Param glyph: number = 18;

  build() {
    Image(this.src)
      .width(this.glyph)
      .height(this.glyph)
      .fillColor(this.color)
      .objectFit(ImageFit.Contain)
      .accessibilityLevel('no')
  }
}

export function levelColor(level: Level): string {
  switch (level) {
    case 'GOOD':
      return Theme.CALM;
    case 'LOOK':
      return Theme.ELEVATED;
    default:
      return Theme.TEXT_2;
  }
}

export function levelTint(level: Level): string {
  switch (level) {
    case 'GOOD':
      return Theme.CALM_TINT;
    case 'LOOK':
      return Theme.ELEVATED_TINT;
    default:
      return Theme.BUTTON;
  }
}

export function zoneColor(zone: Zone): string {
  switch (zone) {
    case 'CALM':
      return Theme.CALM;
    case 'NEAR':
    case 'BELOW':
      return Theme.ELEVATED;
    case 'ABOVE':
      return Theme.ALERT;
    default:
      return Theme.TEXT_3;
  }
}

/** Shape of a zone: circle-check calm, triangle near / below, octagon above, dashed circle waiting. */
export function zoneShape(zone: Zone): Resource {
  switch (zone) {
    case 'CALM':
      return $r('app.media.ic_risk_ok');
    case 'NEAR':
    case 'BELOW':
      return $r('app.media.ic_risk_possible');
    case 'ABOVE':
      return $r('app.media.ic_risk_known');
    default:
      return $r('app.media.ic_risk_unknown');
  }
}

function levelShape(level: Level): Resource {
  switch (level) {
    case 'GOOD':
      return $r('app.media.ic_risk_ok');
    case 'LOOK':
      return $r('app.media.ic_risk_possible');
    case 'OKAY':
      return $r('app.media.ic_gauge');
    default:
      return $r('app.media.ic_risk_unknown');
  }
}

/** Status word + shape on its tint (DESIGN.md §6.10). Never red: red is for alerts. */
@ComponentV2
export struct StatusPill {
  @Param level: Level = 'NONE';

  build() {
    Row({ space: 3 }) {
      Icon({ src: levelShape(this.level), color: levelColor(this.level), glyph: 11 })
      Text(levelWord(this.level))
        .fontSize(Theme.MICRO)
        .fontWeight(FontWeight.Bold)
        .fontColor(levelColor(this.level))
        .maxLines(1)
    }
    .height(20)
    .padding({ left: 6, right: 8 })
    .borderRadius(10)
    .backgroundColor(levelTint(this.level))
  }
}

/** "SIM": the signal is simulated (Huawei measures it, watch apps can't read it yet). */
@ComponentV2
export struct SimBadge {
  @Param label: string = 'SIM';

  build() {
    Text(this.label)
      .fontSize(8)
      .fontWeight(FontWeight.Bolder)
      .letterSpacing(0.8)
      .fontFamily('monospace')
      .fontColor(Theme.ELEVATED)
      .padding({ left: 4, right: 4, top: 1, bottom: 1 })
      .borderRadius(4)
      .border({ width: 1, color: Theme.ELEVATED_TINT })
  }
}

/** Caps label (`CAPS`). */
@ComponentV2
export struct Caps {
  @Param @Require text: string;
  @Param color: string = Theme.TEXT_3;

  build() {
    Text(this.text)
      .fontSize(Theme.CAPS)
      .fontWeight(FontWeight.Bold)
      .letterSpacing(1)
      .fontColor(this.color)
      .maxLines(1)
  }
}

/** Capsule action (two side by side on alerts). */
@ComponentV2
export struct PillButton {
  @Param @Require label: string;
  @Param bg: string = Theme.BUTTON;
  @Param fg: string = Theme.TEXT;
  @Param pillWidth: number = 84;
  @Param pillHeight: number = Theme.PILL_HEIGHT;
  @Param fontSize: number = Theme.BODY;
  @Event onTap: () => void = () => {};

  build() {
    Button(this.label, { type: ButtonType.Capsule, stateEffect: true })
      .width(this.pillWidth)
      .height(this.pillHeight)
      .fontSize(this.fontSize)
      .fontWeight(FontWeight.Bold)
      .backgroundColor(this.bg)
      .fontColor(this.fg)
      .padding({ left: 6, right: 6 })
      .onClick(() => this.onTap())
  }
}

/** The one primary action at the bottom of a round screen (ArcButton, our colours). */
@ComponentV2
export struct EdgeButton {
  @Param @Require label: string;
  @Param bg: string = Theme.BUTTON;
  @Param fg: string = Theme.TEXT;
  @Event onTap: () => void = () => {};
  @Local opts: ArcButtonOptions = new ArcButtonOptions({});

  aboutToAppear(): void {
    this.opts = new ArcButtonOptions({
      label: this.label,
      position: ArcButtonPosition.BOTTOM_EDGE,
      styleMode: ArcButtonStyleMode.CUSTOM,
      backgroundColor: ColorMetrics.resourceColor(this.bg),
      fontColor: ColorMetrics.resourceColor(this.fg),
      pressedFontColor: ColorMetrics.resourceColor(this.fg),
      fontSize: LengthMetrics.fp(16),
      shadowEnabled: false,
      onClick: () => {
        this.onTap();
      }
    });
  }

  @Monitor('label')
  onLabel(): void {
    this.opts.label = this.label;
  }

  build() {
    ArcButton({ options: this.opts })
  }
}

/** Live heart glyph: a double beat (1 → 1.25 → 1 → 1.15 → 1), faster as the zone gets more urgent. */
@ComponentV2
export struct HeartBeat {
  @Param periodMs: number = 1100;
  @Param color: string = Theme.BRAND;
  @Param glyph: number = 16;
  @Param beating: boolean = true;
  @Local scaleV: number = 1;

  aboutToAppear(): void {
    this.start();
  }

  @Monitor('periodMs', 'beating')
  onChange(): void {
    this.start();
  }

  start(): void {
    const ui = this.getUIContext();
    this.scaleV = 1;
    if (!this.beating) {
      return;
    }
    const p = this.periodMs;
    try {
      ui.keyframeAnimateTo({ iterations: -1 }, [
      { duration: Math.round(p * 0.15), curve: Curve.EaseOut, event: () => {
        this.scaleV = 1.25;
      } },
      { duration: Math.round(p * 0.15), curve: Curve.EaseIn, event: () => {
        this.scaleV = 1;
      } },
      { duration: Math.round(p * 0.15), curve: Curve.EaseOut, event: () => {
        this.scaleV = 1.15;
      } },
      { duration: Math.round(p * 0.55), curve: Curve.EaseInOut, event: () => {
        this.scaleV = 1;
      } }
    ]);
    } catch (e) {
      // No animation is fine: the glyph still shows.
    }
  }

  build() {
    Image($r('app.media.ic_heart_fill'))
      .width(this.glyph)
      .height(this.glyph)
      .fillColor(this.beating ? this.color : Theme.TEXT_3)
      .scale({ x: this.scaleV, y: this.scaleV })
      .accessibilityLevel('no')
  }
}
