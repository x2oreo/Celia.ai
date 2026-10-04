// "About this medicine" (F-36): what a scanned box is - kind of medicine, active substance, strength, form,
// pack, prescription status, maker, ATC code, source - plus the official patient leaflet. Facts only, from the
// national register or what the user typed; the verdict card above stays the only safety statement.

import { common } from '@kit.AbilityKit';
import { BoxInfo } from '../model/BoxInfo';
import { describeBox, InfoRow, infoRows, sourceLine } from '../drugs/BoxFacts';
import { forgetBox } from '../drugs/BarcodeService';
import { Logger } from '../common/Logger';
import { toast } from '../common/Toast';

const log: Logger = new Logger('MedicineInfo');

@ComponentV2
export struct MedicineInfoCard {
  @Param box: BoxInfo | undefined = undefined;
  @Event onForgotten: () => void = () => {
  };

  private openLeaflet(url: string): void {
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ctx.openLink(url).catch((e: Error) => {
      log.warn(`leaflet open failed: ${JSON.stringify(e)}`);
      toast(this.getUIContext(), $r('app.string.error_generic'));
    });
  }

  @Builder
  row(r: InfoRow) {
    Row({ space: 12 }) {
      Text(r.label)
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_2'))
        .width('38%')
      Text(r.value)
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink'))
        .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .accessibilityGroup(true)
  }

  build() {
    if (this.box !== undefined) {
      Column({ space: 12 }) {
        Row({ space: 10 }) {
          Image($r('app.media.ic_pill')).width(20).height(20).fillColor($r('app.color.brand_accent'))
          Text($r('app.string.info_title'))
            .fontSize($r('app.float.font_subtitle'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
        }
        .width('100%')

        Text(describeBox(this.box))
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.ink'))
          .lineHeight(22)

        Column() {
          ForEach(infoRows(this.box), (r: InfoRow, i: number) => {
            if (i > 0) {
              Divider().color($r('app.color.divider'))
            }
            this.row(r)
          }, (r: InfoRow) => r.label)
        }
        .width('100%')

        if (this.box.leafletUrl.length > 0) {
          Row({ space: 8 }) {
            Text($r('app.string.info_leaflet'))
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.brand_accent'))
              .layoutWeight(1)
            Image($r('app.media.ic_chevron_right')).width(16).height(16).fillColor($r('app.color.brand_accent'))
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
          .accessibilityGroup(true)
          .accessibilityText($r('app.string.info_leaflet'))
          .onClick(() => {
            this.openLeaflet(this.box?.leafletUrl ?? '');
          })
        }

        Text(sourceLine(this.box))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))

        if (this.box.source === 'LEARNED' || this.box.source === 'ONLINE') {
          Text($r('app.string.info_forget'))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.risk_known'))
            .onClick(() => {
              const gtin: string = this.box?.gtin ?? '';
              forgetBox(gtin).then(() => {
                toast(this.getUIContext(), $r('app.string.info_forgotten'));
                this.onForgotten();
              });
            })
        }
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.border') })
      .borderRadius($r('app.float.radius_l'))
    }
  }
}
