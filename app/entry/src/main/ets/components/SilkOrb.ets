// The agent's orb (DESIGN.md §6.6): a soft sphere with no hard outline, silky bands that wrap and turn around it,
// and colour that drifts inside. Palette "Dawn": coral shifting to peach with a touch of rose-violet.
// Drawn on one ArkUI Canvas with plain 2D calls (radial gradients, stroked paths, compositing). No shader, no blur.
//
// The orb itself carries the state, always next to a text label drawn by the caller:
//   off        bands faint, turning slowly
//   connecting bands brighten and pick up speed
//   listening  calm, a soft neutral halo behind it
//   hearing    the neutral halo follows the user's voice, the orb draws in slightly
//   thinking   all bands line up and spin together on one axis, slightly dimmer
//   speaking   the orb swells with the agent's voice, bands bright and fast, warm halo
//   muted      faded and still
// Neutral halo = the user's voice, warm halo = the agent. A slow single breath, never a double beat that could
// read as a pulse; nothing here looks like an ECG trace. Reduced motion: one settled frame per state.

import { Motion } from '../common/Motion';
import { VoicePhase } from '../voice/RealtimeSession';

// Dawn palette (DESIGN.md §6.6). The canvas takes RGB numbers, so the stops live here; the same body stops are the
// `orb_light` / `orb_mid` / `orb_dark` resources used by the static avatar.
const INNER: number[] = [255, 206, 176];
const MID: number[] = [242, 116, 112];
const EDGE: number[] = [212, 96, 156];
const BLOB_A: number[] = [255, 220, 170];
const BLOB_B: number[] = [196, 96, 178];
const BLOB_C: number[] = [255, 140, 118];
const LINE: number[] = [255, 246, 240];

const TWO_PI: number = 6.2832;
const SEGMENTS: number = 44;
const GROUPS: number = 3;
const CANVAS_SCALE: number = 1.9;   // the canvas is wider than the orb so the halo has room
const FRAME_MS: number = 33;
const FRAME_SMALL_MS: number = 50;

// What a state asks of the orb; the drawn values ease towards these.
class OrbLook {
  ink: number = 0;      // 0 warm halo (the agent), 1 neutral halo (the user)
  dim: number = 1;      // overall opacity
  swirl: number = 0;    // 1 = bands aligned and spinning together
  out: number = 0;      // swell with the voice level
  inw: number = 0;      // draw in while hearing the user
  halo: number = 0;
  lines: number = 0.45;

  constructor(ink: number, dim: number, swirl: number, out: number, inw: number, halo: number, lines: number) {
    this.ink = ink;
    this.dim = dim;
    this.swirl = swirl;
    this.out = out;
    this.inw = inw;
    this.halo = halo;
    this.lines = lines;
  }
}

const LOOK_OFF: OrbLook = new OrbLook(0, 1, 0, 0, 0, 0, 0.45);
const LOOK_CONNECTING: OrbLook = new OrbLook(0, 1, 0.5, 0, 0, 0.3, 0.8);
const LOOK_LISTENING: OrbLook = new OrbLook(1, 1, 0, 0, 0, 0.7, 0.55);
const LOOK_HEARING: OrbLook = new OrbLook(1, 1, 0, 0, 1, 1, 0.9);
const LOOK_THINKING: OrbLook = new OrbLook(0, 0.88, 1, 0, 0, 0.3, 0.9);
const LOOK_SPEAKING: OrbLook = new OrbLook(0, 1, 0, 1, 0, 1, 1);
const LOOK_MUTED: OrbLook = new OrbLook(0, 0.45, 0, 0, 0, 0, 0.15);

function rgba(c: number[], a: number): string {
  const alpha: number = Math.max(0, Math.min(1, a));
  return `rgba(${Math.round(c[0])},${Math.round(c[1])},${Math.round(c[2])},${alpha.toFixed(3)})`;
}

function mix(a: number[], b: number[], t: number): number[] {
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
}

@ComponentV2
export struct SilkOrb {
  @Param dim: number = 168;            // orb diameter; the layout box is dim × dim, the halo paints beyond it
  @Param phase: VoicePhase = 'OFF';
  @Param level: number = 0;            // 0..1 loudness of whoever is talking
  @Param muted: boolean = false;
  @Param small: boolean = false;       // tab-bar size: four bands per group, slower frames
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private g: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private look: OrbLook = new OrbLook(0, 1, 0, 0, 0, 0, 0.45);
  private lvl: number = 0;
  private drift: number = 0;
  private spin: number = 0;
  private clock: number = 0;
  private last: number = 0;
  private timer: number = -1;
  private ready: boolean = false;
  private visible: boolean = true;
  private haloInk: number[] = [138, 129, 123];
  private offMotion: () => void = () => {
  };

  aboutToAppear(): void {
    this.readInk();
    this.offMotion = Motion.onChange((on: boolean) => {
      this.restart();
    });
  }

