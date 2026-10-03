// Reusable empty/placeholder state: icon, title, subtitle. Used until each screen gets real content.

@ComponentV2
export struct PlaceholderView {
  @Param icon: Resource = $r('app.media.ic_tab_heart');
  @Param title: ResourceStr = '';
  @Param subtitle: ResourceStr = '';

  build() {
    Column({ space: 12 }) {
      Image(this.icon)
        .width(56)
        .height(56)
        .fillColor($r('app.color.brand_accent'))
      Text(this.title)
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Center)
      Text(this.subtitle)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding($r('app.float.space_l'))
  }
}
