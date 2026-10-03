// The agent's small avatar (DESIGN.md §6.6): the Dawn orb as a still gradient with a soft sheen, breathing while
// idle. Sizes 28 and 40 (inline). From 56 up the orb is the animated SilkOrb (tab bar, stage).

import { Motion } from '../common/Motion';

@ComponentV2
export struct AgentAvatar {
  @Param dim: number = 40;
  @Param breathing: boolean = true;
  @Local out: boolean = false;

  build() {
    Stack() {
      Row()
        .width(this.dim)
        .height(this.dim)
        .radialGradient({
          center: [this.dim * 0.36, this.dim * 0.3],
          radius: this.dim * 0.82,
          colors: [
            [$r('app.color.orb_light'), 0],
            [$r('app.color.orb_mid'), 0.62],
            [$r('app.color.orb_dark'), 1]
          ]
        })
      Row()
        .width(this.dim)
        .height(this.dim)
        .radialGradient({
          center: [this.dim * 0.3, this.dim * 0.24],
          radius: this.dim * 0.42,
          colors: [
            [$r('app.color.orb_sheen'), 0],
            [$r('app.color.orb_sheen_clear'), 1]
          ]
        })
    }
    .width(this.dim)
    .height(this.dim)
    .borderRadius(this.dim / 2)
    .clip(true)
    .scale({ x: this.out ? 1.04 : 0.92, y: this.out ? 1.04 : 0.92 })
    .opacity(this.out ? 1 : 0.92)
    .animation(this.breathing && !Motion.reduced ? {
      duration: Motion.BREATH_MS,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate
    } : undefined)
    .onAppear(() => {
      this.out = true;
    })
  }
}
