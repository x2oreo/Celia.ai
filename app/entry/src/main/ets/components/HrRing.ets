// Heart-rate ring hero (Home and Heart): bezel ring, pulsing heart, display bpm, state line and source badge.
// Heart rate only. The ring colour follows the alert zone and is always paired with a word.

import { Motion } from '../common/Motion';
import { SourceBadge } from './Common';

export type HrZone = 'CALM' | 'ELEVATED' | 'ALERT';

@ComponentV2
export struct HrRing {
  @Param bpm: number = 0;                 // 0 = no reading yet
  @Param caption: ResourceStr = '';       // "bpm · resting"
  @Param zone: HrZone = 'CALM';
  @Param live: boolean = false;
  @Param simulated: boolean = true;
  @Param dim: number = 232;
  @Local beat: number = 1;
  private beating: boolean = false;

  private ringColor(): ResourceColor {
    if (this.zone === 'ALERT') {
      return $r('app.color.risk_known');
    }
    return this.zone === 'ELEVATED' ? $r('app.color.risk_possible') : $r('app.color.brand_accent');
  }

  // Map 40–180 bpm onto the ring so a resting rate fills roughly a third.
  private arc(): number {
    if (this.bpm <= 0) {
      return 0;
    }
    return Math.max(4, Math.min(100, (this.bpm - 40) / 140 * 100));
  }

  private startBeat(): void {
    if (this.beating || Motion.reduced || !this.live) {
      return;
    }
    this.beating = true;
    const d: number = Motion.BEAT_MS;
    this.getUIContext().keyframeAnimateTo({ iterations: -1 }, [
      { duration: d * 0.15, event: () => { this.beat = 1.25; } },
      { duration: d * 0.15, event: () => { this.beat = 1; } },
      { duration: d * 0.15, event: () => { this.beat = 1.15; } },
      { duration: d * 0.55, event: () => { this.beat = 1; } }
    ]);
  }

  build() {
    Stack() {
      Progress({ value: this.arc(), total: 100, type: ProgressType.Ring })
        .width(this.dim)
        .height(this.dim)
        .color(this.ringColor())
        .backgroundColor($r('app.color.border'))
        .style({ strokeWidth: 12 })
      Column({ space: 2 }) {
        Image($r('app.media.ic_heart_fill'))
          .width(20)
          .height(20)
          .fillColor($r('app.color.brand_accent'))
          .scale({ x: this.beat, y: this.beat })
        Text(this.bpm > 0 ? `${this.bpm}` : '--')
          .fontSize($r('app.float.font_display'))
          .fontWeight(800)
          .fontColor($r('app.color.ink'))
          .fontFeature('"tnum" on')
          .lineHeight(64)
        Text(this.caption)
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink_3'))
        SourceBadge({
          label: this.simulated ? $r('app.string.badge_simulated') : $r('app.string.badge_watch'),
          solid: !this.simulated
        })
          .margin({ top: 8 })
      }
    }
    .width(this.dim)
    .height(this.dim)
    .onAppear(() => this.startBeat())
  }
}
