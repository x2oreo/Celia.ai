// "Can I take this?" service card, 2×2 and 2×4 (design B6, DESIGN.md §11 widgets v2): ink card, the agent's orb in
// the corner, one coral action. The 2×4 adds the last three checks on an always-light inset, each with its risk shape
// and word (§3, never colour alone). Risks come from the logged, deterministic verdicts.

let checkStorage: LocalStorage = new LocalStorage();

@Entry(checkStorage)
@Component
struct CheckCard {
  @LocalStorageProp('chk0Name') n0: string = '';
  @LocalStorageProp('chk0Risk') r0: string = '';
  @LocalStorageProp('chk1Name') n1: string = '';
  @LocalStorageProp('chk1Risk') r1: string = '';
  @LocalStorageProp('chk2Name') n2: string = '';
  @LocalStorageProp('chk2Risk') r2: string = '';
  @LocalStorageProp('wide') wide: boolean = false;

  private open(target: string): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { target: target }
    });
  }

  private shape(r: string): Resource {
    switch (r) {
      case 'KNOWN':
        return $r('app.media.ic_risk_known');
      case 'POSSIBLE':
        return $r('app.media.ic_risk_possible');
      case 'CONDITIONAL':
        return $r('app.media.ic_risk_conditional');
      case 'OK':
        return $r('app.media.ic_risk_ok');
      default:
        return $r('app.media.ic_risk_unknown');
    }
  }

  private solid(r: string): Resource {
    switch (r) {
      case 'KNOWN':
        return $r('app.color.risk_known');
      case 'POSSIBLE':
        return $r('app.color.risk_possible');
      case 'CONDITIONAL':
        return $r('app.color.risk_conditional');
      case 'OK':
        return $r('app.color.risk_not_listed');
      default:
        return $r('app.color.risk_unknown');
    }
  }

  private text(r: string): Resource {
    switch (r) {
      case 'KNOWN':
        return $r('app.color.risk_known_text');
      case 'POSSIBLE':
        return $r('app.color.risk_possible_text');
      case 'CONDITIONAL':
        return $r('app.color.risk_conditional_text');
      case 'OK':
        return $r('app.color.risk_not_listed_text');
      default:
        return $r('app.color.risk_unknown_text');
    }
  }

  private word(r: string): Resource {
    switch (r) {
      case 'KNOWN':
        return $r('app.string.risk_known');
      case 'POSSIBLE':
        return $r('app.string.risk_possible');
      case 'CONDITIONAL':
        return $r('app.string.risk_conditional');
      case 'OK':
        return $r('app.string.risk_not_listed');
      default:
        return $r('app.string.risk_unknown');
    }
  }

  @Builder
  checkRow(name: string, risk: string) {
    Row({ space: 6 }) {
      Image(this.shape(risk)).width(16).height(16).fillColor(this.solid(risk))
      Text(name)
        .fontSize($r('app.float.font_caption'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.card_fixed_ink'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(this.word(risk))
        .fontSize($r('app.float.font_mono'))
        .fontWeight(FontWeight.Bolder)
        .letterSpacing(0.3)
        .textCase(TextCase.UpperCase)
        .fontColor(this.text(risk))
        .maxLines(1)
    }
    .width('100%')
    .height(22)
  }

  @Builder
  recent() {
    Column({ space: 4 }) {
      Text($r('app.string.widget_check_recent'))
        .fontSize($r('app.float.font_mono'))
        .fontWeight(FontWeight.Bolder)
        .letterSpacing(0.6)
        .fontColor($r('app.color.card_fixed_ink_3'))
        .margin({ bottom: 2 })
      if (this.n0 === '') {
        Text($r('app.string.widget_check_empty'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.card_fixed_ink_2'))
      } else {
        this.checkRow(this.n0, this.r0)
        if (this.n1 !== '') {
          this.checkRow(this.n1, this.r1)
        }
        if (this.n2 !== '') {
          this.checkRow(this.n2, this.r2)
        }
      }
    }
    .height('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding(10)
    .borderRadius($r('app.float.radius_m'))
    .backgroundColor($r('app.color.card_fixed_bg'))
    .onClick(() => this.open('history'))
  }

  @Builder
  ask() {
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
    .width(this.wide ? '46%' : '100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width(96)
        .height(96)
        .borderRadius(48)
        .radialGradient({
          center: [34, 30],
          radius: 78,
          colors: [[$r('app.color.orb_light'), 0], [$r('app.color.orb_mid'), 0.68], [$r('app.color.orb_dark'), 1]]
        })
        // Right edge 28 vp past the corner (the ask column's corner on the 2×4), as in the B6 drawing.
        .position({ x: this.wide ? '50%' : '100%', y: 0 })
        .markAnchor({ x: 68, y: 28 })

      Row({ space: 12 }) {
        this.ask()
        if (this.wide) {
          this.recent()
        }
      }
      .width('100%')
      .height('100%')
      .padding(14)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.widget_ink'))
    .onClick(() => this.open('scan'))
  }
}
