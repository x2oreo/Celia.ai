// "How are you feeling?" service card, 2×2 and 2×4 (B15, DESIGN.md §11 widgets v2). The 2×4 shows the five moods:
// one tap opens the diary entry with that mood picked, so logging is a tap and a Save. Moods are not verdicts, so
// the chips are neutral. The last entry line comes from the app's snapshot. No AI.

let feelingStorage: LocalStorage = new LocalStorage();

@Entry(feelingStorage)
@Component
struct FeelingCard {
  @LocalStorageProp('feelLast') last: string = '';
  @LocalStorageProp('wide') wide: boolean = false;

  private open(target: string): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { target: target }
    });
  }

  @Builder
  mood(label: Resource, mood: string) {
    Text(label)
      .fontSize($r('app.float.font_caption'))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.ink'))
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .layoutWeight(1)
      .height(36)
      .borderRadius(18)
      .backgroundColor($r('app.color.surface_alt'))
      .onClick(() => this.open(`feeling:${mood}`))
  }

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
      Text(this.last === '' ? $r('app.string.widget_feel_none') : this.last)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 2 })
      if (this.wide) {
        Row({ space: 6 }) {
          this.mood($r('app.string.widget_mood_great'), 'GREAT')
          this.mood($r('app.string.widget_mood_good'), 'GOOD')
          this.mood($r('app.string.widget_mood_okay'), 'OKAY')
          this.mood($r('app.string.widget_mood_low'), 'LOW')
          this.mood($r('app.string.widget_mood_unwell'), 'UNWELL')
        }
        .width('100%')
        .margin({ top: 10 })
      } else {
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
        .borderRadius(18)
        .backgroundColor($r('app.color.chat_user_bg'))
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .onClick(() => this.open('feeling'))
  }
}
