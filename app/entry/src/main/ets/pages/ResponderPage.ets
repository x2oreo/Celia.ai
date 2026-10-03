// Stub (docs/handoff/B_PLAN.md): route registered in pages/Index.ets; its stream replaces this page.

@ComponentV2
export struct ResponderPage {
  build() {
    NavDestination() {
      Text('For first responders')
        .fontSize($r('app.float.font_headline'))
        .fontColor($r('app.color.ink'))
        .padding(24)
    }
    .title('For first responders')
    .backgroundColor($r('app.color.bg'))
  }
}
