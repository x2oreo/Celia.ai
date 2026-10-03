// Stub (docs/handoff/B_PLAN.md): route registered in pages/Index.ets; its stream replaces this page.

@ComponentV2
export struct EmergencyProfilePage {
  build() {
    NavDestination() {
      Text('Emergency details')
        .fontSize($r('app.float.font_headline'))
        .fontColor($r('app.color.ink'))
        .padding(24)
    }
    .title('Emergency details')
    .backgroundColor($r('app.color.bg'))
  }
}
