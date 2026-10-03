// "How are you feeling?" 2×2 service card (B15): one tap opens the diary entry page. Static, no data, no AI.

@Entry
@Component
struct FeelingCard {
  build() {
    Column() {
      Text($r('app.string.widget_brand'))
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink_3'))
      Blank()
      Text($r('app.string.doc_widget_name'))
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bolder)
        .fontColor($r('app.color.ink'))
        .maxLines(2)
      Row({ space: 6 }) {
        Image($r('app.media.ic_plus')).width(16).height(16).fillColor($r('app.color.chat_user_text'))
        Text($r('app.string.doc_widget_action'))
          .fontSize($r('app.float.font_badge'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.chat_user_text'))
          .maxLines(1)
      }
      .height(36)
      .padding({ left: 12, right: 12 })
      .margin({ top: 10 })
      .borderRadius($r('app.float.radius_s'))
      .backgroundColor($r('app.color.chat_user_bg'))
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { target: 'feeling' }
      });
    })
  }
}
