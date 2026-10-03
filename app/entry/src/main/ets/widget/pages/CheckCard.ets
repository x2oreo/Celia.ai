// "Can I take this?" 2×2 service card (design B6): ink card, the agent's orb in the corner, one coral action.

@Entry
@Component
struct CheckCard {
  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Row()
        .width(96)
        .height(96)
        .borderRadius(48)
        .radialGradient({
          center: [34, 30],
          radius: 78,
          colors: [[$r('app.color.orb_light'), 0], [$r('app.color.orb_mid'), 0.68], [$r('app.color.orb_dark'), 1]]
        })
        .offset({ x: 28, y: -28 })

      Column() {
        Text($r('app.string.widget_brand'))
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.on_accent'))
        Blank()
        Text($r('app.string.check_prompt'))
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bolder)
          .fontColor($r('app.color.on_accent'))
          .maxLines(2)
        Row({ space: 6 }) {
          Image($r('app.media.ic_box')).width(16).height(16).fillColor($r('app.color.on_accent'))
          Text($r('app.string.widget_scan_or_type'))
            .fontSize($r('app.float.font_badge'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.on_accent'))
            .maxLines(1)
        }
        .height(36)
        .padding({ left: 12, right: 12 })
        .margin({ top: 10 })
        .borderRadius($r('app.float.radius_s'))
        .backgroundColor($r('app.color.brand_accent'))
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.widget_ink'))
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { target: 'scan' }
      });
    })
  }
}
