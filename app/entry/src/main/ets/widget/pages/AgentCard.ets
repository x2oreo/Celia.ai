// "The agent" service card, 2×2 and 2×4 (DESIGN.md §11 widgets v2): the orb, what the agent has to say right now and
// one tap to talk. The line is the app's deterministic sentence (widget/WidgetSnapshot.ets), never model text.

let agentStorage: LocalStorage = new LocalStorage();

@Entry(agentStorage)
@Component
struct AgentCard {
  @LocalStorageProp('agentLine') line: string = '';
  @LocalStorageProp('wide') wide: boolean = false;

  private open(target: string): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { target: target }
    });
  }

  @Builder
  pill(icon: Resource, label: Resource, target: string, primary: boolean) {
    Row({ space: 6 }) {
      Image(icon)
        .width(16)
        .height(16)
        .fillColor(primary ? $r('app.color.on_accent') : $r('app.color.ink'))
      Text(label)
        .fontSize($r('app.float.font_badge'))
        .fontWeight(FontWeight.Bold)
        .fontColor(primary ? $r('app.color.on_accent') : $r('app.color.ink'))
        .maxLines(1)
    }
    .height(36)
    .padding({ left: 12, right: 12 })
    .borderRadius(18)
    .backgroundColor(primary ? $r('app.color.brand_accent') : $r('app.color.surface_alt'))
    .onClick(() => this.open(target))
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Row()
          .width(28)
          .height(28)
          .borderRadius(14)
          .radialGradient({
            center: [10, 9],
            radius: 24,
            colors: [[$r('app.color.orb_light'), 0], [$r('app.color.orb_mid'), 0.68], [$r('app.color.orb_dark'), 1]]
          })
        Text($r('app.string.widget_agent_label'))
          .fontSize($r('app.float.font_micro'))
          .fontWeight(FontWeight.Bolder)
          .letterSpacing(0.6)
          .fontColor($r('app.color.ink_3'))
      }

      Text(this.line === '' ? $r('app.string.widget_agent_empty') : this.line)
        .fontSize($r('app.float.font_small'))
        .fontWeight(FontWeight.Medium)
        .lineHeight(19)
        .fontColor($r('app.color.ink'))
        .maxLines(this.wide ? 2 : 3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 8 })

      Blank()

      Row({ space: 6 }) {
        this.pill($r('app.media.ic_mic'), $r('app.string.widget_agent_talk'), 'agent', true)
        if (this.wide) {
          this.pill($r('app.media.ic_scan'), $r('app.string.widget_agent_scan'), 'scan', false)
          this.pill($r('app.media.ic_smile'), $r('app.string.widget_agent_feel'), 'feeling', false)
        }
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .onClick(() => this.open('agent'))
  }
}
