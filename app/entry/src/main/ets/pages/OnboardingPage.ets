// Onboarding (B3): 8 steps, one question group per screen, progress shown, Skip on every optional step.
//   1 welcome + consent  2 account  3 about you  4 medicines  5 contacts  6 emergency details  7 permissions  8 watch
// State lives in one place: the profile draft below (plus the consent flag). Every step is kept alive and only the
// current one is shown, so going back never loses anything, half-typed fields included. Saved once, on Finish.
// Step rules are pure functions in onboarding/OnboardingFlow.ets.

import { AgentAvatar } from '../components/AgentAvatar';
import { AddMedForm } from '../components/AddMedForm';
import { AuthForm } from '../components/AuthForm';
import { EmergencyDetailsForm } from '../components/EmergencyDetailsForm';
import { PrimaryButton, RiskBadge, SecondaryButton } from '../components/Common';
import { OnbHeading } from '../components/onboarding/OnbParts';
import { StepAbout } from '../components/onboarding/StepAbout';
import { StepContacts } from '../components/onboarding/StepContacts';
import { StepPermissions } from '../components/onboarding/StepPermissions';
import { LocalStore } from '../data/LocalStore';
import { Session } from '../account/Session';
import { AuthMode, Routes } from '../common/Routes';
import { EMERGENCY_NUMBERS, EmergencyInfo, emergencyFor, systemCountry } from '../common/EmergencyNumbers';
import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { medRisk } from './MedicinesPage';
import { Logger } from '../common/Logger';
import {
  canContinue,
  copyProfile,
  finalProfile,
  isLastStep,
  isOptional,
  newProfile,
  nextStep,
  OnbStep,
  prevStep,
  shouldFinishAfterSignIn,
  STEP_COUNT,
  withDetails
} from '../onboarding/OnboardingFlow';

export { validPhone } from '../onboarding/OnboardingFlow';

const log: Logger = new Logger('Onboarding');
const STEP_INDEXES: number[] = [0, 1, 2, 3, 4, 5, 6, 7];
const AUTH_MODES: AuthMode[] = ['SIGN_UP', 'LOG_IN'];

