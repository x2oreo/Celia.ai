// Medical ID card for the lock screen (B13). The one lock-screen surface a third-party app gets in Europe: a Form
// Kit widget with renderingMode "autoColor" (home screen in colour, lock screen in a single colour). Meaning never
// depends on colour: the label, weight and the fixed "AVOID" line carry it. Data is the app's snapshot
// (widget/MedIdData.ets via WidgetSync); nothing here calls a model or the network. The user places it.

let medIdStorage: LocalStorage = new LocalStorage();

@Entry(medIdStorage)
@Component
struct MedIdCard {
  @LocalStorageProp('condition') condition: string = 'Long QT syndrome';
  @LocalStorageProp('midName') name: string = '';
  @LocalStorageProp('midIcd') icd: string = '';
  @LocalStorageProp('midMeds') meds: string = '';
  @LocalStorageProp('midOther') other: string = '';

  @Builder
  line(text: string, bold: boolean) {
    Text(text)
      .fontSize($r('app.float.font_caption'))
      .fontWeight(bold ? FontWeight.Bold : FontWeight.Medium)
      .fontColor($r('app.color.card_fixed_ink_2'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  build() {
    Column({ space: 2 }) {
      Row({ space: 6 }) {
        Image($r('app.media.ic_heart_fill'))
          .width(14)
          .height(14)
          .fillColor($r('app.color.card_fixed_alert'))
        Text($r('app.string.ntf_medid_label'))
          .fontSize($r('app.float.font_micro'))
          .fontWeight(FontWeight.Bolder)
          .letterSpacing(0.6)
          .fontColor($r('app.color.card_fixed_alert'))
      }
      if (this.name !== '') {
        Text(this.name)
          .fontSize($r('app.float.font_button'))
          .fontWeight(FontWeight.Bolder)
          .fontColor($r('app.color.card_fixed_ink'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Text(this.condition)
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.card_fixed_ink'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text($r('app.string.em_avoid'))
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Bolder)
        .fontColor($r('app.color.card_fixed_alert'))
        .maxLines(2)
      if (this.icd !== '') {
        this.line(this.icd, true)
      }
      if (this.meds !== '') {
        this.line(this.meds, false)
      }
      if (this.other !== '') {
        this.line(this.other, false)
      }
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.card_fixed_bg'))
    .onClick(() => {
      // On the lock screen the system asks to unlock before the app opens.
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { target: 'emergency' }
      });
    })
  }
}
