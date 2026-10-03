// Stub (docs/handoff/B_PLAN.md): route registered in pages/Index.ets; its stream replaces this page.

@ComponentV2
export struct WelcomePage {
  build() {
    NavDestination() {
      Text('Welcome')
        .fontSize($r('app.float.font_headline'))
        .fontColor($r('app.color.ink'))
        .padding(24)
    }
    .title('Welcome')
    .backgroundColor($r('app.color.bg'))
  }
}