@ComponentV2
export struct OnboardingPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local step: number = OnbStep.WELCOME;
  @Local consented: boolean = false;
  @Local draft: Profile = newProfile('PL');
  @Local meds: Medication[] = [];
  @Local authMode: AuthMode = 'SIGN_UP';
  @Local signedIn: boolean = false;
  @Local finishing: boolean = false;
  private scroller: Scroller = new Scroller();
  private startedAt: number = Date.now();
  private offSession: () => void = () => {
  };

  aboutToAppear(): void {
    const sys: string = systemCountry();
    this.draft = newProfile(emergencyFor(sys).code === '' ? 'PL' : sys);
    this.signedIn = Session.isSignedIn();
    this.offSession = Session.onChange((signedIn: boolean) => {
      this.signedIn = signedIn;
    });
    this.reloadMeds();
  }

  aboutToDisappear(): void {
    this.offSession();
  }

  private async reloadMeds(): Promise<void> {
    this.meds = await LocalStore.get().listMeds();
  }

  private goTo(step: number): void {
    this.step = step;
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }

  private next(): void {
    if (isLastStep(this.step)) {
      this.finish();
    } else {
      this.goTo(nextStep(this.step));
    }
  }

  private async onAuthDone(signedIn: boolean): Promise<void> {
    this.signedIn = signedIn;
    if (!signedIn) {
      return;
    }
    // The accounts stream restores the profile from the account at sign-in; if one came back, we are done.
    const restored: Profile | undefined = await LocalStore.get().getProfile();
    if (shouldFinishAfterSignIn(signedIn, restored)) {
      log.info('returning user: profile restored, onboarding skipped');
      this.navStack.clear();
      return;
    }
    this.goTo(nextStep(OnbStep.ACCOUNT));
  }

  private async finish(): Promise<void> {
    if (this.finishing) {
      return;
    }
    this.finishing = true;
    const profile: Profile = finalProfile(this.draft);
    await LocalStore.get().saveProfile(profile);
    log.info(`profile saved: ${this.meds.length} meds, ${profile.contacts.length} contacts, ` +
      `onboarding took ${Math.round((Date.now() - this.startedAt) / 1000)} s`);
    this.navStack.clear();
  }

  // Back from the first step only returns to the Welcome page (accounts stream); onboarding is never dismissed into
  // an app with no profile. Returns true when the back press is handled here.
  private onBack(): boolean {
    if (this.step > 0) {
      this.goTo(prevStep(this.step));
      return true;
    }
    const names: string[] = this.navStack.getAllPathName();
    const below: string = names.length >= 2 ? names[names.length - 2] : '';
    return below !== Routes.WELCOME;
  }

  // ── Steps ──────────────────────────────────────────────────────────────────────────────────────────────────

  @Builder
  stepWelcome() {
    Column({ space: 16 }) {
      // Padded so the breathing scale is not clipped at the page edge.
      Row() {
        AgentAvatar({ dim: 96 })
      }
      .padding(8)
      OnbHeading({ heading: $r('app.string.onb_welcome_title'), subtitle: $r('app.string.onb_welcome_body') })
      Text($r('app.string.onb_welcome_time'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_2'))
      Row({ space: 12 }) {
        Checkbox({ name: 'onbConsent' })
          .select(this.consented)
          .selectedColor($r('app.color.ink'))
          .width(24)
          .height(24)
          .onChange((on: boolean) => {
            this.consented = on;
          })
        Text($r('app.string.onb_welcome_consent'))
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)
      }
      .width('100%')
      .constraintSize({ minHeight: $r('app.float.touch_min') })
      .padding($r('app.float.space_m'))
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: this.consented ? $r('app.color.ink') : $r('app.color.border') })
      .borderRadius($r('app.float.radius_m'))
      .onClick(() => {
        this.consented = !this.consented;
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  stepAccount() {
    Column({ space: 16 }) {
      OnbHeading({ heading: $r('app.string.onb_account_title'), subtitle: $r('app.string.onb_account_subtitle') })
      if (this.signedIn) {
        Row({ space: 8 }) {
          Image($r('app.media.ic_check')).width(20).height(20).fillColor($r('app.color.ink_2'))
          Text($r('app.string.onb_account_signed_in', Session.email()))
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
        }
        .width('100%')
        .padding($r('app.float.space_m'))
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border') })
        .borderRadius($r('app.float.radius_m'))
      } else {
        Row({ space: 8 }) {
          ForEach(AUTH_MODES, (m: AuthMode) => {
            Text(m === 'SIGN_UP' ? $r('app.string.onb_account_new') : $r('app.string.onb_account_existing'))
              .fontSize($r('app.float.font_body'))
              .fontColor(this.authMode === m ? $r('app.color.on_accent') : $r('app.color.ink'))
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height($r('app.float.chip_height'))
              .borderRadius($r('app.float.radius_s'))
              .backgroundColor(this.authMode === m ? $r('app.color.ink') : $r('app.color.surface'))
              .border({ width: this.authMode === m ? 0 : 1.5, color: $r('app.color.border_strong') })
              .accessibilitySelected(this.authMode === m)
              .onClick(() => {
                this.authMode = m;
              })
          }, (m: AuthMode) => m)
        }
        .width('100%')
        AuthForm({
          mode: this.authMode,
          embedded: true,
          onDone: (signedIn: boolean) => {
            this.onAuthDone(signedIn);
          }
        })
        Text($r('app.string.onb_account_skip_note'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  stepMeds() {
    Column({ space: 16 }) {
      OnbHeading({ heading: $r('app.string.onb_meds_title'), subtitle: $r('app.string.onb_meds_subtitle') })
      AddMedForm({
        embedded: true,
        onAdded: () => {
          this.reloadMeds();
        }
      })
      ForEach(this.meds, (m: Medication) => {
        Row({ space: 8 }) {
          Text(m.dose === '' ? m.name : `${m.name} · ${m.dose}`)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
          RiskBadge({ risk: medRisk(m), compact: true })
        }
        .width('100%')
        .padding($r('app.float.space_sm'))
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border') })
        .borderRadius($r('app.float.radius_s'))
      }, (m: Medication) => `${m.id}`)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  stepDetails() {
    Column({ space: 16 }) {
      OnbHeading({ heading: $r('app.string.onb_details_title'), subtitle: $r('app.string.onb_details_subtitle') })
      Column({ space: 6 }) {
        Text($r('app.string.onb_country'))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_3'))
        Select(EMERGENCY_NUMBERS.map((e: EmergencyInfo) => {
          const opt: SelectOption = { value: `${e.name} (${e.ambulance})` };
          return opt;
        }))
          .selected(Math.max(0, EMERGENCY_NUMBERS.findIndex((e: EmergencyInfo) => e.code === this.draft.country)))
          .value(`${emergencyFor(this.draft.country).name} (${emergencyFor(this.draft.country).ambulance})`)
          .width('100%')
          .onSelect((index: number) => {
            const p: Profile = copyProfile(this.draft);
            p.country = EMERGENCY_NUMBERS[index].code;
            this.draft = p;
          })
        Text($r('app.string.onb_finish_subtitle'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.ink_3'))
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      EmergencyDetailsForm({
        profile: this.draft,
        showDob: false,
        onChange: (p: Profile) => {
          this.draft = withDetails(this.draft, p);
        }
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  stepWatch() {
    Column({ space: 16 }) {
      OnbHeading({ heading: $r('app.string.onb_watch_title'), subtitle: $r('app.string.onb_watch_subtitle') })
      SecondaryButton({
        label: $r('app.string.onb_watch_pair'),
        onTap: () => {
          this.navStack.pushPathByName(Routes.PAIR_WATCH, null);
        }
      })
      Text($r('app.string.onb_watch_later'))
        .fontSize($r('app.float.font_small'))
        .fontColor($r('app.color.ink_3'))
      Text($r('app.string.onb_privacy_account'))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  progress() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        ForEach(STEP_INDEXES, (i: number) => {
          Column()
            .height(4)
            .layoutWeight(1)
            .borderRadius(2)
            .backgroundColor(i <= this.step ? $r('app.color.brand_accent') : $r('app.color.border_strong'))
        }, (i: number) => `${i}`)
      }
      .width('100%')
      Text($r('app.string.onb_step_of', this.step + 1, STEP_COUNT))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.ink_3'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ top: $r('app.float.space_m'), bottom: $r('app.float.space_m') })
  }

  build() {
    NavDestination() {
      Column() {
        this.progress()

        Scroll(this.scroller) {
          Column() {
            // All steps stay built; only the current one is visible (keeps half-typed input when going back).
            Column() {
              this.stepWelcome()
            }
            .visibility(this.step === OnbStep.WELCOME ? Visibility.Visible : Visibility.None)
            Column() {
              this.stepAccount()
            }
            .visibility(this.step === OnbStep.ACCOUNT ? Visibility.Visible : Visibility.None)
            Column() {
              StepAbout({
                profile: this.draft,
                onChange: (p: Profile) => {
                  this.draft = p;
                }
              })
            }
            .visibility(this.step === OnbStep.ABOUT ? Visibility.Visible : Visibility.None)
            Column() {
              this.stepMeds()
            }
            .visibility(this.step === OnbStep.MEDS ? Visibility.Visible : Visibility.None)
            Column() {
              StepContacts({
                profile: this.draft,
                onChange: (p: Profile) => {
                  this.draft = p;
                }
              })
            }
            .visibility(this.step === OnbStep.CONTACTS ? Visibility.Visible : Visibility.None)
            Column() {
              this.stepDetails()
            }
            .visibility(this.step === OnbStep.DETAILS ? Visibility.Visible : Visibility.None)
            Column() {
              StepPermissions()
            }
            .visibility(this.step === OnbStep.PERMISSIONS ? Visibility.Visible : Visibility.None)
            Column() {
              this.stepWatch()
            }
            .visibility(this.step === OnbStep.WATCH ? Visibility.Visible : Visibility.None)
          }
          .width('100%')
          .padding({ bottom: $r('app.float.space_m') })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)

        Column({ space: 8 }) {
          PrimaryButton({
            label: isLastStep(this.step) ? $r('app.string.onb_done') : $r('app.string.onb_continue'),
            active: isLastStep(this.step) ? !this.finishing : canContinue(this.step, this.consented, this.draft),
            onTap: () => {
              if (isLastStep(this.step) || canContinue(this.step, this.consented, this.draft)) {
                this.next();
              }
            }
          })
          Row() {
            if (this.step > 0) {
              Text($r('app.string.onb_back'))
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.ink_3'))
                .padding($r('app.float.space_s'))
                .constraintSize({ minHeight: $r('app.float.touch_min') })
                .onClick(() => {
                  this.goTo(prevStep(this.step));
                })
            }
            Blank()
            if (isOptional(this.step)) {
              Text($r('app.string.onb_skip'))
                .fontSize($r('app.float.font_body'))
                .fontColor($r('app.color.ink_3'))
                .padding($r('app.float.space_s'))
                .constraintSize({ minHeight: $r('app.float.touch_min') })
                .onClick(() => this.next())
            }
          }
          .width('100%')
          Text($r('app.string.disclaimer'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.ink_4'))
            .textAlign(TextAlign.Center)
        }
        .padding({ bottom: $r('app.float.space_s') })
      }
      .width('100%')
      .height('100%')
      .padding({ left: $r('app.float.space_screen'), right: $r('app.float.space_screen') })
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg'))
    .onBackPressed(() => this.onBack())
  }
}
