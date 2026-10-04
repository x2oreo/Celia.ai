import { Level, levelWord, Zone } from '../vitals/WatchStatus';
import { Theme } from './Theme';

/**
 * Bezel modes (DESIGN.md §7): GAUGE = Home's 290° arc open at the bottom, filled from your min to your max; RING = a
 * full circle (a countdown when `fraction` < 1, draining clockwise from 12 o'clock); SPIN = a short turning arc;
 * DASHED = no reading or something to fix.
 */
export type BezelMode = 'GAUGE' | 'RING' | 'SPIN' | 'DASHED';

/** Gauge geometry: the gap is centred at 6 o'clock so the page dots sit in it. */
const GAUGE_SWEEP_DEG: number = 290;
const GAUGE_START_DEG: number = 90 + (360 - GAUGE_SWEEP_DEG) / 2;
const SPIN_SWEEP_DEG: number = 70;
const SPIN_MS: number = 1100;

function rad(deg: number): number {
  return deg * Math.PI / 180;
}

/** The bezel ring, drawn on one Canvas so it can be an open gauge, a countdown, dashed or spinning. */
@ComponentV2
export struct Bezel {
  @Param mode: BezelMode = 'RING';
  /** 0-1: gauge fill or what is left of a countdown. */
  @Param fraction: number = 1;
  @Param color: string = Theme.CALM;
  /** Gauge below the min: a single dot at the start of the arc instead of a fill. */
  @Param dot: boolean = false;
  @Param strokeWidth: number = Theme.RING_STROKE;
  @Local angle: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  aboutToAppear(): void {
    this.spin();
  }

  @Monitor('mode', 'fraction', 'color', 'dot', 'strokeWidth')
  onChange(): void {
    this.draw();
  }

  @Monitor('mode')
  onMode(): void {
    this.spin();
  }

  spin(): void {
    if (this.mode !== 'SPIN') {
      this.angle = 0;
      return;
    }
    try {
      this.getUIContext().animateTo({ duration: SPIN_MS, curve: Curve.Linear, iterations: -1 }, () => {
        this.angle = 360;
      });
    } catch (e) {
      // A still arc is fine: the words say what is happening.
    }
  }

