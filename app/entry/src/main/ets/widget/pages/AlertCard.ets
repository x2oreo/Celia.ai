// Medical alert 2×4 service card (design B6): call circle, condition, key facts, the AVOID line and the ICE
// contact. Always light, so a stranger can read it. Data comes from the app's snapshot (widget/WidgetSync.ets).

let alertStorage: LocalStorage = new LocalStorage();

@Entry(alertStorage)
@Component
struct AlertCard {
  @LocalStorageProp('condition') condition: string = 'Long QT syndrome';
  @LocalStorageProp('facts') facts: string = '';
  @LocalStorageProp('number') number: string = '112';
  @LocalStorageProp('ice') ice: string = '';

  private open(target: string): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { target: target }
    });
  }

  build() {
    Row({ space: 12 }) {
      Column() {
        Text($r('app.string.em_call'))
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.on_accent'))
        Text(this.number)
          .fontSize($r('app.float.font_title'))
          .fontWeight(FontWeight.Bolder)
          .fontColor($r('app.color.on_accent'))
      }
      .width(88)
      .height(88)
      .justifyContent(FlexAlign.Center)
      .borderRadius(44)
      .backgroundColor($r('app.color.danger'))
      .border({ width: 4, color: $r('app.color.risk_known_border') })
      .onClick(() => this.open('call'))

      Column({ space: 2 }) {
        Text($r('app.string.em_alert_label'))
          .fontSize($r('app.float.font_micro'))
          .fontWeight(FontWeight.Bolder)
          .letterSpacing(0.6)
          .fontColor($r('app.color.card_fixed_alert'))
        Text(this.condition)
          .fontSize($r('app.float.font_button'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.card_fixed_ink'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.facts !== '') {
          Text(this.facts)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.card_fixed_ink_2'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text($r('app.string.em_avoid'))
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.card_fixed_alert'))
          .maxLines(1)
        Row({ space: 6 }) {
          Text(this.ice === '' ? $r('app.string.widget_open_card') : `Call ${this.ice} (ICE)`)
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.card_fixed_ink'))
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .height(32)
            .borderRadius($r('app.float.radius_s'))
            .backgroundColor($r('app.color.card_fixed_border'))
            .onClick(() => this.open(this.ice === '' ? 'emergency' : 'ice'))
          // Bystander guide (T24): call, CPR, AED — opens without unlocking personal data.
          Text($r('app.string.widget_help'))
            .fontSize($r('app.float.font_caption'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.on_accent'))
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .layoutWeight(1)
            .height(32)
            .borderRadius($r('app.float.radius_s'))
            .backgroundColor($r('app.color.card_fixed_alert'))
            .onClick(() => this.open('bystander'))
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_fixed_bg'))
    .onClick(() => this.open('emergency'))
  }
}