  aboutToDisappear(): void {
    this.offMotion();
    this.stop();
  }

  // The neutral halo uses the `ink_4` token, so it follows light and dark mode.
  private readInk(): void {
    try {
      const argb: number | undefined =
        this.getUIContext().getHostContext()?.resourceManager.getColorSync($r('app.color.ink_4').id);
      if (argb !== undefined) {
        this.haloInk = [(argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF];
      }
    } catch (e) {
      // keeps the light-mode default
    }
  }

  private side(): number {
    return this.dim * CANVAS_SCALE;
  }

  private target(): OrbLook {
    if (this.muted) {
      return LOOK_MUTED;
    }
    switch (this.phase) {
      case 'CONNECTING':
        return LOOK_CONNECTING;
      case 'LISTENING':
        return LOOK_LISTENING;
      case 'HEARING':
        return LOOK_HEARING;
      case 'THINKING':
        return LOOK_THINKING;
      case 'SPEAKING':
        return LOOK_SPEAKING;
      default:
        return LOOK_OFF;
    }
  }

  // Without a loudness signal (on-device recognition owns the mic) the orb still opens up while someone talks.
  private levelTarget(): number {
    if (this.muted) {
      return 0;
    }
    if (this.phase === 'HEARING' || this.phase === 'SPEAKING') {
      return Math.max(0.25, Math.min(1, this.level));
    }
    return this.phase === 'LISTENING' ? Math.min(1, this.level) * 0.5 : 0;
  }

  private step(dt: number): void {
    const t: OrbLook = this.target();
    const k: number = Math.min(1, dt * 6);
    this.look.ink += (t.ink - this.look.ink) * k;
    this.look.dim += (t.dim - this.look.dim) * k;
    this.look.swirl += (t.swirl - this.look.swirl) * k;
    this.look.out += (t.out - this.look.out) * k;
    this.look.inw += (t.inw - this.look.inw) * k;
    this.look.halo += (t.halo - this.look.halo) * k;
    this.look.lines += (t.lines - this.look.lines) * k;
    this.lvl += (this.levelTarget() - this.lvl) * Math.min(1, dt * 9);
    this.drift += dt * (0.55 + 1.5 * this.lvl + 0.5 * this.look.lines);
    this.spin += dt * 2.4;
    this.clock += dt;
  }

  private soft(x: number, y: number, r: number, c: number[], a: number): void {
    if (a <= 0.002 || r <= 0) {
      return;
    }
    const grad: CanvasGradient = this.g.createRadialGradient(x, y, 0, x, y, r);
    grad.addColorStop(0, rgba(c, a));
    grad.addColorStop(1, rgba(c, 0));
    this.g.beginPath();
    this.g.arc(x, y, r, 0, TWO_PI);
    this.g.fillStyle = grad;
    this.g.fill();
  }

  // One group of silk bands: latitude circles of a unit sphere around a slowly tumbling axis, front half only.
  private bands(c: number, r: number, k: number, count: number): void {
    const p: OrbLook = this.look;
    const yaw: number = this.drift * (0.35 + 0.12 * k) * (1 - p.swirl) + this.spin * p.swirl +
      k * 2.1 * (1 - p.swirl * 0.85);
    const pitch: number = Math.sin(this.drift * 0.23 + k * 1.7) * 0.9 * (1 - p.swirl) + 0.35 * p.swirl;
    const nx: number = Math.cos(pitch) * Math.cos(yaw);
    const ny: number = Math.cos(pitch) * Math.sin(yaw);
    const nz: number = Math.sin(pitch);
    let ux: number = -ny;
    let uy: number = nx;
    const ul: number = Math.sqrt(ux * ux + uy * uy) || 1;
    ux /= ul;
    uy /= ul;
    const vx: number = -nz * uy;
    const vy: number = nz * ux;
    const vz: number = nx * uy - ny * ux;
    const amp: number = 0.012 + 0.05 * this.lvl;
    for (let i = 0; i < count; i++) {
      const phi: number = 0.5 + 0.78 * (i / (count - 1)) + 0.06 * Math.sin(this.drift * 0.6 + k);
      const cp: number = Math.cos(phi);
      const sp: number = Math.sin(phi);
      let open: boolean = false;
      this.g.beginPath();
      for (let s = 0; s <= SEGMENTS; s++) {
        const th: number = s / SEGMENTS * TWO_PI;
        const rr: number = 1 + amp * Math.sin(th * 3 + this.drift * 2.2 + i * 0.7 + k);
        const ct: number = Math.cos(th);
        const st: number = Math.sin(th);
        const x: number = rr * (cp * (ux * ct + vx * st) + sp * nx);
        const y: number = rr * (cp * (uy * ct + vy * st) + sp * ny);
        const z: number = cp * (vz * st) + sp * nz;
        if (z > -0.02) {
          if (open) {
            this.g.lineTo(c + x * r, c + y * r);
          } else {
            this.g.moveTo(c + x * r, c + y * r);
            open = true;
          }
        } else {
          open = false;
        }
      }
      this.g.strokeStyle = rgba(LINE, (0.16 + 0.5 * (i / count)) * p.lines * (0.55 + 0.6 * this.lvl + 0.2 * p.swirl));
      this.g.lineWidth = 0.8 + 1.1 * (i / count);
      this.g.stroke();
    }
  }

  private paint(): void {
    if (!this.ready) {
      return;
    }
    const p: OrbLook = this.look;
    const side: number = this.side();
    const c: number = side / 2;
    // One slow breath (4 s), then the voice: swell with the agent, draw in for the user.
    const breath: number = Motion.reduced ? 1 : 1 + 0.025 * Math.sin(this.clock * 1.57);
    const r: number = this.dim / 2 * breath * (1 + 0.08 * this.lvl * p.out - 0.03 * p.inw);
    const d: number = this.drift;
    const g: CanvasRenderingContext2D = this.g;

    g.globalCompositeOperation = 'source-over';
    g.clearRect(0, 0, side, side);

    // Body, then three drifting colour blobs inside it.
    const base: CanvasGradient = g.createRadialGradient(c - r * 0.2, c - r * 0.25, 0, c, c, r * 1.1);
    base.addColorStop(0, rgba(INNER, 1));
    base.addColorStop(0.6, rgba(MID, 1));
    base.addColorStop(1, rgba(EDGE, 1));
    g.fillStyle = base;
    g.fillRect(c - r * 1.12, c - r * 1.12, r * 2.24, r * 2.24);
    this.soft(c + Math.cos(d * 0.9) * r * 0.42, c + Math.sin(d * 0.7) * r * 0.42, r * 0.9, BLOB_A, 0.8);
    this.soft(c + Math.cos(d * 0.6 + 2.1) * r * 0.5, c + Math.sin(d * 0.4 + 2.1) * r * 0.5, r * 0.85, BLOB_B, 0.5);
    this.soft(c + Math.cos(d * 1.1 + 4.2) * r * 0.4, c + Math.sin(d * 1.0 + 4.2) * r * 0.4, r * 0.75, BLOB_C, 0.7);

    g.lineCap = 'round';
    const count: number = this.small ? 4 : 8;
    for (let k = 0; k < GROUPS; k++) {
      this.bands(c, r, k, count);
    }

    // Soft edge: keep what is inside a radial alpha mask. The mask also carries the state's opacity.
    g.globalCompositeOperation = 'destination-in';
    const mask: CanvasGradient = g.createRadialGradient(c, c, r * 0.74, c, c, r * 1.06);
    mask.addColorStop(0, `rgba(0,0,0,${p.dim.toFixed(3)})`);
    mask.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = mask;
    g.fillRect(0, 0, side, side);

    // Behind the orb: its own warm glow, then the halo (neutral for the user's voice, warm for the agent's).
    g.globalCompositeOperation = 'destination-over';
    this.soft(c, c + r * 0.14, Math.min(c, r * 1.4), MID, 0.16 * p.dim);
    this.soft(c, c, Math.min(c, r * (1.45 + 0.45 * this.lvl)), mix(MID, this.haloInk, p.ink),
      0.26 * p.halo * (0.5 + this.lvl));
    g.globalCompositeOperation = 'source-over';
  }

  private frame(): void {
    const now: number = Date.now();
    const dt: number = Math.min(0.05, this.last > 0 ? (now - this.last) / 1000 : 0.016);
    this.last = now;
    this.step(dt);
    this.paint();
  }

  // One settled frame: where the state ends up, without the motion in between.
  private settle(): void {
    for (let i = 0; i < 60; i++) {
      this.step(0.05);
    }
    this.paint();
  }

  private stop(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private restart(): void {
    this.stop();
    if (!this.ready) {
      return;
    }
    if (Motion.reduced) {
      this.settle();
      return;
    }
    if (!this.visible) {
      return;
    }
    this.last = 0;
    this.frame();
    this.timer = setInterval((): void => this.frame(), this.small ? FRAME_SMALL_MS : FRAME_MS);
  }

  // With loops off nothing repaints by itself: redraw when the state or the size changes.
  @Monitor('phase', 'muted', 'dim')
  onStateChange(m: IMonitor): void {
    if (this.timer === -1 && this.ready) {
      if (Motion.reduced) {
        this.settle();
      } else {
        this.paint();
      }
    }
  }

  build() {
    Stack() {
      Canvas(this.g)
        .width(this.side())
        .height(this.side())
        .hitTestBehavior(HitTestMode.None)
        .onReady(() => {
          this.ready = true;
          this.restart();
        })
    }
    .width(this.dim)
    .height(this.dim)
    .onVisibleAreaChange([0, 0.1], (visible: boolean, ratio: number) => {
      this.visible = visible;
      this.restart();
    })
  }
}
