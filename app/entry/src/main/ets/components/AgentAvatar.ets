// The agent's orb avatar (DESIGN.md §6.6): coral radial gradient with a soft highlight, breathing while idle.
// Sizes: 24 (tab), 28, 40, 96.

import { Motion } from '../common/Motion';

@ComponentV2
export struct AgentAvatar {
  @Param dim: number = 40;
  @Param breathing: boolean = true;
  @Local out: boolean = false;

  build() {
    Row()
      .width(this.dim)
      .height(this.dim)
      .borderRadius(this.dim / 2)
      .radialGradient({
        center: [this.dim * 0.35, this.dim * 0.3],
        radius: this.dim * 0.8,
        colors: [
          [$r('app.color.orb_light'), 0],
          [$r('app.color.orb_mid'), 0.68],
          [$r('app.color.orb_dark'), 1]
        ]
      })
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
