// Result of a medicine check (NavDestination). Param: CheckParam.

import { CheckParam } from '../common/Routes';
import { CheckOutcome, CheckService } from '../drugs/CheckService';
import { LocalStore } from '../data/LocalStore';
import { Medication } from '../model/Medication';
import { Genotype, Profile } from '../model/Profile';
import { VerdictCard } from '../components/VerdictCard';
import { PrimaryButton, SecondaryButton } from '../components/Common';
import { Logger } from '../common/Logger';
import { toast } from '../common/Toast';

const log: Logger = new Logger('CheckResult');

@ComponentV2
export struct CheckResultPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local outcome: CheckOutcome | undefined = undefined;
  @Local genotype: Genotype = 'UNKNOWN';
  @Local alreadyMine: boolean = false;
  @Local failed: boolean = false;

  private async load(param: CheckParam): Promise<void> {
    try {
      const profile: Profile | undefined = await LocalStore.get().getProfile();
      this.genotype = profile?.genotype ?? 'UNKNOWN';
      const result: CheckOutcome = param.log ? await CheckService.run(param.query, param.via ?? 'TEXT') :
        await CheckService.peek(param.query);
      const meds: Medication[] = await LocalStore.get().listMeds();
      this.alreadyMine = meds.some((m: Medication) => m.ingredient === result.verdict.ingredient);
      this.outcome = result;
    } catch (e) {
      log.error(`check failed: ${JSON.stringify(e)}`);
      this.failed = true;
    }
  }

  private async addToMine(): Promise<void> {
    if (this.outcome === undefined) {
      return;
    }
    await LocalStore.get().addMed(this.outcome.verdict.query, this.outcome.verdict.ingredient, '');
    this.alreadyMine = true;
    toast(this.getUIContext(), $r('app.string.meds_added'));
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          if (this.failed) {
            Text($r('app.string.error_generic'))
              .fontSize($r('app.float.font_body'))
              .fontColor($r('sys.color.font_secondary'))
              .padding(24)
          } else if (this.outcome === undefined) {
            LoadingProgress().width(40).height(40).margin({ top: 80 })
          } else {
            VerdictCard({ verdict: this.outcome.verdict, combo: this.outcome.combo, genotype: this.genotype })
            if (this.outcome.verdict.ingredient !== '' && !this.alreadyMine) {
              SecondaryButton({
                label: $r('app.string.check_add_to_mine'),
                icon: $r('app.media.ic_plus'),
                onTap: () => {
                  this.addToMine();
                }
              })
            }
            PrimaryButton({
              label: $r('app.string.check_another'),
              icon: $r('app.media.ic_search'),
              onTap: () => {
                this.navStack.pop();
              }
            })
            Text($r('app.string.disclaimer'))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('sys.color.font_tertiary'))
              .textAlign(TextAlign.Center)
              .width('100%')
          }
        }
        .padding(16)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .backgroundColor($r('app.color.page_bg'))
    }
    .title($r('app.string.check_title'))
    .backgroundColor($r('app.color.page_bg'))
    .onReady((ctx: NavDestinationContext) => {
      const param: CheckParam = ctx.pathInfo.param as CheckParam;
      this.load(param);
    })
  }
}