  draw(): void {
    if (!this.ready) {
      return;
    }
    const c = this.ctx;
    const w = c.width;
    const h = c.height;
    const cx = w / 2;
    const cy = h / 2;
    const r = Math.min(w, h) / 2 - Theme.RING_INSET - this.strokeWidth / 2;
    const f = Math.max(0, Math.min(1, this.fraction));
    c.clearRect(0, 0, w, h);
    c.lineCap = 'round';
    c.lineWidth = this.strokeWidth;

    if (this.mode === 'DASHED') {
      c.setLineDash([this.strokeWidth * 1.4, this.strokeWidth * 1.1]);
      c.lineCap = 'butt';
      c.lineWidth = this.strokeWidth * 0.75;
      c.strokeStyle = this.color;
      c.beginPath();
      c.arc(cx, cy, r, 0, Math.PI * 2);
      c.stroke();
      c.setLineDash([]);
      return;
    }

    const start = this.mode === 'GAUGE' ? GAUGE_START_DEG : -90;
    const sweep = this.mode === 'GAUGE' ? GAUGE_SWEEP_DEG : 360;
    c.strokeStyle = Theme.RING_TRACK;
    c.beginPath();
    c.arc(cx, cy, r, rad(start), rad(start + sweep));
    c.stroke();

    c.strokeStyle = this.color;
    if (this.mode === 'SPIN') {
      c.beginPath();
      c.arc(cx, cy, r, rad(-90), rad(-90 + SPIN_SWEEP_DEG));
      c.stroke();
      return;
    }
    if (this.mode === 'GAUGE' && this.dot) {
      c.fillStyle = this.color;
      c.beginPath();
      c.arc(cx + r * Math.cos(rad(start)), cy + r * Math.sin(rad(start)), this.strokeWidth / 2, 0, Math.PI * 2);
      c.fill();
      return;
    }
    if (f <= 0) {
      return;
    }
    c.beginPath();
    c.arc(cx, cy, r, rad(start), rad(start + sweep * f));
    c.stroke();
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .rotate({ angle: this.angle })
      .onReady(() => {
        this.ready = true;
        this.draw();
      })
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

/** Status shapes (DESIGN.md §7): dot = good, up / down triangle, hollow ring = waiting / no data. */
export type Mark = 'DOT' | 'UP' | 'DOWN' | 'RING';

@ComponentV2
export struct StatusMark {
  @Param mark: Mark = 'DOT';
  @Param color: string = Theme.CALM;
  @Param dim: number = 12;

  build() {
    if (this.mark === 'UP' || this.mark === 'DOWN') {
      Icon({ src: this.mark === 'UP' ? $r('app.media.ic_tri_up') : $r('app.media.ic_tri_down'), color: this.color,
        glyph: this.dim })
    } else {
      Circle()
        .width(this.dim)
        .height(this.dim)
        .fill(this.mark === 'DOT' ? this.color : Theme.TRANSPARENT)
        .stroke(this.mark === 'DOT' ? Theme.TRANSPARENT : this.color)
        .strokeWidth(this.mark === 'DOT' ? 0 : 1.5)
        .accessibilityLevel('no')
    }
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
      return Theme.TEXT_2;
  }
}

export function zoneMark(zone: Zone): Mark {
  switch (zone) {
    case 'CALM':
      return 'DOT';
    case 'NEAR':
    case 'ABOVE':
      return 'UP';
    case 'BELOW':
      return 'DOWN';
    default:
      return 'RING';
  }
}

export function levelColor(level: Level): string {
  switch (level) {
    case 'GOOD':
      return Theme.CALM;
    case 'LOOK':
      return Theme.ELEVATED;
    case 'OKAY':
      return Theme.TEXT;
    default:
      return Theme.TEXT_2;
  }
}

function levelMark(level: Level): Mark {
  switch (level) {
    case 'GOOD':
    case 'OKAY':
      return 'DOT';
    case 'LOOK':
      return 'UP';
    default:
      return 'RING';
  }
}

/** Vitals status: shape + word, no fill (DESIGN.md §6.10). Never red: red is for alerts. */
@ComponentV2
export struct StatusWord {
  @Param level: Level = 'NONE';

  build() {
    Row({ space: 4 }) {
      StatusMark({ mark: levelMark(this.level), color: levelColor(this.level), dim: 9 })
      Text(levelWord(this.level))
        .fontSize(Theme.SMALL)
        .fontWeight(FontWeight.Bold)
        .fontColor(levelColor(this.level))
        .maxLines(1)
    }
  }
}

/** Outlined mono badge: "SIM" on a simulated signal, "DEMO DATA" for scripted heart rate. Dashed = simulator title. */
@ComponentV2
export struct OutlineBadge {
  @Param label: string = 'SIM';
  @Param dashed: boolean = false;
  @Param color: string = Theme.TEXT_2;

  build() {
    Text(this.label)
      .fontSize(Theme.MICRO)
      .fontWeight(FontWeight.Bolder)
      .letterSpacing(0.8)
      .fontFamily('monospace')
      .fontColor(this.color)
      .padding({ left: 4, right: 4, top: 1, bottom: 1 })
      .borderRadius(4)
      .border({ width: 1, color: Theme.TEXT_3, style: this.dashed ? BorderStyle.Dashed : BorderStyle.Solid })
  }
}

/** Capsule chip on `SURFACE` (Home: genotype, phone). An optional check after the text. */
@ComponentV2
export struct Chip {
  @Param @Require label: string;
  @Param color: string = Theme.TEXT;
  @Param check: boolean = false;

  build() {
    Row({ space: 3 }) {
      Text(this.label).fontSize(Theme.SMALL - 1).fontWeight(FontWeight.Bold).fontColor(this.color).maxLines(1)
      if (this.check) {
        Icon({ src: $r('app.media.ic_check'), color: this.color, glyph: 11 })
      }
    }
    .height(Theme.CHIP_HEIGHT)
    .padding({ left: 8, right: 8 })
    .borderRadius(Theme.CHIP_HEIGHT / 2)
    .backgroundColor(Theme.SURFACE)
  }
}

/** Caps label (`CAPS`). */
@ComponentV2
export struct Caps {
  @Param @Require text: string;
  @Param color: string = Theme.TEXT_2;

  build() {
    Text(this.text)
      .fontSize(Theme.CAPS)
      .fontWeight(FontWeight.Bold)
      .letterSpacing(1)
      .fontColor(this.color)
      .maxLines(1)
  }
}

/** Centred capsule action: alone or two side by side (DESIGN.md §7). */
@ComponentV2
export struct PillButton {
  @Param @Require label: string;
  @Param bg: string = Theme.BUTTON;
  @Param fg: string = Theme.TEXT;
  @Param ring: string = Theme.TRANSPARENT;
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
      .border({ width: this.ring === Theme.TRANSPARENT ? 0 : 1.5, color: this.ring })
      .padding({ left: 6, right: 6 })
      .onClick(() => this.onTap())
  }
}

/** I'm OK / Need help: the two actions on every alert. */
@ComponentV2
export struct OkHelp {
  @Event onOk: () => void = () => {};
  @Event onHelp: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      PillButton({ label: "I'm OK", pillWidth: 78, onTap: () => this.onOk() })
      PillButton({ label: 'Need help', bg: Theme.ALERT, pillWidth: 94, onTap: () => this.onHelp() })
    }
  }
}

/** Filled disc with a glyph: green check (sent, paired). */
@ComponentV2
export struct CheckDisc {
  @Param color: string = Theme.CALM;

  build() {
    Stack() {
      Icon({ src: $r('app.media.ic_check'), color: Theme.BG, glyph: 18 })
    }
    .width(30)
    .height(30)
    .borderRadius(15)
    .backgroundColor(this.color)
  }
}

/** Two grey bars in place of a number when there is no reading. */
@ComponentV2
export struct NoNumber {
  build() {
    Row({ space: 6 }) {
      Rect().width(22).height(9).radius(1).fill(Theme.TEXT_3).fillOpacity(0.6)
      Rect().width(22).height(9).radius(1).fill(Theme.TEXT_3).fillOpacity(0.6)
    }
    .height(36)
    .alignItems(VerticalAlign.Center)
    .accessibilityLevel('no')
  }
}
