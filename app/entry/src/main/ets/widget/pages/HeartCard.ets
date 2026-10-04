// "Resting heart rate" service card, 2×2 and 2×4 (DESIGN.md §11 widgets v2, §6.10): the 7-day average, the change
// against the week before, and the week as dots on the usual range. A day without a reading has no dot and nothing
// bridges it. The 2×4 adds the status pill (fixed rules, word + shape, never red) and the last live reading.
// Heart rate only: never QT, never a trace.

let heartStorage: LocalStorage = new LocalStorage();

const PLOT_S: number = 40;
const PLOT_L: number = 56;

@Entry(heartStorage)
@Component
struct HeartCard {
  @LocalStorageProp('hrAvg') avg: number = 0;
  @LocalStorageProp('hrChange') change: string = '';
  @LocalStorageProp('hrSource') source: string = '';
  @LocalStorageProp('hrLevel') level: string = 'NONE';
  @LocalStorageProp('hrLast') last: string = '';
  @LocalStorageProp('hd0') d0: number = -1;
  @LocalStorageProp('hd1') d1: number = -1;
  @LocalStorageProp('hd2') d2: number = -1;
  @LocalStorageProp('hd3') d3: number = -1;
  @LocalStorageProp('hd4') d4: number = -1;
  @LocalStorageProp('hd5') d5: number = -1;
  @LocalStorageProp('hd6') d6: number = -1;
  @LocalStorageProp('hbLo') bandLo: number = 0;
  @LocalStorageProp('hbHi') bandHi: number = 0;
  @LocalStorageProp('wide') wide: boolean = false;

  private open(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { target: 'heart' }
    });
  }

  private days(): number[] {
    return [this.d0, this.d1, this.d2, this.d3, this.d4, this.d5, this.d6];
  }

  @Builder
  caps() {
    Text($r('app.string.widget_heart_label'))
      .fontSize($r('app.float.font_micro'))
      .fontWeight(FontWeight.Bolder)
      .letterSpacing(0.6)
      .fontColor($r('app.color.ink_3'))
      .maxLines(1)
  }

  // Mono 9 fp badge (§6.2): WATCH solid ink, SIMULATED outlined.
  @Builder
  badge() {
    Text(this.source === 'WATCH' ? $r('app.string.badge_watch') : $r('app.string.badge_simulated'))
      .fontSize($r('app.float.font_mono'))
      .fontWeight(FontWeight.Bold)
      .fontFamily('monospace')
      .fontColor(this.source === 'WATCH' ? $r('app.color.chat_user_text') : $r('app.color.ink'))
      .padding({ left: 5, right: 5, top: 3, bottom: 3 })
      .borderRadius(4)
      .backgroundColor(this.source === 'WATCH' ? $r('app.color.chat_user_bg') : Color.Transparent)
      .border({ width: this.source === 'WATCH' ? 0 : 1, color: $r('app.color.ink') })
  }

  @Builder
  value() {
    Row({ space: 4 }) {
      Text(`${this.avg}`)
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bolder)
        .fontColor($r('app.color.ink'))
      Text($r('app.string.widget_heart_avg'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
    }
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  plot(h: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      // The usual range as a surface-alt band behind the dots.
      if (this.bandHi > this.bandLo) {
        Row()
          .width('100%')
          .height((this.bandHi - this.bandLo) / 100 * h)
          .margin({ top: (100 - this.bandHi) / 100 * h })
          .borderRadius(4)
          .backgroundColor($r('app.color.surface_alt'))
      }
      Row() {
        ForEach(this.days(), (v: number, i: number) => {
          Stack({ alignContent: Alignment.Bottom }) {
            if (v >= 0) {
              Row()
                .width(i === 6 ? 10 : 6)
                .height(i === 6 ? 10 : 6)
                .borderRadius(i === 6 ? 5 : 3)
                .backgroundColor($r('app.color.brand_accent'))
                .margin({ bottom: v / 100 * (h - (i === 6 ? 10 : 6)) })
            }
          }
          .layoutWeight(1)
          .height(h)
        }, (v: number, i: number) => `${i}-${v}`)
      }
      .width('100%')
      .height(h)
    }
    .width('100%')
    .height(h)
  }

  // Status pill (§6.10): Good = check circle on the Not-listed tint, Worth a look = triangle on the Possible tint,
  // Okay = ring with a bar on surface-alt.
  @Builder
  status() {
    if (this.level === 'GOOD' || this.level === 'ATTENTION' || this.level === 'OKAY') {
      Row({ space: 5 }) {
        if (this.level === 'GOOD') {
          Image($r('app.media.ic_risk_ok')).width(14).height(14).fillColor($r('app.color.risk_not_listed'))
        } else if (this.level === 'ATTENTION') {
          Image($r('app.media.ic_risk_possible')).width(14).height(14).fillColor($r('app.color.risk_possible'))
        } else {
          Stack() {
            Row().width(5).height(2).borderRadius(1).backgroundColor($r('app.color.ink_2'))
          }
          .width(14)
          .height(14)
          .borderRadius(7)
          .border({ width: 1.5, color: $r('app.color.ink_2') })
        }
        Text(this.level === 'GOOD' ? $r('app.string.status_good') :
          (this.level === 'ATTENTION' ? $r('app.string.status_attention') : $r('app.string.status_okay')))
          .fontSize($r('app.float.font_caption'))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.level === 'GOOD' ? $r('app.color.risk_not_listed_text') :
            (this.level === 'ATTENTION' ? $r('app.color.risk_possible_text') : $r('app.color.ink_2')))
          .maxLines(1)
      }
      .height(24)
      .padding({ left: 5, right: 10 })
      .borderRadius(12)
      .backgroundColor(this.level === 'GOOD' ? $r('app.color.risk_not_listed_tint') :
        (this.level === 'ATTENTION' ? $r('app.color.risk_possible_tint') : $r('app.color.surface_alt')))
    }
  }

  @Builder
  empty() {
    Column({ space: 4 }) {
      this.caps()
      Blank()
      Text($r('app.string.widget_heart_empty'))
        .fontSize($r('app.float.font_headline'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
        .maxLines(2)
      if (this.last !== '') {
        Text($r('app.string.widget_heart_last', this.last))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
          .maxLines(1)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  small() {
    Column() {
      this.caps()
      Row() {
        this.value()
      }
      .margin({ top: 6 })
      Text(this.change)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
        .maxLines(1)
      Blank()
      // A 2×2 is too narrow for the badge next to the value: it sits over the plot's right end.
      Row() {
        Blank()
        this.badge()
      }
      .width('100%')
      .margin({ bottom: 4 })
      this.plot(PLOT_S)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  large() {
    Row({ space: 16 }) {
      Column({ space: 4 }) {
        this.caps()
        this.value()
        Text(this.change)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
          .maxLines(1)
        Blank()
        this.status()
      }
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .width('42%')
      Column() {
        Row() {
          Blank()
          this.badge()
        }
        .width('100%')
        Blank()
        this.plot(PLOT_L)
        if (this.last !== '') {
          Text($r('app.string.widget_heart_last', this.last))
            .fontSize($r('app.float.font_micro'))
            .fontColor($r('app.color.ink_3'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 6 })
        }
      }
      .height('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      if (this.avg <= 0) {
        this.empty()
      } else if (this.wide) {
        this.large()
      } else {
        this.small()
      }
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .onClick(() => this.open())
  }
}
