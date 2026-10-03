// The hero orb of the voice conversation (DESIGN.md §6.6a). Layers, back to front: two halos that swell with the
// voice, the coral core with a slowly drifting sheen, and an orbiting arc while the agent connects or thinks.
// Halos are coral when the agent speaks and neutral ink when it hears the user, so the state never relies on
// motion alone. Plain ArkUI shapes and gradients only. Loops respect Motion.reduced.

import { Motion } from '../common/Motion';
import { VoicePhase } from '../voice/RealtimeSession';

const SHEEN_TURN_MS: number = 14000;
const ARC_TURN_MS: number = 1600;
const LEVEL_MS: number = 160;
const SIZE_MS: number = 320;

// Thin arc circling the orb. A component of its own so the spin restarts each time it appears.
@ComponentV2
struct OrbitArc {
  @Param dim: number = 160;
  @Param reduced: boolean = false;
  @Local turned: boolean = false;

  build() {
    Circle()
      .width(this.dim)
      .height(this.dim)
      .fillOpacity(0)
      .stroke($r('app.color.brand_accent'))
      .strokeWidth(3)
      .strokeLineCap(LineCapStyle.Round)
      .strokeDashArray([this.dim * 0.55, this.dim * Math.PI])
      // Size eases once; only the rotation below loops.
      .animation({ duration: SIZE_MS, curve: Curve.EaseInOut })
      .rotate({ angle: this.turned ? 360 : 0 })
      .animation(this.reduced ? undefined : {
        duration: ARC_TURN_MS,
        curve: Curve.Linear,
        iterations: -1
      })
      .onAppear(() => {
        this.turned = true;
      })
      .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
  }
}

@ComponentV2
export struct VoiceOrb {
  @Param dim: number = 168;
  @Param phase: VoicePhase = 'OFF';
  @Param level: number = 0;       // 0..1 loudness of whoever is talking
  @Param muted: boolean = false;
  @Local out: boolean = false;
  @Local turned: boolean = false;
  @Local reduced: boolean = Motion.reduced;   // system reduce-motion: loops stay static
  private offMotion: () => void = () => {
  };

  aboutToAppear(): void {
    this.offMotion = Motion.onChange((on: boolean) => {
      this.reduced = on;
    });
  }

  aboutToDisappear(): void {
    this.offMotion();
  }

  private voiced(): boolean {
    return this.phase === 'HEARING' || this.phase === 'SPEAKING';
  }

  // Without a loudness signal (on-device recognition owns the mic) the halos still open up while someone talks.
  private lift(): number {
    if (this.muted) {
      return 0;
    }
    if (this.voiced()) {
      return Math.max(0.25, this.level);
    }
    return this.phase === 'LISTENING' ? this.level * 0.5 : 0;
  }

  private haloColor(): Resource {
    return this.phase === 'HEARING' || this.phase === 'LISTENING' ? $r('app.color.ink_4') :
      $r('app.color.brand_accent');
  }

  private live(): boolean {
    return this.phase !== 'OFF' && !this.muted;
  }

  @Builder
  halo(base: number, gain: number, alpha: number) {
    Circle()
      .width(this.dim)
      .height(this.dim)
      .animation({ duration: SIZE_MS, curve: Curve.EaseInOut })
      .fill(this.haloColor())
      .opacity(this.live() ? alpha : alpha * 0.5)
      .scale({ x: base + this.lift() * gain, y: base + this.lift() * gain })
      .animation({ duration: LEVEL_MS, curve: Curve.EaseOut })
  }

  // .animation() covers the attributes written before it, so size changes ease once while the loops keep
  // running on scale and rotate only.
  build() {
    Stack() {
      this.halo(1.2, 0.42, 0.08)
      this.halo(1.08, 0.2, 0.14)

      // Core: gradient body, drifting sheen, soft glow underneath.
      Stack() {
        Stack() {
          Row()
            .width('100%')
            .height('100%')
            .radialGradient({
              center: ['36%', '30%'],
              radius: '82%',
              colors: [
                [$r('app.color.orb_light'), 0],
                [$r('app.color.orb_mid'), 0.62],
                [$r('app.color.orb_dark'), 1]
              ]
            })
          Row()
            .width('100%')
            .height('100%')
            .radialGradient({
              center: ['30%', '24%'],
              radius: '42%',
              colors: [
                [$r('app.color.orb_sheen'), 0],
                [$r('app.color.orb_sheen_clear'), 1]
              ]
            })
            .rotate({ angle: this.turned ? 360 : 0 })
            .animation(this.reduced ? undefined : {
              duration: SHEEN_TURN_MS,
              curve: Curve.Linear,
              iterations: -1
            })
        }
        .width('100%')
        .height('100%')
        .borderRadius(this.dim / 2)
        .clip(true)
        // The corner radius follows the size once. Left under the breathing loop below, it would keep swinging
        // between the old and the new radius after the orb grows, and the core would pulse into a rounded square.
        .animation({ duration: SIZE_MS, curve: Curve.EaseInOut })
        .scale({ x: this.out ? 1.03 : 0.95, y: this.out ? 1.03 : 0.95 })
        .animation(this.reduced ? undefined : {
          duration: Motion.BREATH_MS,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        })
      }
      .width(this.dim)
      .height(this.dim)
      .borderRadius(this.dim / 2)
      .shadow({ radius: this.dim * 0.28, color: $r('app.color.orb_glow'), offsetX: 0, offsetY: this.dim * 0.08 })
      .animation({ duration: SIZE_MS, curve: Curve.EaseInOut })
      .opacity(this.muted ? 0.5 : 1)
      // The agent's own voice makes the core swell slightly; hearing the user only moves the halos.
      .scale({
        x: 1 + (this.phase === 'SPEAKING' ? this.level * 0.07 : 0),
        y: 1 + (this.phase === 'SPEAKING' ? this.level * 0.07 : 0)
      })
      .animation({ duration: LEVEL_MS, curve: Curve.EaseOut })

      if (this.phase === 'CONNECTING' || this.phase === 'THINKING') {
        OrbitArc({ dim: this.dim * 1.16, reduced: this.reduced })
      }
    }
    .width(this.dim)
    .height(this.dim)
    .onAppear(() => {
      this.out = true;
      this.turned = true;
    })
  }
}
