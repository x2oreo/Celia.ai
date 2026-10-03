// Result of a medicine check (NavDestination). Param: CheckParam.

import { CheckParam } from '../common/Routes';
import { CheckOutcome, CheckService } from '../drugs/CheckService';
import { LocalStore } from '../data/LocalStore';
import { Medication } from '../model/Medication';
import { Genotype, Profile } from '../model/Profile';
import { VerdictCard } from '../components/VerdictCard';
import { BackHeader, QuietButton, SecondaryButton, StatusStrip, TypingDots } from '../components/Common';
import { Logger } from '../common/Logger';
import { toast } from '../common/Toast';
import { AgentPrompt } from '../agent/AgentPrompt';
import { DrugVerdict } from '../model/DrugVerdict';

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

  // Hand the checked medicine to the agent: back to the tabs, chat opened, question already sent.
  private askCelia(): void {
    if (this.outcome === undefined) {
      return;
    }
    const v: DrugVerdict = this.outcome.verdict;
    this.navStack.clear();
    AgentPrompt.ask(`I was offered ${v.query}. Is it safe for me, and what should I ask my doctor?`);
  }

  build() {
    NavDestination() {
      Column() {
        BackHeader({
          title: $r('app.string.check_title'),
          onBack: () => {
            this.navStack.pop();
          }
        })
        Scroll() {
          Column({ space: 12 }) {
            if (this.failed) {
              StatusStrip({
                kind: 'ERROR',
                label: $r('app.string.check_failed'),
                action: $r('app.string.check_retry'),
                onAction: () => {
                  this.navStack.pop();
                }
              })
            } else if (this.outcome === undefined) {
              TypingDots({ label: $r('app.string.agent_thinking') })
                .margin({ top: 80 })
            } else {
              Column() {
                VerdictCard({
                  verdict: this.outcome.verdict,
                  combo: this.outcome.combo,
                  genotype: this.genotype,
                  variant: 'SHEET',
                  actionLabel: this.outcome.verdict.ingredient !== '' && !this.alreadyMine ?
                    $r('app.string.check_add_to_mine') : '',
                  onAction: () => {
                    this.addToMine();
                  }
                })
              }
              .padding(16)
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1, color: $r('app.color.border') })
              .borderRadius($r('app.float.radius_l'))

              QuietButton({
                label: $r('app.string.agent_ask_about'),
                onTap: () => {
                  this.askCelia();
                }
              })
              SecondaryButton({
                label: $r('app.string.check_another'),
                icon: $r('app.media.ic_search'),
                onTap: () => {
                  this.navStack.pop();
                }
              })
            }
          }
          .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen'), bottom: 24 })
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .onReady((ctx: NavDestinationContext) => {
      const param: CheckParam = ctx.pathInfo.param as CheckParam;
      this.load(param);
    })
  }
}
