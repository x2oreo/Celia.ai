// "Already took it?" card (DESIGN.md 10.2 "I took it"): logs that a medicine with QT risk was taken and tells the
// watch (drugs/DrugIntake.ets). Used on the Check result page and in the medicine detail sheet. Never a risk colour:
// logging an intake is not a verdict.

import { DrugIntake, IntakeRecord, WATCH_WINDOW_MS } from '../drugs/DrugIntake';
import { clock, dateTime } from '../common/Format';
import { Logger } from '../common/Logger';
import { InkButton, StatusStrip } from './Common';

const log: Logger = new Logger('IntakeCard');

@ComponentV2
export struct IntakeCard {
  @Param name: string = '';   // ingredient (or the checked name when unknown)
  @Param risk: string = '';   // DrugIntake riskToLog(); the card is only shown when it is non-empty
  @Local intake: IntakeRecord | undefined = undefined;
  @Local busy: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  // The detail sheet reuses this card when another medicine is opened.
  @Monitor('name')
  onNameChanged(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.intake = await DrugIntake.recent(this.name, Date.now());
  }

  // Logging tells the watch, so ask first and say plainly that it is not a safety verdict.
  private confirm(): void {
    if (this.busy) {
      return;
    }
    try {
      this.getUIContext().showAlertDialog({
        title: $r('app.string.intake_confirm_title', this.name),
        message: $r('app.string.intake_confirm_body'),
        primaryButton: {
          value: $r('app.string.intake_confirm_no'),
          action: () => {
          }
        },
        secondaryButton: {
          value: $r('app.string.intake_confirm_yes'),
          action: () => {
            this.log();
          }
        }
      });
    } catch (e) {
      log.error(`intake dialog failed: ${JSON.stringify(e)}`);
    }
  }

  private async log(): Promise<void> {
    this.busy = true;
    // A retry keeps the original time of taking: the watch's 72 h window starts when it was taken.
    const at: number = this.intake?.ts ?? Date.now();
    this.intake = await DrugIntake.record(this.name, this.risk, at, this.intake !== undefined);
    this.busy = false;
  }

  build() {
    Column({ space: 10 }) {
      if (this.intake === undefined) {
        Text($r('app.string.intake_title'))
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text($r('app.string.intake_body'))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_3'))
        InkButton({
          label: $r('app.string.intake_button'),
          icon: $r('app.media.ic_pill'),
          onTap: () => {
            this.confirm();
          }
        })
      } else {
        Row({ space: 10 }) {
          Image($r('app.media.ic_check')).width(20).height(20).fillColor($r('app.color.ink_2'))
          Text($r('app.string.intake_done', clock(this.intake.ts)))
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
        }
        .width('100%')
        if (this.intake.watchSynced) {
          Text($r('app.string.intake_watching', dateTime(this.intake.ts + WATCH_WINDOW_MS, Date.now())))
            .fontSize($r('app.float.font_small'))
            .fontColor($r('app.color.ink_3'))
        } else {
          StatusStrip({
            kind: 'ERROR',
            label: $r('app.string.intake_not_synced'),
            action: $r('app.string.intake_retry'),
            onAction: () => {
              this.log();
            }
          })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.border') })
    .borderRadius($r('app.float.radius_l'))
  }
}
