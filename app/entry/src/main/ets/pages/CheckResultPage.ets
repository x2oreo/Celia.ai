// Result of a medicine check (NavDestination). Param: CheckParam.

import { CheckParam } from '../common/Routes';
import { CheckOutcome, CheckService } from '../drugs/CheckService';
import { LocalStore } from '../data/LocalStore';
import { Medication } from '../model/Medication';
import { BoxInfo } from '../model/BoxInfo';
import { Genotype, Profile } from '../model/Profile';
import { VerdictCard } from '../components/VerdictCard';
import { MedicineInfoCard } from '../components/MedicineInfoCard';
import {
  fmtText, QuietButton, ScreenHeader, SecondaryButton, StatusStrip, TypingDots
} from '../components/Common';
import { Logger } from '../common/Logger';
import { toast } from '../common/Toast';
import { AgentPrompt } from '../agent/AgentPrompt';
import { DrugVerdict } from '../model/DrugVerdict';
import { intakeName, intakeRisk } from '../drugs/DrugIntake';
import { IntakeCard } from '../components/IntakeCard';

const log: Logger = new Logger('CheckResult');

@ComponentV2
export struct CheckResultPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local outcome: CheckOutcome | undefined = undefined;
  @Local genotype: Genotype = 'UNKNOWN';
  @Local alreadyMine: boolean = false;
  @Local failed: boolean = false;
  private param: CheckParam | undefined = undefined;

  private async load(param: CheckParam): Promise<void> {
    this.param = param;
    this.failed = false;
    try {
      const profile: Profile | undefined = await LocalStore.get().getProfile();
      this.genotype = profile?.genotype ?? 'UNKNOWN';
      const result: CheckOutcome = param.log ? await CheckService.run(param.query, param.via ?? 'TEXT') :
        await CheckService.peek(param.query);
      const meds: Medication[] = await LocalStore.get().listMeds();
      const key: string = result.verdict.ingredient !== '' ? result.verdict.ingredient :
        (result.box?.ingredients ?? '');
      this.alreadyMine = key !== '' && meds.some((m: Medication) => m.ingredient === key);
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
    // From a box: keep the brand as the name and the strength as the dose.
    const box: BoxInfo | undefined = this.outcome.box;
    const ingredient: string = this.outcome.verdict.ingredient !== '' ? this.outcome.verdict.ingredient :
      (box?.ingredients ?? '');
    await LocalStore.get().addMed(box?.brand ?? this.outcome.verdict.query, ingredient, box?.strength ?? '');
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
    AgentPrompt.ask(fmtText(this.getUIContext(), $r('app.string.check_ask_prompt'), v.query));
  }

  build() {
    NavDestination() {
      Column() {
        ScreenHeader({ title: $r('app.string.check_title') })
        Scroll() {
          Column({ space: 12 }) {
            if (this.failed) {
              StatusStrip({
                kind: 'ERROR',
                label: $r('app.string.check_failed'),
                action: $r('app.string.check_retry'),
                onAction: () => {
                  if (this.param !== undefined) {
                    this.load(this.param);
                  }
                }
              })
              SecondaryButton({
                label: $r('app.string.check_another'),
                icon: $r('app.media.ic_search'),
                onTap: () => {
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
                  combos: this.outcome.combos,
                  combinedRisk: this.outcome.combinedRisk,
                  genotype: this.genotype,
                  variant: 'SHEET',
                  actionLabel: (this.outcome.verdict.ingredient !== '' || this.outcome.box !== undefined) &&
                    !this.alreadyMine ?
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

              if (intakeRisk(this.outcome) !== '') {
                IntakeCard({ name: intakeName(this.outcome), risk: intakeRisk(this.outcome) })
              }

              if (this.outcome.box !== undefined) {
                MedicineInfoCard({
                  box: this.outcome.box,
                  onForgotten: () => {
                    this.navStack.pop();
                  }
                })
              }

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
