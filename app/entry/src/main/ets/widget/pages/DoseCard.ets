// "Next dose" service card, 2×2 (DESIGN.md §11 widgets v2): the dose to take now or the next one, today's doses as
// dots, and a one-tap Taken. Dose styling is neutral (§6.9): a missed dose is a word, never risk red. The state is
// moved on by the clock in the form extension (widget/WidgetDose.ets).

let doseStorage: LocalStorage = new LocalStorage();

@Entry(doseStorage)
@Component
struct DoseCard {
  @LocalStorageProp('doseState') state: string = 'NONE';
  @LocalStorageProp('doseName') name: string = '';
  @LocalStorageProp('doseWhen') when: string = '';
  @LocalStorageProp('doseTaken') taken: number = 0;
  @LocalStorageProp('doseTotal') total: number = 0;
  @LocalStorageProp('doseDots') dots: string = '';

  private open(target: string): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { target: target }
    });
  }

  private canTake(): boolean {
    return this.state === 'DUE' || this.state === 'MISSED';
  }

  private hasDose(): boolean {
    return this.canTake() || this.state === 'UPCOMING';
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.widget_dose_label'))
          .fontSize($r('app.float.font_micro'))
          .fontWeight(FontWeight.Bolder)
          .letterSpacing(0.6)
          .fontColor($r('app.color.ink_3'))
        Blank()
        Row({ space: 4 }) {
          ForEach(this.dots.split(''), (d: string, i: number) => {
            Row()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(d === '1' ? $r('app.color.ink') : Color.Transparent)
              .border({ width: d === '1' ? 0 : 1.5, color: $r('app.color.border_strong') })
          }, (d: string, i: number) => `${i}-${d}`)
        }
        .accessibilityText($r('app.string.widget_a11y_dose_count', this.taken, this.total))
      }
      .width('100%')

      if (this.hasDose()) {
        Row({ space: 10 }) {
          Row() {
            Image($r('app.media.ic_pill')).width(18).height(18).fillColor($r('app.color.ink_2'))
          }
          .width(32)
          .height(32)
          .justifyContent(FlexAlign.Center)
          .borderRadius($r('app.float.radius_s'))
          .backgroundColor($r('app.color.surface_alt'))
          Column({ space: 2 }) {
            Text(this.name)
              .fontSize($r('app.float.font_headline'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ink'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.when)
              .fontSize($r('app.float.font_caption'))
              .fontWeight(this.state === 'MISSED' ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.state === 'MISSED' ? $r('app.color.risk_possible_text') : $r('app.color.ink_3'))
              .maxLines(1)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 12 })
      } else {
        Text(this.state === 'DONE' ? $r('app.string.widget_dose_done') : $r('app.string.widget_dose_none'))
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .maxLines(2)
          .margin({ top: 12 })
      }

      Blank()

      if (this.canTake()) {
        Row({ space: 6 }) {
          Image($r('app.media.ic_check')).width(16).height(16).fillColor($r('app.color.chat_user_text'))
          Text($r('app.string.widget_dose_taken'))
            .fontSize($r('app.float.font_badge'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.chat_user_text'))
        }
        .width('100%')
        .height(36)
        .justifyContent(FlexAlign.Center)
        .borderRadius(18)
        .backgroundColor($r('app.color.chat_user_bg'))
        .accessibilityText($r('app.string.widget_a11y_dose_taken', this.name))
        .onClick(() => this.open('take'))
      } else {
        Text(this.state === 'NONE' ? $r('app.string.widget_dose_set') : $r('app.string.widget_dose_reminders'))
          .fontSize($r('app.float.font_badge'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .textAlign(TextAlign.Center)
          .width('100%')
          .height(36)
          .borderRadius(18)
          .backgroundColor($r('app.color.surface_alt'))
          .onClick(() => this.open('reminders'))
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .onClick(() => this.open('reminders'))
  }
}
