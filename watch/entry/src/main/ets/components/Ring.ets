import { Theme } from './Theme';

/** Edge ring of the round screen: arc from 12 o'clock clockwise, `percent` of the full circle. */
@ComponentV2
export struct Ring {
  @Param percent: number = 100;
  @Param color: string = Theme.OK;
  @Param strokeWidth: number = 8;

  build() {
    Progress({ value: Math.max(0, Math.min(100, this.percent)), total: 100, type: ProgressType.Ring })
      .width('100%')
      .height('100%')
      .padding(5)
      .color(this.color)
      .backgroundColor(Theme.TRACK)
      .style({ strokeWidth: this.strokeWidth, shadow: false })
  }
}
