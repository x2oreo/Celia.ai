// Someone else's emergency card, scanned from their QR with Celia's scanner (F-30). Decoded on device from the
// link's #fragment — works offline, nothing is stored. Same high-contrast look as our own card.
// Param: CardPayload (emergency/CardLink.ets).

import { CardPayload } from '../emergency/CardLink';
import { cardText, CardText } from '../common/CardStrings';
import { emergencyFor, EmergencyInfo } from '../common/EmergencyNumbers';
import { dial } from '../common/Dialer';
import { PrimaryButton, SecondaryButton } from '../components/Common';
import { toast } from '../common/Toast';

@ComponentV2
export struct CardViewPage {
  @Local card: CardPayload | undefined = undefined;
  private lang: string = 'en';

  private text(): CardText {
    return cardText(this.lang);
  }

  private info(): EmergencyInfo {
    return emergencyFor(this.card?.cc ?? '');
  }

  private medsText(c: CardPayload): string {
    if (c.m.length === 0 && c.x === 0) {
      return this.text().noMeds;
    }
    return c.m.join('\n') + (c.x > 0 ? `\n+${c.x} more` : '');
  }

  private async call(number: string): Promise<void> {
    if (!(await dial(number))) {
      toast(this.getUIContext(), $r('app.string.emergency_dial_failed'));
    }
  }

  @Builder
  line(label: string, value: string) {
    Column({ space: 2 }) {
      Text(label.toUpperCase()).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#667085')
      Text(value).fontSize(18).fontColor('#101828')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  cardView(c: CardPayload) {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Image($r('app.media.ic_tab_heart')).width(26).height(26).fillColor('#FFFFFF')
        Text(this.text().title).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').layoutWeight(1)
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#B42318')
      .borderRadius({ topLeft: 20, topRight: 20 })

      Column({ space: 14 }) {
        if (c.n.length > 0) {
          Text(c.n).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#101828')
        }
        Text(this.text().condition).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#B42318')
        this.line(this.text().genotype, c.g === 'UNKNOWN' ? '?' : c.g)
        Text(c.i === 1 ? this.text().icdYes : this.text().icdNo)
          .fontSize(18)
          .fontWeight(c.i === 1 ? FontWeight.Bold : FontWeight.Normal)
          .fontColor('#101828')
        Text(this.text().avoid)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#101828')
          .padding(12)
          .backgroundColor('#FEF3F2')
          .borderRadius(12)
          .width('100%')
        Text(this.text().treatment).fontSize(16).fontColor('#344054')
        this.line(this.text().meds, this.medsText(c))
        if (c.o.length > 0) {
          this.line(this.text().notes, c.o)
        }
      }
      .padding({ left: 16, right: 16, bottom: 16 })
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .border({ width: 2, color: '#B42318' })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          if (this.card !== undefined) {
            PrimaryButton({
              label: `${this.info().ambulance} · Call ambulance`,
              icon: $r('app.media.ic_phone'),
              danger: true,
              large: true,
              onTap: () => {
                this.call(this.info().ambulance);
              }
            })
            this.cardView(this.card)
            ForEach(this.card.c, (contact: string[]) => {
              SecondaryButton({
                label: `Call ${contact[0]}${contact[2] ? ` (${contact[2]})` : ''}`,
                icon: $r('app.media.ic_phone'),
                onTap: () => {
                  this.call(contact[1]);
                }
              })
            }, (contact: string[]) => `${contact[0]}-${contact[1]}`)
            Text($r('app.string.cardview_note'))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('sys.color.font_tertiary'))
          }
        }
        .padding(16)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .backgroundColor($r('app.color.page_bg'))
    }
    .title($r('app.string.cardview_title'))
    .backgroundColor($r('app.color.page_bg'))
    .onReady((ctx: NavDestinationContext) => {
      this.card = ctx.pathInfo.param as CardPayload;
    })
  }
}
